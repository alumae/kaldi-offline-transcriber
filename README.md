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
E.g., trancribing a radio inteview of length 8:23 takes about 37 minutes.

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

### Compilation and development tools ###

  * C compiler, make, etc (the command `apt-get install build-essential` installs all this on Debian)
  * Perl
  
### Kaldi ###

Install and compile e.g. under `/home/speech/tools/kaldi`. Follow instructions at
http://kaldi.sourceforge.net/install.html. Install the `kaldi-trunk` version.

NB! By default, Kaldi doesn't build the shared libraries of the OpenFST package.
However, one of our python script needs the OpenFST shared libraries. To enable 
shared libraries,  edit the file `tools/Makefile` before running `make` under `tools`
and change the line:

### Python 2.7 ###

Install python 2.7, using your OS tools (e.g., `apt-get`). 
Make sure `pip` is installed (`apt-get install python-pip`).

## Python package pyfst ##

The python package `pyfst` is needed for reconstructing compound words. This package
itself needs OpenFst shared libararies, that we already built when installing Kaldi.
To install `pyfst` and make it use the Kaldi's Openfst libraries, install
it like that (as root):

    
    CPPFLAGS="-I/home/speech/tools/kaldi-trunk/tools/openfst/include -L/home/speech/tools/kaldi-trunk/tools/openfst/lib" pip install pyfst
    
### This package ###

Just clone the git reposititory under `/home/speech/tools`:

   cd /home/speech/tools
   git clone ...
   
Set the paths in `Makefile.options` (TODO)

Run this once:

    make .init
    
This compiles all the necessary files from original model files that are used
during decoding. 

Note that all files that are created during initialization and decoding are
put under the `build` subdirectory. So, if you feel that you want to do a fresh 
start, just delete the `build` directory and do a `make .init` again.



