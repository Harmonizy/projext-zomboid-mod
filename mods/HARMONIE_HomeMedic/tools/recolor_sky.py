#!/usr/bin/env python3
"""HARMONIE - Home Medic 0.27.2: the window icons (our own drawn tab / pin /
check icons) moved from the old blue (hue ~213) to the new sky / medical
cyan of HM_Theme (hue ~197), so Home Medic no longer looks like SVU3's
navy mechanic window. Only blue pixels (hue 190-240) move; red, white and
the rest stay. Run once; running again does nothing more (already sky)."""
import colorsys, glob, os
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.join(HERE, "..", "42", "media", "textures", "HARMONIE_HomeMedic")
SHIFT = -16 / 360.0
n_files = 0
for p in sorted(glob.glob(os.path.join(DIR, "tab_*.png")) + glob.glob(os.path.join(DIR, "pin_*.png")) + [os.path.join(DIR, "icon_check.png")]):
    im = Image.open(p).convert("RGBA")
    px = im.load(); changed = 0
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            if a == 0: continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if 190 / 360 <= h <= 240 / 360 and s > 0.12:
                h = h + SHIFT
                s = min(1.0, s * 1.05)
                r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v)
                px[x, y] = (round(r2 * 255), round(g2 * 255), round(b2 * 255), a); changed += 1
    if changed:
        im.save(p); n_files += 1
        print("%-20s %5d pixels" % (os.path.basename(p), changed))
print("files", n_files)
