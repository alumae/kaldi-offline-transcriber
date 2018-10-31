#! /usr/bin/env python
'''
Created on Oct 15, 2010

@author: tanel
'''

from __future__ import print_function
import sys
import re


if __name__ == '__main__':
  p = re.compile(r'(?:.*\/)?(.+)_(\d+.\d{3})[_-](\d+.\d{3})_([^_]+)$')
  last_segment_id = ""
  for l in sys.stdin:
    ss = l.split()
    m = p.match(ss[0])
    if m:
      segment_id = "%s_%s" % (m.group(1), m.group(2))  
    
      file_id = m.group(1)
      
      speaker_id = m.group(4)  
      start = float(m.group(2))
      end = float(m.group(3))
      
      word = ss[4]
      score = "1"
      if len(ss) > 5:
          score = ss[5]

      if segment_id != last_segment_id:
        print("%s 1 %0.3f %0.3f %s %s" % (file_id, float(ss[2]) + start, 0, "<start=%f,end=%f,speaker=%s>" % (start, end, speaker_id), "1"))

      print("%s 1 %0.3f %0.3f %s %s" % (file_id, float(ss[2]) + start, float(ss[3]), word, score))
      last_segment_id = segment_id
    else:
      print("Cannot parse: ", ss[0], file=sys.stderr)
    
