#!/usr/bin/env python3
"""Synthesizes every HARMONIE_TheWayToAttack sound from scratch (no recorded
or third-party audio) -- round 11 request 2026-09-28: "เสียงเงียบเลย ไม่มี
เสียงอะไรทั้งนั้นตอนทำ ตอน action time เหมือนกัน สร้างเสียงมาเองเลยก็ได้".

Writes 16-bit mono 44.1 kHz WAV files to ../42/media/sound/ and the matching
sound script ../42/media/scripts/TWA_sounds.txt. Needs numpy.

Round 12: every sound is a SHORT one-shot of category UI, played with
getSoundManager():playUISound() -- the way Casualties Undead plays all of
its own sounds, and the only way ours were heard in game (the 3D "Item"
sounds played through the character stayed silent). A working sound is
re-triggered every LENGTH ms while the work goes on (HARMONIE_TWA_Sound.lua),
so each "loop" sound here is one short grain with soft ends. The lengths go
to lua/shared/HARMONIE_TWA_SoundLengths.lua.
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
S["TWA_Hammer"] = (norm(metal_hit(0.5, 520)), True)
S["TWA_HammerWood"] = (norm(wood_knock(0.3) + 0.35 * metal_hit(0.3, 1300, 0.3)), True)
S["TWA_Knap"] = (norm(stone_click(0.25)), True)
# Grade reveal: the big final blow, a rising tension roll and a fanfare.
d = 1.6; t = t_(d)
big = np.zeros_like(t); place(big, metal_hit(1.2, 330, 1.4) * 1.4, 0); place(big, metal_hit(1.2, 495, 1.2), 0.0)
big += lowpass(noise(d), 200) * np.exp(-t / 0.08) * 1.5
S["TWA_BigHit"] = (norm(big), False)
d = 2.4; t = t_(d)
roll = bandpass(noise(d), 150, 1200) * (0.3 + 0.7 * (t / d) ** 1.5) * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * (6 + 10 * t / d) * t)))
S["TWA_Tension"] = (norm(roll * adsr(len(t), 0.3, 0.05), 0.6), False)
d = 1.8; t = t_(d); fan = np.zeros_like(t)
for k, (f, at) in enumerate(((523, 0.0), (659, 0.12), (784, 0.24), (1047, 0.38))):
    tt = t_(d - at)
    tone = sum(np.sin(2 * np.pi * f * m * tt) * a for m, a in ((1, 1), (2, 0.35), (3, 0.15))) * np.exp(-tt / (0.5 + 0.3 * k))
    place(fan, tone * 0.6, at)
S["TWA_Fanfare"] = (norm(fan * adsr(len(t), 0.005, 0.1), 0.7), False)

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

# Round 16: the gemstone reveal -- a roulette tick, a stone cracking open and
# a glittering chime for the gem (deterministic, no rng: the earlier sounds
# keep their exact noise).
g16 = np.random.default_rng(16)
d = 0.06; t = t_(d)
tick = np.sin(2 * np.pi * 2400 * t) * np.exp(-t / 0.008) + highpass(g16.uniform(-1, 1, len(t)), 4000) * np.exp(-t / 0.004) * 0.6
S["TWA_Tick"] = (norm(tick, 0.5), False)
d = 0.7; t = t_(d); cr = np.zeros_like(t)
for at in (0.0, 0.05, 0.13, 0.2):
    n = int(0.25 * SR)
    burst = bandpass(g16.uniform(-1, 1, n), 800, 6000) * np.exp(-np.arange(n) / SR / 0.03)
    place(cr, burst * (1 - at * 2), at)
cr += lowpass(g16.uniform(-1, 1, len(t)), 180) * np.exp(-t / 0.15) * 1.2
S["TWA_Crack"] = (norm(cr, 0.75), False)
d = 2.4; t = t_(d); sh = np.zeros_like(t)
for k, f in enumerate((1568, 1976, 2349, 2637, 3136, 3951, 4699)):
    at = 0.07 * k; tt = t_(d - at)
    tone = sum(np.sin(2 * np.pi * f * m * tt) * a for m, a in ((1, 1), (2.76, 0.25), (5.4, 0.08))) * np.exp(-tt / 0.6)
    place(sh, tone * 0.35, at)
sh += highpass(g16.uniform(-1, 1, len(t)), 7000) * np.exp(-t / 0.5) * 0.15 * (0.5 + 0.5 * np.sin(2 * np.pi * 23 * t))
S["TWA_Shimmer"] = (norm(sh * adsr(len(t), 0.005, 0.2), 0.6), False)

# Round 18: a crowd -- applause for an S grade or a diamond, booing for an F
# grade or dung (deterministic, own rng).
g18 = np.random.default_rng(18)
d = 3.2; t = t_(d); ap = np.zeros_like(t)
for k in range(900):                       # ~40 people clapping, loose rhythm
    at = g18.uniform(0, d - 0.05)
    n = int(0.03 * SR)
    clap = bandpass(g18.uniform(-1, 1, n), 700 + g18.uniform(0, 900), 4500) * np.exp(-np.arange(n) / SR / 0.006)
    place(ap, clap * g18.uniform(0.3, 1.0), at)
ap *= np.minimum(1, t / 0.25) * np.minimum(1, (d - t) / 1.2)
cheer = np.zeros_like(t)
for k in range(6):                         # a few whoops in the crowd
    at = g18.uniform(0.1, 1.6); n = int(0.5 * SR); tt = np.arange(n) / SR
    f = g18.uniform(500, 900) * (1 + 0.4 * np.sin(np.pi * tt / 0.5))
    v = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / 0.5)
    place(cheer, v * 0.12, at)
S["TWA_Applause"] = (norm(ap + cheer, 0.7), False)
d = 2.6; t = t_(d); boo = np.zeros_like(t)
for k in range(16):                        # many voices going "boooo"
    f0 = g18.uniform(95, 190); at = g18.uniform(0, 0.4)
    tt = t_(d - at)
    f = f0 * (1 - 0.12 * tt / d) * (1 + 0.02 * np.sin(2 * np.pi * g18.uniform(4, 6) * tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    src = sum(np.sin(m * ph) / m for m in range(1, 12))
    voice = bandpass(src, 200, 1000) * np.minimum(1, tt / 0.15) * np.minimum(1, (d - at - tt) / 0.5)
    place(boo, voice * g18.uniform(0.5, 1.0), at)
boo += lowpass(g18.uniform(-1, 1, len(t)), 500) * 0.05
S["TWA_Boo"] = (norm(boo, 0.7), False)

# Working sounds: one grain each (see the docstring).
GRAIN = { "TWA_Whetstone": 0.6, "TWA_Saw": 0.5, "TWA_Weld": 0.6, "TWA_Screw": 0.5, "TWA_Wrap": 0.6,
          "TWA_Grind": 0.5, "TWA_Bellows": 0.8, "TWA_Quench": 0.7, "TWA_Pour": 0.6, "TWA_Coat": 0.5,
          "TWA_Sew": 0.5, "TWA_Drill": 0.5, "TWA_Carve": 0.33, "TWA_Craft": 1.0 }
for name, g in GRAIN.items():
    x, _ = S[name]
    n = int(g * SR); y = x[:n].copy(); f = int(0.04 * SR)
    y[:f] *= np.linspace(0, 1, f); y[-f:] *= np.linspace(1, 0, f)
    S[name] = (norm(y), True)

os.makedirs(SOUND_DIR, exist_ok=True)
# Round 14 ("การตั้งค่าเราเหมือนไม่ได้ควบคุมระดับเสียงได้เลย"): the game's
# per-sound user volume didn't change our UI sounds, so every sound is ALSO
# written at fixed loudness levels -- NAME_v25 / _v50 / _v75 / (NAME = 100) /
# _v150 / _v200 -- and TWASound plays the file matching the player's
# volume. Above 100 a soft limiter keeps it from clipping. Files are
# 22.05 kHz to keep the six sets small.
LEVELS = [(25, 0.25), (50, 0.5), (75, 0.75), (100, 1.0), (150, 1.5), (200, 2.0)]
OUT_SR = 22050
for f in os.listdir(SOUND_DIR):
    if f.startswith("TWA_") and f.endswith(".wav"): os.remove(os.path.join(SOUND_DIR, f))
lines = ["/* GENERATED by mods/HARMONIE_TheWayToAttack/tools/gen_sounds.py -- every",
         "   sound here is synthesized by that script (no recorded audio). */",
         "module Base", "{"]
for name, (x, loop) in S.items():
    y = lowpass(x, 9500)[::2]
    for tag, g in LEVELS:
        z = y * g
        if g > 1: z = np.tanh(z * 1.1) / np.tanh(1.1 * 0.8) * 0.8
        fname = name if tag == 100 else "%s_v%d" % (name, tag)
        data = (np.clip(z, -1, 1) * 32767).astype("<i2").tobytes()
        with wave.open(os.path.join(SOUND_DIR, fname + ".wav"), "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(OUT_SR); w.writeframes(data)
        lines += ["    sound %s" % fname, "    {",
                  "        category = UI,",
                  "        clip", "        {",
                  "            file = media/sound/%s.wav," % fname,
                  "            distanceMax = 10,", "        }", "    }", ""]
lines.append("}")
open(SCRIPT, "w").write("\n".join(lines) + "\n")
lua = ["-- GENERATED by mods/HARMONIE_TheWayToAttack/tools/gen_sounds.py -- do not edit.",
       "-- Length of every sound in ms (a working sound is re-played every LENGTH).",
       "TWASound = TWASound or {}", "TWASound.LENGTH = {"]
for name, (x, loop) in S.items():
    lua.append("    %s = %d," % (name, int(len(x) / SR * 1000)))
lua.append("}")
lua.append("-- Loudness levels every sound also exists at (NAME_vNN; 100 = NAME).")
lua.append("TWASound.LEVELS = { %s }" % ", ".join(str(t) for t, _ in LEVELS))
open(os.path.join(HERE, "..", "42", "media", "lua", "shared", "HARMONIE_TWA_SoundLengths.lua"), "w").write("\n".join(lua) + "\n")
print("sounds:", len(S))
