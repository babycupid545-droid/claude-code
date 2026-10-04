"""Draws the farm-themed UI sheet: wood/hay/paper textures, sign boards, ribbons, fences and
barnyard icons (golden egg currency, basket, barn, windmill, corn...). It is a second
1024x1024 image next to UiSheet.png, so the original icons keep working while this one is
being uploaded. src/shared/FarmSprites.luau (written by this script) maps names to rects.

Textures (woodTile, hayTile, paperTile) are greyscale with alpha so they tint whatever
colour sits under them.

Run: python3 tools/art/make_farm_sheet.py
"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

from make_ui_sheet import (CELL, GOLD, GOLD_DARK, GREEN, GREEN_DARK, GREY, GREY_DARK, HIGHLIGHT, OUTLINE, RED,
                           RED_DARK, ROOT, S, SS, WHITE, YELLOW, Icon, circle, highlight, star_points)

OUT_PNG = os.path.join(ROOT, "assets", "ui", "FarmSheet.png")
OUT_LUAU = os.path.join(ROOT, "src", "shared", "FarmSprites.luau")
SHEET = 1024

BROWN = (150, 96, 56, 255)
BROWN_DARK = (104, 62, 34, 255)
BROWN_LIGHT = (196, 140, 88, 255)
STRAW = (246, 210, 110, 255)
STRAW_DARK = (214, 164, 64, 255)
EGG = (255, 248, 232, 255)
EGG_SHADE = (236, 220, 196, 255)
BARN = (206, 62, 52, 255)
BARN_DARK = (150, 36, 36, 255)
ROOF = (88, 78, 96, 255)
SKY = (120, 200, 255, 255)
ORANGE = (255, 150, 40, 255)


# --- icons (128 cells, drawn at 4x) -------------------------------------------------------------

def egg_shape(d, cx, cy, w, h, color):
    """Egg: wider at the bottom."""
    pts = []
    for i in range(80):
        a = i / 80 * math.tau
        x = math.cos(a) * w / 2
        y = math.sin(a) * h / 2
        if y < 0:
            x *= 0.82 + 0.18 * (1 + y / (h / 2))
        pts.append((cx + x, cy + y))
    d.polygon(pts, fill=color)


def icon_egg_coin():
    ic = Icon()
    d, dd = ic.d, ic.dd
    egg_shape(d, S / 2, S / 2 + 8, 300, 380, GOLD)
    egg_shape(dd, S / 2 + 26, S / 2 + 40, 220, 300, (255, 176, 40, 255))
    egg_shape(dd, S / 2 - 6, S / 2 + 14, 230, 320, GOLD)
    # Shine and a sparkle.
    dd.ellipse([S / 2 - 100, S / 2 - 120, S / 2 - 40, S / 2 - 20], fill=(255, 255, 230, 230))
    dd.ellipse([S / 2 - 110, S / 2 + 10, S / 2 - 80, S / 2 + 40], fill=(255, 255, 230, 160))
    dd.polygon(star_points(S * 0.76, S * 0.22, 56, 16, 4, -90), fill=WHITE)
    return ic.render()


def icon_basket():
    ic = Icon()
    d, dd = ic.d, ic.dd
    # Eggs peeking out.
    for x, c in ((-80, EGG), (60, GOLD), (-5, EGG)):
        egg_shape(d, S / 2 + x, S / 2 - 30, 130, 170, c)
    # Handle.
    d.arc([S / 2 - 170, S / 2 - 210, S / 2 + 170, S / 2 + 150], 180, 360, fill=BROWN, width=34)
    d.polygon([(S / 2 - 200, S / 2), (S / 2 + 200, S / 2), (S / 2 + 160, S / 2 + 190), (S / 2 - 160, S / 2 + 190)], fill=BROWN_LIGHT)
    # Weave.
    for i in range(5):
        y = S / 2 + 20 + i * 36
        dd.line([(S / 2 - 190 + i * 8, y), (S / 2 + 190 - i * 8, y)], fill=BROWN_DARK, width=8)
    for i in range(-4, 5):
        dd.line([(S / 2 + i * 40, S / 2 + 6), (S / 2 + i * 34, S / 2 + 186)], fill=(150, 96, 56, 160), width=6)
    dd.rectangle([S / 2 - 205, S / 2 - 14, S / 2 + 205, S / 2 + 18], fill=BROWN)
    return ic.render()


def icon_barn():
    ic = Icon()
    d, dd = ic.d, ic.dd
    cx = S / 2
    d.polygon([(cx - 190, S - 70), (cx - 190, 220), (cx - 120, 130), (cx, 80), (cx + 120, 130), (cx + 190, 220), (cx + 190, S - 70)], fill=BARN)
    d.polygon([(cx - 215, 236), (cx - 130, 118), (cx, 58), (cx + 130, 118), (cx + 215, 236), (cx + 190, 250), (cx + 115, 150), (cx, 96), (cx - 115, 150), (cx - 190, 250)], fill=ROOF)
    dd.rectangle([cx - 90, 280, cx + 90, S - 70], fill=BARN_DARK)
    dd.rectangle([cx - 90, 280, cx + 90, S - 70], outline=WHITE, width=16)
    dd.line([(cx - 90, 280), (cx + 90, S - 70)], fill=WHITE, width=16)
    dd.line([(cx + 90, 280), (cx - 90, S - 70)], fill=WHITE, width=16)
    dd.rectangle([cx - 40, 170, cx + 40, 230], fill=BARN_DARK, outline=WHITE, width=10)
    return ic.render()


def icon_windmill():
    ic = Icon()
    d, dd = ic.d, ic.dd
    cx = S / 2
    d.polygon([(cx - 110, S - 50), (cx - 60, 200), (cx + 60, 200), (cx + 110, S - 50)], fill=(250, 244, 230, 255))
    d.polygon([(cx - 80, 210), (cx, 120), (cx + 80, 210)], fill=ROOF)
    dd.rectangle([cx - 28, S - 140, cx + 28, S - 50], fill=BROWN_DARK)
    hub = (cx, 200)
    for k in range(4):
        a = math.radians(45 + k * 90)
        ex, ey = hub[0] + math.cos(a) * 210, hub[1] + math.sin(a) * 210
        px, py = -math.sin(a) * 46, math.cos(a) * 46
        d.polygon([(hub[0] + math.cos(a) * 40, hub[1] + math.sin(a) * 40), (ex, ey), (ex + px, ey + py),
                   (hub[0] + math.cos(a) * 40 + px, hub[1] + math.sin(a) * 40 + py)], fill=(250, 248, 240, 255))
        dd.line([hub, (ex, ey)], fill=BROWN, width=14)
    circle(dd, hub[0], hub[1], 26, BROWN_DARK)
    return ic.render()


def icon_corn():
    ic = Icon()
    d, dd = ic.d, ic.dd
    cx, cy = S / 2, S / 2
    d.ellipse([cx - 80, cy - 200, cx + 80, cy + 150], fill=YELLOW)
    for row in range(9):
        for col in range(-2, 3):
            x = cx + col * 28 + (row % 2) * 14 - 7
            y = cy - 160 + row * 34
            if abs(col * 28) < 70 - abs(row - 4) * 4:
                dd.ellipse([x - 11, y - 13, x + 11, y + 13], fill=(255, 196, 40, 255))
    d.polygon([(cx - 20, cy + 210), (cx - 150, cy - 40), (cx - 60, cy + 40), (cx, cy + 150)], fill=GREEN)
    d.polygon([(cx + 20, cy + 210), (cx + 150, cy - 60), (cx + 60, cy + 40), (cx, cy + 150)], fill=GREEN_DARK)
    return ic.render()


def icon_horseshoe():
    ic = Icon()
    d, dd = ic.d, ic.dd
    cx, cy = S / 2, S / 2 - 10
    d.arc([cx - 180, cy - 190, cx + 180, cy + 170], 180, 360, fill=GOLD, width=90)
    d.rectangle([cx - 180, cy - 10, cx - 90, cy + 190], fill=GOLD)
    d.rectangle([cx + 90, cy - 10, cx + 180, cy + 190], fill=GOLD)
    for a in (200, 240, 300, 340):
        r = math.radians(a)
        circle(dd, cx + math.cos(r) * 135, cy + math.sin(r) * 135, 12, GOLD_DARK)
    for y in (60, 130):
        circle(dd, cx - 135, cy + y, 12, GOLD_DARK)
        circle(dd, cx + 135, cy + y, 12, GOLD_DARK)
    highlight(dd, [cx - 150, cy - 160, cx - 90, cy - 80])
    return ic.render()


def icon_nest():
    ic = Icon()
    d, dd = ic.d, ic.dd
    cx, cy = S / 2, S / 2 + 60
    for x, c in ((-80, EGG), (80, EGG), (0, GOLD)):
        egg_shape(d, cx + x, cy - 70, 130, 170, c)
    d.ellipse([cx - 220, cy - 60, cx + 220, cy + 120], fill=STRAW)
    rng = random.Random(3)
    for _ in range(40):
        x = cx + rng.uniform(-200, 200)
        y = cy + rng.uniform(-40, 100)
        a = rng.uniform(-0.5, 0.5)
        dd.line([(x - 40 * math.cos(a), y - 40 * math.sin(a)), (x + 40 * math.cos(a), y + 40 * math.sin(a))], fill=STRAW_DARK, width=7)
    return ic.render()


def icon_wheat():
    ic = Icon()
    d, dd = ic.d, ic.dd
    cx = S / 2
    d.line([(cx, S - 50), (cx + 20, 120)], fill=STRAW_DARK, width=24)
    for i in range(6):
        y = 130 + i * 52
        for side in (-1, 1):
            egg_shape(d, cx + 10 + side * 44, y, 70, 100, STRAW)
    egg_shape(d, cx + 22, 90, 60, 100, STRAW)
    return ic.render()


def icon_sun():
    ic = Icon()
    d, dd = ic.d, ic.dd
    cx, cy = S / 2, S / 2
    d.polygon(star_points(cx, cy, 240, 160, 12), fill=ORANGE)
    circle(d, cx, cy, 160, YELLOW)
    circle(dd, cx - 55, cy - 20, 18, OUTLINE)
    circle(dd, cx + 55, cy - 20, 18, OUTLINE)
    dd.arc([cx - 70, cy - 20, cx + 70, cy + 80], 20, 160, fill=OUTLINE, width=16)
    highlight(dd, [cx - 110, cy - 120, cx - 40, cy - 60])
    return ic.render()


def icon_egg_crack():
    ic = Icon()
    d, dd = ic.d, ic.dd
    cx, cy = S / 2, S / 2 + 20
    egg_shape(d, cx, cy, 300, 380, EGG)
    zig = [(cx - 160, cy - 10), (cx - 100, cy - 60), (cx - 50, cy + 10), (cx, cy - 70), (cx + 50, cy + 10), (cx + 100, cy - 60), (cx + 160, cy - 10)]
    dd.line(zig, fill=OUTLINE, width=16, joint="curve")
    dd.polygon([(cx - 40, cy + 60), (cx + 50, cy + 40), (cx + 20, cy + 120)], fill=(255, 200, 60, 255))
    return ic.render()


def icon_chick():
    ic = Icon()
    d, dd = ic.d, ic.dd
    cx, cy = S / 2, S / 2 + 30
    circle(d, cx, cy + 40, 170, YELLOW)
    circle(d, cx + 10, cy - 130, 120, YELLOW)
    d.polygon([(cx + 120, cy - 140), (cx + 210, cy - 115), (cx + 120, cy - 90)], fill=ORANGE)
    circle(dd, cx + 55, cy - 160, 20, OUTLINE)
    circle(dd, cx + 62, cy - 168, 7, WHITE)
    dd.ellipse([cx - 120, cy + 10, cx + 30, cy + 110], fill=(255, 200, 40, 255))
    d.polygon([(cx - 20, cy - 250), (cx + 10, cy - 290), (cx + 30, cy - 240)], fill=YELLOW)
    return ic.render()


def icon_hay_bale():
    ic = Icon()
    d, dd = ic.d, ic.dd
    cx, cy = S / 2, S / 2 + 20
    d.rounded_rectangle([cx - 210, cy - 140, cx + 210, cy + 150], radius=40, fill=STRAW)
    rng = random.Random(9)
    for _ in range(60):
        x = cx + rng.uniform(-190, 190)
        y = cy + rng.uniform(-120, 130)
        dd.line([(x - 26, y), (x + 26, y + rng.uniform(-6, 6))], fill=STRAW_DARK, width=6)
    for x in (-100, 100):
        dd.rectangle([cx + x - 14, cy - 140, cx + x + 14, cy + 150], fill=(170, 110, 50, 255))
    return ic.render()


def icon_pitchfork():
    ic = Icon()
    d, dd = ic.d, ic.dd
    cx = S / 2
    d.line([(cx, S - 40), (cx, 230)], fill=BROWN, width=34)
    d.rounded_rectangle([cx - 120, 200, cx + 120, 250], radius=20, fill=GREY)
    for x in (-110, 0, 110):
        d.polygon([(cx + x - 16, 225), (cx + x + 16, 225), (cx + x + 8, 50), (cx + x, 30), (cx + x - 8, 50)], fill=GREY)
    dd.line([(cx - 6, S - 50), (cx - 6, 260)], fill=BROWN_LIGHT, width=8)
    return ic.render()


def icon_bell():
    ic = Icon()
    d, dd = ic.d, ic.dd
    cx, cy = S / 2, S / 2
    d.pieslice([cx - 150, cy - 190, cx + 150, cy + 110], 180, 360, fill=GOLD)
    d.polygon([(cx - 150, cy - 40), (cx + 150, cy - 40), (cx + 200, cy + 140), (cx - 200, cy + 140)], fill=GOLD)
    circle(d, cx, cy + 170, 48, GOLD_DARK)
    circle(d, cx, cy - 200, 34, GOLD_DARK)
    dd.rectangle([cx - 200, cy + 100, cx + 200, cy + 140], fill=GOLD_DARK)
    highlight(dd, [cx - 110, cy - 150, cx - 50, cy + 40])
    return ic.render()


def icon_cloud():
    ic = Icon()
    d = ic.d
    for x, y, r in ((-110, 40, 100), (0, -20, 130), (120, 40, 100), (0, 80, 110)):
        circle(d, S / 2 + x, S / 2 + y, r, WHITE)
    return ic.render()


def icon_footprint():
    ic = Icon()
    d = ic.d
    cx, cy = S / 2, S / 2 + 120
    for a in (-35, 0, 35):
        r = math.radians(a - 90)
        d.line([(cx, cy), (cx + math.cos(r) * 260, cy + math.sin(r) * 260)], fill=ORANGE, width=46)
        circle(d, cx + math.cos(r) * 260, cy + math.sin(r) * 260, 23, ORANGE)
    d.line([(cx, cy), (cx, cy + 110)], fill=ORANGE, width=46)
    circle(d, cx, cy, 40, ORANGE)
    return ic.render()


ICONS = [
    ("eggCoin", icon_egg_coin), ("basket", icon_basket), ("barn", icon_barn), ("windmill", icon_windmill),
    ("corn", icon_corn), ("horseshoe", icon_horseshoe), ("nest", icon_nest), ("wheat", icon_wheat),
    ("sun", icon_sun), ("eggCrack", icon_egg_crack), ("chick", icon_chick), ("hayBale", icon_hay_bale),
    ("pitchfork", icon_pitchfork), ("bell", icon_bell), ("cloud", icon_cloud), ("footprint", icon_footprint),
]


# --- textures and decorations -------------------------------------------------------------------

def wood_tile(size=256):
    """Seamless planks as a greyscale overlay: dark seams and grain, light plank tops."""
    big = size * 2
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = random.Random(4)
    planks = 4
    ph = big // planks
    for p in range(planks):
        y0 = p * ph
        # Grain: long wavy streaks.
        for _ in range(9):
            gy = y0 + rng.uniform(10, ph - 10)
            amp = rng.uniform(2, 6)
            phase = rng.uniform(0, math.tau)
            pts = [(x, gy + math.sin(x / big * math.tau * 2 + phase) * amp) for x in range(0, big + 8, 8)]
            d.line(pts, fill=(0, 0, 0, rng.randint(18, 40)), width=rng.randint(2, 4))
        # Knot.
        kx, ky = rng.uniform(40, big - 40), y0 + ph / 2 + rng.uniform(-10, 10)
        for r in (18, 11, 5):
            d.ellipse([kx - r * 1.8, ky - r, kx + r * 1.8, ky + r], outline=(0, 0, 0, 50), width=3)
        # Light top edge, dark seam.
        d.rectangle([0, y0 + 4, big, y0 + 10], fill=(255, 255, 255, 40))
        d.rectangle([0, y0, big, y0 + 4], fill=(0, 0, 0, 120))
        # Staggered butt joint with nails.
        jx = (p * 0.37 % 1) * big
        d.rectangle([jx, y0, jx + 4, y0 + ph], fill=(0, 0, 0, 110))
        for nx in (jx - 14, jx + 18):
            for ny in (y0 + 18, y0 + ph - 18):
                d.ellipse([nx - 5, ny - 5, nx + 5, ny + 5], fill=(0, 0, 0, 110))
                d.ellipse([nx - 3, ny - 4, nx + 1, ny], fill=(255, 255, 255, 90))
    return img.resize((size, size), Image.LANCZOS)


def hay_tile(size=256):
    big = size * 2
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = random.Random(7)
    for _ in range(900):
        x, y = rng.uniform(0, big), rng.uniform(0, big)
        a = rng.uniform(-0.6, 0.6)
        length = rng.uniform(20, 60)
        col = (255, 255, 255, rng.randint(25, 60)) if rng.random() < 0.5 else (0, 0, 0, rng.randint(20, 45))
        for ox in (-big, 0, big):
            for oy in (-big, 0, big):
                d.line([(x + ox, y + oy), (x + ox + math.cos(a) * length, y + oy + math.sin(a) * length)], fill=col, width=3)
    return img.resize((size, size), Image.LANCZOS)


def paper_tile(size=256):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    rng = random.Random(11)
    for y in range(size):
        for x in range(size):
            v = rng.random()
            if v < 0.08:
                px[x, y] = (0, 0, 0, 14)
            elif v > 0.94:
                px[x, y] = (255, 255, 255, 22)
    return img.filter(ImageFilter.SMOOTH)


def print_tile(size=256):
    """Scattered chicken footprints, white, for subtle backgrounds."""
    big = size * 2
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, (x, y, rot) in enumerate(((120, 130, 20), (330, 300, -15), (130, 420, 5), (400, 90, 30))):
        for a in (-35, 0, 35):
            r = math.radians(a - 90 + rot)
            d.line([(x, y), (x + math.cos(r) * 56, y + math.sin(r) * 56)], fill=WHITE, width=12)
        r = math.radians(90 + rot)
        d.line([(x, y), (x + math.cos(r) * 26, y + math.sin(r) * 26)], fill=WHITE, width=12)
    return img.resize((size, size), Image.LANCZOS)


def sign_board(w=512, h=128):
    """A chunky wooden sign plank with nails. Slice it horizontally (SliceCenter 64..448)."""
    W, H = w * SS, h * SS
    ic = Icon(max(W, H))
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(canvas)
    pad = 36
    d.rounded_rectangle([pad, pad, W - pad, H - pad - 14], radius=60, fill=OUTLINE)
    d.rounded_rectangle([pad + 26, pad + 26, W - pad - 26, H - pad - 40], radius=40, fill=BROWN_LIGHT)
    d.rounded_rectangle([pad + 26, H / 2 - 4, W - pad - 26, H - pad - 40], radius=40, fill=BROWN)
    d.rectangle([pad + 60, H / 2 - 6, W - pad - 60, H / 2 + 4], fill=BROWN_DARK)
    rng = random.Random(5)
    for _ in range(14):
        gy = rng.uniform(pad + 50, H - pad - 70)
        gx = rng.uniform(pad + 80, W - pad - 400)
        d.line([(gx, gy), (gx + rng.uniform(150, 380), gy + rng.uniform(-6, 6))], fill=(110, 66, 36, 120), width=7)
    for x in (pad + 80, W - pad - 80):
        for y in (pad + 70, H - pad - 90):
            circle(d, x, y, 18, (80, 70, 80, 255))
            circle(d, x - 5, y - 5, 7, (220, 220, 230, 255))
    del ic
    return canvas.resize((w, h), Image.LANCZOS)


def ribbon(w=512, h=128):
    W, H = w * SS, h * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    o = 22
    # Tails behind.
    for side in (-1, 1):
        x0 = W / 2 + side * (W / 2 - 40)
        x1 = W / 2 + side * (W / 2 - 290)
        tail = [(x0, H * 0.32), (x1, H * 0.32), (x1, H * 0.86), (x0, H * 0.86), (x0 - side * 70, H * 0.59)]
        d.polygon(tail, fill=OUTLINE)
        inner = [(x0 - side * o * 1.6, H * 0.32 + o), (x1, H * 0.32 + o), (x1, H * 0.86 - o), (x0 - side * o * 1.6, H * 0.86 - o), (x0 - side * 70 - side * o, H * 0.59)]
        d.polygon(inner, fill=RED_DARK)
    d.rounded_rectangle([200, 30, W - 200, H * 0.76], radius=30, fill=OUTLINE)
    d.rounded_rectangle([200 + o, 30 + o, W - 200 - o, H * 0.76 - o], radius=20, fill=RED)
    d.rectangle([200 + o, 30 + o, W - 200 - o, 30 + o + 40], fill=(255, 130, 120, 255))
    for x in range(260, W - 260, 60):
        d.line([(x, H * 0.76 - o - 26), (x + 30, H * 0.76 - o - 26)], fill=(255, 210, 200, 200), width=8)
    return img.resize((w, h), Image.LANCZOS)


def fence_strip(w=512, h=128):
    """White picket fence, tiles horizontally (8 pickets)."""
    W, H = w * SS, h * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pw = W / 8
    o = 20
    for rail_y in (H * 0.42, H * 0.74):
        d.rectangle([0, rail_y - 34, W, rail_y + 34], fill=OUTLINE)
        d.rectangle([0, rail_y - 34 + o, W, rail_y + 34 - o], fill=(226, 222, 214, 255))
    for i in range(8):
        x = i * pw + pw / 2
        bw = pw * 0.62
        shape = [(x - bw / 2, H - 6), (x - bw / 2, 90), (x, 20), (x + bw / 2, 90), (x + bw / 2, H - 6)]
        d.polygon(shape, fill=OUTLINE)
        inner = [(x - bw / 2 + o, H - 6 - o), (x - bw / 2 + o, 90 + o * 0.6), (x, 20 + o * 1.8), (x + bw / 2 - o, 90 + o * 0.6), (x + bw / 2 - o, H - 6 - o)]
        d.polygon(inner, fill=WHITE)
        d.line([(x - bw / 2 + o + 12, 110), (x - bw / 2 + o + 12, H - 40)], fill=(255, 255, 255, 255), width=10)
        d.line([(x + bw / 2 - o - 10, 110), (x + bw / 2 - o - 10, H - 30)], fill=(214, 208, 198, 255), width=14)
    return img.resize((w, h), Image.LANCZOS)


def grass_strip(w=512, h=128):
    W, H = w * SS, h * SS
    blades = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(blades)
    rng = random.Random(2)
    for i in range(70):
        x = (i / 70) * W
        bh = rng.uniform(H * 0.35, H * 0.85)
        lean = rng.uniform(-50, 50)
        color = GREEN if rng.random() < 0.6 else GREEN_DARK
        for ox in (-W, 0, W):
            d.polygon([(x + ox - 26, H), (x + ox + lean, H - bh), (x + ox + 26, H)], fill=color)
    d.rectangle([0, H - 40, W, H], fill=GREEN_DARK)
    alpha = blades.split()[3].point(lambda a: 255 if a > 8 else 0)
    grown = alpha.filter(ImageFilter.MaxFilter(17))
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", out.size, OUTLINE), mask=grown)
    out = Image.alpha_composite(out, blades)
    return out.resize((w, h), Image.LANCZOS)


def big_egg(size=256):
    ic = Icon()
    d, dd = ic.d, ic.dd
    egg_shape(d, S / 2, S / 2 + 10, 320, 410, GOLD)
    egg_shape(dd, S / 2 + 30, S / 2 + 44, 240, 330, (255, 176, 40, 255))
    egg_shape(dd, S / 2 - 6, S / 2 + 16, 250, 350, GOLD)
    dd.ellipse([S / 2 - 110, S / 2 - 130, S / 2 - 40, S / 2 - 20], fill=(255, 255, 230, 230))
    for x, y, r in ((0.8, 0.2, 60), (0.18, 0.8, 40), (0.85, 0.75, 34)):
        dd.polygon(star_points(S * x, S * y, r, r * 0.3, 4, -90), fill=WHITE)
    return ic.render().resize((size, size), Image.LANCZOS)


def rosette(size=256):
    ic = Icon()
    d, dd = ic.d, ic.dd
    cx, cy = S / 2, S / 2 - 40
    for side in (-1, 1):
        d.polygon([(cx + side * 30, cy + 60), (cx + side * 150, cy + 300), (cx + side * 90, cy + 270), (cx + side * 60, cy + 320), (cx + side * -40, cy + 80)], fill=BLUE_RIBBON)
    d.polygon(star_points(cx, cy, 190, 160, 18), fill=GOLD)
    circle(d, cx, cy, 130, GOLD_DARK)
    circle(dd, cx, cy, 104, GOLD)
    dd.polygon(star_points(cx, cy, 70, 30, 5), fill=WHITE)
    return ic.render().resize((size, size), Image.LANCZOS)


BLUE_RIBBON = (70, 140, 240, 255)


def main():
    sheet = Image.new("RGBA", (SHEET, SHEET), (0, 0, 0, 0))
    entries = []
    for i, (name, fn) in enumerate(ICONS):
        x, y = (i % 8) * CELL, (i // 8) * CELL
        sheet.alpha_composite(fn().resize((CELL, CELL), Image.LANCZOS), (x, y))
        entries.append((name, x, y, CELL, CELL))
    for name, img, x, y in [
        ("woodTile", wood_tile(), 0, 256),
        ("hayTile", hay_tile(), 256, 256),
        ("paperTile", paper_tile(), 512, 256),
        ("printTile", print_tile(), 768, 256),
        ("sign", sign_board(), 0, 512),
        ("ribbon", ribbon(), 512, 512),
        ("fence", fence_strip(), 0, 640),
        ("grass", grass_strip(), 512, 640),
        ("bigEgg", big_egg(), 0, 768),
        ("rosette", rosette(), 256, 768),
    ]:
        sheet.alpha_composite(img, (x, y))
        entries.append((name, x, y, img.width, img.height))

    os.makedirs(os.path.dirname(OUT_PNG), exist_ok=True)
    sheet.save(OUT_PNG, optimize=True)
    lines = [
        "--!strict",
        "-- GENERATED by tools/art/make_farm_sheet.py - do not edit by hand.",
        "-- Where each image sits on the farm UI sheet (assets/ui/FarmSheet.png).",
        "",
        "export type Sprite = { offset: Vector2, size: Vector2 }",
        "",
        "local sprites: { [string]: Sprite } = {",
    ]
    for name, x, y, w, h in entries:
        lines.append(f"\t{name} = {{ offset = Vector2.new({x}, {y}), size = Vector2.new({w}, {h}) }},")
    lines += ["}", "", "return sprites", ""]
    with open(OUT_LUAU, "w") as f:
        f.write("\n".join(lines))
    print(f"wrote {OUT_PNG} with {len(entries)} sprites")


if __name__ == "__main__":
    main()
