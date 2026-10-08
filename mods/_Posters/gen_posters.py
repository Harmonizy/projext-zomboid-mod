#!/usr/bin/env python3
"""HARMONIE posters: one family look, a different emblem and colour per mod.
Drawn here with Pillow (4x supersampled) -- no copied or generated art.
Writes, for every mod:
  mods/<Mod>/42/poster.png           512x512 (the in-game mod list picture)
  Workshop/<Mod>/preview.png          512x512 (the Steam Workshop picture)
Not a mod itself (no mod.info). Run: python3 mods/_Posters/gen_posters.py
then sync each mod (mods/sync_to_workshop.sh <Mod> 42).
Fonts are only used to draw the letters (DejaVu Sans Bold, Loma Bold for
Thai); no font file is shipped.
"""
import os, math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SIZE, K = 512, 4
BIG = SIZE * K
LATIN = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
THAI = "/usr/share/fonts/opentype/tlwg/Loma-Bold.otf"


def font(path, px): return ImageFont.truetype(path, int(px * K))
def S(*v): return [x * K for x in v]
def mix(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def background(c1, c2, seed):
    """a diagonal two-colour gradient with soft rings, the same for all mods"""
    img = Image.new("RGBA", (BIG, BIG))
    px = img.load()
    g = Image.new("RGBA", (256, 256))
    gp = g.load()
    for y in range(256):
        for x in range(256):
            t = (x + y) / 510
            gp[x, y] = mix(c1, c2, t) + (255,)
    img = g.resize((BIG, BIG), Image.BICUBIC)
    lay = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    rnd = random.Random(seed)
    for _ in range(9):
        cx, cy, r = rnd.uniform(0, SIZE), rnd.uniform(0, SIZE), rnd.uniform(60, 220)
        d.ellipse(S(cx - r, cy - r, cx + r, cy + r), outline=(255, 255, 255, 22), width=int(6 * K))
    img = Image.alpha_composite(img, lay)
    # vignette
    v = Image.new("L", (BIG, BIG), 0)
    vd = ImageDraw.Draw(v)
    for i in range(40):
        a = int(150 * (1 - i / 40))
        vd.rectangle(S(i * 3, i * 3, SIZE - i * 3, SIZE - i * 3), outline=a, width=int(3 * K))
    dark = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 255))
    dark.putalpha(v.filter(ImageFilter.GaussianBlur(30)))
    return Image.alpha_composite(img, dark)


def emblem_disc(img, cx, cy, r, ring, fill):
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    d.ellipse(S(cx - r + 6, cy - r + 10, cx + r + 6, cy + r + 10), fill=(0, 0, 0, 110))
    lay = lay.filter(ImageFilter.GaussianBlur(10 * K))
    img.alpha_composite(lay)
    d = ImageDraw.Draw(img)
    d.ellipse(S(cx - r, cy - r, cx + r, cy + r), fill=ring)
    d.ellipse(S(cx - r + 10, cy - r + 10, cx + r - 10, cy + r - 10), fill=fill)
    d.arc(S(cx - r + 16, cy - r + 16, cx + r - 16, cy + r - 16), 200, 300, fill=(255, 255, 255, 70), width=int(5 * K))


def text_center(d, s, y, f, fill, shadow=(0, 0, 0, 170), spacing=0):
    w = d.textlength(s, font=f)
    x = (BIG - w) / 2
    d.text((x + 3 * K, y + 3 * K), s, font=f, fill=shadow)
    d.text((x, y), s, font=f, fill=fill)


def fit_font(d, s, path, px, maxw):
    while px > 14:
        f = font(path, px)
        if d.textlength(s, font=f) <= maxw * K: return f
        px -= 1
    return font(path, px)


