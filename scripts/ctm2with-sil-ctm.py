#! /usr/bin/env python

from __future__ import print_function
import sys

last_file_id = ""
last_end_time = 0.0

for l in sys.stdin:
  ss = l.split()
  file_id = ss[0]
  word = ss[4]
  start_time = float(ss[2])
  end_time = start_time + float(ss[3])
  if word == "<sil>":
    continue
  if file_id == last_file_id and last_file_id != "" and start_time - last_end_time > 0.0001:
    print("%s 1 %0.3f %0.3f <sil=%0.3f>" % (file_id, last_end_time, start_time - last_end_time, start_time - last_end_time))
  print(l,)
  last_end_time = end_time
  last_file_id = file_id
  
    
  

