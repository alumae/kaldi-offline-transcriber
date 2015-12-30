# Kaldi Offline Transcriber #

## Updates ##

### 2015-12-29 ###
  * Updated acoustic and language models (see below on how to update). No need
    to update Kaldi. Recognition errors reduced by more than 10%. Word error rate on broadcast conversations is about 14%.

### 2015-05-14 ###
  * Removed the option to decode using non-online (old style) nnet2 models
    since the online nnet2 models are more accurate and faster (they don't 
    require first pass decoding using triphone models). 
    
  * Decoding using online nnet2 models now uses non-online decoder because it
    allows multithreaded execution. This means that the whole transcription process from
    start to finish works in 1.3x realtime when using one thread, and in
    0.8x realtime when using `nthreads=4` on a 8 year old server.
    
  * Segments recognized as music and jingle are now reflected as filler
    segments in the final .trs files (probably not important for most users).
      
  * Implemented a framework for automatic punctuation. The punctuation
    models are not yet publicly available, will be soon.

### 2015-03-11 ###
  * Language model has been updated on recent text data.

### 2014-12-17 ###
  * Fixed handling of names with multipart surnames, etc (such as Erik-Niiles Kross) in the speaker ID system. Download new models.

### 2014-12-04 ###

  * Updated online DNN acoustic models (now they use multisplice features), which results in lower word error rate than offline SAT DNNs. Word error rate on broadcast conversations is now about 17%.
    Made decoding using online DNNs default. Also, refactored speaker ID system a bit. *NB:* requires fairly recent Kaldi. 
    Update Kaldi and download new models as documented below.  

### 2014-10-24 ###

  * Implemented alternative transcribing scheme using online DNN models using speaker i-vector as extra input (actually wrapped the corresponding Kaldi implementation). This is requires only one pass over the audio but gives about 10% relatively more errors. This scheme can activated using the `--nnet2-online true` option to `speech2text.sh`, or the `DO_NNET2_ONLINE=yes` variable in `Makefile.options`.

### 2014-10-23 ###
  
  * Now uses language model rescoring using "constant ARPA" LM implemented recently in Kaldi, which makes LM rescoring faster and needs less memory. You have to update Kaldi to use this.
  * Uploaded new Estonian acoustic and language models. Word error rate on broadcast conversations is about 18%.

### 2014-08-03 ###
 
  * Implemented very experimental speaker ID system using i-vectors

## Introduction ##

