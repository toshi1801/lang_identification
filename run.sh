#!/bin/bash
# Copyright   2017   Johns Hopkins University (Author: Daniel Garcia-Romero)
#             2017   Johns Hopkins University (Author: Daniel Povey)
#        2017-2018   David Snyder
#             2018   Ewald Enzinger
# Apache 2.0.
# Modified by Naman Jain(nj2387) for end-to-end language identification project.(COMS 6998)
#
# See ../README.txt for more info on data required.
# Results (mostly equal error-rates) are inline in comments below.

. ./cmd.sh
. ./path.sh
set -e
mfccdir=`pwd`/mfcc
vaddir=`pwd`/mfcc


lid_trials=data/lid_test/trials
lid_root=db/audio
nnet_dir=exp/xvector_nnet_1a
musan_root=db/musan

stage=0

if [ $stage -le 0 ]; then
  local/make_lid_data.pl $lid_root dev data/lid_train
  local/make_lid_data.pl $lid_root test data/lid_test
  utils/combine_data.sh data/train data/lid_train
fi

if [ $stage -le 1 ]; then
  # Make MFCCs and compute the energy-based VAD for each dataset
  for name in train lid_test; do
    steps/make_mfcc.sh --write-utt2num-frames true --mfcc-config conf/mfcc.conf --nj 3 --cmd "$train_cmd" \
      data/${name} exp/make_mfcc $mfccdir
    utils/fix_data_dir.sh data/${name}
    sid/compute_vad_decision.sh --nj 3 --cmd "$train_cmd" \
      data/${name} exp/make_vad $vaddir
    utils/fix_data_dir.sh data/${name}
  done
fi

echo "Stage 2 Started."
# In this section, we augment the language data with reverberation,
# noise, music, and babble, and combine it with the clean data.
if [ $stage -le 2 ]; then
  frame_shift=0.01
  awk -v frame_shift=$frame_shift '{print $1, $2*frame_shift;}' data/train/utt2num_frames > data/train/reco2dur

  if [ ! -d "RIRS_NOISES" ]; then
    # Download the package that includes the real RIRs, simulated RIRs, isotropic noises and point-source noises
    wget --no-check-certificate http://www.openslr.org/resources/28/rirs_noises.zip
    unzip rirs_noises.zip
  fi

  # Make a version with reverberated speech
  rvb_opts=()
  rvb_opts+=(--rir-set-parameters "0.5, RIRS_NOISES/simulated_rirs/smallroom/rir_list")
  rvb_opts+=(--rir-set-parameters "0.5, RIRS_NOISES/simulated_rirs/mediumroom/rir_list")

  # Make a reverberated version of the lang data list.  Note that we don't add any
  # additive noise here.
  python steps/data/reverberate_data_dir.py \
    "${rvb_opts[@]}" \
    --speech-rvb-probability 1 \
    --pointsource-noise-addition-probability 0 \
    --isotropic-noise-addition-probability 0 \
    --num-replications 1 \
    --source-sampling-rate 16000 \
    data/train data/train_reverb
  cp data/train/vad.scp data/train_reverb/
  utils/copy_data_dir.sh --utt-suffix "-reverb" data/train_reverb data/train_reverb.new
  rm -rf data/train_reverb
  mv data/train_reverb.new data/train_reverb

  # Prepare the MUSAN corpus, which consists of music, speech, and noise
  # suitable for augmentation.
  local/make_musan.sh $musan_root data

  # Get the duration of the MUSAN recordings.  This will be used by the
  # script augment_data_dir.py.
  for name in speech noise music; do
    utils/data/get_utt2dur.sh data/musan_${name}
    mv data/musan_${name}/utt2dur data/musan_${name}/reco2dur
  done

  # Augment with musan_noise
  python steps/data/augment_data_dir.py --utt-suffix "noise" --fg-interval 1 --fg-snrs "15:10:5:0" --fg-noise-dir "data/musan_noise" data/train data/train_noise
  # Augment with musan_music
  python steps/data/augment_data_dir.py --utt-suffix "music" --bg-snrs "15:10:8:5" --num-bg-noises "1" --bg-noise-dir "data/musan_music" data/train data/train_music
  # Augment with musan_speech
  python steps/data/augment_data_dir.py --utt-suffix "babble" --bg-snrs "20:17:15:13" --num-bg-noises "3:4:5:6:7" --bg-noise-dir "data/musan_speech" data/train data/train_babble

  # Combine reverb, noise, music, and babble into one directory.
  utils/combine_data.sh data/train_aug data/train_reverb data/train_noise data/train_music data/train_babble
