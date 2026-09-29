#!/usr/bin/env python3
"""Round 23: icons for the new Epic / Elite / Legendary weapons -- drawn by
this script (no third-party art). Realistic tools and weapons of the kind a
survivor would forge or scavenge: steel blades, hammers, batons, spears,
axes, sledges -- no glow, no fantasy shapes.

Each weapon is drawn lying horizontally (handle left, head right) on a big
canvas, turned 45 degrees to the usual up-right item-icon pose, given a dark
outline and scaled down to 32x32. Writes ../42/media/textures/Item_<Icon>.png.
The list of weapons (and their looks) comes from gen_new_weapons.WEAPONS.
Needs Pillow."""
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "42", "media", "textures")
S = 32
C = 400           # drawing canvas (horizontal pose)
W = 256           # final big canvas before scaling to 32
CY = C // 2

# finishes (steel colours, lighter -> darker)
FIN = {
    "steel":   ((205, 210, 218), (150, 156, 166), (95, 100, 110)),     # bead-blasted steel
    "black":   ((95, 98, 104), (58, 60, 66), (32, 33, 37)),             # black coated
    "damascus": ((190, 192, 196), (130, 132, 138), (80, 82, 88)),       # patterned
    "mirror":  ((240, 244, 250), (185, 192, 204), (120, 128, 142)),    # polished
    "brass":   ((220, 190, 120), (170, 135, 70), (110, 85, 40)),
}
GRIPS = {
    "black":  ((70, 72, 76), (40, 41, 44)),
    "olive":  ((110, 112, 78), (70, 72, 48)),
    "wood":   ((150, 100, 60), (100, 64, 36)),
    "darkwood": ((105, 68, 42), (66, 40, 24)),
    "cord":   ((60, 70, 60), (35, 42, 36)),
    "coyote": ((170, 140, 100), (120, 96, 66)),
    "rubber": ((50, 52, 56), (28, 29, 32)),
    "red":    ((150, 40, 36), (95, 24, 22)),
}

class Pen:
    """Composites see-through fills (Pillow would replace the alpha)."""
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
    def rectangle(self, *a, **k): self._go("rectangle", a, k)

def rgba(c, a=255): return tuple(c[:3]) + (a,)

def band_poly(d, x0, x1, y0, y1, cols):
    """A bar from x0..x1, y0..y1 shaded top light -> bottom dark."""
    n = len(cols)
    h = (y1 - y0) / n
    for i, c in enumerate(cols):
        d.rectangle([x0, y0 + i * h, x1, y0 + (i + 1) * h + 1], fill=rgba(c))

def shade3(fin):
    a, b, c = FIN[fin]
    return [a, b, b, c]

# ---- handles -----------------------------------------------------------------

def grip(d, x0, x1, thick, style, rnd, cord=False, cy=CY):
    lo, hi = GRIPS[style][1], GRIPS[style][0]
    y0, y1 = cy - thick / 2, cy + thick / 2
    band_poly(d, x0, x1, y0, y1, [hi, hi, lo, lo])
    d.line([(x0, y0 + 2), (x1, y0 + 2)], fill=rgba(tuple(min(255, v + 40) for v in hi)), width=2)
    if cord:  # paracord wrap
        for x in range(int(x0) + 3, int(x1) - 2, 7):
            d.line([(x, y0), (x + 5, y1)], fill=rgba(lo), width=3)
            d.line([(x + 1, y0), (x + 6, y1)], fill=rgba(tuple(min(255, v + 25) for v in hi)), width=1)
    else:     # texture grooves
        for x in range(int(x0) + 6, int(x1) - 4, 9):
            d.line([(x, y0 + 3), (x, y1 - 3)], fill=rgba(lo, 200), width=2)
    d.rectangle([x0, y0, x1, y1], outline=rgba((20, 20, 22)), width=2)

def long_shaft(d, x0, x1, thick, style, cy=CY):
    lo, hi = GRIPS[style][1], GRIPS[style][0]
    band_poly(d, x0, x1, cy - thick / 2, cy + thick / 2, [hi, hi, lo])
    d.line([(x0, cy - thick / 2 + 2), (x1, cy - thick / 2 + 2)], fill=rgba(tuple(min(255, v + 45) for v in hi)), width=2)
    d.rectangle([x0, cy - thick / 2, x1, cy + thick / 2], outline=rgba((20, 20, 22)), width=2)

