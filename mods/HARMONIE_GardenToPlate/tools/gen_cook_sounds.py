#!/usr/bin/env python3
"""HARMONIE - From Garden to Plate: the cooking minigames' sounds (0.13.1,
owner: "เสียงมินิเกมมีไหม"). Every sound is synthesized here from noise and
sine waves -- no recorded or third-party audio.

Same way as The Way To Attack's sounds (the way that is heard in game):
short one-shots of category UI played with getSoundManager():playUISound();
a sound that goes on while you work (stirring, pouring, sizzling) is one
short grain played again each time it ends. Every sound exists at several
loudness levels (NAME_v25 .. NAME_v150) because the game's per-sound volume
does not reach UI sounds -- the guide's settings pick the file.

Writes 16-bit mono 44.1 kHz WAVs to ../42/media/sound/, the sound script
../42/media/scripts/HARMONIE_GTP_CookSounds.txt and the lengths table
../42/media/lua/client/HARMONIEGardenToPlate/HARMONIE_CookSoundLengths.lua.
Needs numpy.
"""
import os, wave
import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.join(HERE, "..", "42", "media")
SOUND_DIR = os.path.join(BASE, "sound")
SCRIPT = os.path.join(BASE, "scripts", "HARMONIE_GTP_CookSounds.txt")
LENGTHS = os.path.join(BASE, "lua", "client", "HARMONIEGardenToPlate", "HARMONIE_CookSoundLengths.lua")
LEVELS = (25, 50, 75, 100, 150)
rng = np.random.default_rng(7)
os.makedirs(SOUND_DIR, exist_ok=True)


def t_(d): return np.arange(int(d * SR)) / SR
def noise(d): return rng.uniform(-1, 1, int(d * SR))


def onepole(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x); p = 0.0
    for i, v in enumerate(x):
        p = (1 - a) * v + a * p; y[i] = p
    return y


def lp(x, c): return onepole(x, c)
def hp(x, c): return x - onepole(x, c)
def bp(x, lo, hi): return lp(hp(x, lo), hi)
def env(n, tau): return np.exp(-np.arange(n) / SR / tau)


def fade(x, a=0.004, r=0.02):
    x = x.copy(); na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    x[:na] *= np.linspace(0, 1, na); x[-nr:] *= np.linspace(1, 0, nr); return x


def place(buf, s, at):
    i = int(at * SR); j = min(len(buf), i + len(s)); buf[i:j] += s[: j - i]


def norm(x, peak=0.8):
    m = np.max(np.abs(x)) or 1; return x / m * peak


def tone(f, d, tau=0.3, harm=(1, 0.3, 0.1)):
    t = t_(d); s = sum(a * np.sin(2 * np.pi * f * (k + 1) * t) for k, a in enumerate(harm))
    return s * env(len(t), tau)


# ------------------------------------------------------------------ sounds
def chop():        # knife through food onto a wooden board
    d = 0.22; s = np.zeros(int(d * SR))
    cut = bp(noise(0.03), 1500, 6000) * env(int(0.03 * SR), 0.008) * 0.5
    thud = lp(noise(0.12), 400) * env(int(0.12 * SR), 0.03) * 2.2 + tone(140, 0.12, 0.03, (1, 0.2)) * 0.6
    place(s, cut, 0); place(s, thud, 0.012); return fade(norm(s, 0.85))


def slice_():      # a lighter, crisper cut
    d = 0.16; s = np.zeros(int(d * SR))
    place(s, bp(noise(0.06), 2500, 9000) * env(int(0.06 * SR), 0.02), 0)
    place(s, lp(noise(0.06), 600) * env(int(0.06 * SR), 0.015) * 1.2, 0.03); return fade(norm(s, 0.7))


def scrub():       # hand scrubbing under running water (grain)
    d = 0.35; n = noise(d)
    s = bp(n, 800, 5000) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t_(d))) + bp(noise(d), 200, 900) * 0.4
    return fade(norm(s, 0.45), 0.03, 0.06)


def scrape():      # knife / grater scraping (grain)
    d = 0.22; t = t_(d)
    s = bp(noise(d), 2000, 8000) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 18 * t)))
    return fade(norm(s, 0.45), 0.02, 0.05)


def spread():      # butter knife on toast (grain)
    d = 0.3; s = bp(noise(d), 1200, 4000) * (0.4 + 0.6 * np.sin(np.pi * t_(d) / d))
    return fade(norm(s, 0.35), 0.03, 0.06)


def thump():       # dough / meat being pounded
    d = 0.25; s = lp(noise(d), 250) * env(int(d * SR), 0.05) * 2 + tone(90, d, 0.06, (1, 0.4)) * 0.8
    return fade(norm(s, 0.9))


def crack():       # an egg cracked on the rim
    d = 0.3; s = np.zeros(int(d * SR))
    place(s, hp(noise(0.012), 3000) * env(int(0.012 * SR), 0.003), 0)
    place(s, hp(noise(0.01), 2500) * env(int(0.01 * SR), 0.003) * 0.7, 0.02)
    place(s, lp(noise(0.12), 500) * env(int(0.12 * SR), 0.04) * 0.6, 0.08)  # the egg plops in
    return fade(norm(s, 0.95))


def sizzle():      # hot pan (grain)
    d = 0.4; n = hp(noise(d), 3000)
    pops = np.zeros_like(n)
    for _ in range(14):
        place(pops, hp(noise(0.004), 2000) * 3, rng.uniform(0, d - 0.01))
    return fade(norm(n * 0.5 + pops, 0.6), 0.04, 0.08)


def toss():        # a pan flick: whoosh + sizzle burst
    d = 0.4; t = t_(d)
    whoosh = bp(noise(d), 300, 2500) * np.sin(np.pi * t / d) ** 2
    s = whoosh + np.concatenate([np.zeros(int(0.18 * SR)), sizzle()[: len(t) - int(0.18 * SR)]]) * 0.7
    return fade(norm(s, 0.75))


