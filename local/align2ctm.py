#! /usr/bin/env python

import sys
import argparse
from subprocess import Popen, PIPE

if __name__ == '__main__':

  parser = argparse.ArgumentParser(description='Convert aligned output to CTM')
  parser.add_argument('--frame-shift', default=0.01, type=float)
  parser.add_argument('--unk-word', default="<unk>")
  parser.add_argument('--unk-p2g-cmd', default="")
  args = parser.parse_args()

  unk_p2g_proc = None
  if args.unk_p2g_cmd != "":
    unk_p2g_proc = Popen(args.unk_p2g_cmd, shell=True, stdin=PIPE, stdout=PIPE)

  for l in sys.stdin:
    ss = l.split()
    start_frame = int(ss[1])
    num_frames = int(ss[2])
    word = ss[4]
    phones_str = " ".join(ss[5:])

    if word == args.unk_word and unk_p2g_proc:
      unk_p2g_proc.stdin.write((phones_str + "\n").encode('utf-8'))
      unk_p2g_proc.stdin.flush()
      word = unk_p2g_proc.stdout.readline().strip().decode('utf-8')
      #word = "[%s]" % word

    if word != "<eps>":
      print("%s 1 %0.2f %0.2f %s" % (ss[0], start_frame * args.frame_shift, num_frames * args.frame_shift, word))


