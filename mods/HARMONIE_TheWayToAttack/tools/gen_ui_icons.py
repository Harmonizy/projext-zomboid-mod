#!/usr/bin/env python3
"""Draws the crafting window's sound button icons (round 14: "ปุ่มปิดเสียงใน
ui คราฟ ... ปุ่มให้เป็นรูปโทรโข่ง"): a megaphone with sound waves (on) and
the same megaphone crossed out (off). 32x32, drawn 8x and scaled down.
R67: also the yellow tick that blinks beside the next button to press.
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

def tick():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = [(40, 136), (100, 196), (216, 64)]
    d.line(pts, fill=(30, 22, 0, 255), width=56, joint="curve")
    for p in pts:
        d.ellipse([p[0] - 28, p[1] - 28, p[0] + 28, p[1] + 28], fill=(30, 22, 0, 255))
    d.line(pts, fill=(255, 214, 30, 255), width=34, joint="curve")
    for p in pts:
        d.ellipse([p[0] - 17, p[1] - 17, p[0] + 17, p[1] + 17], fill=(255, 214, 30, 255))
    img.resize((S, S), Image.LANCZOS).save(os.path.join(OUT, "TWA_UI_TickYellow.png"))

make(True); make(False); tick()
print("ok")
