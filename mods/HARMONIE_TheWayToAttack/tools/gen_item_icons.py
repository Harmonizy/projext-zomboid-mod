#!/usr/bin/env python3
"""Draws this mod's own item icons (32x32, drawn 8x and scaled down; no
third-party art). Round 15:
  - 17 gemstones, each with its own cut AND colour,
  - Mithril / Adamantium / Vibranium ingots (clear violet, blazing orange,
    radiant gold with a rainbow sheen), one ingot shape for all,
  - Oridecon / Elunium / Bradium ore crystals.
Round 16: TWA_Gemstone is an angular rock with gem colour peeking out.
Writes ../42/media/textures/Item_<Icon>.png. Needs Pillow."""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter

S, N = 32, 8
W = S * N
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "42", "media", "textures")
LIGHT = (-0.55, -0.7)

class Pen:
    """ImageDraw that really blends see-through fills (Pillow replaces the
    alpha of an RGBA image instead of compositing) -- a see-through shape is
    drawn on its own layer and composited."""
    def __init__(self, img):
        self.img, self.d = img, ImageDraw.Draw(img)
    def _go(self, fn, args, kw):
        fill = kw.get("fill")
        if fill is not None and len(fill) == 4 and fill[3] < 255:
            layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
            getattr(ImageDraw.Draw(layer), fn)(*args, **kw)
            self.img.alpha_composite(layer)
        else:
            getattr(self.d, fn)(*args, **kw)
    def polygon(self, *a, **k): self._go("polygon", a, k)
    def line(self, *a, **k): self._go("line", a, k)
    def ellipse(self, *a, **k): self._go("ellipse", a, k)

def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (c[3] if len(c) > 3 else 255,)

def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)

def finish(img, name):
    a = img.split()[3]
    ol = a.filter(ImageFilter.MaxFilter(2 * N - 3))
    bg = Image.new("RGBA", (W, W), (18, 16, 22, 0)); bg.putalpha(ol.point(lambda v: int(v * 0.9)))
    bg.alpha_composite(img)
    bg.resize((S, S), Image.LANCZOS).save(os.path.join(OUT, "Item_%s.png" % name))

def poly(shape, cx=W / 2, cy=W / 2, sx=W * 0.42, sy=W * 0.42):
    return [(cx + x * sx, cy + y * sy) for x, y in shape]

def shape_round(n=16, rx=1.0, ry=1.0, rot=0.0):
    return [(math.cos(rot + i * 2 * math.pi / n) * rx, math.sin(rot + i * 2 * math.pi / n) * ry) for i in range(n)]

def faceted(name, outline, col, table=0.5, sparkle=True, second=None, crown=None):
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0)); d = Pen(img)
    pts = outline
    cx = sum(p[0] for p in pts) / len(pts); cy = sum(p[1] for p in pts) / len(pts)
    inner = [(cx + (x - cx) * table, cy + (y - cy) * table) for x, y in pts]
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        ia, ib = inner[i], inner[(i + 1) % n]
        mx, my = (a[0] + b[0]) / 2 - cx, (a[1] + b[1]) / 2 - cy
        l = math.hypot(mx, my) or 1
        lit = (mx / l) * LIGHT[0] + (my / l) * LIGHT[1]
        c = col if not second else mix(col, second, (i / n))
        d.polygon([a, b, ib, ia], fill=shade(c, 0.75 + 0.55 * lit))
        d.line([a, b], fill=shade(c, 0.45), width=3)
        d.line([ia, a], fill=shade(c, 1.35), width=2)
    d.polygon(inner, fill=shade(col if not second else mix(col, second, 0.5), 1.15))
    # table highlights
    for k in range(3):
        t = 0.55 - k * 0.12
        hi = [(cx + (x - cx) * table * t - W * 0.05, cy + (y - cy) * table * t - W * 0.05) for x, y in pts]
        d.polygon(hi, fill=shade(col, 1.3 + 0.15 * k)[:3] + (60,))
    if sparkle:
        sx, sy, r = cx - W * 0.12, cy - W * 0.13, W * 0.07
        d.polygon([(sx - r, sy), (sx, sy - r * 0.2), (sx + r, sy), (sx, sy + r * 0.2)], fill=(255, 255, 255, 230))
        d.polygon([(sx, sy - r), (sx + r * 0.2, sy), (sx, sy + r), (sx - r * 0.2, sy)], fill=(255, 255, 255, 230))
    finish(img, name)

