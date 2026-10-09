#!/usr/bin/env python3
"""HARMONIE - Mercenary Is Life: the workbench window's own icons (drawn
here, red theme -- the same badge idea as How to Survive / The Way To
Attack / Car for Crash). Writes tools/ours/media/textures/MIL_UI/*.png and
copies them into 42/ (re-run after edits)."""
import os, shutil, math
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "ours", "media", "textures", "MIL_UI")
MOD = os.path.join(HERE, "..", "42", "media", "textures", "MIL_UI")
K = 4                     # supersampling
N = 64 * K
RED, DARK, LIGHT, WHITE = (220, 52, 48, 255), (46, 8, 10, 255), (255, 150, 140, 255), (250, 238, 236, 255)


def badge():
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((2 * K, 2 * K, N - 2 * K, N - 2 * K), radius=14 * K, fill=DARK, outline=RED, width=3 * K)
    return im, d


def S(*v): return [x * K for x in v]


def cube(d):
    top = S(32, 12, 50, 21, 32, 30, 14, 21)
    d.polygon(top, fill=LIGHT)
    d.polygon(S(14, 21, 32, 30, 32, 52, 14, 43), fill=RED)
    d.polygon(S(50, 21, 32, 30, 32, 52, 50, 43), fill=(150, 30, 30, 255))
    for a, b in ((0, 1), (1, 2), (2, 3), (3, 0)):
        pass
    d.line(S(32, 30, 32, 52), fill=WHITE, width=2 * K)


def bars(d):
    for i, h in enumerate((14, 24, 34)):
        x = 15 + i * 13
        d.rectangle(S(x, 50 - h, x + 9, 50), fill=(RED, LIGHT, WHITE)[i])
    d.line(S(12, 52, 52, 52), fill=WHITE, width=2 * K)


def wrench(d):
    d.line(S(20, 44, 40, 24), fill=WHITE, width=7 * K)
    d.ellipse(S(34, 12, 52, 30), fill=WHITE)
    d.ellipse(S(40, 14, 50, 24), fill=DARK)
    d.rectangle(S(44, 10, 54, 18), fill=DARK)
    d.ellipse(S(14, 38, 26, 50), fill=RED)


def bullet(d):
    for i, x in enumerate((18, 30, 42)):
        d.rectangle(S(x - 4, 28, x + 4, 50), fill=(RED if i != 1 else LIGHT))
        d.pieslice(S(x - 4, 16, x + 4, 36), 180, 360, fill=WHITE)
        d.rectangle(S(x - 5, 48, x + 5, 52), fill=(180, 150, 60, 255))


def book(d):
    d.polygon(S(12, 18, 31, 22, 31, 50, 12, 46), fill=WHITE)
    d.polygon(S(52, 18, 33, 22, 33, 50, 52, 46), fill=LIGHT)
    for y in (28, 34, 40):
        d.line(S(16, y, 28, y + 2), fill=RED, width=2 * K)
        d.line(S(36, y + 2, 48, y), fill=RED, width=2 * K)


def close(d):
    d.line(S(20, 20, 44, 44), fill=WHITE, width=6 * K)
    d.line(S(44, 20, 20, 44), fill=WHITE, width=6 * K)


def crosshair(d):
    d.ellipse(S(14, 14, 50, 50), outline=WHITE, width=4 * K)
    d.ellipse(S(26, 26, 38, 38), fill=RED)
    for a, b, c, e in ((32, 6, 32, 20), (32, 44, 32, 58), (6, 32, 20, 32), (44, 32, 58, 32)):
        d.line(S(a, b, c, e), fill=WHITE, width=3 * K)


def plus(d):
    d.line(S(18, 32, 46, 32), fill=WHITE, width=6 * K)
    d.line(S(32, 18, 32, 46), fill=WHITE, width=6 * K)


def minus(d):
    d.line(S(18, 32, 46, 32), fill=WHITE, width=6 * K)


def pin(on):
    def f(d):
        col = WHITE if on else (150, 110, 108, 255)
        d.ellipse(S(22, 12, 42, 30), fill=RED if on else (110, 30, 30, 255))
        d.polygon(S(26, 26, 38, 26, 35, 38, 29, 38), fill=col)
        d.line(S(32, 38, 32 if on else 22, 54), fill=col, width=3 * K)
    return f


ICONS = {"tab_inspect": cube, "tab_stats": bars, "tab_parts": wrench, "tab_ammo": bullet,
         "tab_guide": book, "icon_close": close, "emblem": crosshair,
         "icon_plus": plus, "icon_minus": minus, "pin_on": pin(True), "pin_off": pin(False)}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(MOD, exist_ok=True)
    for name, fn in ICONS.items():
        im, d = badge()
        fn(d)
        im = im.resize((64, 64), Image.LANCZOS)
        p = os.path.join(OUT, name + ".png")
        im.save(p, optimize=True)
        shutil.copy2(p, os.path.join(MOD, name + ".png"))
        print(name)
