"""Renders preview screenshots of the GUI built by src/builders/GuiBuilder.luau, without Studio.

Runs the builder in the fake engine (tools/preview/mock.luau), sets up a few game states the
way the client scripts would, dumps the instance tree as JSON and lays it out / draws it with
a small reimplementation of Roblox's UI layout rules.

Usage: python3 tools/preview/render_gui.py <scenario> <out.png> --luau <luau> --fonts <dir>
       scenarios: vote, round, results, shop, emotes, driver
"""

import json
import math
import os
import re
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPRITES = {}
# The preview shows both sheets as if uploaded (farm sprites win, like SpriteSheets.find).
for _png, _index in (("UiSheet.png", "UiSprites.luau"), ("FarmSheet.png", "FarmSprites.luau")):
    _sheet = Image.open(os.path.join(ROOT, "assets/ui", _png)).convert("RGBA")
    for m in re.findall(r"(\w+) = \{ offset = Vector2.new\((\d+), (\d+)\), size = Vector2.new\((\d+), (\d+)\) \}",
                        open(os.path.join(ROOT, "src/shared", _index)).read()):
        SPRITES[m[0]] = (_sheet, int(m[1]), int(m[2]), int(m[3]), int(m[4]))
W, H = 1280, 720
SS = 2  # supersample for smoother edges

MODULES = ["src/shared/Config.luau", "src/shared/AssetIds.luau", "src/shared/UiSprites.luau",
           "src/shared/FarmSprites.luau", "src/shared/SpriteSheets.luau",
           "src/shared/Modes.luau", "src/shared/Cosmetics.luau",
           "src/builders/GuiKit.luau", "src/builders/GuiBuilder.luau"]

