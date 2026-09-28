#!/usr/bin/env python3
"""Synthesizes every HARMONIE_TheWayToAttack sound from scratch (no recorded
or third-party audio) -- round 11 request 2026-09-28: "เสียงเงียบเลย ไม่มี
เสียงอะไรทั้งนั้นตอนทำ ตอน action time เหมือนกัน สร้างเสียงมาเองเลยก็ได้".

Writes 16-bit mono 44.1 kHz WAV files to ../42/media/sound/ and the matching
sound script ../42/media/scripts/TWA_sounds.txt. Needs numpy.

Loops (loop = true) repeat until the game stops them: timed actions and the
minigames stop them when the work stops. One-shots play once.
"""
import os, wave
import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
SOUND_DIR = os.path.join(HERE, "..", "42", "media", "sound")
SCRIPT = os.path.join(HERE, "..", "42", "media", "scripts", "TWA_sounds.txt")
rng = np.random.default_rng(42)

def t_(dur): return np.arange(int(dur * SR)) / SR
def noise(dur): return rng.uniform(-1, 1, int(dur * SR))

def lowpass(x, cutoff):
    # one-pole low-pass
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x); prev = 0.0
    for i, v in enumerate(x):
        prev = (1 - a) * v + a * prev; y[i] = prev
    return y

def highpass(x, cutoff): return x - lowpass(x, cutoff)
def bandpass(x, lo, hi): return lowpass(highpass(x, lo), hi)

def env_exp(n, tau): return np.exp(-np.arange(n) / SR / tau)
def adsr(n, a=0.01, r=0.05):
    e = np.ones(n); na, nr = int(a * SR), int(r * SR)
    if na: e[:na] = np.linspace(0, 1, na)
    if nr: e[-nr:] *= np.linspace(1, 0, nr)
    return e

def place(buf, snd, at):
    i = int(at * SR); j = min(len(buf), i + len(snd)); buf[i:j] += snd[: j - i]

def norm(x, peak=0.8):
    m = np.max(np.abs(x)) or 1; return x / m * peak

def loop_fade(x, ms=12):
    # soften the loop seam
    n = int(ms / 1000 * SR); x = x.copy()
    x[:n] *= np.linspace(0, 1, n); x[-n:] *= np.linspace(1, 0, n); return x

# ---- building blocks
def metal_hit(dur=0.45, base=520, bright=1.0):
    t = t_(dur); s = np.zeros_like(t)
    for ratio, amp, tau in ((1.0, 1.0, 0.18), (2.76, 0.6, 0.10), (5.40, 0.4, 0.06), (8.93, 0.25, 0.04), (13.3, 0.15 * bright, 0.025)):
        s += amp * np.sin(2 * np.pi * base * ratio * t + rng.uniform(0, 6)) * np.exp(-t / tau)
    click = highpass(noise(dur), 2000) * np.exp(-t / 0.006) * 0.8
    return s + click

def wood_knock(dur=0.25, base=180):
    t = t_(dur)
    body = np.sin(2 * np.pi * base * t) * np.exp(-t / 0.05) + 0.5 * np.sin(2 * np.pi * base * 2.3 * t) * np.exp(-t / 0.03)
    thud = lowpass(noise(dur), 900) * np.exp(-t / 0.02) * 1.5
    return body + thud

def stone_click(dur=0.2):
    t = t_(dur)
    return bandpass(noise(dur), 1200, 5000) * np.exp(-t / 0.015) * 2 + np.sin(2 * np.pi * 1900 * t) * np.exp(-t / 0.02) * 0.4

# ---- the sounds: name -> (samples, loop)
S = {}

# Hammer on metal: a knock every 0.55 s (first at 0, so a 260 ms cut = one blow)
b = np.zeros(int(1.1 * SR))
for at in (0.0, 0.55): place(b, metal_hit(0.5, 520 + rng.uniform(-20, 20)), at)
S["TWA_Hammer"] = (norm(b), True)
b = np.zeros(int(1.1 * SR))
for at in (0.0, 0.55): place(b, wood_knock(0.25) + 0.35 * metal_hit(0.25, 1300, 0.3), at)
S["TWA_HammerWood"] = (norm(b), True)
b = np.zeros(int(0.9 * SR))
for at in (0.0, 0.45): place(b, stone_click(), at)
S["TWA_Knap"] = (norm(b), True)

