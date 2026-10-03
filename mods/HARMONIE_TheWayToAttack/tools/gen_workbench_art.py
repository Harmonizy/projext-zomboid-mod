#!/usr/bin/env python3
"""HARMONIE - The Way To Attack: the workbench window's own art (R69).

Writes 42/media/textures/TWA_UI/:
  tab_craft / tab_weapons / tab_materials / tab_modify / tab_guide .png --
      the five tab icons, one badge style (dark amber plate, yellow rim),
      the same layout as Home Medic's tab badges but in yellow;
  guide_*.png -- the pictures of the guide tab (512 x 288), simple drawn
      scenes of the window and the craft steps.
All drawn here with Pillow (4x supersampled), nothing copied.
"""
import os, math
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "42", "media", "textures", "TWA_UI")
os.makedirs(OUT, exist_ok=True)

CREAM = (244, 236, 214, 255)
YEL = (255, 196, 46, 255)
YEL_D = (196, 140, 28, 255)
PLATE = (34, 26, 10, 238)
DARK = (22, 17, 8, 255)
STEEL = (170, 178, 190, 255)
STEEL_D = (100, 108, 120, 255)
WOOD = (150, 98, 52, 255)
RED = (220, 70, 50, 255)
GREEN = (90, 200, 90, 255)
BLUE = (80, 160, 240, 255)


def canvas(size=128):
    big = size * 4
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = big / 128.0
    d.rounded_rectangle([6 * s, 6 * s, 122 * s, 122 * s], radius=22 * s, fill=PLATE,
                        outline=(217, 158, 40, 255), width=int(4 * s))
    return img, d, s


def done(img, name, size=128):
    img.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def P(s, pts):
    return [(x * s, y * s) for x, y in pts]


def tab_craft():
    """Crafting: an anvil with a hammer above it."""
    img, d, s = canvas()
    d.polygon(P(s, [(22, 58), (98, 58), (106, 50), (106, 66), (90, 74), (76, 74), (70, 88), (82, 100),
                    (40, 100), (52, 88), (46, 74), (30, 74)]), fill=STEEL)
    d.polygon(P(s, [(22, 58), (98, 58), (96, 64), (26, 64)]), fill=CREAM)
    d.line(P(s, [(58, 46), (90, 18)]), fill=WOOD, width=int(9 * s))
    d.rounded_rectangle([40 * s, 22 * s, 70 * s, 40 * s], radius=4 * s, fill=YEL)
    for (x, y) in ((40, 48), (30, 44), (82, 46)):
        d.ellipse([x * s, y * s, (x + 5) * s, (y + 5) * s], fill=YEL)
    done(img, "tab_craft")


def tab_weapons():
    """Weapon recipes: a sword and an axe crossed."""
    img, d, s = canvas()
    d.polygon(P(s, [(28, 22), (36, 18), (92, 86), (84, 94)]), fill=STEEL)
    d.line(P(s, [(78, 98), (100, 76)]), fill=YEL, width=int(8 * s))
    d.line(P(s, [(90, 88), (104, 102)]), fill=WOOD, width=int(9 * s))
    d.line(P(s, [(98, 22), (30, 100)]), fill=WOOD, width=int(9 * s))
    d.polygon(P(s, [(84, 22), (106, 14), (112, 40), (96, 46)]), fill=STEEL)
    d.polygon(P(s, [(104, 16), (112, 40), (108, 42), (100, 18)]), fill=CREAM)
    done(img, "tab_weapons")


def tab_materials():
    """Material recipes: two metal bars and a gem."""
    img, d, s = canvas()
    for (x, y, col) in ((20, 70, STEEL), (44, 82, YEL)):
        d.polygon(P(s, [(x, y + 16), (x + 8, y), (x + 52, y), (x + 60, y + 16)]), fill=col)
        d.polygon(P(s, [(x + 8, y), (x + 52, y), (x + 48, y + 6), (x + 12, y + 6)]), fill=CREAM)
    d.polygon(P(s, [(70, 24), (96, 24), (108, 38), (83, 66), (58, 38)]), fill=BLUE)
    d.polygon(P(s, [(70, 24), (96, 24), (90, 38), (76, 38)]), fill=(170, 220, 255, 255))
    done(img, "tab_materials")


