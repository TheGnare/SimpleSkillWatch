#!/usr/bin/env python3
"""Generate SimpleSkillWatch's own alert sounds (Sounds/*.ogg).

Every sound is synthesized here from sine waves, so the files are entirely the
addon's own. To change a sound, edit SOUNDS below and run this again:

    pip install numpy          (ffmpeg must be installed too)
    python tools/make_sounds.py

Notes are played one after another, each ringing on over the next.
"""
import pathlib
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100
OUT = pathlib.Path(__file__).resolve().parent.parent / "Sounds"

# Note frequencies (Hz), equal temperament, A4 = 440.
A4, B4, C5 = 440.00, 493.88, 523.25
A5, B5, C6 = 880.00, 987.77, 1046.50


def mallet(freq, length):
    """A struck wooden bar (marimba/xylophone): a quick knock, short ring."""
    t = np.arange(int(RATE * length)) / RATE
    tone = np.sin(2 * np.pi * freq * t) * np.exp(-t / 0.16)
    tone += 0.30 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-t / 0.045)   # the bar's bright overtone
    tone += 0.10 * np.sin(2 * np.pi * freq * 9.2 * t) * np.exp(-t / 0.012)  # the knock of the mallet
    return tone


def bell(freq, length):
    """A small soft bell: slower fade, a gentle shimmer from two close partials."""
    t = np.arange(int(RATE * length)) / RATE
    tone = np.sin(2 * np.pi * freq * t) * np.exp(-t / 0.32)
    tone += 0.35 * np.sin(2 * np.pi * freq * 2.0 * t) * np.exp(-t / 0.20)
    tone += 0.20 * np.sin(2 * np.pi * freq * 3.01 * t) * np.exp(-t / 0.12)
    tone += 0.10 * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-t / 0.05)
    return tone


def phrase(voice, notes, gap, tail):
    """notes: frequencies in order. gap: seconds between note starts. tail: ring after the last."""
    total = gap * (len(notes) - 1) + tail
    out = np.zeros(int(RATE * total))
    for i, freq in enumerate(notes):
        start = int(RATE * gap * i)
        note = voice(freq, total - gap * i)
        attack = int(RATE * 0.003)                    # 3 ms fade-in: no click
        note[:attack] *= np.linspace(0, 1, attack)
        out[start:start + len(note)] += note
    fade = int(RATE * 0.06)                           # fade the very end to silence
    out[-fade:] *= np.linspace(1, 0, fade)
    return out / np.max(np.abs(out)) * 0.70           # peak about -3 dB


# file name -> (voice, notes, seconds between notes, ring after the last note)
SOUNDS = {
    # a minor third up
    "TwoNotes":       (mallet, [A5, C6], 0.13, 0.45),
    # low, high, middle: a minor third up, then a half step down
    "ThreeNotes":     (mallet, [A5, C6, B5], 0.12, 0.45),
    "ThreeNotesBell": (bell,   [A5, C6, B5], 0.14, 0.70),
    "ThreeNotesLow":  (mallet, [A4, C5, B4], 0.12, 0.50),
    # the low one with the notes closer together (same notes, same ring)
    "ThreeNotesLow125": (mallet, [A4, C5, B4], 0.12 / 1.25, 0.50),
    "ThreeNotesLow150": (mallet, [A4, C5, B4], 0.12 / 1.50, 0.50),
    "ThreeNotesLow175": (mallet, [A4, C5, B4], 0.12 / 1.75, 0.50),
    "ThreeNotesLow200": (mallet, [A4, C5, B4], 0.12 / 2.00, 0.50),
}


def main():
    OUT.mkdir(exist_ok=True)
    for name, (voice, notes, gap, tail) in SOUNDS.items():
        samples = (phrase(voice, notes, gap, tail) * 32767).astype("<i2")
        with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
            with wave.open(tmp.name, "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(RATE)
                w.writeframes(samples.tobytes())
            target = OUT / f"{name}.ogg"
            subprocess.run(
                ["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name,
                 "-c:a", "libvorbis", "-q:a", "5", "-map_metadata", "-1", str(target)],
                check=True)
        print(f"{target.name}: {len(samples) / RATE:.2f} s, {target.stat().st_size} bytes")


if __name__ == "__main__":
    main()
