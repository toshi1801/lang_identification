Project: End-to-End Language identification
UNI: nj2387
Name: Naman Jain
Course: Fundamentals of Speech Recognition COMS 6998 003

Data:

The cleaned speech data is present in folder 'db'
This folder contains the following structure:

audio (For Training and Testing)
    --> dev
        --> aac
            --> li_<lang> (lang_folder, where <lang>: cant, mand, eng, tamil, turk)
                --> utterance_id
                    --> wav files
                    ..
                ..
            ..
    --> test
        --> aac
            --> <lang> (lang_folder, where <lang>: cant, mand, eng, tamil, turk)
                --> utterance_id
                    --> wav files
                    ..
                ..
            ..

musan (For Data Augmentation, have to be downloaded from http://www.openslr.org/17/ and extracted into 'db' directory)
    --> Has its own structure.


How to run:

1. Place the code folder nj2387_lid in the egs folder of Kaldi. All scripts internally use kaldi scripts present in
   other folders, thus, maintaining this relative path is essential.
2. The data folder (db) is present in lang_id folder. The data/audio files needs to be sampled at 16KHz. Data was
   available in different forms like sph and wav. If format is sph then covert it to wav using convert_sph_to_wav.py.
   Re-sampling can be done using script update_sampling rate. As the data is collected from different sources, it was
   difficult to made this data transformation as part of run.sh
3. librosa needs to be installed for using re-sampling script. librosa also require ffmpeg to be installed on system.
3. Execute run.sh. There are no other changes necessary. The "run" script performs all steps from data extraction till
   xvector(NN) training without any further manual intervention.
4. The scores are output to exp/scores_lid_test. Scoring is done using i-vector and its execution logs are in
   exp/scores/log/lid_test_scoring.log. In stage 12 prepare_for_eer.py calculates the ERR of the entire system and
   prints it.
5. If someone is interested in human readable output, kindly run decoder.sh to verify the accuracy of model.

----------------------------

Code changes:

For this project, several VoxCeleb2 scripts were used as is, some were modified for this problem statement, and a few
new scripts were added.

Modified scripts:
1. run.sh: This is based on VoxCeleb2's run.sh with unnecessary steps commented out and invoking custom scripts in other
   places.
2. cmd.sh: Changed queue.pl(used for distributed training) to run.pl(used for multi-core CPU training)
3. make_lid_data.pl: This was modified to accommodate changes in data location and data format. Earlier this script
   expects data in sph format. Have modified its name to suit the use case.
4. prepare_feats_for_egs.sh: Updated main code directory path.
5. run_xvector_1a.sh: Updated main code directory path.

New scripts (For usage, refer these scripts inside local/):
1. decode.sh: This script selects samples from testing data and performs scoring and give the predicted language for
   each input audio. This also calculate accuracy of system on the sample.
2. convert_sph_to_wav.py: Convert audio file format from sph to wav.
3. get_trials.py: Created trial set for scoring while running run.sh, this is only called inside run.sh
4. get_trials_decoder.py: Created trial set for scoring while running decoder.sh, this is only  called inside decoder.sh
5. identify_language.py: Called by decoder.sh to get the human readable language predictions for the given sample.
6. update_sampling_rate.py: Re-sample wav files with given sampling rate. Needs librosa and ffmpeg to installed on system
   for this script to work.
7. calculate_data_sample_time.py: Script calculates the duration of the given audio (only wav) samples.