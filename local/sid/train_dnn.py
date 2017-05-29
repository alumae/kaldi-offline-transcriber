#! /usr/bin/env python3.5

from __future__ import print_function
import argparse
import csv
import pandas
import random
import numpy
from keras import backend as K
from keras.models import Sequential
from keras.layers import Dense, Dropout
from collections import Counter, OrderedDict

# Label regularization loss, according to Keras API
# Actually, our y_true is 1D, containing prior probabilities for
# our labels. But Keras API wants it to be a 2D array of shape 
# (batch_size, num_classes)
# So, we expand it to 2D when calling train_on_batch (see below) and 
# just take a mean
# in this function
def label_reg_loss(y_true, y_pred):
  # KL-div
  y_true = K.clip(y_true, K.epsilon(), 1)
  y_pred = K.clip(y_pred, K.epsilon(), 1)

  y_true_mean = K.mean(y_true, axis=0)
  y_pred_mean = K.mean(y_pred, axis=0)
  return K.sum(y_true_mean * K.log(y_true_mean / y_pred_mean), axis=-1)


  

if __name__ == '__main__':
  random.seed(42)
  
  parser = argparse.ArgumentParser(description="Train a DNN")
  parser.add_argument("--save-model", default=None) 
  parser.add_argument("--min-spk-occ", default=5, type=int, 
    help="Keep speaker names that occur at least in that many shows")
  parser.add_argument("--num-epochs", type=int, default=20, 
    help="Number of epochs to train")
  parser.add_argument("--num-dev-shows", default=10, type=int,       
    help="Number of dev shows for validation")
  parser.add_argument("--confidence-threshold", type=float, default=0.7, 
    help="Posterior probability threshold for confident predictions")
  parser.add_argument("spk_file", 
    help="File speaker data (IDs and i-vectors) in CSV format")
  parser.add_argument("meta_file", help="Metadata file CSV format")

  args = parser.parse_args()

  metadata_df = pandas.read_csv(args.meta_file, sep=";", encoding='utf-8-sig')
  speaker_df = pandas.read_csv(args.spk_file, sep=",", header=None)

  # Dictionary that maps show ID to a set of names who appear in it
  show2names = OrderedDict()
  # Reverse to above: speaker name -> set of show IDs
  name2shows = OrderedDict()

  for index, row in metadata_df.iterrows():
    names_val = row['esinejad']
    if not pandas.isnull(names_val):
      names = set([s.strip() for s in names_val.split(",")])
      if len(names) > 0:
        show2names[row['id']] = names
        for name in names:
          name2shows.setdefault(name, set()).add(row['id'])
  
  
  # keep names that occur at least args.min_spk_occ times across all shows
  pruned_name2shows = \
    {name: shows for name, shows in name2shows.items() \
     if len(shows) >= args.min_spk_occ}
  print("%s speakers left after pruning" % len(pruned_name2shows))

  # pruned_name_list is a list of all names left after pruning, plus <unk>
  # name_ids is a dict that maps names to their indexes in pruned_name_list
  pruned_name_list = []
  pruned_name_list = ["<unk>"]
  pruned_name_list.extend(sorted(pruned_name2shows.keys()))
  name_ids = {}
  for name in pruned_name_list:
    name_ids[name] = len(name_ids)

  # keep only the ivectors that are from a show that has name data
  valid_speaker_df = \
    speaker_df[speaker_df[0].isin(show2names.keys())].reset_index(drop=True)

  # name_ids_in_shows is a dict that maps show IDs to sets that contain 
  # all name IDs in that show, with a special ID for <unk> for 
  # pruned-out speakers
  name_ids_in_shows = {}
  unk_count_in_shows = Counter()
  for show, names in show2names.items():
    name_ids_in_show = set()
    for name in names:
      if name in name_ids:
        name_ids_in_show.add(name_ids[name])
      else:
        #unk_count_in_shows[show] += 1
        unk_count_in_shows[show] = 1
    name_ids_in_shows[show] = name_ids_in_show

  ivecs = valid_speaker_df.ix[:,3:].as_matrix()

  # Create a DNN
  model = Sequential()
  model.add(Dense(512, activation='relu', input_shape=(ivecs.shape[1],)))
  model.add(Dropout(0.2))
  model.add(Dense(512, activation='relu'))
  model.add(Dropout(0.2))
  model.add(Dense(len(name_ids), activation='softmax'))
  model.compile(optimizer='sgd', loss=label_reg_loss)

  print("Model summary")
  print(model.summary())

  
  valid_show_ids = random.sample(show2names.keys(), k=args.num_dev_shows)
  print(valid_show_ids)
  # Compute oracle coverage
  names_in_valid_shows = []
  for show in valid_show_ids:
    names_in_valid_shows.extend(show2names[show])
  coverage = 1.0 * sum([(name in pruned_name_list) for name in names_in_valid_shows]) / len(names_in_valid_shows)
  print("Oracle name coverage on dev data: %f" % coverage)

  def validate(model):
    tp = 0
    fp = 0
    fn = 0
    for show in valid_show_ids:
      dev_ivecs = valid_speaker_df[valid_speaker_df[0] ==show].ix[:,3:].as_matrix()
      true_speakers = set(show2names[show])
      dev_predicted_target_probs = model.predict_on_batch(dev_ivecs)
      dev_predicted_speaker_ids = (dev_predicted_target_probs).argmax(axis=1)

      predicted_speakers = set()
      for (i, dev_predicted_speaker_id) in enumerate(dev_predicted_speaker_ids):
        if dev_predicted_speaker_id != name_ids["<unk>"] and \
           dev_predicted_target_probs[i, dev_predicted_speaker_id] > args.confidence_threshold:
          predicted_speakers.add(pruned_name_list[dev_predicted_speaker_id])
      tp += len(predicted_speakers & true_speakers)
      fp += len(predicted_speakers - true_speakers)
      fn += len(true_speakers - predicted_speakers)
    print("Recall: %f, precision: %f" % (1.0 * tp / (tp + fn), 1.0 * tp / (tp + fp)))
    

  for epoch in range(args.num_epochs):
    # Train the DNN, show-by-show
    for show, names in random.sample(show2names.items(), k=len(show2names)):
      if show not in valid_show_ids:
        ivecs_for_show = \
          valid_speaker_df[valid_speaker_df[0] == show].ix[:,3:].as_matrix()
        # Label proportions: uniform over the names in that show
        label_props_for_show = numpy.zeros((len(name_ids)))
        label_props_for_show[list(name_ids_in_shows[show])] = \
          1.0 / (len(name_ids_in_shows[show]) + unk_count_in_shows[show])
        label_props_for_show[name_ids["<unk>"]] = \
          unk_count_in_shows[show] / (len(name_ids_in_shows[show]) + unk_count_in_shows[show])
        # Expand label proportions, because Keras needs labels
        # to be of the same length as the minibatch
        # We will later un-expand it in the cost function
        label_props_expanded = numpy.repeat(
          label_props_for_show.reshape(1,-1), 
          len(ivecs_for_show), axis=0)
        model.train_on_batch(ivecs_for_show, label_props_expanded)
    print("Finished epoch %d" % epoch)
    validate(model)

  print("Finished training")
  
  if args.save_model:
    model.save(args.save_model)
    print("Saved model to %s" % args.save_model)
    with open("%s.names" % args.save_model, "wt", encoding='utf-8') as f:
      for name in pruned_name_list:
        print(name, file=f)
        

