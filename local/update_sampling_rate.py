# Author: Naman Jain(nj2387), COMS 6998
# Re-sample wav files based on the given sampling rate
# Usage : python update_sampling_rate.py <absolute_path_to_audio_directory> <sample_rate>

import librosa
import os
import sys


def main():
    files = []
    directory = sys.argv[1]
    sample_rate = int(sys.argv[2])
    for (path, dirs, filename) in os.walk(directory):
        files.extend(filename)

    print("Total Files: {}".format(len(files)))
    count = 1
    for f in files:
        print(count, f)
        y, s = librosa.load(os.path.join(d, f), sr=sample_rate)
        librosa.output.write_wav(f, y, s)
        count += 1


if __name__ == '__main__':
    main()
