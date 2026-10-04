"""Draws the clean icon set: one 1024x1024 PNG with every UI icon in a flat, modern style.

Every icon is built from simple rounded shapes. Each shape gets
  - a thin outline in a darker shade of its own colour (never one black outline round everything),
  - a soft darker band along its lower edges and a lighter band along its upper edges,
and nothing else: no drop shadows, no sticker borders. Icons are drawn at 4x and downscaled
for smooth edges, sit in 128x128 cells with ~10% padding, and read on both the dark and the
cream panels of the barnyard UI.

src/shared/IconSprites.luau (written by this script) maps names to cells. Textures and
decorations (woodTile, ribbon, sunburst, ...) stay on UiSheet/FarmSheet.

Run: python3 tools/art/make_icon_sheet.py
"""

import math
import os
from collections import namedtuple

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_PNG = os.path.join(ROOT, "assets", "ui", "IconSheet.png")
OUT_LUAU = os.path.join(ROOT, "src", "shared", "IconSprites.luau")

CELL = 128
SS = 4  # supersampling factor
N = CELL * SS  # drawing size of one cell (all coordinates below are in this 512 space)
SHEET = 1024
OW = 13  # outline width at 512 (about 3.25 px in a 128 cell)

# --- palette -------------------------------------------------------------------------------
# outline (darkest, same hue) / shade (lower band) / base / hi (upper band)
Pal = namedtuple("Pal", "outline shade base hi")

GOLD = Pal((170, 96, 22), (242, 164, 32), (255, 199, 56), (255, 228, 132))
YELLOW = Pal((178, 116, 20), (250, 192, 46), (255, 221, 84), (255, 242, 158))
CREAM = Pal((160, 118, 80), (236, 218, 188), (255, 247, 230), (255, 255, 253))
RED = Pal((134, 34, 34), (206, 56, 50), (234, 82, 66), (255, 128, 108))
TOMATO = Pal((146, 46, 26), (228, 86, 46), (246, 116, 66), (255, 160, 116))
ORANGE = Pal((164, 70, 20), (240, 118, 32), (255, 152, 52), (255, 194, 112))
BLUE = Pal((34, 80, 150), (58, 130, 212), (84, 166, 238), (140, 206, 255))
BLUE_LIGHT = Pal((46, 98, 166), (112, 172, 228), (148, 202, 246), (198, 232, 255))
GREEN = Pal((40, 106, 46), (80, 166, 66), (112, 198, 86), (160, 228, 122))
WOOD = Pal((96, 56, 30), (150, 92, 52), (180, 118, 68), (212, 160, 106))
WOOD_LIGHT = Pal((118, 72, 36), (198, 142, 84), (222, 172, 110), (242, 206, 150))
STRAW = Pal((152, 100, 32), (226, 172, 68), (247, 208, 104), (255, 233, 160))
STEEL = Pal((84, 94, 116), (170, 180, 198), (208, 216, 228), (242, 246, 251))
CHARCOAL = Pal((30, 26, 34), (60, 54, 64), (84, 78, 90), (118, 112, 124))
PINK = Pal((140, 36, 76), (214, 72, 118), (242, 106, 150), (255, 162, 194))
CLOUD = Pal((92, 138, 196), (212, 228, 248), (250, 252, 255), (255, 255, 255))
GLASS = Pal((46, 98, 152), (152, 202, 238), (192, 228, 250), (232, 247, 255))

GLYPH = (255, 251, 240)  # symbols printed on round badges (check, X, play, i)

# --- geometry (points pass through a transform stack so whole icons can be rotated) --------
_XF = [lambda x, y: (x, y)]
_SC = [1.0]
_SIZE = [N]


class xf:
    """Rotate (degrees, clockwise on screen) / scale / move everything drawn inside the block."""

    def __init__(self, rot=0.0, center=(256, 256), scale=1.0, dx=0.0, dy=0.0, flip=False):
        self.rot, self.center, self.scale, self.dx, self.dy, self.flip = rot, center, scale, dx, dy, flip

    def __enter__(self):
        outer = _XF[-1]
        c, s = math.cos(math.radians(self.rot)), math.sin(math.radians(self.rot))
        cx, cy = self.center
        k, dx, dy, flip = self.scale, self.dx, self.dy, self.flip

        def f(x, y):
            x, y = x - cx, y - cy
            if flip:
                x = -x
            x, y = (x * c - y * s) * k, (x * s + y * c) * k
            return outer(cx + x + dx, cy + y + dy)

        _XF.append(f)
        _SC.append(_SC[-1] * k)
        return self

    def __exit__(self, *exc):
        _XF.pop()
        _SC.pop()


def _img():
    return Image.new("L", (_SIZE[-1], _SIZE[-1]), 0)


def _arr(im):
    return np.asarray(im) > 127


def poly(pts):
    im = _img()
    ImageDraw.Draw(im).polygon([_XF[-1](*p) for p in pts], fill=255)
    return _arr(im)


def ell(cx, cy, rx, ry, rot=0.0, n=160):
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    pts = []
    for i in range(n):
        t = math.tau * i / n
        x, y = rx * math.cos(t), ry * math.sin(t)
        pts.append((cx + x * c - y * s, cy + x * s + y * c))
    return poly(pts)


def circ(cx, cy, r):
    return ell(cx, cy, r, r)


def rrect(x0, y0, x1, y1, r):
    r = min(r, (x1 - x0) / 2, (y1 - y0) / 2)
    pts = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for i in range(13):
            a = math.radians(a0 + 90 * i / 12)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(pts)