def stir():        # spoon through liquid (grain)
    d = 0.45; t = t_(d)
    s = bp(noise(d), 150, 900) * (0.5 + 0.5 * np.sin(2 * np.pi * 2.2 * t)) + tone(320, d, 0.5, (0.05,)) * 0
    s += bp(noise(d), 900, 2500) * 0.15
    return fade(norm(s, 0.4), 0.05, 0.08)


def whisk():       # fast clicking of wires in a bowl (grain)
    d = 0.3; s = np.zeros(int(d * SR))
    for k in range(9):
        place(s, hp(noise(0.006), 4000) * env(int(0.006 * SR), 0.0015) * (0.6 + 0.4 * rng.random()), k * d / 9)
    s += bp(noise(d), 600, 2000) * 0.12
    return fade(norm(s, 0.8), 0.01, 0.03)


def grind():       # pestle on stone (grain)
    d = 0.35; t = t_(d)
    s = bp(noise(d), 300, 1800) * (0.6 + 0.4 * np.sin(2 * np.pi * 6 * t)) + hp(noise(d), 4000) * 0.1
    return fade(norm(s, 0.5), 0.03, 0.06)


def squish():      # mashing a soft lump
    d = 0.22; t = t_(d)
    s = lp(noise(d), 700) * env(len(t), 0.06) * (1 + 0.5 * np.sin(2 * np.pi * 30 * t)) + tone(110, d, 0.05, (1,)) * 0.3
    return fade(norm(s, 0.75))


def pour():        # salt / flour pouring (grain)
    d = 0.3; s = np.zeros(int(d * SR))
    for _ in range(120):
        place(s, hp(noise(0.002), 3000) * rng.uniform(0.2, 1), rng.uniform(0, d - 0.003))
    return fade(norm(s, 0.65), 0.02, 0.05)


def bubble():      # tea steeping / water simmering (grain)
    d = 0.5; s = np.zeros(int(d * SR))
    for _ in range(9):
        f = rng.uniform(300, 900); dd = rng.uniform(0.02, 0.05); tt = t_(dd)
        b = np.sin(2 * np.pi * (f + 2500 * tt) * tt) * env(len(tt), dd / 3)
        place(s, b, rng.uniform(0, d - dd))
    return fade(norm(s, 0.6), 0.04, 0.08)


def roll():        # rolling pin over dough (grain)
    d = 0.4; s = lp(noise(d), 300) * 0.8 + bp(noise(d), 300, 1200) * 0.2
    return fade(norm(s, 0.4), 0.05, 0.08)


def slip():        # a clumsy clatter
    d = 0.3; s = np.zeros(int(d * SR))
    for k, f in enumerate((1800, 2600, 2200)):
        place(s, tone(f, 0.12, 0.03, (1, 0.5, 0.3)) * 0.5, k * 0.05)
    place(s, lp(noise(0.08), 500) * env(int(0.08 * SR), 0.02), 0.0)
    return fade(norm(s, 0.7))


def chime(notes, step=0.09, tau=0.35, peak=0.6):
    d = step * len(notes) + 0.6; s = np.zeros(int(d * SR))
    for k, f in enumerate(notes):
        place(s, tone(f, 0.6, tau, (1, 0.25, 0.08)), k * step)
    return fade(norm(s, peak), 0.003, 0.1)


SOUNDS = {
    "Chop": chop, "Slice": slice_, "Scrub": scrub, "Scrape": scrape, "Spread": spread, "Thump": thump, "Crack": crack,
    "Sizzle": sizzle, "Toss": toss, "Stir": stir, "Whisk": whisk, "Grind": grind, "Squish": squish, "Pour": pour,
    "Bubble": bubble, "Roll": roll, "Slip": slip,
    "Excellent": lambda: chime((784, 988, 1175, 1568)),
    "Good": lambda: chime((659, 880)),
    "Bad": lambda: chime((440, 392), step=0.14, tau=0.25, peak=0.45),
    "Miss": lambda: chime((392, 330, 262), step=0.12, tau=0.2, peak=0.5),
}


def write(path, x):
    x = np.clip(x, -1, 1)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


lengths = {}
script = ["/* GENERATED by mods/HARMONIE_GardenToPlate/tools/gen_cook_sounds.py -- every",
          "   sound here is synthesized by that script (no recorded audio). */", "module Base", "{"]
for name, fn in SOUNDS.items():
    x = fn()
    full = "GTPC_" + name
    lengths[full] = int(len(x) / SR * 1000)
    for lvl in LEVELS:
        sname = full if lvl == 100 else "%s_v%d" % (full, lvl)
        write(os.path.join(SOUND_DIR, sname + ".wav"), x * lvl / 100)
        script += ["    sound %s" % sname, "    {", "        category = UI,", "        clip", "        {",
                   "            file = media/sound/%s.wav," % sname, "            distanceMax = 10,", "        }", "    }", ""]
script.append("}")
open(SCRIPT, "w").write("\n".join(script) + "\n")
with open(LENGTHS, "w") as f:
    f.write("-- GENERATED by tools/gen_cook_sounds.py: each cooking sound's length in ms\n")
    f.write("HARMONIE_GTP = HARMONIE_GTP or {}\nHARMONIE_GTP.CookSoundLength = {\n")
    for k, v in lengths.items(): f.write('    %s = %d,\n' % (k, v))
    f.write("}\nHARMONIE_GTP.CookSoundLevels = { %s }\n" % ", ".join(str(l) for l in LEVELS))
print("sounds", len(SOUNDS), "files", len(SOUNDS) * len(LEVELS))