This is an offline transcription system for Estonian based on Kaldi (https://github.com/kaldi-asr/kaldi).

The system is targetted to users who have no speech research background
but who want to transcribe long audio recordings using automatic speech recognition.

Much of the code is based on the training and testing recipes that come
with Kaldi.

The system performs:
  * Speech/non-speech detection, speech segmentation, speaker diarization (using the LIUMSpkDiarization package, http://lium3.univ-lemans.fr/diarization)
  * Two-pass decoding
    - With Kaldi's "online-nnet2" style acoustic models that use i-vectors for speaker adaptation
    - Rescoring with a larger language model
  * Finally, the recognized words are reconstructed into compound words (i.e., decoding is done using de-compounded words).
    This is the only part that is specific to Estonian.

Trancription is performed in roughly 1.3x realtime on a 8 year old server, using one CPU.
E.g., transcribing a radio inteview of length 8:23 takes about 11:20 minutes. This
can be accelerated to be faster than realtime using multithreaded decoding (see below).

Memory requirements: during most of the work, less than 1 GB of memory is used.

## Requirements ##

### Server ###

Server running Linux is needed. The system is tested on Debian 'testing', but any 
modern distro should do.

#### Memory requirements ####
  
  * Around 8GB of RAM is required to initialize the speech recognition models (`make .init`)
  * Around 2GB of RAM is required for actual transcription, once the models have been initialized
  
#### Remarks ####

If you plan to process many recordings in parallel, we recommend to
turn off hyperthreading in server BIOS. This reduces the number of (virtual)
cores by half, but should make processing faster, if you won't run more than
`N` processes in parallel, where `N` is the number of physical cores.

It is recommended (but not needed) to create a decicated user account for the transcription work. 
In the following we assume the user is `speech`, with a home directory `/home/speech`.

### Development tools ###

  * C/C++ compiler, make, etc (the command `apt-get install build-essential` installs all this on Debian)
  * Perl
  * java-jre

### Audio processing tools ###

  * ffmpeg
  * sox

## Installation ##

### Atlas

Install the ATLAS matrix algebra library. On Ubuntu/Debian (as root):

    apt-get install libatlas-dev
      
### Kaldi ###

IMPORTANT: The system works agains Kaldi trunk as of 2014-11-15. The system
may not work with Kaldi revisions that are a lot (months) older or newer than that.

Update: also tested against Kaldi as of 2015-11-15 -- everything works OK.


Install and compile e.g. under `/home/speech/tools`. Follow instructions at
http://kaldi-asr.org/doc/install.html. Install the `kaldi-trunk` version.

You should probably execute something along the following lines (but refer to the official
install guide for details):

    cd ~/tools
    git clone git@github.com:kaldi-asr/kaldi.git kaldi-trunk
    cd kaldi-trunk
    cd tools
    make -j 4

    cd ../src
    ./configure
    make depend
    make -j 4


### Python  ###

Install python (at least 2.6), using your OS tools (e.g., `apt-get`). 
Make sure `pip` is installed (`apt-get install python-pip`).

### Python package pyfst ###

The python package `pyfst` is needed for reconstructing compound words. This package
itself needs OpenFst shared libararies, that we already built when installing Kaldi.
To install `pyfst` and make it use the Kaldi's OpenFst libraries, install
it like that (as root):

    CPPFLAGS="-I/home/speech/tools/kaldi-trunk/tools/openfst/include -L/home/speech/tools/kaldi-trunk/tools/openfst/lib" pip install pyfst
    
If you have OpenFst installed as a system-wide library, you don't need the flags, i.e., just execute (as root):

    pip install pyfst
    
### This package ###

Just clone the git reposititory, e.g. under `/home/speech/tools`:

    cd /home/speech/tools
    git clone https://github.com/alumae/kaldi-offline-transcriber.git
   
Download and unpack the Estonian acoustic and language models:

    cd /home/speech/tools/kaldi-offline-transcriber
    curl http://bark.phon.ioc.ee/tanel/kaldi-offline-transcriber-data-2015-12-29.tgz | tar xvz 

Create a file `Makefile.options` and set the `KALDI_ROOT` path to where it's installed:

    KALDI_ROOT=/home/speech/tools/kaldi-trunk

Run this once:

    make .init
    
This compiles all the necessary files from original model files that are used
during decoding (takes around 30 minutes).

Note that all files that are created during initialization and decoding are
put under the `build` subdirectory. So, if you feel that you messed something up and
want to do a fresh start, just delete the `build` directory and do a `make .init` again.


## How to upgrade from a previous version ##

Update Kaldi:

    cd /home/speech/tools/kaldi-trunk
    svn update
    cd src
    make clean
    make -j 4 depend
    make -j 4 

Update this system:

    cd /home/speech/tools/kaldi-offline-transcriber
    git pull
    
Remove old `build`, `kaldi-data` and `language_model` directories:

    rm -rf build/ kaldi-data/ language_model/
  
Get new Estonian models:

    curl http://bark.phon.ioc.ee/tanel/kaldi-offline-transcriber-data-2015-12-29.tgz | tar xvz 

Initialize the new models:

    make .init
  

## Usage ##

Put a speech file under `src-audio`. Many file types (wav, mp3, ogg, mpg, m4a)
are supported. E.g:

    cd src-audio
    wget http://media.kuku.ee/intervjuu/intervjuu201306211256.mp3
    cd ..

To run the transcription pipeline, execute `make build/output/<filename>.txt` where `filename` matches the name of  the audio file
in `src-audio` (without the extension). This command runs all the necessary commands to generate the transcription file.

For example:

    make build/output/intervjuu201306211256.txt
    
Result (if everything goes fine, after about 11:20 minutes later (audio file was 8:35 in length, resulting in realtime factor of 1.3)).
Also demos automatic punctuation (not yet publicly available):

    # head -5 build/output/intervjuu201306211256.txt
    
    Palgainfoagentuur koostöös, et see on laim ja teiste partneritega viis kevadel läbi tööandjate ja töötajate palgauuringu. Meil on telefonil nüüd palgainfoagentuuri juht Kadri Seeder. Tervist.
    Kui laiapõhjaline see uuring oli, ma saan aru, et ei ole kaasatud ainult Eesti tööandjad ja töötajad.
    Jah, me seekord viisime uuringu läbi ka Lätis ja Leedus ja, ja see on täpselt samasuguse metoodikaga, nii et me saame võrrelda Läti ja Leedu andmed
    seda küll mitte täna sellepärast et Läti-Leedu tööandjatele ankeete lõpetavad. Täna vaatasime töötajate tööotsijate uuringusse väga põgusalt sisse,
    need tulemused tulevad juuli käigus


Note that in the `.txt` file, all recognized sentences are title-cased and end with a '.'.
    
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


## Alternative usage ##

Alternatively, one can use the wrapper script `speech2text.sh` to transcribe audio files. The scripts is a wrapper to the Makefile-based
system. The scripts can be called from any directory.

E.g., being in some data directory, you can execute:

    /home/speech/kaldi-offline-transcriber/speech2text.sh --trs result/test.trs audio/test.ogg
    
This transcribes the file `audio/test.ogg` and puts the result in Transcriber XML format to `result/test.trs`.
The script automatically deletes the intermediate files generated during decoding, unless the option `--clean false` is
used.

## Speeding up decoding ##

The most time-consuming parts of the system can be executed in parallel. This speeds up decoding
with the expense of using more CPU cores.

To enable multi-threaded execution, set the variable `nthreads` in `Makefile.options`, e.g.:

    nthreads = 4

The speedup is not quite linear, mostly because speaker diarization is still single-threaded.
For example, decoding an audio file of 8:35 minutes takes
   
  * 11:20 minutes with 1 thread (1.3x realtime)
  * 7:03 minutes with 4 threads (0.8x realtime)
    
~~The lattice rescoring part that is very memory intensive is executed in a single thread. So, if your
server has many cores but relatively little memory (say 16 cores and 16 GB RAM), you can set `nthreads = 5`,
and use up to 3 parallel decoding processes (e.g., using a queue system, such as Sun Grid Engine).
This way, the total memory consumption should never exceed 16 GB, and the decoding happens in ~1.5x realtime.~~

The above no longer applies. Lattice rescoring doesn't require a lot of memory.


## One-pass decoding using online DNN models with speaker i-vectors ##

This is now the only way to decode. The option to decode with non-online
nnet models has been removed, since it is much slower and not more accurate.

