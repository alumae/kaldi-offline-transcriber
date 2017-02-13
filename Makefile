SHELL := /bin/bash

# Use this file to override various settings
-include Makefile.options

DO_MUSIC_DETECTION?=yes

# Set to 'yes' if you want to do speaker ID for trs files
# Assumes you have models for speaker ID
DO_SPEAKER_ID?=yes
SID_THRESHOLD?=25

# Where is Kaldi root directory?
KALDI_ROOT?=/home/speech/tools/kaldi-trunk

# Location of the Java binary
JAVA_BIN?=/usr/bin/java

# How many processes to use for one transcription task
njobs ?= 1

# How many threads to use in each process
nthreads ?= 1

PATH := utils:$(KALDI_ROOT)/src/bin:$(KALDI_ROOT)/tools/openfst/bin:$(KALDI_ROOT)/src/fstbin/:$(KALDI_ROOT)/src/gmmbin/:$(KALDI_ROOT)/src/featbin/:$(KALDI_ROOT)/src/lm/:$(KALDI_ROOT)/src/sgmmbin/:$(KALDI_ROOT)/src/sgmm2bin/:$(KALDI_ROOT)/src/fgmmbin/:$(KALDI_ROOT)/src/latbin/:$(KALDI_ROOT)/src/nnet2bin/:$(KALDI_ROOT)/src/online2bin/:$(KALDI_ROOT)/src/kwsbin:$(KALDI_ROOT)/src/lmbin:$(PATH):$(KALDI_ROOT)/src/ivectorbin:$(KALDI_ROOT)/src/nnet3bin:$(PATH)

export train_cmd=run.pl
export decode_cmd=run.pl
export cuda_cmd=run.pl
export mkgraph_cmd=run.pl

# Main language model (should be slightly pruned), used for rescoring
LM ?=language_model/pruned.vestlused-dev.splitw2.arpa.gz

# More aggressively pruned LM, used in decoding
PRUNED_LM ?=language_model/pruned6.vestlused-dev.splitw2.arpa.gz

COMPOUNDER_LM ?=language_model/compounder-pruned.vestlused-dev.splitw.arpa.gz

# Vocabulary in dict format (no pronouncation probs for now)
VOCAB?=language_model/vestlused-dev.splitw2.dict

LM_SCALE?=17

DO_PUNCTUATION?=no

ifeq "yes" "$(DO_PUNCTUATION)"
  PUNCTUATE_SYNC_TXT_CMD?=(cd ~/tools/punctuator/src; python2.7 wrapper.py)
  DOT_PUNCTUATED=.punctuated
endif


# Find out where this Makefile is located (this is not really needed)
where-am-i = $(lastword $(MAKEFILE_LIST))
THIS_DIR := $(shell dirname $(call where-am-i))

FINAL_PASS=chain_tdnn_bi_online_pruned_rescored_main

LD_LIBRARY_PATH+=$(KALDI_ROOT)/tools/openfst/lib

.SECONDARY:
.DELETE_ON_ERROR:

PYTHONIOENCODING="utf-8"

export

# Call this (once) before using the system
.init: .kaldi .lang

.kaldi:
	rm -f steps utils sid
	ln -s $(KALDI_ROOT)/egs/wsj/s5/steps
	ln -s $(KALDI_ROOT)/egs/wsj/s5/utils
	ln -s $(KALDI_ROOT)/egs/sre08/v1/sid
	mkdir -p src-audio

.lang: build/fst/data/prunedlm build/fst/chain_tdnn_bi_online/graph_prunedlm build/fst/data/largelm build/fst/data/compounderlm


