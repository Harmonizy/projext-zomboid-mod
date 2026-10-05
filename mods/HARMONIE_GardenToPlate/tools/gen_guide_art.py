#!/usr/bin/env python3
"""HARMONIE - From Garden to Plate: the vitamin guide window's own art.

Writes 42/media/textures/GTP_UI/:
  tab_overview / tab_vitamins / tab_foods / tab_other .png -- the four tab
      icons: the same badge layout as Home Medic's / The Way To Attack's /
      the SVU3 window's tabs (rounded plate, coloured rim), in green;
  pin_on / pin_off .png -- the pin button;
  icon_close / icon_plus / icon_minus .png -- close, text bigger (A+),
      text smaller (A-).
All drawn here with Pillow (4x supersampled), nothing copied.
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "42", "media", "textures", "GTP_UI")
os.makedirs(OUT, exist_ok=True)

WHITE = (240, 255, 240, 255)
SKY = (126, 230, 132, 255)
SKY_D = (60, 160, 80, 255)
PLATE = (8, 34, 14, 240)
RIM = (96, 200, 110, 255)
DARK = (6, 20, 8, 255)
ORANGE = (255, 150, 40, 255)
RED = (230, 70, 60, 255)
YELLOW = (255, 214, 80, 255)
BROWN = (150, 98, 52, 255)
STEEL = (180, 190, 196, 255)


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



def tab_overview():
    """Overview: a heart-rate style line over a leaf."""
    img, d, s = canvas()
    d.ellipse([30 * s, 26 * s, 98 * s, 94 * s], fill=SKY_D)
    d.polygon(P(s, [(64, 22), (100, 60), (64, 104), (28, 60)]), fill=SKY)
    d.line(P(s, [(64, 30), (64, 98)]), fill=PLATE, width=int(4 * s))
    d.line(P(s, [(14, 64), (40, 64), (50, 44), (62, 84), (74, 50), (82, 64), (114, 64)]), fill=WHITE, width=int(6 * s), joint="curve")
    done(img, "tab_overview")


def tab_vitamins():
    """Vitamins: a capsule with a small leaf."""
    img, d, s = canvas()
    d.rounded_rectangle([26 * s, 48 * s, 102 * s, 80 * s], radius=16 * s, fill=WHITE)
    d.rounded_rectangle([26 * s, 48 * s, 64 * s, 80 * s], radius=16 * s, fill=SKY)
    d.rectangle([48 * s, 48 * s, 64 * s, 80 * s], fill=SKY)
    d.ellipse([70 * s, 18 * s, 100 * s, 42 * s], fill=SKY_D)
    d.line(P(s, [(72, 40), (98, 20)]), fill=WHITE, width=int(3 * s))
    for (x, y, c) in ((34, 92, ORANGE), (56, 98, RED), (78, 92, YELLOW)):
        d.ellipse([x * s, y * s, (x + 14) * s, (y + 14) * s], fill=c)
    done(img, "tab_vitamins")


def tab_foods():
    """Foods: a carrot, an apple and a fish."""
    img, d, s = canvas()
    d.polygon(P(s, [(22, 34), (40, 28), (70, 92), (64, 96)]), fill=ORANGE)
    d.polygon(P(s, [(22, 34), (14, 20), (28, 26)]), fill=SKY)
    d.polygon(P(s, [(26, 30), (30, 14), (36, 28)]), fill=SKY)
    d.ellipse([66 * s, 26 * s, 106 * s, 64 * s], fill=RED)
    d.line(P(s, [(86, 28), (90, 16)]), fill=BROWN, width=int(4 * s))
    d.ellipse([88 * s, 12 * s, 102 * s, 22 * s], fill=SKY)
    d.ellipse([60 * s, 76 * s, 100 * s, 100 * s], fill=STEEL)
    d.polygon(P(s, [(98, 88), (114, 76), (114, 100)]), fill=STEEL)
    d.ellipse([68 * s, 84 * s, 74 * s, 90 * s], fill=DARK)
    done(img, "tab_foods")


def tab_other():
    """Other sources: a jar of home-canned food and a pill bottle."""
    img, d, s = canvas()
    d.rounded_rectangle([20 * s, 40 * s, 62 * s, 104 * s], radius=6 * s, fill=STEEL)
    d.rectangle([20 * s, 58 * s, 62 * s, 86 * s], fill=WHITE)
    d.ellipse([32 * s, 64 * s, 50 * s, 80 * s], fill=ORANGE)
    d.rectangle([18 * s, 32 * s, 64 * s, 42 * s], fill=SKY_D)
    d.rounded_rectangle([72 * s, 44 * s, 108 * s, 104 * s], radius=6 * s, fill=(240, 160, 60, 255))
    d.rectangle([70 * s, 32 * s, 110 * s, 46 * s], fill=WHITE)
    d.rectangle([76 * s, 62 * s, 104 * s, 86 * s], fill=WHITE)
    d.rectangle([88 * s, 66 * s, 92 * s, 82 * s], fill=SKY_D)
    d.rectangle([82 * s, 72 * s, 98 * s, 76 * s], fill=SKY_D)
    done(img, "tab_other")


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


for f in (tab_overview, tab_vitamins, tab_foods, tab_other):
    f()
pin_icon(True)
pin_icon(False)
for n, g in (("icon_close", g_close), ("icon_plus", g_plus), ("icon_minus", g_minus)):
    ui_icon(n, g)
print("ok")
