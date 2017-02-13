#! /usr/bin/env python

from __future__ import print_function
import sys
import re
import argparse
import datetime
import codecs

def print_header(filename):
  now = datetime.datetime.now()
  print('<?xml version="1.0" encoding="UTF-8"?>')
  print('<!DOCTYPE Trans SYSTEM "trans-14.dtd">')
  print('<Trans scribe="est-speech2txt" audio_filename="'+ filename+ '" version="1" version_date="' + now.strftime("%y%m%d") + '">')
    
    
def print_footer():
  print('</Episode>')
  print('</Trans>')
    
def print_speakers(speakers, speaker_table):
  print("<Speakers>")
  i = 1
  for v in sorted(speakers.values()):
    speaker_name = speaker_table.get(v)
    print('<Speaker id="%s" name="%s" check="no" dialect="native" accent="" scope="local" type="male"/>' % (v, speaker_name))
    i += 1
  print("</Speakers>")
  print('<Episode>')
        

def print_sections(sections):
  for i in range(len(sections)):
    section_type, turns = sections[i]
    starttime = turns[0][1][0][0]
    endtime = turns[-1][1][-1][1]
    if i < len(sections) - 1 and endtime > sections[i+1][1][0][1][0][0]:
      # do not allow endtime to overlap
      print("Adjusting section end from %f to to %f" % (turns[-1][1][-1][1], sections[i+1][1][0][1][0][0]), file=sys.stderr)
      endtime = sections[i+1][1][0][1][0][0]
    
    if section_type == "report":
      print('<Section type="%s" startTime="%s" endTime="%s"' % (section_type, starttime, endtime), end='')
      print('>')
      for (speaker, turn) in turns:
        turn_endtime =  turn[-1][1]
        if turn_endtime > endtime:
          turn_endtime = endtime
        print('<Turn speaker="%s" startTime="%s" endTime="%s">' % (speaker, turn[0][0], turn_endtime))
        for line in turn:
          #print line[2]
          print('<Sync time="%s"/>' % line[0])
          content = line[2]
          print(" ".join(content))
        print('</Turn>')
      print('</Section>')
    elif section_type in ["filler", "nontrans"]:
      print('<Section type="%s" startTime="%s" endTime="%s"' % (section_type, starttime, endtime), end='')
      print('>')
      
      for _, turn in turns:
        turn_endtime =  turn[-1][1]
        if turn_endtime > endtime:
          turn_endtime = endtime
        print('<Turn startTime="%s" endTime="%s">' % (turn[0][0], endtime))
        for event in turn:
          print('<Event desc="%s" type="%s" extent="instantaneous"/>' % (event[2], event[3]))
        print('</Turn>')
      print('</Section>')

def titlecase(s):
    return re.sub(re.compile(r"[\w]+('[\w]+)?", flags=re.UNICODE),
                  lambda mo: mo.group(0)[0].upper() +
                             mo.group(0)[1:].lower(),
                  s)


if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='Convert hyp to trs file')
  parser.add_argument('-s', '--sid', help='Speaker ID file, with lines in format <speaker_code> <speaker full name>')
  parser.add_argument('--fid', default="unknown", help="File id to be used in trs header")
  parser.add_argument('--pms', help="File with speech/non-speech segmentation")
  args = parser.parse_args()
  

  speaker_realnames = {}
  if args.sid:
    print("Using %s for speaker ID" % args.sid, file=sys.stderr)
    for l in codecs.open(args.sid, "r", "utf-8"):
      fields = l.split(None, 1)
      speaker_realnames[fields[0]] = fields[1].strip()
  
  # list of triples (start, length, speech/music/jingle)
  pms_seg = []
  if args.pms:
    print("Reading speech/music/jingle segmentation from %s" % args.pms, file=sys.stderr)
    for l in open(args.pms):
      fields = l.split()
      pms_seg.append((float(fields[2])/100, float(fields[3])/100, fields[7]))
  
  sections = []
  
  for seg in pms_seg:
    if seg[2] in ['music', 'jingle']:
      turns = [("foo", [(seg[0], seg[0] + seg[1], seg[2], "noise")])]
      sections.append(("filler", turns))
  
  last_speaker_id = ""
  last_end_time = -1.0
  
  speakers = {}
  num_speakers = 0
  speaker_table = {}
  
  do_uppercase = True
  
  while 1:
    l = sys.stdin.readline()
    if not l: break
    words = l.split()
    for word in words:
      if word.startswith("<") and "start=" in word:
        start_time = float(re.match(r".*start=(\d+(\.\d+)?)", word).group(1))
        end_time = float(re.match(r".*end=(\d+(\.\d+)?)", word).group(1))
        speaker_id = re.match(r".*speaker=(\w+)", word).group(1)

        if not (speaker_id in speakers):
          speaker_code = "S%d" % (num_speakers + 1)
          speakers[speaker_id] = speaker_code
          speaker_table[speaker_code] = speaker_realnames.get(speaker_id, "K%d" % (num_speakers + 1))
          num_speakers += 1
        
        if abs(start_time != last_end_time) > 0.001:
          turns = []
          sections.append(("report", turns))
          last_speaker_id = ""
        
        if speaker_id != last_speaker_id:
          turn = []
          turns.append((speakers[speaker_id], turn))
        
        content = []
        line = (start_time, end_time, content)
        turn.append(line)
        last_end_time = end_time
        last_speaker_id = speaker_id
      else:
        if do_uppercase:
          content.append(titlecase(word))
        else:
          content.append(word)
        do_uppercase = word.endswith(".")
          
  
  sections.sort(key=lambda turns: turns[1][0][1][0][0])  
  
     
  print_header(args.fid)
  print_speakers(speakers, speaker_table)        
  print_sections(sections)
  print_footer()  

    
