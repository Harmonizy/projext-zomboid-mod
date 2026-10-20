#!/usr/bin/env python3
"""HARMONIE - Life With Style: the window's icons, the make-up item icon, mod icon / poster
(our own art, drawn here). Dark strokes + champagne gold for the white window."""
import math, os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.join(os.path.dirname(HERE), "42")
UI = os.path.join(MOD, "media", "textures", "HARMONIE_LWS")
INK = (46, 40, 38, 255)
GOLD = (189, 136, 82, 255)
ROSE = (214, 142, 140, 255)
WHITE = (255, 255, 255, 255)


def canvas(size=128):
    big = size * 4
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img), big / 128.0


def done(img, size, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path)
    print("wrote", os.path.relpath(path, MOD))


def P(s, pts):
    return [(x * s, y * s) for x, y in pts]


def hanger(d, s, col=INK, w=8):
    d.arc([54 * s, 16 * s, 74 * s, 36 * s], 180, 90, fill=col, width=int(w * s))
    d.line(P(s, [(64, 36), (64, 44)]), fill=col, width=int(w * s))
    d.line(P(s, [(64, 44), (16, 86), (112, 86), (64, 44)]), fill=col, width=int(w * s), joint="curve")


def tab_dress(path):
    img, d, s = canvas()
    hanger(d, s)
    d.polygon(P(s, [(34, 90), (94, 90), (102, 118), (26, 118)]), fill=GOLD)
    done(img, 128, path)


def tab_collection(path):
    img, d, s = canvas()
    d.rounded_rectangle([18 * s, 14 * s, 110 * s, 114 * s], radius=8 * s, outline=INK, width=int(7 * s))
    d.line(P(s, [(64, 14), (64, 114)]), fill=INK, width=int(6 * s))
    d.ellipse([52 * s, 58 * s, 60 * s, 66 * s], fill=GOLD)
    d.ellipse([68 * s, 58 * s, 76 * s, 66 * s], fill=GOLD)
    d.line(P(s, [(26, 30), (56, 30)]), fill=GOLD, width=int(5 * s))
    done(img, 128, path)


def tab_admin(path):
    img, d, s = canvas()
    d.polygon(P(s, [(18, 96), (24, 40), (46, 66), (64, 30), (82, 66), (104, 40), (110, 96)]), fill=GOLD, outline=INK)
    d.rectangle([18 * s, 96 * s, 110 * s, 110 * s], fill=INK)
    for x in (24, 64, 104):
        d.ellipse([(x - 6) * s, 26 * s, (x + 6) * s, 38 * s], fill=INK)
    done(img, 128, path)


def tab_guide(path):
    img, d, s = canvas()
    d.polygon(P(s, [(14, 28), (60, 22), (64, 28), (64, 108), (60, 102), (14, 106)]), outline=INK, width=int(6 * s))
    d.polygon(P(s, [(114, 28), (68, 22), (64, 28), (64, 108), (68, 102), (114, 106)]), outline=INK, width=int(6 * s))
    for y in (44, 58, 72, 86):
        d.line(P(s, [(24, y), (52, y - 2)]), fill=GOLD, width=int(4 * s))
        d.line(P(s, [(76, y - 2), (104, y)]), fill=GOLD, width=int(4 * s))
    done(img, 128, path)


def tab_trade(path):
    img, d, s = canvas()
    d.line(P(s, [(20, 44), (96, 44)]), fill=INK, width=int(9 * s))
    d.polygon(P(s, [(96, 26), (118, 44), (96, 62)]), fill=INK)
    d.line(P(s, [(108, 86), (32, 86)]), fill=GOLD, width=int(9 * s))
    d.polygon(P(s, [(32, 68), (10, 86), (32, 104)]), fill=GOLD)
    done(img, 128, path)


def icon_compact(path, out):
    """two arrows: inward (make small) or outward (make big)"""
    img, d, s = canvas(64)
    for (x0, y0, x1, y1) in ((16, 16, 52, 52), (112, 112, 76, 76)):
        if out:
            x0, y0, x1, y1 = x1, y1, x0, y0
        d.line([(x0 * s, y0 * s), (x1 * s, y1 * s)], fill=INK, width=int(12 * s))
        sx = 1 if x1 > x0 else -1
        d.polygon([(x1 * s, y1 * s), ((x1 - sx * 26) * s, y1 * s), (x1 * s, (y1 - sx * 26) * s)], fill=INK)
    d.rectangle([52 * s, 52 * s, 76 * s, 76 * s], outline=GOLD, width=int(8 * s))
    done(img, 64, path)


def logo(path):
    img, d, s = canvas()
    d.ellipse([6 * s, 6 * s, 122 * s, 122 * s], fill=WHITE, outline=GOLD, width=int(6 * s))
    hanger(d, s, INK, 7)
    d.ellipse([56 * s, 92 * s, 72 * s, 108 * s], fill=ROSE)
    done(img, 128, path)


def icon_close(path):
    img, d, s = canvas(64)
    d.line([(16 * s, 16 * s), (112 * s, 112 * s)], fill=INK, width=int(16 * s))
    d.line([(112 * s, 16 * s), (16 * s, 112 * s)], fill=INK, width=int(16 * s))
    done(img, 64, path)