def line(pts, w):
    """A thick polyline with round caps and joints (built from quads + discs, so it stays clean)."""
    im = _img()
    d = ImageDraw.Draw(im)
    tp = [_XF[-1](*p) for p in pts]
    r = w * _SC[-1] / 2
    for (x0, y0), (x1, y1) in zip(tp, tp[1:]):
        length = math.hypot(x1 - x0, y1 - y0)
        if length == 0:
            continue
        nx, ny = -(y1 - y0) / length * r, (x1 - x0) / length * r
        d.polygon([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)], fill=255)
    for x, y in tp:
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return _arr(im)


def arc_pts(cx, cy, r, a0, a1, n=64):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def arc(cx, cy, r, a0, a1, w):
    return line(arc_pts(cx, cy, r, a0, a1), w)


def ring(cx, cy, r, w):
    return sub(circ(cx, cy, r + w / 2), circ(cx, cy, r - w / 2))


def star_pts(cx, cy, r_out, r_in, points=5, rot=-90):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180 / points)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def egg(cx, cy, rx, ry, k=0.15, n=200):
    """Egg outline: narrower at the top, fuller at the bottom."""
    pts = []
    for i in range(n):
        t = math.tau * i / n
        y, x = -math.cos(t), math.sin(t)
        pts.append((cx + rx * x * (1 + k * y), cy + ry * y))
    return poly(pts)


def tear(cx, cy, r, tx, ty, n=80):
    """A teardrop: circle (cx, cy, r) drawn out to a point at (tx, ty)."""
    d = math.hypot(tx - cx, ty - cy)
    base = math.atan2(ty - cy, tx - cx)
    a = math.acos(r / d)
    pts = [(tx, ty)]
    for i in range(n + 1):
        ang = base + a + (math.tau - 2 * a) * i / n
        pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    return poly(pts)


def sparkle(cx, cy, rx, ry=None, e=2.6, n=160):
    """Four-pointed sparkle with curved sides."""
    ry = ry or rx
    pts = []
    for i in range(n):
        t = math.tau * i / n
        c, s = math.cos(t), math.sin(t)
        pts.append((cx + rx * math.copysign(abs(c) ** e, c), cy + ry * math.copysign(abs(s) ** e, s)))
    return poly(pts)


def U(*ms):
    return np.logical_or.reduce(ms)


def sub(a, *bs):
    for b in bs:
        a = a & ~b
    return a


def inter(a, b):
    return a & b


def shift(m, dx, dy):
    out = np.zeros_like(m)
    h, w = m.shape
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    out[yd, xd] = m[ys, xs]
    return out


def erode(m, r):
    return ndimage.distance_transform_edt(m) > r


def dilate(m, r):
    return ndimage.distance_transform_edt(~m) <= r


def rounded(m, r):
    """Rounds convex corners with radius r."""
    r *= _SIZE[-1] / N
    return dilate(erode(m, r), r)


def smooth(m, r):
    """Rounds both convex and concave corners."""
    r *= _SIZE[-1] / N
    closed = erode(dilate(m, r), r)
    return dilate(erode(closed, r), r)


def box_h(m):
    ys = np.where(m.any(axis=1))[0]
    return (ys[-1] - ys[0]) if len(ys) else 0


# --- drawing -------------------------------------------------------------------------------

class Icon:
    def __init__(self, n=N):
        _SIZE.append(n)
        self.n = n
        self.k = n / N
        self.rgba = np.zeros((n, n, 4), np.uint8)

    def put(self, m, color):
        self.rgba[m] = (*color[:3], 255)

    def shape(self, m, pal, ow=OW, shade=True, hi=True, sd=None, hd=None):
        """A filled shape: own-hue outline, base fill, darker lower band, lighter upper band."""
        self.put(m, pal.outline)
        inner = erode(m, ow * self.k) if ow else m
        self.put(inner, pal.base)
        h = box_h(m) / self.k
        lo = np.zeros_like(m)
        if shade:
            d = sd if sd is not None else max(8, min(30, h * 0.1))
            lo = inner & ~shift(inner, 0, -int(d * self.k))
            self.put(lo, pal.shade)
        if hi:
            d = hd if hd is not None else max(6, min(16, h * 0.055))
            up = inner & ~shift(inner, 0, int(d * self.k)) & ~lo
            self.put(up, pal.hi)
        return inner

    def flat(self, m, color):
        self.put(m, color)

    def done(self, center=True):
        _SIZE.pop()
        img = Image.fromarray(self.rgba, "RGBA")
        if center:
            x0, y0, x1, y1 = img.getbbox()
            dx = round((self.n - (x1 - x0)) / 2 - x0)
            dy = round((self.n - (y1 - y0)) / 2 - y0)
            out = Image.new("RGBA", img.size, (0, 0, 0, 0))
            out.paste(img, (dx, dy))
            img = out
        return img


# --- icons ---------------------------------------------------------------------------------
# Content area is roughly 51..461 (10% padding). Icons are re-centred on their bounding box.

def badge(pal, glyph):
    ic = Icon()
    ic.shape(circ(256, 256, 202), pal, sd=28, hd=14)
    ic.flat(glyph, GLYPH)
    return ic.done()


def icon_check():
    return badge(GREEN, line([(160, 262), (226, 328), (352, 196)], 54))


def icon_close():
    return badge(RED, U(line([(180, 180), (332, 332)], 54), line([(332, 180), (180, 332)], 54)))


def icon_info():
    return badge(BLUE, U(circ(256, 152, 34), rrect(226, 214, 286, 368, 30)))


def icon_play():
    return badge(ORANGE, rounded(poly([(206, 152), (206, 360), (378, 256)]), 22))


def arrow(rot):
    ic = Icon()
    with xf(rot=rot):
        m = poly([(76, 200), (236, 200), (236, 100), (438, 256), (236, 412), (236, 312), (76, 312)])
    ic.shape(rounded(m, 24), CREAM)
    return ic.done()


def icon_arrow_right():
    return arrow(0)


def icon_arrow_left():
    return arrow(180)


def icon_arrow_up():
    return arrow(-90)


