#!/bin/bash

BASEDIR=$(dirname $0)

echo "$0 $@"  # Print the command line for logging

txt=""
trs=""
ctm=""
sbv=""
srt=""
with_compounds_ctm=""
clean=true
nthreads=1

. $BASEDIR/utils/parse_options.sh || exit 1;

if [ $# -ne 1 ]; then
  echo "Usage: speech2text [options] <audiofile>"
  echo "Options:"  
  echo "  --nthreads <n>                   # Use <n> threads in parallel for decoding"
  echo "  --txt <txt-file>                 # Put the result in a simple text file"
  echo "  --json <json-file>               # Put the result in JSON file"  
  echo "  --trs <trs-file>                 # Put the result in trs file (XML file for Transcriber)"
  echo "  --ctm <ctm-file>                 # Put the result in CTM file (one line pwer word with timing information)"
  echo "  --srt <srt-file>                 # Put the result in SRT file (subtitles for e.g. VLC)"
  echo "  --with-compounds-ctm <ctm-file>  # Put the result in CTM file (with compound break symbols)"
  echo "  --clean (true|false)  # Delete intermediate files generated during decoding (true by default)"
  exit 1;
fi

  
cp -u $1 $BASEDIR/src-audio

filename=$(basename "$1")
basename="${filename%.*}"

nthreads_arg="nthreads=${nthreads}"

(cd $BASEDIR; make $nthreads_arg build/output/$basename.{txt,json,trs,ctm,srt,with-compounds.ctm} || exit 1; if $clean ; then make .$basename.clean; rm src-audio/$filename; fi)

echo "Finished transcribing, result is in files $BASEDIR/build/output/${basename%.*}.{txt,json,trs,ctm,srt,with-compounds.ctm}"

if [ ! -z $txt ]; then
  cp $BASEDIR/build/output/${basename}.txt $txt
  echo $txt
fi

if [ ! -z $trs ]; then
  cp $BASEDIR/build/output/${basename}.trs $trs
fi

if [ ! -z $json ]; then
  cp $BASEDIR/build/output/${basename}.json $json
fi

if [ ! -z $ctm ]; then
  cp $BASEDIR/build/output/${basename}.ctm $ctm
fi

if [ ! -z $srt ]; then
  cp $BASEDIR/build/output/${basename}.srt $srt
fi

if [ ! -z $with_compounds_ctm ]; then
  cp $BASEDIR/build/output/${basename}.with-compounds.ctm $with_compounds_ctm
fi


