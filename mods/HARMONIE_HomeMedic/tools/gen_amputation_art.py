#!/usr/bin/env python3
"""HARMONIE - How to Survive: the Amputation tab's pictures (our own art).

Writes 42/media/textures/HARMONIE_HomeMedic/:
  * tab_amputation.png -- the tab icon, in the badge style of
    gen_surgery_textures.py (its _canvas / _done / colours);
  * amp/arm_<L|R>_<state>.png -- one arm hanging down, 96x224, for each
    state the tab shows: none (whole arm), Hand, ForeArm, UpperArm (cut there:
    the part below is a faint outline, the stump a red cap), Hand_prost,
    ForeArm_prost (the missing part as a steel prosthesis). R is L mirrored.
Run with a Python that has Pillow (here: /usr/bin/python3).
"""
import os
import sys
from PIL import Image, ImageDraw, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from gen_surgery_textures import _canvas, _done, CREAM, RED, OUT  # noqa: E402

W, H, K = 96, 224, 4                      # picture size, drawn at 4x
STUMP = (200, 74, 64, 255)
STEEL = (128, 146, 166, 255)
SOCKET = (52, 64, 80, 255)
CUT_Y = {"Hand": 164, "ForeArm": 122, "UpperArm": 58}   # where each cut is (picture px)


def arm_layer(fill):
    """The whole left arm, thumb toward the body (picture's left)."""
    img = Image.new("RGBA", (W * K, H * K), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = K
    d.ellipse([22 * s, 4 * s, 74 * s, 40 * s], fill=fill)                       # shoulder
    d.rounded_rectangle([30 * s, 18 * s, 66 * s, 98 * s], radius=17 * s, fill=fill)   # upper arm
    d.polygon([(31 * s, 96 * s), (65 * s, 96 * s), (61 * s, 166 * s), (35 * s, 166 * s)], fill=fill)  # forearm
    d.ellipse([31 * s, 84 * s, 65 * s, 108 * s], fill=fill)                     # elbow
    d.rounded_rectangle([33 * s, 160 * s, 63 * s, 198 * s], radius=9 * s, fill=fill)  # palm
    for i, x in enumerate((35, 42, 49, 56)):                                     # fingers
        d.rounded_rectangle([x * s, 190 * s, (x + 6) * s, (214 - abs(i - 1.5) * 3) * s], radius=3 * s, fill=fill)
    d.polygon([(34 * s, 168 * s), (28 * s, 176 * s), (21 * s, 192 * s), (25 * s, 196 * s),
               (33 * s, 184 * s), (38 * s, 178 * s)], fill=fill)                 # thumb
    return img


def below(img, y, keep_below):
    """Keep only the part of img below (or above) picture row y."""
    out = img.copy()
    a = out.getchannel("A")
    mask = Image.new("L", out.size, 0)
    md = ImageDraw.Draw(mask)
    if keep_below:
        md.rectangle([0, y * K, W * K, H * K], fill=255)
    else:
        md.rectangle([0, 0, W * K, y * K], fill=255)
    out.putalpha(Image.composite(a, Image.new("L", out.size, 0), mask))
    return out


def faint(img, alpha=0.20):
    out = img.copy()
    out.putalpha(out.getchannel("A").point(lambda v: int(v * alpha)))
    return out


def arm(state):
    whole = arm_layer(CREAM)
    if state == "none":
        pic = whole
    else:
        part = state.replace("_prost", "")
        y = CUT_Y[part]
        pic = Image.new("RGBA", whole.size, (0, 0, 0, 0))
        if state.endswith("_prost"):
            pic.alpha_composite(below(arm_layer(STEEL), y, True))
        else:
            pic.alpha_composite(faint(below(whole, y, True)))
        pic.alpha_composite(below(whole, y, False))
        d = ImageDraw.Draw(pic)
        # the end of the stump: a rounded red cap across the arm's width there
        xs = [x for x in range(W * K) if whole.getpixel((x, y * K))[3] > 128]
        if xs:
            x0, x1 = xs[0], xs[-1]
            if state.endswith("_prost"):
                d.rounded_rectangle([x0 - 2 * K, (y - 4) * K, x1 + 2 * K, (y + 6) * K], radius=3 * K, fill=SOCKET)
            else:
                d.ellipse([x0, (y - 5) * K, x1, (y + 5) * K], fill=STUMP)
    return pic.resize((W, H), Image.LANCZOS)


def tab_amputation(size=128):
    """Amputation: a forearm with a dashed cut line, the hand above it faint."""
    img, d, s = _canvas(size)
    d.rounded_rectangle([50 * s, 20 * s, 78 * s, 44 * s], radius=8 * s, fill=(238, 232, 220, 70))   # hand (gone)
    d.rounded_rectangle([48 * s, 56 * s, 80 * s, 112 * s], radius=10 * s, fill=CREAM)               # forearm
    d.ellipse([48 * s, 50 * s, 80 * s, 62 * s], fill=STUMP)                                         # stump
    for x in range(22, 106, 14):                                                                     # cut line
        d.line([(x * s, 48 * s), ((x + 8) * s, 48 * s)], fill=RED, width=int(6 * s))
    return _done(img, size)


if __name__ == "__main__":
    os.makedirs(os.path.join(OUT, "amp"), exist_ok=True)
    tab_amputation().save(os.path.join(OUT, "tab_amputation.png"))
    n = 0
    for state in ("none", "Hand", "ForeArm", "UpperArm", "Hand_prost", "ForeArm_prost"):
        left = arm(state)
        left.save(os.path.join(OUT, "amp", "arm_L_%s.png" % state))
        ImageOps.mirror(left).save(os.path.join(OUT, "amp", "arm_R_%s.png" % state))
        n += 2
    print("wrote tab_amputation.png and %d arm pictures in %s" % (n, OUT))
