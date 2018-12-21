#!/bin/bash

python local/get_trials.py --count 100 db/audio/test/aac data/lid_test/trials

# Make utterance related files
# Extract MFCC and VAD
# Extract Xevctors
# Try to get proper label