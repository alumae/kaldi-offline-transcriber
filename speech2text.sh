#!/bin/bash

BASEDIR=$(dirname $0)

echo "$0 $@"  # Print the command line for logging

txt=""
trs=""
ctm=""
sbv=""
clean=true

. $BASEDIR/utils/parse_options.sh || exit 1;

if [ $# -ne 1 ]; then
  echo "Usage: speech2text [options] <audiofile>"
  echo "Options:"
  echo "  --txt <txt-file>      # Put the result in a simple text file"
  echo "  --trs <trs-file>      # Put the result in trs file (XML file for Transcriber)"
  echo "  --ctm <ctm-file>      # Put the result in CTM file (one line pwer word with timing information)"
  echo "  --sbv <sbv-file>      # Put the result in SBV file (subtitles for e.g. YouTube)"
  echo "  --clean (true|false)  # Delete intermediate files generated during decoding (true by default)"
  exit 1;
fi

  
cp -u $1 $BASEDIR/src-audio

(cd $BASEDIR; make build/output/${1%.*}.{txt,trs,ctm,sbv}; if $clean ; then make .${1%.*}.clean; fi)

if [ ! -z $txt ]; then
  cp $BASEDIR/build/output/${1%.*}.txt $txt
  echo $txt
fi

if [ ! -z $trs ]; then
  cp $BASEDIR/build/output/${1%.*}.trs $trs
fi

if [ ! -z $ctm ]; then
  cp $BASEDIR/build/output/${1%.*}.ctm $ctm
fi

if [ ! -z $sbv ]; then
  cp $BASEDIR/build/output/${1%.*}.sbv $sbv
fi