def icon_arrow_down():
    return arrow(90)


def icon_clock():
    ic = Icon()
    ic.shape(rrect(226, 54, 286, 100, 14), BLUE, shade=False, hi=False)  # crown button
    ic.shape(line([(256, 92), (256, 120)], 34), BLUE, shade=False, hi=False)
    ic.shape(line([(360, 112), (384, 136)], 34), BLUE, shade=False, hi=False)  # side button
    ic.shape(circ(256, 280, 182), BLUE, sd=24)
    ic.shape(circ(256, 280, 134), CREAM, shade=False, hi=False)
    ink = BLUE.outline
    for a in range(0, 360, 90):
        x, y = 256 + 104 * math.cos(math.radians(a)), 280 + 104 * math.sin(math.radians(a))
        ic.flat(circ(x, y, 10), CREAM.shade)
    ic.flat(line([(256, 280), (256, 196)], 22), ink)
    ic.flat(line([(256, 280), (318, 318)], 22), RED.base)
    ic.flat(circ(256, 280, 18), ink)
    return ic.done()


def person(cx, top, scale):
    with xf(center=(cx, top), scale=scale, dx=0):
        head = circ(cx, top + 64, 64)
        body = inter(ell(cx, top + 270, 128, 120), rrect(cx - 200, top + 140, cx + 200, top + 330, 0))
        body = rounded(body, 20)
    return head, body


def icon_users():
    ic = Icon()
    h2, b2 = person(330, 70, 0.86)
    ic.shape(b2, BLUE_LIGHT)
    ic.shape(h2, BLUE_LIGHT)
    h1, b1 = person(210, 120, 1.0)
    ic.shape(b1, BLUE)
    ic.shape(h1, BLUE)
    return ic.done()


def icon_vote():
    ic = Icon()
    with xf(rot=-6, center=(256, 200)):
        paper = rrect(170, 70, 342, 300, 18)
        tick = line([(208, 170), (244, 206), (302, 136)], 30)
    slot_y = 252
    ic.shape(inter(paper, poly([(0, 0), (512, 0), (512, slot_y), (0, slot_y)])), CREAM, shade=False)
    ic.flat(tick, GREEN.base)
    ic.shape(rrect(80, 236, 432, 452, 30), BLUE, sd=26)
    ic.flat(rrect(150, slot_y - 12, 362, slot_y + 12, 12), BLUE.outline)
    ic.flat(rrect(206, 330, 306, 352, 11), BLUE.hi)
    return ic.done()


def draw_hen(ic):
    """White hen in side view, running to the right."""
    leg_w = 24
    ic.shape(U(line([(226, 344), (186, 396), (124, 420)], leg_w), line([(124, 420), (100, 406)], leg_w),
               line([(276, 344), (312, 390), (300, 452)], leg_w), line([(300, 452), (340, 452)], leg_w)),
             ORANGE, shade=False, hi=False)
    ic.shape(U(ell(116, 184, 46, 86, rot=-22), ell(92, 232, 40, 72, rot=-52)), CREAM)  # tail
    comb = rounded(U(circ(312, 84, 30), circ(348, 76, 30), circ(378, 94, 26), rrect(298, 86, 386, 122, 10)), 6)
    ic.shape(comb, RED, shade=False)
    with xf(rot=-12, center=(236, 260)):
        body = ell(236, 262, 160, 112)
    head_neck = U(circ(336, 152, 74), poly([(272, 160), (402, 160), (360, 290), (240, 280)]))
    ic.shape(smooth(U(body, head_neck), 18), CREAM)
    ic.shape(rounded(poly([(398, 130), (460, 158), (398, 186)]), 8), ORANGE, shade=False, hi=False)  # beak
    ic.shape(ell(392, 206, 18, 28), RED, shade=False, hi=False)  # wattle
    ic.flat(circ(350, 140, 15), CHARCOAL.outline)  # eye
    wing = tear(236, 262, 64, 116, 226)
    ic.shape(rounded(wing, 10), Pal(CREAM.outline, CREAM.shade, CREAM.shade, CREAM.base), shade=False, hd=8)


def icon_chicken_run():
    ic = Icon()
    with xf(rot=-6, center=(256, 256)):
        draw_hen(ic)
    return ic.done()


def icon_chicken():
    """Hen's head, facing right (the skins tab)."""
    ic = Icon()
    comb = rounded(U(circ(192, 112, 42), circ(248, 88, 48), circ(304, 106, 40), rrect(166, 112, 324, 170, 10)), 8)
    ic.shape(comb, RED, shade=False)
    ic.shape(circ(244, 286, 172), CREAM, sd=26)
    ic.shape(ell(388, 350, 30, 46), RED, shade=False, hi=False)
    ic.shape(rounded(poly([(366, 240), (466, 278), (366, 316)]), 10), ORANGE, shade=False)
    ic.flat(circ(316, 232, 22), CHARCOAL.outline)
    ic.flat(circ(309, 224, 7), CREAM.base)
    ic.flat(ell(196, 316, 36, 22), (255, 196, 170))
    return ic.done()


def icon_chick():
    ic = Icon()
    ic.shape(U(line([(220, 410), (220, 446)], 22), line([(220, 446), (194, 446)], 22),
               line([(286, 410), (286, 446)], 22), line([(286, 446), (260, 446)], 22)), ORANGE,
             shade=False, hi=False)
    tuft = U(ell(282, 72, 16, 34, rot=-20), ell(306, 80, 13, 28, rot=24))
    ic.shape(tuft, YELLOW, shade=False, hi=False)
    body = smooth(U(circ(240, 310, 150), circ(296, 176, 108)), 20)
    ic.shape(body, YELLOW, sd=28)
    ic.shape(rounded(poly([(384, 160), (448, 186), (384, 212)]), 8), ORANGE, shade=False, hi=False)
    ic.flat(circ(338, 160, 17), YELLOW.outline)
    wing = tear(214, 306, 54, 108, 270)
    ic.shape(rounded(wing, 10), Pal(YELLOW.outline, YELLOW.shade, YELLOW.shade, YELLOW.base), shade=False, hd=8)
    return ic.done()


