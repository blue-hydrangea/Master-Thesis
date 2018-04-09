#!/bin/bash

. ./path.sh

copy-feats ark:mfcc/raw_mfcc_dev.1.ark ark,t:- > clustering/feats/king_feats.txt
copy-feats ark:mfcc/raw_mfcc_dev.2.ark ark,t:- >> clustering/feats/king_feats.txt
copy-feats ark:mfcc/raw_mfcc_dev.3.ark ark,t:- >> clustering/feats/king_feats.txt
copy-feats ark:mfcc/raw_mfcc_dev.4.ark ark,t:- >> clustering/feats/king_feats.txt

copy-feats ark:mfcc/raw_mfcc_test.1.ark ark,t:- >> clustering/feats/king_feats.txt
copy-feats ark:mfcc/raw_mfcc_test.2.ark ark,t:- >> clustering/feats/king_feats.txt
copy-feats ark:mfcc/raw_mfcc_test.3.ark ark,t:- >> clustering/feats/king_feats.txt
copy-feats ark:mfcc/raw_mfcc_test.4.ark ark,t:- >> clustering/feats/king_feats.txt

copy-feats ark:mfcc/raw_mfcc_train.1.ark ark,t:- >> clustering/feats/king_feats.txt
copy-feats ark:mfcc/raw_mfcc_train.2.ark ark,t:- >> clustering/feats/king_feats.txt
copy-feats ark:mfcc/raw_mfcc_train.3.ark ark,t:- >> clustering/feats/king_feats.txt
copy-feats ark:mfcc/raw_mfcc_train.4.ark ark,t:- >> clustering/feats/king_feats.txt

awk -F "  " '{print $2}' clustering/feats/king_feats.txt | sed "s/ /,/g" | sed "s/^$//g" | sed "s/\[//g" | sed "s/\]//g" | sed "s/,$//g" | sort -R | head -1305229 > clustering/feats/king_1mil_shuffled_feats.txt
