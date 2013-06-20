import sys


sentences = {}

for l in sys.stdin:
  if not l.startswith("#"):
    ss = l.split()
    sent_id = ss[0]
    word = ss[4]
    sentences[sent_id] = sentences.get(sent_id, []) + [word]

for sent_id in sorted(sentences):
  print "%s (%s)" % (" ".join(sentences[sent_id]), sent_id)