def cabochon(name, rx, ry, col, iridescent=False, opaque=False):
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0)); d = Pen(img)
    cx, cy = W / 2, W / 2 + W * 0.03
    for k in range(40, 0, -1):
        t = k / 40
        c = shade(col, 0.55 + 0.6 * (1 - t))
        if iridescent:
            hue = (1 - t) * 6
            rainbow = (int(128 + 110 * math.sin(hue)), int(128 + 110 * math.sin(hue + 2.1)), int(128 + 110 * math.sin(hue + 4.2)))
            c = mix(c, rainbow + (255,), 0.35)
        ox, oy = -W * 0.08 * (1 - t), -W * 0.1 * (1 - t)
        d.ellipse([cx - rx * W * t + ox, cy - ry * W * t + oy, cx + rx * W * t + ox, cy + ry * W * t + oy], fill=c)
    d.ellipse([cx - rx * W * 0.45 - W * 0.1, cy - ry * W * 0.6, cx - rx * W * 0.05, cy - ry * W * 0.25], fill=(255, 255, 255, 120 if opaque else 170))
    finish(img, name)

def rough(name, col, seed=3, cols=None):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0)); d = Pen(img)
    n = 9
    pts = [(W / 2 + math.cos(i * 2 * math.pi / n) * W * rnd.uniform(0.28, 0.4), W / 2 + math.sin(i * 2 * math.pi / n) * W * rnd.uniform(0.26, 0.38)) for i in range(n)]
    cx, cy = W / 2, W / 2
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        c = cols[i % len(cols)] if cols else col
        mx, my = (a[0] + b[0]) / 2 - cx, (a[1] + b[1]) / 2 - cy
        l = math.hypot(mx, my) or 1
        lit = (mx / l) * LIGHT[0] + (my / l) * LIGHT[1]
        d.polygon([a, b, (cx + rnd.uniform(-12, 12), cy + rnd.uniform(-12, 12))], fill=shade(c, 0.8 + 0.45 * lit))
    d.line(pts + [pts[0]], fill=(60, 55, 50, 255), width=4)
    finish(img, name)

def gemrock(name, seed=7):
    """Round 16: an angular grey rock (flat chipped faces) with patches of
    gem colour peeking out where it broke open -- a raw, uncut gemstone."""
    rnd = random.Random(seed)
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0)); d = Pen(img)
    cx, cy = W * 0.5, W * 0.52
    out = [(-1.0, 0.25), (-0.75, -0.6), (0.05, -1.0), (0.9, -0.5), (1.0, 0.35), (0.35, 0.95), (-0.55, 0.85)]
    pts = [(cx + x * W * 0.4, cy + y * W * 0.34) for x, y in out]
    ridge = (cx - W * 0.06, cy - W * 0.08)          # top point where the faces meet
    n = len(pts)
    faces = []
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        mx, my = (a[0] + b[0]) / 2 - cx, (a[1] + b[1]) / 2 - cy
        l = math.hypot(mx, my) or 1
        lit = (mx / l) * LIGHT[0] + (my / l) * LIGHT[1]
        g = 118 + rnd.randint(-10, 10)
        base = (g, g - 6, g - 14, 255)
        d.polygon([a, b, ridge], fill=shade(base, 0.62 + 0.8 * lit))
        faces.append((a, b, lit))
    # crisp face edges
    for a, b, lit in faces:
        d.line([a, ridge], fill=shade((120, 114, 106), 0.9 + 0.7 * lit), width=3)
    # stone grain speckles
    for _ in range(60):
        x, y = cx + rnd.uniform(-0.8, 0.8) * W * 0.4, cy + rnd.uniform(-0.7, 0.7) * W * 0.34
        v = rnd.choice([(60, 56, 52, 90), (200, 194, 186, 70)])
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=v)
    # gem windows: a jagged break with bright faceted crystal inside
    wins = [((0.3, -0.3), 0.62, (235, 40, 90), (255, 170, 200)),
            ((-0.45, 0.3), 0.5, (40, 130, 255), (170, 230, 255)),
            ((0.45, 0.5), 0.34, (60, 210, 110), (200, 255, 210))]
    for (wx, wy), r, c1, c2 in wins:
        px, py = cx + wx * W * 0.4, cy + wy * W * 0.34
        k = 7
        rim = []
        for j in range(k):
            ang = j * 2 * math.pi / k + rnd.uniform(-0.25, 0.25)
            rr = r * W * rnd.uniform(0.6, 1.0) * 0.5
            rim.append((px + math.cos(ang) * rr, py + math.sin(ang) * rr * 0.85))
        d.polygon([(x + 3, y + 4) for x, y in rim], fill=(40, 36, 34, 200))   # dark broken lip
        for j in range(k):
            a, b = rim[j], rim[(j + 1) % k]
            t = j / k
            c = mix(c1 + (255,), c2 + (255,), 0.5 + 0.5 * math.sin(t * 6.28 + 1.0))
            d.polygon([a, b, (px, py)], fill=shade(c, 0.75 + 0.45 * math.cos(t * 6.28 + 2.3)))
        d.line(rim + [rim[0]], fill=(55, 50, 46, 255), width=2)
        # glint
        gx, gy, gr = px - r * W * 0.12, py - r * W * 0.14, r * W * 0.16
        d.polygon([(gx - gr, gy), (gx, gy - gr * 0.25), (gx + gr, gy), (gx, gy + gr * 0.25)], fill=(255, 255, 255, 235))
        d.polygon([(gx, gy - gr), (gx + gr * 0.25, gy), (gx, gy + gr), (gx - gr * 0.25, gy)], fill=(255, 255, 255, 235))
    d.line(pts + [pts[0]], fill=(52, 48, 44, 255), width=4)
    finish(img, name)