def tab_modify():
    """Modify a weapon: a wrench over a blade with a gem."""
    img, d, s = canvas()
    d.polygon(P(s, [(20, 96), (88, 28), (100, 30), (102, 42), (34, 110)]), fill=STEEL)
    d.ellipse([56 * s, 52 * s, 72 * s, 68 * s], fill=RED)
    d.line(P(s, [(40, 34), (96, 92)]), fill=YEL, width=int(11 * s))
    d.ellipse([24 * s, 18 * s, 54 * s, 48 * s], fill=YEL)
    d.ellipse([33 * s, 27 * s, 45 * s, 39 * s], fill=PLATE)
    d.polygon(P(s, [(24, 18), (40, 30), (34, 36)]), fill=PLATE)
    done(img, "tab_modify")


def tab_guide():
    """Guide: an open book with a hammer mark."""
    img, d, s = canvas()
    d.polygon(P(s, [(20, 34), (60, 28), (64, 34), (64, 102), (60, 96), (20, 100)]), fill=CREAM)
    d.polygon(P(s, [(108, 34), (68, 28), (64, 34), (64, 102), (68, 96), (108, 100)]), fill=CREAM)
    d.line(P(s, [(64, 32), (64, 102)]), fill=YEL_D, width=int(3 * s))
    for y in (46, 58, 70, 82):
        d.line(P(s, [(28, y), (54, y - 2)]), fill=(150, 130, 100, 255), width=int(3 * s))
    d.line(P(s, [(78, 82), (98, 52)]), fill=WOOD, width=int(5 * s))
    d.rounded_rectangle([82 * s, 44 * s, 104 * s, 56 * s], radius=2 * s, fill=YEL)
    done(img, "tab_guide")


# --------------------------------------------------------------- guide pictures
GW, GH = 512, 288


def scene():
    big = 2
    img = Image.new("RGBA", (GW * big, GH * big), (26, 20, 10, 255))
    d = ImageDraw.Draw(img)
    return img, d, big