# Glass smash (one-shot)
d = 1.0; t = t_(d)
sh = highpass(noise(d), 3000) * np.exp(-t / 0.12)
tinkles = np.zeros_like(t)
for _ in range(40):
    f = rng.uniform(2500, 7000); at = rng.uniform(0.02, 0.7)
    tt = t_(0.08); place(tinkles, np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.02) * rng.uniform(0.2, 0.6), at)
S["TWA_Smash"] = (norm(sh + tinkles + 0.6 * wood_knock(1.0, 120)), False)

# Whetstone: long scrapes back and forth
d = 1.2; t = t_(d)
scr = bandpass(noise(d), 1800, 7000)
am = 0.35 + 0.65 * np.abs(np.sin(np.pi * t / 0.6)) ** 0.7
S["TWA_Whetstone"] = (norm(loop_fade(scr * am * (1 + 0.2 * np.sin(2 * np.pi * 37 * t)))), True)

# Saw: rasping strokes with tooth buzz
d = 1.0; t = t_(d)
teeth = np.sign(np.sin(2 * np.pi * 95 * t)) * 0.3
rasp = bandpass(noise(d), 700, 4500) + teeth
am = np.abs(np.sin(np.pi * t / 0.5)) ** 0.5
S["TWA_Saw"] = (norm(loop_fade(rasp * am)), True)

# Weld: crackling arc + hiss
d = 1.5; t = t_(d)
hiss = highpass(noise(d), 2500) * 0.35
crack = np.zeros_like(t)
for _ in range(260):
    at = rng.uniform(0, d - 0.01); c = highpass(noise(0.004), 1500) * rng.uniform(0.3, 1)
    place(crack, c, at)
hum = 0.12 * np.sin(2 * np.pi * 110 * t)
S["TWA_Weld"] = (norm(loop_fade(hiss + crack + hum)), True)

# Screwdriver / ratchet: quick clicks with a creak
d = 1.0; t = t_(d); b = np.zeros_like(t)
for k in range(12):
    tt = t_(0.03); place(b, highpass(noise(0.03), 2500) * np.exp(-tt / 0.004) + 0.3 * np.sin(2 * np.pi * 2600 * tt) * np.exp(-tt / 0.006), k / 12 * d)
creak = bandpass(noise(d), 300, 900) * 0.15 * (0.5 + 0.5 * np.sin(2 * np.pi * 1.0 * t))
S["TWA_Screw"] = (norm(loop_fade(b + creak)), True)

# Wrapping cloth/tape: rustle
d = 1.2; t = t_(d)
rus = bandpass(noise(d), 1500, 9000) * (0.4 + 0.6 * np.abs(np.sin(2 * np.pi * 1.6 * t)))
tape = np.zeros_like(t)
for _ in range(80):
    place(tape, highpass(noise(0.002), 3000) * 0.5, rng.uniform(0, d - 0.01))
S["TWA_Wrap"] = (norm(loop_fade(rus + tape)), True)

# Grindstone: whirring wheel with grit
d = 1.0; t = t_(d)
whir = 0.4 * np.sin(2 * np.pi * 140 * t + 2 * np.sin(2 * np.pi * 3 * t)) + 0.2 * np.sin(2 * np.pi * 280 * t)
grit = bandpass(noise(d), 2500, 8000) * 0.6
S["TWA_Grind"] = (norm(loop_fade(whir + grit)), True)

# Bellows: breathing whoosh with fire crackle
d = 1.6; t = t_(d)
whoosh = lowpass(noise(d), 700) * (0.25 + 0.75 * np.sin(np.pi * t / 0.8) ** 2)
crack = np.zeros_like(t)
for _ in range(40): place(crack, highpass(noise(0.006), 1800) * rng.uniform(0.2, 0.7), rng.uniform(0, d - 0.01))
S["TWA_Bellows"] = (norm(loop_fade(whoosh * 2 + crack)), True)

# Quench: violent hiss that keeps bubbling
d = 1.5; t = t_(d)
hiss = highpass(noise(d), 3000) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.7 * t))
bub = np.zeros_like(t)
for _ in range(70):
    f = rng.uniform(300, 900); tt = t_(0.05)
    place(bub, np.sin(2 * np.pi * f * tt * (1 + tt * 8)) * np.exp(-tt / 0.015) * 0.3, rng.uniform(0, d - 0.06))