# Convert dict and LM to FST format
build/fst/data/dict build/fst/data/prunedlm: $(PRUNED_LM) $(VOCAB)
	rm -rf build/fst/data/dict build/fst/data/prunedlm
	mkdir -p build/fst/data/dict build/fst/data/prunedlm
	cp -r $(THIS_DIR)/kaldi-data/dict/* build/fst/data/dict
	rm -f build/fst/data/dict/lexicon.txt build/fst/data/dict/lexiconp.txt
	cat models/etc/filler16k.dict | egrep -v "^<.?s>"   > build/fst/data/dict/lexicon.txt
	cat $(VOCAB) | perl -npe 's/\(\d\)(\s)/\1/' >> build/fst/data/dict/lexicon.txt
	utils/prepare_lang.sh build/fst/data/dict "++garbage++" build/fst/data/dict/tmp build/fst/data/prunedlm
	gunzip -c $(PRUNED_LM) | \
		grep -v '<s> <s>' | \
		grep -v '</s> <s>' | \
		grep -v '</s> </s>' | \
		arpa2fst --disambig-symbol=#0 \
		  --read-symbol-table=build/fst/data/prunedlm/words.txt  -  $@/G.fst
	fstisstochastic build/fst/data/prunedlm/G.fst || echo "Warning: LM not stochastic"

build/fst/data/largelm: build/fst/data/prunedlm $(LM)
	rm -rf $@
	mkdir -p $@
	utils/build_const_arpa_lm.sh \
		$(LM) build/fst/data/prunedlm $@

build/fst/data/compounderlm: $(COMPOUNDER_LM) $(VOCAB)
	rm -rf $@
	mkdir -p $@
	cat $(VOCAB) | perl -npe 's/(\(\d\))?\s.+//' | uniq | ./scripts/make-compounder-symbols.py > $@/words.txt
	zcat $(COMPOUNDER_LM) | \
		grep -v '<s> <s>' | \
		grep -v '</s> <s>' | \
		grep -v '</s> </s>' | \
		arpa2fst  - | fstprint | \
		utils/s2eps.pl | fstcompile --isymbols=$@/words.txt --osymbols=$@/words.txt > $@/G.fst 
		
build/fst/chain_tdnn_bi_online/final.mdl:
	rm -rf `dirname $@`
	mkdir -p `dirname $@`
	cp -r $(THIS_DIR)/kaldi-data/chain_tdnn_bi_online/* `dirname $@`
	perl -i -npe 's/=.*online\//=build\/fst\/chain_tdnn_bi_online\//' build/fst/chain_tdnn_bi_online/conf/*.conf


build/fst/%/graph_prunedlm: build/fst/data/prunedlm build/fst/%/final.mdl
	rm -rf $@
	utils/mkgraph.sh --self-loop-scale 1.0  build/fst/data/prunedlm build/fst/$* $@

build/audio/base/%.wav: src-audio/%.wav
	mkdir -p `dirname $@`
	sox $^ -c 1 -2 build/audio/base/$*.wav rate -v 16k

build/audio/base/%.wav: src-audio/%.mp3
	mkdir -p `dirname $@`
	ffmpeg -i $^ -f sox - | sox -t sox - -c 1 -2 $@ rate -v 16k	

build/audio/base/%.wav: src-audio/%.ogg
	mkdir -p `dirname $@`
	sox $^ -c 1 build/audio/base/$*.wav rate -v 16k

build/audio/base/%.wav: src-audio/%.mp2
	mkdir -p `dirname $@`
	sox $^ -c 1 build/audio/base/$*.wav rate -v 16k

build/audio/base/%.wav: src-audio/%.m4a
	mkdir -p `dirname $@`
	ffmpeg -i $^ -f sox - | sox -t sox - -c 1 -2 $@ rate -v 16k
	
build/audio/base/%.wav: src-audio/%.mp4
	mkdir -p `dirname $@`
	sox $^ -c 1 build/audio/base/$*.wav rate -v 16k

build/audio/base/%.wav: src-audio/%.flac
	mkdir -p `dirname $@`
	sox $^ -c 1 build/audio/base/$*.wav rate -v 16k

build/audio/base/%.wav: src-audio/%.amr
	mkdir -p `dirname $@`
	amrnb-decoder $^ $@.tmp.raw
	sox -s -2 -c 1 -r 8000 $@.tmp.raw -c 1 build/audio/base/$*.wav rate -v 16k
	rm $@.tmp.raw

build/audio/base/%.wav: src-audio/%.mpg
	mkdir -p `dirname $@`
	ffmpeg -i $^ -f sox - | sox -t sox - -c 1 -2 build/audio/base/$*.wav rate -v 16k
	
# Speaker diarization
build/diarization/%/show.seg: build/audio/base/%.wav
	rm -rf `dirname $@`
	mkdir -p `dirname $@`
	echo "$* 1 0 1000000000 U U U 1" >  `dirname $@`/show.uem.seg;
	if [ $(DO_MUSIC_DETECTION) = yes ]; then diarization_opts="-m"; fi; \
	./scripts/diarization.sh $$diarization_opts $^ `dirname $@`/show.uem.seg


build/audio/segmented/%: build/diarization/%/show.seg
	rm -rf $@
	mkdir -p $@
	cat $^ | cut -f 3,4,8 -d " " | \
	while read LINE ; do \
		start=`echo $$LINE | cut -f 1 -d " " | perl -npe '$$_=$$_/100.0'`; \
		len=`echo $$LINE | cut -f 2 -d " " | perl -npe '$$_=$$_/100.0'`; \
		sp_id=`echo $$LINE | cut -f 3 -d " "`; \
		timeformatted=`echo "$$start $$len" | perl -ne '@t=split(); $$start=$$t[0]; $$len=$$t[1]; $$end=$$start+$$len; printf("%08.3f-%08.3f\n", $$start,$$end);'` ; \
		sox build/audio/base/$*.wav --norm $@/$*_$${timeformatted}_$${sp_id}.wav trim $$start $$len ; \
	done

build/audio/segmented/%: build/diarization/%/show.seg
	rm -rf $@
	mkdir -p $@
	cat $^ | cut -f 3,4,8 -d " " | \
	while read LINE ; do \
		start=`echo $$LINE | cut -f 1 -d " " | perl -npe '$$_=$$_/100.0'`; \
		len=`echo $$LINE | cut -f 2 -d " " | perl -npe '$$_=$$_/100.0'`; \
		sp_id=`echo $$LINE | cut -f 3 -d " "`; \
		timeformatted=`echo "$$start $$len" | perl -ne '@t=split(); $$start=$$t[0]; $$len=$$t[1]; $$end=$$start+$$len; printf("%08.3f-%08.3f\n", $$start,$$end);'` ; \
		sox build/audio/base/$*.wav --norm $@/$*_$${timeformatted}_$${sp_id}.wav trim $$start $$len ; \
	done

build/trans/%/wav.scp: build/audio/segmented/%
	mkdir -p `dirname $@`
	/bin/ls $</*.wav  | \
		perl -npe 'chomp; $$orig=$$_; s/.*\/(.*)_(\d+\.\d+-\d+\.\d+)_(S\d+)\.wav/\1-\3---\2/; $$_=$$_ .  " $$orig\n";' | LC_ALL=C sort > $@

build/trans/%/utt2spk: build/trans/%/wav.scp
	cat $^ | perl -npe 's/\s+.*//; s/((.*)---.*)/\1 \2/' > $@