SCENARIO = r'''
local scenario = "%s"
local root = Instance.new("Folder")
local function mod(path) return mockRequire(path) end
local GuiBuilder = mockRequire(builders:FindFirstChild("GuiBuilder"))
GuiBuilder.build(root)
local Modes = mockRequire(shared:FindFirstChild("Modes"))
local Cosmetics = mockRequire(shared:FindFirstChild("Cosmetics"))
local hud, shop, emotesGui, driver = root.Hud, root.Shop, root.Emotes, root.Driver
local function setSprite(img, s) img:SetAttribute("Sprite", s) end
local function tpl(folder, name) local c = folder[name]:Clone(); c.Visible = true; return c end
local function setButton(b, text, color)
	if text and b.Face.Content:FindFirstChild("Label") then b.Face.Content.Label.Text = text end
	if color then
		b.Face.BackgroundColor3 = color
		b.Base.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.45)
	end
end
local out = {}
local function feed(text, icon, i)
	local line = tpl(hud.Templates, "FeedLine")
	line.LayoutOrder = i
	setSprite(line.Row.Icon, icon)
	line.Row.Text.Text = text
	line.Parent = hud.Feed
end
local function toast(text, icon, color, i)
	local t = tpl(hud.Templates, "Toast")
	t.LayoutOrder = i
	setSprite(t.Row.Icon, icon)
	t.Row.Text.Text = text
	t.Row.Text.TextColor3 = color
	t.Parent = hud.Toasts
end
hud.Side.Coins.Row.Amount.Text = "1,250"
if scenario == "vote" then
	hud.Top.Status.Row.Title.Text = "VOTE!"
	setSprite(hud.Top.Status.Row.Icon, "vote")
	hud.Top.Status.Row.TimerPill.Timer.Text = "0:12"
	hud.Vote.Visible = true
	local looks = { Solo = { "chickenRun", Color3.fromRGB(255, 150, 40) }, Teams = { "team", Color3.fromRGB(60, 160, 255) }, RoadRage = { "angry", Color3.fromRGB(255, 80, 80) } }
	local votes = { Solo = 3, Teams = 1, RoadRage = 4 }
	for i, id in { "Solo", "Teams", "RoadRage" } do
		local mode = Modes.get(id)
		local card = tpl(hud.Templates, "VoteCard")
		card.LayoutOrder = i
		setButton(card, nil, looks[id][2])
		setSprite(card.Face.Content.Icon, looks[id][1])
		card.Face.Content.ModeName.Text = string.upper(mode.name)
		card.Face.Content.Desc.Text = mode.description
		card.Face.Content.Bar.Fill.Size = UDim2.fromScale(votes[id] / 8, 1)
		card.Face.Content.Bar.Votes.Text = tostring(votes[id])
		card.Check.Visible = id == "RoadRage"
		card.Parent = hud.Vote.Cards
	end
	feed("Cluckers joined the game", "info", 1)
	feed("Henrietta egged Nugget to their doom!", "egg", 2)
elseif scenario == "round" then
	hud.Top.Status.Row.Title.Text = "CROSS!"
	setSprite(hud.Top.Status.Row.Icon, "chickenRun")
	hud.Top.Status.Row.TimerPill.Timer.Text = "1:42"
	hud.Top.Info.Mode.Visible = true
	hud.Top.Info.Mode.Row.Label.Text = "RUSH HOUR"
	setSprite(hud.Top.Info.Mode.Row.Icon, "lightning")
	hud.Top.Info.Alive.Visible = true
	hud.Top.Info.Alive.Row.Label.Text = "7 LEFT"
	hud.Stamina.Visible = true
	hud.Stamina.Track.Fill.Size = UDim2.fromScale(0.65, 1)
	feed("Nugget got flattened by a car", "car", 3)
	feed("Henrietta egged Drumstick to their doom!", "egg", 2)
	feed("Sidewalk A is collapsing! Cross the road!", "lightning", 1)
	toast("+15 eggs knockout", "eggCoin", Color3.fromRGB(255, 201, 60), 1)
	hud.CrossBanner.Visible = true
	hud.CrossBanner.Label.Text = "RUN TO THE WINDMILL!"
	hud.CrossBanner.TimePill.Time.Text = "7"
	hud.CrossBanner.Track.Fill.Size = UDim2.fromScale(0.45, 1)
	hud.CrossBanner.Track.Fill.BackgroundColor3 = Color3.fromRGB(255, 205, 64)
	hud.EventBanner.Visible = true
	hud.EventBanner.Time.Text = "18"
	toast("KNOCKOUT! Drumstick", "egg", Color3.fromRGB(255, 200, 90), 2)
	hud.Countdown.Visible = true
	hud.Countdown.Number.Text = "GO!"
	hud.Countdown.Number.TextColor3 = Color3.fromRGB(110, 240, 120)
	hud.Danger.Visible = true
elseif scenario == "results" then
	hud.Top.Status.Row.Title.Text = "ROUND OVER"
	setSprite(hud.Top.Status.Row.Icon, "trophy")
	hud.Top.Status.Row.TimerPill.Timer.Text = "0:05"
	hud.Results.Visible = true
	hud.Results.Title.Text = "YOU WIN!"
	hud.Results.Winner.Text = "Henrietta crossed the road!"
	hud.Results.Reward.Visible = true
	hud.Results.Reward.Row.Label.Text = "+85"
	toast("+50 eggs for winning!", "eggCoin", Color3.fromRGB(255, 201, 60), 1)
elseif scenario == "shop" then
	shop.Dim.Visible = true
	shop.Panel.Visible = true
	shop.Panel.Body.Header.Coins.Row.Amount.Text = "1,250"
	setButton(shop.Panel.Body.Tabs.ChickenSkin, nil, Color3.fromRGB(80, 210, 100))
	local states = { "EQUIPPED", "EQUIP", "250", "400", "900", "1200", "3000", "R$ 99", "300", "800" }
	local i = 0
	for _, item in Cosmetics.list do
		if item.slot == "ChickenSkin" or (item.slot == "EggSkin" and i < 10) then
			i += 1
			if i > 10 then break end
			local card = tpl(shop.Templates, "ItemCard")
			card.LayoutOrder = i
			local c = Cosmetics.rarityColors[item.rarity]
			card.RarityGradient.Color = ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.15), c:Lerp(Color3.new(0, 0, 0), 0.45))
			card.Glow.ImageColor3 = c
			card.ItemName.Text = item.name
			card.Rarity.Text = string.upper(item.rarity)
			setSprite(card.PreviewIcon, if item.slot == "ChickenSkin" then "chicken" else "egg")
			local st = states[i]
			local color = if st == "EQUIPPED" then Color3.fromRGB(150, 150, 170) elseif st == "EQUIP" then Color3.fromRGB(80, 210, 100) elseif st:sub(1, 2) == "R$" then Color3.fromRGB(255, 100, 170) else Color3.fromRGB(255, 150, 40)
			setButton(card.Action, st, color)
			card.Action.Face.Content.Icon.Visible = tonumber(st) ~= nil
			card.Equipped.Visible = st == "EQUIPPED"
			card.Lock.Visible = st ~= "EQUIPPED" and st ~= "EQUIP"
			card.Parent = shop.Panel.Body.Grid
		end
	end
elseif scenario == "emotes" then
	emotesGui.Wheel.Visible = true
	local names = { "BAWK!", "SPIN", "HAPPY HOP", "EMPTY" }
	for i = 1, 4 do
		setButton(emotesGui.Wheel["Slot" .. i], names[i], if i == 4 then Color3.fromRGB(150, 150, 170) else nil)
	end
elseif scenario == "driver" then
	driver.Enabled = true
	driver.Controls.Cooldown.Fill.Size = UDim2.fromScale(0.6, 1)
	hud.Top.Status.Row.Title.Text = "CROSS!"
	hud.Top.Status.Row.TimerPill.Timer.Text = "0:58"
end
print("JSON" .. dumpTree(root))
'''

