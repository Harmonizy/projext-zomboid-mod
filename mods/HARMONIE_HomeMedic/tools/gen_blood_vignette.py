#!/usr/bin/env python3
"""HARMONIE - Home Medic: the blood-loss vignette texture (drawn here, no
third-party art). A black frame whose alpha rises from a clear centre to
opaque corners; HARMONIE_BloodVision.lua stretches it over the screen and
fades it in with blood loss.
Writes ../42/media/textures/HARMONIE_HomeMedic/blood_vignette.png. Needs Pillow + numpy."""
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "42", "media", "textures", "HARMONIE_HomeMedic", "blood_vignette.png")
SIZE = 512

def main():
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    c = (SIZE - 1) / 2
    # elliptical distance, 0 at the centre, ~1 at the edge midpoints
    d = np.sqrt(((x - c) / c) ** 2 + ((y - c) / c) ** 2)
    a = np.clip((d - 0.35) / (1.25 - 0.35), 0, 1)
    a = a * a * (3 - 2 * a)            # smoothstep
    rgba = np.zeros((SIZE, SIZE, 4), np.uint8)
    rgba[..., 0] = 20                   # a touch of red in the dark
    rgba[..., 3] = (a * 255).astype(np.uint8)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(OUT)
    print("wrote", OUT)

if __name__ == "__main__":
    main()
