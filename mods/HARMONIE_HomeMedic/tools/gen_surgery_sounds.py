#!/usr/bin/env python3
"""HARMONIE - Home Medic: the surgery minigames' sounds, synthesized here (no
recorded or third-party audio).

Writes 16-bit mono 44.1 kHz WAVs to ../42/media/sound/HM_Surg_*.wav and the
sound script ../42/media/scripts/HM_surgery_sounds.txt. Every sound is a
short one-shot of category UI, played with getSoundManager():playUISound();
a continuous sound (suction, saw, drill, pump) is re-triggered by the game
while the work goes on, so those are short grains with soft ends.
Needs numpy.
"""
import os
import wave

import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
SOUND_DIR = os.path.join(HERE, "..", "42", "media", "sound")
SCRIPT = os.path.join(HERE, "..", "42", "media", "scripts", "HM_surgery_sounds.txt")
rng = np.random.default_rng(7)


def t_(d): return np.arange(int(d * SR)) / SR
def noise(d): return rng.uniform(-1, 1, int(d * SR))


def onepole(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    prev = 0.0
    for i, v in enumerate(x):
        prev = (1 - a) * v + a * prev
        y[i] = prev
    return y


def lowpass(x, c): return onepole(onepole(x, c), c)
def highpass(x, c): return x - lowpass(x, c)
def bandpass(x, lo, hi): return lowpass(highpass(x, lo), hi)


def fade(x, a=0.005, r=0.03):
    x = x.copy()
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    x[:na] *= np.linspace(0, 1, na)
    x[-nr:] *= np.linspace(1, 0, nr)
    return x


def env_exp(n, tau): return np.exp(-np.arange(n) / SR / tau)


def norm(x, peak=0.75):
    m = np.max(np.abs(x)) or 1
    return x / m * peak


# ---------------------------------------------------------------- sounds
def cut():          # scalpel through skin: a soft, wet tearing hiss
    d = 0.28
    n = noise(d)
    s = bandpass(n, 1800, 6500) * env_exp(len(n), 0.09)
    crackle = (rng.random(len(n)) > 0.996) * rng.uniform(-1, 1, len(n))
    s += lowpass(crackle, 3000) * 2
    return norm(fade(s, 0.002, 0.05), 0.5)


def clamp():        # ratchet of a hemostat locking: two quick metal ticks
    out = np.zeros(int(0.16 * SR))
    for at, f in ((0.0, 3400), (0.05, 3900)):
        t = t_(0.06)
        tick = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.7 * t)) * env_exp(len(t), 0.008)
        i = int(at * SR)
        out[i:i + len(tick)] += tick[: len(out) - i]
    return norm(fade(out, 0.001, 0.02), 0.55)


def squirt():       # syringe irrigation: pressurised water
    d = 0.35
    n = noise(d)
    s = bandpass(n, 900, 4000) * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t_(d)))
    s *= np.minimum(1, t_(d) / 0.04) * env_exp(len(n), 0.22)
    return norm(fade(s, 0.003, 0.08), 0.45)


def suction():      # suction tip: gurgling slurp grain
    d = 0.32
    t = t_(d)
    n = noise(d)
    gurgle = bandpass(n, 300, 1400) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (14 + 6 * np.sin(2 * np.pi * 3 * t)) * t)))
    hiss = bandpass(noise(d), 2500, 7000) * 0.3
    return norm(fade(gurgle + hiss, 0.02, 0.05), 0.4)


def saw():          # oscillating bone saw: buzzing grain
    d = 0.3
    t = t_(d)
    tone = np.sign(np.sin(2 * np.pi * 180 * t)) * 0.5 + np.sin(2 * np.pi * 540 * t) * 0.4
    grit = bandpass(noise(d), 2000, 6000) * 0.5 * (0.5 + 0.5 * np.sin(2 * np.pi * 180 * t))
    return norm(fade(lowpass(tone, 4000) + grit, 0.02, 0.05), 0.42)