FONTS = {}


def font(name, size):
    key = (name, size)
    if key not in FONTS:
        fdir = FONT_DIR
        if name == "LuckiestGuy":
            f = ImageFont.truetype(os.path.join(fdir, "LuckiestGuy.ttf"), size)
        else:
            f = ImageFont.truetype(os.path.join(fdir, "Fredoka.ttf"), size)
            try:
                f.set_variation_by_name("SemiBold")
            except Exception:
                pass
        FONTS[key] = f
    return FONTS[key]


def nine_slice(src, center, w, h, scale):
    """Roblox-style 9-slice: corners keep their size (times `scale`), edges/centre stretch."""
    x0, y0, x1, y1 = center
    sw, sh = src.size
    cols = [(0, x0), (x0, x1), (x1, sw)]
    rows = [(0, y0), (y0, y1), (y1, sh)]
    cw = [max(1, int(x0 * scale)), 0, max(1, int((sw - x1) * scale))]
    rh = [max(1, int(y0 * scale)), 0, max(1, int((sh - y1) * scale))]
    cw[1] = max(1, w - cw[0] - cw[2])
    rh[1] = max(1, h - rh[0] - rh[2])
    out = Image.new("RGBA", (max(1, w), max(1, h)))
    oy = 0
    for (ry0, ry1), th in zip(rows, rh):
        ox = 0
        for (cx0, cx1), tw in zip(cols, cw):
            if cx1 > cx0 and ry1 > ry0:
                out.alpha_composite(src.crop((cx0, ry0, cx1, ry1)).resize((tw, th), Image.LANCZOS), (ox, oy))
            ox += tw
        oy += th
    return out


def run_luau(scenario, luau):
    parts = [open(os.path.join(ROOT, "tools/preview/mock.luau")).read()]
    parts.append('local shared = service("ReplicatedStorage"):FindFirstChild("Shared")')
    parts.append('for _, n in { "Modes", "Cosmetics", "FarmSprites", "SpriteSheets" } do moduleInst(n, "./src/shared/" .. n .. ".luau").Parent = shared end')
    parts.append('for _, n in { "GuiKit", "GuiBuilder" } do moduleInst(n, "./src/builders/" .. n .. ".luau").Parent = builders end')
    for rel in MODULES:
        src = open(os.path.join(ROOT, rel)).read()
        src = re.sub(r"^export type", "type", src, flags=re.M).replace("--!strict", "")
        parts.append(f'__modules["./{rel}"] = function(script, require)\n{src}\nend\n')
    parts.append(SCENARIO % scenario)
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as f:
        f.write("\n".join(parts))
        path = f.name
    out = subprocess.run([luau, path], capture_output=True, text=True)
    for line in out.stdout.splitlines():
        if line.startswith("JSON"):
            return json.loads(line[4:])
    sys.exit(out.stdout[-3000:] + out.stderr[-3000:])


