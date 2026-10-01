#!/usr/bin/env python3
"""HARMONIE - Home Medic: the surgery minigames' two textures (our own art).

Writes 42/media/textures/HARMONIE_HomeMedic/surg_dot.png (filled circle) and
surg_ring.png (ring), white on transparent, antialiased, 128 px -- the games
tint and scale them (HM_SurgeryGames.lua) -- and tab_*.png, the
medical window's five tab icons (one badge style: monitor, immunity, stats,
diagnosis, handbook) -- and pin_on.png / pin_off.png, the windows' pin button.
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


def tab_surgery(size=128):
    """Surgery: a scalpel over a stitched incision."""
    img, d, s = _canvas(size)
    d.line([(26 * s, 96 * s), (100 * s, 96 * s)], fill=RED, width=int(6 * s))
    for x in range(34, 100, 14):
        d.line([(x * s, 88 * s), ((x + 6) * s, 104 * s)], fill=CREAM, width=int(4 * s))
    d.polygon([(30 * s, 70 * s), (78 * s, 22 * s), (90 * s, 30 * s), (46 * s, 74 * s)], fill=(200, 210, 225, 255))
    d.polygon([(78 * s, 22 * s), (104 * s, 12 * s), (96 * s, 38 * s), (90 * s, 30 * s)], fill=CREAM)
    d.line([(46 * s, 74 * s), (30 * s, 70 * s)], fill=(120, 140, 170, 255), width=int(3 * s))
    return _done(img, size)


TABS = {"tab_ehr": tab_ehr, "tab_immunity": tab_immunity, "tab_stats": tab_stats,
        "tab_diagnosis": tab_diagnosis, "tab_handbook": tab_handbook, "tab_surgery": tab_surgery}


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    disc().save(os.path.join(OUT, "surg_dot.png"))
    disc(inner=N / 2 - 9).save(os.path.join(OUT, "surg_ring.png"))
    for name, fn in TABS.items():
        fn().save(os.path.join(OUT, name + ".png"))
    pin_icon(True).save(os.path.join(OUT, "pin_on.png"))
    pin_icon(False).save(os.path.join(OUT, "pin_off.png"))
    print("wrote", OUT)
