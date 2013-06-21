# Kaldi Offline Transcriber #

This is an offline transcription system based on Kaldi (http://kaldi.sourceforge.net), with some Estonian specific
aspects. 

The system is targetted to users who have no speech research background
but who want to transcribe long audio recordings using automatic speech recognition.

Much of the code is based on the training and testing recipes that come
with Kaldi.

The system performs:
  * Speech/non-speech detection, speech segmentation, speaker diarization (using the LIUMSpkDiarization package, http://lium3.univ-lemans.fr/diarization)
  * Four-pass decoding
    - With speaker-independent features using MMI-trained acoustic models 
    - With speaker-adapted features and MMI-based acoustic models
    - With speaker-adapated features and neural network based acoustic models
    - Final rescoring with a larger language model
  * Finally, the recognized words are reconstructed into compound words (i.e., decoding is done using de-compounded words).
    This is the only part that is specific to Estonian.

Trancription is performed in roughly 4.5x realtime on a 5 year old server, using one CPU.
E.g., transcribing a radio inteview of length 8:23 takes about 37 minutes.

Memory requirements: during most of the work, less than 1 GB of memory is used.
However, during the final rescoring pass, about 5 GB memory is used for a very short time.

## Requirements ##

### Server ###

Server running Linux is needed. The system is tested on Debian 'testing', but any 
modern distro should do.

If you plan to process many recordings in parallel, we recoemmend to
turn off hyperthreading in srver BIOS. This reduces the number of (virtual)
cores by half, but should make processing faster, if you won't run more than
`N` processes in parallel, where `N` is the number of physical cores.

It is recommended to create a decicated user account for the transcription work. 
In the following we assume the user is `speech`, with a home directory `/home/speech`.

### Development tools ###

  * C compiler, make, etc (the command `apt-get install build-essential` installs all this on Debian)
  * Perl

### Audio processing tools ###

  * ffmpeg
  * sox
  
### Kaldi ###

Install and compile e.g. under `/home/speech/tools/kaldi`. Follow instructions at
http://kaldi.sourceforge.net/install.html. Install the `kaldi-trunk` version.


### Python  ###

Install python (at least 2.6), using your OS tools (e.g., `apt-get`). 
Make sure `pip` is installed (`apt-get install python-pip`).

## Python package pyfst ##

The python package `pyfst` is needed for reconstructing compound words. This package
itself needs OpenFst shared libararies, that we already built when installing Kaldi.
To install `pyfst` and make it use the Kaldi's OpenFst libraries, install
it like that (as root):

    CPPFLAGS="-I/home/speech/tools/kaldi-trunk/tools/openfst/include -L/home/speech/tools/kaldi-trunk/tools/openfst/lib" pip install pyfst
    
### This package ###

Just clone the git reposititory under `/home/speech/tools`:

   cd /home/speech/tools
   git clone ...
   
Download and unpack the Estonian acoustic and language models:

    cd /home/speech/tools/kaldi-offline-transcriber
    curl http://www.phon.ioc.ee/~tanela/kaldi-offline-transcriber-data.tgz | tar xvf 

Create a file `Makefile.options` and set the `KALDI_ROOT` path to where it's installed:

    KALDI_ROOT=/home/speech/tools/kaldi-trunk

Run this once:

    make .init
    
This compiles all the necessary files from original model files that are used
during decoding (takes some time).

Note that all files that are created during initialization and decoding are
put under the `build` subdirectory. So, if you feel that you messed something up and
want to do a fresh start, just delete the `build` directory and do a `make .init` again.


## Usage ##

Put a speech file under `src-audio`. Many file types (wav, mp3, ogg, mpg, m4a)
are supported. E.g:

    cd src-audio
    wget http://media.kuku.ee/intervjuu/intervjuu201306211256.mp3
    cd ..

Run the transcription pipeline, and put the resulting text in `build/output/intervjuu201306211256.txt`:

    make build/output/intervjuu201306211256.txt
    
The system can also generate a result in other formats: 

  * `.trs` -- XML file in Transcriber (http://trans.sourceforge.net) format, with speakers information, sentence start and end times
  * `.ctm` -- CTM file in NIST format -- contains timing information for each recognized word
  * `.with-compounds.ctm` -- same as `.ctm`, but compound words are concatenated using the '+' character
  * `.sbv` -- subtitle file format, can be used for adding subtitles to YouTube videos
  
For example, to create a subtitle file, run

    make build/output/intervjuu201306211256.sbv
   
Note that generating files in different formats doesn't add any runtime complexity, since all the different
output files are generated from the same internal representation.
  
To remove the intermediate files generated during decoding, run the pseudo-target `make .filename.clean`, e.g.:

    make .intervjuu201306211256.clean
