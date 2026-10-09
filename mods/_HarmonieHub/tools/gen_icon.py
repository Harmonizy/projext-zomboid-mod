#!/usr/bin/env python3
"""The HARMONIE "H" mark for every right-click option of our mods (drawn
here, no outside art). 64x64 RGBA -> ../media/ui/HARMONIE_H.png"""
import os
from PIL import Image, ImageDraw, ImageFilter
S = 64; SS = 4; W = S * SS
im = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
r = 14 * SS
# a dark plate with a gold rim
d.rounded_rectangle([2 * SS, 2 * SS, W - 2 * SS, W - 2 * SS], r, fill=(22, 20, 28, 255), outline=(232, 186, 74, 255), width=4 * SS)
# the H: two posts and a bar, slightly bevelled
gold, light = (240, 196, 84, 255), (255, 232, 160, 255)
post = 10 * SS; top, bot = 14 * SS, W - 14 * SS
lx, rx = 17 * SS, W - 17 * SS - post
for x in (lx, rx):
    d.rounded_rectangle([x, top, x + post, bot], 3 * SS, fill=gold)
    d.rectangle([x + 2 * SS, top + 2 * SS, x + 4 * SS, bot - 2 * SS], fill=light)
d.rounded_rectangle([lx, W // 2 - 5 * SS, rx + post, W // 2 + 5 * SS], 3 * SS, fill=gold)
d.rectangle([lx + post, W // 2 - 3 * SS, rx, W // 2 - 1 * SS], fill=light)
im = im.resize((S, S), Image.LANCZOS)
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "media", "ui", "HARMONIE_H.png")
im.save(out)
print("wrote", os.path.normpath(out))
