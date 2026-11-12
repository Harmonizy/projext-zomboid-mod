#!/usr/bin/env python3
"""The HARMONIE admin-test mark (a flask on a dark plate with a red rim, the
same plate as HARMONIE_H.png). 64x64 RGBA -> ../media/ui/HARMONIE_icon_test.png"""
import os
from PIL import Image, ImageDraw
S = 64; SS = 4; W = S * SS
im = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.rounded_rectangle([2*SS, 2*SS, W-2*SS, W-2*SS], 14*SS, fill=(22, 20, 28, 255), outline=(225, 80, 70, 255), width=4*SS)
glass, liquid, light = (235, 235, 245, 255), (120, 220, 140, 255), (255, 255, 255, 255)
# neck
d.rectangle([27*SS, 13*SS, 37*SS, 27*SS], fill=glass)
d.rectangle([24*SS, 12*SS, 40*SS, 15*SS], fill=glass)
# body (triangle flask)
d.polygon([(27*SS, 26*SS), (37*SS, 26*SS), (50*SS, 50*SS), (14*SS, 50*SS)], fill=glass)
d.polygon([(22*SS, 38*SS), (42*SS, 38*SS), (48*SS, 48*SS), (16*SS, 48*SS)], fill=liquid)
d.ellipse([24*SS, 41*SS, 28*SS, 45*SS], fill=light)
d.ellipse([33*SS, 43*SS, 36*SS, 46*SS], fill=light)
im = im.resize((S, S), Image.LANCZOS)
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "media", "ui", "HARMONIE_icon_test.png")
im.save(out); print("wrote", os.path.normpath(out))
