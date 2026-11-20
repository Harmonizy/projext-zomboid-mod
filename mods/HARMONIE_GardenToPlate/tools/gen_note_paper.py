"""GTP 1.8.0: the cook's note paper (owner's picture: a crumpled sheet of
white paper). Drawn here, not copied: a soft off-white sheet with wavy
edges, crumple shading and two creases, on a transparent background.

    /usr/bin/python3 tools/gen_note_paper.py
-> 42/media/ui/GTP_NotePaper.png (512 x 320)

To use the owner's own picture instead, save it over that file (same name,
PNG with transparency, about 8:5): the window stretches it to its size.
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

W, H = 512, 320
M = 14            # margin for the shadow and wavy edges
random.seed(42)

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "42", "media", "ui", "GTP_NotePaper.png")


def smooth_noise(w, h, cell, amp):
    """value noise: a coarse random grid, bilinear, as a list of rows"""
    gw, gh = w // cell + 2, h // cell + 2
    g = [[random.uniform(-amp, amp) for _ in range(gw)] for _ in range(gh)]
    out = []
    for y in range(h):
        fy, iy = (y / cell) % 1, y // cell
        row = []
        for x in range(w):
            fx, ix = (x / cell) % 1, x // cell
            sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
            a = g[iy][ix] * (1 - sx) + g[iy][ix + 1] * sx
            b = g[iy + 1][ix] * (1 - sx) + g[iy + 1][ix + 1] * sx
            row.append(a * (1 - sy) + b * sy)
        out.append(row)
    return out


def edge(n, amp, freq):
    """a wavy offset per pixel along one edge"""
    ph1, ph2 = random.uniform(0, 6.28), random.uniform(0, 6.28)
    return [amp * (math.sin(i * freq + ph1) * 0.6 + math.sin(i * freq * 2.7 + ph2) * 0.4) for i in range(n)]


def main():
    # the sheet's outline
    top, bot = edge(W, 2.0, 0.021), edge(W, 2.6, 0.017)
    lef, rig = edge(H, 1.6, 0.03), edge(H, 1.6, 0.027)
    mask = Image.new("L", (W, H), 0)
    px = mask.load()
    for y in range(H):
        for x in range(W):
            if M + top[x] <= y <= H - M + bot[x] and M + lef[y] <= x <= W - M + rig[y]:
                px[x, y] = 255
    mask = mask.filter(ImageFilter.GaussianBlur(0.6))

    # crumple shading: large soft patches + finer grain
    n1 = smooth_noise(W, H, 64, 9)
    n2 = smooth_noise(W, H, 18, 4)
    paper = Image.new("RGB", (W, H))
    pp = paper.load()
    for y in range(H):
        for x in range(W):
            v = 238 + n1[y][x] + n2[y][x] + random.uniform(-1.5, 1.5)
            pp[x, y] = (int(min(255, v + 1)), int(min(255, v)), int(min(255, v - 4)))

    # creases: a dark line with a light line beside it, softened
    crease = Image.new("L", (W, H), 128)
    cd = ImageDraw.Draw(crease)
    for (x1, y1, x2, y2) in ((330, M, 420, 120), (M, 190, 140, 168), (180, H - M, 260, 230)):
        cd.line((x1, y1, x2, y2), fill=96, width=2)
        cd.line((x1 + 2, y1 + 1, x2 + 2, y2 + 1), fill=168, width=2)
    crease = crease.filter(ImageFilter.GaussianBlur(1.4))
    cp = crease.load()
    for y in range(H):
        for x in range(W):
            d = (cp[x, y] - 128) * 0.35
            r, g, b = pp[x, y]
            pp[x, y] = (max(0, min(255, int(r + d))), max(0, min(255, int(g + d))), max(0, min(255, int(b + d))))

    # a soft drop shadow under the sheet
    shadow = mask.filter(ImageFilter.GaussianBlur(5)).point(lambda a: int(a * 0.35))
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste((0, 0, 0, 255), (3, 4), shadow)
    sheet = paper.convert("RGBA")
    sheet.putalpha(mask)
    out = Image.alpha_composite(out, sheet)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT)
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