def crystals(name, col, seed):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0)); d = Pen(img)
    # a rock base with prisms growing out of it
    d.ellipse([W * 0.12, W * 0.6, W * 0.88, W * 0.92], fill=(70, 64, 60, 255))
    d.ellipse([W * 0.16, W * 0.62, W * 0.84, W * 0.86], fill=(96, 88, 80, 255))
    for k, (x, h, lean, w) in enumerate([(0.5, 0.62, 0, 0.13), (0.32, 0.45, -0.25, 0.1), (0.68, 0.48, 0.25, 0.1), (0.42, 0.3, -0.1, 0.07), (0.6, 0.32, 0.12, 0.07)]):
        bx, by = W * x, W * 0.78
        tx, ty = bx + W * lean * h, by - W * h
        ww = W * w
        c = shade(col, 0.9 + 0.1 * rnd.random())
        left = [(bx - ww, by), (tx - ww * 0.8, ty + ww * 0.6), (tx, ty), (bx, by)]
        right = [(bx, by), (tx, ty), (tx + ww * 0.8, ty + ww * 0.6), (bx + ww, by)]
        d.polygon(left, fill=shade(c, 1.25)); d.polygon(right, fill=shade(c, 0.7))
        d.line([(bx, by), (tx, ty)], fill=shade(c, 1.6), width=3)
        d.line(left[:3] + right[2:], fill=shade(c, 0.4), width=3)
    finish(img, name)

def ingot(name, top, side, front, rainbow=False, clear=False):
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0)); d = Pen(img)
    # an isometric trapezoid bar: narrow top face, sloped long side, end face
    A = (W * 0.20, W * 0.46); B = (W * 0.62, W * 0.26); C = (W * 0.86, W * 0.40); D = (W * 0.44, W * 0.60)
    Ab = (W * 0.10, W * 0.58); Bb = (W * 0.10, W * 0.58)
    E = (W * 0.10, W * 0.62); F = (W * 0.42, W * 0.80); G = (W * 0.94, W * 0.52)
    alpha = 200 if clear else 255
    d.polygon([E, F, D, A], fill=front[:3] + (alpha,))           # front slope
    d.polygon([F, G, C, D], fill=side[:3] + (alpha,))            # side slope
    d.polygon([A, B, C, D], fill=top[:3] + (alpha,))             # top face
    if rainbow:
        for i in range(7):
            t = i / 7
            hue = t * 6.28
            rc = (int(200 + 55 * math.sin(hue)), int(200 + 55 * math.sin(hue + 2.1)), int(120 + 80 * math.sin(hue + 4.2)), 110)
            p1 = (A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t)
            p2 = (A[0] + (B[0] - A[0]) * (t + 1 / 7), A[1] + (B[1] - A[1]) * (t + 1 / 7))
            p3 = (D[0] + (C[0] - D[0]) * (t + 1 / 7), D[1] + (C[1] - D[1]) * (t + 1 / 7))
            p4 = (D[0] + (C[0] - D[0]) * t, D[1] + (C[1] - D[1]) * t)
            d.polygon([p1, p2, p3, p4], fill=rc)
    if clear:
        d.line([(A[0] + 14, A[1] - 2), (B[0] - 10, B[1] + 6)], fill=(255, 255, 255, 170), width=5)
    for seg in ([A, B, C, D, A], [E, F, G], [A, E], [D, F], [C, G]):
        d.line(seg, fill=shade(front, 0.45), width=4)
    d.line([A, B], fill=shade(top, 1.4), width=4)
    # glints
    for gx, gy in ((0.5, 0.36), (0.72, 0.42)):
        x, y, r = W * gx, W * gy, W * 0.035
        d.polygon([(x - r, y), (x, y - r * 0.25), (x + r, y), (x, y + r * 0.25)], fill=(255, 255, 255, 220))
        d.polygon([(x, y - r), (x + r * 0.25, y), (x, y + r), (x - r * 0.25, y)], fill=(255, 255, 255, 220))
    finish(img, name)

