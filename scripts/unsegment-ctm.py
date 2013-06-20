'''
Created on Oct 15, 2010

@author: tanel
'''

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
				
			start = float(m.group(2))
			word = ss[4]
			score = "1"
			if len(ss) > 5:
					score = ss[5]
			if last_segment_id != "" and segment_id != last_segment_id:
				print file_id, "1", float(ss[2]) + start, 0, "<#s>", "1"
				
			print file_id, "1", float(ss[2]) + start, ss[3], word, score
			last_segment_id = segment_id
		else:
			print >> sys.stderr, "Cannot parse: ", ss[0]
		
