# GTP 1.6.0: the dish-buff moodle icon (a bowl with steam), 30 px and 128 px.
# Run: /usr/bin/python3 tools/gen_dishbuff_icon.py  (from mods/HARMONIE_GardenToPlate)
from PIL import Image, ImageDraw
def draw(size):
    S = 4
    W = size * S
    im = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    u = W / 128.0
    # steam
    for i, x in enumerate((44, 64, 84)):
        pts = []
        for k in range(12):
            t = k / 11.0
            y = 58 - t * 40
            xx = x + (8 if (k + i) % 4 < 2 else -8) * (0.4 + 0.6 * t)
            pts.append((xx * u, y * u))
        d.line(pts, fill=(235, 240, 235, 210), width=int(6 * u))
    # bowl
    d.chord([14 * u, 40 * u, 114 * u, 116 * u], 0, 180, fill=(196, 92, 46, 255), outline=(70, 30, 12, 255), width=int(5 * u))
    d.rectangle([12 * u, 74 * u, 116 * u, 82 * u], fill=(230, 150, 70, 255), outline=(70, 30, 12, 255), width=int(4 * u))
    # food surface
    d.ellipse([20 * u, 68 * u, 108 * u, 86 * u], fill=(250, 205, 90, 255))
    d.ellipse([38 * u, 70 * u, 52 * u, 78 * u], fill=(110, 170, 70, 255))
    d.ellipse([70 * u, 72 * u, 86 * u, 80 * u], fill=(200, 60, 50, 255))
    return im.resize((size, size), Image.LANCZOS)
draw(30).save("42/media/ui/DishBuff.png")
draw(128).save("42/media/ui/Moodles/128/DishBuff.png")
print("written")