def icon_trophy():
    ic = Icon()
    ic.shape(ring(132, 160, 58, 30), GOLD, shade=False, hi=False)
    ic.shape(ring(380, 160, 58, 30), GOLD, shade=False, hi=False)
    bowl = U(inter(ell(256, 92, 142, 226), rrect(0, 92, 512, 512, 0)), rrect(114, 72, 398, 112, 12))
    bowl = inter(bowl, rrect(0, 0, 512, 318, 0))
    ic.shape(rounded(bowl, 10), GOLD)
    ic.shape(poly([(232, 300), (280, 300), (300, 372), (212, 372)]), GOLD, hi=False)
    ic.shape(rrect(150, 366, 362, 446, 20), WOOD)
    ic.flat(rrect(206, 392, 306, 412, 10), WOOD.hi)
    ic.flat(rounded(poly(star_pts(256, 182, 62, 27)), 4), GOLD.hi)
    return ic.done()


def icon_lightning():
    ic = Icon()
    with xf(scale=1.1):
        m = poly([(292, 52), (124, 286), (238, 286), (206, 462), (392, 210), (274, 210)])
    ic.shape(rounded(m, 14), GOLD, sd=24)
    return ic.done()


def face(pal):
    ic = Icon()
    ic.shape(circ(256, 256, 200), pal, sd=28)
    return ic


def icon_emote():
    ic = face(YELLOW)
    ink = YELLOW.outline
    ic.flat(ell(196, 214, 24, 36), ink)
    ic.flat(ell(316, 214, 24, 36), ink)
    ic.flat(arc(256, 270, 100, 28, 152, 28), ink)
    ic.flat(ell(152, 300, 30, 20), (255, 176, 96))
    ic.flat(ell(360, 300, 30, 20), (255, 176, 96))
    return ic.done()


def icon_angry():
    ic = face(TOMATO)
    ink = TOMATO.outline
    ic.flat(line([(150, 182), (228, 220)], 30), ink)
    ic.flat(line([(362, 182), (284, 220)], 30), ink)
    ic.flat(circ(204, 262, 24), ink)
    ic.flat(circ(308, 262, 24), ink)
    ic.flat(arc(256, 400, 82, 222, 318, 28), ink)
    return ic.done()


def flag(pal, flip=False):
    ic = Icon()
    with xf(flip=flip):
        top, bot = [], []
        for i in range(25):
            x = 150 + 290 * i / 24
            ph = (i / 24) * math.tau * 0.85
            off = 22 * math.sin(ph)
            top.append((x, 92 + off))
            bot.append((x, 286 + off))
        cloth = rounded(poly(top + bot[::-1]), 16)
        pole = line([(140, 84), (140, 456)], 38)
        knob = circ(140, 72, 30)
    ic.shape(cloth, pal)
    ic.shape(pole, WOOD, shade=False)
    ic.shape(knob, GOLD, shade=False)
    return ic.done()


def icon_flag_red():
    return flag(RED)


def icon_flag_blue():
    return flag(BLUE)


def icon_team():
    ic = Icon()

    def one(pal, mirror):
        with xf(flip=mirror):
            # pole leans from bottom-right to top-left; cloth flies to the left of the pole top
            px0, py0, px1, py1 = 330, 456, 178, 74

            def pole_x(y):
                return px1 + (y - py1) * (px0 - px1) / (py0 - py1)
            top, bot = [], []
            for i in range(17):
                t = i / 16
                y_t = 90 + 4 * t
                x = pole_x(y_t) - 4 - 168 * t
                off = 16 * math.sin(t * math.tau * 0.8)
                top.append((x, 92 + off + 4 * t))
                bot.append((pole_x(236) - 4 - 168 * t, 236 + off + 4 * t))
            cloth = rounded(poly(top + bot[::-1]), 12)
            pole = line([(px0, py0), (px1, py1)], 34)
            knob = circ(px1 - 2, py1 - 6, 27)
        return cloth, pole, knob

    rc, rp, rk = one(RED, False)
    bc, bp, bk = one(BLUE, True)
    ic.shape(bp, WOOD, shade=False)
    ic.shape(rp, WOOD, shade=False)
    ic.shape(bc, BLUE)
    ic.shape(rc, RED)
    ic.shape(bk, GOLD, shade=False)
    ic.shape(rk, GOLD, shade=False)
    return ic.done()


def icon_egg_coin():
    ic = Icon()
    ic.shape(egg(256, 256, 150, 198), GOLD, sd=30)
    ic.flat(ell(198, 168, 22, 44, rot=24), GOLD.hi)
    return ic.done()


def icon_egg():
    ic = Icon()
    ic.shape(egg(256, 256, 150, 198), CREAM, sd=30)
    ic.flat(ell(198, 168, 22, 44, rot=24), (255, 255, 255))
    return ic.done()


def icon_egg_crack():
    ic = Icon()
    whole = egg(256, 270, 146, 186)
    zig = [(40, 236), (150, 236), (190, 280), (236, 226), (282, 280), (326, 226), (368, 270), (472, 270)]
    below = poly(zig + [(472, 512), (40, 512)])
    bottom = inter(whole, below)
    with xf(rot=-16, center=(140, 240), dy=-34):
        top = inter(egg(256, 270, 146, 186), poly(zig + [(472, 0), (40, 0)]))
    ic.shape(rounded(top, 6), CREAM)
    ic.shape(rounded(bottom, 6), CREAM, sd=26)
    return ic.done()


