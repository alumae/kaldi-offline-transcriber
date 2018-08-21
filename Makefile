SHELL := /bin/bash

# Use this file to override various settings
-include Makefile.options

DO_MUSIC_DETECTION?=yes

# Set to 'yes' if you want to do speaker ID for trs files
# Assumes you have models for speaker ID
DO_SPEAKER_ID?=no
SID_SIMILARITY_THRESHOLD?=10

# Where is Kaldi root directory?
KALDI_ROOT?=/home/speech/tools/kaldi-trunk

# Location of the Java binary
JAVA_BIN?=/usr/bin/java

# How many processes to use for one transcription task
njobs ?= 1

# How many threads to use in each process
nthreads ?= 1

PATH:=utils:$(KALDI_ROOT)/src/bin:$(KALDI_ROOT)/tools/openfst/bin:$(KALDI_ROOT)/src/fstbin/:$(KALDI_ROOT)/src/gmmbin/:$(KALDI_ROOT)/src/featbin/:$(KALDI_ROOT)/src/lm/:$(KALDI_ROOT)/src/sgmmbin/:$(KALDI_ROOT)/src/sgmm2bin/:$(KALDI_ROOT)/src/fgmmbin/:$(KALDI_ROOT)/src/latbin/:$(KALDI_ROOT)/src/nnet2bin/:$(KALDI_ROOT)/src/online2bin/:$(KALDI_ROOT)/src/kwsbin:$(KALDI_ROOT)/src/lmbin:$(PATH):$(KALDI_ROOT)/src/ivectorbin:$(KALDI_ROOT)/src/nnet3bin:$(KALDI_ROOT)/src/rnnlmbin:$(PATH)

# Needed for compounder.py
LD_LIBRARY_PATH:=$(KALDI_ROOT)/tools/openfst/lib:$(LD_LIBRARY_PATH)

export train_cmd=run.pl
export decode_cmd=run.pl
export cuda_cmd=run.pl
export mkgraph_cmd=run.pl

# Main language model (should be slightly pruned), used for rescoring
LM ?=language_model/pruned.vestlused-dev.splitw2.arpa.gz

# More aggressively pruned LM, used in decoding
PRUNED_LM ?=language_model/pruned6.vestlused-dev.splitw2.arpa.gz

RNNLM_MODEL ?=language_model/rnnlm.vestlused-dev

COMPOUNDER_LM ?=language_model/compounder-pruned.vestlused-dev.splitw.arpa.gz

ACOUSTIC_MODEL?=tdnn_7d_online

# Vocabulary in dict format (no pronouncation probs for now)
VOCAB?=language_model/vestlused-dev.splitw2.with_long.dict

ET_G2P_FST?=../et-g2p-fst

LM_SCALE?=10

DO_PUNCTUATION?=no

ifeq "yes" "$(DO_PUNCTUATION)"
  PUNCTUATE_SYNC_TXT_CMD?=(cd ~/tools/punctuator/src; python2.7 wrapper.py)
  DOT_PUNCTUATED=.punctuated
endif


# Find out where this Makefile is located (this is not really needed)
where-am-i = $(lastword $(MAKEFILE_LIST))
THIS_DIR := $(shell dirname $(call where-am-i))

FINAL_PASS=$(ACOUSTIC_MODEL)_pruned_rescored_main_rnnlm_unk

LD_LIBRARY_PATH:=$(KALDI_ROOT)/tools/openfst/lib:$(LD_LIBRARY_PATH)

.SECONDARY:
.DELETE_ON_ERROR:

PYTHONIOENCODING="utf-8"

export

# Call this (once) before using the system
.init: .kaldi .lang

.kaldi:
	rm -f steps utils sid rnnlm
	ln -s $(KALDI_ROOT)/egs/wsj/s5/steps
	ln -s $(KALDI_ROOT)/egs/wsj/s5/utils
	ln -s $(KALDI_ROOT)/egs/sre08/v1/sid
	ln -s $(KALDI_ROOT)/scripts/rnnlm
	mkdir -p src-audio

.lang: build/fst/data/prunedlm_unk build/fst/$(ACOUSTIC_MODEL)/graph_prunedlm_unk build/fst/data/largelm_unk build/fst/data/rnnlm_unk build/fst/data/compounderlm