S["TWA_Quench"] = (norm(loop_fade(hiss + bub)), True)

# Pour: heavy molten glug + sizzle
d = 1.2; t = t_(d)
glug = lowpass(noise(d), 350) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 2.5 * t)))
S["TWA_Pour"] = (norm(loop_fade(glug * 2 + highpass(noise(d), 4000) * 0.25)), True)

# Coating: brush swishes
d = 1.0; t = t_(d)
S["TWA_Coat"] = (norm(loop_fade(bandpass(noise(d), 800, 5000) * np.sin(np.pi * t / 0.5) ** 2)), True)

# Sewing: thread drawn through leather (zip), a soft pop
d = 1.0; t = t_(d); b = np.zeros_like(t)
zip_ = bandpass(noise(0.35), 2000, 8000) * np.linspace(0.2, 1, int(0.35 * SR)) * np.linspace(1, 0.3, int(0.35 * SR))
place(b, zip_, 0.05); place(b, wood_knock(0.06, 500) * 0.4, 0.42)
S["TWA_Sew"] = (norm(loop_fade(b)), True)

# Hand drill: grinding into wood with a low rumble
d = 1.0; t = t_(d)
S["TWA_Drill"] = (norm(loop_fade(bandpass(noise(d), 400, 3000) * (0.7 + 0.3 * np.sin(2 * np.pi * 6 * t)) + 0.2 * np.sin(2 * np.pi * 75 * t))), True)

# Carving: knife scraping wood, short strokes
d = 1.0; t = t_(d)
S["TWA_Carve"] = (norm(loop_fade(bandpass(noise(d), 1200, 6000) * np.abs(np.sin(np.pi * t / 0.33)) ** 1.5)), True)

# Generic workshop tinkering (Start/Cancel/Incomplete/Finish, fallbacks)
d = 2.0; t = t_(d); b = np.zeros_like(t)
for at, kind in ((0.05, "m"), (0.45, "w"), (0.8, "m"), (1.25, "w"), (1.6, "m")):
    place(b, metal_hit(0.3, rng.uniform(700, 1100), 0.6) * 0.5 if kind == "m" else wood_knock(0.2, rng.uniform(150, 260)), at)
b += bandpass(noise(d), 1000, 5000) * 0.08
S["TWA_Craft"] = (norm(loop_fade(b)), True)

# Minigame results (UI)
d = 0.6; t = t_(d)
chime = sum(np.sin(2 * np.pi * f * t) * np.exp(-t / 0.25) * a for f, a in ((880, 1), (1320, 0.6), (1760, 0.3)))
chime[int(0.12 * SR):] += (np.sin(2 * np.pi * 1175 * t) * np.exp(-t / 0.2))[: len(chime) - int(0.12 * SR)] * 0.8
S["TWA_Success"] = (norm(chime * adsr(len(t), 0.005, 0.05), 0.6), False)
d = 0.5; t = t_(d)
thud = np.sin(2 * np.pi * 110 * t * (1 - t)) * np.exp(-t / 0.12) + lowpass(noise(d), 400) * np.exp(-t / 0.05)
S["TWA_Fail"] = (norm(thud, 0.7), False)

os.makedirs(SOUND_DIR, exist_ok=True)
lines = ["/* GENERATED by mods/HARMONIE_TheWayToAttack/tools/gen_sounds.py -- every",
         "   sound here is synthesized by that script (no recorded audio). */",
         "module Base", "{"]
for name, (x, loop) in S.items():
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(os.path.join(SOUND_DIR, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data)
    ui = name in ("TWA_Success", "TWA_Fail")
    lines += ["    sound %s" % name, "    {",
              "        category = %s," % ("UI" if ui else "Item"),
              "        loop = %s," % ("true" if loop else "false"),
              "        is3D = %s," % ("false" if ui else "true"),
              "        clip", "        {",
              "            file = media/sound/%s.wav," % name,
              "            distanceMin = 2,", "            distanceMax = 20,",
              "            volume = 0.8,", "        }", "    }", ""]
lines.append("}")
open(SCRIPT, "w").write("\n".join(lines) + "\n")
print("sounds:", len(S))