# --- layout ---------------------------------------------------------------------------------------

GUI_CLASSES = {"Frame", "TextLabel", "TextButton", "ImageLabel", "ImageButton", "ScrollingFrame", "ViewportFrame"}


def P(n, key, default=None):
    return n["props"].get(key, default)


def kids(n, cls=None):
    return [c for c in n["children"] if cls is None or P(c, "ClassName") in cls]


def child_of_class(n, cls):
    for c in n["children"]:
        if P(c, "ClassName") == cls:
            return c
    return None


def udim2(v, default=(0, 0, 0, 0)):
    return v["udim2"] if v else default


def resolve_size(n, pw, ph):
    sx, ox, sy, oy = udim2(P(n, "Size"), (0, 100, 0, 100))
    constraint = P(n, "SizeConstraint", "RelativeXY")
    basex = ph if constraint == "RelativeYY" else pw
    basey = pw if constraint == "RelativeXX" else ph
    w, h = sx * basex + ox, sy * basey + oy
    ar = child_of_class(n, "UIAspectRatioConstraint")
    if ar:
        r = P(ar, "AspectRatio", 1)
        if w / max(h, 1e-6) > r:
            w = h * r
        else:
            h = w / r
    sc = child_of_class(n, "UISizeConstraint")
    if sc:
        mx = P(sc, "MaxSize", {"v2": [1e9, 1e9]})["v2"]
        mn = P(sc, "MinSize", {"v2": [0, 0]})["v2"]
        w = min(max(w, mn[0]), mx[0])
        h = min(max(h, mn[1]), mx[1])
    return w, h


def anim_scale(n):
    for c in n["children"]:
        if P(c, "ClassName") == "UIScale":
            return P(c, "Scale", 1)
    return 1