def pommel(d, x, thick, fin, cy=CY):
    a, b, c = FIN[fin]
    d.rectangle([x - 8, cy - thick / 2 - 2, x + 2, cy + thick / 2 + 2], fill=rgba(b), outline=rgba((20, 20, 22)), width=2)

def guard(d, x, h, fin, cy=CY, w=8):
    a, b, c = FIN[fin]
    d.rectangle([x, cy - h / 2, x + w, cy + h / 2], fill=rgba(b), outline=rgba((20, 20, 22)), width=2)
    d.line([(x + 2, cy - h / 2 + 2), (x + 2, cy + h / 2 - 2)], fill=rgba(a), width=2)

# ---- blades ------------------------------------------------------------------

def blade(d, x0, x1, h, fin, kind, rnd, cy=CY):
    """Knife-like blade from x0 (ricasso) to x1 (tip); spine on top."""
    a, b, c = FIN[fin]
    top, bot = cy - h * 0.55, cy + h * 0.45
    L = x1 - x0
    if kind == "tanto":
        pts = [(x0, top), (x1 - L * 0.18, top), (x1, top + h * 0.25), (x1 - L * 0.12, bot - h * 0.1), (x0, bot)]
        edge_top = [(x1 - L * 0.12, bot - h * 0.1), (x1, top + h * 0.25)]
    elif kind == "bowie":
        pts = [(x0, top), (x1 - L * 0.3, top), (x1 - L * 0.12, top + h * 0.18), (x1, top + h * 0.3), (x1 - L * 0.25, bot), (x0, bot)]
        edge_top = [(x1 - L * 0.3, top), (x1, top + h * 0.3)]
    elif kind == "dagger":
        pts = [(x0, top + h * 0.05), (x1 - L * 0.1, cy - h * 0.12), (x1, cy), (x1 - L * 0.1, cy + h * 0.12), (x0, bot - h * 0.05)]
        edge_top = None
    else:  # fighter / drop point / trench
        pts = [(x0, top), (x1 - L * 0.35, top), (x1, cy - h * 0.05), (x1 - L * 0.2, bot - h * 0.12), (x0, bot)]
        edge_top = [(x1 - L * 0.35, top), (x1, cy - h * 0.05)]
    d.polygon(pts, fill=rgba(b))
    # flat (upper) lighter, bevel to the edge lighter still
    flat = [(x0, top + 2), (x1 - L * 0.4, top + 2), (x1 - L * 0.22, cy - h * 0.05), (x0, cy - h * 0.05)]
    d.polygon(flat, fill=rgba(a, 160))
    bevel = [(x0, bot - h * 0.3), (x1 - L * 0.3, bot - h * 0.3), (x1 - L * 0.08, cy + h * 0.02), (x1 - L * 0.2, bot - h * 0.06), (x0, bot - 1)]
    d.polygon(bevel, fill=rgba(tuple(min(255, v + 25) for v in a), 170))
    if fin == "damascus":
        for k in range(9):
            yy = top + 4 + k * (h - 8) / 9
            pts2 = [(x0 + 4 + j * 10, yy + 3 * math.sin(j * 0.9 + k)) for j in range(int((L * 0.75) / 10))]
            if len(pts2) > 1: d.line(pts2, fill=rgba(c, 150), width=2)
    if kind == "dagger":
        d.line([(x0, cy), (x1 - L * 0.05, cy)], fill=rgba(c, 200), width=2)   # central ridge
    else:
        d.line([(x0 + 4, cy - h * 0.1), (x1 - L * 0.45, cy - h * 0.1)], fill=rgba(c, 150), width=2)  # fuller
    if edge_top:
        d.line(edge_top, fill=rgba((250, 252, 255), 200), width=2)
    d.line(pts + [pts[0]], fill=rgba((25, 26, 30)), width=3)
    return top, bot

def serrate(d, x0, x1, y, fin):
    a, b, c = FIN[fin]
    for x in range(int(x0), int(x1), 8):
        d.polygon([(x, y), (x + 4, y - 5), (x + 8, y)], fill=rgba(c))

