#!/bin/bash

# created by Sabrina Beer (MT student at the SSG; Wilhelm Hagg)
# date of origin: 15.03.2018
# this script trains an ASR system on the German corpus from the TU Darmstadt

#-----------------------------------------------------------------------------------------------------------------------

. ./path.sh
. ./cmd.sh
. ../../../env.sh

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

# 1.) Get the data and the lexicon ready. This means (a) adjusting the path to the data in all wav.scp (b) removing { ' , - } from the lexicon, adding whitespaces between phones, and obtaining the phone inventory

local/prepare_data.sh

local/prepare_lexicon.sh

local/tuda_prepare_dict.sh

cat data/local/dict/nonsilence_phones.txt | sed "s/^ //" | sed "/^$/d" > data/local/dict/nonsilence_fixed.txt
rm data/local/dict/nonsilence_phones.txt
mv data/local/dict/nonsilence_fixed.txt data/local/dict/nonsilence_phones.txt

utils/prepare_lang.sh data/local/dict "<SPOKEN_NOISE>" data/local/lang_tmp data/lang

echo "-------------------------------------------------"
echo "Preparing the Language Model"
echo "-------------------------------------------------"

# 2.) Train an LM

cp $KALDI_ROOT/egs/iban/s5/local/train_lms_srilm.sh local
cp $KALDI_ROOT/egs/babel/s5/local/arpa2G.sh local

local/train_lms_srilm.sh --words_file data/lang/words.txt --dev-text data/dev/text --train-text data/train/text data data/local/srilm

local/arpa2G.sh data/local/srilm/4gram.kn0123.gz data/lang data/lang

echo "-------------------------------------------------"
echo "Extracting MFCC Features"
echo "-------------------------------------------------"

# 3.) Extract Features

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

exit

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