build/trans/%/spk2utt: build/trans/%/utt2spk
	utils/utt2spk_to_spk2utt.pl $^ > $@


# MFCC calculation
build/trans/%/mfcc: build/trans/%/spk2utt
	rm -rf $@
	rm -f build/trans/$*/cmvn.scp
	steps/make_mfcc.sh --mfcc-config conf/mfcc_hires.conf --cmd "$$train_cmd" --nj $(njobs) \
		build/trans/$* build/trans/$*/exp/make_mfcc $@ || exit 1
	steps/compute_cmvn_stats.sh build/trans/$* build/trans/$*/exp/make_mfcc $@ || exit 1


### Do 1-pass decoding using chain online models
build/trans/%/chain_tdnn_bi_online_pruned/decode/log: build/fst/chain_tdnn_bi_online/final.mdl build/fst/chain_tdnn_bi_online/graph_prunedlm build/trans/%/spk2utt build/trans/%/mfcc
	rm -rf build/trans/$*/chain_tdnn_bi_online_pruned
	mkdir -p build/trans/$*/chain_tdnn_bi_online_pruned
	steps/online/nnet2/extract_ivectors_online.sh --cmd "$$decode_cmd" --nj $(njobs) \
        build/trans/$* build/fst/chain_tdnn_bi_online/ivector_extractor build/trans/$*/nnet2_online/ivectors
	(cd build/trans/$*/chain_tdnn_bi_online_pruned; for f in ../../../fst/chain_tdnn_bi_online/*; do ln -s $$f; done)
	steps/nnet3/decode.sh --num-threads $(nthreads) --acwt 1.0  --post-decode-acwt 10.0 \
	    --config conf/decode.conf --skip-scoring true --cmd "$$decode_cmd" --nj $(njobs) \
	    --online-ivector-dir build/trans/$*/nnet2_online/ivectors \
	    --skip-diagnostics true \
      build/fst/chain_tdnn_bi_online/graph_prunedlm build/trans/$* `dirname $@` || exit 1;
	(cd build/trans/$*/chain_tdnn_bi_online_pruned; ln -s ../../../fst/chain_tdnn_bi_online/graph_prunedlm graph)

# Rescore lattices with a larger language model
build/trans/%/chain_tdnn_bi_online_pruned_rescored_main/decode/log: build/trans/%/chain_tdnn_bi_online_pruned/decode/log build/fst/data/largelm
	rm -rf build/trans/$*/chain_tdnn_bi_online_pruned_rescored_main
	mkdir -p build/trans/$*/chain_tdnn_bi_online_pruned_rescored_main
	(cd build/trans/$*/chain_tdnn_bi_online_pruned_rescored_main; for f in ../../../fst/chain_tdnn_bi_online/*; do ln -s $$f; done)
	steps/lmrescore_const_arpa.sh \
	  build/fst/data/prunedlm build/fst/data/largelm \
	  build/trans/$* \
	  build/trans/$*/chain_tdnn_bi_online_pruned/decode build/trans/$*/chain_tdnn_bi_online_pruned_rescored_main/decode || exit 1;
	cp -r --preserve=links build/trans/$*/chain_tdnn_bi_online_pruned/graph build/trans/$*/chain_tdnn_bi_online_pruned_rescored_main/	


%/decode/.ctm: %/decode/log
	steps/get_ctm.sh  `dirname $*` $*/graph $*/decode
	touch -m $@

build/trans/%.segmented.splitw2.ctm: build/trans/%/decode/.ctm
	cat build/trans/$*/decode/score_$(LM_SCALE)/`dirname $*`.ctm  | perl -npe 's/(.*)-(S\d+)---(\S+)/\1_\3_\2/' > $@

%.with-compounds.ctm: %.splitw2.ctm build/fst/data/compounderlm
	scripts/compound-ctm.py \
		"scripts/compounder.py build/fst/data/compounderlm/G.fst build/fst/data/compounderlm/words.txt" \
		< $*.splitw2.ctm > $@

%.segmented.ctm: %.segmented.with-compounds.ctm
	cat $^ | grep -v "++" |  grep -v "\[sil\]" | grep -v -e " $$" | perl -npe 's/\+//g' > $@

%.synced.ctm: %.segmented.ctm
	cat $^ | ./scripts/unsegment-ctm.py | LC_ALL=C sort -k 1,1 -k 3,3n -k 4,4n > $@

%.with-compounds.synced.ctm: %.segmented.with-compounds.ctm
	cat $^ | ./scripts/unsegment-ctm.py | LC_ALL=C sort -k 1,1 -k 3,3n -k 4,4n > $@
	
%.ctm: %.synced.ctm
	cat $^ | grep -v "<" > $@

%.with-sil.ctm: %.ctm
	cat $^ | ./scripts/ctm2with-sil-ctm.py > $@

%.punctuated.synced.txt: %.synced.with-sil.ctm
	cat $^ | cut -f 5 -d " " | perl -npe 's/\n/ /' | $(PUNCTUATE_SYNC_TXT_CMD) > $@

%.synced.txt: %.synced.with-sil.ctm
	cat $^ | cut -f 5 -d " " | perl -npe 's/\n/ /; s/<sil=\S+>//'  > $@


%.hyp: %.segmented.ctm
	cat $^ | ./scripts/segmented-ctm-to-hyp.py > $@

ifeq "yes" "$(DO_SPEAKER_ID)"
ifeq "yes" "$(DO_MUSIC_DETECTION)"
build/trans/%/$(FINAL_PASS).trs: build/trans/%/$(FINAL_PASS)$(DOT_PUNCTUATED).synced.txt build/sid/%/sid-result.txt build/diarization/%/show.seg
	cat build/trans/$*/$(FINAL_PASS)$(DOT_PUNCTUATED).synced.txt | ./scripts/synced-txt-to-trs.py --fid $* --sid build/sid/$*/sid-result.txt  --pms build/diarization/$*/show.pms.seg > $@
else
build/trans/%/$(FINAL_PASS).trs: build/trans/%/$(FINAL_PASS)$(DOT_PUNCTUATED).synced.txt build/sid/%/sid-result.txt 
	cat build/trans/$*/$(FINAL_PASS)$(DOT_PUNCTUATED).synced.txt | ./scripts/synced-txt-to-trs.py --fid $* --sid build/sid/$*/sid-result.txt  > $@
endif	
else
ifeq "yes" "$(DO_MUSIC_DETECTION)"
build/trans/%/$(FINAL_PASS).trs: build/trans/%/$(FINAL_PASS)$(DOT_PUNCTUATED).synced.txt build/diarization/%/show.seg
	cat build/trans/$*/$(FINAL_PASS)$(DOT_PUNCTUATED).synced.txt | ./scripts/synced-txt-to-trs.py --fid $* --pms build/diarization/$*/show.pms.seg > $@
else
build/trans/%/$(FINAL_PASS).trs: build/trans/%/$(FINAL_PASS)$(DOT_PUNCTUATED).synced.txt
	cat build/trans/$*/$(FINAL_PASS)$(DOT_PUNCTUATED).synced.txt | ./scripts/synced-txt-to-trs.py --fid $*  > $@
endif
endif

%.sbv: %.hyp
	cat $^ | ./scripts/hyp2sbv.py > $@
	
%.txt: %.trs
	cat $^  | grep -v "^<" > $@

%.punctuated.hyp: %.hyp
	cat $^ | perl -npe 's/ \(\S+\)$$//' |  hidden-ngram -hidden-vocab $(PUNCTUATOR_HIDDEN_VOCAB) -order 4 -lm $(PUNCTUATOR_LM) -text - -keep-unk | \
	perl -npe 's/ ,COMMA/,/g; s/ \.PERIOD/\./g' > $@.tmp
	cat $^ | perl -npe 's/.*(\(\S+\))$$/ \1/' | paste $@.tmp - > $@
	#rm $@.tmp
	


build/output/%.trs: build/trans/%/$(FINAL_PASS).trs	
	mkdir -p `dirname $@`
	cp $^ $@

build/output/%.ctm: build/trans/%/$(FINAL_PASS).ctm 
	mkdir -p `dirname $@`
	cp $^ $@

build/output/%.txt: build/trans/%/$(FINAL_PASS).txt
	mkdir -p `dirname $@`
	cp $^ $@

build/output/%.with-compounds.ctm: build/trans/%/$(FINAL_PASS).with-compounds.ctm
	mkdir -p `dirname $@`
	cp $^ $@

build/output/%.sbv: build/trans/%/$(FINAL_PASS).sbv
	mkdir -p `dirname $@`
	cp $^ $@

### Speaker ID stuff

# MFCC for Speaker ID, since the features for MFCC are different from speech recognition
build/sid/%/wav.scp: build/trans/%/wav.scp
	mkdir -p `dirname $@`
	ln $^ $@

build/sid/%/utt2spk : build/trans/%/utt2spk
	mkdir -p `dirname $@`
	ln $^ $@

build/sid/%/spk2utt : build/trans/%/spk2utt
	mkdir -p `dirname $@`
	ln $^ $@
	
build/sid/%/mfcc: build/sid/%/wav.scp build/sid/%/utt2spk build/sid/%/spk2utt
	rm -rf $@
	rm -f build/sid/$*/vad.scp
	rm -f build/sid/$*/cmvn.scp
	steps/make_mfcc.sh --mfcc-config conf/mfcc_sid.conf --cmd "$$train_cmd" --nj $(njobs) \
		build/sid/$* build/sid/$*/exp/make_mfcc $@ || exit 1
	steps/compute_cmvn_stats.sh build/sid/$* build/sid/$*/exp/make_mfcc $@ || exit 1
	sid/compute_vad_decision.sh --nj $(njobs) --cmd "$$decode_cmd" \
		build/sid/$* build/sid/$*/exp/make_vad $@  || exit 1

# i-vectors for each speaker in our audio file
build/sid/%/ivectors: build/sid/%/mfcc
	rm -rf build/sid/$*/ivectors
	sid/extract_ivectors.sh --cmd "$$decode_cmd" --nj $(njobs) \
		$(THIS_DIR)/kaldi-data/extractor_2048_top500 build/sid/$* $@

# a cross product of train and test speakers
build/sid/%/sid-trials.txt: build/sid/%/ivectors
	cut -f 1 -d " " $(THIS_DIR)/kaldi-data/ivectors_train_top500/spk_ivector.scp | \
	while read a; do \
		cut -f 1 -d " " build/sid/$*/ivectors/spk_ivector.scp | \
		while read b; do \
			echo "$$a $$b"; \
		done ; \
	done > $@

# similarity scores
build/sid/%/sid-scores.txt: build/sid/%/sid-trials.txt
	ivector-plda-scoring \
		"ivector-copy-plda --smoothing=0.1 $(THIS_DIR)/kaldi-data/ivectors_train_top500/plda - |" \
		"ark:ivector-subtract-global-mean scp:$(THIS_DIR)/kaldi-data/ivectors_train_top500/spk_ivector.scp ark:- |" \
		"ark:ivector-subtract-global-mean scp:build/sid/$*/ivectors/spk_ivector.scp ark:- |" \
   build/sid/$*/sid-trials.txt $@

# pick speakers above the threshold
build/sid/%/sid-result.txt: build/sid/%/sid-scores.txt
	cat build/sid/$*/sid-scores.txt | sort -u -k 2,2  -k 3,3nr | sort -u -k2,2 | \
	awk 'int($$3)>=$(SID_THRESHOLD)' | perl -npe 's/(\S+) \S+-(S\d+) \S+/\2 \1/; s/-/ /g' | \
	LC_ALL=C sort -k 2 | LC_ALL=C join -1 2 - $(THIS_DIR)/kaldi-data/ivectors_train_top500/speaker2names.txt | cut -f 2- -d " " > $@



# Meta-target that deletes all files created during processing a file. Call e.g. 'make .etteytlus2013.clean
.%.clean:
	rm -rf build/audio/base/$*.wav build/audio/segmented/$* build/diarization/$* build/trans/$* build/sid/$*

# Also deletes the output files	
.%.cleanest: .%.clean
	rm -rf build/output/$*.{trs,txt,ctm,with-compounds.ctm,sbv}
