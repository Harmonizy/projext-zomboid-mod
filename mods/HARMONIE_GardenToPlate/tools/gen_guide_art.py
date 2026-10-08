#!/usr/bin/env python3
"""HARMONIE - From Garden to Plate: the vitamin guide window's own art.

Writes 42/media/textures/GTP_UI/:
  tab_overview / tab_vitamins / tab_foods / tab_other .png -- the four tab
      icons: the same badge layout as Home Medic's / The Way To Attack's /
      the SVU3 window's tabs (rounded plate, coloured rim), in green;
  tab_check .png -- the Check tab (2026-10-08);
  tab_calendar .png -- the planting calendar tab (2026-10-08);
  tab_cook .png -- the Cooking tab (2026-10-08): a pot with steam;
  cook_<step> .png -- the cooking steps (wash, peel, chop, mince, trim,
      crack, grate, knead, measure, whisk, season, stir);
  icon_settings .png -- the gear (settings page, 2026-10-08);
  pin_on / pin_off .png -- the pin button;
  icon_close / icon_plus / icon_minus .png -- close, text bigger (A+),
      text smaller (A-).
All drawn here with Pillow (4x supersampled), nothing copied.
"""
import os, math
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "42", "media", "textures", "GTP_UI")
os.makedirs(OUT, exist_ok=True)

WHITE = (240, 255, 240, 255)
SKY = (126, 230, 132, 255)
SKY_D = (60, 160, 80, 255)
PLATE = (8, 34, 14, 240)
RIM = (96, 200, 110, 255)
DARK = (6, 20, 8, 255)
ORANGE = (255, 150, 40, 255)
RED = (230, 70, 60, 255)
YELLOW = (255, 214, 80, 255)
BROWN = (150, 98, 52, 255)
STEEL = (180, 190, 196, 255)


def canvas(size=128):
    big = size * 4
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = big / 128.0
    d.rounded_rectangle([6 * s, 6 * s, 122 * s, 122 * s], radius=22 * s, fill=PLATE, outline=RIM, width=int(4 * s))
    return img, d, s


def done(img, name, size=128):
    img.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def P(s, pts):
    return [(x * s, y * s) for x, y in pts]



def tab_overview():
    """Overview: a heart-rate style line over a leaf."""
    img, d, s = canvas()
    d.ellipse([30 * s, 26 * s, 98 * s, 94 * s], fill=SKY_D)
    d.polygon(P(s, [(64, 22), (100, 60), (64, 104), (28, 60)]), fill=SKY)
    d.line(P(s, [(64, 30), (64, 98)]), fill=PLATE, width=int(4 * s))
    d.line(P(s, [(14, 64), (40, 64), (50, 44), (62, 84), (74, 50), (82, 64), (114, 64)]), fill=WHITE, width=int(6 * s), joint="curve")
    done(img, "tab_overview")


def tab_check():
    """Check: a magnifying glass over a person with a small heart."""
    img, d, s = canvas()
    d.ellipse([28 * s, 22 * s, 56 * s, 50 * s], fill=SKY_D)
    d.rounded_rectangle([20 * s, 52 * s, 64 * s, 100 * s], radius=14 * s, fill=SKY_D)
    d.ellipse([56 * s, 40 * s, 100 * s, 84 * s], outline=WHITE, width=int(7 * s))
    d.ellipse([62 * s, 46 * s, 94 * s, 78 * s], fill=(20, 60, 30, 200))
    d.polygon(P(s, [(78, 72), (66, 60), (70, 54), (78, 59), (86, 54), (90, 60)]), fill=RED)
    d.line(P(s, [(94, 80), (110, 100)]), fill=WHITE, width=int(10 * s))
    done(img, "tab_check")


def tab_calendar():
    """Planting calendar: a calendar page with a sprout."""
    img, d, s = canvas()
    d.rounded_rectangle([20 * s, 26 * s, 108 * s, 104 * s], radius=8 * s, fill=WHITE)
    d.rectangle([20 * s, 26 * s, 108 * s, 46 * s], fill=SKY_D)
    for x in (38, 90):
        d.rounded_rectangle([(x - 4) * s, 18 * s, (x + 4) * s, 34 * s], radius=3 * s, fill=PLATE)
    for r in range(3):
        for c in range(4):
            x, y = 28 + c * 20, 52 + r * 16
            d.rectangle([x * s, y * s, (x + 12) * s, (y + 10) * s], fill=(200, 230, 200, 255))
    d.rectangle([68 * s, 68 * s, 80 * s, 78 * s], fill=SKY)
    d.line(P(s, [(74, 100), (74, 84)]), fill=SKY_D, width=int(4 * s))
    d.ellipse([60 * s, 78 * s, 74 * s, 88 * s], fill=SKY)
    d.ellipse([74 * s, 74 * s, 90 * s, 86 * s], fill=SKY)
    done(img, "tab_calendar")