def icon_shop():
    ic = Icon()
    ic.shape(arc(256, 176, 76, 180, 360, 26), RED, shade=False, hi=False)
    body = rounded(poly([(108, 170), (404, 170), (430, 450), (82, 450)]), 26)
    ic.shape(body, RED, sd=28)
    ic.flat(rrect(108, 214, 404, 232, 9), RED.shade)
    ic.flat(circ(180, 196, 13), RED.outline)
    ic.flat(circ(332, 196, 13), RED.outline)
    ic.flat(rounded(poly(star_pts(256, 330, 58, 25)), 4), GOLD.base)
    return ic.done()


def icon_speaker(mute=False):
    ic = Icon()
    body = rounded(U(rrect(70, 194, 170, 318, 10), poly([(150, 194), (284, 92), (284, 420), (150, 318)])), 18)
    ic.shape(body, CREAM)
    if mute:
        ic.shape(U(line([(330, 204), (434, 308)], 46), line([(434, 204), (330, 308)], 46)), RED, shade=False)
    else:
        ic.shape(arc(276, 256, 72, -46, 46, 42), CREAM, shade=False, hi=False)
        ic.shape(arc(276, 256, 146, -46, 46, 42), CREAM, shade=False, hi=False)
    return ic.done()


def icon_speaker_mute():
    return icon_speaker(True)


def icon_eye():
    ic = Icon()
    R, d = 228, 108
    almond = rounded(inter(circ(256, 256 - d, R), circ(256, 256 + d, R)), 24)
    ic.shape(almond, CREAM, shade=False)
    iris = inter(circ(256, 256, 84), erode(almond, 10))
    ic.shape(iris, BLUE, shade=False, hi=False)
    ic.flat(circ(256, 256, 38), BLUE.outline)
    ic.flat(circ(282, 226, 16), (255, 255, 255))
    return ic.done()


def icon_lock():
    ic = Icon()
    ic.shape(line([(164, 264), (164, 196)] + arc_pts(256, 196, 92, 180, 360) + [(348, 196), (348, 264)], 46),
             STEEL, shade=False)
    ic.shape(rrect(100, 236, 412, 450, 40), GOLD, sd=26)
    ink = GOLD.outline
    ic.flat(circ(256, 322, 30), ink)
    ic.flat(rounded(poly([(240, 330), (272, 330), (282, 392), (230, 392)]), 6), ink)
    return ic.done()


def icon_star():
    ic = Icon()
    ic.shape(rounded(poly(star_pts(256, 270, 222, 100)), 22), GOLD, sd=28)
    return ic.done()


def icon_crown():
    ic = Icon()
    for x, y in ((92, 150), (256, 98), (420, 150)):
        ic.shape(circ(x, y, 28), GOLD, shade=False)
    top = poly([(92, 330), (92, 160), (176, 252), (256, 112), (336, 252), (420, 160), (420, 330)])
    ic.shape(rounded(top, 10), GOLD, sd=10)
    ic.shape(rrect(80, 316, 432, 412, 22), GOLD, sd=22)
    ic.shape(circ(256, 364, 28), RED, shade=False)
    ic.flat(circ(164, 364, 13), GOLD.outline)
    ic.flat(circ(348, 364, 13), GOLD.outline)
    return ic.done()


def icon_barn():
    ic = Icon()
    body = poly([(86, 456), (86, 252), (134, 156), (256, 92), (378, 156), (426, 252), (426, 456)])
    ic.shape(body, RED, hi=False, sd=0.001)
    trim = line([(70, 266), (124, 150), (256, 78), (388, 150), (442, 266)], 42)
    ic.shape(trim, CREAM, shade=False, hi=False)
    door_out = (178, 296, 334, 456)
    door_in = (204, 322, 308, 456)
    inner = rrect(*door_in, 0)
    frame = sub(rrect(*door_out, 0), inner)
    braces = inter(U(line([(door_in[0], door_in[1]), (door_in[2], door_in[3])], 24),
                     line([(door_in[2], door_in[1]), (door_in[0], door_in[3])], 24)), inner)
    ic.flat(inner, RED.shade)
    ic.shape(U(frame, braces), CREAM, shade=False, hi=False)
    ic.shape(rrect(222, 166, 290, 234, 6), CREAM, shade=False, hi=False)
    ic.flat(rrect(238, 182, 274, 218, 2), RED.outline)
    return ic.done()


def icon_windmill():
    ic = Icon()
    ic.shape(poly([(186, 214), (326, 214), (362, 456), (150, 456)]), CREAM, sd=0.001)
    ic.shape(rrect(228, 370, 284, 456, 28), WOOD, shade=False, hi=False)
    ic.shape(inter(circ(256, 224, 90), rrect(0, 0, 512, 236, 0)), RED, shade=False)
    hub = (256, 196)
    for a in (45, 135, 225, 315):
        with xf(rot=a, center=hub):
            ic.shape(rrect(290, 162, 438, 230, 10), WOOD_LIGHT, shade=False, hi=False)
            ic.flat(U(line([(304, 196), (424, 196)], 9), line([(364, 176), (364, 216)], 9)), WOOD_LIGHT.outline)
    ic.shape(line([(222, 196), (290, 196)], 20), WOOD, shade=False, hi=False)
    ic.shape(circ(*hub, 32), GOLD, shade=False)
    return ic.done()


def icon_car():
    ic = Icon()
    cabin = poly([(140, 262), (188, 146), (338, 146), (398, 262)])
    body = rounded(U(rrect(52, 238, 460, 378, 46), rounded(cabin, 30)), 6)
    ic.shape(body, RED, sd=22)
    with xf():
        w1 = rounded(poly([(180, 246), (210, 176), (252, 176), (252, 246)]), 12)
        w2 = rounded(poly([(276, 246), (276, 176), (324, 176), (360, 246)]), 12)
    ic.shape(w1, GLASS, shade=False)
    ic.shape(w2, GLASS, shade=False)
    ic.shape(rrect(420, 268, 452, 302, 10), GOLD, shade=False, hi=False)
    for x in (154, 358):
        ic.shape(circ(x, 378, 58), CHARCOAL, shade=False, hi=False)
        ic.shape(circ(x, 378, 24), STEEL, shade=False, hi=False)
    return ic.done()


