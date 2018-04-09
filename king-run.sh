#!/bin/bash

. ./path.sh
. ./cmd.sh
. ../../../tools/env.sh

feats_nj=4
train_nj=30
decode_nj=5

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

echo "-------------------------------------------------"
echo "Preparing the Data and Lexicon"
echo "-------------------------------------------------"


# 1.) Data Preparation

# 1.1.) Splitting the data

# the merged wav.scp, utt2spk, spk2utt and text files are copied from /speech/misc/haggw1/projects/int-nnet3/run/myegs/int/de/data/king/channel0/all
# the script below adjusts the path in wav.scp and splits the data into train, dev and test sets
# train: speakers 21-180, 47990 utterances (90%), 87f 73m
# test: speakers 1-20, 5995 utterances (~10%), 11f 9m
# dev: speakers 181-200, 6000 utterances (~10%), 12f 8m

local/split_data.sh

# 1.2.) Preparing the dictionary

local/prepare_lexicon.sh

local/king_prepare_dict.sh

cat data/local/dict/nonsilence_phones.txt | sed "s/^ //g" | sed "/^$/d" > data/local/dict/non_whitespace.txt
rm data/local/dict/nonsilence_phones.txt
mv data/local/dict/non_whitespace.txt data/local/dict/nonsilence_phones.txt

utils/prepare_lang.sh data/local/dict "<SPOKEN_NOISE>" data/local/lang_tmp data/lang


echo "-------------------------------------------------"
echo "Preparing the Language Model"
echo "-------------------------------------------------"


# 2.) Language Model

cp $KALDI_ROOT/egs/iban/s5/local/train_lms_srilm.sh local
cp $KALDI_ROOT/egs/babel/s5/local/arpa2G.sh local

# 2.1.) Train the LM

local/train_lms_srilm.sh --words_file data/lang/words.txt --dev-text data/dev/text --train-text data/train/text data data/local/srilm

# 2.2.) Create G.fst

local/arpa2G.sh data/local/srilm/4gram.gt0111.gz data/lang data/lang


echo "-------------------------------------------------"
echo "Extracting MFCC Features"
echo "-------------------------------------------------"


# 3.) Extract MFCC features

mfccdir=mfcc

for x in test dev train ; do
 steps/make_mfcc.sh --nj $feats_nj --cmd "$train_cmd" data/$x exp/make_mfcc/$x $mfccdir ; \
 steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir ;
done


echo "-------------------------------------------------"
echo "Training the Monophone AM"
echo "-------------------------------------------------"


# 4.) Train the Monophone AM

steps/train_mono.sh  --nj "$train_nj" --cmd "$train_cmd" data/train data/lang exp/mono

utils/mkgraph.sh data/lang exp/mono exp/mono/graph

steps/decode.sh --skip-scoring true --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/mono/graph data/dev exp/mono/decode_dev

steps/score_kaldi.sh --cmd "$decode_cmd" --min_lmwt 1 --max_lmwt 10 data/dev exp/mono/graph exp/mono/decode_dev

steps/decode.sh --skip-scoring true --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/mono/graph data/test exp/mono/decode_test

steps/score_kaldi.sh --cmd "$decode_cmd" --min_lmwt 1 --max_lmwt 10 data/test exp/mono/graph exp/mono/decode_test


echo "-------------------------------------------------"
echo "Training the Triphone AM"
echo "-------------------------------------------------"


# 5.) Extend the Monophone Model to a Triphone Model

steps/align_si.sh --boost-silence 1.25 --nj "$train_nj" --cmd "$train_cmd" \
 data/train data/lang exp/mono exp/mono_ali

steps/train_deltas.sh --cmd "$train_cmd" \
 $numLeavesTri1 $numGaussTri1 data/train data/lang exp/mono_ali exp/tri1

utils/mkgraph.sh data/lang exp/tri1 exp/tri1/graph

steps/decode.sh --skip-scoring true --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/tri1/graph data/dev exp/tri1/decode_dev

steps/score_kaldi.sh --cmd "$decode_cmd" --min_lmwt 1 --max_lmwt 10 data/dev exp/tri1/graph exp/tri1/decode_dev

steps/decode.sh --skip-scoring true --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/tri1/graph data/test exp/tri1/decode_test

steps/score_kaldi.sh --cmd "$decode_cmd" --min_lmwt 1 --max_lmwt 10 data/test exp/tri1/graph exp/tri1/decode_test


echo "-------------------------------------------------"
echo "Training the tri2 AM: LDA+MLLT"
echo "-------------------------------------------------"


# 6.) Train LDA + MLLT on top of tri1 to obtain tri2

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


echo "-------------------------------------------------"
echo "              tri3 : LDA + MLLT + SAT                 "
echo "-------------------------------------------------"


# 7.) Train SAT on top of tri2 to obtain tri3

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

