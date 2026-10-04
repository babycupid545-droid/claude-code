"""Draws the game's UI sprite sheet: one 1024x1024 PNG holding every icon and decorative image.

Uploading a single image means the game needs just one image id. Each icon sits in a
128x128 cell; src/shared/UiSprites.luau (written by this script) maps names to cells.

Run: python3 tools/art/make_ui_sheet.py
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_PNG = os.path.join(ROOT, "assets", "ui", "UiSheet.png")
OUT_LUAU = os.path.join(ROOT, "src", "shared", "UiSprites.luau")

CELL = 128
SS = 4  # supersampling factor for smooth edges
S = CELL * SS  # drawing size of one cell
SHEET = 1024

OUTLINE = (43, 29, 58, 255)
WHITE = (255, 255, 255, 255)
GOLD = (255, 201, 60, 255)
GOLD_DARK = (229, 140, 28, 255)
RED = (255, 77, 77, 255)
RED_DARK = (200, 40, 50, 255)
BLUE = (61, 165, 255, 255)
BLUE_DARK = (30, 100, 210, 255)
GREEN = (76, 217, 100, 255)
GREEN_DARK = (30, 160, 70, 255)
ORANGE = (255, 159, 28, 255)
PINK = (255, 111, 174, 255)
PURPLE = (168, 107, 255, 255)
GREY = (201, 204, 214, 255)
GREY_DARK = (130, 135, 150, 255)
CREAM = (255, 246, 222, 255)
YELLOW = (255, 225, 70, 255)
HIGHLIGHT = (255, 255, 255, 110)


class Icon:
    """A layered icon: colored shapes, then an automatic thick outline around them."""

    def __init__(self, size=S):
        self.size = size
        self.fill = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.fill)
        self.details = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        self.dd = ImageDraw.Draw(self.details)

    def render(self, outline=28):
        alpha = self.fill.split()[3].point(lambda a: 255 if a > 8 else 0)
        grown = alpha.filter(ImageFilter.MaxFilter(outline * 2 + 1)) if outline else alpha
        out = Image.new("RGBA", (self.size, self.size), (0, 0, 0, 0))
        out.paste(Image.new("RGBA", out.size, OUTLINE), mask=grown)
        # A soft drop shadow under the outline sells the "sticker" look.
        shadow = Image.new("RGBA", out.size, (0, 0, 0, 0))
        shadow.paste(Image.new("RGBA", out.size, (20, 10, 30, 90)), mask=grown)
        shadow = shadow.transform(out.size, Image.AFFINE, (1, 0, 0, 0, 1, -14))
        base = Image.alpha_composite(shadow, out)
        base = Image.alpha_composite(base, self.fill)
        base = Image.alpha_composite(base, self.details)
        return base


def circle(d, cx, cy, r, color):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)


def ring(d, cx, cy, r, color, width):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=width)


def star_points(cx, cy, r_out, r_in, points=5, rot=-90):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180 / points)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def highlight(d, box):
    d.ellipse(box, fill=HIGHLIGHT)


# --- icons ---------------------------------------------------------------------------------

def icon_coin():
    ic = Icon()
    circle(ic.d, 256, 256, 210, GOLD_DARK)
    circle(ic.d, 256, 240, 200, GOLD)
    ring(ic.dd, 256, 240, 150, GOLD_DARK, 22)
    ic.dd.polygon(star_points(256, 240, 95, 42), fill=(255, 236, 140, 255))
    highlight(ic.dd, [120, 90, 230, 170])
    return ic.render()


def icon_cart():
    ic = Icon()
    ic.d.line([(60, 110), (130, 110), (180, 330)], fill=GREY_DARK, width=34, joint="curve")
    ic.d.polygon([(140, 160), (450, 160), (410, 330), (180, 330)], fill=ORANGE)
    for x in (230, 300, 370):
        ic.dd.line([(x, 175), (x - 10, 315)], fill=(230, 120, 10, 255), width=14)
    circle(ic.d, 210, 410, 46, GREY_DARK)
    circle(ic.d, 380, 410, 46, GREY_DARK)
    circle(ic.dd, 210, 410, 18, GREY)
    circle(ic.dd, 380, 410, 18, GREY)
    highlight(ic.dd, [170, 175, 260, 215])
    return ic.render()


def icon_smile():
    ic = Icon()
    circle(ic.d, 256, 256, 205, YELLOW)
    ic.dd.ellipse([170, 160, 220, 250], fill=OUTLINE)
    ic.dd.ellipse([292, 160, 342, 250], fill=OUTLINE)
    ic.dd.arc([140, 170, 372, 380], 20, 160, fill=OUTLINE, width=26)
    circle(ic.dd, 150, 300, 30, (255, 150, 150, 160))
    circle(ic.dd, 362, 300, 30, (255, 150, 150, 160))
    highlight(ic.dd, [130, 90, 230, 150])
    return ic.render()


def icon_trophy():
    ic = Icon()
    ring(ic.d, 130, 200, 75, GOLD_DARK, 34)
    ring(ic.d, 382, 200, 75, GOLD_DARK, 34)
    ic.d.pieslice([120, 10, 392, 380], 0, 180, fill=GOLD)
    ic.d.rectangle([120, 70, 392, 196], fill=GOLD)
    ic.d.rectangle([226, 330, 286, 400], fill=GOLD_DARK)
    ic.d.rounded_rectangle([150, 390, 362, 460], 20, fill=GOLD)
    ic.dd.polygon(star_points(256, 200, 70, 30), fill=(255, 236, 140, 255))
    highlight(ic.dd, [150, 90, 210, 260])
    return ic.render()


def icon_egg():
    ic = Icon()
    ic.d.ellipse([120, 50, 392, 470], fill=CREAM)
    ic.d.chord([120, 50, 392, 470], 20, 160, fill=(240, 225, 195, 255))
    highlight(ic.dd, [170, 120, 240, 240])
    return ic.render()


def icon_chicken():
    ic = Icon()
    circle(ic.d, 200, 120, 46, RED)
    circle(ic.d, 260, 95, 52, RED)
    circle(ic.d, 320, 120, 46, RED)
    circle(ic.d, 256, 270, 175, WHITE)
    ic.d.polygon([(360, 250), (470, 290), (360, 330)], fill=ORANGE)
    ic.d.ellipse([340, 320, 395, 400], fill=RED)
    circle(ic.dd, 300, 230, 30, OUTLINE)
    circle(ic.dd, 310, 220, 10, WHITE)
    circle(ic.dd, 230, 310, 32, (255, 170, 170, 150))
    highlight(ic.dd, [130, 150, 210, 210])
    return ic.render()


def icon_clock():
    ic = Icon()
    circle(ic.d, 256, 270, 200, BLUE)
    circle(ic.d, 256, 270, 155, WHITE)
    ic.d.rounded_rectangle([206, 30, 306, 80], 14, fill=BLUE_DARK)
    for i in range(12):
        a = math.radians(i * 30)
        r1, r2 = 125, 145
        ic.dd.line([(256 + r1 * math.cos(a), 270 + r1 * math.sin(a)),
                    (256 + r2 * math.cos(a), 270 + r2 * math.sin(a))], fill=OUTLINE, width=12)
    ic.dd.line([(256, 270), (256, 160)], fill=OUTLINE, width=26)
    ic.dd.line([(256, 270), (330, 310)], fill=RED, width=22)
    circle(ic.dd, 256, 270, 20, OUTLINE)
    return ic.render()


def icon_skull():
    ic = Icon()
    circle(ic.d, 256, 220, 175, WHITE)
    ic.d.rounded_rectangle([160, 300, 352, 440], 40, fill=WHITE)
    ic.dd.ellipse([155, 180, 240, 280], fill=OUTLINE)
    ic.dd.ellipse([272, 180, 357, 280], fill=OUTLINE)
    ic.dd.polygon([(256, 290), (230, 340), (282, 340)], fill=OUTLINE)
    for x in (205, 256, 307):
        ic.dd.line([(x, 380), (x, 440)], fill=OUTLINE, width=14)
    return ic.render()


def icon_crown():
    ic = Icon()
    ic.d.polygon([(70, 400), (60, 150), (170, 260), (256, 100), (342, 260), (452, 150), (442, 400)], fill=GOLD)
    ic.d.rounded_rectangle([70, 360, 442, 440], 20, fill=GOLD_DARK)
    circle(ic.dd, 256, 300, 34, RED)
    circle(ic.dd, 150, 320, 24, BLUE)
    circle(ic.dd, 362, 320, 24, GREEN)
    for x, y in ((60, 150), (256, 100), (452, 150)):
        circle(ic.d, x, y, 30, GOLD)
    highlight(ic.dd, [120, 230, 200, 330])
    return ic.render()


def icon_check():
    ic = Icon()
    circle(ic.d, 256, 256, 205, GREEN)
    ic.dd.line([(150, 260), (225, 340), (370, 180)], fill=WHITE, width=56, joint="curve")
    highlight(ic.dd, [130, 90, 230, 150])
    return ic.render()


def icon_close():
    ic = Icon()
    ic.d.rounded_rectangle([60, 60, 452, 452], 90, fill=RED)
    ic.dd.line([(170, 170), (342, 342)], fill=WHITE, width=60)
    ic.dd.line([(342, 170), (170, 342)], fill=WHITE, width=60)
    highlight(ic.dd, [100, 90, 220, 140])
    return ic.render()


def icon_lock():
    ic = Icon()
    ic.d.arc([150, 50, 362, 300], 180, 360, fill=GREY_DARK, width=50)
    ic.d.rectangle([150, 170, 200, 240], fill=GREY_DARK)
    ic.d.rectangle([312, 170, 362, 240], fill=GREY_DARK)
    ic.d.rounded_rectangle([100, 220, 412, 460], 40, fill=GOLD)
    circle(ic.dd, 256, 310, 34, OUTLINE)
    ic.dd.rectangle([240, 320, 272, 390], fill=OUTLINE)
    highlight(ic.dd, [130, 240, 230, 290])
    return ic.render()


def icon_star():
    ic = Icon()
    ic.d.polygon(star_points(256, 270, 230, 100), fill=GOLD)
    ic.dd.polygon(star_points(256, 270, 120, 55), fill=(255, 236, 140, 255))
    return ic.render()


def icon_heart():
    ic = Icon()
    circle(ic.d, 180, 200, 115, PINK)
    circle(ic.d, 332, 200, 115, PINK)
    ic.d.polygon([(72, 240), (440, 240), (256, 450)], fill=PINK)
    highlight(ic.dd, [120, 130, 200, 200])
    return ic.render()


def icon_lightning():
    ic = Icon()
    ic.d.polygon([(300, 30), (120, 290), (240, 290), (190, 480), (390, 200), (270, 200), (340, 30)], fill=YELLOW)
    ic.dd.polygon([(300, 60), (170, 270), (230, 270)], fill=(255, 250, 200, 200))
    return ic.render()


def icon_car():
    ic = Icon()
    ic.d.rounded_rectangle([40, 220, 472, 380], 50, fill=RED)
    ic.d.polygon([(140, 230), (190, 120), (340, 120), (400, 230)], fill=RED)
    ic.dd.polygon([(175, 220), (210, 145), (262, 145), (262, 220)], fill=(180, 225, 255, 255))
    ic.dd.polygon([(280, 220), (280, 145), (325, 145), (365, 220)], fill=(180, 225, 255, 255))
    circle(ic.d, 140, 385, 60, OUTLINE)
    circle(ic.d, 372, 385, 60, OUTLINE)
    circle(ic.dd, 140, 385, 26, GREY)
    circle(ic.dd, 372, 385, 26, GREY)
    ic.dd.rounded_rectangle([430, 260, 470, 300], 10, fill=YELLOW)
    highlight(ic.dd, [80, 240, 200, 280])
    return ic.render()


def icon_note():
    ic = Icon()
    ic.d.ellipse([90, 330, 230, 440], fill=PURPLE)
    ic.d.ellipse([280, 290, 420, 400], fill=PURPLE)
    ic.d.rectangle([195, 110, 230, 390], fill=PURPLE)
    ic.d.rectangle([385, 70, 420, 350], fill=PURPLE)
    ic.d.polygon([(195, 110), (420, 50), (420, 130), (195, 190)], fill=PURPLE)
    return ic.render()


def icon_gear():
    ic = Icon()
    for i in range(8):
        a = i * 45
        tooth = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(tooth).rounded_rectangle([216, 40, 296, 140], 16, fill=GREY)
        ic.fill.alpha_composite(tooth.rotate(a, center=(256, 256)))
    circle(ic.d, 256, 256, 160, GREY)
    circle(ic.dd, 256, 256, 60, OUTLINE)
    return ic.render()


def icon_gift():
    ic = Icon()
    ic.d.rounded_rectangle([80, 200, 432, 450], 24, fill=RED)
    ic.d.rounded_rectangle([60, 150, 452, 240], 24, fill=RED_DARK)
    ic.dd.rectangle([226, 150, 286, 450], fill=YELLOW)
    ic.d.ellipse([130, 60, 256, 170], fill=YELLOW)
    ic.d.ellipse([256, 60, 382, 170], fill=YELLOW)
    return ic.render()


def icon_flag(color, dark):
    ic = Icon()
    ic.d.rounded_rectangle([90, 50, 130, 470], 14, fill=GREY_DARK)
    ic.d.polygon([(130, 70), (300, 40), (440, 100), (440, 280), (300, 230), (130, 270)], fill=color)
    ic.dd.polygon([(130, 200), (300, 170), (440, 220), (440, 280), (300, 230), (130, 270)], fill=dark)
    return ic.render()


def icon_vote():
    ic = Icon()
    ic.d.rounded_rectangle([170, 50, 380, 280], 16, fill=WHITE)
    ic.dd.line([(215, 160), (255, 200), (335, 110)], fill=GREEN, width=34, joint="curve")
    ic.d.rounded_rectangle([70, 240, 442, 460], 30, fill=BLUE)
    ic.dd.rounded_rectangle([150, 260, 362, 290], 10, fill=BLUE_DARK)
    highlight(ic.dd, [100, 300, 220, 350])
    return ic.render()


def icon_eye():
    ic = Icon()
    ic.d.chord([40, 100, 472, 420], 200, 340, fill=WHITE)
    ic.d.chord([40, 92, 472, 412], 20, 160, fill=WHITE)
    ic.d.ellipse([40, 160, 472, 352], fill=WHITE)
    circle(ic.dd, 256, 256, 95, BLUE)
    circle(ic.dd, 256, 256, 45, OUTLINE)
    circle(ic.dd, 280, 230, 18, WHITE)
    return ic.render()


def icon_arrow(direction):
    ic = Icon()
    pts = [(256, 50), (450, 260), (330, 260), (330, 460), (182, 460), (182, 260), (62, 260)]
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(img).polygon(pts, fill=WHITE)
    angle = {"up": 0, "left": 90, "down": 180, "right": -90}[direction]
    ic.fill.alpha_composite(img.rotate(angle, center=(256, 256)))
    return ic.render()


def icon_play():
    ic = Icon()
    circle(ic.d, 256, 256, 205, GREEN)
    ic.dd.polygon([(205, 150), (370, 256), (205, 362)], fill=WHITE)
    return ic.render()


def icon_sparkle():
    ic = Icon()
    ic.d.polygon(star_points(256, 256, 230, 55, points=4, rot=-90), fill=YELLOW)
    ic.dd.polygon(star_points(256, 256, 110, 30, points=4, rot=-90), fill=WHITE)
    circle(ic.d, 420, 100, 40, YELLOW)
    return ic.render()


def icon_fire():
    ic = Icon()
    ic.d.polygon([(256, 30), (360, 170), (410, 120), (430, 300), (370, 430), (256, 470),
                  (140, 430), (80, 300), (110, 170), (160, 230)], fill=ORANGE)
    ic.dd.polygon([(256, 200), (320, 300), (330, 380), (256, 430), (180, 380), (195, 300)], fill=YELLOW)
    return ic.render()


def icon_feather():
    ic = Icon()
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([186, 40, 326, 420], fill=WHITE)
    d.line([(256, 80), (256, 490)], fill=GREY_DARK, width=18)
    ic.fill.alpha_composite(img.rotate(-35, center=(256, 256)))
    return ic.render()


def icon_boom():
    ic = Icon()
    ic.d.polygon(star_points(256, 256, 235, 140, points=10), fill=ORANGE)
    ic.dd.polygon(star_points(256, 256, 140, 80, points=10, rot=-72), fill=YELLOW)
    circle(ic.dd, 256, 256, 50, WHITE)
    return ic.render()


def icon_users():
    ic = Icon()
    circle(ic.d, 330, 160, 75, BLUE_DARK)
    ic.d.pieslice([210, 250, 450, 520], 180, 360, fill=BLUE_DARK)
    circle(ic.d, 190, 190, 90, BLUE)
    ic.d.pieslice([50, 300, 330, 600], 180, 360, fill=BLUE)
    return ic.render()


def icon_angry():
    ic = Icon()
    circle(ic.d, 256, 256, 205, RED)
    ic.dd.line([(150, 170), (235, 215)], fill=OUTLINE, width=30)
    ic.dd.line([(362, 170), (277, 215)], fill=OUTLINE, width=30)
    ic.dd.ellipse([175, 220, 225, 280], fill=OUTLINE)
    ic.dd.ellipse([287, 220, 337, 280], fill=OUTLINE)
    ic.dd.arc([170, 320, 342, 450], 200, 340, fill=OUTLINE, width=26)
    return ic.render()


def icon_speaker(muted):
    ic = Icon()
    ic.d.rectangle([70, 190, 170, 320], fill=WHITE)
    ic.d.polygon([(160, 190), (300, 80), (300, 432), (160, 320)], fill=WHITE)
    if muted:
        ic.dd.line([(340, 190), (450, 320)], fill=RED, width=40)
        ic.dd.line([(450, 190), (340, 320)], fill=RED, width=40)
    else:
        ic.d.arc([250, 150, 400, 360], -50, 50, fill=WHITE, width=34)
        ic.d.arc([250, 90, 470, 420], -50, 50, fill=WHITE, width=34)
    return ic.render()


def icon_team():
    ic = Icon()
    ic.d.rounded_rectangle([60, 60, 90, 460], 10, fill=GREY_DARK)
    ic.d.polygon([(90, 70), (240, 50), (240, 230), (90, 250)], fill=RED)
    ic.d.rounded_rectangle([422, 60, 452, 460], 10, fill=GREY_DARK)
    ic.d.polygon([(422, 70), (272, 50), (272, 230), (422, 250)], fill=BLUE)
    return ic.render()


def icon_info():
    ic = Icon()
    circle(ic.d, 256, 256, 205, BLUE)
    circle(ic.dd, 256, 150, 34, WHITE)
    ic.dd.rounded_rectangle([226, 210, 286, 390], 20, fill=WHITE)
    return ic.render()


def icon_chicken_run():
    """Chicken silhouette for the logo / Solo mode."""
    ic = Icon()
    ic.d.ellipse([90, 180, 400, 420], fill=WHITE)
    circle(ic.d, 360, 170, 90, WHITE)
    circle(ic.d, 345, 70, 32, RED)
    circle(ic.d, 390, 80, 30, RED)
    ic.d.polygon([(430, 160), (500, 185), (430, 205)], fill=ORANGE)
    ic.d.polygon([(90, 250), (30, 170), (60, 300)], fill=WHITE)
    ic.d.line([(220, 400), (190, 480)], fill=ORANGE, width=22)
    ic.d.line([(290, 400), (330, 480)], fill=ORANGE, width=22)
    circle(ic.dd, 380, 155, 16, OUTLINE)
    ic.dd.arc([170, 240, 330, 360], 20, 160, fill=(220, 220, 230, 255), width=18)
    return ic.render()


ICONS = [
    ("coin", icon_coin), ("shop", icon_cart), ("emote", icon_smile), ("trophy", icon_trophy),
    ("egg", icon_egg), ("chicken", icon_chicken), ("clock", icon_clock), ("skull", icon_skull),
    ("crown", icon_crown), ("check", icon_check), ("close", icon_close), ("lock", icon_lock),
    ("star", icon_star), ("heart", icon_heart), ("lightning", icon_lightning), ("car", icon_car),
    ("note", icon_note), ("gear", icon_gear), ("gift", icon_gift),
    ("flagRed", lambda: icon_flag(RED, RED_DARK)), ("flagBlue", lambda: icon_flag(BLUE, BLUE_DARK)),
    ("vote", icon_vote), ("eye", icon_eye),
    ("arrowUp", lambda: icon_arrow("up")), ("arrowDown", lambda: icon_arrow("down")),
    ("arrowLeft", lambda: icon_arrow("left")), ("arrowRight", lambda: icon_arrow("right")),
    ("play", icon_play), ("sparkle", icon_sparkle), ("fire", icon_fire), ("feather", icon_feather),
    ("boom", icon_boom), ("users", icon_users), ("angry", icon_angry),
    ("speaker", lambda: icon_speaker(False)), ("speakerMute", lambda: icon_speaker(True)),
    ("team", icon_team), ("info", icon_info), ("chickenRun", icon_chicken_run),
]


# --- decorative images ---------------------------------------------------------------------

def sunburst(size):
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = big / 2
    rays = 16
    for i in range(rays):
        a0 = math.radians(i * 360 / rays)
        a1 = math.radians(i * 360 / rays + 360 / rays / 2)
        d.polygon([(c, c), (c + big * math.cos(a0), c + big * math.sin(a0)),
                   (c + big * math.cos(a1), c + big * math.sin(a1))], fill=(255, 255, 255, 255))
    # Fade rays out toward the edge.
    small = img.resize((size, size), Image.LANCZOS)
    px = small.load()
    half = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            r, g, b, a = px[x, y]
            dist = math.hypot(x - half, y - half) / half
            px[x, y] = (r, g, b, int(a * max(0.0, 1 - dist) ** 1.2))
    return small


def glow(size):
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    px = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            dist = math.hypot(x - c, y - c) / c
            a = max(0.0, 1 - dist) ** 2
            px[x, y] = (255, 255, 255, int(255 * a))
    return img


def splat(size):
    """Organic egg splat: random blobs, blurred and thresholded into a smooth shape."""
    import random
    big = size * SS
    rng = random.Random(7)
    mask = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(mask)
    c = big / 2
    circle(d, c, c * 0.95, big * 0.27, 255)
    for _ in range(14):
        a = rng.random() * math.tau
        r = big * (0.18 + rng.random() * 0.14)
        rr = big * (0.07 + rng.random() * 0.07)
        circle(d, c + r * math.cos(a), c * 0.95 + r * math.sin(a), rr, 255)
    for _ in range(9):  # flecks
        a = rng.random() * math.tau
        r = big * (0.38 + rng.random() * 0.08)
        circle(d, c + r * math.cos(a), c * 0.95 + r * math.sin(a), big * (0.015 + rng.random() * 0.02), 255)
    for _ in range(4):  # drips
        x = c + (rng.random() - 0.5) * big * 0.45
        w = big * (0.025 + rng.random() * 0.02)
        length = big * (0.25 + rng.random() * 0.2)
        d.rounded_rectangle([x - w, c, x + w, c + length], int(w), fill=255)
        circle(d, x, c + length, w * 1.5, 255)
    mask = mask.filter(ImageFilter.GaussianBlur(big * 0.012)).point(lambda a: 255 if a > 128 else 0)
    img = Image.new("RGBA", (big, big), (255, 252, 240, 0))
    img.putalpha(mask.point(lambda a: int(a * 0.93)))
    d2 = ImageDraw.Draw(img)
    yolk = (255, 196, 40, 255)
    circle(d2, c, c * 0.95, big * 0.15, yolk)
    circle(d2, c - big * 0.05, c * 0.95 - big * 0.05, big * 0.04, (255, 240, 180, 255))
    return img.resize((size, size), Image.LANCZOS)


def dots(size):
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    step = big // 4
    for row in range(4):
        for col in range(4):
            circle(d, col * step + step / 2, row * step + step / 2, big / 26, (255, 255, 255, 255))
    return img.resize((size, size), Image.LANCZOS)


def stripes(size):
    big = size * SS
    img = Image.new("RGBA", (big, big), (25, 25, 30, 255))
    d = ImageDraw.Draw(img)
    w = big // 4
    for i in range(-4, 8):
        x = i * w * 2
        d.polygon([(x, big), (x + w, big), (x + w + big, 0), (x + big, 0)], fill=(255, 205, 40, 255))
    return img.resize((size, size), Image.LANCZOS)


def main():
    sheet = Image.new("RGBA", (SHEET, SHEET), (0, 0, 0, 0))
    entries = []
    per_row = SHEET // CELL
    for i, (name, fn) in enumerate(ICONS):
        x, y = (i % per_row) * CELL, (i // per_row) * CELL
        sheet.alpha_composite(fn().resize((CELL, CELL), Image.LANCZOS), (x, y))
        entries.append((name, x, y, CELL, CELL))

    # Decorative images in the bottom rows.
    deco_y = 5 * CELL
    for name, img, x, y in [
        ("sunburst", sunburst(256), 0, deco_y),
        ("glow", glow(256), 256, deco_y),
        ("splat", splat(256), 512, deco_y),
        ("dots", dots(128), 768, deco_y),
        ("stripes", stripes(128), 896, deco_y),
    ]:
        sheet.alpha_composite(img, (x, y))
        entries.append((name, x, y, img.width, img.height))

    os.makedirs(os.path.dirname(OUT_PNG), exist_ok=True)
    sheet.save(OUT_PNG, optimize=True)

    lines = [
        "--!strict",
        "-- GENERATED by tools/art/make_ui_sheet.py - do not edit by hand.",
        "-- Where each image sits on the UI sprite sheet (assets/ui/UiSheet.png).",
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