fi
echo "Stage 2 completed."

echo "Stage 3 Started."
if [ $stage -le 3 ]; then
  # Take a random subset of the augmentations
  utils/subset_data_dir.sh data/train_aug 20000 data/train_aug_1m
  utils/fix_data_dir.sh data/train_aug_1m

  # Make MFCCs for the augmented data.  Note that we do not compute a new
  # vad.scp file here.  Instead, we use the vad.scp from the clean version of
  # the list.
  steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --nj 2 --cmd "$train_cmd" \
    data/train_aug_1m exp/make_mfcc $mfccdir

  # Combine the clean and augmented lang data list.  This is now roughly
  # double the size of the original clean list.
  utils/combine_data.sh data/train_combined data/train_aug_1m data/train
fi
echo "Stage 3 Completed."

echo "Stage 4 Started."
# Now we prepare the features to generate examples for xvector training.
if [ $stage -le 4 ]; then
  # This script applies CMVN and removes nonspeech frames.  Note that this is somewhat
  # wasteful, as it roughly doubles the amount of training data on disk.  After
  # creating training examples, this can be removed.
  local/nnet3/xvector/prepare_feats_for_egs.sh --nj 2 --cmd "$train_cmd" \
    data/train_combined data/train_combined_no_sil exp/train_combined_no_sil
  utils/fix_data_dir.sh data/train_combined_no_sil
fi
echo "Stage 4 Completed."

echo "Stage 5 Started."
if [ $stage -le 5 ]; then
  # Now, we need to remove features that are too short after removing silence
  # frames.  We want atleast 5s (500 frames) per utterance.
  min_len=400
  mv data/train_combined_no_sil/utt2num_frames data/train_combined_no_sil/utt2num_frames.bak
  awk -v min_len=${min_len} '$2 > min_len {print $1, $2}' data/train_combined_no_sil/utt2num_frames.bak > data/train_combined_no_sil/utt2num_frames
  utils/filter_scp.pl data/train_combined_no_sil/utt2num_frames data/train_combined_no_sil/utt2spk > data/train_combined_no_sil/utt2spk.new
  mv data/train_combined_no_sil/utt2spk.new data/train_combined_no_sil/utt2spk
  utils/fix_data_dir.sh data/train_combined_no_sil

  # We also want several utterances per speaker. Now we'll throw out speakers
  # with fewer than 8 utterances.
  min_num_utts=8
  awk '{print $1, NF-1}' data/train_combined_no_sil/spk2utt > data/train_combined_no_sil/spk2num
  awk -v min_num_utts=${min_num_utts} '$2 >= min_num_utts {print $1, $2}' data/train_combined_no_sil/spk2num | utils/filter_scp.pl - data/train_combined_no_sil/spk2utt > data/train_combined_no_sil/spk2utt.new
  mv data/train_combined_no_sil/spk2utt.new data/train_combined_no_sil/spk2utt
  utils/spk2utt_to_utt2spk.pl data/train_combined_no_sil/spk2utt > data/train_combined_no_sil/utt2spk

  utils/filter_scp.pl data/train_combined_no_sil/utt2spk data/train_combined_no_sil/utt2num_frames > data/train_combined_no_sil/utt2num_frames.new
  mv data/train_combined_no_sil/utt2num_frames.new data/train_combined_no_sil/utt2num_frames

  # Now we're ready to create training examples.
  utils/fix_data_dir.sh data/train_combined_no_sil