def icon_plus(path):
    img, d, s = canvas(64)
    d.text((10 * s, 12 * s), "A", fill=INK, font=font(int(92 * s)))
    d.line([(92 * s, 24 * s), (92 * s, 64 * s)], fill=GOLD, width=int(12 * s))
    d.line([(72 * s, 44 * s), (112 * s, 44 * s)], fill=GOLD, width=int(12 * s))
    done(img, 64, path)


def icon_minus(path):
    img, d, s = canvas(64)
    d.text((10 * s, 12 * s), "A", fill=INK, font=font(int(92 * s)))
    d.line([(72 * s, 44 * s), (112 * s, 44 * s)], fill=GOLD, width=int(12 * s))
    done(img, 64, path)


def icon_settings(path):
    img, d, s = canvas(64)
    cx, cy = 64 * s, 64 * s
    for k in range(8):
        a = k * math.pi / 4
        d.line([(cx + math.cos(a) * 30 * s, cy + math.sin(a) * 30 * s), (cx + math.cos(a) * 54 * s, cy + math.sin(a) * 54 * s)],
               fill=INK, width=int(18 * s))
    d.ellipse([cx - 40 * s, cy - 40 * s, cx + 40 * s, cy + 40 * s], fill=INK)
    d.ellipse([cx - 16 * s, cy - 16 * s, cx + 16 * s, cy + 16 * s], fill=(0, 0, 0, 0))
    done(img, 64, path)


def pin(path, on):
    img, d, s = canvas(64)
    col = GOLD if on else INK
    d.ellipse([38 * s, 10 * s, 90 * s, 62 * s], fill=col)
    d.line([(64 * s, 60 * s), (64 * s, 118 * s)], fill=col, width=int(10 * s))
    if not on:
        d.line([(20 * s, 108 * s), (108 * s, 20 * s)], fill=INK, width=int(8 * s))
    done(img, 64, path)


def lipstick(path):
    img, d, s = canvas(64)
    d.rounded_rectangle([40 * s, 64 * s, 88 * s, 120 * s], radius=6 * s, fill=GOLD)
    d.rectangle([46 * s, 40 * s, 82 * s, 66 * s], fill=INK)
    d.polygon(P(s, [(48, 42), (80, 42), (80, 14), (48, 28)]), fill=(196, 34, 52, 255))
    done(img, 64, path)


def font(px):
    for name in ("DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, px)
        except OSError:
            pass
    return ImageFont.load_default()


def poster(path, size):
    w, h = size
    img = Image.new("RGBA", (w, h), (248, 245, 240, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([0, h - h // 5, w, h], fill=(236, 228, 216, 255))
    s = min(w, h) / 128.0 * 0.55
    ox, oy = (w - 128 * s) / 2, h * 0.12
    def Q(pts): return [(ox + x * s, oy + y * s) for x, y in pts]
    d.arc([ox + 54 * s, oy + 16 * s, ox + 74 * s, oy + 36 * s], 180, 90, fill=INK, width=max(2, int(7 * s)))
    d.line(Q([(64, 36), (64, 44)]), fill=INK, width=max(2, int(7 * s)))
    d.line(Q([(64, 44), (16, 86), (112, 86), (64, 44)]), fill=INK, width=max(2, int(7 * s)), joint="curve")
    d.polygon(Q([(34, 90), (94, 90), (102, 118), (26, 118)]), fill=GOLD)
    f1, f2 = font(max(12, h // 10)), font(max(10, h // 16))
    t1, t2 = "Life With Style", "HARMONIE"
    d.text(((w - d.textlength(t2, font=f2)) / 2, h * 0.70), t2, fill=GOLD, font=f2)
    d.text(((w - d.textlength(t1, font=f1)) / 2, h * 0.78), t1, fill=INK, font=f1)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", path)


if __name__ == "__main__":
    tab_dress(os.path.join(UI, "tab_dress.png"))
    tab_collection(os.path.join(UI, "tab_collection.png"))
    tab_admin(os.path.join(UI, "tab_admin.png"))
    tab_guide(os.path.join(UI, "tab_guide.png"))
    tab_trade(os.path.join(UI, "tab_trade.png"))
    icon_compact(os.path.join(UI, "icon_compact.png"), False)
    icon_compact(os.path.join(UI, "icon_expand.png"), True)
    logo(os.path.join(UI, "logo.png"))
    icon_close(os.path.join(UI, "icon_close.png"))
    icon_plus(os.path.join(UI, "icon_plus.png"))
    icon_minus(os.path.join(UI, "icon_minus.png"))
    icon_settings(os.path.join(UI, "icon_settings.png"))
    pin(os.path.join(UI, "pin_on.png"), True)
    pin(os.path.join(UI, "pin_off.png"), False)
    lipstick(os.path.join(MOD, "media", "textures", "Item_LWS_Makeup.png"))
    poster(os.path.join(MOD, "poster.png"), (512, 512))
    poster(os.path.join(MOD, "icon.png"), (64, 64))
    poster(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(HERE))), "Workshop", "HARMONIE_LifeWithStyle", "preview.png"), (256, 256))
