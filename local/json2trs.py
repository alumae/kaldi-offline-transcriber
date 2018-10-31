#! /usr/bin/env python3
import random
import json
import sys
import datetime
import os.path
import argparse

def print_header(filename):
  now = datetime.datetime.now()
  print('<?xml version="1.0" encoding="UTF-8"?>')
  print('<!DOCTYPE Trans SYSTEM "trans-14.dtd">')
  print('<Trans scribe="est-speech2txt" audio_filename="'+ filename+ '" version="1" version_date="' + now.strftime("%y%m%d") + '">')
    
    
def print_footer():
  print('</Episode>')
  print('</Trans>')
    
def print_speakers(speakers):
  print("<Speakers>")
  i = 1
  for speaker_id, speaker in speakers.items():
    default_speaker_name = "K%02d" % i    
    print('<Speaker id="%s" name="%s" check="no" dialect="native" accent="" scope="local" type="male"/>' % (speaker_id, speaker.get("name", default_speaker_name)))
    i += 1
  print("</Speakers>")
  print('<Episode>')
        

def print_sections(sections):
  for section in sections:
    section_type = section["type"]     
    
    if section_type == "speech":
      print('<Section type="%s" startTime="%0.3f" endTime="%0.3f">' % ("report", section["start"], section["end"]))
      for turn in section.get("turns", []):
      
        print('<Turn speaker="%s" startTime="%0.3f" endTime="%0.3f">' % (turn["speaker"], turn["start"], turn["end"]))
        print(turn["transcript"])
        print('</Turn>')
      print('</Section>')
    elif section_type == "non-speech":
      print('<Section type="%s" startTime="%0.3f" endTime="%0.3f">' % ("filler", section["start"], section["end"]))

parser = argparse.ArgumentParser("Converts JSON format to Transcriber trs")
parser.add_argument('--fid', default="unknown", help="File id to be used in trs header")
parser.add_argument('json')

args = parser.parse_args()

trans = json.load(open(args.json))

print_header(args.fid)
print_speakers(trans["speakers"])
print_sections(trans["sections"])
print_footer()

