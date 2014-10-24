# Kaldi Offline Transcriber #

## Updates ##

### 2014-10-24 ###

  * Implemented alternative transcribing scheme using online DNN models using speaker i-vector as extra input (actually wrapped the corresponding Kaldi implementation). This is requires only one pass over the audio but gives about 10% relatively more errors. This scheme can activated using the `--nnet2-online true` option to `speech2text.sh`, or the `DO_NNET2_ONLINE=yes` variable in `Makefile.options`.

### 2014-10-23 ###
  
  * Now uses language model rescoring using "constant ARPA" LM implemented recently in Kaldi, which makes LM rescoring faster and needs less memory. You have to update Kaldi to use this.
  * Uploaded new Estonian acoustic and language models. Word error rate on broadcast conversations is about 18%.

### 2014-08-03 ###
 
  * Implemented very experimental speaker ID system using i-vectors

## Introduction ##

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

## Requirements ##

### Server ###

Server running Linux is needed. The system is tested on Debian 'testing', but any 
modern distro should do.

Around 8 GB of RAM is required to initialize the speech recognition models for Estonian.

If you plan to process many recordings in parallel, we recoemmend to
turn off hyperthreading in server BIOS. This reduces the number of (virtual)
cores by half, but should make processing faster, if you won't run more than
`N` processes in parallel, where `N` is the number of physical cores.

It is recommended (but not needed) to create a decicated user account for the transcription work. 
In the following we assume the user is `speech`, with a home directory `/home/speech`.

### Development tools ###

  * C/C++ compiler, make, etc (the command `apt-get install build-essential` installs all this on Debian)
  * Perl

### Audio processing tools ###

  * ffmpeg
  * sox

## Installation ##
  
### Kaldi ###

IMPORTANT: The system works agains Kaldi trunk as of 2014-10-15. The system
may not work with Kaldi revisions that are a lot (months) older or newer than that.

Install and compile e.g. under `/home/speech/tools`. Follow instructions at
http://kaldi.sourceforge.net/install.html. Install the `kaldi-trunk` version.

You should probably execute something along the following lines (but refer to the official
install guide for details):

    cd ~/tools
    svn co svn://svn.code.sf.net/p/kaldi/code/trunk kaldi-trunk
    cd kaldi-trunk
    cd tools
    make -j 4
    ./install_atlas.sh

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
    
### This package ###

Just clone the git reposititory, e.g. under `/home/speech/tools`:

    cd /home/speech/tools
    git clone https://github.com/alumae/kaldi-offline-transcriber.git
   
Download and unpack the Estonian acoustic and language models:

    cd /home/speech/tools/kaldi-offline-transcriber
    curl http://bark.phon.ioc.ee/tanel/kaldi-offline-transcriber-data-2014-10-24.tgz | tar xvz 

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

    curl http://bark.phon.ioc.ee/tanel/kaldi-offline-transcriber-data-2014-10-24.tgz | tar xvz 

Initialize the new models:

    make .init
  

## Usage ##

Put a speech file under `src-audio`. Many file types (wav, mp3, ogg, mpg, m4a)
are supported. E.g:

    cd src-audio
    wget http://media.kuku.ee/intervjuu/intervjuu201306211256.mp3
    cd ..

Tp run the transcription pipeline, execute `make build/output/<filename>.txt` where `filename` matches the name of  the audio file
in `src-audio` (without the extension). This command runs all the necessary commands to generate the transcription file.

For example:

    make build/output/intervjuu201306211256.txt
    
Result (if everything goes fine, after about 36 minutes later (audio file was 8:35 in length, resulting in realtime factor of 4.2)): 

    # head -5 build/output/intervjuu201306211256.txt
    Palgainfoagentuur koostöös CV Online ja teiste partneritega viis kevadel läbi tööandjate ja töötajate palgauuringu meil on telefonil nüüd Palgainfo Agentuuri juht Kadri Seeder tervist.
    Kui laiapõhjaline see uuring oli ma saan aru et ei ole kaasatud ainult Eesti tööandjad ja töötajad.
    Jah me seekord viisime uuringu läbi ka Lätis ja Leedus ja ja see on täpselt samasuguse metoodikaga nii et me saame võrrelda Läti ja Leedu andmeid.
    Mitte täna sellepärast et Läti-Leedu tööandjatel ankeete lõpetavad täna vaatasime töötajate tööotsijate uuringusse väga põgusalt sisse.
    Need tulemused tulevad juuli käigus.


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

The speedup is not quite linear. For example, decoding an audio file of 8:35 minutes takes
   
  * 29 minutes with 1 thread (3.4x realtime)
  * 11.5 minutes with 4 threads (1.4x realtime)
    
The lattice rescoring part that is very memory intensive is executed in a single thread. So, if your
server has many cores but relatively little memory (say 16 cores and 16 GB RAM), you can set `nthreads = 5`,
and use up to 3 parallel decoding processes (e.g., using a queue system, such as Sun Grid Engine).
This way, the total memory consumption should never exceed 16 GB, and the decoding happens in ~1.5x realtime.


## One-pass decoding using online DNN models with speaker i-vectors ##

Instead of the three-pass decoding strategy, one can alternatively use one-pass decoding
using "online" DNN models that use i-vectors calculated from each speaker's speech
as additional input to the DNN, thus providing kind-of unsupervised speaker/channel adaptation. This
scheme is about two times faster than the default (when using one thread) but introduces
about 10% relatively more errors: the WER on Estonian radio talk shows when using the default scheme
is currently 17.7%, when using the one-pass decoding strategy it goes up to 19.3%.

You can activate the scheme by defining `DO_NNET2_ONLINE=yes` variable in `Makefile.options`, or using
the `--nnet2-online true` option to `speech2text.sh`.
  
To decode the same file as above (8:35 minutes), the one-pass scheme requires
  
  * 15 minutes with one thread (1.8x realtime)

