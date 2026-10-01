#!/usr/bin/env python3
"""HARMONIE - Home Medic: one illustration per operation (surgery tab list and
pre-op header), composed only from our own generated surgery art
(gen_surgery_art.py output -- run that first). No third-party images.

Writes ../42/media/textures/HARMONIE_HomeMedic/surg/card_<surgery id>.png
(256 x 144). Needs Pillow + numpy.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SURG = os.path.join(os.path.dirname(HERE), "42", "media", "textures", "HARMONIE_HomeMedic", "surg")
W, H = 256, 144


def load(name):
    return Image.open(os.path.join(SURG, name + ".png")).convert("RGBA")


def cover(img, w=W, h=H, ox=0.5, oy=0.5, zoom=1.0):
    """scale img to cover w x h, then crop around (ox, oy)."""
    s = max(w / img.width, h / img.height) * zoom
    im = img.resize((max(w, int(img.width * s)), max(h, int(img.height * s))), Image.LANCZOS)
    x = int((im.width - w) * ox)
    y = int((im.height - h) * oy)
    return im.crop((x, y, x + w, y + h))


def tint(img, rgb, keep=0.0):
    a = np.asarray(img).astype(np.float32) / 255
    lum = a[..., :3].mean(axis=2, keepdims=True)
    col = np.array(rgb, np.float32)[None, None, :] / 255
    out = a.copy()
    out[..., :3] = lum * col * (1 - keep) + a[..., :3] * keep
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA")


def paste(base, img, cx, cy, size=None, angle=0.0, alpha=1.0):
    if size:
        s = size / max(img.width, img.height)
        img = img.resize((max(1, int(img.width * s)), max(1, int(img.height * s))), Image.LANCZOS)
    if angle:
        img = img.rotate(angle, resample=Image.BICUBIC, expand=True)
    if alpha < 1:
        r, g, b, a = img.split()
        a = a.point(lambda v: int(v * alpha))
        img = Image.merge("RGBA", (r, g, b, a))
    base.alpha_composite(img, (int(cx - img.width / 2), int(cy - img.height / 2)))


def shadow_tool(base, tool, cx, cy, size, angle):
    sh = tool.copy()
    sh = Image.merge("RGBA", (*[Image.new("L", sh.size, 0)] * 3, sh.split()[3].point(lambda v: int(v * 0.55))))
    sh = sh.filter(ImageFilter.GaussianBlur(3))
    paste(base, sh, cx + 6, cy + 7, size, angle)
    paste(base, tool, cx, cy, size, angle)


def finish(img, name):
    vig = cover(load("vignette"))
    img.alpha_composite(vig)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, W - 1, H - 1), outline=(80, 160, 255, 255), width=2)
    img.save(os.path.join(SURG, "card_" + name + ".png"))


def card_debridement():
    img = cover(load("wound_bed"))
    paste(img, load("necro_patch"), 120, 74, 92)
    paste(img, load("necro_patch"), 150, 64, 54, 40)
    shadow_tool(img, load("tool_curette"), 182, 46, 150, 28)
    finish(img, "debridement")


def card_abscess_drainage():
    img = cover(load("field_skin"))
    paste(img, tint(load("raw_patch"), (255, 150, 120), 0.4), 118, 76, 100)
    paste(img, tint(load("blood"), (235, 210, 90)), 118, 78, 44, alpha=0.9)
    paste(img, tint(load("drop"), (235, 210, 110)), 140, 98, 18)
    shadow_tool(img, load("tool_syringe"), 180, 52, 150, 30)
    finish(img, "abscess_drainage")


def card_foreign_body():
    img = cover(load("wound_bed"), ox=0.3)
    paste(img, load("bullet"), 118, 80, 46, 20)
    paste(img, load("glass"), 78, 64, 30, -15, 0.8)
    shadow_tool(img, load("tool_forceps"), 180, 60, 150, 20)
    finish(img, "foreign_body")


def card_parasite_extraction():
    img = cover(load("tissue"))
    paste(img, load("worm"), 112, 80, 110, 12)
    paste(img, load("worm"), 70, 46, 60, -30, 0.7)
    shadow_tool(img, load("tool_forceps"), 186, 62, 140, 25)
    finish(img, "parasite_extraction")


def card_thoracic():
    img = cover(load("organ_bed"))
    # ribs held apart by a retractor: pale curved bars over the open chest
    d = ImageDraw.Draw(img)
    for i, y in enumerate((22, 48, 98, 124)):
        bow = -10 if y < 72 else 10
        pts = [(x, y + bow * math.sin(math.pi * (x - 30) / 196)) for x in range(30, 227, 4)]
        d.line(pts, fill=(120, 100, 80, 220), width=12)
        d.line(pts, fill=(232, 222, 196, 255), width=8)
    shadow_tool(img, load("tool_hemostat"), 176, 72, 140, 30)
    finish(img, "thoracic")


def card_organ_salvage():
    img = cover(load("organ_bed"), ox=0.4)
    organ = cover(load("organ"), 120, 90)
    mask = Image.new("L", organ.size, 0)
    ImageDraw.Draw(mask).ellipse((2, 2, 118, 88), fill=255)
    organ.putalpha(mask.filter(ImageFilter.GaussianBlur(3)))
    organ = ImageEnhance.Brightness(tint(organ, (150, 70, 110), 0.3)).enhance(1.25)
    d = ImageDraw.Draw(img)
    d.ellipse((50, 29, 174, 123), fill=(60, 10, 20, 200))
    paste(img, organ, 112, 76)
    paste(img, load("thread"), 112, 76, 70, 60)
    shadow_tool(img, load("tool_scalpel"), 190, 50, 130, 35)
    shadow_tool(img, load("tool_needle"), 60, 110, 100, -150)
    finish(img, "organ_salvage")


def card_neurosurgery():
    img = cover(load("skull"), oy=0.4)
    d = ImageDraw.Draw(img)
    for r, a in ((13, 255), (9, 255)):
        d.ellipse((118 - r, 70 - r, 118 + r, 70 + r), fill=(40, 10, 10, a) if r == 9 else (90, 40, 30, 255))
    shadow_tool(img, load("tool_drill"), 170, 50, 150, 30)
    finish(img, "neurosurgery")


def card_blood_purification():
    img = cover(load("field_skin"), ox=0.7)
    vein = load("vein")
    paste(img, vein, 128, 84, 260, 8)
    paste(img, load("tool_catheter"), 140, 70, 150, 20)
    for i in range(6):
        paste(img, tint(load("drop"), (200, 20, 20)), 30 + i * 36, 30 + (i % 2) * 8, 18)
    d = ImageDraw.Draw(img)
    d.line((20, 40, 236, 40), fill=(170, 20, 20, 200), width=4)
    finish(img, "blood_purification")


def card_amputation():
    img = cover(load("fat"), zoom=1.2)
    paste(img, load("bone"), 110, 74, 200, 0)
    paste(img, tint(load("splash"), (190, 20, 20)), 120, 76, 70, alpha=0.85)
    shadow_tool(img, load("tool_saw"), 160, 56, 170, 60)
    finish(img, "amputation")


def card_experimental():
    img = cover(load("dish"), zoom=1.1)
    cell = load("cell")
    for i, (x, y) in enumerate(((90, 60), (120, 84), (150, 58), (104, 100), (160, 96))):
        paste(img, cell, x, y, 34 + (i % 3) * 6, i * 40)
    shadow_tool(img, load("tool_pipette"), 190, 42, 130, 35)
    finish(img, "experimental")


def main():
    for fn in (card_debridement, card_abscess_drainage, card_foreign_body, card_parasite_extraction,
               card_thoracic, card_organ_salvage, card_neurosurgery, card_blood_purification,
               card_amputation, card_experimental):
        fn()
    print("wrote 10 surgery cards")


if __name__ == "__main__":
    main()