def poster(mod, c1, c2, accent, draw_emblem, title_lines, sub=None, thai=None):
    img = background(c1, c2, mod)
    d = ImageDraw.Draw(img)
    # the HARMONIE wordmark band
    d.rounded_rectangle(S(36, 26, SIZE - 36, 92), radius=18 * K, fill=(0, 0, 0, 120), outline=accent + (255,), width=int(3 * K))
    fw = font(LATIN, 46)
    text_center(d, "HARMONIE", 31 * K, fw, (255, 255, 255, 255))
    for i in range(3):  # small accent dots either side
        for side in (-1, 1):
            x = SIZE / 2 + side * (150 + i * 14)
            d.ellipse(S(x - 3, 59 - 3, x + 3, 59 + 3), fill=accent + (255,))
    # the emblem
    # three lines of name (two + Thai) need the emblem a little higher
    crowded = len(title_lines) + (1 if thai else 0) >= 3
    ey = 214 if crowded else 228
    emblem_disc(img, SIZE / 2, ey, 104 if crowded else 112, accent + (255,), mix(c2, (0, 0, 0), 0.45) + (255,))
    d = ImageDraw.Draw(img)
    draw_emblem(d, SIZE / 2, ey)
    # the mod's name
    y = 334 if crowded else 362
    for line in title_lines:
        f = fit_font(d, line, LATIN, 44, SIZE - 60)
        text_center(d, line, y * K, f, (255, 255, 255, 255))
        y += 46 if crowded else 50
    if thai:
        f = fit_font(d, thai, THAI, 40, SIZE - 80)
        text_center(d, thai, y * K - 4 * K, f, accent + (255,))
        y += 46
    if sub:
        f = fit_font(d, sub, LATIN, 20, SIZE - 80)
        text_center(d, sub, (y + 2) * K, f, (235, 235, 235, 220))
    d.rounded_rectangle(S(8, 8, SIZE - 8, SIZE - 8), radius=26 * K, outline=accent + (200,), width=int(4 * K))
    out = img.resize((SIZE, SIZE), Image.LANCZOS)
    return out


# ------------------------------------------------------------------ emblems
W = (255, 255, 255, 255)


def e_garden(d, cx, cy):
    # a plate with a carrot and a sprout
    d.ellipse(S(cx - 74, cy + 6, cx + 74, cy + 70), fill=(236, 236, 228, 255))
    d.ellipse(S(cx - 54, cy + 18, cx + 54, cy + 58), fill=(210, 214, 204, 255))
    d.polygon(S(cx - 46, cy + 30, cx + 30, cy - 46, cx + 42, cy - 34, cx - 30, cy + 42), fill=(245, 135, 40, 255))
    for i in range(3):
        d.line(S(cx - 20 + i * 18, cy + 12 - i * 18, cx - 10 + i * 18, cy + 20 - i * 18), fill=(200, 100, 20, 255), width=int(3 * K))
    for a in (-40, 0, 40):
        x2 = cx + 40 + math.sin(math.radians(a)) * 40
        y2 = cy - 40 - math.cos(math.radians(a)) * 40
        d.line(S(cx + 36, cy - 40, x2, y2), fill=(80, 190, 70, 255), width=int(9 * K))
    d.ellipse(S(cx + 20, cy - 92, cx + 46, cy - 66), fill=(120, 220, 90, 255))


def e_medic(d, cx, cy):
    d.polygon(S(cx - 70, cy - 4, cx, cy - 72, cx + 70, cy - 4), fill=(250, 250, 250, 255))
    d.rectangle(S(cx - 56, cy - 6, cx + 56, cy + 62), fill=(250, 250, 250, 255))
    d.rectangle(S(cx - 13, cy - 2, cx + 13, cy + 54), fill=(220, 40, 50, 255))
    d.rectangle(S(cx - 33, cy + 13, cx + 33, cy + 39), fill=(220, 40, 50, 255))
    pts = [(-92, 78), (-40, 78), (-28, 60), (-12, 96), (6, 70), (40, 78), (92, 78)]
    d.line([((cx + x) * K, (cy + y) * K) for x, y in pts], fill=(255, 210, 210, 255), width=int(5 * K), joint="curve")


def e_audio(d, cx, cy):
    d.rectangle(S(cx - 70, cy - 22, cx - 42, cy + 22), fill=W)
    d.polygon(S(cx - 42, cy - 22, cx - 10, cy - 52, cx - 10, cy + 52, cx - 42, cy + 22), fill=W)
    for r in (26, 46, 66):
        d.arc(S(cx - 10 - r, cy - r, cx - 10 + r, cy + r), -50, 50, fill=(200, 170, 255, 255), width=int(7 * K))
    for i, h in enumerate((30, 54, 40, 66)):  # equalizer
        x = cx + 46 + i * 0 
    for i, h in enumerate((24, 44, 32, 56, 38)):
        x = cx - 60 + i * 26
        d.rounded_rectangle(S(x, cy + 70 - h * 0.5, x + 16, cy + 74), radius=4 * K, fill=(255, 190, 80, 255))