build/fst/$(ACOUSTIC_MODEL)/final.mdl:
	rm -rf `dirname $@`
	mkdir -p `dirname $@`
	cp -r $(THIS_DIR)/kaldi-data/$(ACOUSTIC_MODEL)/* `dirname $@`
	perl -i -npe 's#=.*online/#=build/fst/$(ACOUSTIC_MODEL)/#' build/fst/$(ACOUSTIC_MODEL)/conf/*.conf
	if [ ! -e build/fst/$(ACOUSTIC_MODEL)/cmvn_opts ]; then \
		echo "--norm-means=false --norm-vars=false" > build/fst/$(ACOUSTIC_MODEL)/cmvn_opts; \
	fi

build/fst/data/dict/.done: $(VOCAB) build/fst/$(ACOUSTIC_MODEL)/final.mdl
	rm -rf build/fst/data/dict
	mkdir -p build/fst/data/dict
	cp -r $(THIS_DIR)/kaldi-data/dict/* build/fst/data/dict
	rm -f build/fst/data/dict/lexicon.txt build/fst/data/dict/lexiconp.txt
	cat models/etc/filler16k.dict | egrep -v "^<.?s>"   > build/fst/data/dict/lexicon.txt
	cat $(VOCAB) | perl -npe 's/\(\d\)(\s)/\1/' >> build/fst/data/dict/lexicon.txt
	touch -m $@

build/fst/data/prunedlm: $(PRUNED_LM) $(VOCAB) build/fst/$(ACOUSTIC_MODEL)/final.mdl build/fst/data/dict/.done
	rm -rf build/fst/data/prunedlm
	mkdir -p build/fst/data/prunedlm
	utils/prepare_lang.sh --phone-symbol-table build/fst/$(ACOUSTIC_MODEL)/phones.txt build/fst/data/dict '<unk>' build/fst/data/dict/tmp build/fst/data/prunedlm
	gunzip -c $(PRUNED_LM) | arpa2fst --disambig-symbol=#0 \
		--read-symbol-table=build/fst/data/prunedlm/words.txt - build/fst/data/prunedlm/G.fst
	echo "Checking how stochastic G is (the first of these numbers should be small):"
	fstisstochastic build/fst/data/prunedlm/G.fst || echo "not stochastic (probably OK)"	
	utils/validate_lang.pl build/fst/data/prunedlm || exit 1

build/fst/data/unk_lang_model: build/fst/data/dict/.done
	rm -rf $@
	utils/lang/make_unk_lm.sh build/fst/data/dict $@

build/fst/data/prunedlm_unk: build/fst/data/unk_lang_model build/fst/data/prunedlm
	rm -rf $@
	utils/prepare_lang.sh --unk-fst build/fst/data/unk_lang_model/unk_fst.txt build/fst/data/dict "<unk>" build/fst/data/prunedlm $@
	cp build/fst/data/prunedlm/G.fst $@
	
build/fst/%/graph_prunedlm_unk: build/fst/data/prunedlm_unk build/fst/%/final.mdl
	rm -rf $@
	self_loop_scale_arg=""; \
	if [ -f build/fst/$*/frame_subsampling_factor ]; then \
	  factor=`cat build/fst/$*/frame_subsampling_factor`; \
	  if [ $$factor -eq "3" ]; then \
	    self_loop_scale_arg="--self-loop-scale 1.0 "; \
	  fi; \
	fi; \
	utils/mkgraph.sh $$self_loop_scale_arg build/fst/data/prunedlm_unk build/fst/$* $@

build/fst/data/largelm_unk: build/fst/data/prunedlm
	rm -rf $@
	mkdir -p $@	
	utils/build_const_arpa_lm.sh \
		$(LM) build/fst/data/prunedlm $@
	