def layout(n, x, y, w, h, out):
    """Computes absolute rects for n's GUI children; n occupies (x,y,w,h)."""
    pad = child_of_class(n, "UIPadding")
    cx, cy, cw, ch = x, y, w, h
    if pad:
        l = P(pad, "PaddingLeft", {"udim": [0, 0]})["udim"]
        r = P(pad, "PaddingRight", {"udim": [0, 0]})["udim"]
        t = P(pad, "PaddingTop", {"udim": [0, 0]})["udim"]
        b = P(pad, "PaddingBottom", {"udim": [0, 0]})["udim"]
        pl, pr = l[0] * w + l[1], r[0] * w + r[1]
        pt, pb = t[0] * h + t[1], b[0] * h + b[1]
        cx, cy, cw, ch = x + pl, y + pt, w - pl - pr, h - pt - pb
    children = [c for c in n["children"] if P(c, "ClassName") in GUI_CLASSES]
    lst = child_of_class(n, "UIListLayout")
    grid = child_of_class(n, "UIGridLayout")
    if lst:
        horizontal = P(lst, "FillDirection") == "Horizontal"
        padding = P(lst, "Padding", {"udim": [0, 0]})["udim"]
        gap = padding[0] * (cw if horizontal else ch) + padding[1]
        items = sorted([c for c in children if P(c, "Visible", True)], key=lambda c: P(c, "LayoutOrder", 0))
        sizes = [resolve_size(c, cw, ch) for c in items]
        total = sum(s[0] if horizontal else s[1] for s in sizes) + gap * max(0, len(items) - 1)
        halign = P(lst, "HorizontalAlignment", "Left")
        valign = P(lst, "VerticalAlignment", "Top")
        if horizontal:
            start = cx + {"Left": 0, "Center": (cw - total) / 2, "Right": cw - total}.get(halign, 0)
        else:
            start = cy + {"Top": 0, "Center": (ch - total) / 2, "Bottom": ch - total}.get(valign, 0)
        pos = start
        for c, (iw, ih) in zip(items, sizes):
            s = anim_scale(c)
            if horizontal:
                iy = cy + {"Top": 0, "Center": (ch - ih) / 2, "Bottom": ch - ih}.get(valign, 0)
                place(c, pos, iy, iw, ih, s, out)
                pos += iw + gap
            else:
                ix = cx + {"Left": 0, "Center": (cw - iw) / 2, "Right": cw - iw}.get(halign, 0)
                place(c, ix, pos, iw, ih, s, out)
                pos += ih + gap
        return
    if grid:
        cell = udim2(P(grid, "CellSize"))
        cpad = udim2(P(grid, "CellPadding"))
        gw, gh = cell[0] * cw + cell[1], cell[2] * ch + cell[3]
        px, py = cpad[0] * cw + cpad[1], cpad[2] * ch + cpad[3]
        per_row = max(1, int((cw + px) // (gw + px)))
        items = sorted([c for c in children if P(c, "Visible", True)], key=lambda c: P(c, "LayoutOrder", 0))
        row_w = per_row * gw + (per_row - 1) * px
        off = (cw - row_w) / 2 if P(grid, "HorizontalAlignment") == "Center" else 0
        for i, c in enumerate(items):
            r, col = divmod(i, per_row)
            place(c, cx + off + col * (gw + px), cy + r * (gh + py), gw, gh, anim_scale(c), out)
        return
    for c in children:
        cw2, ch2 = resolve_size(c, cw, ch)
        psx, pox, psy, poy = udim2(P(c, "Position"))
        ax, ay = P(c, "AnchorPoint", {"v2": [0, 0]})["v2"]
        px = cx + psx * cw + pox - ax * cw2
        py = cy + psy * ch + poy - ay * ch2
        place(c, px, py, cw2, ch2, anim_scale(c), out)


def place(n, x, y, w, h, scale, out):
    if not P(n, "Visible", True):
        return
    if scale != 1:
        mx, my = x + w / 2, y + h / 2
        w, h = w * scale, h * scale
        x, y = mx - w / 2, my - h / 2
    out.append((n, x, y, w, h))
    start = len(out)
    layout(n, x, y, w, h, out)
    # Children draw above their parent; siblings by ZIndex (stable).
    sub = out[start:]
    del out[start:]
    direct = []
    # Re-sort only direct grandchildren groups is overkill; sort the whole subtree by depth-first z.
    out.extend(sub)


# --- drawing --------------------------------------------------------------------------------------

def rounded_mask(w, h, radius):
    m = Image.new("L", (max(1, int(w)), max(1, int(h))), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, m.width - 1, m.height - 1], radius=max(0, int(radius)), fill=255)
    return m


def corner_radius(n, w, h):
    c = child_of_class(n, "UICorner")
    if not c:
        return 0
    s, o = P(c, "CornerRadius", {"udim": [0, 8]})["udim"]
    return min(s * min(w, h) + o * SS, min(w, h) / 2)


def gradient_image(n, w, h, base):
    g = child_of_class(n, "UIGradient") or next((c for c in n["children"] if P(c, "ClassName") == "UIGradient"), None)
    w, h = max(1, int(w)), max(1, int(h))
    color = np.ones((h, w, 3)) * np.array(base)
    alpha = np.ones((h, w))
    if g:
        rot = P(g, "Rotation", 0)
        off = P(g, "Offset", {"v2": [0, 0]})["v2"]
        yy, xx = np.mgrid[0:h, 0:w]
        u = (xx + 0.5) / w - 0.5
        v = (yy + 0.5) / h - 0.5
        a = math.radians(rot)
        t = np.clip(u * math.cos(a) + v * math.sin(a) + 0.5 - (off[0] * math.cos(a) + off[1] * math.sin(a)), 0, 1)
        cs = P(g, "Color")
        if cs:
            keys = cs["cseq"]
            ts = [k[0] for k in keys]
            for ch in range(3):
                color[..., ch] *= np.interp(t, ts, [k[1 + ch] for k in keys])
        ns = P(g, "Transparency")
        if ns:
            keys = ns["nseq"]
            alpha *= 1 - np.interp(t, [k[0] for k in keys], [k[1] for k in keys])
    return color, alpha


def draw_node(canvas, n, x, y, w, h):
    cls = P(n, "ClassName")
    X, Y, Wd, Ht = x * SS, y * SS, w * SS, h * SS
    if Wd < 1 or Ht < 1:
        return
    radius = corner_radius(n, Wd, Ht)
    bt = P(n, "BackgroundTransparency", 0)
    stroke = next((c for c in n["children"] if P(c, "ClassName") == "UIStroke"
                   and P(c, "ApplyStrokeMode") == "Border"), None)
    if stroke is None and cls in ("Frame", "ScrollingFrame") and child_of_class(n, "UIStroke") and \
            P(child_of_class(n, "UIStroke"), "ApplyStrokeMode") != "Contextual":
        stroke = child_of_class(n, "UIStroke")
    if stroke and bt < 1:
        th = P(stroke, "Thickness", 1) * SS
        col = tuple(int(c * 255) for c in P(stroke, "Color", {"c3": [0, 0, 0]})["c3"])
        m = rounded_mask(Wd + 2 * th, Ht + 2 * th, radius + th)
        canvas.paste(Image.new("RGBA", m.size, col + (255,)), (int(X - th), int(Y - th)), m)
    if bt < 1:
        base = P(n, "BackgroundColor3", {"c3": [0.64, 0.64, 0.64]})["c3"]
        color, alpha = gradient_image(n, Wd, Ht, base)
        alpha = alpha * (1 - bt)
        img = Image.fromarray(np.dstack([np.clip(color * 255, 0, 255), alpha * 255]).astype(np.uint8), "RGBA")
        mask = rounded_mask(Wd, Ht, radius)
        a = np.array(img.split()[3]) * (np.array(mask) / 255)
        img.putalpha(Image.fromarray(a.astype(np.uint8)))
        canvas.alpha_composite(img, (int(X), int(Y)))
    if cls in ("ImageLabel", "ImageButton"):
        sprite = n["attrs"].get("Sprite")
        if sprite in SPRITES and P(n, "ImageTransparency", 0) < 1:
            sheet, ox, oy, sw, sh = SPRITES[sprite]
            src = sheet.crop((int(ox), int(oy), int(ox + sw), int(oy + sh)))
            tint = P(n, "ImageColor3", {"c3": [1, 1, 1]})["c3"]
            arr = np.array(src).astype(float)
            arr[..., :3] *= np.array(tint)
            arr[..., 3] *= 1 - P(n, "ImageTransparency", 0)
            src = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")
            if P(n, "ScaleType") == "Slice" and P(n, "SliceCenter"):
                x0, y0, x1, y1 = (int(v) for v in P(n, "SliceCenter")["rect"])
                layer = nine_slice(src, (x0, y0, x1, y1), int(Wd), int(Ht), SS * 0.5)
                canvas.alpha_composite(layer, (int(X), int(Y)))
            elif P(n, "ScaleType") == "Tile":
                tile = P(n, "TileSize", {"udim2": [0, 32, 0, 32]})["udim2"]
                tw, th = max(4, int(tile[1] * SS)), max(4, int(tile[3] * SS))
                t = src.resize((tw, th), Image.LANCZOS)
                layer = Image.new("RGBA", (int(Wd), int(Ht)))
                for ty in range(0, int(Ht), th):
                    for tx in range(0, int(Wd), tw):
                        layer.alpha_composite(t, (tx, ty))
                if radius:
                    a = np.array(layer.split()[3]) * (np.array(rounded_mask(Wd, Ht, radius)) / 255)
                    layer.putalpha(Image.fromarray(a.astype(np.uint8)))
                canvas.alpha_composite(layer, (int(X), int(Y)))
            else:
                s = min(Wd / sw, Ht / sh) if P(n, "ScaleType", "Stretch") == "Fit" else None
                if s:
                    iw, ih = max(1, int(sw * s)), max(1, int(sh * s))
                    img = src.resize((iw, ih), Image.LANCZOS)
                    rot = P(n, "Rotation", 0)
                    if rot:
                        img = img.rotate(-rot, resample=Image.BICUBIC, expand=False)
                    canvas.alpha_composite(img, (int(X + (Wd - iw) / 2), int(Y + (Ht - ih) / 2)))
                else:
                    canvas.alpha_composite(src.resize((max(1, int(Wd)), max(1, int(Ht))), Image.LANCZOS), (int(X), int(Y)))
    if cls in ("TextLabel", "TextButton") and P(n, "Text", ""):
        draw_text(canvas, n, X, Y, Wd, Ht)


def draw_text(canvas, n, X, Y, Wd, Ht):
    text = P(n, "Text", "")
    fname = P(n, "Font", "FredokaOne")
    color = tuple(int(c * 255) for c in P(n, "TextColor3", {"c3": [0, 0, 0]})["c3"])
    tsc = child_of_class(n, "UITextSizeConstraint")
    max_size = (P(tsc, "MaxTextSize", 100) if tsc else 100) * SS
    stroke = next((c for c in n["children"] if P(c, "ClassName") == "UIStroke"
                   and P(c, "ApplyStrokeMode", "Contextual") == "Contextual"), None)
    sw = int(P(stroke, "Thickness", 0) * SS) if stroke else 0
    scol = tuple(int(c * 255) for c in P(stroke, "Color", {"c3": [0, 0, 0]})["c3"]) if stroke else None
    size = int(min(max_size, Ht))
    wrap = P(n, "TextWrapped", False)

    def wrap_lines(f):
        if not wrap:
            return text.split("\n")
        out_lines = []
        for para in text.split("\n"):
            cur = ""
            for word in para.split(" "):
                trial = (cur + " " + word).strip()
                if f.getbbox(trial)[2] + 2 * sw <= Wd or not cur:
                    cur = trial
                else:
                    out_lines.append(cur)
                    cur = word
            out_lines.append(cur)
        return out_lines

    while size > 6:
        f = font(fname, size)
        lines = wrap_lines(f)
        widths = [f.getbbox(l)[2] for l in lines]
        if max(widths) + 2 * sw <= Wd and size * 1.15 * len(lines) <= Ht:
            break
        size -= 2
    f = font(fname, size)
    lines = wrap_lines(f)
    d = ImageDraw.Draw(canvas)
    line_h = size * 1.15
    total = line_h * len(lines)
    ty = Y + (Ht - total) / 2
    align = P(n, "TextXAlignment", "Center")
    for l in lines:
        bbox = f.getbbox(l)
        lw = bbox[2]
        tx = X + {"Left": sw, "Right": Wd - lw - sw}.get(align, (Wd - lw) / 2)
        d.text((tx, ty + (line_h - size) / 2 - bbox[1] * 0.3), l, font=f, fill=color,
               stroke_width=sw, stroke_fill=scol)
        ty += line_h


def render(tree, scenario, out):
    canvas = Image.new("RGBA", (W * SS, H * SS))
    # Fake game scene behind the UI.
    bg = Image.new("RGBA", (W * SS, H * SS))
    d = ImageDraw.Draw(bg)
    for yy in range(H * SS):
        t = yy / (H * SS)
        d.line([(0, yy), (W * SS, yy)], fill=(int(120 + 80 * t), int(170 + 60 * t), 255, 255))
    d.polygon([(0, H * SS * 0.62), (W * SS, H * SS * 0.55), (W * SS, H * SS), (0, H * SS)], fill=(62, 64, 74, 255))
    canvas.alpha_composite(bg)
    rects = []
    for screen in tree["children"]:
        if P(screen, "ClassName") != "ScreenGui" or P(screen, "Enabled", True) is False:
            continue
        layout(screen, 0, 0, W, H, rects)
    for n, x, y, w, h in rects:
        draw_node(canvas, n, x, y, w, h)
    canvas.resize((W, H), Image.LANCZOS).convert("RGB").save(out)


def main():
    global FONT_DIR
    scenario, out = sys.argv[1], sys.argv[2]
    luau = sys.argv[sys.argv.index("--luau") + 1]
    FONT_DIR = sys.argv[sys.argv.index("--fonts") + 1]
    tree = run_luau(scenario, luau)
    # ScreenGuis sorted by DisplayOrder.
    tree["children"].sort(key=lambda s: P(s, "DisplayOrder", 0))
    render(tree, scenario, out)


if __name__ == "__main__":
    main()
