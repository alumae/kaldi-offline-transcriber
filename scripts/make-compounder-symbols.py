#! /usr/bin/env python

from __future__ import print_function
import sys

print("<eps> 0")
i = 1
for w in sys.stdin:
  print(w.strip(), i)
  i += 1
print("<unk>", i)
i+=1
print("+C+", i)
i+=1
print("+D+", i)
i+=1
print("#0", i)