build/fst/data/rnnlm_unk: $(RNNLM_MODEL) build/fst/data/prunedlm
	rm -rf $@
	mkdir -p $@
	cp -r $(RNNLM_MODEL)/* $@/
	cp build/fst/data/prunedlm/words.txt $@/config/words.txt
	brk_id=`cat $@/config/words.txt | wc -l`; \
	echo "<brk> $$brk_id" >> $@/config/words.txt; \
	bos_id=`grep "^<s>" $@/config/words.txt  | awk '{print $$2}'`; \
	eos_id=`grep "^</s>" $@/config/words.txt  | awk '{print $$2}'`; \
	echo "--eos-symbol=$${eos_id} --brk-symbol=$${brk_id} --bos-symbol=$${bos_id}" > $@/special_symbol_opts.txt
	rnnlm/get_word_features.py \
	  --unigram-probs $@/config/unigram_probs.txt \
	  build/fst/data/prunedlm/words.txt \
	  $@/config/features.txt \
		> $@/word_feats.txt

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
	ffmpeg -i $^ -f sox - | sox -t sox - -c 1 -2 $@ rate -v 16k

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

build/trans/%/wav.scp:
	mkdir -p build/trans/$*
	echo "$* build/audio/base/$*.wav" > $@

build/trans/%/reco2file_and_channel:
	echo "$* $* A" > $@

build/trans/%/segments: build/diarization/%/show.seg build/trans/%/wav.scp build/trans/%/reco2file_and_channel
	cat build/diarization/$*/show.seg | cut -f 3,4,8 -d " " | \
	while read LINE ; do \
		start=`echo $$LINE | cut -f 1,2 -d " " | perl -ne '@t=split(); $$start=$$t[0]/100.0; printf("%08.3f", $$start);'`; \
		end=`echo $$LINE   | cut -f 1,2 -d " " | perl -ne '@t=split(); $$start=$$t[0]/100.0; $$len=$$t[1]/100.0; $$end=$$start+$$len; printf("%08.3f", $$end);'`; \
		sp_id=`echo $$LINE | cut -f 3 -d " "`; \
		echo $*-$${sp_id}---$${start}-$${end} $* $$start $$end; \
	done > $@
	
build/trans/%/utt2spk: build/trans/%/segments
	cat $^ | perl -npe 's/\s+.*//; s/((.*)---.*)/\1 \2/' > $@

build/trans/%/spk2utt: build/trans/%/utt2spk
	utils/utt2spk_to_spk2utt.pl $^ > $@


# MFCC calculation
build/trans/%/mfcc: build/trans/%/spk2utt build/fst/$(ACOUSTIC_MODEL)/final.mdl
	rm -rf $@
	rm -f build/trans/$*/cmvn.scp
	steps/make_mfcc.sh --mfcc-config build/fst/$(ACOUSTIC_MODEL)/conf/mfcc.conf --cmd "$$decode_cmd" --nj $(njobs) \
		build/trans/$* build/trans/$*/exp/make_mfcc $@ || exit 1
	steps/compute_cmvn_stats.sh build/trans/$* build/trans/$*/exp/make_mfcc $@ || exit 1
	utils/fix_data_dir.sh build/trans/$*
	# Touch files that utils/fix_data_dir.sh might modify, in the right order
	# so that make will not try to remake them
	touch -m build/trans/$*/wav.scp
	touch -m build/trans/$*/segments
	touch -m build/trans/$*/utt2spk
	touch -m build/trans/$*/spk2utt
	touch -m $@

build/trans/%/ivectors: build/trans/%/mfcc
	rm -rf $@	
	steps/online/nnet2/extract_ivectors_online.sh --cmd "$$decode_cmd" --nj $(njobs) \
		build/trans/$* build/fst/$(ACOUSTIC_MODEL)/ivector_extractor $@ || exit 1;