def e_firearm(d, cx, cy):
    d.ellipse(S(cx - 66, cy - 66, cx + 66, cy + 66), outline=W, width=int(8 * K))
    d.ellipse(S(cx - 30, cy - 30, cx + 30, cy + 30), outline=W, width=int(5 * K))
    for x1, y1, x2, y2 in ((cx - 86, cy, cx - 40, cy), (cx + 40, cy, cx + 86, cy), (cx, cy - 86, cx, cy - 40), (cx, cy + 40, cx, cy + 86)):
        d.line(S(x1, y1, x2, y2), fill=W, width=int(7 * K))
    # a wrench across
    d.line(S(cx - 30, cy + 70, cx + 54, cy - 14), fill=(255, 170, 60, 255), width=int(14 * K))
    d.ellipse(S(cx + 38, cy - 44, cx + 82, cy), fill=(255, 170, 60, 255))
    d.polygon(S(cx + 56, cy - 40, cx + 74, cy - 52, cx + 82, cy - 32, cx + 64, cy - 22), fill=(60, 30, 14, 255))


def e_perf(d, cx, cy):
    d.arc(S(cx - 80, cy - 70, cx + 80, cy + 90), 180, 360, fill=W, width=int(12 * K))
    for i in range(9):
        a = math.radians(180 + i * 22.5)
        r1, r2 = 62, 74
        d.line(S(cx + math.cos(a) * r1, cy + 10 + math.sin(a) * r1, cx + math.cos(a) * r2, cy + 10 + math.sin(a) * r2), fill=W, width=int(4 * K))
    a = math.radians(-35)
    d.line(S(cx, cy + 10, cx + math.cos(a) * 64, cy + 10 + math.sin(a) * 64), fill=(255, 90, 80, 255), width=int(8 * K))
    d.ellipse(S(cx - 12, cy - 2, cx + 12, cy + 22), fill=W)
    pts = [(-70, 70), (-46, 50), (-26, 62), (-2, 34), (22, 56), (46, 40), (70, 52)]
    d.line([((cx + x) * K, (cy + y) * K) for x, y in pts], fill=(120, 255, 210, 255), width=int(5 * K), joint="curve")


def e_svu(d, cx, cy):
    # an armoured truck front with a gear
    d.rounded_rectangle(S(cx - 78, cy - 50, cx + 78, cy + 40), radius=12 * K, fill=(150, 160, 170, 255))
    d.rectangle(S(cx - 62, cy - 40, cx + 62, cy - 6), fill=(70, 90, 110, 255))
    for i in range(6):
        x = cx - 56 + i * 21
        d.rectangle(S(x, cy + 2, x + 12, cy + 30), fill=(60, 64, 70, 255))
    for x in (cx - 66, cx + 50):
        d.ellipse(S(x, cy - 2, x + 16, cy + 14), fill=(255, 220, 120, 255))
    d.rectangle(S(cx - 90, cy + 36, cx + 90, cy + 50), fill=(90, 96, 104, 255))
    gx, gy = cx + 56, cy + 56
    for i in range(8):
        a = i * math.pi / 4
        d.line(S(gx + math.cos(a) * 18, gy + math.sin(a) * 18, gx + math.cos(a) * 32, gy + math.sin(a) * 32), fill=(255, 190, 70, 255), width=int(9 * K))
    d.ellipse(S(gx - 24, gy - 24, gx + 24, gy + 24), fill=(255, 190, 70, 255))
    d.ellipse(S(gx - 9, gy - 9, gx + 9, gy + 9), fill=(40, 44, 52, 255))


