"""How to Survive moodle icons (HTS 1.2.9), our own drawings.
HM_BloodLoss: red drop. HM_Saline: pale blue drop with a red core.
HM_Stump: a bandaged arm stump.
Writes 42/media/ui/<name>.png (30x30) and 42/media/ui/Moodles/128/<name>.png.
Run with /usr/bin/python3 (Pillow) from mods/HARMONIE_HomeMedic."""
from PIL import Image, ImageDraw
import math, os

def drop(S, d, outer, inner, core=None):
    cx, r, cy, tip = S / 2, S * 0.30, S * 0.62, S * 0.10
    ang = math.asin(r / (cy - tip))
    left = (cx - r * math.cos(ang), cy - r * math.sin(ang))
    right = (cx + r * math.cos(ang), cy - r * math.sin(ang))
    d.polygon([(cx, tip), left, right], fill=outer)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=outer)
    r2 = r * 0.82
    d.ellipse([cx - r2, cy - r2 + S * 0.01, cx + r2, cy + r2 + S * 0.01], fill=inner)
    if core:
        r3 = r * 0.38
        d.ellipse([cx - r3, cy - r3 + S * 0.05, cx + r3, cy + r3 + S * 0.05], fill=core)
    d.ellipse([cx - r * 0.55, cy - r * 0.55, cx - r * 0.15, cy - r * 0.05], fill=(255, 255, 255, 170))

def blood(S, d): drop(S, d, (150, 10, 18, 255), (205, 28, 36, 255))
def saline(S, d): drop(S, d, (40, 110, 170, 255), (140, 200, 240, 255), (200, 40, 50, 255))

def stump(S, d):
    # forearm going down-left to a rounded, bandaged end
    skin, edge, band, line = (226, 180, 140, 255), (120, 80, 55, 255), (245, 245, 238, 255), (190, 60, 60, 255)
    w = S * 0.30
    x0, y0, x1, y1 = S * 0.30, S * 0.12, S * 0.70, S * 0.62
    d.rounded_rectangle([x0 - S*0.02, y0 - S*0.02, x1 + S*0.02, y1], radius=S*0.06, fill=edge)
    d.rounded_rectangle([x0, y0, x1, y1], radius=S*0.05, fill=skin)
    d.ellipse([x0 - S*0.02, y1 - S*0.18, x1 + S*0.02, S*0.90], fill=edge)
    d.ellipse([x0, y1 - S*0.16, x1, S*0.88], fill=band)
    d.rectangle([x0, y1 - S*0.20, x1, y1 + S*0.06], fill=band)
    for k in (0.0, 0.08, 0.16):
        yy = y1 - S*0.17 + S*k
        d.line([x0 + S*0.02, yy, x1 - S*0.02, yy + S*0.04], fill=(205, 205, 195, 255), width=max(1, int(S*0.02)))
    d.ellipse([S*0.45, S*0.70, S*0.58, S*0.80], fill=line)

def make(fn, size):
    S = size * 4
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    fn(S, ImageDraw.Draw(im))
    return im.resize((size, size), Image.LANCZOS)

base = os.path.join("42", "media", "ui")
os.makedirs(os.path.join(base, "Moodles", "128"), exist_ok=True)
for name, fn in (("HM_BloodLoss", blood), ("HM_Saline", saline), ("HM_Stump", stump)):
    make(fn, 30).save(os.path.join(base, name + ".png"))
    make(fn, 128).save(os.path.join(base, "Moodles", "128", name + ".png"))
print("written")
