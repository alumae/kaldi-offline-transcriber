#! /usr/bin/env python

'''
Created on May 21, 2010

@author: tanel
'''
from __future__ import print_function

import os, sys, re
from subprocess import Popen, PIPE

def process_sentence(proc, sent):
    if (len(sent)) > 0:
        if sent[0][2] == "<s>":
            sent.pop(0)
        if sent[-1][2] == "</s>":
            sent.pop()
        
        text = " ".join([ww[2] for ww in sent]) + "\n"
        #print "before: ", text
        
        proc.stdin.write(text.encode('utf-8'))
        proc.stdin.flush()
        text = proc.stdout.readline().decode('utf-8')
        #print "after:  ", text
        words = text.split()
        if len(words) == 0:
            return
        if words[0] in ["+C+", "+D+"]:
            words = words[1:]
        if words[-1] in ["+C+", "+D+"]:
            words = words[0:-1]
            
        
        i_orig = 0
        i_new = 0
        result = []
        while i_new < len(words):
            new_word = words[i_new]
            new_start = sent[i_orig][0]
            new_dur = sent[i_orig][1]
            new_confidence = sent[i_orig][3]
            new_id = sent[i_orig][4]
            while (i_new + 1 < len(words)) and (words[i_new + 1] in ["+C+", "+D+"] or words[i_new + 1].startswith("_")):
                #append next word
                if (words[i_new + 1] == "+C+"):
                    new_word = new_word + "+" + words[i_new + 2]                    
                    i_new +=  2
                    i_orig += 1
                elif (words[i_new + 1] == "+D+"):
                    new_word = new_word + "-" + words[i_new + 2]
                    i_new +=  2
                    i_orig += 1                    
                else:
                    new_word += words[i_new + 1][1:]
                    i_new +=  1
                    i_orig += 1
                    
                new_dur = sent[i_orig][0] + sent[i_orig][1] - new_start 
                new_confidence = min(new_confidence, sent[i_orig][3])
                
            i_new += 1
            i_orig += 1
            new_word = new_word.replace("_", "")
            result.append((new_start, new_dur, new_word, new_confidence, new_id))
        
        for r in result:
            print("%s 1 %0.3f %0.3f %s %0.2f" % (r[4].replace("-", "_"), r[0], r[1], r[2], r[3]))
        

if __name__ == '__main__':
    cmd = sys.argv[1]
    proc = Popen(cmd, shell=True, stdin=PIPE, stdout=PIPE)
    
    sent = []
    last_id = ""
    
    for l in sys.stdin:

        if sys.version_info >= (3, 0):
            ss = l.split()
        else:
            ss = l.decode('utf-8').split()
        id = ss[0]
        channel = ss[1]
        start = float(ss[2])
        duration = float(ss[3])
        word = ss[4]
        if len(ss) > 5:
            confidence = float(ss[5])
        else:
            confidence = 1.0
        if id != last_id:
            process_sentence(proc, sent)
            sent = []
        if (word == "<#s>"):
            word = "</s>"
        if (word == "<filler>"):
            continue            
        sent.append((start, duration, word, confidence, id))
        if (word == "</s>"):
            process_sentence(proc, sent)
            sent = []
            
        last_id = id
    process_sentence(proc, sent)
    
        