def tab_vitamins():
    """Vitamins: a capsule with a small leaf."""
    img, d, s = canvas()
    d.rounded_rectangle([26 * s, 48 * s, 102 * s, 80 * s], radius=16 * s, fill=WHITE)
    d.rounded_rectangle([26 * s, 48 * s, 64 * s, 80 * s], radius=16 * s, fill=SKY)
    d.rectangle([48 * s, 48 * s, 64 * s, 80 * s], fill=SKY)
    d.ellipse([70 * s, 18 * s, 100 * s, 42 * s], fill=SKY_D)
    d.line(P(s, [(72, 40), (98, 20)]), fill=WHITE, width=int(3 * s))
    for (x, y, c) in ((34, 92, ORANGE), (56, 98, RED), (78, 92, YELLOW)):
        d.ellipse([x * s, y * s, (x + 14) * s, (y + 14) * s], fill=c)
    done(img, "tab_vitamins")


def tab_foods():
    """Foods: a carrot, an apple and a fish."""
    img, d, s = canvas()
    d.polygon(P(s, [(22, 34), (40, 28), (70, 92), (64, 96)]), fill=ORANGE)
    d.polygon(P(s, [(22, 34), (14, 20), (28, 26)]), fill=SKY)
    d.polygon(P(s, [(26, 30), (30, 14), (36, 28)]), fill=SKY)
    d.ellipse([66 * s, 26 * s, 106 * s, 64 * s], fill=RED)
    d.line(P(s, [(86, 28), (90, 16)]), fill=BROWN, width=int(4 * s))
    d.ellipse([88 * s, 12 * s, 102 * s, 22 * s], fill=SKY)
    d.ellipse([60 * s, 76 * s, 100 * s, 100 * s], fill=STEEL)
    d.polygon(P(s, [(98, 88), (114, 76), (114, 100)]), fill=STEEL)
    d.ellipse([68 * s, 84 * s, 74 * s, 90 * s], fill=DARK)
    done(img, "tab_foods")


def tab_other():
    """Other sources: a jar of home-canned food and a pill bottle."""
    img, d, s = canvas()
    d.rounded_rectangle([20 * s, 40 * s, 62 * s, 104 * s], radius=6 * s, fill=STEEL)
    d.rectangle([20 * s, 58 * s, 62 * s, 86 * s], fill=WHITE)
    d.ellipse([32 * s, 64 * s, 50 * s, 80 * s], fill=ORANGE)
    d.rectangle([18 * s, 32 * s, 64 * s, 42 * s], fill=SKY_D)
    d.rounded_rectangle([72 * s, 44 * s, 108 * s, 104 * s], radius=6 * s, fill=(240, 160, 60, 255))
    d.rectangle([70 * s, 32 * s, 110 * s, 46 * s], fill=WHITE)
    d.rectangle([76 * s, 62 * s, 104 * s, 86 * s], fill=WHITE)
    d.rectangle([88 * s, 66 * s, 92 * s, 82 * s], fill=SKY_D)
    d.rectangle([82 * s, 72 * s, 98 * s, 76 * s], fill=SKY_D)
    done(img, "tab_other")


def pin_icon(pinned, size=64):
    """The pin: upright (pinned) or tipped over (unpinned), blue."""
    big = size * 4
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = big / 64.0
    col = WHITE if pinned else (170, 182, 205, 255)
    head = SKY if pinned else SKY_D
    d.ellipse([16 * s, 2 * s, 48 * s, 34 * s], fill=head, outline=DARK, width=int(2 * s))
    d.rectangle([25 * s, 30 * s, 39 * s, 38 * s], fill=col)
    d.polygon([(12 * s, 38 * s), (52 * s, 38 * s), (47 * s, 46 * s), (17 * s, 46 * s)], fill=col)
    d.polygon([(29 * s, 46 * s), (35 * s, 46 * s), (32 * s, 63 * s)], fill=col)
    if not pinned:
        img = img.rotate(45, resample=Image.BICUBIC, center=(big / 2, big / 2))
    img.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, "pin_on.png" if pinned else "pin_off.png"))


