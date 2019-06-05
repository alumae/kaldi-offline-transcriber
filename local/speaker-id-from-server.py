#! /usr/bin/env python3

import argparse
import requests
import json
import sys

from urllib3.filepost import encode_multipart_formdata, choose_boundary
from urllib3.fields import RequestField
import subprocess

def encode_multipart_related(fields, boundary=None):
  if boundary is None:
    boundary = choose_boundary()

  body, _ = encode_multipart_formdata(fields, boundary)
  content_type = str('multipart/related; boundary=%s' % boundary)

  return body, content_type

def encode_media_related(audio_files):
  rfs = []
  for f in audio_files:
    if f.endswith("|"):
      p = subprocess.Popen(f[:-1], shell=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=False)
      data = p.stdout.read()
      rf = RequestField(
          name='placeholder2',
          data=data,
          headers={'Content-Type': "audio/wav"},
      )
    else:
      rf = RequestField(
          name='placeholder2',
          data=open(f, 'rb').read(),
          headers={'Content-Type': "audio/wav"},
      )
    rfs.append(rf)
  return encode_multipart_related(rfs)



if __name__ == "__main__":

  
  parser = argparse.ArgumentParser(description='Perform speaker ID using a dedicated server')

  parser.add_argument('--url', default="http://localhost:8888")
  parser.add_argument('spk2utt')
  parser.add_argument('wav_scp')
  parser.add_argument('output_json')

  args = parser.parse_args()
  
  wavs = {}
  for l in open(args.wav_scp):
    ss = l.split()
    wavs[ss[0]] = " ".join(ss[1:])
  
  
  spk2utt = {}
  for l in open(args.spk2utt):
    ss = l.split()
    spk2utt[ss[0]] = [wavs[utt] for utt in ss[1:]]
    
  output = {}
  
  for speaker, wavs in spk2utt.items():
    body, content_type = encode_media_related(wavs)
    full_url = args.url + "/v1/identify?uploadType=multipart"
    try:
      print("Doing speaker ID for speaker %s using URL %s" % (speaker, full_url), file=sys.stderr)
      r = requests.post(full_url, data=body, headers={"Content-Type": content_type})
      if r.status_code == 200:
        speaker_info = json.loads(r.content.decode("utf-8"))
        output[speaker] = speaker_info
        print("Speaker ID successful, speaker info: " + str(speaker_info), file=sys.stderr)
      else:
        print("Speaker ID not successful, status %d " % r.status_code, file=sys.stderr)
        output[speaker] = {}
    except Exception as ex:
      print("Failed to do speaker ID using server URL %s" % full_url, file=sys.stderr)
      print(ex,  file=sys.stderr)
      output[speaker] = {}
      
  json.dump(output, open(args.output_json, "w"), sort_keys=False, indent=4)
    

  