def knife(name, style, fin, grip_style, rnd, serrated=False, trench=False, cord=False):
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0)); d = Pen(img)
    L = 310
    x0 = (C - L) / 2
    gx1 = x0 + L * 0.36
    grip(d, x0 + 10, gx1, 30, grip_style, rnd, cord=cord)
    pommel(d, x0 + 12, 30, fin)
    if trench:
        # knuckle guard -- a steel loop over the grip
        d.line([(x0 + 14, CY - 22), (x0 + 30, CY - 34), (gx1 - 10, CY - 34), (gx1 + 4, CY - 22)], fill=rgba(FIN[fin][2]), width=7)
        d.line([(x0 + 14, CY - 22), (x0 + 30, CY - 34), (gx1 - 10, CY - 34), (gx1 + 4, CY - 22)], fill=rgba(FIN[fin][0]), width=3)
    guard(d, gx1, 54, fin)
    top, bot = blade(d, gx1 + 8, x0 + L, 52, fin, style, rnd)
    if serrated: serrate(d, gx1 + 20, gx1 + 80, top + 1, fin)
    return img

def hammer(name, style, fin, grip_style, rnd):
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0)); d = Pen(img)
    L = 320
    x0 = (C - L) / 2
    hx = x0 + L - 40                       # head centre along the handle
    long_shaft(d, x0 + 30, hx + 6, 22, "wood" if grip_style == "wood" else "black")
    grip(d, x0 + 10, x0 + 130, 30, grip_style, rnd)
    a, b, c = FIN[fin]
    # head: across the handle (vertical in the horizontal pose)
    if style == "claw":
        d.polygon([(hx - 14, CY - 20), (hx + 14, CY - 20), (hx + 14, CY + 20), (hx - 14, CY + 20)], fill=rgba(b))
        d.rectangle([hx - 16, CY + 18, hx + 16, CY + 58], fill=rgba(a), outline=rgba((25, 25, 28)), width=3)   # face
        d.polygon([(hx - 12, CY - 20), (hx + 12, CY - 20), (hx + 22, CY - 70), (hx + 4, CY - 64)], fill=rgba(c))  # claw
        d.line([(hx + 4, CY - 64), (hx + 14, CY - 45)], fill=rgba((20, 20, 22)), width=3)
    elif style == "ballpeen":
        d.rectangle([hx - 16, CY - 50, hx + 16, CY + 56], fill=rgba(b), outline=rgba((25, 25, 28)), width=3)
        d.ellipse([hx - 18, CY - 70, hx + 18, CY - 38], fill=rgba(a), outline=rgba((25, 25, 28)), width=3)
        d.rectangle([hx - 18, CY + 44, hx + 18, CY + 60], fill=rgba(a), outline=rgba((25, 25, 28)), width=3)
    elif style == "club":      # hand sledge / club hammer
        d.rectangle([hx - 24, CY - 50, hx + 24, CY + 50], fill=rgba(b), outline=rgba((25, 25, 28)), width=3)
        d.rectangle([hx - 26, CY - 54, hx + 26, CY - 40], fill=rgba(a), outline=rgba((25, 25, 28)), width=2)
        d.rectangle([hx - 26, CY + 40, hx + 26, CY + 54], fill=rgba(a), outline=rgba((25, 25, 28)), width=2)
    elif style == "war":       # hammer face + back spike
        d.rectangle([hx - 16, CY - 18, hx + 16, CY + 48], fill=rgba(b), outline=rgba((25, 25, 28)), width=3)
        d.rectangle([hx - 20, CY + 36, hx + 20, CY + 58], fill=rgba(a), outline=rgba((25, 25, 28)), width=3)
        d.polygon([(hx - 12, CY - 18), (hx + 12, CY - 18), (hx + 2, CY - 78)], fill=rgba(a), outline=rgba((25, 25, 28)))
        d.line([(hx, CY - 20), (hx + 1, CY - 70)], fill=rgba(c), width=2)
        d.polygon([(hx + 14, CY - 10), (hx + 50, CY - 4), (hx + 50, CY + 4), (hx + 14, CY + 10)], fill=rgba(b), outline=rgba((25, 25, 28)))  # top spike
    d.line([(hx - 10, CY - 16), (hx - 10, CY + 16)], fill=rgba((255, 255, 255), 90), width=3)
    return img

