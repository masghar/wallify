#!/usr/bin/env python3
"""Synthesize the original ~32 s ambient promo track (Am-F-C-G pad at 90 BPM
with soft kick/hats). 100% generated - no licensing exposure.
Run from repo root: python3 tool/marketing/make_music.py"""
import pathlib
import wave
import numpy as np

SR = 44100
BPM = 90
BEAT = 60 / BPM                       # 0.667 s
BAR = 4 * BEAT
BARS = 12                             # ~32 s
N = int(SR * BAR * BARS)
t = np.arange(N) / SR

A3, C4, E4 = 220.00, 261.63, 329.63
F3, A3b, C4b = 174.61, 220.00, 261.63
C3, E3, G3 = 130.81, 164.81, 196.00
G3b, B3, D4 = 196.00, 246.94, 293.66
CHORDS = [(A3, C4, E4), (F3, A3b, C4b), (C3, E3, G3), (G3b, B3, D4)]


def pad():
    out = np.zeros(N)
    for bar in range(BARS):
        chord = CHORDS[bar % 4]
        s0, s1 = int(bar * BAR * SR), int((bar + 1) * BAR * SR)
        seg_t = t[s0:s1] - t[s0]
        env = np.minimum(seg_t / 0.8, 1) * np.minimum((BAR - seg_t) / 0.8, 1)
        seg = sum(np.sin(2 * np.pi * f * seg_t) * 0.5
                  + np.sin(2 * np.pi * (f * 1.003) * seg_t) * 0.35
                  + np.sin(2 * np.pi * (f / 2) * seg_t) * 0.25
                  for f in chord)
        out[s0:s1] = seg * env
    # gentle low-pass (moving average) to soften the tone
    k = 25
    return np.convolve(out, np.ones(k) / k, mode="same")


def kick():
    out = np.zeros(N)
    for i in range(int(BARS * 4)):
        s = int(i * BEAT * SR)
        dur = int(0.25 * SR)
        seg_t = np.arange(dur) / SR
        f = 110 * np.exp(-seg_t * 18) + 40
        out[s:s + dur] += np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-seg_t * 14)
    return out


def hats(rng):
    out = np.zeros(N)
    for i in range(int(BARS * 8)):
        if i % 2 == 0:
            continue                   # off-beats only
        s = int(i * BEAT / 2 * SR)
        dur = int(0.05 * SR)
        out[s:s + dur] += rng.standard_normal(dur) * np.exp(-np.arange(dur) / SR * 90)
    return out


def main():
    rng = np.random.default_rng(7)
    mix = 0.5 * pad() + 0.35 * kick() + 0.06 * hats(rng)
    mix /= np.max(np.abs(mix)) * 1.15                     # headroom
    fade = int(2 * SR)
    mix[-fade:] *= np.linspace(1, 0, fade)
    stereo = np.stack([mix, np.roll(mix, 300)], axis=1)   # subtle width
    pcm = (stereo * 32767).astype("<i2")
    out = pathlib.Path(__file__).resolve().parent.parent.parent / \
        "marketing" / "video" / "soundtrack.wav"
    out.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(out), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"wrote {out} ({len(mix)/SR:.1f}s)")


if __name__ == "__main__":
    main()
