#!/bin/bash
# Copyright Johns Hopkins University (Author: Daniel Povey) 2012.  Apache 2.0.

# This script produces CTM files from a decoding directory that has lattices
# present.


# begin configuration section.
cmd=run.pl
stage=0
frame_shift=0.01
min_lmwt=5
max_lmwt=20
use_segments=true # if we have a segments file, use it to convert
                  # the segments to be relative to the original files.
print_silence=false
unk_p2g_cmd=
unk_word=
#end configuration section.

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh
. parse_options.sh || exit 1;

if [ $# -ne 3 ]; then
  echo "Usage: $0 [options] <data-dir> <lang-dir|graph-dir> <decode-dir>"
  echo " Options:"
  echo "    --cmd (run.pl|queue.pl...)      # specify how to run the sub-processes."
  echo "    --stage (0|1|2)                 # start scoring script from part-way through."
  echo "    --use-segments (true|false)     # use segments and reco2file_and_channel files "
  echo "                                    # to produce a ctm relative to the original audio"
  echo "                                    # files, with channel information (typically needed"
  echo "                                    # for NIST scoring)."
  echo "    --frame-shift (default=0.01)    # specify this if your lattices have a frame-shift"
  echo "                                    # not equal to 0.01 seconds"
  echo "e.g.:"
  echo "$0 data/train data/lang exp/tri4a/decode/"
  echo "See also: steps/get_train_ctm.sh"
  exit 1;
fi

data=$1
lang=$2 # Note: may be graph directory not lang directory, but has the necessary stuff copied.
dir=$3

basedir=$(dirname "$0")

model=$dir/../final.mdl # assume model one level up from decoding dir.


for f in $lang/words.txt $model $dir/lat.1.gz; do
  [ ! -f $f ] && echo "$0: expecting file $f to exist" && exit 1;
done

name=`basename $data`; # e.g. eval2000

mkdir -p $dir/scoring/log

if [ $stage -le 0 ]; then
  if [ -f $data/segments ] && $use_segments; then
    f=$data/reco2file_and_channel
    [ ! -f $f ] && echo "$0: expecting file $f to exist" && exit 1;
    filter_cmd="utils/convert_ctm.pl $data/segments $data/reco2file_and_channel"
  else
    filter_cmd=cat
  fi

  nj=$(cat $dir/num_jobs)
  lats=$(for n in $(seq $nj); do echo -n "$dir/lat.$n.gz "; done)

  if [ -f $lang/phones/word_boundary.int ]; then
  
	# first, get one best lattice
    $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring/log/get_ctm1.LMWT.log \
      set -o pipefail '&&' mkdir -p $dir/score_LMWT/ '&&' \
      lattice-1best --lm-scale=LMWT "ark:gunzip -c $lats|" ark:$dir/score_LMWT/$name.1best.lat
     
    # second, get CTM with confidences
    $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring/log/get_ctm2.LMWT.log \
      set -o pipefail '&&' mkdir -p $dir/score_LMWT/ '&&' \
      lattice-align-words $lang/phones/word_boundary.int $model "ark:gunzip -c $lats|" ark:- \| \
      lattice-to-ctm-conf --frame-shift=$frame_shift --decode-mbr=false --inv-acoustic-scale=LMWT \
        ark:- "ark:lattice-best-path ark:$dir/score_LMWT/$name.1best.lat ark:- |" $dir/score_LMWT/$name.tmp1.ctm || exit 1;
    
    # third, get CTM with UNKs decoded  
    $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring/log/get_ctm3.LMWT.log \
      set -o pipefail '&&' mkdir -p $dir/score_LMWT/ '&&' \
      lattice-align-words $lang/phones/word_boundary.int $model ark:$dir/score_LMWT/$name.1best.lat ark:- \| \
      lattice-arc-post --acoustic-scale=0.1 $model ark:- - \| \
      utils/int2sym.pl -f 5 $lang/words.txt \| \
      utils/int2sym.pl -f 6-  $lang/phones.txt \| \
      python3 ${basedir}/align2ctm.py --unk-p2g-cmd "$unk_p2g_cmd" --unk-word \'$unk_word\' --frame-shift $frame_shift \
      '>' $dir/score_LMWT/$name.tmp2.ctm || exit 1;

	# fourth, join the two CTMs generated above
    $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring/log/get_ctm4.LMWT.log \
		cut -d " " -f 6 $dir/score_LMWT/$name.tmp1.ctm  \| paste -d " " $dir/score_LMWT/$name.tmp2.ctm - \| \
		$filter_cmd '>' $dir/score_LMWT/$name.ctm || exit 1;
  
  else
    echo "$0: no $lang/phones/word_boundary.int: cannot align."
    exit 1;
  fi
fi