def gdone(img, name):
    img.resize((GW, GH), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def box(d, k, x, y, w, h, fill=(40, 32, 16, 255), outline=YEL_D, width=2, r=8):
    d.rounded_rectangle([x * k, y * k, (x + w) * k, (y + h) * k], radius=r * k, fill=fill,
                        outline=outline, width=int(width * k))


def arrow(d, k, x0, y0, x1, y1, col=YEL, w=6):
    d.line([(x0 * k, y0 * k), (x1 * k, y1 * k)], fill=col, width=int(w * k))
    ang = math.atan2(y1 - y0, x1 - x0)
    for da in (2.6, -2.6):
        d.line([(x1 * k, y1 * k), ((x1 + 16 * math.cos(ang + da)) * k, (y1 + 16 * math.sin(ang + da)) * k)],
               fill=col, width=int(w * k))


def window(d, k, x, y, w, h, active):
    box(d, k, x, y, w, h, fill=(16, 12, 6, 255), outline=YEL, width=3)
    d.rectangle([(x + 3) * k, (y + 3) * k, (x + w - 3) * k, (y + 22) * k], fill=(36, 27, 10, 255))
    tx = x + 10
    tw = min(34, (w - 20) / 5 - 6)
    for i in range(5):
        on = i == active
        box(d, k, tx, y + 28, tw, 26, fill=(70, 50, 12, 255) if on else (30, 24, 12, 255),
            outline=YEL if on else YEL_D, width=2, r=5)
        tx += tw + 6
    return y + 60


def guide_open():
    """Ch.1: right-click an item -> Craft Weapon, or press L."""
    img, d, k = scene()
    box(d, k, 30, 40, 200, 150, fill=(44, 36, 24, 255), outline=STEEL_D)
    for i, label_col in enumerate((CREAM, YEL, CREAM, CREAM)):
        box(d, k, 40, 52 + i * 32, 180, 26, fill=(70, 52, 18, 255) if i == 1 else (54, 44, 30, 255),
            outline=YEL if i == 1 else STEEL_D, width=2, r=4)
        d.rectangle([52 * k, (61 + i * 32) * k, (52 + (110 if i == 1 else 80)) * k, (69 + i * 32) * k], fill=label_col)
    d.polygon([(214 * k, 92 * k), (232 * k, 112 * k), (222 * k, 114 * k), (228 * k, 128 * k), (222 * k, 130 * k),
               (216 * k, 116 * k), (208 * k, 122 * k)], fill=CREAM)
    arrow(d, k, 250, 116, 300, 116)
    window(d, k, 310, 50, 180, 190, 1)
    box(d, k, 400, 210, 70, 50, fill=(54, 44, 30, 255), outline=YEL, width=3, r=6)
    d.rectangle([425 * k, 228 * k, 445 * k, 242 * k], fill=YEL)
    gdone(img, "guide_open")


def guide_recipes():
    """Ch.2: recipe list with filters, a star and the procedure icons."""
    img, d, k = scene()
    top = window(d, k, 20, 20, 472, 250, 1)
    box(d, k, 30, top, 120, 190, fill=(30, 24, 12, 255))
    for i in range(4):
        box(d, k, 38 + (i % 2) * 54, top + 10 + (i // 2) * 30, 48, 22, fill=(150, 90, 20, 255) if i == 0 else (50, 40, 20, 255), width=1, r=4)
    for r in range(4):
        y = top + r * 46
        box(d, k, 160, y, 320, 40, fill=(34, 28, 14, 255), outline=YEL_D, width=1, r=5)
        d.rectangle([168 * k, (y + 6) * k, 196 * k, (y + 34) * k], fill=STEEL)
        d.rectangle([206 * k, (y + 8) * k, 290 * k, (y + 15) * k], fill=CREAM)
        d.rectangle([206 * k, (y + 22) * k, 260 * k, (y + 28) * k], fill=(120, 200, 120, 255) if r < 2 else (220, 100, 90, 255))
        for j in range(3):
            d.rectangle([(350 + j * 26) * k, (y + 9) * k, (370 + j * 26) * k, (y + 29) * k], fill=(80, 70, 50, 255))
        cx, cy = 462, y + 20
        pts = []
        for i in range(10):
            rr = 11 if i % 2 == 0 else 5
            a = -math.pi / 2 + i * math.pi / 5
            pts.append(((cx + rr * math.cos(a)) * k, (cy + rr * math.sin(a)) * k))
        d.polygon(pts, fill=YEL if r == 0 else (90, 90, 90, 255))
    gdone(img, "guide_recipes")


def step(d, k, x, y, w, label_col, icon):
    box(d, k, x, y, w, 70, fill=(40, 32, 16, 255), outline=YEL, width=3)
    icon(d, k, x + w / 2, y + 35)
    d.rectangle([(x + 12) * k, (y + 78) * k, (x + w - 12) * k, (y + 86) * k], fill=label_col)


def ico_box(d, k, cx, cy):
    d.rectangle([(cx - 18) * k, (cy - 14) * k, (cx + 18) * k, (cy + 14) * k], fill=WOOD)
    d.rectangle([(cx - 18) * k, (cy - 14) * k, (cx + 18) * k, (cy - 8) * k], fill=(190, 130, 70, 255))


def ico_hammer(d, k, cx, cy):
    d.line([((cx - 14) * k, (cy + 16) * k), ((cx + 6) * k, (cy - 6) * k)], fill=WOOD, width=int(6 * k))
    d.rectangle([(cx - 2) * k, (cy - 18) * k, (cx + 20) * k, (cy - 6) * k], fill=STEEL)


def ico_check(d, k, cx, cy):
    d.line([((cx - 16) * k, cy * k), ((cx - 4) * k, (cy + 12) * k), ((cx + 18) * k, (cy - 14) * k)],
           fill=GREEN, width=int(8 * k), joint="curve")


def ico_sword(d, k, cx, cy):
    d.polygon([((cx - 20) * k, (cy + 18) * k), ((cx + 16) * k, (cy - 18) * k), ((cx + 20) * k, (cy - 14) * k),
               ((cx - 16) * k, (cy + 22) * k)], fill=STEEL)
    d.line([((cx - 22) * k, (cy + 8) * k), ((cx - 8) * k, (cy + 22) * k)], fill=YEL, width=int(5 * k))


def guide_flow():
    """Ch.3: Start -> procedures -> Finish."""
    img, d, k = scene()
    xs = [24, 146, 268, 390]
    icons = [ico_box, ico_hammer, ico_check, ico_sword]
    for i, x in enumerate(xs):
        step(d, k, x, 90, 98, YEL if i in (0, 3) else CREAM, icons[i])
        if i < 3:
            arrow(d, k, x + 102, 125, x + 120, 125, w=5)
    gdone(img, "guide_flow")


def guide_minigame():
    """Ch.4: the minigame -- hit inside the yellow zone."""
    img, d, k = scene()
    box(d, k, 40, 60, 432, 60, fill=(30, 24, 12, 255), outline=YEL_D, width=2)
    d.rectangle([60 * k, 80 * k, 452 * k, 100 * k], fill=(70, 60, 40, 255))
    d.rectangle([230 * k, 80 * k, 290 * k, 100 * k], fill=YEL)
    d.rectangle([250 * k, 80 * k, 270 * k, 100 * k], fill=GREEN)
    d.polygon([(262 * k, 70 * k), (254 * k, 56 * k), (270 * k, 56 * k)], fill=CREAM)
    labels = [(RED, "Miss"), ((240, 150, 60, 255), "Bad"), (GREEN, "Good"), (YEL, "Excellent")]
    for i, (c, _) in enumerate(labels):
        box(d, k, 50 + i * 106, 170, 96, 60, fill=(40, 32, 16, 255), outline=c, width=3)
        for j in range(i + 1):
            d.ellipse([(64 + i * 106 + j * 18) * k, 192 * k, (78 + i * 106 + j * 18) * k, 206 * k], fill=c)
    gdone(img, "guide_minigame")


def guide_quality():
    """Ch.5: overall quality -> grade."""
    img, d, k = scene()
    cols = [(220, 100, 90, 255), GREEN, YEL]
    for i, c in enumerate(cols):
        box(d, k, 30, 40 + i * 76, 150, 60, fill=(40, 32, 16, 255), outline=c, width=3)
        arrow(d, k, 190, 70 + i * 76, 240, 70 + i * 76, col=c, w=4)
        for j in range(3):
            box(d, k, 256 + j * 78, 44 + i * 76, 64, 52, fill=(54, 44, 26, 255), outline=c, width=2, r=6)
            d.rectangle([(272 + j * 78) * k, (62 + i * 76) * k, (304 + j * 78) * k, (78 + i * 76) * k], fill=CREAM if j == 0 else (150, 140, 120, 255))
    gdone(img, "guide_quality")


def guide_pause():
    """Ch.6: Incomplete -> the unfinished weapon -> Continue; Cancel gives back."""
    img, d, k = scene()
    box(d, k, 30, 60, 120, 90, fill=(40, 32, 16, 255), outline=(140, 150, 245, 255), width=3)
    ico_sword(d, k, 90, 105)
    arrow(d, k, 160, 105, 220, 105)
    box(d, k, 230, 60, 120, 90, fill=(40, 32, 16, 255), outline=STEEL_D, width=3)
    ico_sword(d, k, 290, 105)
    d.rectangle([250 * k, 130 * k, 330 * k, 138 * k], fill=(120, 110, 90, 255))
    d.rectangle([250 * k, 130 * k, 290 * k, 138 * k], fill=YEL)
    arrow(d, k, 360, 105, 420, 105)
    box(d, k, 430, 70, 60, 70, fill=(70, 52, 18, 255), outline=YEL, width=3)
    d.ellipse([452 * k, 96 * k, 468 * k, 112 * k], fill=YEL)
    box(d, k, 30, 190, 460, 60, fill=(36, 20, 16, 255), outline=RED, width=2)
    ico_box(d, k, 120, 220)
    arrow(d, k, 170, 220, 330, 220, col=RED, w=4)
    ico_box(d, k, 380, 220)
    gdone(img, "guide_pause")


def guide_practice():
    """Ch.7: practise a procedure."""
    img, d, k = scene()
    top = window(d, k, 20, 20, 472, 250, 1)
    for i in range(12):
        x = 34 + (i % 4) * 52
        y = top + 10 + (i // 4) * 52
        box(d, k, x, y, 44, 44, fill=(60, 48, 20, 255) if i == 5 else (36, 30, 16, 255),
            outline=YEL if i == 5 else YEL_D, width=2, r=5)
    box(d, k, 260, top, 220, 190, fill=(30, 24, 12, 255))
    d.rectangle([276 * k, (top + 14) * k, 400 * k, (top + 24) * k], fill=CREAM)
    for j in range(4):
        d.rectangle([276 * k, (top + 40 + j * 18) * k, (380 - j * 20) * k, (top + 46 + j * 18) * k], fill=(150, 140, 120, 255))
    box(d, k, 276, top + 140, 188, 34, fill=(60, 110, 60, 255), outline=GREEN, width=2, r=6)
    d.ellipse([284 * k, (top + 150) * k, 298 * k, (top + 164) * k], fill=YEL)
    gdone(img, "guide_practice")


def guide_modify():
    """Ch.8: parts and gem sockets."""
    img, d, k = scene()
    d.polygon([(60 * k, 200 * k), (360 * k, 80 * k), (380 * k, 92 * k), (80 * k, 214 * k)], fill=STEEL)
    d.line([(40 * k, 190 * k), (100 * k, 230 * k)], fill=YEL, width=int(10 * k))
    for (x, y, c) in ((160, 160, RED), (230, 132, BLUE), (300, 104, GREEN)):
        d.ellipse([(x - 14) * k, (y - 14) * k, (x + 14) * k, (y + 14) * k], fill=c, outline=CREAM, width=int(3 * k))
    for i in range(4):
        box(d, k, 400, 40 + i * 54, 90, 44, fill=(40, 32, 16, 255), outline=YEL_D, width=2, r=6)
        d.rectangle([414 * k, (56 + i * 54) * k, 476 * k, (66 + i * 54) * k], fill=CREAM)
    gdone(img, "guide_modify")


def guide_settings():
    """Ch.9: options -- size, text, volume."""
    img, d, k = scene()
    for i in range(3):
        y = 60 + i * 64
        box(d, k, 40, y, 432, 48, fill=(36, 30, 16, 255), outline=YEL_D, width=2)
        d.rectangle([60 * k, (y + 18) * k, 180 * k, (y + 28) * k], fill=CREAM)
        d.rectangle([220 * k, (y + 20) * k, 440 * k, (y + 26) * k], fill=(90, 80, 60, 255))
        d.rectangle([220 * k, (y + 20) * k, (260 + i * 70) * k, (y + 26) * k], fill=YEL)
        d.ellipse([(252 + i * 70) * k, (y + 14) * k, (268 + i * 70) * k, (y + 30) * k], fill=CREAM)
    gdone(img, "guide_settings")


for f in (tab_craft, tab_weapons, tab_materials, tab_modify, tab_guide, guide_open, guide_recipes, guide_flow,
          guide_minigame, guide_quality, guide_pause, guide_practice, guide_modify, guide_settings):
    f()
print("ok")