def icon_boom():
    ic = Icon()
    pts = []
    for i in range(20):
        r = (214 if i % 4 == 0 else 176) if i % 2 == 0 else 128
        a = math.radians(-90 + i * 18)
        pts.append((256 + r * math.cos(a), 256 + r * math.sin(a)))
    ic.shape(rounded(poly(pts), 10), ORANGE, sd=22)
    ic.shape(rounded(poly(star_pts(256, 256, 118, 74, points=8, rot=-67.5)), 10), YELLOW, sd=14)
    return ic.done()


def icon_feather():
    ic = Icon()
    with xf(rot=38, center=(256, 256)):
        R, d = 300, 222
        leaf = inter(circ(256 - d, 230, R), circ(256 + d, 230, R))
        leaf = sub(leaf, poly([(340, 170), (282, 206), (340, 196)]), poly([(170, 280), (230, 300), (170, 306)]))
        leaf = rounded(leaf, 8)
        quill = line([(256, 340), (256, 462)], 18)
        vein = line([(256, 100), (256, 380)], 8)
    ic.shape(quill, CREAM, shade=False, hi=False)
    ic.shape(leaf, CREAM)
    ic.flat(vein, CREAM.shade)
    return ic.done()


def icon_gift():
    ic = Icon()
    ic.shape(ell(196, 132, 66, 40, rot=24), GOLD, shade=False)
    ic.shape(ell(316, 132, 66, 40, rot=-24), GOLD, shade=False)
    ic.shape(rrect(100, 236, 412, 450, 22), RED, sd=26)
    ic.shape(rrect(80, 172, 432, 252, 20), RED, sd=14)
    ic.shape(rrect(228, 172, 284, 450, 6), GOLD, shade=False)
    ic.shape(circ(256, 164, 32), GOLD, shade=False)
    return ic.done()


def icon_basket():
    ic = Icon()
    ic.shape(arc(256, 260, 146, 180, 360, 30), WOOD, shade=False, hi=False)
    ic.shape(egg(206, 218, 54, 70), CREAM, shade=False)
    ic.shape(egg(304, 208, 56, 74), GOLD, shade=False)
    body = rounded(poly([(92, 262), (420, 262), (382, 450), (130, 450)]), 22)
    ic.shape(body, WOOD, sd=20)
    for y in (330, 390):
        ic.flat(rrect(110, y - 7, 402, y + 7, 7), WOOD.shade)
    ic.shape(rrect(70, 236, 442, 292, 26), WOOD_LIGHT, sd=12)
    return ic.done()


def icon_nest():
    ic = Icon()
    ic.shape(ell(256, 290, 196, 56), STRAW, shade=False, hi=False)
    ic.flat(ell(256, 296, 150, 34), STRAW.outline)
    ic.shape(egg(184, 250, 58, 74), CREAM, shade=False)
    ic.shape(egg(328, 250, 58, 74), CREAM, shade=False)
    ic.shape(egg(256, 230, 62, 80), GOLD, shade=False)
    bowl = rounded(U(inter(ell(256, 290, 200, 150), rrect(0, 300, 512, 512, 0)), ell(256, 304, 200, 30)), 10)
    ic.shape(bowl, STRAW, sd=24)
    for (x0, y0, x1, y1) in ((128, 350, 230, 330), (250, 372, 380, 344), (170, 404, 300, 392)):
        ic.flat(line([(x0, y0), (x1, y1)], 10), STRAW.shade)
    return ic.done()


def icon_cloud():
    ic = Icon()
    m = U(circ(178, 268, 92), circ(270, 210, 120), circ(356, 280, 82), rrect(86, 250, 438, 372, 61))
    ic.shape(smooth(m, 12), CLOUD, sd=24)
    return ic.done()


def icon_sun():
    ic = Icon()
    ic.shape(rounded(poly(star_pts(256, 256, 212, 150, points=12, rot=-90)), 14), ORANGE, hi=False, sd=14)
    ic.shape(circ(256, 256, 132), GOLD, sd=24)
    return ic.done()


def leaf_poly(base, tip, bulge, side):
    """A leaf from base to tip bulging to one side (side = +1 right, -1 left)."""
    bx, by = base
    tx, ty = tip
    dx, dy = tx - bx, ty - by
    length = math.hypot(dx, dy)
    nx, ny = -dy / length * side, dx / length * side
    pts = []
    for i in range(41):
        t = i / 40
        w = bulge * math.sin(math.pi * t) * (1 - 0.35 * t)
        pts.append((bx + dx * t + nx * w, by + dy * t + ny * w))
    for i in range(41):
        t = 1 - i / 40
        w = bulge * 0.18 * math.sin(math.pi * t)
        pts.append((bx + dx * t - nx * w, by + dy * t - ny * w))
    return poly(pts)


def icon_corn():
    ic = Icon()
    with xf(rot=18, center=(256, 256)):
        cob = ell(256, 214, 84, 168)
        ic.shape(cob, YELLOW, shade=False)
        inner = erode(cob, OW + 4)
        grid = np.zeros_like(cob)
        for x in (214, 256, 298):
            grid |= line([(x, 40), (x, 400)], 8)
        for y in range(96, 380, 40):
            grid |= line([(150, y), (360, y)], 8)
        ic.flat(inter(grid, inner), YELLOW.shade)
        ic.shape(leaf_poly((250, 456), (166, 186), 76, 1), GREEN)
        ic.shape(leaf_poly((262, 456), (346, 196), 76, -1), GREEN)
    return ic.done()


