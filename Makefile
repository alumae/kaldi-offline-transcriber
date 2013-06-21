SHELL := /bin/bash

# Use this file to override various settings
-include Makefile.options

# Where is Kaldi root directory?
KALDI_ROOT?=/home/speech/tools/kaldi-trunk

# How many processes to use for one transcription task
njobs ?= 1

PATH := utils:$(KALDI_ROOT)/src/bin:$(KALDI_ROOT)/tools/openfst/bin:$(KALDI_ROOT)/src/fstbin/:$(KALDI_ROOT)/src/gmmbin/:$(KALDI_ROOT)/src/featbin/:$(KALDI_ROOT)/src/lm/:$(KALDI_ROOT)/src/sgmmbin/:$(KALDI_ROOT)/src/sgmm2bin/:$(KALDI_ROOT)/src/fgmmbin/:$(KALDI_ROOT)/src/latbin/:$(KALDI_ROOT)/src/nnetbin:$(KALDI_ROOT)/src/nnet-cpubin/:$(KALDI_ROOT)/src/kwsbin:$(PATH)
export train_cmd=run.pl
export decode_cmd=run.pl
export cuda_cmd=run.pl
export mkgraph_cmd=run.pl

# Main language model (should be slightly pruned), used for rescoring
LM ?=language_model/pruned.vestlused-dev.splitw2.arpa.gz

# More aggressively pruned LM, used in decoding
PRUNED_LM ?=language_model/pruned5.vestlused-dev.splitw2.arpa.gz

COMPOUNDER_LM ?=language_model/compounder-pruned.vestlused-dev.splitw.arpa.gz


# Vocabulary in dict format (no pronouncation probs for now)
VOCAB?=language_model/vestlused-dev.splitw2.dict

LM_SCALE?=17

# Find out where this Makefile is located (this is not really needed)
where-am-i = $(lastword $(MAKEFILE_LIST))
THIS_DIR := $(shell dirname $(call where-am-i))

FINAL_PASS=nnet5c1_pruned_rescored_main

LD_LIBRARY_PATH=$(KALDI_ROOT)/tools/openfst/lib

.SECONDARY:
.DELETE_ON_ERROR:

export

# Call this (once) before using the system
.init: .kaldi .lang .composed_lms

.kaldi:
	rm -f steps utils
	ln -s $(KALDI_ROOT)/egs/wsj/s5/steps
	ln -s $(KALDI_ROOT)/egs/wsj/s5/utils
	mkdir -p src-audio

.lang: build/fst/data/mainlm build/fst/data/prunedlm build/fst/data/compounderlm

.composed_lms: build/fst/tri3b/graph_prunedlm 

# Convert dict and LM to FST format
build/fst/data/dict build/fst/data/mainlm: $(LM) $(VOCAB)
	rm -rf build/fst/data/dict build/fst/data/mainlm
	mkdir -p build/fst/data/dict build/fst/data/mainlm
	cp -r $(THIS_DIR)/kaldi-data/dict/* build/fst/data/dict
	rm build/fst/data/dict/lexicon.txt
	cat models/etc/filler16k.dict | egrep -v "^<.?s>"   > build/fst/data/dict/lexicon.txt
	cat $(VOCAB) | perl -npe 's/\(\d\)(\s)/\1/' >> build/fst/data/dict/lexicon.txt
	utils/prepare_lang.sh build/fst/data/dict "++garbage++" build/fst/data/dict/tmp build/fst/data/mainlm
	gunzip -c $(LM) | \
		grep -v '<s> <s>' | \
		grep -v '</s> <s>' | \
		grep -v '</s> </s>' | \
		arpa2fst - | fstprint | \
		utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=build/fst/data/mainlm/words.txt \
			--osymbols=build/fst/data/mainlm/words.txt  --keep_isymbols=false --keep_osymbols=false | \
		 fstrmepsilon > build/fst/data/mainlm/G.fst
	fstisstochastic build/fst/data/mainlm/G.fst || echo "Warning: LM not stochastic"


build/fst/data/prunedlm: build/fst/data/mainlm $(PRUNED_LM)
	rm -rf $@
	mkdir -p $@
	cp -r build/fst/data/mainlm/* $@
	rm $@/G.fst
	gunzip -c $(PRUNED_LM) | \
		grep -v '<s> <s>' | \
		grep -v '</s> <s>' | \
		grep -v '</s> </s>' | \
		arpa2fst - | fstprint | \
		utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=$@/words.txt \
			--osymbols=$@/words.txt  --keep_isymbols=false --keep_osymbols=false | \
		 fstrmepsilon > $@/G.fst
	fstisstochastic $@/G.fst || echo "Warning: LM not stochastic"


build/fst/data/compounderlm: $(COMPOUNDER_LM) $(VOCAB)
	rm -rf $@
	mkdir -p $@
	cat $(VOCAB) | perl -npe 's/(\(\d\))?\s.+//' | uniq | python scripts/make-compounder-symbols.py > $@/words.txt
	zcat $(COMPOUNDER_LM) | \
		grep -v '<s> <s>' | \
		grep -v '</s> <s>' | \
		grep -v '</s> </s>' | \
		arpa2fst  - | fstprint | \
		utils/s2eps.pl | fstcompile --isymbols=$@/words.txt --osymbols=$@/words.txt > $@/G.fst 
		

build/fst/%/final.mdl:
	cp -r $(THIS_DIR)/kaldi-data/$* `dirname $@`
	
build/fst/%/graph_mainlm: build/fst/data/mainlm build/fst/%/final.mdl
	rm -rf $@
	utils/mkgraph.sh build/fst/data/mainlm build/fst/$* $@

build/fst/%/graph_prunedlm: build/fst/data/prunedlm build/fst/%/final.mdl
	rm -rf $@
	utils/mkgraph.sh build/fst/data/prunedlm build/fst/$* $@

build/audio/base/%.wav: src-audio/%.wav
	mkdir -p `dirname $@`
	sox $^ -c 1 -2 build/audio/base/$*.wav rate -v 16k

build/audio/base/%.wav: src-audio/%.mp3
	mkdir -p `dirname $@`
	sox $^ -c 1 build/audio/base/$*.wav rate -v 16k

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
	./scripts/diarization.sh $^ `dirname $@`/show.uem.seg;


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
	steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --cmd "$$train_cmd" --nj $(njobs) \
		build/trans/$* build/trans/$*/exp/make_mfcc $@ || exit 1
	steps/compute_cmvn_stats.sh build/trans/$* build/trans/$*/exp/make_mfcc $@ || exit 1;
	
