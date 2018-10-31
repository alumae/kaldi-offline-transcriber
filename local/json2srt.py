#! /usr/bin/env python3
import random
import json
import sys
import datetime
import argparse

def get_word(word):
  return word.get("word_with_punctuation", word["word"])

def length_feature(subtitle, pause):
  num_characters = len(subtitle)
  if num_characters > 70:
    return -2 * num_characters
  if num_characters <= 20:
    return (20 - num_characters) * -1
    
  return num_characters
  
def punctuation_feature(subtitle, pause):
  if subtitle[-1] in ["!", ".", "?"]:
    return 30
  if subtitle[-1] == ",":
    return 10
  return 0
  
def pause_feature(subitle, pause):
  if pause > 0:
    return max(10, 10*pause)
  return 0
 
def total_fit(subtitles_and_pauses):
  fit = 0
  #print("Evaluating partition ", subtitles_and_pauses)
  for (subtitle, pause) in subtitles_and_pauses:
    fit += length_feature(subtitle, pause)
    fit += punctuation_feature(subtitle, pause)
    fit += pause_feature(subtitle, pause)
  fit -= len(subtitles_and_pauses) * 10
  #print("Fit is", fit)
  return fit

def get_fit(words, partition):
  subtitles_and_pauses = []
  start = 0
  for split in partition:
    text = " ".join([get_word(word) for word in words[start:split]])
    pause = words[split + 1]["start"]  - words[split]["end"]
    subtitles_and_pauses.append((text, pause))
    start = split
  text = " ".join([get_word(word) for word in words[start:]])
  subtitles_and_pauses.append((text, 1.0))
  return total_fit(subtitles_and_pauses)
    
def split_words(words):
  if len(words) > 10:
    
    best_partitions = [([], get_fit(words, []))]
    
    patience = 10
    
    num_prune = 20
    num_candidate_splits = 3
    num_candidate_merges = 3
    num_candidate_shifts = 10
    
    best_score = -100000
    num_no_increase = 0
    while True:
      generated_partitions = best_partitions[:]
      for current_partition in ([p[0] for p in best_partitions]):
        for i in range(num_candidate_splits):
          new_split = random.randint(1, len(words) - 2)
          if new_split not in current_partition:
            new_partition = sorted(current_partition + [new_split])
            generated_partitions.append((new_partition, get_fit(words, new_partition)))
        for i in range(num_candidate_merges):
          if len(current_partition) > 1:
            new_partition = current_partition[:]
            del new_partition[random.randrange(len(new_partition))]
            generated_partitions.append((new_partition, get_fit(words, new_partition)))
      
        for i in range(num_candidate_shifts):
          if len(current_partition) > 0:
            new_partition = current_partition[:]
            shift_index = random.randrange(len(new_partition))
            if i % 2 == 0:
              new_split = new_partition[shift_index] + random.randint(1, 3)
            else:
              new_split = new_partition[shift_index] - random.randint(1, 3) 
            if new_split not in new_partition and new_split < len(words) - 1 and new_split > 0:
              del new_partition[shift_index]
              new_partition = sorted(new_partition + [new_split])
              generated_partitions.append((new_partition, get_fit(words, new_partition)))
      
      best_partitions = sorted(generated_partitions, key=lambda s: s[1], reverse=True)[0:num_prune]
      
      if best_partitions[0][1] > best_score:
        best_score = best_partitions[0][1]
        num_no_increase = 0
      else:
        num_no_increase += 1
      if num_no_increase > patience:
        return best_partitions[0][0]
  else:
    return []

parser = argparse.ArgumentParser("Converts JSON format to SRT subtitle format, by fuzzily finding optimal split points")
parser.add_argument('json', help="JSON input file")
      
args = parser.parse_args()
      
trans = json.load(open(args.json))

sections = trans["sections"]
j = 1
for section in sections:
  if section["type"] == "speech":
    turns = section.get("turns")
    if turns:
      for turn in turns:
        words = turn.get("words", None)
        if words:
          split_list = split_words(words)
          splits = [0] + split_list + [len(words)]
          for i in range(len(splits) - 1):
            text = " ".join([get_word(word) for word in words[splits[i]:splits[i+1]]])
            start = words[splits[i]]["start"]
            end = words[splits[i+1] - 1]["end"]
                        
            datetime1 = datetime.datetime.utcfromtimestamp(start)
            datetime2 = datetime.datetime.utcfromtimestamp(end)
            print(j)
            print("%s --> %s" % (datetime1.strftime('%H:%M:%S,%f')[:-3], datetime2.strftime('%H:%M:%S,%f')[:-3]))
            print(text)
            print()
            j += 1