def icon_fire():
    ic = Icon()
    outer = smooth(U(tear(256, 318, 136, 276, 44), tear(170, 340, 74, 108, 190), tear(342, 338, 78, 408, 200)), 26)
    ic.shape(outer, ORANGE, sd=26)
    ic.shape(tear(256, 362, 80, 262, 196), YELLOW, sd=16)
    return ic.done()


def icon_sparkle():
    ic = Icon()
    ic.shape(sparkle(220, 284, 176), GOLD, sd=24)
    ic.shape(sparkle(380, 132, 74), GOLD, sd=12)
    return ic.done()


def icon_heart():
    ic = Icon()
    pts = []
    for i in range(240):
        t = math.tau * i / 240
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((256 + 12.6 * x, 236 + 12.6 * y))
    ic.shape(rounded(poly(pts), 16), RED, sd=28)
    ic.flat(ell(166, 184, 24, 38, rot=-34), RED.hi)
    return ic.done()


def icon_skull():
    ic = Icon()
    bone = Pal(CREAM.outline, (230, 214, 186), CREAM.base, CREAM.hi)
    ic.shape(smooth(U(circ(256, 222, 168), rrect(164, 290, 348, 440, 44)), 14), bone, sd=22)
    ink = (110, 76, 52)
    ic.flat(ell(192, 248, 48, 52), ink)
    ic.flat(ell(320, 248, 48, 52), ink)
    ic.flat(rounded(poly([(256, 304), (282, 350), (230, 350)]), 6), ink)
    for x in (226, 286):
        ic.flat(line([(x, 396), (x, 438)], 12), CREAM.outline)
    return ic.done()


def icon_coin():
    ic = Icon()
    ic.shape(circ(256, 256, 200), GOLD, sd=30)
    ic.flat(ring(256, 256, 146, 14), GOLD.shade)
    ic.flat(rounded(poly(star_pts(256, 262, 86, 38)), 8), GOLD.shade)
    return ic.done()


def icon_gear():
    ic = Icon()
    teeth = [poly([(256 + math.cos(math.radians(a)) * r - math.sin(math.radians(a)) * w,
                    256 + math.sin(math.radians(a)) * r + math.cos(math.radians(a)) * w)
                   for r, w in ((120, -46), (212, -36), (212, 36), (120, 46))])
             for a in range(0, 360, 45)]
    m = sub(U(circ(256, 256, 160), *teeth), circ(256, 256, 62))
    ic.shape(smooth(m, 12), STEEL, sd=22)
    return ic.done()


def icon_note():
    ic = Icon()
    heads = U(ell(166, 380, 66, 50, rot=-22), ell(366, 344, 66, 50, rot=-22))
    stems = U(rrect(196, 132, 230, 384, 6), rrect(396, 98, 430, 346, 6))
    beam = poly([(196, 120), (430, 82), (430, 146), (196, 184)])
    ic.shape(smooth(U(heads, stems, beam), 8), PINK, sd=22)
    return ic.done()


def icon_horseshoe():
    ic = Icon()
    m = arc(256, 236, 150, -36, 216, 86)
    ic.shape(m, STEEL, sd=24)
    ink = STEEL.outline
    for a in (-16, 20, 56, 124, 160, 196):
        x, y = 256 + 150 * math.cos(math.radians(a)), 236 + 150 * math.sin(math.radians(a))
        with xf(rot=a + 90, center=(x, y)):
            ic.flat(rrect(x - 8, y - 15, x + 8, y + 15, 7), ink)
    return ic.done()


def icon_wheat():
    ic = Icon()
    with xf(rot=16, center=(256, 256), scale=1.08):
        ic.shape(line([(256, 150), (256, 462)], 22), STRAW, shade=False, hi=False)
        ic.shape(leaf_poly((256, 452), (180, 330), 34, 1), GREEN, shade=False)
        ic.shape(ell(256, 92, 34, 54), STRAW, shade=False)
        for y in (154, 220, 286):
            ic.shape(ell(214, y, 34, 56, rot=-34), STRAW, shade=False)
            ic.shape(ell(298, y, 34, 56, rot=34), STRAW, shade=False)
    return ic.done()


def icon_hay_bale():
    ic = Icon()
    ic.shape(rrect(62, 132, 450, 420, 44), STRAW, sd=26)
    ink = STRAW.shade
    for (x0, y0, x1) in ((110, 196, 170), (300, 186, 380), (120, 300, 200), (290, 330, 340), (190, 372, 260),
                         (220, 240, 270), (360, 262, 412)):
        ic.flat(line([(x0, y0), (x1, y0)], 9), ink)
    for x in (172, 340):
        ic.shape(rrect(x - 16, 126, x + 16, 426, 8), WOOD, shade=False, hi=False)
    return ic.done()


def icon_pitchfork():
    ic = Icon()
    with xf(rot=28, center=(256, 256), scale=1.06):
        ic.shape(line([(256, 236), (256, 476)], 42), WOOD, shade=False)
        prongs = U(arc(256, 132, 88, 0, 180, 34), line([(168, 132), (168, 44)], 34),
                   line([(344, 132), (344, 44)], 34), line([(256, 220), (256, 44)], 34))
        ic.shape(prongs, STEEL, shade=False)
        ic.shape(rrect(226, 208, 286, 266, 12), STEEL, shade=False)
    return ic.done()


def icon_bell():
    ic = Icon()
    ic.shape(ring(256, 82, 26, 18), GOLD, shade=False, hi=False)
    ic.shape(circ(256, 414, 36), GOLD, shade=False)
    pts = []
    for i in range(41):
        y = 196 + 168 * i / 40
        pts.append((256 - (112 + 66 * (i / 40) ** 2.2), y))
    right = [(512 - x, y) for x, y in pts[::-1]]
    shell = U(circ(256, 196, 112), poly(pts + right))
    ic.shape(rounded(shell, 8), GOLD, sd=10)
    ic.shape(rrect(70, 348, 442, 404, 28), GOLD, sd=14)
    return ic.done()


