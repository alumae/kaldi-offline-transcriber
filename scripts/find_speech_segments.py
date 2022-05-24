import sys
import logging
import argparse
import torch
torch.set_num_threads(1)

import os
from pathlib import Path

if __name__ == '__main__':
  logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)
  parser = argparse.ArgumentParser()  
  parser.add_argument("--sample-rate", default=16000, type=int)  
  parser.add_argument("--collar", default=1.0, type=float)  
  parser.add_argument("wav")  
  parser.add_argument("out_uem")
  args = parser.parse_args()
  
  
  USE_ONNX = False # change this to True if you want to test onnx model
  
  model, utils = torch.hub.load(repo_or_dir='snakers4/silero-vad',
                                model='silero_vad',
                                force_reload=False,
                                onnx=USE_ONNX)

  (get_speech_timestamps,
   save_audio,
   read_audio,
   VADIterator,
   collect_chunks) = utils
   
  wav = read_audio(args.wav, sampling_rate=args.sample_rate)
  
  assert len(wav.shape) == 1
  
  num_frames = len(wav)
  
  speech_timestamps = get_speech_timestamps(wav, model, sampling_rate=args.sample_rate)
  
  collar_in_samples = int(args.collar * args.sample_rate)
  
  current_segment = None
  result = []
  for segment in speech_timestamps:
    start = max(segment["start"] - collar_in_samples, 0)
    end = min(segment["end"] + collar_in_samples, num_frames)
    if current_segment is not None:
      if current_segment[1] > start:
        current_segment = (current_segment[0], end)
      else:
        result.append(current_segment)
        current_segment = (start, end)
    else:
      current_segment = (start, end)
  
  if current_segment is not None:
    result.append(current_segment)
  
  stem = Path(args.wav).stem
  step_size = args.sample_rate//100
  with open(args.out_uem, "w") as f:
    for segment in result:
      print(f"{stem} 1 {segment[0]//step_size} {(segment[1]-segment[0])//step_size} U U U 1", file=f)
  