def ui_icon(name, draw, size=64):
    big = size * 4
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw(d, big / 64.0)
    img.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def g_settings(d, s):
    """A gear: 8 teeth round a ring."""
    cx = cy = 32 * s
    for i in range(8):
        a = i * math.pi / 4
        pts = []
        for da, r in ((-0.22, 20), (-0.16, 27), (0.16, 27), (0.22, 20)):
            pts.append((cx + math.cos(a + da) * r * s, cy + math.sin(a + da) * r * s))
        d.polygon(pts, fill=WHITE)
    d.ellipse([cx - 20 * s, cy - 20 * s, cx + 20 * s, cy + 20 * s], fill=WHITE)
    d.ellipse([cx - 8 * s, cy - 8 * s, cx + 8 * s, cy + 8 * s], fill=(0, 0, 0, 0))


def g_close(d, s):
    w = int(7 * s)
    d.line([(16 * s, 16 * s), (48 * s, 48 * s)], fill=WHITE, width=w)
    d.line([(48 * s, 16 * s), (16 * s, 48 * s)], fill=WHITE, width=w)


def letter_a(d, s, big):
    """A capital A, big or small, on the left of the glyph."""
    k = 1.0 if big else 0.72
    x0, y1 = 6, 54
    h, w = 44 * k, 30 * k
    top = (x0 + w / 2, y1 - h)
    t = int(6 * s)
    d.line([(x0 * s, y1 * s), (top[0] * s, top[1] * s)], fill=WHITE, width=t)
    d.line([((x0 + w) * s, y1 * s), (top[0] * s, top[1] * s)], fill=WHITE, width=t)
    yb = y1 - h * 0.38
    d.line([((x0 + w * 0.22) * s, yb * s), ((x0 + w * 0.78) * s, yb * s)], fill=WHITE, width=int(5 * s))


def g_plus(d, s):
    letter_a(d, s, True)
    d.rectangle([40 * s, 21 * s, 60 * s, 27 * s], fill=SKY)
    d.rectangle([47 * s, 14 * s, 53 * s, 34 * s], fill=SKY)


def g_minus(d, s):
    letter_a(d, s, False)
    d.rectangle([40 * s, 21 * s, 60 * s, 27 * s], fill=SKY)



def tab_cook():
    """Cooking: a steaming pot with a ladle."""
    img, d, s = canvas()
    for x in (46, 64, 82):
        d.line(P(s, [(x, 44), (x - 6, 34), (x, 24), (x - 6, 14)]), fill=WHITE, width=int(4 * s), joint="curve")
    d.rounded_rectangle([24 * s, 54 * s, 104 * s, 104 * s], radius=10 * s, fill=STEEL)
    d.rectangle([18 * s, 50 * s, 110 * s, 60 * s], fill=SKY)
    d.rectangle([10 * s, 62 * s, 24 * s, 70 * s], fill=STEEL)
    d.rectangle([104 * s, 62 * s, 118 * s, 70 * s], fill=STEEL)
    d.line(P(s, [(88, 30), (74, 78)]), fill=BROWN, width=int(6 * s))
    done(img, "tab_cook")


def step(name, draw):
    img, d, s = canvas()
    draw(d, s)
    done(img, "cook_" + name, 64)


def knife(d, s, x0=24, y0=86, x1=100, y1=40):
    d.line(P(s, [(x0, y0), (x0 + 22, y0 - 13)]), fill=BROWN, width=int(10 * s))
    d.polygon(P(s, [(x0 + 22, y0 - 19), (x1, y1), (x1 + 4, y1 + 6), (x0 + 24, y0 - 7)]), fill=STEEL)


def g_wash(d, s):
    d.ellipse([34 * s, 40 * s, 94 * s, 100 * s], fill=ORANGE)
    for x, y in ((40, 26), (64, 18), (88, 28)):
        d.polygon(P(s, [(x, y), (x - 6, y + 12), (x + 6, y + 12)]), fill=(110, 170, 255, 255))
        d.ellipse([(x - 6) * s, (y + 8) * s, (x + 6) * s, (y + 20) * s], fill=(110, 170, 255, 255))


def g_peel(d, s):
    d.ellipse([24 * s, 34 * s, 84 * s, 94 * s], fill=(235, 220, 160, 255))
    d.arc([20 * s, 30 * s, 88 * s, 98 * s], 200, 340, fill=BROWN, width=int(8 * s))
    d.line(P(s, [(84, 50), (100, 70), (90, 96), (104, 110)]), fill=BROWN, width=int(6 * s), joint="curve")
    knife(d, s, 60, 110, 112, 70)


