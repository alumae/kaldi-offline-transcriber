
# Requirements #

## Server ##

Server running Linux is needed. The system is tested on Debian 'testing', but any 
modern distro should do.

If you plan to process many recordings in parallel, we recoemmend to
turn off hyperthreading in srver BIOS. This reduces the number of (virtual)
cores by half, but should make processing faster, if you won't run more than
`N` processes in parallel, where `N` is the number of physical cores.

It is recommended to create a decicated user account for the transcription work. 
In the following we assume the user is `speech`, with a home directory `/home/speech`.

## Compilation and development tools ##

  * make
  * Perl
  
## Kaldi ##

Install e.g. under `/home/speech/tools/kaldi`. Follow instructions at
http://kaldi.sourceforge.net/install.html.

## Python 2.7 ##

Install python 2.7, using your OS tools (e.g., `apt-get`). 
Make sure `pip` is installed (`apt-get install python-pip`).

## Python package pyfst ##

The python package `pyfst` is needed for reconstructing compound words. 

Install:

    pip install pyfst
    
## This package ##

Just clone the git reposititory under `/home/speech/tools`:

   cd /home/speech/tools
   git clone ...
   
Set the paths in `Makefile.options` (TODO)

Run this once:

    make .init
    
This creates all the necessary files from original model files that are used
during decoding. 

Note that all files that are created during initialization and decoding are
put under `build` subdirectory. So, if you feel that you want to do a fresh 
start, just delete the `build` directory and do a `make .init` again.



