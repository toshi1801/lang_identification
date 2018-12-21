# Author: Naman Jain(nj2387), COMS 6998
# This script calculates the duration of the given audio (only wav) samples.
# Usage: python local/calculate_data_sample_time.py <path-to-audio-data-directory>
import wave
import contextlib
import os
import sys


directory = sys.argv[1]

total_duration = 0.0
count = 0
files = []
for (path, dname, fs) in os.walk(directory):
    if fs:
        for fi in fs:
            files.append(os.path.join(path, fi))

for fi in files:
    with contextlib.closing(wave.open(fi, 'r')) as f:
        total_duration += f.getnframes() / float(f.getframerate())
print(total_duration / 3600)
