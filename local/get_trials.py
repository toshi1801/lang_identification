from __future__ import print_function
from collections import defaultdict

import os
import random
import sys
import argparse


def get_args():
    parser = argparse.ArgumentParser(description="Create the trials file for scoring."
                                                 "Usage: local/get_trials.py [options...] <test-directory-path> "
                                                 "<trials-file> "
                                                 "E.g., local/get_trials.py --count 100 "
                                                 "db/audio/test/aac data/lid_test/trials",
                                     formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('--count', type=int, dest="count", default=100,
                        help='Number of trial cases.')
    parser.add_argument("test_directory_path",
                        help="Directory path to test data.")
    parser.add_argument("trials_filename",
                        help="Input trials file, with columns of the form "
                             "<utt1> <utt2> <target/nontarget>")
    sys.stderr.write(' '.join(sys.argv) + "\n")
    args = parser.parse_args()
    args = check_args(args)
    return args


def check_args(args):
    if args.count <= 0:
        raise Exception("--count must be greater than 0")
    return args


def main():
    args = get_args()

    files = []
    for (path, dirs, filename) in os.walk(args.test_directory_path):
        if filename:
            for fname in filename:
                p = os.path.join(path, fname)
                p1 = p.replace(args.test_directory_path + '/', '')
                files.append(p1)

    tmap = defaultdict(list)

    for f in files:
        f_parts = f.split('/')
        tmap[f_parts[0]].append(f_parts[0] + '-' + f_parts[1] + '-' + f_parts[2].split('.')[0])

    flag = 1
    for i in range(args.count):
        if flag:
            key, value = random.choice(list(tmap.items()))
            c1 = random.choice(value)
            c2 = random.choice(value)
            label = 'target'
            flag = 0
        else:
            key, value = random.choice(list(tmap.items()))
            c1 = random.choice(value)
            key_list = tmap.keys()
            key_list.remove(key)
            diff_key = random.choice(key_list)
            c2 = random.choice(tmap[diff_key])
            label = 'nontarget'
            flag = 1

        with open(args.trials_filename, 'a') as f:
            line = c1 + ' ' + c2 + ' ' + label + '\n'
            f.write(line)


if __name__ == '__main__':
    main()
