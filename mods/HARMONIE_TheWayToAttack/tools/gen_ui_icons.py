#!/usr/bin/env python3
"""Draws the crafting window's sound button icons (round 14: "ปุ่มปิดเสียงใน
ui คราฟ ... ปุ่มให้เป็นรูปโทรโข่ง"): a megaphone with sound waves (on) and
the same megaphone crossed out (off). 32x32, drawn 8x and scaled down.
R68: also the yellow dot that blinks on the next button to press and on
the procedures still to do (it replaced R67's yellow tick); the favourite
star (on / off) of the recipe list.
Needs Pillow."""
import os
from PIL import Image, ImageDraw

S, N = 32, 8
W = S * N
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "42", "media", "textures")

def megaphone(d, col, dark):
    # mouthpiece, cone, handle
    d.rectangle([28, 104, 70, 152], fill=col, outline=dark, width=6)
    d.polygon([(70, 96), (170, 44), (170, 212), (70, 160)], fill=col, outline=dark)
    d.line([(70, 96), (170, 44), (170, 212), (70, 160), (70, 96)], fill=dark, width=6)
    d.rectangle([168, 40, 182, 216], fill=dark)
    d.polygon([(92, 160), (112, 160), (104, 210), (86, 210)], fill=dark)

def make(on):
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    col = (235, 200, 90, 255) if on else (150, 150, 155, 255)
    dark = (40, 32, 20, 255)
    megaphone(d, col, dark)
    if on:
        for r in (36, 62):
            d.arc([176 - r, 128 - r - 10, 176 + r + 20, 128 + r + 10], -50, 50, fill=(235, 200, 90, 255), width=12)
    else:
        d.line([(30, 30), (226, 226)], fill=(40, 10, 10, 255), width=30)
        d.line([(30, 30), (226, 226)], fill=(230, 60, 50, 255), width=18)
    out = img.resize((S, S), Image.LANCZOS)
    out.save(os.path.join(OUT, "TWA_UI_Sound%s.png" % ("On" if on else "Off")))

def dot():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([28, 28, 228, 228], fill=(30, 22, 0, 255))
    d.ellipse([52, 52, 204, 204], fill=(255, 214, 30, 255))
    d.ellipse([84, 76, 132, 116], fill=(255, 244, 170, 255))  # small shine
    img.resize((S, S), Image.LANCZOS).save(os.path.join(OUT, "TWA_UI_DotYellow.png"))

import math
def star(on):
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = []
    for i in range(10):
        r = 112 if i % 2 == 0 else 46
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((128 + r * math.cos(a), 134 + r * math.sin(a)))
    if on:
        d.polygon(pts, fill=(255, 205, 40, 255), outline=(60, 40, 0, 255))
        d.line(pts + [pts[0]], fill=(60, 40, 0, 255), width=10)
    else:
        d.line(pts + [pts[0]], fill=(30, 30, 30, 255), width=22)
        d.line(pts + [pts[0]], fill=(170, 170, 175, 255), width=12)
    img.resize((S, S), Image.LANCZOS).save(os.path.join(OUT, "TWA_UI_Star%s.png" % ("On" if on else "Off")))

make(True); make(False); dot(); star(True); star(False)
print("ok")