### Do 1-pass decoding using chain online models
build/trans/%/$(ACOUSTIC_MODEL)_pruned_unk/decode/log: build/fst/$(ACOUSTIC_MODEL)/final.mdl build/fst/$(ACOUSTIC_MODEL)/graph_prunedlm_unk build/trans/%/spk2utt build/trans/%/mfcc build/trans/%/ivectors
	rm -rf build/trans/$*/$(ACOUSTIC_MODEL)_pruned_unk
	mkdir -p build/trans/$*/$(ACOUSTIC_MODEL)_pruned_unk
	(cd build/trans/$*/$(ACOUSTIC_MODEL)_pruned_unk; for f in ../../../fst/$(ACOUSTIC_MODEL)/*; do ln -s $$f; done)
	steps/nnet3/decode.sh --num-threads $(nthreads) --acwt 1.0  --post-decode-acwt 10.0 \
	    --skip-scoring true --cmd "$$decode_cmd" --nj $(njobs) \
	    --online-ivector-dir build/trans/$*/ivectors \
	    --skip-diagnostics true \
      build/fst/$(ACOUSTIC_MODEL)/graph_prunedlm_unk build/trans/$* `dirname $@` || exit 1;
	(cd build/trans/$*/$(ACOUSTIC_MODEL)_pruned_unk; ln -s ../../../fst/$(ACOUSTIC_MODEL)/graph_prunedlm_unk graph)

# Rescore lattices with a larger language model
build/trans/%/$(ACOUSTIC_MODEL)_pruned_rescored_main_unk/decode/log: build/trans/%/$(ACOUSTIC_MODEL)_pruned_unk/decode/log build/fst/data/largelm_unk
	rm -rf build/trans/$*/$(ACOUSTIC_MODEL)_pruned_rescored_main_unk
	mkdir -p build/trans/$*/$(ACOUSTIC_MODEL)_pruned_rescored_main_unk
	(cd build/trans/$*/$(ACOUSTIC_MODEL)_pruned_rescored_main_unk; for f in ../../../fst/$(ACOUSTIC_MODEL)/*; do ln -s $$f; done)
	steps/lmrescore_const_arpa.sh \
	  build/fst/data/prunedlm_unk build/fst/data/largelm_unk \
	  build/trans/$* \
	  build/trans/$*/$(ACOUSTIC_MODEL)_pruned_unk/decode build/trans/$*/$(ACOUSTIC_MODEL)_pruned_rescored_main_unk/decode || exit 1;
	cp -r --preserve=links build/trans/$*/$(ACOUSTIC_MODEL)_pruned_unk/graph build/trans/$*/$(ACOUSTIC_MODEL)_pruned_rescored_main_unk/	


build/trans/%/$(ACOUSTIC_MODEL)_pruned_rescored_main_rnnlm_unk/decode/log: build/trans/%/$(ACOUSTIC_MODEL)_pruned_rescored_main_unk/decode/log build/fst/data/rnnlm_unk
	rm -rf build/trans/$*/$(ACOUSTIC_MODEL)_pruned_rescored_main_rnnlm_unk
	mkdir -p build/trans/$*/$(ACOUSTIC_MODEL)_pruned_rescored_main_rnnlm_unk
	(cd build/trans/$*/$(ACOUSTIC_MODEL)_pruned_rescored_main_rnnlm_unk; for f in ../../../fst/$(ACOUSTIC_MODEL)/*; do ln -s $$f; done)
	rnnlm/lmrescore_pruned.sh \
	    --skip-scoring true \
	    --max-ngram-order 4 \
      build/fst/data/largelm_unk \
      build/fst/data/rnnlm_unk \
      build/trans/$* \
	    build/trans/$*/$(ACOUSTIC_MODEL)_pruned_rescored_main_unk/decode \
      build/trans/$*/$(ACOUSTIC_MODEL)_pruned_rescored_main_rnnlm_unk/decode
	cp -r --preserve=links build/trans/$*/$(ACOUSTIC_MODEL)_pruned_unk/graph build/trans/$*/$(ACOUSTIC_MODEL)_pruned_rescored_main_rnnlm_unk/	


%/decode/.ctm: %/decode/log
	frame_shift_opt=""; \
	if [ -f $*/frame_subsampling_factor ]; then \
	  factor=`cat $*/frame_subsampling_factor`; \
	  frame_shift_opt="--frame-shift 0.0$$factor"; \
	fi; \
	steps/get_ctm.sh $$frame_shift_opt `dirname $*` $*/graph $*/decode
	touch -m $@

%_unk/decode/.ctm: %_unk/decode/log
	frame_shift_opt=""; \
	if [ -f  $*_unk/frame_subsampling_factor ]; then \
	  factor=`cat $*_unk/frame_subsampling_factor`; \
	  frame_shift_opt="--frame-shift 0.0$$factor"; \
	fi; \
	$(THIS_DIR)/local/get_ctm_unk.sh --use_segments false $$frame_shift_opt \
	  --unk-p2g-cmd "python3 $(THIS_DIR)/local/unk_p2g.py --p2g-cmd 'python3 $(ET_G2P_FST)/g2p.py --inverse --fst  $(ET_G2P_FST)/data/chars.fst --nbest 1'" \
	  --unk-word '<unk>' \
	  --min-lmwt $(LM_SCALE) \
	  --max-lmwt $(LM_SCALE) \
	  `dirname $*` $*_unk/graph $*_unk/decode
	touch -m $@



build/trans/%.segmented.splitw2.ctm: build/trans/%/decode/.ctm
	cat build/trans/$*/decode/score_$(LM_SCALE)/`dirname $*`.ctm  | perl -npe 's/(.*)-(S\d+)---(\S+)/\1_\3_\2/' > $@

%.with-compounds.ctm: %.splitw2.ctm build/fst/data/compounderlm	
	python3 scripts/compound-ctm.py \
		"python3 scripts/compounder.py build/fst/data/compounderlm/G.fst build/fst/data/compounderlm/words.txt" \
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
	cat build/trans/$*/$(FINAL_PASS)$(DOT_PUNCTUATED).synced.txt | ./scripts/synced-txt-to-trs.py --fid $* > $@
endif
endif

build/trans/%/$(FINAL_PASS).sbv: build/trans/%/$(FINAL_PASS)$(DOT_PUNCTUATED).synced.txt
	cat build/trans/$*/$(FINAL_PASS)$(DOT_PUNCTUATED).synced.txt | ./scripts/synced-txt-to-trs.py --output-sbv > $@

build/trans/%/$(FINAL_PASS).srt: build/trans/%/$(FINAL_PASS)$(DOT_PUNCTUATED).synced.txt
	cat build/trans/$*/$(FINAL_PASS)$(DOT_PUNCTUATED).synced.txt | ./scripts/synced-txt-to-trs.py --output-srt > $@

%.txt: %.trs
	cat $^  | grep -v "^<" > $@

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

build/output/%.srt: build/trans/%/$(FINAL_PASS).srt
	mkdir -p `dirname $@`
	cp $^ $@


### Speaker ID stuff

# MFCC for Speaker ID, since the features for MFCC are different from speech recognition
build/sid/%/wav.scp: build/trans/%/wav.scp
	mkdir -p `dirname $@`
	rm -f $@
	ln $^ $@

build/sid/%/utt2spk : build/trans/%/utt2spk
	mkdir -p `dirname $@`
	rm -f $@
	ln $^ $@

build/sid/%/spk2utt : build/trans/%/spk2utt
	mkdir -p `dirname $@`
	rm -f $@
	ln $^ $@

build/sid/%/segments : build/trans/%/segments
	mkdir -p `dirname $@`
	rm -f $@
	ln $^ $@

	
build/sid/%/mfcc: build/sid/%/wav.scp build/sid/%/utt2spk build/sid/%/spk2utt build/sid/%/segments
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
		$(THIS_DIR)/kaldi-data/sid/extractor_2048 build/sid/$* $@

# cross-product between trained speakers and diarized speakers
build/sid/%/trials: build/sid/%/ivectors
	join -j 2 \
		<(cut -d " " -f 1 kaldi-data/sid/name_ivector.scp | sort ) \
		<(cut -d " " -f 1 build/sid/$*/ivectors/spk_ivector.scp | sort ) > $@
  
build/sid/%/lda_plda_scores: build/sid/%/trials
	ivector-plda-scoring --normalize-length=true \
		"ivector-copy-plda --smoothing=0.3 kaldi-data/sid/lda_plda - |" \
	  "ark:ivector-subtract-global-mean scp:kaldi-data/sid//name_ivector.scp ark:- | transform-vec kaldi-data/sid/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
	  "ark:ivector-subtract-global-mean kaldi-data/sid/mean.vec scp:build/sid/$*/ivectors/spk_ivector.scp ark:- | transform-vec kaldi-data/sid/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
	  build/sid/$*/trials $@

build/sid/%/sid-result.txt: build/sid/%/lda_plda_scores
	cat build/sid/$*/lda_plda_scores | sort -k2,2 -k3,3nr | awk '{print $$3, $$1, $$2}' | uniq -f2 | awk '{if ($$1 > $(SID_SIMILARITY_THRESHOLD)) {print $$3, $$2}}' | \
	perl -npe 's/^\S+-(S\d+)/\1/; s/_/ /g;' > $@


# Meta-target that deletes all files created during processing a file. Call e.g. 'make .etteytlus2013.clean
.%.clean:
	rm -rf build/audio/base/$*.wav build/audio/segmented/$* build/diarization/$* build/trans/$* build/sid/$*

# Also deletes the output files	
.%.cleanest: .%.clean
	rm -rf build/output/$*.{trs,txt,ctm,with-compounds.ctm,sbv}
