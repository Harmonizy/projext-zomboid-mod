#!/usr/bin/env python3
"""White glyphs on a clear background (owner 2026-11-17: "fewer words, only
symbols, the text shows on hover"). Drawn here, no outside art; any window
tints them with drawTextureScaled(tex, x, y, w, h, a, r, g, b).
64x64 RGBA -> ../media/ui/HARMONIE_g_<name>.png. Run with /usr/bin/python3."""
import os, math
from PIL import Image, ImageDraw
S = 64; SS = 4; W = S * SS
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "media", "ui")
WH = (255, 255, 255, 255)
CL = (0, 0, 0, 0)
def p(v): return int(v * SS)
def new():
    im = Image.new("RGBA", (W, W), CL)
    return im, ImageDraw.Draw(im)
def save(im, name):
    im = im.resize((S, S), Image.LANCZOS)
    path = os.path.join(OUT, "HARMONIE_g_%s.png" % name)
    im.save(path); print("wrote", os.path.normpath(path))

def warn():
    im, d = new()
    d.polygon([(p(32), p(6)), (p(60), p(56)), (p(4), p(56))], fill=WH)
    d.rounded_rectangle([p(29), p(22), p(35), p(42)], p(3), fill=CL)
    d.ellipse([p(28.5), p(45), p(35.5), p(52)], fill=CL)
    return im
def info():
    im, d = new()
    d.ellipse([p(4), p(4), p(60), p(60)], fill=WH)
    d.ellipse([p(28), p(14), p(36), p(22)], fill=CL)
    d.rounded_rectangle([p(28), p(27), p(36), p(50)], p(3), fill=CL)
    return im
def lock():
    im, d = new()
    d.rounded_rectangle([p(10), p(28), p(54), p(58)], p(6), fill=WH)
    d.arc([p(18), p(6), p(46), p(40)], 180, 360, fill=WH, width=p(7))
    d.line([p(21.5), p(23), p(21.5), p(30)], fill=WH, width=p(7))
    d.line([p(42.5), p(23), p(42.5), p(30)], fill=WH, width=p(7))
    d.ellipse([p(28), p(37), p(36), p(45)], fill=CL)
    d.rectangle([p(30.5), p(42), p(33.5), p(51)], fill=CL)
    return im
def busy():
    im, d = new()
    d.rectangle([p(12), p(4), p(52), p(10)], fill=WH)
    d.rectangle([p(12), p(54), p(52), p(60)], fill=WH)
    d.polygon([(p(16), p(10)), (p(48), p(10)), (p(34), p(32)), (p(48), p(54)), (p(16), p(54)), (p(30), p(32))], fill=WH)
    d.polygon([(p(22), p(14)), (p(42), p(14)), (p(32), p(28))], fill=CL)
    d.polygon([(p(32), p(40)), (p(42), p(50)), (p(22), p(50))], fill=CL)
    return im
def play():
    im, d = new()
    d.polygon([(p(14), p(6)), (p(56), p(32)), (p(14), p(58))], fill=WH)
    return im
def menu():
    im, d = new()
    for y in (12, 29, 46):
        d.rounded_rectangle([p(6), p(y), p(58), p(y + 7)], p(3), fill=WH)
    return im
def mode():
    im, d = new()
    for y, kx in ((16, 42), (40, 22)):
        d.rounded_rectangle([p(4), p(y - 3), p(60), p(y + 3)], p(3), fill=WH)
        d.ellipse([p(kx - 9), p(y - 9), p(kx + 9), p(y + 9)], fill=WH)
        d.ellipse([p(kx - 4), p(y - 4), p(kx + 4), p(y + 4)], fill=CL)
    return im
def check():
    im, d = new()
    d.line([(p(8), p(34)), (p(25), p(51)), (p(57), p(14))], fill=WH, width=p(10), joint="curve")
    return im
def cross():
    im, d = new()
    d.line([(p(12), p(12)), (p(52), p(52))], fill=WH, width=p(10))
    d.line([(p(52), p(12)), (p(12), p(52))], fill=WH, width=p(10))
    return im
def back():
    im, d = new()
    d.polygon([(p(4), p(32)), (p(28), p(8)), (p(28), p(22)), (p(60), p(22)), (p(60), p(42)), (p(28), p(42)), (p(28), p(56))], fill=WH)
    return im
def redo():
    im, d = new()
    d.arc([p(8), p(10), p(52), p(54)], 40, 330, fill=WH, width=p(8))
    d.polygon([(p(60), p(10)), (p(58), p(34)), (p(38), p(22))], fill=WH)
    return im
def target():
    im, d = new()
    d.ellipse([p(4), p(4), p(60), p(60)], fill=WH)
    d.ellipse([p(12), p(12), p(52), p(52)], fill=CL)
    d.ellipse([p(20), p(20), p(44), p(44)], fill=WH)
    d.ellipse([p(27), p(27), p(37), p(37)], fill=CL)
    return im
def box():
    im, d = new()
    d.polygon([(p(32), p(4)), (p(60), p(16)), (p(32), p(28)), (p(4), p(16))], fill=WH)
    d.polygon([(p(4), p(20)), (p(30), p(32)), (p(30), p(60)), (p(4), p(48))], fill=WH)
    d.polygon([(p(34), p(32)), (p(60), p(20)), (p(60), p(48)), (p(34), p(60))], fill=WH)
    return im
def tool():
    im, d = new()
    d.line([(p(14), p(54)), (p(40), p(26))], fill=WH, width=p(9))
    d.rounded_rectangle([p(30), p(6), p(60), p(22)], p(3), fill=WH)
    return im
def flag():
    im, d = new()
    d.rectangle([p(10), p(4), p(16), p(60)], fill=WH)
    d.polygon([(p(16), p(6)), (p(56), p(18)), (p(16), p(32))], fill=WH)
    return im

for name, fn in (("warn", warn), ("info", info), ("lock", lock), ("busy", busy), ("play", play), ("menu", menu),
                 ("mode", mode), ("check", check), ("cross", cross), ("back", back), ("redo", redo),
                 ("target", target), ("box", box), ("tool", tool), ("flag", flag)):
    save(fn(), name)
