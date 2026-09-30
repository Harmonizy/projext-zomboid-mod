#!/usr/bin/env python3
"""HARMONIE - Home Medic: the surgery minigames' two textures (our own art).

Writes 42/media/textures/HARMONIE_HomeMedic/surg_dot.png (filled circle) and
surg_ring.png (ring), white on transparent, antialiased, 128 px -- the games
tint and scale them (HM_SurgeryGames.lua) -- and tab_diagnosis.png, the
medical window's Diagnosis tab icon (a clipboard with a heartbeat trace).
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


def diagnosis_icon(size=128):
    from PIL import ImageDraw
    big = size * 4
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = big / 128.0
    d.rounded_rectangle([22 * s, 18 * s, 106 * s, 116 * s], radius=10 * s, outline=(235, 230, 220, 255), width=int(8 * s))
    d.rounded_rectangle([44 * s, 8 * s, 84 * s, 28 * s], radius=6 * s, fill=(235, 230, 220, 255))
    pts = [(32, 70), (48, 70), (56, 50), (66, 92), (76, 60), (82, 70), (96, 70)]
    d.line([(x * s, y * s) for x, y in pts], fill=(230, 40, 40, 255), width=int(7 * s), joint="curve")
    return img.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    disc().save(os.path.join(OUT, "surg_dot.png"))
    disc(inner=N / 2 - 9).save(os.path.join(OUT, "surg_ring.png"))
    diagnosis_icon().save(os.path.join(OUT, "tab_diagnosis.png"))
    print("wrote", OUT)
