import os
import contextlib
import sys
import wave

from sphfile import SPHFile


def create_wav(sph, filename):
    with contextlib.closing(wave.open(filename, 'wb')) as fh:
        params = (
            sph.format['channel_count'],
            sph.format['sample_n_bytes'],
            sph.format['sample_rate'],
            0,
            'NONE', 'NONE'
        )
        fh.setparams(params)
        data = sph.content
        fh.writeframes(data.tostring())
    return filename


def main():
    source_directory = sys.argv[1]
    destination_directory = sys.argv[2]

    files = []
    for (path, dirs, filename) in os.walk(source_directory):
        files.extend(filename)

    for f in files:
        sph = SPHFile(os.path.join(source_directory, f))
        dest = f.split('.')[0] + '.wav'
        create_wav(sph, os.path.join(destination_directory, dest))


if __name__ == '__main__':
    main()