def baton(name, fin, grip_style, rnd):
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0)); d = Pen(img)
    L = 340
    x0 = (C - L) / 2
    grip(d, x0 + 8, x0 + 120, 28, grip_style, rnd)
    a, b, c = FIN[fin]
    # telescoping steel sections, thinner toward the tip
    for i, (w, h) in enumerate(((100, 22), (80, 18), (40, 14))):
        xs = x0 + 120 + sum(v for v, _ in ((100, 22), (80, 18), (40, 14))[:i])
        band_poly(d, xs, xs + w, CY - h / 2, CY + h / 2, [a, b, c])
        d.rectangle([xs, CY - h / 2, xs + w, CY + h / 2], outline=rgba((25, 25, 28)), width=2)
    tip = x0 + 120 + 220
    d.ellipse([tip - 12, CY - 12, tip + 12, CY + 12], fill=rgba(b), outline=rgba((25, 25, 28)), width=2)
    d.ellipse([x0, CY - 16, x0 + 14, CY + 16], fill=rgba(b), outline=rgba((25, 25, 28)), width=2)
    return img

def spear(name, style, fin, shaft, rnd):
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0)); d = Pen(img)
    x0, x1 = 6, C - 6
    head0 = x1 - 110
    long_shaft(d, x0, head0 + 6, 16, shaft)
    for k in range(3):   # grip wraps
        xx = x0 + 40 + k * 16
        d.rectangle([xx, CY - 10, xx + 10, CY + 10], fill=rgba(GRIPS["black"][0]), outline=rgba((20, 20, 22)), width=1)
    a, b, c = FIN[fin]
    d.rectangle([head0 - 26, CY - 11, head0 + 4, CY + 11], fill=rgba(b), outline=rgba((25, 25, 28)), width=2)  # socket
    if style == "boar":
        d.polygon([(head0, CY - 22), (x1 - 12, CY - 3), (x1, CY), (x1 - 12, CY + 3), (head0, CY + 22)], fill=rgba(b))
        d.polygon([(head0, CY - 22), (x1 - 12, CY - 3), (x1, CY), (head0, CY)], fill=rgba(a))
        d.line([(head0, CY), (x1 - 4, CY)], fill=rgba(c), width=2)
        d.rectangle([head0 - 12, CY - 34, head0 - 4, CY + 34], fill=rgba(c), outline=rgba((25, 25, 28)), width=2)  # lugs
        d.polygon([(head0, CY - 22), (x1 - 12, CY - 3), (x1, CY), (x1 - 12, CY + 3), (head0, CY + 22)], outline=rgba((25, 25, 28)))
    elif style == "pike":
        d.polygon([(head0, CY - 8), (x1, CY), (head0, CY + 8)], fill=rgba(a), outline=rgba((25, 25, 28)))
        d.line([(head0 + 30, CY + 4), (head0 + 60, CY + 40), (head0 + 40, CY + 50)], fill=rgba(c), width=9)   # hook
        d.line([(head0 + 30, CY + 4), (head0 + 60, CY + 40), (head0 + 40, CY + 50)], fill=rgba(a), width=4)
    elif style == "gig":
        for dy in (-18, 0, 18):
            d.line([(head0, CY + dy * 0.3), (x1 - 8, CY + dy)], fill=rgba(c), width=7)
            d.line([(head0, CY + dy * 0.3), (x1 - 8, CY + dy)], fill=rgba(a), width=3)
            d.polygon([(x1 - 14, CY + dy - 6), (x1, CY + dy), (x1 - 14, CY + dy + 1)], fill=rgba(a))
        d.rectangle([head0 - 4, CY - 8, head0 + 10, CY + 8], fill=rgba(b), outline=rgba((25, 25, 28)), width=2)
    elif style == "naginata":
        pts = [(head0, CY - 10), (x1 - 40, CY - 14), (x1, CY - 40), (x1 - 20, CY - 6), (head0, CY + 12)]
        d.polygon(pts, fill=rgba(b)); d.polygon([(head0, CY + 4), (x1 - 30, CY - 2), (x1 - 4, CY - 34), (head0 + 40, CY + 10)], fill=rgba(a, 170))
        d.polygon(pts, outline=rgba((25, 25, 28)))
        d.rectangle([head0 - 8, CY - 18, head0, CY + 18], fill=rgba(c), outline=rgba((25, 25, 28)), width=2)
    else:  # leaf / bayonet
        wid = 24 if style == "leaf" else 16
        pts = [(head0, CY - wid * 0.5), (head0 + 60, CY - wid), (x1, CY), (head0 + 60, CY + wid), (head0, CY + wid * 0.5)]
        d.polygon(pts, fill=rgba(b)); d.polygon([(head0, CY - wid * 0.4), (head0 + 60, CY - wid + 2), (x1 - 4, CY), (head0, CY)], fill=rgba(a))
        d.line([(head0, CY), (x1 - 6, CY)], fill=rgba(c), width=2)
        d.polygon(pts, outline=rgba((25, 25, 28)))
    return img

