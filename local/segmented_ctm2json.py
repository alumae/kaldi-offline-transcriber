#! /usr/bin/env python3

import sys
import argparse
import simplejson as json
import re
from collections import OrderedDict
from decimal import Decimal

def get_turn(start, speaker_id, sections, speakers, new_turn_sil_length):
  if speaker_id not in speakers:
    speakers[speaker_id] = {}
    
  current_section = None
  for section in sections:
    if section["type"] == "speech":
      if section["start"] <= start and section["end"] > start:
        current_section = section
        break
  if current_section is None:
    raise Exception("No speech section for word starting at %.3f" % start)
  turns = section.setdefault("turns", [])
  if len(turns) == 0 or turns[-1]["speaker"] != speaker_id or turns[-1]["end"] + new_turn_sil_length < start:
    turns.append({"speaker" : speaker_id, "start" : start, "end" : start, "transcript" : "", "words" : []})
    
  return turns[-1]

parser = argparse.ArgumentParser("Converts (segmented) CTM to dedicated JSON format")
parser.add_argument('--new-turn-sil-length', default="2.0", type=Decimal, help="Length of silence in seconds, from which a new turn is created")
parser.add_argument('--speech-padding', default="0.25", type=Decimal, help="Speech segments are padded by this amount")
parser.add_argument('--pms-seg', help="The pms (speech/non-speech segmentation) file from diarization")
parser.add_argument('--speaker-names', help="File in JSON format that maps speaker IDs to speaker info (usually just name name)")
parser.add_argument('segmented_ctm')

args = parser.parse_args()

result = OrderedDict()

sections = []


if args.pms_seg:
  for l in open(args.pms_seg):
    ss = l.split()
    start = Decimal(int(ss[2]) / Decimal(100.0))
    end = start + Decimal(int(ss[3]) / Decimal(100.0))
    if ss[7] == 'speech':
      kind = 'speech'
      if (start > 0.0):
        start -=  args.speech_padding
      end +=  args.speech_padding
    else:
      kind = 'non-speech'
      if (start > 0.0):
        start +=  args.speech_padding
      end -=  args.speech_padding
    
    if start < end:
      sections.append({"type" : kind, "start" : start, "end" : end})
else:
  sections.append({"type" : "speech", "start" : Decimal(0.0), "end" : Decimal(99999)})
  
sections = sorted(sections, key=lambda s: s["start"])
 
speakers = {}

p = re.compile(r'(?:.*\/)?(.+)_(\d+.\d{3})[_-](\d+.\d{3})_([^_]+)$')
for l in open(args.segmented_ctm):
  ss = l.split()
  m = p.match(ss[0])
  if m:
    file_id = m.group(1)
    speaker_id = m.group(4)  
    segment_start = Decimal(m.group(2))
    segment_end = segment_start + Decimal(m.group(3))
    word_start = segment_start + Decimal(ss[2])
    word_end = word_start + Decimal(ss[3])
    word = ss[4]
    word_dict = OrderedDict([("word", word), ("start", word_start), ("end", word_end)])
    if len(ss) > 5:
      word_dict["confidence"] = Decimal(ss[5])
    turn = get_turn(word_start, speaker_id, sections, speakers, args.new_turn_sil_length)
    #print(turn)
    turn["words"].append(word_dict)
    turn["end"] = word_end
  else:
    raise Exception("Cannot parse line utt id: %s" % ss[0])

for section in sections:
  if "turns" in section:
    for (i, turn) in enumerate(section["turns"]):
      turn["transcript"] = " ".join([w["word"] for w in turn["words"]])
      # extend turn end time to the next turn, to avoid gaps between turns
      if i < len(section["turns"]) - 1:
        turn["end"] = section["turns"][i+1]["start"]
      

if not args.pms_seg:
  if "turns" in sections[0]:
    sections[0]["end"] = sections[0]["turns"][-1]["end"]

if args.speaker_names:
  speakers.update(json.load(open(args.speaker_names)))
  

result['speakers'] = speakers
result['sections'] = sections

print(json.dumps(result, sort_keys=False, indent=4))
