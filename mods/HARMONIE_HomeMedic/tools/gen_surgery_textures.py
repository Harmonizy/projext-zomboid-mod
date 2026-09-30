#!/usr/bin/env python3
"""HARMONIE - Home Medic: the surgery minigames' two textures (our own art).

Writes 42/media/textures/HARMONIE_HomeMedic/surg_dot.png (filled circle) and
surg_ring.png (ring), white on transparent, antialiased, 128 px -- the games
tint and scale them (HM_SurgeryGames.lua).
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


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    disc().save(os.path.join(OUT, "surg_dot.png"))
    disc(inner=N / 2 - 9).save(os.path.join(OUT, "surg_ring.png"))
    print("wrote", OUT)
