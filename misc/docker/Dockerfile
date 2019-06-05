FROM debian:9
MAINTAINER Tanel Alumae <alumae@gmail.com>

RUN apt-get update && apt-get install -y  \
    autoconf \
    automake \
    bzip2 \
    g++ \
    gfortran \
    git \
    libatlas3-base \
    libtool-bin \
    make \
    python2.7 \
    python3 \
    python-pip \
    python-dev \
    python3-dev \
    sox \
    ffmpeg \
    subversion \
    wget \
    zlib1g-dev && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    ln -s -f /usr/bin/python3 /usr/bin/python ; ln -s -f bash /bin/sh

WORKDIR /opt

RUN git clone https://github.com/kaldi-asr/kaldi && \
    cd /opt/kaldi/tools && \
    make -j8 && \
    cd /opt/kaldi/src && ./configure --shared && \
    sed -i '/-g # -O0 -DKALDI_PARANOID/c\-O3 -DNDEBUG' kaldi.mk && \
    make -j8 depend && make -j8
    
RUN apt-get install -y python3-setuptools && \
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
    
RUN git clone https://github.com/alumae/et-g2p-fst.git    

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y locales

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8

ENV LANG en_US.UTF-8
    
RUN apt-get install -y openjdk-8-jre-headless

RUN echo 6 > /dev/null && \
    git clone https://github.com/alumae/kaldi-offline-transcriber.git
COPY Makefile.options /opt/kaldi-offline-transcriber/Makefile.options

RUN cd /opt/kaldi-offline-transcriber && \
    wget -q -O - http://bark.phon.ioc.ee/tanel/kaldi-offline-transcriber-data-2018-09-12.tgz | tar xvz

RUN cd /opt/kaldi/tools && \
    extras/install_pocolm.sh

ENV HOME /opt
ENV LD_LIBRARY_PATH /usr/local/lib

RUN apt-get install -y python3-numpy && \
    cd /opt/kaldi-offline-transcriber && \
    make .init

RUN ln -s -f /usr/bin/python2 /usr/bin/python && \
    apt-get install -y python-numpy python-scipy python3-simplejson python3-pytest && \
    pip2 install theano --no-deps

# Set up punctuator    
RUN echo 1 > /dev/null && \
    cd /opt/kaldi-offline-transcriber && \
    wget -q -O - http://bark.phon.ioc.ee/tanel/est_punct2.tar.gz | tar xvz && \
	  echo 'DO_PUNCTUATION=yes' >> /opt/kaldi-offline-transcriber/Makefile.options && \
    echo 'PUNCTUATE_JSON_CMD=(cd punctuator-data/est_punct2/; temp_file1=$$(mktemp); temp_file2=$$(mktemp); cat > $$temp_file1;  python2 punctuator_pad_emb_json.py Model_stage2p_final_563750_h256_lr0.02.pcl $$temp_file1 $$temp_file2 > /dev/stderr; cat $$temp_file2; rm $$temp_file1 $$temp_file2)' >> /opt/kaldi-offline-transcriber/Makefile.options 

# Do a final git pull. This is actually not needed if building from scratch
RUN echo 7 > /dev/null && \
    cd /opt/kaldi-offline-transcriber && \
    git pull    
   
CMD ["/bin/bash"]    

