import sys

print "<eps> 0"
i = 1
for w in sys.stdin:
  print w.strip(), i
  i += 1
print "<unk>", i
i+=1
print "<space>", i
i+=1
print "+C+", i
i+=1
print "+D+", i
i+=1