def axe(name, style, fin, shaft, rnd):
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0)); d = Pen(img)
    L = 300 if style in ("felling", "doublebit", "breach") else 270
    x0 = (C - L) / 2
    hx = x0 + L - 40
    long_shaft(d, x0, hx + 20, 22, shaft)
    grip(d, x0 + 4, x0 + 90, 26, "black" if shaft != "wood" else "darkwood", rnd)
    a, b, c = FIN[fin]
    d.rectangle([hx - 14, CY - 20, hx + 14, CY + 20], fill=rgba(b), outline=rgba((25, 25, 28)), width=2)  # eye
    def bit(sign, big):
        # a broad blade out from the eye, its curved cutting edge running
        # along the handle's direction
        h = 96 if big else 74
        back, front = (hx - 38, hx + 46) if big else (hx - 30, hx + 36)
        edge = [(back + (front - back) * t, CY + sign * (h + 8 * math.sin(math.pi * t))) for t in [i / 8 for i in range(9)]]
        # a solid wedge: a wide cheek from the eye, flaring to the edge
        pts = [(hx - 22, CY + sign * 16), (hx - 26, CY + sign * (h * 0.45))] + edge + [(hx + 30, CY + sign * (h * 0.45)), (hx + 24, CY + sign * 16)]
        d.polygon(pts, fill=rgba(b))
        bev = [(x, y - sign * 14) for x, y in edge]
        d.polygon(edge + bev[::-1], fill=rgba(a))
        d.line(edge, fill=rgba((250, 252, 255), 230), width=3)
        d.polygon(pts, outline=rgba((25, 25, 28)))
    if style == "doublebit":
        bit(1, True); bit(-1, True)
    elif style == "breach":
        bit(1, True)
        d.polygon([(hx - 10, CY - 18), (hx + 10, CY - 18), (hx, CY - 70)], fill=rgba(a), outline=rgba((25, 25, 28)))  # spike
    elif style == "tomahawk":
        bit(1, False)
        d.polygon([(hx - 8, CY - 18), (hx + 8, CY - 18), (hx + 2, CY - 52)], fill=rgba(a), outline=rgba((25, 25, 28)))
    else:  # felling
        bit(1, True)
        d.rectangle([hx - 16, CY - 34, hx + 16, CY - 18], fill=rgba(c), outline=rgba((25, 25, 28)), width=2)  # poll
    return img

def sledge(name, style, fin, shaft, rnd):
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0)); d = Pen(img)
    L = 360
    x0 = (C - L) / 2
    hx = x0 + L - 44
    long_shaft(d, x0, hx + 10, 22, shaft)
    grip(d, x0 + 4, x0 + 90, 26, "rubber" if shaft != "wood" else "darkwood", rnd)
    a, b, c = FIN[fin]
    if style == "maul":
        pts = [(hx - 26, CY - 34), (hx + 26, CY - 34), (hx + 26, CY + 20), (hx, CY + 74), (hx - 26, CY + 20)]
        d.polygon(pts, fill=rgba(b))
        d.polygon([(hx - 26, CY - 34), (hx - 6, CY - 34), (hx - 6, CY + 30), (hx, CY + 74), (hx - 26, CY + 20)], fill=rgba(a, 170))
        d.polygon(pts, outline=rgba((25, 25, 28)))
        d.rectangle([hx - 28, CY - 48, hx + 28, CY - 32], fill=rgba(a), outline=rgba((25, 25, 28)), width=3)
    else:  # sledgehammer
        d.rectangle([hx - 30, CY - 58, hx + 30, CY + 58], fill=rgba(b), outline=rgba((25, 25, 28)), width=3)
        d.rectangle([hx - 32, CY - 62, hx + 32, CY - 46], fill=rgba(a), outline=rgba((25, 25, 28)), width=2)
        d.rectangle([hx - 32, CY + 46, hx + 32, CY + 62], fill=rgba(a), outline=rgba((25, 25, 28)), width=2)
        d.line([(hx - 22, CY - 44), (hx - 22, CY + 44)], fill=rgba((255, 255, 255), 80), width=4)
    return img