def drill():        # cranial drill: high whine grain
    d = 0.3
    t = t_(d)
    f = 1450 + 40 * np.sin(2 * np.pi * 7 * t)
    phase = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(phase) + 0.35 * np.sin(2 * phase) + 0.2 * np.sin(3.01 * phase)
    grit = bandpass(noise(d), 3000, 8000) * 0.25
    return norm(fade(tone + grit, 0.02, 0.05), 0.35)


def stitch():       # thread drawn through skin: a short swish
    d = 0.24
    n = noise(d)
    s = bandpass(n, 2500, 9000) * np.sin(np.pi * np.clip(t_(d) / d, 0, 1)) ** 2
    return norm(fade(s, 0.003, 0.03), 0.4)


def beep():         # monitor pulse beep
    t = t_(0.09)
    s = np.sin(2 * np.pi * 980 * t) * np.minimum(1, (0.09 - t) / 0.02)
    return norm(fade(s, 0.003, 0.02), 0.3)


def alarm():        # monitor alarm: two-tone
    out = np.concatenate([np.sin(2 * np.pi * 880 * t_(0.14)), np.zeros(int(0.04 * SR)), np.sin(2 * np.pi * 660 * t_(0.14))])
    return norm(fade(out, 0.004, 0.02), 0.35)


def splat():        # blood spurt / spill
    d = 0.22
    n = noise(d)
    s = lowpass(n, 1200) * env_exp(len(n), 0.05)
    s += np.sin(2 * np.pi * 110 * t_(d)) * env_exp(len(n), 0.04) * 0.6
    return norm(fade(s, 0.001, 0.04), 0.45)


def pop():          # pipette drop placed
    t = t_(0.1)
    f = 900 - 3500 * t
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(len(t), 0.025)
    return norm(fade(s, 0.001, 0.02), 0.35)


def pump():         # dialysis roller pump thump
    t = t_(0.28)
    s = np.sin(2 * np.pi * 70 * t) * env_exp(len(t), 0.06) + bandpass(noise(0.28), 400, 1500) * env_exp(len(t), 0.03) * 0.4
    return norm(fade(s, 0.002, 0.04), 0.5)


def good():         # step finished well: soft rising chime
    out = np.zeros(int(0.5 * SR))
    for k, f in enumerate((660, 880, 1320)):
        t = t_(0.35)
        tone = np.sin(2 * np.pi * f * t) * env_exp(len(t), 0.18)
        i = int(k * 0.06 * SR)
        out[i:i + len(tone)] += tone
    return norm(fade(out, 0.003, 0.05), 0.3)


def bad():          # mistake: dull low buzz
    t = t_(0.3)
    s = np.sign(np.sin(2 * np.pi * 120 * t)) * env_exp(len(t), 0.12)
    return norm(fade(lowpass(s, 900), 0.003, 0.05), 0.35)


SOUNDS = {
    "HM_Surg_Cut": cut, "HM_Surg_Clamp": clamp, "HM_Surg_Squirt": squirt, "HM_Surg_Suction": suction,
    "HM_Surg_Saw": saw, "HM_Surg_Drill": drill, "HM_Surg_Stitch": stitch, "HM_Surg_Beep": beep,
    "HM_Surg_Alarm": alarm, "HM_Surg_Splat": splat, "HM_Surg_Pop": pop, "HM_Surg_Pump": pump,
    "HM_Surg_Good": good, "HM_Surg_Bad": bad,
}


def write_wav(path, x):
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def main():
    os.makedirs(SOUND_DIR, exist_ok=True)
    lines = ["/* GENERATED by mods/HARMONIE_HomeMedic/tools/gen_surgery_sounds.py -- every",
             "   sound here is synthesized by that script (no recorded audio). */", "module Base", "{"]
    for name, fn in SOUNDS.items():
        write_wav(os.path.join(SOUND_DIR, name + ".wav"), fn())
        lines += ["    sound " + name, "    {", "        category = UI,", "        clip", "        {",
                  "            file = media/sound/" + name + ".wav,", "            distanceMax = 10,", "        }", "    }", ""]
    lines.append("}")
    with open(SCRIPT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("wrote", len(SOUNDS), "sounds")


if __name__ == "__main__":
    main()
