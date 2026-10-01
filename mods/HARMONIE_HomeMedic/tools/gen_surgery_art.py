#!/usr/bin/env python3
"""HARMONIE - Home Medic: the surgery minigames' art (our own, procedural).

Writes 42/media/textures/HARMONIE_HomeMedic/surg/*.png:
  field_skin    operative field: skin with pores, faint veins, Betadine stain
  drape         surgical drape (blue-green cotton weave), tiles
  tissue        wound bed: wet red muscle fibres with fat globules
  organ         glossy liver-like organ surface
  necro         necrotic crust (black-brown, cracked)
  fat           yellow fat lobules
  bone          bone cross-section (cortex + spongy marrow)
  skull         skull surface (curved bone, sutures)
  dish          petri dish with culture medium
  cell          one stem cell (translucent, nucleus), white for tinting
  blood         blood blob (alpha), white-ish for tinting by code
  drop          small blood drop
  splash        water splash
  vignette      OR-lamp light pool (dark edges), drawn over the field
  vein          a vein seen through skin (horizontal strip, alpha)
  wound         an open incision (horizontal; skin edge, fat, muscle)
  thread        surgical thread strand (horizontal, blue nylon)
  debris1..4    dirt / gravel / grass bits
  bullet, glass, worm, clot   foreign bodies
  tool_scalpel, tool_hemostat, tool_needle, tool_forceps, tool_syringe,
  tool_suction, tool_saw, tool_drill, tool_pipette, tool_catheter, tool_curette
              instruments, drawn pointing to the RIGHT with the working tip
              at the right edge middle (the code rotates them about the tip)
Run:  python mods/HARMONIE_HomeMedic/tools/gen_surgery_art.py
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "42", "media", "textures", "HARMONIE_HomeMedic", "surg")
RNG = np.random.default_rng(1337)


# ---------------------------------------------------------------- noise
def value_noise(w, h, cell, seed=0, tile=True):
    rng = np.random.default_rng(seed)
    gw, gh = max(1, w // cell), max(1, h // cell)
    grid = rng.random((gh + 1, gw + 1))
    if tile:
        grid[-1, :] = grid[0, :]
        grid[:, -1] = grid[:, 0]
    ys = np.linspace(0, gh, h, endpoint=False)
    xs = np.linspace(0, gw, w, endpoint=False)
    y0 = np.floor(ys).astype(int); x0 = np.floor(xs).astype(int)
    fy = ys - y0; fx = xs - x0
    fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
    a = grid[y0][:, x0]; b = grid[y0][:, x0 + 1]
    c = grid[y0 + 1][:, x0]; d = grid[y0 + 1][:, x0 + 1]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]


def fbm(w, h, base=64, octaves=5, seed=0):
    out = np.zeros((h, w)); amp = 1.0; tot = 0
    cell = base
    for o in range(octaves):
        out += value_noise(w, h, max(2, cell), seed + o * 17) * amp
        tot += amp; amp *= 0.5; cell //= 2
    return out / tot


def to_img(rgb, alpha=None):
    rgb = np.clip(rgb, 0, 1)
    if alpha is None:
        alpha = np.ones(rgb.shape[:2])
    arr = np.dstack([rgb, np.clip(alpha, 0, 1)])
    return Image.fromarray((arr * 255).astype(np.uint8), "RGBA")


def mix(c1, c2, t):
    c1 = np.array(c1, float); c2 = np.array(c2, float)
    return c1[None, None, :] * (1 - t[..., None]) + c2[None, None, :] * t[..., None]


def radial(w, h, cx=0.5, cy=0.5, rx=0.5, ry=0.5):
    y, x = np.mgrid[0:h, 0:w]
    return np.sqrt(((x / w - cx) / rx) ** 2 + ((y / h - cy) / ry) ** 2)


def save(img, name):
    img.save(os.path.join(OUT, name + ".png"))


# ---------------------------------------------------------------- surfaces
def field_skin(w=512, h=320):
    n = fbm(w, h, 96, 5, 1)
    skin = mix((0.86, 0.66, 0.56), (0.76, 0.54, 0.45), n)
    # pores and fine grain
    pores = RNG.random((h, w)) > 0.985
    skin[pores] *= 0.88
    grain = (RNG.random((h, w)) - 0.5) * 0.035
    skin += grain[..., None]
    # faint blue veins
    v = fbm(w, h, 128, 3, 7)
    veins = np.exp(-((v - 0.5) ** 2) / 0.0006)
    skin = skin * (1 - 0.10 * veins[..., None]) + np.array([0.45, 0.5, 0.7]) * 0.10 * veins[..., None]
    # Betadine (povidone-iodine) prep stain: orange-brown, patchy, stronger in the middle
    r = radial(w, h, 0.5, 0.5, 0.48, 0.55)
    stain = np.clip(1.15 - r, 0, 1) * (0.55 + 0.45 * fbm(w, h, 48, 4, 9))
    skin = skin * (1 - 0.55 * stain[..., None]) + np.array([0.62, 0.30, 0.10]) * 0.55 * stain[..., None]
    return to_img(skin)


def drape(s=256):
    y, x = np.mgrid[0:s, 0:s]
    weave = 0.5 + 0.25 * np.sin(x * math.pi / 2) * np.sin(y * math.pi / 2)
    n = fbm(s, s, 64, 4, 3)
    base = mix((0.20, 0.42, 0.46), (0.14, 0.33, 0.38), n * 0.8 + weave * 0.2)
    base += ((RNG.random((s, s)) - 0.5) * 0.04)[..., None]
    return to_img(base)


def tissue(s=256, seed=4):
    """wet muscle: domain-warped fibres, dark crevices, fat, highlights"""
    y, x = np.mgrid[0:s, 0:s].astype(float)
    wx = (fbm(s, s, 96, 4, seed + 1) - 0.5) * 70
    wy = (fbm(s, s, 96, 4, seed + 2) - 0.5) * 30
    fib = 0.5 + 0.5 * np.sin((y + wy) * 0.32 + (x + wx) * 0.05 + fbm(s, s, 48, 3, seed) * 4)
    fib = fib ** 1.6
    n = fbm(s, s, 64, 5, seed)
    col = mix((0.36, 0.03, 0.04), (0.66, 0.12, 0.11), np.clip(fib * 0.45 + n * 0.55, 0, 1))
    crev = np.exp(-((fbm(s, s, 40, 3, seed + 5) - 0.5) ** 2) / 0.004)
    col *= (1 - 0.22 * crev)[..., None]
    g = fbm(s, s, 32, 3, seed + 11)
    fatm = np.clip((g - 0.70) * 5, 0, 1)
    col = col * (1 - fatm[..., None]) + np.array([0.90, 0.76, 0.40]) * fatm[..., None]
    spec = np.clip((fbm(s, s, 12, 2, seed + 21) - 0.74) * 5, 0, 1)
    col += spec[..., None] * 0.30
    return to_img(col)


def bed(inner_img, w=512, h=320, seed=111):
    """an oval wound opening: retracted skin rim, ragged edge, the inner
    surface inside, transparent outside (drawn over the prepped skin)"""
    inner = np.array(inner_img.convert("RGB").resize((w, h), Image.BICUBIC)).astype(float) / 255
    r = radial(w, h, 0.5, 0.5, 0.47, 0.44)
    rag = (fbm(w, h, 24, 3, seed) - 0.5) * 0.12
    rr = r + rag
    alpha = np.clip((1.0 - rr) * 30, 0, 1)
    rim = np.exp(-((rr - 0.94) ** 2) / 0.0012)
    fatring = np.exp(-((rr - 0.87) ** 2) / 0.0020)
    shade = np.clip(1 - (rr - 0.6) * 1.2, 0.55, 1)          # depth: darker toward the edge
    col = inner * shade[..., None]
    col = col * (1 - 0.8 * fatring[..., None]) + np.array([0.93, 0.80, 0.45]) * 0.8 * fatring[..., None]
    col = col * (1 - rim[..., None]) + np.array([0.80, 0.47, 0.40]) * rim[..., None]
    return to_img(col, alpha)


def patch(tex_img, s=128, seed=121, tint=None):
    """an irregular patch of a texture (blob alpha)"""
    base = np.array(tex_img.convert("RGB").resize((s, s), Image.BICUBIC)).astype(float) / 255
    if tint is not None:
        base = base * np.array(tint)
    y, x = np.mgrid[0:s, 0:s]
    ang = np.arctan2(y - s / 2, x - s / 2)
    rad = np.sqrt((x - s / 2) ** 2 + (y - s / 2) ** 2) / (s / 2)
    rng = np.random.default_rng(seed)
    wob = 0.78 + sum(rng.random() * 0.07 * np.sin(k * ang + rng.random() * 6) for k in range(2, 8))
    wob = wob + (fbm(s, s, 16, 2, seed) - 0.5) * 0.15
    alpha = np.clip((wob - rad) * 9, 0, 1)
    return to_img(base, alpha)


def track(s=64):
    """a wet hole seen from above: dark centre, glistening rim"""
    r = radial(s, s)
    col = mix((0.10, 0.01, 0.02), (0.45, 0.05, 0.06), np.clip(r * 1.1, 0, 1))
    alpha = np.clip((1 - r) * 4, 0, 1)
    return to_img(col, alpha)


def organ(s=256):
    n = fbm(s, s, 96, 5, 31)
    col = mix((0.36, 0.06, 0.08), (0.56, 0.14, 0.14), n)
    lob = fbm(s, s, 20, 2, 33)
    col *= (0.9 + 0.12 * lob)[..., None]
    spec = np.clip((fbm(s, s, 40, 3, 35) - 0.66) * 4, 0, 1)
    col += spec[..., None] * np.array([0.45, 0.38, 0.38])
    return to_img(col)


def necro(s=256):
    n = fbm(s, s, 48, 5, 41)
    col = mix((0.07, 0.05, 0.04), (0.30, 0.20, 0.10), n)
    cracks = fbm(s, s, 32, 3, 43)
    line = np.exp(-((cracks - 0.5) ** 2) / 0.0008)
    col *= (1 - 0.6 * line)[..., None]
    slough = np.clip((fbm(s, s, 24, 2, 45) - 0.68) * 5, 0, 1)
    col = col * (1 - slough[..., None]) + np.array([0.62, 0.56, 0.30]) * slough[..., None]
    return to_img(col)


def fat(s=256):
    n = fbm(s, s, 20, 3, 51)
    col = mix((0.95, 0.83, 0.48), (0.84, 0.66, 0.30), n)
    edges = np.exp(-((fbm(s, s, 22, 2, 53) - 0.5) ** 2) / 0.0012)
    col = col * (1 - 0.35 * edges[..., None]) + np.array([0.75, 0.25, 0.20]) * 0.35 * edges[..., None]
    return to_img(col)


def bone(s=256):
    r = radial(s, s)
    n = fbm(s, s, 12, 3, 61)
    spongy = mix((0.62, 0.30, 0.22), (0.90, 0.80, 0.62), n)
    cortex = np.array([0.93, 0.89, 0.78])
    ring = np.clip((r - 0.62) * 12, 0, 1)
    col = spongy * (1 - ring[..., None]) + cortex * ring[..., None]
    alpha = np.clip((0.98 - r) * 40, 0, 1)
    return to_img(col, alpha)


def skull(w=512, h=256):
    n = fbm(w, h, 64, 5, 71)
    col = mix((0.86, 0.80, 0.68), (0.95, 0.91, 0.80), n)
    y, x = np.mgrid[0:h, 0:w]
    suture = np.abs(y - h * 0.5 - np.sin(x * 0.12) * 6 - np.sin(x * 0.37) * 3) < 1.6
    col[suture] *= 0.55
    shade = 1 - 0.35 * (np.abs(y / h - 0.45) ** 1.5)
    col *= shade[..., None]
    return to_img(col)


def dish(s=384):
    r = radial(s, s)
    n = fbm(s, s, 64, 4, 81)
    col = mix((0.84, 0.36, 0.42), (0.93, 0.55, 0.58), n)  # pink culture medium
    rim = np.clip((r - 0.9) * 30, 0, 1)
    col = col * (1 - rim[..., None]) + np.array([0.86, 0.90, 0.95]) * rim[..., None]
    alpha = np.clip((1.0 - r) * 40, 0, 1)
    glare = np.clip(1 - radial(s, s, 0.35, 0.3, 0.18, 0.08), 0, 1) * 0.35
    col += glare[..., None]
    return to_img(col, alpha)


def cell(s=96):
    r = radial(s, s)
    body = np.clip((1 - r) * 6, 0, 1)
    nuc = np.clip((0.35 - radial(s, s, 0.52, 0.48, 0.5, 0.5)) * 10, 0, 1)
    col = np.ones((s, s, 3)) * 0.92
    col -= nuc[..., None] * 0.55
    edge = np.exp(-((r - 0.86) ** 2) / 0.004)
    col -= edge[..., None] * 0.35
    alpha = body * (0.55 + 0.45 * np.maximum(nuc, edge))
    return to_img(col, alpha)


def blob(s=128, seed=91, soft=8.0):
    y, x = np.mgrid[0:s, 0:s]
    ang = np.arctan2(y - s / 2, x - s / 2)
    rad = np.sqrt((x - s / 2) ** 2 + (y - s / 2) ** 2) / (s / 2)
    rng = np.random.default_rng(seed)
    wob = 0.75 + sum(rng.random() * 0.08 * np.sin(k * ang + rng.random() * 6) for k in range(2, 7))
    alpha = np.clip((wob - rad) * soft, 0, 1)
    shade = 0.75 + 0.25 * (1 - rad)
    col = np.ones((s, s, 3)) * shade[..., None]
    spec = np.clip(1 - radial(s, s, 0.38, 0.34, 0.14, 0.09), 0, 1)
    col += spec[..., None] * 0.6
    return to_img(col, alpha)


def vignette(w=512, h=320):
    r = radial(w, h, 0.5, 0.5, 0.62, 0.66)
    alpha = np.clip((r - 0.55) * 1.6, 0, 0.85)
    return to_img(np.zeros((h, w, 3)), alpha)


def vein(w=512, h=48):
    y, x = np.mgrid[0:h, 0:w]
    d = np.abs(y - h / 2) / (h / 2)
    alpha = np.clip(1 - d, 0, 1) ** 1.5 * 0.75
    col = mix((0.25, 0.30, 0.55), (0.40, 0.42, 0.70), np.clip(1 - d, 0, 1))
    return to_img(col, alpha)


def wound(w=512, h=64):
    y, x = np.mgrid[0:h, 0:w]
    d = np.abs(y - h / 2) / (h / 2)
    n = fbm(w, h, 16, 3, 101)
    layers = np.zeros((h, w, 3))
    muscle = np.array([0.50, 0.04, 0.05]) * (0.8 + 0.4 * n[..., None])
    fatc = np.array([0.95, 0.82, 0.45]) * (0.85 + 0.2 * n[..., None])
    skin_edge = np.array([0.78, 0.40, 0.36])
    t1 = np.clip((d - 0.45) * 8, 0, 1)
    t2 = np.clip((d - 0.78) * 10, 0, 1)
    layers = muscle * (1 - t1[..., None]) + fatc * t1[..., None]
    layers = layers * (1 - t2[..., None]) + skin_edge * t2[..., None]
    taper = np.clip(np.minimum(x, w - x) / (w * 0.08), 0, 1)
    alpha = np.clip((1 - d / np.maximum(taper, 0.05)) * 6, 0, 1)
    return to_img(layers, alpha)


def thread(w=128, h=8):
    y = np.mgrid[0:h, 0:w][0]
    d = np.abs(y - h / 2) / (h / 2)
    col = mix((0.10, 0.22, 0.50), (0.35, 0.55, 0.95), np.clip(1 - d, 0, 1))
    return to_img(col, np.clip((1 - d) * 3, 0, 1))


def debris(i, s=96):
    if True:
        piece = blob(s, 200 + i, soft=6)
        arr = np.array(piece).astype(float) / 255
        tint = [np.array([0.45, 0.40, 0.30]), np.array([0.35, 0.33, 0.30]), np.array([0.30, 0.42, 0.18]), np.array([0.50, 0.46, 0.38])][i]
        noise = fbm(s, s, 8, 2, 300 + i)
        arr[..., :3] = tint * (0.7 + 0.6 * noise[..., None]) * arr[..., :3]
        return Image.fromarray((arr * 255).astype(np.uint8), "RGBA")


def bullet(s=96):
    img = Image.new("RGBA", (s * 4, s * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    S = s * 4 / 96
    d.rounded_rectangle([20 * S, 34 * S, 66 * S, 62 * S], radius=4 * S, fill=(150, 112, 50, 255))
    d.ellipse([52 * S, 34 * S, 84 * S, 62 * S], fill=(120, 90, 70, 255))
    d.rectangle([52 * S, 34 * S, 66 * S, 62 * S], fill=(120, 90, 70, 255))
    d.line([(24 * S, 38 * S), (62 * S, 38 * S)], fill=(220, 190, 120, 255), width=int(3 * S))
    return img.resize((s, s), Image.LANCZOS)


def glass(s=96):
    img = Image.new("RGBA", (s * 4, s * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    S = s * 4 / 96
    pts = [(20 * S, 60 * S), (40 * S, 18 * S), (70 * S, 30 * S), (78 * S, 70 * S), (44 * S, 80 * S)]
    d.polygon(pts, fill=(190, 230, 235, 150), outline=(240, 255, 255, 230))
    d.line([(40 * S, 22 * S), (52 * S, 70 * S)], fill=(255, 255, 255, 200), width=int(3 * S))
    return img.resize((s, s), Image.LANCZOS)


def worm(w=160, h=64):
    img = Image.new("RGBA", (w * 4, h * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    S = 4
    pts = [(10 + i * 7, 32 + math.sin(i * 0.7) * 12) for i in range(21)]
    for k, (x, y) in enumerate(pts):
        rad = 9 - abs(k - 10) * 0.45
        d.ellipse([(x - rad) * S, (y - rad) * S, (x + rad) * S, (y + rad) * S], fill=(232, 220, 196, 255))
    for k, (x, y) in enumerate(pts[::2]):
        d.arc([(x - 6) * S, (y - 8) * S, (x + 6) * S, (y + 8) * S], 300, 60, fill=(170, 150, 120, 255), width=S * 2)
    return img.resize((w, h), Image.LANCZOS)


# ---------------------------------------------------------------- instruments
def _tool_canvas(w, h):
    big = Image.new("RGBA", (w * 4, h * 4), (0, 0, 0, 0))
    return big, ImageDraw.Draw(big), 4


STEEL = (196, 204, 214, 255)
STEEL_D = (120, 128, 140, 255)
STEEL_L = (236, 240, 246, 255)


def _steel_bar(d, S, x1, y1, x2, y2, w):
    d.line([(x1 * S, y1 * S), (x2 * S, y2 * S)], fill=STEEL_D, width=int((w + 1) * S))
    d.line([(x1 * S, y1 * S), (x2 * S, y2 * S)], fill=STEEL, width=int(w * S))
    d.line([(x1 * S, (y1 - w * 0.25) * S), (x2 * S, (y2 - w * 0.25) * S)], fill=STEEL_L, width=max(1, int(w * 0.3 * S)))


def tool_scalpel(w=160, h=40):
    img, d, S = _tool_canvas(w, h)
    d.rounded_rectangle([4 * S, 14 * S, 92 * S, 26 * S], radius=4 * S, fill=STEEL_D)
    d.rounded_rectangle([5 * S, 15 * S, 91 * S, 24 * S], radius=4 * S, fill=STEEL)
    for i in range(10, 80, 8):
        d.line([(i * S, 16 * S), ((i + 3) * S, 23 * S)], fill=STEEL_D, width=S)
    d.polygon([(92 * S, 15 * S), (150 * S, 18 * S), (159 * S, 20 * S), (140 * S, 27 * S), (92 * S, 25 * S)], fill=STEEL_L, outline=STEEL_D)
    return img.resize((w, h), Image.LANCZOS)


def tool_hemostat(w=160, h=60):
    img, d, S = _tool_canvas(w, h)
    for dy in (-1, 1):
        d.ellipse([4 * S, (30 + dy * 14 - 9) * S, 22 * S, (30 + dy * 14 + 9) * S], outline=STEEL_D, width=3 * S)
        _steel_bar(d, S, 20, 30 + dy * 13, 92, 30 + dy * 2, 4)
        _steel_bar(d, S, 92, 30 + dy * 2, 158, 30 + dy * 0.5, 3)
    d.ellipse([88 * S, 26 * S, 98 * S, 34 * S], fill=STEEL_D)
    return img.resize((w, h), Image.LANCZOS)


def tool_needle(w=160, h=60):
    img, d, S = _tool_canvas(w, h)
    for dy in (-1, 1):
        d.ellipse([4 * S, (30 + dy * 14 - 9) * S, 22 * S, (30 + dy * 14 + 9) * S], outline=(200, 170, 70, 255), width=3 * S)
        _steel_bar(d, S, 20, 30 + dy * 13, 100, 30 + dy * 2, 4)
    _steel_bar(d, S, 100, 30, 132, 30, 5)
    d.arc([128 * S, 16 * S, 158 * S, 44 * S], 270, 90, fill=STEEL_L, width=2 * S)   # curved needle
    d.line([(143 * S, 44 * S), (100 * S, 58 * S)], fill=(60, 110, 220, 255), width=S * 2)  # thread
    return img.resize((w, h), Image.LANCZOS)


def tool_forceps(w=160, h=40):
    img, d, S = _tool_canvas(w, h)
    _steel_bar(d, S, 6, 20, 156, 16, 5)
    _steel_bar(d, S, 6, 20, 156, 24, 5)
    for i in range(30, 70, 6):
        d.line([(i * S, 13 * S), (i * S, 27 * S)], fill=STEEL_D, width=S)
    return img.resize((w, h), Image.LANCZOS)


def tool_syringe(w=160, h=40):
    img, d, S = _tool_canvas(w, h)
    d.rectangle([2 * S, 8 * S, 8 * S, 32 * S], fill=STEEL_D)
    d.rectangle([8 * S, 17 * S, 36 * S, 23 * S], fill=STEEL)
    d.rounded_rectangle([34 * S, 10 * S, 120 * S, 30 * S], radius=3 * S, fill=(220, 236, 245, 170), outline=(150, 170, 190, 255), width=S)
    d.rectangle([60 * S, 12 * S, 118 * S, 28 * S], fill=(150, 200, 235, 150))
    for i in range(44, 118, 10):
        d.line([(i * S, 10 * S), (i * S, 15 * S)], fill=(90, 110, 130, 255), width=S)
    d.polygon([(120 * S, 14 * S), (130 * S, 18 * S), (130 * S, 22 * S), (120 * S, 26 * S)], fill=(150, 170, 190, 255))
    d.line([(130 * S, 20 * S), (158 * S, 20 * S)], fill=STEEL_L, width=S * 2)
    return img.resize((w, h), Image.LANCZOS)


def tool_suction(w=160, h=40):
    img, d, S = _tool_canvas(w, h)
    d.line([(2 * S, 30 * S), (40 * S, 22 * S)], fill=(210, 230, 240, 200), width=S * 9)
    d.rounded_rectangle([36 * S, 14 * S, 100 * S, 28 * S], radius=6 * S, fill=STEEL, outline=STEEL_D)
    _steel_bar(d, S, 100, 21, 150, 19, 6)
    d.ellipse([146 * S, 14 * S, 158 * S, 24 * S], fill=STEEL_D)
    return img.resize((w, h), Image.LANCZOS)


def tool_saw(w=180, h=70):
    img, d, S = _tool_canvas(w, h)
    d.rounded_rectangle([2 * S, 24 * S, 52 * S, 46 * S], radius=8 * S, fill=(40, 52, 70, 255))
    d.rectangle([52 * S, 30 * S, 70 * S, 40 * S], fill=STEEL_D)
    d.rectangle([70 * S, 22 * S, 172 * S, 48 * S], fill=STEEL)
    for i in range(72, 172, 6):
        d.polygon([(i * S, 48 * S), ((i + 3) * S, 54 * S), ((i + 6) * S, 48 * S)], fill=STEEL_D)
    d.line([(72 * S, 25 * S), (170 * S, 25 * S)], fill=STEEL_L, width=S * 2)
    return img.resize((w, h), Image.LANCZOS)


def tool_drill(w=180, h=70):
    img, d, S = _tool_canvas(w, h)
    d.rounded_rectangle([2 * S, 16 * S, 96 * S, 52 * S], radius=10 * S, fill=(214, 220, 228, 255), outline=STEEL_D, width=S * 2)
    d.rectangle([20 * S, 52 * S, 44 * S, 68 * S], fill=(190, 196, 204, 255))
    d.rectangle([96 * S, 28 * S, 118 * S, 40 * S], fill=STEEL_D)
    d.polygon([(118 * S, 30 * S), (172 * S, 33 * S), (178 * S, 34 * S), (172 * S, 35 * S), (118 * S, 38 * S)], fill=STEEL)
    for i in range(122, 170, 7):
        d.line([(i * S, 30 * S), ((i + 4) * S, 38 * S)], fill=STEEL_D, width=S)
    return img.resize((w, h), Image.LANCZOS)


def tool_pipette(w=160, h=40):
    img, d, S = _tool_canvas(w, h)
    d.rounded_rectangle([2 * S, 10 * S, 34 * S, 30 * S], radius=8 * S, fill=(70, 120, 200, 255))
    d.rectangle([34 * S, 16 * S, 120 * S, 24 * S], fill=(230, 236, 240, 200), outline=(160, 170, 180, 255))
    d.polygon([(120 * S, 16 * S), (158 * S, 19 * S), (158 * S, 21 * S), (120 * S, 24 * S)], fill=(230, 236, 240, 220))
    return img.resize((w, h), Image.LANCZOS)


def tool_catheter(w=160, h=40):
    img, d, S = _tool_canvas(w, h)
    d.line([(2 * S, 20 * S), (40 * S, 20 * S)], fill=(240, 240, 240, 220), width=S * 6)
    d.rounded_rectangle([40 * S, 12 * S, 70 * S, 28 * S], radius=3 * S, fill=(80, 170, 90, 255))
    d.rectangle([70 * S, 17 * S, 120 * S, 23 * S], fill=(230, 236, 240, 210))
    _steel_bar(d, S, 120, 20, 158, 20, 2)
    return img.resize((w, h), Image.LANCZOS)


def tool_curette(w=160, h=40):
    img, d, S = _tool_canvas(w, h)
    d.rounded_rectangle([4 * S, 14 * S, 84 * S, 26 * S], radius=5 * S, fill=STEEL, outline=STEEL_D)
    _steel_bar(d, S, 84, 20, 146, 20, 3)
    d.ellipse([142 * S, 12 * S, 158 * S, 28 * S], outline=STEEL_D, width=S * 3)
    return img.resize((w, h), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    save(field_skin(), "field_skin")
    save(drape(), "drape")
    t = tissue()
    save(t, "tissue")
    save(bed(t), "wound_bed")
    o = organ()
    save(o, "organ")
    save(bed(o, seed=113), "organ_bed")
    nc = necro()
    save(nc, "necro")
    save(patch(nc, 128, 121), "necro_patch")
    save(patch(t, 128, 123, tint=(1.35, 0.8, 0.8)), "raw_patch")
    save(track(), "track")
    save(fat(), "fat")
    save(bone(), "bone")
    save(skull(), "skull")
    save(dish(), "dish")
    save(cell(), "cell")
    save(blob(128, 91), "blood")
    save(blob(48, 93, soft=10), "drop")
    save(blob(96, 95, soft=4), "splash")
    save(vignette(), "vignette")
    save(vein(), "vein")
    save(wound(), "wound")
    save(thread(), "thread")
    for i in range(4):
        save(debris(i), "debris%d" % (i + 1))
    save(bullet(), "bullet")
    save(glass(), "glass")
    save(worm(), "worm")
    save(blob(96, 97, soft=7), "clot")
    for name, fn in (("tool_scalpel", tool_scalpel), ("tool_hemostat", tool_hemostat), ("tool_needle", tool_needle),
                     ("tool_forceps", tool_forceps), ("tool_syringe", tool_syringe), ("tool_suction", tool_suction),
                     ("tool_saw", tool_saw), ("tool_drill", tool_drill), ("tool_pipette", tool_pipette),
                     ("tool_catheter", tool_catheter), ("tool_curette", tool_curette)):
        save(fn(), name)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
