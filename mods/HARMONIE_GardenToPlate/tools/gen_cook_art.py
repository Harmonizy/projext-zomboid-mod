#!/usr/bin/env python3
"""HARMONIE - From Garden to Plate: the cooking minigames' scene art (0.13.0).
Drawn here with Pillow, 3x supersampled -- nothing copied from any game or mod.
Writes 42/media/textures/GTP_UI/cookgame_*.png.

Rims and frames (pot, bowl, mortar, pan, mug, jug) are drawn with an EMPTY
middle: the minigame paints what is inside (soup, batter, tea ...) under them,
so one picture serves every recipe."""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "42", "media", "textures", "GTP_UI")
os.makedirs(OUT, exist_ok=True)
S = 3
random.seed(42)


def canvas(w, h):
    img = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def save(img, name):
    w, h = img.size
    img.resize((w // S, h // S), Image.LANCZOS).save(os.path.join(OUT, "cookgame_" + name + ".png"))


def P(*v): return [int(x * S) for x in v]


def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def radial_ring(d, cx, cy, r_out, r_in, c_out, c_in, steps=40, hilite=None):
    """a ring shaded from its outer to its inner edge (metal / ceramic rims)"""
    for i in range(steps):
        t = i / (steps - 1)
        r = r_out - (r_out - r_in) * t
        col = lerp(c_out, c_in, math.sin(t * math.pi))
        d.ellipse(P(cx - r, cy - r, cx + r, cy + r), fill=col)
    d.ellipse(P(cx - r_in, cy - r_in, cx + r_in, cy + r_in), fill=(0, 0, 0, 0))
    if hilite:
        d.arc(P(cx - r_out + 3, cy - r_out + 3, cx + r_out - 3, cy + r_out - 3), 200, 290, fill=hilite, width=int(2.5 * S))


def counter():
    w, h = 560, 290
    img, d = canvas(w, h)
    base = (198, 186, 166, 255)
    d.rectangle(P(0, 0, w, h), fill=base)
    # speckled stone worktop
    for _ in range(9000):
        x, y = random.uniform(0, w), random.uniform(0, h)
        c = random.choice([(170, 158, 140, 255), (215, 205, 188, 255), (150, 140, 124, 255), (226, 218, 204, 255)])
        r = random.uniform(0.4, 1.3)
        d.ellipse(P(x - r, y - r, x + r, y + r), fill=c)
    # tile seams and a soft light from the top left
    for x in range(0, w, 140): d.line(P(x, 0, x, h), fill=(160, 150, 134, 255), width=S)
    shade = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for i in range(60):
        a = int(70 * (i / 60))
        sd.rectangle(P(0, h - i * 2, w, h - i * 2 + 2), fill=(40, 30, 20, a // 3))
    img = Image.alpha_composite(img, shade)
    save(img, "counter")


def board():
    w, h = 470, 210
    img, d = canvas(w, h)
    d.rounded_rectangle(P(4, 8, w - 4, h - 2), radius=18 * S, fill=(70, 46, 24, 140))       # shadow
    d.rounded_rectangle(P(0, 0, w - 8, h - 10), radius=18 * S, fill=(176, 122, 70, 255), outline=(96, 62, 32, 255), width=2 * S)
    # wood grain
    for i in range(34):
        y = 8 + i * 5.7 + random.uniform(-1, 1)
        col = random.choice([(158, 106, 58, 255), (190, 136, 82, 255), (166, 112, 62, 255)])
        pts = [(x, y + math.sin(x / 37 + i) * 2.4 + math.sin(x / 11) * 0.6) for x in range(14, w - 22, 6)]
        d.line([(px * S, py * S) for px, py in pts], fill=col, width=int(1.4 * S))
    for _ in range(3):  # knots
        kx, ky = random.uniform(60, w - 80), random.uniform(30, h - 50)
        for r in range(9, 1, -2):
            d.ellipse(P(kx - r * 1.6, ky - r, kx + r * 1.6, ky + r), outline=(130, 84, 42, 255), width=S)
    d.rounded_rectangle(P(14, 12, w - 22, h - 22), radius=12 * S, outline=(150, 100, 54, 255), width=int(2.5 * S))  # juice groove
    d.ellipse(P(w - 46, h / 2 - 15, w - 26, h / 2 + 5), fill=(80, 52, 26, 255))  # hanging hole
    save(img, "board")


def basin():
    w, h = 330, 250
    img, d = canvas(w, h)
    d.rounded_rectangle(P(0, 20, w, h), radius=26 * S, fill=(150, 156, 164, 255), outline=(90, 96, 104, 255), width=2 * S)
    d.rounded_rectangle(P(16, 34, w - 16, h - 14), radius=20 * S, fill=(118, 124, 132, 255))
    for i in range(30):  # water, lighter at the top
        t = i / 29
        d.rounded_rectangle(P(20 + i * 0.3, 40 + i * 0.3 + 40, w - 20 - i * 0.3, h - 18), radius=18 * S, fill=lerp((90, 150, 205, 120), (60, 118, 182, 170), t))
    for _ in range(14):  # ripples
        x, y, r = random.uniform(50, w - 50), random.uniform(100, h - 40), random.uniform(10, 26)
        d.arc(P(x - r, y - r / 3, x + r, y + r / 3), 0, 180, fill=(200, 230, 255, 150), width=S)
    # tap
    d.rounded_rectangle(P(w / 2 - 10, 0, w / 2 + 10, 34), radius=4 * S, fill=(196, 200, 208, 255), outline=(100, 104, 112, 255), width=S)
    d.rounded_rectangle(P(w / 2 - 34, 0, w / 2 + 34, 12), radius=5 * S, fill=(210, 214, 222, 255), outline=(100, 104, 112, 255), width=S)
    save(img, "basin")


def pot():
    w = h = 300
    img, d = canvas(w, h)
    for side in (-1, 1):  # handles
        x = w / 2 + side * 138
        d.rounded_rectangle(P(x - 16, h / 2 - 12, x + 16, h / 2 + 12), radius=6 * S, fill=(52, 54, 58, 255), outline=(20, 20, 22, 255), width=S)
    radial_ring(d, w / 2, h / 2, 128, 112, (96, 100, 108, 255), (206, 212, 220, 255), hilite=(250, 250, 255, 220))
    save(img, "pot")


def bowl():
    w = h = 300
    img, d = canvas(w, h)
    radial_ring(d, w / 2, h / 2, 132, 110, (204, 196, 178, 255), (250, 246, 236, 255), hilite=(255, 255, 255, 230))
    d.ellipse(P(w / 2 - 132, h / 2 - 132, w / 2 + 132, h / 2 + 132), outline=(120, 92, 60, 255), width=2 * S)
    for a in range(0, 360, 30):  # a painted band
        x, y = w / 2 + math.cos(math.radians(a)) * 121, h / 2 + math.sin(math.radians(a)) * 121
        d.ellipse(P(x - 3, y - 3, x + 3, y + 3), fill=(70, 120, 170, 255))
    save(img, "bowl")


def mortar():
    w = h = 260
    img, d = canvas(w, h)
    radial_ring(d, w / 2, h / 2, 112, 80, (110, 108, 102, 255), (176, 172, 164, 255), hilite=(220, 218, 210, 200))
    for _ in range(900):
        a, r = random.uniform(0, 6.283), random.uniform(82, 110)
        x, y = w / 2 + math.cos(a) * r, h / 2 + math.sin(a) * r
        d.point(P(x, y), fill=random.choice([(90, 88, 84, 255), (190, 186, 178, 255)]))
    save(img, "mortar")


def pan():
    w, h = 400, 300
    img, d = canvas(w, h)
    cx, cy = 150, 150
    d.rounded_rectangle(P(cx + 118, cy - 14, w - 6, cy + 14), radius=12 * S, fill=(40, 30, 24, 255), outline=(14, 10, 8, 255), width=S)  # handle
    d.ellipse(P(w - 40, cy - 6, w - 28, cy + 6), fill=(90, 80, 70, 255))
    radial_ring(d, cx, cy, 130, 112, (40, 42, 46, 255), (116, 120, 128, 255), hilite=(200, 204, 212, 200))
    save(img, "pan")


def mug():
    w, h = 300, 260
    img, d = canvas(w, h)
    cx, cy = 130, 130
    d.ellipse(P(cx + 82, cy - 50, cx + 160, cy + 50), outline=(214, 84, 62, 255), width=14 * S)  # handle
    radial_ring(d, cx, cy, 110, 94, (176, 56, 44, 255), (236, 112, 90, 255), hilite=(255, 210, 200, 220))
    save(img, "mug")


def grater():
    w, h = 150, 270
    img, d = canvas(w, h)
    d.rounded_rectangle(P(10, 20, w - 10, h - 4), radius=10 * S, fill=(190, 194, 202, 255), outline=(96, 100, 108, 255), width=2 * S)
    d.rounded_rectangle(P(w / 2 - 34, 0, w / 2 + 34, 26), radius=10 * S, fill=(40, 40, 44, 255))  # handle
    for row in range(16):
        y = 36 + row * 14
        for col in range(5):
            x = 26 + col * 20 + (10 if row % 2 else 0)
            if x > w - 30: continue
            d.ellipse(P(x - 5, y - 3, x + 5, y + 3), fill=(70, 72, 78, 255))
            d.arc(P(x - 6, y - 5, x + 6, y + 3), 200, 340, fill=(250, 250, 255, 255), width=S)
    save(img, "grater")


def jug():
    w, h = 140, 250
    img, d = canvas(w, h)
    # glass: just the outline, highlights and marks -- the level is drawn behind
    d.rounded_rectangle(P(14, 8, w - 14, h - 6), radius=14 * S, outline=(210, 230, 240, 255), width=3 * S)
    d.line(P(26, 24, 26, h - 30), fill=(255, 255, 255, 120), width=3 * S)
    for i in range(1, 10):
        y = h - 6 - (h - 14) * i / 10
        d.line(P(w - 40, y, w - 18, y), fill=(220, 60, 50, 230), width=2 * S if i % 5 == 0 else S)
    save(img, "jug")


def toast():
    w = h = 240
    img, d = canvas(w, h)
    d.rounded_rectangle(P(20, 40, w - 20, h - 12), radius=26 * S, fill=(150, 92, 40, 255))
    d.ellipse(P(20, 10, w - 20, 120), fill=(150, 92, 40, 255))
    d.rounded_rectangle(P(32, 50, w - 32, h - 24), radius=20 * S, fill=(236, 196, 128, 255))
    d.ellipse(P(32, 22, w - 32, 112), fill=(236, 196, 128, 255))
    for _ in range(500):  # crumb
        x, y = random.uniform(40, w - 40), random.uniform(36, h - 32)
        d.point(P(x, y), fill=random.choice([(214, 168, 100, 255), (246, 214, 150, 255)]))
    save(img, "toast")


def dough():
    w, h = 260, 200
    img, d = canvas(w, h)
    for i in range(30):
        t = i / 29
        rx, ry = 120 - i * 2.2, 86 - i * 1.6
        d.ellipse(P(w / 2 - rx, h / 2 - ry + i * 0.6, w / 2 + rx, h / 2 + ry + i * 0.6), fill=lerp((214, 186, 140, 255), (250, 236, 206, 255), t))
    for _ in range(300):
        x, y = random.uniform(30, w - 30), random.uniform(30, h - 30)
        d.point(P(x, y), fill=(255, 255, 255, 160))
    save(img, "dough")


def hand():
    w = h = 80
    img, d = canvas(w, h)
    skin, line = (236, 190, 150, 255), (120, 80, 50, 255)
    d.rounded_rectangle(P(20, 34, 60, 76), radius=12 * S, fill=skin, outline=line, width=S)
    for i, (x, top) in enumerate([(22, 10), (32, 4), (42, 6), (52, 14)]):
        d.rounded_rectangle(P(x - 4, top, x + 4, 44), radius=4 * S, fill=skin, outline=line, width=S)
    d.rounded_rectangle(P(6, 40, 24, 50), radius=5 * S, fill=skin, outline=line, width=S)
    save(img, "hand")


for f in (counter, board, basin, pot, bowl, mortar, pan, mug, grater, jug, toast, dough, hand):
    f()
print("ok")
