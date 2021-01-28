# Kaldi Offline Transcriber #

## Updates ##

### 2018-10-31 ###
  * Introduced a new JSON format for holding all information baout the transcription (speakers, words, timings)
  * Subtitles are now split to shorter segments
  * TRS files now contain turns without utterance breaks

### 2018-09-12 ###
  * Updated speaker ID models

### 2018-08-31 ###
  * Added a Dockerfile for building a Docker image with Estonian models,
    a pre-built image is also available, see [here](misc/docker).

### 2018-08-21 ###
  * Changed the speaker ID system to use Kaldi's native i-vector scoring. That means that Tensorflow
    and Keras are no longer needed for doing speaker identification.

### 2018-08-08 ###
  * Some refactorings, and new models, and RNNLM rescoring.
    Also, now uses a decoding with special unknkwon word handling,
    which makes it possible to produce words not in the LM is the final output. Details
    will be added later.
  
### 2017-05-29 ###
  * Replaced Kaldi-based speaker ID with a custom DNN-based implementation. Requires Keras 1.2.

### 2017-05-02 ###
  * Replaced the usage of the pyfst library in compounder.py with OpenFst's native Python extension (issue #14). See below on how to install it.

### 2017-02-13 ###
  * Migrated to Kaldi's chain models. Needs fairly recent version of Kaldi, so you need to
    recompile Kaldi if you are upgrading. Better accuracy and faster than before 
    (0.6 x realtime using one CPU).
  
  * The acoustic models are trained using noised and reverberated audio data, which
    means that the ASR accuracy on noisy data should be much better. Also, improved the 
    robustness of speech-non-speech detection against noise. 
    
  * The python scripts should now work for both Python 2.7 and 3.3+

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
  * Three-pass decoding
    - With Kaldi's so-called chain TDNN acoustic models that use i-vectors for speaker adaptation
    - Rescoring with a larger language model
    - Rescoring with a recurrent neural network language model
  * Finally, the recognized words are reconstructed into compound words (i.e., decoding is done using de-compounded words).
    This is the only part that is specific to Estonian.

Trancription is performed in roughly 0.6x realtime on a 10 year old server, using one CPU.
E.g., transcribing a radio inteview of length 8:23 takes about 5 minutes.

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
  * Python 2.7 or 3.5+

### Audio processing tools ###

  * ffmpeg
  * sox

## Installation ##

### Atlas

Install the ATLAS matrix algebra library. On Ubuntu/Debian (as root):

    apt-get install libatlas3-base
      
### Kaldi ###

IMPORTANT: The system works agains Kaldi trunk as of 2018-08-01. The system
may not work with Kaldi revisions that are a lot (months) older or newer than that.

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


### Python 3 ###

Install python (at least 3.5), using your OS tools (e.g., `apt-get`). 
Make sure `pip` is installed (`apt-get install python-pip3`). Python 3 should be set as the 
default python on your system.


### Pynini ###

Pynini and OpenFst's Python wrapper are needed for some postprocessing steps. The following
ugly command line should take care of this (run as root):

    apt-get install -y python3-setuptools && \
    cd /tmp && \
    git clone https://github.com/google/re2 && \
    cd /tmp/re2 && \
    make -j4 && \
    make install && \
    cd /tmp && \
    wget http://www.openfst.org/twiki/pub/FST/FstDownload/openfst-1.6.9.tar.gz && \
    tar zxvf openfst-1.6.9.tar.gz && \
    cd openfst-1.6.9 && \
    ./configure --enable-grm && \
    make -j8 && \
    make install && \
    cd /tmp && \
    wget http://www.opengrm.org/twiki/pub/GRM/PyniniDownload/pynini-2.0.0.tar.gz && \
    tar zxvf pynini-2.0.0.tar.gz && \
    cd pynini-2.0.0 && \
    python setup.py install && \
    rm -rf /tmp/re2 /tmp/openfst-1.6.9.tar.gz /tmp/pynini-2.0.0.tar.gz /tmp/openfst-1.6.9 /tmp/pynini-2.0.0

You might also need to include /usr/local/lib to LD_LIBRARY_PATH evironment variable. To do this,
add to `.bashrc`:

    export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

### Et-G2P

The Estonian FST-based grapheme-to-phoneme converter is needed for post-processing.
Available at https://github.com/alumae/et-g2p-fst. Just clone it to a directory, e.g. to
`/home/speech/tools/et-g2p-fst`

    cd /home/speech/tools
    git clone https://github.com/alumae/et-g2p-fst.git
    
Test it (using phoneme-to-grapheme conversion):

    $ echo "muška" | python3 g2p.py --inverse --fst data/chars.fst --nbest 1
    muška Muška 18.6946869
   
    
### This package ###

Just clone the git reposititory, e.g. under `/home/speech/tools`:

    cd /home/speech/tools
    git clone https://github.com/alumae/kaldi-offline-transcriber.git
   
Download and unpack the Estonian acoustic and language models:

    cd /home/speech/tools/kaldi-offline-transcriber
    curl http://bark.phon.ioc.ee/tanel/kaldi-offline-transcriber-data-2018-09-12.tgz  | tar xvz 

Create a file `Makefile.options` and set the `KALDI_ROOT` and `ET_G2P_FST` path to where they are installed:

    KALDI_ROOT=/home/speech/tools/kaldi-trunk
    ET_G2P_FST=/home/speech/tools/et-g2p-fst


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

    curl http://bark.phon.ioc.ee/tanel/kaldi-offline-transcriber-data-2018-08-21.tgz | tar xvz 

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
    
Result (if everything goes fine, after about 5 minutes later (audio file was 8:35 in length, resulting in realtime factor of 0.6)).
Also demos automatic punctuation (not yet publicly available):

    # head -5 build/output/intervjuu201306211256.txt
    
    Palgainfoagentuur koostöös CV-Online'i ja teiste partneritega viis kevadel läbi tööandjate ja töötajate palgauuringu. Meil on telefonil nüüd palgainfoagentuuri juht Kadri Seeder. Tervist.
    Kui laiapõhjaline see uuring oli, ma saan aru, et ei ole kaasatud ainult Eesti tööandjad ja töötajad.
    Jah, me seekord viisime uuringu läbi ka Lätis ja Leedus ja, ja see on täpselt samasuguse metoodikaga, nii et me saame võrrelda Läti ja Leedu andmeid, seda küll veel mitte täna sellepärast et Läti-Leedu tööandjatel ankeete lõpetavad.
    Täna vaatasime töötajate tööotsijate uuringus väga põgusalt sisse, et need tulemused tulevad. Juuli käigus
    aga kui rääkida tänasest esitlusest, siis tee pöörasid tähelepanu sellele, kui täpsemalt rääkisite sellest, millised on toimunud ja prognoositavad muutused põhipalkades ja nende põhjused, kas saaksite meile ka sellest rääkida.


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

