"""Create the original Bamboo Court music loops and event sounds."""

from array import array
from math import exp, sin, tau
from pathlib import Path
from random import Random
import sys
import wave


RATE = 16_000
OUTPUT = Path(__file__).resolve().parents[1] / "games/doudizhu/assets/bamboo_court"


def pluck(track, start, note, length, level):
    offset = round(start * RATE)
    samples = round(length * RATE)
    frequency = 440 * 2 ** ((note - 69) / 12)
    for i in range(samples):
        time = i / RATE
        phase = tau * frequency * time
        envelope = min(1, time / 0.008, (length - time) / 0.045) * exp(-4.6 * time)
        color = sin(phase) + 0.31 * sin(phase * 2.01) * exp(-3 * time)
        color += 0.13 * sin(phase * 3.04) * exp(-5 * time)
        track[(offset + i) % len(track)] += level * color * envelope


def music(tension):
    track = [0.0] * (8 * RATE)
    roots = [50, 55, 57, 50]
    melody = [
        (0.0, 69), (0.5, 74), (1.25, 76), (1.75, 74),
        (2.0, 71), (2.75, 67), (3.5, 69),
        (4.0, 76), (4.5, 74), (5.0, 69), (5.75, 66),
        (6.0, 67), (6.75, 69), (7.25, 74),
    ]
    for i, root in enumerate(roots):
        pluck(track, i * 2, root, 1.9, 0.18)
        pluck(track, i * 2 + 0.75, root + 7, 1.1, 0.09)
        if tension:
            for delay in (0.25, 0.5, 1.0, 1.25, 1.5, 1.75):
                pluck(track, i * 2 + delay, root + 12, 0.24, 0.13)
    for at, note in melody:
        pluck(track, at, note, 0.68, 0.21)
        pluck(track, at + 0.15, note, 0.58, 0.045)
    return track


def paper(length, seed, taps):
    track = [0.0] * round(length * RATE)
    noise = Random(seed)
    last = 0.0
    for i in range(len(track)):
        time = i / RATE
        sample = noise.uniform(-1, 1)
        flutter = sample - 0.52 * last
        last = sample
        for tap in taps:
            age = time - tap
            if age >= 0:
                track[i] += 0.24 * flutter * min(1, age / 0.003) * exp(-46 * age)
        track[i] *= min(1, (length - time) / 0.02)
    return track


def write(name, track):
    signal = array("h", (round(sample * 30_000) for sample in track))
    if sys.byteorder != "little":
        signal.byteswap()
    with wave.open(str(OUTPUT / name), "wb") as clip:
        clip.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        clip.writeframes(signal.tobytes())


def main():
    write("table-music.wav", music(tension=False))
    write("tension-music.wav", music(tension=True))
    write("paper.wav", paper(0.14, 81, (0.0,)))
    write("deal.wav", paper(0.26, 79, (0.0, 0.057, 0.119)))
    chime = [0.0] * RATE
    for at, note in [(0.0, 74), (0.13, 78), (0.26, 81)]:
        pluck(chime, at, note, 0.66, 0.22)
    write("settlement.wav", chime)


if __name__ == "__main__":
    main()
