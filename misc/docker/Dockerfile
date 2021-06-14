FROM kaldiasr/kaldi:latest 
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
    python-pip \
    python-dev \
    sox \
    ffmpeg \
    subversion \
    wget \
    zlib1g-dev && \
    apt-get clean autoclean && \
    apt-get autoremove -y


ENV PATH="/root/miniconda3/bin:${PATH}"
ARG PATH="/root/miniconda3/bin:${PATH}"

RUN wget \
    https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && mkdir /root/.conda \
    && bash Miniconda3-latest-Linux-x86_64.sh -b \
    && rm -f Miniconda3-latest-Linux-x86_64.sh 

RUN conda --version

RUN conda install -c conda-forge pynini=2.1.3

RUN conda install pytorch=1.8.1 torchvision torchaudio=0.8.1 cpuonly -c pytorch

RUN pip install speechbrain

WORKDIR /opt
  
RUN git clone https://github.com/alumae/et-g2p-fst.git    

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y locales

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8

ENV LANG en_US.UTF-8
    
RUN apt-get install -y openjdk-8-jre-headless

RUN echo 2021-06-11#21:18 > /dev/null && \
    git clone https://github.com/alumae/kaldi-offline-transcriber.git

COPY Makefile.options /opt/kaldi-offline-transcriber/Makefile.options

RUN cd /opt/kaldi-offline-transcriber && \
    wget -q -O - http://bark.phon.ioc.ee/tanel/kaldi-offline-transcriber-data-2021-06-11.tgz | tar xvz

RUN cd /opt/kaldi/tools && \
    extras/install_pocolm.sh

ENV HOME /opt
ENV LD_LIBRARY_PATH /usr/local/lib

RUN apt-get install -y python3-numpy &&  \
    cd /opt/kaldi-offline-transcriber && \
    make .init

RUN ln -s -f /usr/bin/python2 /usr/bin/python && \
    apt-get install -y python-numpy python-scipy python3-simplejson python3-pytest && \
    pip2 install theano --no-deps

# Set up punctuator    
RUN echo 2021-06-11#21:18 > /dev/null && \
    cd /opt/kaldi-offline-transcriber && \
    wget -q -O - http://bark.phon.ioc.ee/tanel/est_punct2.tar.gz | tar xvz && \
	  echo 'DO_PUNCTUATION=yes' >> /opt/kaldi-offline-transcriber/Makefile.options && \
    echo 'PUNCTUATE_JSON_CMD=(cd punctuator-data/est_punct2/; temp_file1=$$(mktemp); temp_file2=$$(mktemp); cat > $$temp_file1;  python2 punctuator_pad_emb_json.py Model_stage2p_final_563750_h256_lr0.02.pcl $$temp_file1 $$temp_file2 > /dev/stderr; cat $$temp_file2; rm $$temp_file1 $$temp_file2)' >> /opt/kaldi-offline-transcriber/Makefile.options 

# Do a final git pull. This is actually not needed if building from scratch
RUN echo 2021-06-12#00:18 > /dev/null && \
    cd /opt/kaldi-offline-transcriber && \
    git pull    
   
   
RUN conda install ruamel.yaml && \
    pip install kaldiio && \
    pip install simplejson && \
    pip install pytest


CMD ["/bin/bash"]    

