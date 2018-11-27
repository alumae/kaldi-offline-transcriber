#! /usr/bin/env python3

import sys
import argparse
import simplejson as json
from subprocess import Popen, PIPE
import difflib

def postprocess_sections(sections, postprocessor):
  for section in sections:
    if section["type"] == "speech":
      for turn in section.get("turns", []):
        words_full = turn["words"]
        if len(words_full) > 0:
          words_full_postprocessed = []
          words = [w["word"] for w in turn["words"]]
          words_str = " ".join(words)
          if len(words_str) > 0:
            postprocessor.stdin.write((words_str + "\n").encode('utf-8'))
            postprocessor.stdin.flush()
            words_str_postprocessed = postprocessor.stdout.readline().strip().decode('utf-8')
            words_postprocessed = words_str_postprocessed.split()
            s = difflib.SequenceMatcher(None, words, words_postprocessed)
            for tag, i1, i2, j1, j2 in s.get_opcodes():
              if tag in ["insert", "delete"]:
                print("Warning: postprocessor should only replace words (or word blocks), but [%s] detected % tag", file=sys.stderr)
                words_full_postprocessed = words_full
                break
              else:
                if tag == "equal":
                  words_full_postprocessed.extend(words_full[i1:i2])
                elif tag == "replace":
                  new_word = {"word" : " ".join(words_postprocessed[j1:j2])}
                  new_word["start"] = words_full[i1]["start"]
                  for key in words_full[i2-1].keys():
                    if key not in ["word", "start"]:
                      new_word[key] = words_full[i2-1][key]
                  if "word_with_punctuation" in new_word:
                    new_word["word_with_punctuation"] = new_word["word"] + new_word["punctuation"]
                  new_word["unnormalized_words"] = words_full[i1:i2]
                  if "confidence" in new_word:
                    new_word["confidence"] = min([w["confidence"] for w in words_full[i1:i2]])
                    
                  words_full_postprocessed.append(new_word)
                  
            
            turn["words"] = words_full_postprocessed      
            turn["unnormalized_transcript"] = turn["transcript"]
            if "word_with_punctuation" in turn["words"][0]:
              turn["transcript"] = " ".join([w["word_with_punctuation"] for w in turn["words"]])
            else:
              turn["transcript"] = " ".join([w["word"] for w in turn["words"]])
              
      

if __name__ == '__main__':

  parser = argparse.ArgumentParser("Postprocesses JSON text using an external program")
  parser.add_argument('cmd', help="Normalizer command (pipe)")
  parser.add_argument('json')

  args = parser.parse_args()

  postprocessor = Popen(args.cmd, shell=True, stdin=PIPE, stdout=PIPE)

  trans = json.load(open(args.json))
  
  postprocess_sections(trans["sections"], postprocessor)
  
  print(json.dumps(trans, sort_keys=False, indent=4))