def g_chop(d, s):
    d.rectangle([14 * s, 84 * s, 114 * s, 100 * s], fill=BROWN)
    for i, x in enumerate((24, 44, 64)):
        d.rectangle([x * s, 70 * s, (x + 14) * s, 84 * s], fill=ORANGE)
    knife(d, s, 70, 76, 112, 30)


def g_mince(d, s):
    d.rectangle([14 * s, 84 * s, 114 * s, 100 * s], fill=BROWN)
    for x in range(22, 100, 9):
        for y in (72, 78):
            d.rectangle([x * s, y * s, (x + 5) * s, (y + 5) * s], fill=RED)
    d.rectangle([50 * s, 20 * s, 104 * s, 54 * s], fill=STEEL)
    d.rectangle([30 * s, 30 * s, 52 * s, 40 * s], fill=BROWN)


def g_trim(d, s):
    d.ellipse([18 * s, 50 * s, 96 * s, 100 * s], fill=RED)
    d.ellipse([24 * s, 58 * s, 60 * s, 84 * s], fill=WHITE)
    knife(d, s, 56, 104, 116, 54)


def g_crack(d, s):
    d.ellipse([36 * s, 22 * s, 92 * s, 92 * s], fill=WHITE)
    d.line(P(s, [(40, 58), (52, 50), (60, 62), (70, 48), (80, 60), (90, 54)]), fill=DARK, width=int(4 * s))
    d.ellipse([46 * s, 94 * s, 82 * s, 114 * s], fill=YELLOW)


def g_grate(d, s):
    d.polygon(P(s, [(40, 18), (88, 18), (100, 108), (28, 108)]), fill=STEEL)
    for y in range(32, 100, 12):
        for x in range(46, 84, 12):
            d.rectangle([x * s, y * s, (x + 6) * s, (y + 3) * s], fill=DARK)
    d.rectangle([56 * s, 6 * s, 72 * s, 18 * s], fill=BROWN)


def g_knead(d, s):
    d.ellipse([20 * s, 58 * s, 108 * s, 108 * s], fill=(240, 220, 170, 255))
    d.rounded_rectangle([14 * s, 34 * s, 114 * s, 50 * s], radius=6 * s, fill=BROWN)


def g_measure(d, s):
    d.polygon(P(s, [(30, 30), (98, 30), (90, 108), (38, 108)]), fill=(200, 230, 255, 150), outline=WHITE)
    d.polygon(P(s, [(34, 64), (94, 64), (90, 108), (38, 108)]), fill=(250, 240, 220, 255))
    for y in (46, 64, 82):
        d.line(P(s, [(34, y), (50, y)]), fill=SKY, width=int(3 * s))


def g_whisk(d, s):
    d.rectangle([58 * s, 70 * s, 70 * s, 116 * s], fill=BROWN)
    for w in (10, 20, 30):
        d.ellipse([(64 - w) * s, 12 * s, (64 + w) * s, 78 * s], outline=STEEL, width=int(4 * s))


def g_season(d, s):
    d.rounded_rectangle([40 * s, 16 * s, 88 * s, 76 * s], radius=10 * s, fill=WHITE)
    d.rectangle([40 * s, 16 * s, 88 * s, 30 * s], fill=STEEL)
    for x, y in ((50, 88), (64, 96), (78, 86), (58, 106), (72, 112)):
        d.ellipse([(x - 3) * s, (y - 3) * s, (x + 3) * s, (y + 3) * s], fill=WHITE)


def g_stir(d, s):
    d.ellipse([16 * s, 50 * s, 112 * s, 110 * s], fill=STEEL)
    d.ellipse([24 * s, 56 * s, 104 * s, 98 * s], fill=ORANGE)
    d.arc([36 * s, 62 * s, 92 * s, 92 * s], 30, 300, fill=WHITE, width=int(4 * s))
    d.line(P(s, [(96, 10), (66, 80)]), fill=BROWN, width=int(7 * s))

for f in (tab_overview, tab_check, tab_calendar, tab_vitamins, tab_foods, tab_other, tab_cook):
    f()
pin_icon(True)
pin_icon(False)
for n, g in (("icon_settings", g_settings), ("icon_close", g_close), ("icon_plus", g_plus), ("icon_minus", g_minus)):
    ui_icon(n, g)
for n, g in (("wash", g_wash), ("peel", g_peel), ("chop", g_chop), ("mince", g_mince), ("trim", g_trim), ("crack", g_crack),
             ("grate", g_grate), ("knead", g_knead), ("measure", g_measure), ("whisk", g_whisk), ("season", g_season), ("stir", g_stir)):
    step(n, g)
print("ok")
