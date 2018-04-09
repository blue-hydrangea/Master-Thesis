#!/bin/bash

#
# Copyright 2013 Bagher BabaAli,
#           2014-2017 Brno University of Technology (Author: Karel Vesely)
#
# TIMIT, description of the database:
# http://perso.limsi.fr/lamel/TIMIT_NISTIR4930.pdf
#
# Hon and Lee paper on TIMIT, 1988, introduces mapping to 48 training phonemes,
# then re-mapping to 39 phonemes for scoring:
# http://repository.cmu.edu/cgi/viewcontent.cgi?article=2768&context=compsci
#

. ./cmd.sh
[ -f path.sh ] && . ./path.sh
set -e
. ../../../tools/env.sh 

# Acoustic model parameters
numLeavesTri1=2500
numGaussTri1=15000
numLeavesMLLT=2500
numGaussMLLT=15000
numLeavesSAT=2500
numGaussSAT=15000
numGaussUBM=400
numLeavesSGMM=7000
numGaussSGMM=9000

feats_nj=4
train_nj=30
decode_nj=5

echo ============================================================================
echo "                Data & Lexicon Preparation                     "
echo ============================================================================

mkdir data
mkdir data/local

timit=/speech/db/eng_US/LVCSR/LDC/TIMIT_LDC93S1/package/timit/TIMIT

local/timit_wrd_data_prep.sh $timit 

local/prepare_dict.sh

local/timit_wrd_prepare_dict.sh

utils/prepare_lang.sh data/local/dict "sil" data/local/lang_tmp data/lang

local/adjust_data_dir.sh

echo ============================================================================
echo "                Language Model Preparation                     "
echo ============================================================================

mkdir data/local/srilm

cp $KALDI_ROOT/egs/iban/s5/local/train_lms_srilm.sh local
cp $KALDI_ROOT/egs/babel/s5/local/arpa2G.sh local

local/train_lms_srilm.sh --words_file data/lang/words.txt --dev-text data/dev/text --train-text data/train/text data data/local/srilm

local/arpa2G.sh data/local/srilm/3gram.kn022.gz data/lang data/lang

echo ============================================================================
echo "         MFCC Feature Extration & CMVN for Training and Test set          "
echo ============================================================================

mfccdir=mfcc

for x in train dev test; do
  steps/make_mfcc.sh --nj $feats_nj --cmd "$train_cmd" data/$x exp/make_mfcc/$x $mfccdir
  steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir
done

echo ============================================================================
echo "                     MonoPhone Training & Decoding                        "
echo ============================================================================

steps/train_mono.sh  --nj "$train_nj" --cmd "$train_cmd" data/train data/lang exp/mono

utils/mkgraph.sh data/lang exp/mono exp/mono/graph

steps/decode.sh --skip-scoring true --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/mono/graph data/dev exp/mono/decode_dev

steps/score_kaldi.sh --cmd "$decode_cmd" --min_lmwt 1 --max_lmwt 10 data/dev exp/mono/graph exp/mono/decode_dev

steps/decode.sh --skip-scoring true --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/mono/graph data/test exp/mono/decode_test

steps/score_kaldi.sh --cmd "$decode_cmd" --min_lmwt 1 --max_lmwt 10 data/test exp/mono/graph exp/mono/decode_test

echo ============================================================================
echo "           tri1 : Deltas + Delta-Deltas Training & Decoding               "
echo ============================================================================

steps/align_si.sh --boost-silence 1.25 --nj "$train_nj" --cmd "$train_cmd" \
 data/train data/lang exp/mono exp/mono_ali

# Train tri1, which is deltas + delta-deltas, on train data.
steps/train_deltas.sh --cmd "$train_cmd" \
 $numLeavesTri1 $numGaussTri1 data/train data/lang exp/mono_ali exp/tri1

utils/mkgraph.sh data/lang exp/tri1 exp/tri1/graph

steps/decode.sh --skip-scoring true --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/tri1/graph data/dev exp/tri1/decode_dev

steps/score_kaldi.sh --cmd "$decode_cmd" --min_lmwt 1 --max_lmwt 10 data/dev exp/tri1/graph exp/tri1/decode_dev

steps/decode.sh --skip-scoring true --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/tri1/graph data/test exp/tri1/decode_test

steps/score_kaldi.sh --cmd "$decode_cmd" --min_lmwt 1 --max_lmwt 10 data/test exp/tri1/graph exp/tri1/decode_test

echo ============================================================================
echo "Training the tri2 AM: LDA+MLLT"
echo ============================================================================

steps/align_si.sh --nj "$train_nj" --cmd "$train_cmd" \
 data/train data/lang exp/tri1 exp/tri1_ali

steps/train_lda_mllt.sh --cmd "$train_cmd" \
 --splice-opts "--left-context=3 --right-context=3" \
 $numLeavesMLLT $numGaussMLLT data/train data/lang exp/tri1_ali exp/tri2

utils/mkgraph.sh data/lang exp/tri2 exp/tri2/graph

steps/decode.sh --skip-scoring true --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/tri2/graph data/dev exp/tri2/decode_dev

steps/score_kaldi.sh --cmd "$decode_cmd" --min_lmwt 1 --max_lmwt 10 data/dev exp/tri2/graph exp/tri2/decode_dev

steps/decode.sh --skip-scoring true --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/tri2/graph data/test exp/tri2/decode_test

steps/score_kaldi.sh --cmd "$decode_cmd" --min_lmwt 1 --max_lmwt 10 data/test exp/tri2/graph exp/tri2/decode_test

echo ============================================================================
echo "              tri3 : LDA + MLLT + SAT                 "
echo ============================================================================

steps/align_si.sh --nj "$train_nj" --cmd "$train_cmd" \
 --use-graphs true data/train data/lang exp/tri2 exp/tri2_ali

steps/train_sat.sh --cmd "$train_cmd" \
 $numLeavesSAT $numGaussSAT data/train data/lang exp/tri2_ali exp/tri3

utils/mkgraph.sh data/lang exp/tri3 exp/tri3/graph

steps/decode_fmllr.sh --skip-scoring true --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/tri3/graph data/dev exp/tri3/decode_dev

steps/score_kaldi.sh --cmd "$decode_cmd" --min_lmwt 1 --max_lmwt 10 data/dev exp/tri3/graph exp/tri3/decode_dev

steps/decode_fmllr.sh --skip-scoring true --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/tri3/graph data/test exp/tri3/decode_test

steps/score_kaldi.sh --cmd "$decode_cmd" --min_lmwt 1 --max_lmwt 10 data/test exp/tri3/graph exp/tri3/decode_test