# First, decode using tri3b_mmi (LDA+MLLT+SAT+MMI trained triphones)
build/trans/%/tri3b_mmi_pruned/decode/log: build/fst/tri3b/graph_prunedlm build/fst/tri3b/final.mdl build/fst/tri3b_mmi/final.mdl build/trans/%/mfcc
	rm -rf build/trans/$*/tri3b_mmi_pruned
	mkdir -p build/trans/$*/tri3b_mmi_pruned
	(cd build/trans/$*/tri3b_mmi_pruned; for f in ../../../fst/tri3b_mmi/*; do ln -s $$f; done)
	steps/decode_fmllr.sh --config conf/decode.conf --skip-scoring true --nj $(njobs) --cmd "$$decode_cmd" \
	  --alignment-model build/fst/tri3b/final.alimdl --adapt-model build/fst/tri3b/final.mdl \
		build/fst/tri3b/graph_prunedlm build/trans/$* `dirname $@`
	(cd build/trans/$*/tri3b_mmi_pruned; ln -s ../../../fst/tri3b/graph_prunedlm graph)

# Now, decode using nnet AM, using speaker transforms from tri3b_mmi
build/trans/%/nnet5c1_pruned/decode/log: build/trans/%/tri3b_mmi_pruned/decode/log build/fst/nnet5c1/final.mdl
	rm -rf build/trans/$*/nnet5c1_pruned
	mkdir -p build/trans/$*/nnet5c1_pruned
	(cd build/trans/$*/nnet5c1_pruned; for f in ../../../fst/nnet5c1/*; do ln -s $$f; done)
	steps/decode_nnet_cpu.sh --skip-scoring true --cmd "$$decode_cmd" --nj $(njobs) \
    --transform-dir build/trans/$*/tri3b_mmi_pruned/decode \
     build/fst/tri3b/graph_prunedlm build/trans/$* `dirname $@`
	(cd build/trans/$*/nnet5c1_pruned; ln -s ../../../fst/tri3b/graph_prunedlm graph)

build/trans/%/nnet5c1_pruned_rescored_main/decode/log: build/trans/%/nnet5c1_pruned/decode/log build/fst/data/mainlm
	rm -rf build/trans/$*/nnet5c1_pruned_rescored_main
	mkdir -p build/trans/$*/nnet5c1_pruned_rescored_main
	(cd build/trans/$*/nnet5c1_pruned_rescored_main; for f in ../../../fst/nnet5c1/*; do ln -s $$f; done)
	steps/lmrescore.sh --cmd "$$decode_cmd" --mode 1 build/fst/data/prunedlm build/fst/data/mainlm \
		build/trans/$* build/trans/$*/nnet5c1_pruned/decode build/trans/$*/nnet5c1_pruned_rescored_main/decode || exit 1;
	(cd build/trans/$*/nnet5c1_pruned_rescored_main; ln -s ../../../fst/tri3b/graph_prunedlm graph)

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

%.ctm: %.segmented.ctm
	cat $^ | python scripts/unsegment-ctm.py | LC_ALL=C sort -k 1,1 -k 3,3n -k 4,4n > $@

%.with-compounds.ctm: %.segmented.with-compounds.ctm
	cat $^ | python scripts/unsegment-ctm.py | LC_ALL=C sort -k 1,1 -k 3,3n -k 4,4n > $@

%.hyp: %.segmented.ctm
	cat $^ | python scripts/segmented-ctm-to-hyp.py > $@
	
%.trs: %.hyp
	cat $^ | python scripts/hyp2trs.py > $@

%.sbv: %.hyp
	cat $^ | python scripts/hyp2sbv.py > $@
	
%.txt: %.hyp
	cat $^  | perl -npe 'use locale; s/ \(\S+\)/\./; $$_= ucfirst();' > $@
	
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

	
	
# Meta-target that deletes all files created during processing a file. Call e.g. 'make .etteytlus2013.clean
.%.clean:
	rm -rf build/audio/$* rm -rf build/diarization/$* rm -rf build/trans/$*

# Also deletes the output files	
.%.cleanest: .%.clean
	rm -rf build/output/$*.{trs,txt,ctm,with-compounds.ctm}
