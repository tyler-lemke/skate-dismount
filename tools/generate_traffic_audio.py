"""Generate original SKATE DISMOUNT traffic sounds with Python's standard library.

The synthesis and resulting WAVs are original project assets under the MIT license.
No recordings, samples, fonts, network resources, or third-party libraries are used.
"""

from __future__ import annotations

import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
RATE = 22_050
TAU = math.tau


def write(name: str, samples: list[float], *, loop: bool = False) -> None:
    peak = max(abs(sample) for sample in samples)
    assert 0.01 < peak < 2.0, (name, peak)
    gain = min(0.88 / peak, 1.0)
    pcm = b"".join(
        struct.pack("<h", round(max(-1.0, min(1.0, sample * gain)) * 32767))
        for sample in samples
    )
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm)
    # Explicit loop metadata survives import in the headless verification suite.
    with open(os.path.join(OUT, name + ".wav.import"), "w", encoding="utf-8") as meta:
        meta.write(
            '[remap]\nimporter="wav"\ntype="AudioStreamWAV"\n\n'
            '[deps]\nsource_file="res://assets/audio/' + name + '.wav"\n\n'
            '[params]\nforce/8_bit=false\nforce/mono=false\n'
            'force/max_rate=false\nforce/max_rate_hz=44100\n'
            'edit/trim=false\nedit/normalize=false\n'
            'edit/loop_mode=' + ('2' if loop else '0') + '\n'
            'edit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n'
        )


def envelope(t: float, length: float, attack: float, release: float) -> float:
    return min(1.0, t / attack) * min(1.0, max(0.0, length - t) / release)


def engine() -> list[float]:
    # Two seconds of periodic 56 Hz combustion with a little periodic roughness.
    # Every harmonic and modulation completes an integer number of cycles.
    seconds = 2.0
    samples: list[float] = []
    for i in range(round(seconds * RATE)):
        t = i / RATE
        combustion = (
            math.sin(TAU * 56 * t) * .28
            + math.sin(TAU * 112 * t + .3) * .14
            + math.sin(TAU * 168 * t + .9) * .09
            + math.sin(TAU * 280 * t + 1.4) * .035
        )
        flutter = .79 + .12 * math.sin(TAU * 4 * t) + .07 * math.sin(TAU * 7 * t)
        textured = .025 * math.sin(TAU * 224 * t + .6 * math.sin(TAU * 8 * t))
        samples.append((combustion * flutter + textured) * .75)
    return samples


def squeal() -> list[float]:
    rng = random.Random(141)
    length = .68
    phase = 0.0
    filtered = 0.0
    samples: list[float] = []
    for i in range(round(length * RATE)):
        t = i / RATE
        f = 860 - 410 * t / length + 47 * math.sin(TAU * 17 * t)
        phase += TAU * f / RATE
        filtered = filtered * .82 + rng.uniform(-1, 1) * .18
        chirp = math.sin(phase) * .34 + math.sin(phase * 1.99) * .15
        grit = filtered * .16 + rng.uniform(-1, 1) * .025
        samples.append((chirp + grit) * envelope(t, length, .035, .16))
    return samples


def horn() -> list[float]:
    length = .57
    samples: list[float] = []
    for i in range(round(length * RATE)):
        t = i / RATE
        wobble = 1.0 + .004 * math.sin(TAU * 6 * t)
        pair = math.sin(TAU * 392 * wobble * t) * .30 + math.sin(TAU * 466 * wobble * t) * .27
        body = math.sin(TAU * 196 * t) * .10 + math.sin(TAU * 784 * t) * .06
        samples.append((pair + body) * envelope(t, length, .022, .10))
    return samples


def metal_crash() -> list[float]:
    rng = random.Random(492)
    length = 1.12
    filtered = 0.0
    phases = [0.0, 0.0, 0.0]
    samples: list[float] = []
    for i in range(round(length * RATE)):
        t = i / RATE
        white = rng.uniform(-1, 1)
        filtered = filtered * .74 + white * .26
        strike = white * .40 * math.exp(-t * 34)
        fold = filtered * .31 * math.exp(-t * 5.3)
        # Several short buckling sheets, spaced like panels collapsing.
        folds = 0.0
        for start, weight in ((.09, .22), (.19, .16), (.34, .10)):
            if t > start:
                age = t - start
                folds += rng.uniform(-1, 1) * weight * math.exp(-age * 28)
        ring = 0.0
        for index, base in enumerate((92.0, 147.0, 231.0)):
            frequency = base * (1.0 - .11 * min(1.0, t))
            phases[index] += TAU * frequency / RATE
            ring += math.sin(phases[index]) * (.13 / (index + 1)) * math.exp(-t * (4.0 + index))
        samples.append((strike + fold + folds + ring) * envelope(t, length, .003, .12))
    return samples


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    write("engine", engine(), loop=True)
    write("squeal", squeal())
    write("horn", horn())
    write("metal_crash", metal_crash())
    print("Generated 4 original traffic WAV assets")


if __name__ == "__main__":
    main()
