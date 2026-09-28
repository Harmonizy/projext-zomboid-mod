#!/usr/bin/env python3
"""Draws Item_TWA_MaterialLump.png (32x32): a rough, roundish lump of raw
iron -- round-9 follow-up request "รูปก้อนวัตถุดิบไม่ขึ้น สร้างรูปเองเลยได้ไหม
เป็นก้อนกลมๆสีเหล็กหยาบๆ". Drawn from scratch (no third-party art): an
irregular blob, lit from the top-left, with bumps, pits and speckle.
Rendered 8x larger and scaled down for clean edges. Needs Pillow."""
import math, os, random
from PIL import Image, ImageFilter

S, N = 32, 8
W = S * N
rnd = random.Random(7)
img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
px = img.load()
cx, cy = W * 0.5, W * 0.54
R = W * 0.40

# Irregular outline: radius wobbles with a few low-frequency harmonics.
harm = [(k, rnd.uniform(0.02, 0.07) / (k * 0.6), rnd.uniform(0, 6.28)) for k in range(2, 7)]
def radius(a):
    r = 1.0
    for k, amp, ph in harm:
        r += amp * math.sin(k * a + ph)
    return R * r * (0.92 if math.sin(a) < 0 else 1.0)   # a little flatter on top

# Bumps (raised) and pits (sunken) on the surface.
bumps = [(rnd.uniform(-0.8, 0.8), rnd.uniform(-0.8, 0.8), rnd.uniform(0.10, 0.26), rnd.choice([1, 1, -1]))
         for _ in range(34)]

light = (-0.45, -0.55, 0.75)
ln = math.sqrt(sum(v * v for v in light)); light = tuple(v / ln for v in light)

for y in range(W):
    for x in range(W):
        dx, dy = x - cx, y - cy
        a = math.atan2(dy, dx)
        rr = radius(a)
        d = math.sqrt(dx * dx + dy * dy)
        if d > rr:
            continue
        u, v = dx / rr, dy / rr
        z = math.sqrt(max(0.0, 1 - u * u - v * v))
        nx, ny, nz = u, v, z
        # Bumps tilt the normal.
        for bx, by, br, sgn in bumps:
            ddx, ddy = u - bx, v - by
            q = (ddx * ddx + ddy * ddy) / (br * br)
            if q < 1:
                f = sgn * 0.9 * (1 - q)
                nx += ddx / br * f
                ny += ddy / br * f
        n = math.sqrt(nx * nx + ny * ny + nz * nz)
        nx, ny, nz = nx / n, ny / n, nz / n
        diff = max(0.0, nx * light[0] + ny * light[1] + nz * light[2])
        # Iron: dark blue-grey, a dull metallic sheen, rough speckle.
        spec = max(0.0, nz * 0.9 + nx * -0.3 + ny * -0.3) ** 12 * 0.35
        base = 0.28 + 0.55 * diff + spec
        grain = rnd.uniform(-0.07, 0.07)
        edge = min(1.0, (rr - d) / (W * 0.03))          # darker rim
        k = max(0.0, min(1.0, (base + grain) * (0.55 + 0.45 * edge)))
        r_, g_, b_ = 92 + 130 * k, 96 + 130 * k, 104 + 132 * k
        # A touch of rust-brown in the deepest shade.
        if diff < 0.06 and rnd.random() < 0.5:
            r_, g_, b_ = r_ * 0.9 + 14, g_ * 0.88 + 4, b_ * 0.84
        px[x, y] = (int(min(255, r_ * 0.62)), int(min(255, g_ * 0.62)), int(min(255, b_ * 0.62)), 255)

# Dark outline so it reads on any inventory background.
alpha = img.split()[3]
outline = alpha.filter(ImageFilter.MaxFilter(2 * N + 1))
bg = Image.new("RGBA", (W, W), (22, 22, 26, 0))
bg.putalpha(outline)
bg.alpha_composite(img)
out = bg.resize((S, S), Image.LANCZOS)
here = os.path.dirname(os.path.abspath(__file__))
dest = os.path.join(here, "..", "42", "media", "textures", "Item_TWA_MaterialLump.png")
out.save(dest)
print("wrote", os.path.normpath(dest), out.size)
