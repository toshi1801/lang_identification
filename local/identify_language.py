# Author: Naman Jain(nj2387), COMS 6998
# This script reads the scoring file to output human readable predicted language for the given audio samples.
# Usage: python local/identify_language.py <path-to-trials-file> <path-to-scoring-file>
# Eg: python local/identify_language.py data/lis_test/trials exp/scores_lid_test

import sys

from collections import defaultdict
from operator import itemgetter

trial_file = sys.argv[1]
scores_file = sys.argv[2]

sample_scores = defaultdict(list)

with open(scores_file, 'r') as f:
    lines = f.readlines()
    for line in lines:
        source, target, score = line.strip().split()
        sample_scores[source].append((target, float(score)))

trial_info = defaultdict(list)
with open(trial_file, 'r') as f:
    lines = f.readlines()
    for line in lines:
        s, c, label = line.strip().split()
        trial_info[s].append((c, label))

langs = {'eng': 'English', 'turk': 'Turkish', 'tamil': 'Tamil', 'cant': 'Cantonese', 'mand': 'Mandarin'}

count = 0

for s, scores in sample_scores.items():
    s_max = max(scores, key=itemgetter(1))[0]
    s_lang = s.split('-')[0]
    s_max_lang = s_max.split('-')[0]
    if s_lang == s_max_lang:
        count += 1
    print('Original Language: {} ----> Predicted Language: {}'.format(langs[s_lang], langs[s_max_lang]))

accuracy = (float(count) / len(sample_scores)) * 100
print('Accuracy: {}'.format(accuracy))
