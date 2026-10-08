#!/usr/bin/env python3
"""HARMONIE - From Garden to Plate: item icons of the winter foods
(HARMONIE_GardenToPlate_Extras.txt). Writes 42/media/textures/Item_HARMONIE_*.png,
32x32 like vanilla item icons. Drawn here with Pillow (8x supersampled)."""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "42", "media", "textures")
os.makedirs(OUT, exist_ok=True)
K = 8
OUTL = (40, 26, 14, 255)


def canvas():
    img = Image.new("RGBA", (32 * K, 32 * K), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def save(img, name):
    img.resize((32, 32), Image.LANCZOS).save(os.path.join(OUT, "Item_HARMONIE_" + name + ".png"))


def B(*v):
    return [x * K for x in v]


def ring(d, cx, cy, r, flesh, skin, hole=True):
    d.ellipse(B(cx - r, cy - r, cx + r, cy + r), fill=skin, outline=OUTL, width=K)
    d.ellipse(B(cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2), fill=flesh)
    if hole:
        d.ellipse(B(cx - r / 3, cy - r / 3, cx + r / 3, cy + r / 3), fill=(0, 0, 0, 0), outline=OUTL, width=K // 2)


def slices(d, col, edge, n=3):
    for i in range(n):
        x, y = 5 + i * 7, 10 + (i % 2) * 6
        d.ellipse(B(x, y, x + 14, y + 12), fill=col, outline=OUTL, width=K)
        d.arc(B(x + 2, y + 2, x + 12, y + 10), 200, 340, fill=edge, width=K)


def dried_apple():
    img, d = canvas()
    ring(d, 12, 18, 9, (230, 200, 140, 255), (170, 40, 30, 255))
    ring(d, 21, 12, 8, (236, 208, 150, 255), (180, 50, 35, 255))
    save(img, "DriedApple")


def dried_pear():
    img, d = canvas()
    slices(d, (214, 196, 120, 255), (150, 160, 60, 255))
    save(img, "DriedPear")


def dried_peach():
    img, d = canvas()
    slices(d, (240, 150, 70, 255), (200, 80, 50, 255))
    save(img, "DriedPeach")


def dried_mango():
    img, d = canvas()
    for i in range(3):
        x = 5 + i * 8
        d.rounded_rectangle(B(x, 6 + i * 2, x + 8, 26 - i), radius=3 * K, fill=(250, 170, 40, 255), outline=OUTL, width=K)
    save(img, "DriedMango")


def banana_chips():
    img, d = canvas()
    for (x, y) in ((4, 14), (12, 8), (18, 16), (10, 20)):
        ring(d, x + 5, y + 5, 5, (246, 226, 160, 255), (200, 170, 80, 255), hole=False)
        d.point([((x + 5) * K, (y + 5) * K)], fill=OUTL)
    save(img, "DriedBanana")


def dried_cherry():
    img, d = canvas()
    for (x, y) in ((6, 14), (14, 10), (18, 18), (9, 21)):
        d.ellipse(B(x, y, x + 8, y + 8), fill=(120, 20, 30, 255), outline=OUTL, width=K)
        d.ellipse(B(x + 2, y + 2, x + 4, y + 4), fill=(200, 80, 90, 255))
    save(img, "DriedCherry")


def raisins():
    img, d = canvas()
    for (x, y) in ((5, 16), (11, 11), (17, 15), (12, 20), (20, 21), (8, 23)):
        d.ellipse(B(x, y, x + 7, y + 6), fill=(70, 34, 50, 255), outline=OUTL, width=K)
        d.line(B(x + 2, y + 3, x + 5, y + 3), fill=(110, 60, 80, 255), width=K)
    save(img, "DriedGrapes")


def dried_pineapple():
    img, d = canvas()
    ring(d, 16, 16, 11, (250, 214, 80, 255), (190, 140, 40, 255))
    for a in range(0, 360, 45):
        import math
        x, y = 16 + math.cos(math.radians(a)) * 7, 16 + math.sin(math.radians(a)) * 7
        d.line(B(16 + math.cos(math.radians(a)) * 4, 16 + math.sin(math.radians(a)) * 4, x, y), fill=(220, 170, 50, 255), width=K)
    save(img, "DriedPineapple")


def bean_sprouts():
    img, d = canvas()
    import math
    for i in range(6):
        x = 6 + i * 4
        d.arc(B(x - 4, 6, x + 4, 30), 270 - 40, 270 + 40, fill=(240, 240, 220, 255), width=2 * K)
        d.ellipse(B(x - 3, 4 + (i % 3) * 2, x + 3, 9 + (i % 3) * 2), fill=(240, 220, 90, 255), outline=OUTL, width=K // 2)
        d.ellipse(B(x - 2, 3 + (i % 3) * 2, x + 2, 6 + (i % 3) * 2), fill=(120, 200, 80, 255))
    save(img, "BeanSprouts")


def fish_oil():
    img, d = canvas()
    d.rounded_rectangle(B(9, 8, 23, 29), radius=3 * K, fill=(220, 160, 40, 220), outline=OUTL, width=K)
    d.rectangle(B(10, 15, 22, 28), fill=(240, 190, 50, 255))
    d.rectangle(B(11, 4, 21, 9), fill=(150, 150, 160, 255), outline=OUTL, width=K)
    d.polygon(B(12, 20, 18, 17, 18, 23), fill=(70, 110, 160, 255))
    d.polygon(B(18, 20, 21, 18, 21, 22), fill=(70, 110, 160, 255))
    save(img, "FishLiverOil")


for f in (dried_apple, dried_pear, dried_peach, dried_mango, banana_chips, dried_cherry, raisins,
          dried_pineapple, bean_sprouts, fish_oil):
    f()
print("ok")