def icon_footprint():
    ic = Icon()
    m = U(line([(256, 316), (146, 142)], 52), line([(256, 316), (256, 88)], 52), line([(256, 316), (366, 142)], 52),
          line([(256, 316), (256, 432)], 52), circ(256, 312, 46))
    ic.shape(smooth(m, 10), ORANGE, sd=22)
    return ic.done()


def icon_rosette():
    ic = Icon()
    for side in (-1, 1):
        with xf(flip=side < 0):
            tail = poly([(270, 250), (326, 230), (380, 448), (334, 420), (300, 462)])
            ic.shape(rounded(tail, 6), BLUE, shade=False)
    scallop = U(circ(256, 210, 150), *[circ(256 + 158 * math.cos(math.radians(a)), 210 + 158 * math.sin(math.radians(a)), 34)
                                         for a in range(0, 360, 24)])
    ic.shape(scallop, BLUE, sd=20)
    ic.shape(circ(256, 210, 108), GOLD, sd=18)
    ic.flat(rounded(poly(star_pts(256, 216, 64, 28)), 6), GOLD.hi)
    return ic.done()


def icon_afk():
    ic = Icon()
    big = line([(92, 248), (262, 248), (92, 436), (262, 436)], 60)
    small = line([(312, 96), (420, 96), (312, 214), (420, 214)], 44)
    ic.shape(small, BLUE_LIGHT, shade=False)
    ic.shape(big, BLUE, shade=False)
    return ic.done()


def big_egg():
    ic = Icon(N * 2)
    with xf(center=(0, 0), scale=2):
        ic.shape(egg(256, 268, 150, 196), GOLD, sd=30)
        ic.flat(ell(198, 182, 22, 44, rot=24), GOLD.hi)
        shine = Pal(GOLD.outline, GOLD.base, (255, 226, 120), (255, 246, 204))
        ic.shape(sparkle(412, 104, 50), shine, shade=False)
        ic.shape(sparkle(96, 388, 34), shine, shade=False, hi=False)
        ic.shape(sparkle(432, 304, 26), shine, shade=False, hi=False)
    return ic.done(center=False)


ICONS = [
    ("eggCoin", icon_egg_coin), ("egg", icon_egg), ("eggCrack", icon_egg_crack), ("chick", icon_chick),
    ("chicken", icon_chicken), ("chickenRun", icon_chicken_run), ("feather", icon_feather), ("footprint", icon_footprint),
    ("clock", icon_clock), ("users", icon_users), ("vote", icon_vote), ("trophy", icon_trophy),
    ("lightning", icon_lightning), ("angry", icon_angry), ("emote", icon_emote), ("team", icon_team),
    ("shop", icon_shop), ("basket", icon_basket), ("nest", icon_nest), ("gift", icon_gift),
    ("coin", icon_coin), ("star", icon_star), ("crown", icon_crown), ("rosette", icon_rosette),
    ("speaker", icon_speaker), ("speakerMute", icon_speaker_mute), ("eye", icon_eye), ("lock", icon_lock),
    ("check", icon_check), ("close", icon_close), ("info", icon_info), ("play", icon_play),
    ("arrowLeft", icon_arrow_left), ("arrowRight", icon_arrow_right), ("arrowUp", icon_arrow_up),
    ("arrowDown", icon_arrow_down), ("gear", icon_gear), ("note", icon_note), ("afk", icon_afk), ("heart", icon_heart),
    ("barn", icon_barn), ("windmill", icon_windmill), ("car", icon_car), ("boom", icon_boom),
    ("fire", icon_fire), ("sparkle", icon_sparkle), ("skull", icon_skull), ("bell", icon_bell),
    ("flagRed", icon_flag_red), ("flagBlue", icon_flag_blue), ("horseshoe", icon_horseshoe), ("wheat", icon_wheat),
    ("hayBale", icon_hay_bale), ("pitchfork", icon_pitchfork), ("corn", icon_corn), ("sun", icon_sun),
    ("cloud", icon_cloud),
]
BIG_EGG_CELL = (6, 6)  # bigEgg fills the 2x2 cells in the bottom-right corner


def main():
    sheet = Image.new("RGBA", (SHEET, SHEET), (0, 0, 0, 0))
    per_row = SHEET // CELL
    taken = {(BIG_EGG_CELL[0] + i, BIG_EGG_CELL[1] + j) for i in (0, 1) for j in (0, 1)}
    free = [(c, r) for r in range(per_row) for c in range(per_row) if (c, r) not in taken]
    assert len(ICONS) <= len(free), "too many icons for the sheet"
    entries = []
    for (name, fn), (col, row) in zip(ICONS, free):
        x, y = col * CELL, row * CELL
        sheet.alpha_composite(fn().resize((CELL, CELL), Image.LANCZOS), (x, y))
        entries.append((name, x, y, CELL, CELL))
    bx, by = BIG_EGG_CELL[0] * CELL, BIG_EGG_CELL[1] * CELL
    sheet.alpha_composite(big_egg().resize((CELL * 2, CELL * 2), Image.LANCZOS), (bx, by))
    entries.append(("bigEgg", bx, by, CELL * 2, CELL * 2))

    os.makedirs(os.path.dirname(OUT_PNG), exist_ok=True)
    sheet.save(OUT_PNG, optimize=True)

    lines = [
        "--!strict",
        "-- GENERATED by tools/art/make_icon_sheet.py - do not edit by hand.",
        "-- Where each icon sits on the clean icon sheet (assets/ui/IconSheet.png).",
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
