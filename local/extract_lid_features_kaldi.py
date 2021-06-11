#! /usr/bin/env python
import logging
import sys
import argparse
import kaldiio
import os.path
import torch
import torchaudio
from speechbrain.pretrained import EncoderClassifier



if __name__ == '__main__':
  logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)
  parser = argparse.ArgumentParser(description="Extract LID features from utterances")
  parser.add_argument("--use-gpu", default=False, action='store_true')
  parser.add_argument("datadir")
  parser.add_argument("outdir")

  args = parser.parse_args()

  if args.use_gpu:
    device = "cuda"
  else:
    device = "cpu"

  torch.set_num_threads(1)
  language_id = EncoderClassifier.from_hparams(source="TalTechNLP/voxlingua107-epaca-tdnn",  run_opts={"device": device})  

  write_helper = kaldiio.WriteHelper(f'ark,scp:{args.outdir}/xvector.ark,{args.outdir}/xvector.scp')

  segment_file = f'{args.datadir}/segments'
  if os.path.isfile(segment_file):
    segments = segment_file
  else:
    segments = None
  with kaldiio.ReadHelper(f'scp:{args.datadir}/wav.scp', segments=segments) as reader:
    for key, (rate, numpy_array) in reader:
      logging.debug(f"Computing embeddings for utterance {key}")
      torch_array = torch.from_numpy(numpy_array)
      emb = language_id.encode_batch(torch_array)
      
      write_helper(key, emb.squeeze().cpu().numpy())
