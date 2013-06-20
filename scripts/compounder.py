import sys
import fst

def make_sentence_fsa(words, word_ids):
  t = fst.StdVectorFst()
  t.start = t.add_state()
  i = 0
  space_id = syms["<space>"]
  for word_id in word_ids:
    if i > 0:
      t.add_state()
      t.add_arc(i,  i+1 , space_id, space_id)    
      i += 1
    t.add_state()
    t.add_arc(i,  i+1, word_id, word_id)
    i+=1
  t[i].final = True
  return t

def make_compounder(words, word_ids):
  c = fst.StdVectorFst()
  c.start = c.add_state()
  space_id = syms["<space>"]
  c.add_arc(0, 0, space_id, syms["<eps>"])
  c.add_arc(0, 0, space_id, syms["+C+"])
  c.add_arc(0, 0, space_id, syms["+D+"])
  for word_id in word_ids:
    c.add_arc(0, 0, word_id, word_id)  
  c[0].final = True
  return c



g = fst.read("G.fst")

syms = {}
syms_list = []
for l in open("words-compounder.txt"):
  ss = l.split()
  syms[ss[0]] = int(ss[1])
  syms_list.append(ss[0])
  
unk_id = syms["<unk>"]  
for l in sys.stdin:
  unks = []
  words = l.split()
  word_ids = []
  for word in words:
    word_id = syms.get(word, unk_id)
    word_ids.append(word_id)
    if word_id == unk_id:
      unks.append(word)
    
  
  sentence = make_sentence_fsa(words, word_ids)
  compound = make_compounder(words, word_ids)
  composed = sentence >> compound
  composed2 = composed >> g
  #composed.arc_sort_output()
  
  alignment = composed2.shortest_path()
  alignment.remove_epsilon()
  alignment.top_sort()
  arcs = (next(state.arcs) for state in alignment)
  labels = []
  for arc in arcs:
    if arc.olabel > 0:
      if arc.olabel == unk_id:
        labels.append(unks.pop(0))
      else:
        labels.append(syms_list[arc.olabel])
  print " ".join(labels)
