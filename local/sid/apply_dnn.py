#! /usr/bin/env python3.5

from __future__ import print_function
import argparse
import csv
import pandas
import numpy
from keras.models import load_model
from train_dnn import label_reg_loss
from io import open


def get_speaker_str(speaker_df, row_id):
    return speaker_df.ix[row_id, 0]

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Apply the model")
    parser.add_argument("--confidence-threshold", type=float, default=0.7, 
      help="Posterior probability threshold for confident predictions")
    parser.add_argument("model_file", help="Previously traine model")
    parser.add_argument("dev_spk_file", 
      help="File with dev speaker data (IDs and i-vectors) in CSV format")

    args = parser.parse_args()

    model = load_model(args.model_file, 
                       custom_objects={"label_reg_loss" : label_reg_loss})

    # Load the name table, needed for mapping output IDs of the model
    # to real speaker names
    pruned_name_list = []
    name_ids = {}
    for l in open("%s.names" % args.model_file, "rt", encoding='utf-8'):
      name = l.strip()
      pruned_name_list.append(name)
      name_ids[name] = len(name_ids)
    
    dev_speaker_df = pandas.read_csv(args.dev_spk_file, sep=",", header=None)
    dev_ivecs = dev_speaker_df.ix[:,1:].as_matrix()
    dev_predicted_targets = model.predict_on_batch(dev_ivecs)
    dev_predicted_speakers = (dev_predicted_targets).argmax(axis=1)
    dev_confident_predictions = \
      dev_predicted_targets[numpy.arange(len(dev_predicted_targets)), \
                            dev_predicted_speakers] > args.confidence_threshold
    
    for (i, speaker_id) in enumerate(dev_predicted_speakers):
          print(u"%s %f %s " % \
            (get_speaker_str(dev_speaker_df, i), \
             dev_predicted_targets[i, speaker_id], \
             pruned_name_list[speaker_id]))