# ---- gems: (item, cut, colour)
P = lambda sh, **k: poly(sh, **k)
faceted("TWA_Diamond", P(shape_round(16)), (225, 240, 255))
faceted("TWA_Ruby", P(shape_round(14, 0.8, 1.0)), (205, 20, 50))
faceted("TWA_Sapphire", P([(math.copysign(abs(math.cos(a)) ** 0.5, math.cos(a)), math.copysign(abs(math.sin(a)) ** 0.5, math.sin(a))) for a in [i * 2 * math.pi / 16 for i in range(16)]], sx=W * 0.36, sy=W * 0.36), (25, 60, 200))
faceted("TWA_Emerald", P([(-0.62, -0.9), (0.62, -0.9), (0.82, -0.7), (0.82, 0.7), (0.62, 0.9), (-0.62, 0.9), (-0.82, 0.7), (-0.82, -0.7)], sx=W * 0.34, sy=W * 0.44), (20, 150, 70), table=0.6)
faceted("TWA_Aquamarine", P([(0, -1.0), (0.45, -0.3), (0.62, 0.25), (0.45, 0.72), (0, 0.9), (-0.45, 0.72), (-0.62, 0.25), (-0.45, -0.3)]), (120, 215, 230))
faceted("TWA_Garnet", P(shape_round(10, rot=0.3)), (120, 10, 25), table=0.35)
faceted("TWA_Topaz", P([(0, -1.0), (0.38, -0.5), (0.5, 0), (0.38, 0.5), (0, 1.0), (-0.38, 0.5), (-0.5, 0), (-0.38, -0.5)], sx=W * 0.46, sy=W * 0.44), (240, 170, 30))
faceted("TWA_Tourmaline", P([(-0.3, -1.0), (0.3, -1.0), (0.38, -0.9), (0.38, 0.9), (0.3, 1.0), (-0.3, 1.0), (-0.38, 0.9), (-0.38, -0.9)], sx=W * 0.5, sy=W * 0.44), (235, 80, 150), second=(60, 180, 90), table=0.65)
faceted("TWA_Amethyst", P([(0, 0.95), (-0.75, 0.1), (-0.95, -0.4), (-0.7, -0.85), (-0.3, -0.85), (0, -0.5), (0.3, -0.85), (0.7, -0.85), (0.95, -0.4), (0.75, 0.1)]), (140, 60, 200))
cabochon("TWA_Opal", 0.36, 0.28, (230, 235, 240), iridescent=True)
faceted("TWA_Tanzanite", P([(0, -1.0), (0.3, -0.55), (0.9, 0.55), (0.5, 0.75), (-0.5, 0.75), (-0.9, 0.55), (-0.3, -0.55)]), (70, 60, 210), second=(130, 70, 200))
faceted("TWA_Peridot", P(shape_round(8, rot=math.pi / 8)), (150, 205, 40))
faceted("TWA_Alexandrite", P([(-0.8, -0.8), (0, -0.95), (0.8, -0.8), (0.95, 0), (0.8, 0.8), (0, 0.95), (-0.8, 0.8), (-0.95, 0)]), (30, 150, 140), second=(150, 60, 170))
faceted("TWA_Spinel", P(shape_round(6, rot=math.pi / 6)), (240, 60, 130))
faceted("TWA_Zircon", P([(-0.85, -0.85), (0.85, -0.85), (0.85, 0.85), (-0.85, 0.85)], sx=W * 0.38, sy=W * 0.38), (150, 210, 255), table=0.45)
cabochon("TWA_Jade", 0.34, 0.34, (60, 150, 90), opaque=True)
gemrock("TWA_Gemstone")          # round 16: angular rock, gem colour peeking out

# ---- ingots
ingot("TWA_MaterialBar_Epic", (205, 160, 255), (120, 70, 190), (160, 110, 230), clear=True)        # Mithril: clear violet
ingot("TWA_MaterialBar_Elite", (255, 190, 90), (205, 95, 20), (240, 140, 40))                       # Adamantium: blazing orange
ingot("TWA_MaterialBar_Legendary", (255, 235, 140), (200, 150, 30), (240, 200, 70), rainbow=True)   # Vibranium: radiant gold, rainbow sheen

# ---- ores
crystals("TWA_Oridecon", (120, 70, 230), 1)
crystals("TWA_Elunium", (140, 220, 255), 2)
crystals("TWA_Bradium", (220, 40, 70), 3)
print("ok")
