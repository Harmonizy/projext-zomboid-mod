#!/usr/bin/env python3
# The H icon in each mod's own colour (owner 2026-11-17: the mod rows under
# "HARMONIE: open a tab" show the H in that mod's theme colour, not gold).
# Recolours the gold letter of media/ui/HARMONIE_H.png to each card's accent
# (Hub.CARDS[i].accent in HARMONIE_Hub.lua -- keep the two lists in step).
# Run with /usr/bin/python3 (it has Pillow).
import os, colorsys
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "media", "ui", "HARMONIE_H.png")
ACCENT = {
    "gtp": (0.50, 0.90, 0.52), "twa": (1.0, 0.78, 0.2), "hm": (0.3, 0.84, 1.0),
    "svu": (0.45, 0.68, 1.0), "mfs": (0.92, 0.24, 0.20), "lws": (0.70, 0.49, 0.28),
}
src = Image.open(SRC).convert("RGBA")
GOLD = (240, 196, 84)
gl = colorsys.rgb_to_hls(*[c / 255 for c in GOLD])[1]
for mid, acc in ACCENT.items():
    out = src.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            # the letter = saturated warm pixels; the dark plate stays
            if s > 0.35 and l > 0.25:
                k = l / gl  # keep the letter's shading (edges)
                nr, ng, nb = (min(1.0, c * k) for c in acc)
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    path = os.path.join(HERE, "..", "media", "ui", "HARMONIE_H_%s.png" % mid)
    out.save(path)
    print("wrote", os.path.normpath(path))
