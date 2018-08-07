#! /usr/bin/env python

from __future__ import print_function
import sys
import io
import codecs
import argparse
from subprocess import Popen, PIPE

if __name__ == '__main__':

  parser = argparse.ArgumentParser(description='Convert phone representation to words')
  parser.add_argument('--p2g-cmd', default=None)
  args = parser.parse_args()

  
  p2g_proc = Popen(args.p2g_cmd, shell=True, stdin=PIPE, stdout=PIPE)

  input_stream = io.TextIOWrapper(sys.stdin.buffer, encoding='utf-8')

  p2g_stream = io.TextIOWrapper(p2g_proc.stdout, encoding='utf-8')

  # Following is needed to avoid line buffering
  while 1:
    l = input_stream.readline() 
    
    phones_str = " ".join([p.partition("_")[0] for p in l.split()])
    p2g_proc.stdin.write((phones_str + "\n").encode("utf-8"))
    print(">>> ", phones_str, file=sys.stderr)
    p2g_proc.stdin.flush()
    result = p2g_stream.readline()
    word = result.split()[1]
    print("<<< ", word, file=sys.stderr)

    

    print(word)
    sys.stdout.flush()