def bat(name, fin, grip_style, rnd):
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0)); d = Pen(img)
    L = 360
    x0 = (C - L) / 2
    a, b, c = FIN[fin]
    # a tapered steel bat: knob, grip tape, widening barrel
    pts = [(x0 + 10, CY - 10), (x0 + 130, CY - 12), (x0 + L - 70, CY - 34), (x0 + L - 14, CY - 34), (x0 + L, CY - 18), (x0 + L, CY + 18),
           (x0 + L - 14, CY + 34), (x0 + L - 70, CY + 34), (x0 + 130, CY + 12), (x0 + 10, CY + 10)]
    d.polygon(pts, fill=rgba(b))
    d.polygon([(x0 + 10, CY - 10), (x0 + 130, CY - 12), (x0 + L - 70, CY - 34), (x0 + L - 14, CY - 34), (x0 + L - 10, CY - 14), (x0 + 10, CY - 3)], fill=rgba(a))
    d.ellipse([x0 + L - 20, CY - 34, x0 + L + 4, CY + 34], fill=rgba(c), outline=rgba((25, 25, 28)), width=2)   # end cap
    d.polygon(pts, outline=rgba((25, 25, 28)))
    grip(d, x0 + 12, x0 + 130, 20, grip_style, rnd)
    d.ellipse([x0, CY - 16, x0 + 16, CY + 16], fill=rgba(c), outline=rgba((25, 25, 28)), width=2)
    for k in range(3):  # welded reinforcing bands
        xx = x0 + 190 + k * 45
        d.line([(xx, CY - 20 - k * 2), (xx, CY + 20 + k * 2)], fill=rgba(c), width=5)
    return img

def finish(img, name):
    img = img.rotate(45, resample=Image.BICUBIC, center=(C / 2, C / 2))
    off = (C - W) // 2
    img = img.crop((off, off, off + W, off + W))
    a = img.split()[3]
    ol = a.filter(ImageFilter.MaxFilter(11))
    bg = Image.new("RGBA", (W, W), (14, 14, 16, 0)); bg.putalpha(ol.point(lambda v: int(v * 0.9)))
    bg.alpha_composite(img)
    bg.resize((S, S), Image.LANCZOS).save(os.path.join(OUT, "Item_%s.png" % name))
    return bg

def draw(w):
    rnd = random.Random(hash(w["key"]) & 0xffff)
    k, st = w["look"][0], w["look"][1:]
    if k == "knife":
        style, fin, gs = st[0], st[1], st[2]
        opts = st[3] if len(st) > 3 else {}
        return knife(w["icon"], style, fin, gs, rnd, **opts)
    if k == "hammer": return hammer(w["icon"], st[0], st[1], st[2], rnd)
    if k == "baton": return baton(w["icon"], st[0], st[1], rnd)
    if k == "spear": return spear(w["icon"], st[0], st[1], st[2], rnd)
    if k == "axe": return axe(w["icon"], st[0], st[1], st[2], rnd)
    if k == "sledge": return sledge(w["icon"], st[0], st[1], st[2], rnd)
    if k == "bat": return bat(w["icon"], st[0], st[1], rnd)
    raise ValueError(k)

def main():
    sys.path.insert(0, HERE)
    from gen_new_weapons import WEAPONS
    sheet = Image.new("RGBA", (8 * 132, ((len(WEAPONS) + 7) // 8) * 132), (50, 50, 56, 255))
    for i, w in enumerate(WEAPONS):
        big = finish(draw(w), w["icon"])
        small = Image.open(os.path.join(OUT, "Item_%s.png" % w["icon"])).resize((128, 128), Image.NEAREST)
        sheet.alpha_composite(small, ((i % 8) * 132 + 2, (i // 8) * 132 + 2))
    if len(sys.argv) > 1: sheet.save(sys.argv[1])
    print("icons:", len(WEAPONS))

if __name__ == "__main__":
    main()