fi
echo "Stage 5 completed."

echo "Stage 6-8 started."
# Stages 6 through 8 are handled in run_xvector.sh
local/nnet3/xvector/run_xvector.sh --stage $stage --train-stage -1 \
  --data data/train_combined_no_sil --nnet-dir $nnet_dir \
  --egs-dir $nnet_dir/egs
echo "Stage 6-8 completed."

echo "Stage 9 started."
if [ $stage -le 9 ]; then
  # Extract x-vectors for centering, LDA, and PLDA training.
  sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 4G" --nj 4 \
    $nnet_dir data/train \
    $nnet_dir/xvectors_train

  # Extract x-vectors used in the evaluation.
  sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 4G" --nj 4 \
    $nnet_dir data/lid_test \
    $nnet_dir/xvectors_lid_test
fi
echo "Stage 9 completed."

echo "Stage 10 Started"
if [ $stage -le 10 ]; then
  # Compute the mean vector for centering the evaluation xvectors.
  $train_cmd $nnet_dir/xvectors_train/log/compute_mean.log \
    ivector-mean scp:$nnet_dir/xvectors_train/xvector.scp \
    $nnet_dir/xvectors_train/mean.vec || exit 1;

  # This script uses LDA to decrease the dimensionality prior to PLDA.
  lda_dim=200
  $train_cmd $nnet_dir/xvectors_train/log/lda.log \
    ivector-compute-lda --total-covariance-factor=0.0 --dim=$lda_dim \
    "ark:ivector-subtract-global-mean scp:$nnet_dir/xvectors_train/xvector.scp ark:- |" \
    ark:data/train/utt2spk $nnet_dir/xvectors_train/transform.mat || exit 1;

  # Train the PLDA model.
  $train_cmd $nnet_dir/xvectors_train/log/plda.log \
    ivector-compute-plda ark:data/train/spk2utt \
    "ark:ivector-subtract-global-mean scp:$nnet_dir/xvectors_train/xvector.scp ark:- | transform-vec $nnet_dir/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:-  ark:- |" \
    $nnet_dir/xvectors_train/plda || exit 1;
fi
echo "Stage 10 completed."

if [ $stage -le 11 ]; then
  python local/get_trials.py --count 100 $lid_root/test/aac $lid_trials
  $train_cmd exp/scores/log/lid_test_scoring.log \
    ivector-plda-scoring --normalize-length=true \
    "ivector-copy-plda --smoothing=0.0 $nnet_dir/xvectors_train/plda - |" \
    "ark:ivector-subtract-global-mean $nnet_dir/xvectors_train/mean.vec scp:$nnet_dir/xvectors_lid_test/xvector.scp ark:- | transform-vec $nnet_dir/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "ark:ivector-subtract-global-mean $nnet_dir/xvectors_train/mean.vec scp:$nnet_dir/xvectors_lid_test/xvector.scp ark:- | transform-vec $nnet_dir/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "cat '$lid_trials' | cut -d\  --fields=1,2 |" exp/scores_lid_test || exit 1;
fi

if [ $stage -le 12 ]; then
  eer=`compute-eer <(local/prepare_for_eer.py $lid_trials exp/scores_lid_test) 2> /dev/null`
  mindcf1=`sid/compute_min_dcf.py --p-target 0.01 exp/scores_lid_test $lid_trials 2> /dev/null`
  mindcf2=`sid/compute_min_dcf.py --p-target 0.001 exp/scores_lid_test $lid_trials 2> /dev/null`
  echo "EER: $eer%"
  echo "minDCF(p-target=0.01): $mindcf1"
  echo "minDCF(p-target=0.001): $mindcf2"
#  EER: 9.756%
#  minDCF(p-target=0.01): 0.4634
#  minDCF(p-target=0.001): 0.4634
fi

