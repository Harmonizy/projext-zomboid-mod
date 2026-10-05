#!/usr/bin/env python3
"""HARMONIE - SVU3 Sandbox: the vehicle upgrade window's own art.

Writes 42/media/textures/HSVU_UI/:
  tab_vehicle / tab_upgrades / tab_tiers / tab_guide .png -- the four tab
      icons: the same badge layout as Home Medic's / The Way To Attack's tabs
      (rounded plate, coloured rim), in dark navy with a light blue rim;
  pin_on / pin_off .png -- the pin button;
  icon_close / icon_plus / icon_minus .png -- close, text bigger (A+),
      text smaller (A-).
All drawn here with Pillow (4x supersampled), nothing copied.
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "42", "media", "textures", "HSVU_UI")
os.makedirs(OUT, exist_ok=True)

WHITE = (236, 242, 255, 255)
SKY = (116, 174, 255, 255)
SKY_D = (64, 112, 200, 255)
PLATE = (8, 16, 42, 240)
RIM = (92, 140, 230, 255)
STEEL = (170, 182, 200, 255)
STEEL_D = (96, 108, 130, 255)
DARK = (6, 10, 24, 255)
TIRE = (30, 34, 44, 255)
AMBER = (255, 200, 70, 255)


def canvas(size=128):
    big = size * 4
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = big / 128.0
    d.rounded_rectangle([6 * s, 6 * s, 122 * s, 122 * s], radius=22 * s, fill=PLATE, outline=RIM, width=int(4 * s))
    return img, d, s


def done(img, name, size=128):
    img.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def P(s, pts):
    return [(x * s, y * s) for x, y in pts]


def tab_vehicle():
    """This car: a van seen from the side."""
    img, d, s = canvas()
    d.rounded_rectangle([18 * s, 42 * s, 110 * s, 86 * s], radius=8 * s, fill=SKY)
    d.polygon(P(s, [(70, 42), (96, 42), (110, 62), (110, 64), (70, 64)]), fill=SKY_D)
    d.polygon(P(s, [(76, 48), (94, 48), (104, 62), (76, 62)]), fill=WHITE)
    d.rectangle([26 * s, 50 * s, 64 * s, 62 * s], fill=WHITE)
    d.rectangle([18 * s, 74 * s, 110 * s, 78 * s], fill=SKY_D)
    for cx in (40, 90):
        d.ellipse([(cx - 13) * s, 74 * s, (cx + 13) * s, 100 * s], fill=TIRE)
        d.ellipse([(cx - 6) * s, 81 * s, (cx + 6) * s, 93 * s], fill=STEEL)
    done(img, "tab_vehicle")


def tab_upgrades():
    """Upgrades: a spanner over an armour plate with bolts."""
    img, d, s = canvas()
    d.rounded_rectangle([22 * s, 30 * s, 92 * s, 100 * s], radius=6 * s, fill=STEEL_D)
    d.rounded_rectangle([28 * s, 36 * s, 86 * s, 94 * s], radius=4 * s, fill=STEEL)
    for (x, y) in ((34, 42), (74, 42), (34, 82), (74, 82)):
        d.ellipse([x * s, y * s, (x + 7) * s, (y + 7) * s], fill=STEEL_D)
    d.line(P(s, [(52, 92), (98, 40)]), fill=SKY, width=int(11 * s))
    d.ellipse([88 * s, 20 * s, 114 * s, 46 * s], fill=SKY)
    d.polygon(P(s, [(98, 22), (110, 22), (104, 34)]), fill=PLATE)
    done(img, "tab_upgrades")


def tab_tiers():
    """Tiers: three bars, low to high, numbered by height."""
    img, d, s = canvas()
    for i, (x, top) in enumerate(((22, 78), (52, 56), (82, 32))):
        col = (SKY_D, SKY, WHITE)[i]
        d.rounded_rectangle([x * s, top * s, (x + 24) * s, 102 * s], radius=3 * s, fill=col)
    d.line(P(s, [(16, 104), (112, 104)]), fill=RIM, width=int(3 * s))
    d.polygon(P(s, [(86, 18), (102, 18), (94, 8)]), fill=AMBER)
    done(img, "tab_tiers")


def tab_guide():
    """Guide: an open book with a small car mark."""
    img, d, s = canvas()
    d.polygon(P(s, [(20, 34), (60, 28), (64, 34), (64, 102), (60, 96), (20, 100)]), fill=WHITE)
    d.polygon(P(s, [(108, 34), (68, 28), (64, 34), (64, 102), (68, 96), (108, 100)]), fill=WHITE)
    d.line(P(s, [(64, 32), (64, 102)]), fill=SKY_D, width=int(3 * s))
    for y in (46, 58, 70, 82):
        d.line(P(s, [(28, y), (54, y - 2)]), fill=(120, 140, 180, 255), width=int(3 * s))
    d.rounded_rectangle([76 * s, 54 * s, 100 * s, 68 * s], radius=3 * s, fill=SKY)
    for cx in (82, 95):
        d.ellipse([(cx - 4) * s, 64 * s, (cx + 4) * s, 72 * s], fill=TIRE)
    done(img, "tab_guide")


def pin_icon(pinned, size=64):
    """The pin: upright (pinned) or tipped over (unpinned), blue."""
    big = size * 4
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = big / 64.0
    col = WHITE if pinned else (170, 182, 205, 255)
    head = SKY if pinned else SKY_D
    d.ellipse([16 * s, 2 * s, 48 * s, 34 * s], fill=head, outline=DARK, width=int(2 * s))
    d.rectangle([25 * s, 30 * s, 39 * s, 38 * s], fill=col)
    d.polygon([(12 * s, 38 * s), (52 * s, 38 * s), (47 * s, 46 * s), (17 * s, 46 * s)], fill=col)
    d.polygon([(29 * s, 46 * s), (35 * s, 46 * s), (32 * s, 63 * s)], fill=col)
    if not pinned:
        img = img.rotate(45, resample=Image.BICUBIC, center=(big / 2, big / 2))
    img.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, "pin_on.png" if pinned else "pin_off.png"))


def ui_icon(name, draw, size=64):
    big = size * 4
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw(d, big / 64.0)
    img.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def g_close(d, s):
    w = int(7 * s)
    d.line([(16 * s, 16 * s), (48 * s, 48 * s)], fill=WHITE, width=w)
    d.line([(48 * s, 16 * s), (16 * s, 48 * s)], fill=WHITE, width=w)


def letter_a(d, s, big):
    """A capital A, big or small, on the left of the glyph."""
    k = 1.0 if big else 0.72
    x0, y1 = 6, 54
    h, w = 44 * k, 30 * k
    top = (x0 + w / 2, y1 - h)
    t = int(6 * s)
    d.line([(x0 * s, y1 * s), (top[0] * s, top[1] * s)], fill=WHITE, width=t)
    d.line([((x0 + w) * s, y1 * s), (top[0] * s, top[1] * s)], fill=WHITE, width=t)
    yb = y1 - h * 0.38
    d.line([((x0 + w * 0.22) * s, yb * s), ((x0 + w * 0.78) * s, yb * s)], fill=WHITE, width=int(5 * s))


def g_plus(d, s):
    letter_a(d, s, True)
    d.rectangle([40 * s, 21 * s, 60 * s, 27 * s], fill=SKY)
    d.rectangle([47 * s, 14 * s, 53 * s, 34 * s], fill=SKY)


def g_minus(d, s):
    letter_a(d, s, False)
    d.rectangle([40 * s, 21 * s, 60 * s, 27 * s], fill=SKY)


for f in (tab_vehicle, tab_upgrades, tab_tiers, tab_guide):
    f()
pin_icon(True)
pin_icon(False)
for n, g in (("icon_close", g_close), ("icon_plus", g_plus), ("icon_minus", g_minus)):
    ui_icon(n, g)
print("ok")
