#! /usr/bin/env python
from __future__ import print_function
import sys
import pywrapfst as fst
import pdb
''' 
Script that adds symbols for compound word reconstruction (+C+, +D+, the 
latter is word dash-seperated words) between tokens, using a "hidden event LM",
i.e. a LM that includes also +C+ and +D+.
'''


def make_sentence_fsa(syms, word_ids):
  t = fst.Fst()
  start_state = t.add_state()
  assert(start_state == 0)
  t.set_start(start_state)
  i = 0
  space_id = syms["<space>"]
  for word_id in word_ids:
    if i > 0:
      new_state = t.add_state()
      assert(new_state == i+1)
      t.add_arc(i, fst.Arc(space_id, space_id, 1, i+1))
      i += 1
    t.add_state()
    t.add_arc(i, fst.Arc(word_id, word_id, 1, i+1))
    i+=1
  t.set_final(i, 1)
  return t

def make_compounder(syms, word_ids):
  c = fst.Fst()
  start_state = c.add_state()
  assert(start_state == 0)
  c.set_start(start_state)
  space_id = syms["<space>"]
  c.add_arc(0, fst.Arc(space_id, syms["<eps>"], 1, 0))
  c.add_arc(0, fst.Arc(space_id, syms["+C+"], 1, 0))
  c.add_arc(0, fst.Arc(space_id, syms["+D+"], 1, 0))
  for word_id in word_ids:
    c.add_arc(0, fst.Arc(word_id, word_id, 1, 0))
  c.set_final(0, 1)
  return c


if __name__ == '__main__':
  if len(sys.argv) != 3:
    print("Usage: %s G.fst words.txt" % sys.argv[0], file=sys.stderr)
    
  g = fst.Fst.read(sys.argv[1])

  syms = {}
  syms_list = []
  for l in open(sys.argv[2]):
    ss = l.split()
    syms[ss[0]] = int(ss[1])
    syms_list.append(ss[0])
    
  unk_id = syms["<unk>"]  
  # Following is needed to avoid line buffering
  while 1:
    l = sys.stdin.readline()
    if not l: break
    unks = []
    words = l.split()
    word_ids = []
    for word in words:
      word_id = syms.get(word, unk_id)
      word_ids.append(word_id)
      if word_id == unk_id:
        unks.append(word)
  
  
    sentence = make_sentence_fsa(syms, word_ids)
    compound = make_compounder(syms, word_ids)
    composed = fst.compose(sentence, compound)
    composed2 = fst.compose(composed, g)
    
    alignment = fst.shortestpath(composed2)
    alignment.rmepsilon()
    alignment.topsort()
        
    labels = []
    for state in alignment.states():
      for arc in alignment.arcs(state):
        if arc.olabel > 0:
          if arc.olabel == unk_id:
            labels.append(unks.pop(0))
          else:
            labels.append(syms_list[arc.olabel])
    print(" ".join(labels))
    sys.stdout.flush()
