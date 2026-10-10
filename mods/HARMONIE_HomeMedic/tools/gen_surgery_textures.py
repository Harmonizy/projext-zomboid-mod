#!/usr/bin/env python3
"""HARMONIE - Home Medic: the surgery minigames' two textures (our own art).

Writes 42/media/textures/HARMONIE_HomeMedic/surg_dot.png (filled circle) and
surg_ring.png (ring), white on transparent, antialiased, 128 px -- the games
tint and scale them (HM_SurgeryGames.lua) -- and tab_*.png, the
medical window's tab icons (one badge style: monitor, immunity, stats,
diagnosis, surgery, disease handbook, medication handbook, medical guide) -- and pin_on.png / pin_off.png, the windows' pin button,
and icon_*.png, the glyphs of the small buttons and the settings window (R71).
"""
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "42", "media", "textures", "HARMONIE_HomeMedic")
N = 128


def disc(inner=None):
    y, x = np.mgrid[0:N, 0:N] + 0.5
    r = np.hypot(x - N / 2, y - N / 2)
    outer = np.clip(N / 2 - 1 - r + 0.5, 0, 1)
    a = outer if inner is None else outer * np.clip(r - inner + 0.5, 0, 1)
    rgba = np.zeros((N, N, 4), np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = (a * 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


CREAM = (238, 232, 220, 255)
RED = (82, 172, 255, 255)        # accent (HM_Theme blue; the name is historical)


def _canvas(size):
    from PIL import ImageDraw
    big = size * 4
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = big / 128.0
    # the shared badge: dark blue rounded plate, blue rim (HM_Theme)
    d.rounded_rectangle([6 * s, 6 * s, 122 * s, 122 * s], radius=22 * s, fill=(12, 22, 36, 235),
                        outline=(56, 128, 217, 255), width=int(4 * s))
    return img, d, s


def _done(img, size):
    return img.resize((size, size), Image.LANCZOS)


def _pulse(d, s, pts, width=7, fill=RED):
    d.line([(x * s, y * s) for x, y in pts], fill=fill, width=int(width * s), joint="curve")


def tab_ehr(size=128):
    """Monitor: a heart with a heartbeat trace across it."""
    img, d, s = _canvas(size)
    d.ellipse([28 * s, 30 * s, 66 * s, 68 * s], fill=CREAM)
    d.ellipse([62 * s, 30 * s, 100 * s, 68 * s], fill=CREAM)
    d.polygon([(30 * s, 56 * s), (98 * s, 56 * s), (64 * s, 100 * s)], fill=CREAM)
    _pulse(d, s, [(16, 64), (40, 64), (50, 44), (62, 84), (72, 54), (80, 64), (112, 64)], 7)
    return _done(img, size)


def tab_immunity(size=128):
    """Immune system: a shield with a cross."""
    img, d, s = _canvas(size)
    d.polygon([(64 * s, 20 * s), (102 * s, 34 * s), (98 * s, 74 * s), (64 * s, 108 * s),
               (30 * s, 74 * s), (26 * s, 34 * s)], fill=CREAM)
    d.rectangle([57 * s, 40 * s, 71 * s, 86 * s], fill=RED)
    d.rectangle([41 * s, 56 * s, 87 * s, 70 * s], fill=RED)
    return _done(img, size)


def tab_stats(size=128):
    """Body stats: a chart -- bars of different heights and a trend line."""
    img, d, s = _canvas(size)
    d.line([(26 * s, 100 * s), (104 * s, 100 * s)], fill=CREAM, width=int(5 * s))
    for x, top in ((32, 70), (52, 50), (72, 62), (92, 36)):
        d.rounded_rectangle([x * s, top * s, (x + 13) * s, 96 * s], radius=3 * s, fill=CREAM)
    _pulse(d, s, [(30, 56), (50, 36), (70, 48), (100, 22)], 6)
    return _done(img, size)


def tab_diagnosis(size=128):
    """Diagnosis: a magnifying glass over a heartbeat."""
    img, d, s = _canvas(size)
    d.ellipse([22 * s, 20 * s, 84 * s, 82 * s], outline=CREAM, width=int(9 * s))
    d.line([(76 * s, 74 * s), (104 * s, 102 * s)], fill=CREAM, width=int(15 * s))
    _pulse(d, s, [(30, 52), (42, 52), (48, 38), (56, 66), (63, 46), (68, 52), (76, 52)], 6)
    return _done(img, size)


def tab_handbook(size=128):
    """Handbook: an open book with a cross on the right page."""
    img, d, s = _canvas(size)
    d.polygon([(20 * s, 34 * s), (60 * s, 28 * s), (64 * s, 34 * s), (64 * s, 102 * s), (60 * s, 96 * s), (20 * s, 100 * s)], fill=CREAM)
    d.polygon([(108 * s, 34 * s), (68 * s, 28 * s), (64 * s, 34 * s), (64 * s, 102 * s), (68 * s, 96 * s), (108 * s, 100 * s)], fill=CREAM)
    d.line([(64 * s, 32 * s), (64 * s, 102 * s)], fill=(30, 70, 130, 255), width=int(3 * s))
    for y in (46, 58, 70, 82):
        d.line([(28 * s, y * s), (54 * s, (y - 2) * s)], fill=(150, 140, 130, 255), width=int(3 * s))
    d.rectangle([82 * s, 46 * s, 92 * s, 80 * s], fill=RED)
    d.rectangle([70 * s, 58 * s, 104 * s, 68 * s], fill=RED)
    return _done(img, size)


def pin_icon(pinned, size=64):
    """Window pin: upright (pinned) or tipped over (unpinned)."""
    from PIL import ImageDraw
    big = size * 4
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = big / 64.0
    col = CREAM if pinned else (175, 185, 200, 255)
    head = RED if pinned else (70, 110, 160, 255)
    d.ellipse([16 * s, 2 * s, 48 * s, 34 * s], fill=head, outline=(10, 20, 35, 255), width=int(2 * s))
    d.rectangle([25 * s, 30 * s, 39 * s, 38 * s], fill=col)
    d.polygon([(12 * s, 38 * s), (52 * s, 38 * s), (47 * s, 46 * s), (17 * s, 46 * s)], fill=col)
    d.polygon([(29 * s, 46 * s), (35 * s, 46 * s), (32 * s, 63 * s)], fill=col)
    if not pinned:
        img = img.rotate(45, resample=Image.BICUBIC, center=(big / 2, big / 2))
    return img.resize((size, size), Image.LANCZOS)


def _rot(pts, cx, cy, ang, s):
    """local (x, y) points -> rotated badge coordinates (scaled)."""
    import math
    c, n = math.cos(ang), math.sin(ang)
    return [((cx + x * c - y * n) * s, (cy + x * n + y * c) * s) for x, y in pts]


def tab_surgery(size=128):
    """Surgery (2026-10-11, owner: "เปลี่ยน icon ผ่าตัด"): a scalpel crossed
    with a hemostat (two finger rings, ratchet, jaws) -- the two instruments
    of every operation."""
    import math
    img, d, s = _canvas(size)
    steel = (190, 204, 222, 255)
    dark = (60, 86, 120, 255)
    # hemostat: handle rings lower-right, jaws upper-left
    cx, cy = 64, 64
    ang = -3 * math.pi / 4
    def H(pts): return _rot(pts, cx, cy, ang, s)
    for side in (-1, 1):
        # one arm: ring at the handle end, shank, jaw
        d.line(H([(-34, side * 9), (-8, side * 3), (4, 0)]), fill=steel, width=int(6 * s), joint="curve")
        d.line(H([(4, 0), (36, side * 1.5)]), fill=steel, width=int(5 * s))
        rx, ry = H([(-42, side * 13)])[0]
        rr = 9 * s
        d.ellipse([rx - rr, ry - rr, rx + rr, ry + rr], outline=steel, width=int(5 * s))
    # ratchet teeth and the box joint
    for t in range(3):
        d.line(H([(-24 + t * 4, -6), (-24 + t * 4, 6)]), fill=dark, width=int(2 * s))
    jx, jy = H([(4, 0)])[0]
    d.ellipse([jx - 5 * s, jy - 5 * s, jx + 5 * s, jy + 5 * s], fill=dark)
    # serrated jaws
    for t in range(5):
        d.line(H([(14 + t * 5, -3), (14 + t * 5, 3)]), fill=dark, width=int(2 * s))
    # scalpel crossing it: handle lower-left, blade upper-right
    ang2 = -math.pi / 4
    k = 1.05
    def R(pts): return _rot([(x * k, y * k) for x, y in pts], 66, 62, ang2, s)
    d.polygon(R([(-44, -5), (0, -5), (4, -3.5), (4, 3.5), (0, 5), (-44, 5), (-48, 2.5), (-48, -2.5)]), fill=CREAM, outline=dark)
    for gx in range(-40, -18, 5):
        d.line(R([(gx, -4), (gx, 4)]), fill=dark, width=int(2 * s))
    belly = [(4 + t * 32, 3.5 + 8 * math.sin(math.pi * t) - 3.5 * t) for t in [j / 12 for j in range(13)]]
    d.polygon(R([(4, -3.5), (32, -4.5), (38, -6)] + list(reversed(belly))), fill=RED, outline=dark)
    d.line(R([(6, -1.5), (32, -3)]), fill=(255, 255, 255, 255), width=int(2 * s))
    return _done(img, size)


def tab_meds(size=128):
    """Medication handbook: a two-tone capsule and a round tablet."""
    import math
    img, d, s = _canvas(size)
    ang = -math.pi / 4
    cx, cy = 58, 60
    r = 15
    def cap(x0, x1, col):
        pts = []
        for k in range(13):
            a = math.pi / 2 + math.pi * k / 12
            pts.append((x0 + r * math.cos(a), r * math.sin(a)))
        pts += [(x1, -r), (x1, r)]
        d.polygon(_rot(pts, cx, cy, ang, s), fill=col)
    cap(-24, 0, CREAM)
    # right half: mirror
    pts = [(24 + r * math.cos(-math.pi / 2 + math.pi * k / 12), r * math.sin(-math.pi / 2 + math.pi * k / 12)) for k in range(13)]
    pts += [(0, r), (0, -r)]
    d.polygon(_rot(pts, cx, cy, ang, s), fill=RED)
    d.line(_rot([(-22, -7), (18, -7)], cx, cy, ang, s), fill=(255, 255, 255, 170), width=int(3 * s))
    # round tablet with a score line
    d.ellipse([78 * s, 76 * s, 108 * s, 106 * s], fill=CREAM, outline=(70, 96, 130, 255), width=int(2 * s))
    d.line([(83 * s, 101 * s), (103 * s, 81 * s)], fill=(150, 160, 175, 255), width=int(3 * s))
    return _done(img, size)


def tab_guide(size=128):
    """Medical guide: a clipboard with lines and a blue "i" badge."""
    img, d, s = _canvas(size)
    d.rounded_rectangle([30 * s, 26 * s, 92 * s, 108 * s], radius=6 * s, fill=CREAM)
    d.rounded_rectangle([46 * s, 18 * s, 76 * s, 34 * s], radius=4 * s, fill=(150, 160, 175, 255))
    for y in (50, 64, 78, 92):
        d.line([(40 * s, y * s), (70 * s, y * s)], fill=(150, 140, 130, 255), width=int(4 * s))
    d.ellipse([70 * s, 66 * s, 108 * s, 104 * s], fill=RED, outline=(12, 22, 36, 255), width=int(3 * s))
    d.ellipse([86 * s, 72 * s, 92 * s, 78 * s], fill=(255, 255, 255, 255))
    d.rectangle([86 * s, 82 * s, 92 * s, 98 * s], fill=(255, 255, 255, 255))
    return _done(img, size)


TABS = {"tab_ehr": tab_ehr, "tab_immunity": tab_immunity, "tab_stats": tab_stats,
        "tab_diagnosis": tab_diagnosis, "tab_handbook": tab_handbook, "tab_surgery": tab_surgery,
        "tab_meds": tab_meds, "tab_guide": tab_guide}


# R71 ("เปลี่ยนจากคำในปุ่มเป็นสัญลักษณ์ ... เพิ่มปุ่มตั้งค่า"): glyphs of the
# small buttons and the settings window (cream; the check mark blue)
def ui_icon(name, draw, size=64):
    from PIL import ImageDraw
    big = size * 4
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw(ImageDraw.Draw(img), big / 64.0)
    img.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def g_close(d, s):
    w = int(7 * s)
    d.line([(16 * s, 16 * s), (48 * s, 48 * s)], fill=CREAM, width=w)
    d.line([(48 * s, 16 * s), (16 * s, 48 * s)], fill=CREAM, width=w)


def g_settings(d, s):
    import math
    cx = cy = 32 * s
    for i in range(8):
        a = i * math.pi / 4
        pts = [(cx + math.cos(a + da) * r * s, cy + math.sin(a + da) * r * s)
               for da, r in ((-0.22, 20), (-0.16, 27), (0.16, 27), (0.22, 20))]
        d.polygon(pts, fill=CREAM)
    d.ellipse([cx - 20 * s, cy - 20 * s, cx + 20 * s, cy + 20 * s], fill=CREAM)
    d.ellipse([cx - 8 * s, cy - 8 * s, cx + 8 * s, cy + 8 * s], fill=(0, 0, 0, 0))


def g_left(d, s):
    d.polygon([(42 * s, 14 * s), (42 * s, 50 * s), (18 * s, 32 * s)], fill=CREAM)


def g_right(d, s):
    d.polygon([(22 * s, 14 * s), (22 * s, 50 * s), (46 * s, 32 * s)], fill=CREAM)


def g_check(d, s):
    d.line([(14 * s, 34 * s), (27 * s, 47 * s), (51 * s, 18 * s)], fill=RED, width=int(8 * s), joint="curve")


def g_minus(d, s):
    d.rectangle([14 * s, 28 * s, 50 * s, 36 * s], fill=CREAM)


def g_plus(d, s):
    d.rectangle([14 * s, 28 * s, 50 * s, 36 * s], fill=CREAM)
    d.rectangle([28 * s, 14 * s, 36 * s, 50 * s], fill=CREAM)


ICONS = {"icon_close": g_close, "icon_settings": g_settings, "icon_left": g_left, "icon_right": g_right,
         "icon_check": g_check, "icon_minus": g_minus, "icon_plus": g_plus}


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    disc().save(os.path.join(OUT, "surg_dot.png"))
    disc(inner=N / 2 - 9).save(os.path.join(OUT, "surg_ring.png"))
    for name, fn in TABS.items():
        fn().save(os.path.join(OUT, name + ".png"))
    pin_icon(True).save(os.path.join(OUT, "pin_on.png"))
    pin_icon(False).save(os.path.join(OUT, "pin_off.png"))
    for name, fn in ICONS.items():
        ui_icon(name, fn)
    print("wrote", OUT)