def e_attack(d, cx, cy):
    # crossed sword and hammer over an anvil
    d.polygon(S(cx - 70, cy + 40, cx + 70, cy + 40, cx + 50, cy + 60, cx + 30, cy + 60, cx + 30, cy + 80, cx - 30, cy + 80, cx - 30, cy + 60, cx - 50, cy + 60), fill=(70, 70, 76, 255))
    d.polygon(S(cx - 80, cy + 26, cx + 60, cy + 26, cx + 86, cy + 40, cx - 80, cy + 40), fill=(110, 110, 118, 255))
    # sword
    d.polygon(S(cx - 56, cy + 12, cx + 44, cy - 88, cx + 54, cy - 78, cx - 46, cy + 22), fill=(230, 232, 240, 255))
    d.line(S(cx - 64, cy - 2, cx - 34, cy + 28), fill=(220, 180, 70, 255), width=int(9 * K))
    d.line(S(cx - 50, cy + 14, cx - 70, cy + 34), fill=(120, 70, 30, 255), width=int(9 * K))
    # hammer
    d.line(S(cx + 56, cy + 18, cx - 20, cy - 58), fill=(140, 90, 40, 255), width=int(9 * K))
    d.polygon(S(cx - 46, cy - 52, cx - 12, cy - 86, cx + 4, cy - 70, cx - 30, cy - 36), fill=(200, 200, 208, 255))
    for i in range(5):  # sparks
        a = math.radians(-150 + i * 30)
        d.line(S(cx + math.cos(a) * 92, cy + 30 + math.sin(a) * 30, cx + math.cos(a) * 104, cy + 30 + math.sin(a) * 36), fill=(255, 200, 60, 255), width=int(3 * K))


def e_thai(d, cx, cy):
    fT = font(THAI, 54)
    fL = font(LATIN, 44)
    d.rounded_rectangle(S(cx - 90, cy - 70, cx - 4, cy + 4), radius=16 * K, fill=W)
    d.polygon(S(cx - 70, cy + 2, cx - 52, cy + 2, cx - 74, cy + 22), fill=W)
    d.text(((cx - 47) * K, (cy - 33) * K), "ก", font=fT, fill=(40, 60, 150, 255), anchor="mm")
    d.rounded_rectangle(S(cx + 4, cy - 10, cx + 90, cy + 64), radius=16 * K, fill=(235, 60, 70, 255))
    d.polygon(S(cx + 52, cy + 62, cx + 70, cy + 62, cx + 74, cy + 82), fill=(235, 60, 70, 255))
    d.text(((cx + 47) * K, (cy + 27) * K), "A", font=fL, fill=W, anchor="mm")
    d.line(S(cx - 30, cy + 40, cx - 10, cy + 60), fill=W, width=int(5 * K))
    d.polygon(S(cx - 16, cy + 62, cx - 4, cy + 50, cx - 2, cy + 66), fill=W)
    d.line(S(cx + 30, cy - 36, cx + 10, cy - 56), fill=W, width=int(5 * K))
    d.polygon(S(cx + 16, cy - 58, cx + 4, cy - 46, cx + 2, cy - 62), fill=W)


MODS = [
    ("HARMONIE_GardenToPlate", (24, 84, 40), (10, 40, 18), (140, 230, 110), e_garden, ["From Garden", "to Plate"], "vitamins - farming - cooking", None),
    ("HARMONIE_HomeMedic", (130, 22, 34), (52, 8, 16), (255, 120, 120), e_medic, ["Home Medic"], "diagnosis - surgery - recovery", None),
    ("HARMONIE_LifestyleAudioTune", (70, 34, 140), (26, 12, 60), (200, 160, 255), e_audio, ["Lifestyle", "Audio Tune"], None, None),
    ("HARMONIE_ModernFirearmsSystemFix", (150, 70, 20), (50, 22, 8), (255, 170, 70), e_firearm, ["Modern Firearms", "System Fix"], None, None),
    ("HARMONIE_PerfProbe", (12, 110, 110), (4, 40, 46), (110, 240, 210), e_perf, ["Perf Probe"], "diagnostic", None),
    ("HARMONIE_SVU3Sandbox", (52, 70, 96), (16, 22, 34), (255, 196, 80), e_svu, ["SVU3 Sandbox"], "vehicle upgrades", None),
    ("HARMONIE_TheWayToAttack", (90, 72, 30), (24, 18, 8), (240, 200, 90), e_attack, ["The Way", "To Attack"], "forging - weapons - gems", None),
    ("HARMONIE_TooManyModThaiTranslate", (30, 46, 120), (10, 14, 44), (255, 110, 120), e_thai, ["Too Many Mod", "Thai Translate"], None, "แปลไทย"),
]

if __name__ == "__main__":
    for mod, c1, c2, acc, em, title, sub, thai in MODS:
        img = poster(mod, c1, c2, acc, em, title, sub, thai)
        img.save(os.path.join(ROOT, "mods", mod, "42", "poster.png"), optimize=True)
        img.save(os.path.join(ROOT, "Workshop", mod, "preview.png"), optimize=True)
        print("poster", mod)
