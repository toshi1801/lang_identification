#!/bin/bash
#
# Author: Naman Jain(nj2387), COMS 6998
# This script select 20-25 random samples from test data and predicts their language.
# Usage: ./decode.sh

. ./cmd.sh
. ./path.sh
set -e

nnet_dir=exp/xvector_nnet_1a
lid_trials=data/lid_test/trials_decode

# Create trial for decoder.sh script
python local/get_trials_decoder.py db/audio/test/aac $lid_trials

# Trial scripts contains testing audio files names. mfcc and i-vectors were extracted from testting data during training.
# Here we score i-vectors given in trial file.
$train_cmd exp/scores/log/lid_test_scoring.log \
    ivector-plda-scoring --normalize-length=true \
    "ivector-copy-plda --smoothing=0.0 $nnet_dir/xvectors_train/plda - |" \
    "ark:ivector-subtract-global-mean $nnet_dir/xvectors_train/mean.vec scp:$nnet_dir/xvectors_lid_test/xvector.scp ark:- | transform-vec $nnet_dir/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "ark:ivector-subtract-global-mean $nnet_dir/xvectors_train/mean.vec scp:$nnet_dir/xvectors_lid_test/xvector.scp ark:- | transform-vec $nnet_dir/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "cat '$lid_trials' | cut -d\  --fields=1,2 |" exp/scores_lid_test || exit 1;


# Based on score, extract the highest matching language.
python local/identify_language.py $lid_trials exp/scores_lid_test

