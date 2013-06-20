#! /usr/bin/python
'''
Created on Apr 4, 2012

@author: tanel
'''

import sys
import datetime
import re

for l in sys.stdin:
    
    m = re.match("^(.*) \((.*)_(\d+\.\d+)[-_](\d+\.\d+)_(\S+)(\s+\S+)?\)$", l)
    if m:
        content = m.group(1)
        filename = m.group(2)
        starttime = float(m.group(3))
        endtime = float(m.group(4))
        speaker =m.group(5)
        datetime1 = datetime.datetime.utcfromtimestamp(starttime)
        datetime2 = datetime.datetime.utcfromtimestamp(endtime)
        print "%s,%s" % (datetime1.strftime('%H:%M:%S.%f'), datetime2.strftime('%H:%M:%S.%f'))
        print content
        print 
        
    else:
        raise Exception("cannot process line: " + l)
