#!/usr/bin/env python3
"""Procedurally paints every Velora Jam Co. icon (transparent PNG).
Usage: gen_icons.py <resource_dir> <fonts_dir>
Reads recipes from server/recipes.lua (via lupa) so jar colours stay in sync."""
import math, random, sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

RES = sys.argv[1]
FONTS = sys.argv[2]
S = 1024          # working size (4x supersampled)
OUT = 256

def hexrgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def new():
    return Image.new('RGBA', (S, S), (0, 0, 0, 0))

def mask_new():
    return Image.new('L', (S, S), 0)

def comp(base, layer):
    return Image.alpha_composite(base, layer)

FONT_CINZEL = os.path.join(FONTS, 'cinzel-latin-700-normal.ttf')
FONT_SCRIPT = os.path.join(FONTS, 'great-vibes-latin-400-normal.ttf')
FONT_SERIF = os.path.join(FONTS, 'cormorant-garamond-latin-600-normal.ttf')

def font(path, size):
    return ImageFont.truetype(path, size)

# ─────────────────────────────────────────────────────────────────────────
# Shading
# ─────────────────────────────────────────────────────────────────────────
LIGHT = np.array([-0.5, -0.68, 0.54]); LIGHT /= np.linalg.norm(LIGHT)
HALF = LIGHT + np.array([0, 0, 1.0]); HALF /= np.linalg.norm(HALF)

def shade(mask, base, blur=None, amb=0.36, diff=0.78, spec=0.55, shin=26, tilt=1.7,
          base2=None, grad_dir=(0, 1), noise=0.0, rim=0.0, rim_col=(255, 120, 170), seed=1):
    """Turn a flat mask into a lit, puffy 3D shape. base2 = optional colour gradient."""
    bbox = mask.getbbox()
    if not bbox:
        return new()
    pad = 60
    x0, y0 = max(0, bbox[0] - pad), max(0, bbox[1] - pad)
    x1, y1 = min(S, bbox[2] + pad), min(S, bbox[3] + pad)
    m_img = mask.crop((x0, y0, x1, y1))
    m = np.asarray(m_img, dtype=np.float32) / 255.0
    area = m.sum()
    b = blur or max(4, int(math.sqrt(area) * 0.16))
    h = np.asarray(m_img.filter(ImageFilter.GaussianBlur(b)), dtype=np.float32) / 255.0
    gy, gx = np.gradient(h)
    k = b * tilt
    nx, ny, nz = -gx * k, -gy * k, np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / ln, ny / ln, nz / ln
    d = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
    s = np.clip(nx * HALF[0] + ny * HALF[1] + nz * HALF[2], 0, 1) ** shin * spec
    H, W = m.shape
    col = np.zeros((H, W, 3), np.float32)
    c1 = np.array(base, np.float32)
    if base2 is not None:
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        t = (xx / W) * grad_dir[0] + (yy / H) * grad_dir[1]
        t = (t - t.min()) / max(1e-6, (t.max() - t.min()))
        c2 = np.array(base2, np.float32)
        col[:] = c1 * (1 - t[..., None]) + c2 * t[..., None]
    else:
        col[:] = c1
    lum = amb + diff * d
    if noise > 0:
        rng = np.random.default_rng(seed)
        n = rng.normal(0, 1, (H // 6 + 1, W // 6 + 1)).astype(np.float32)
        n = np.asarray(Image.fromarray(((n * 40) + 128).clip(0, 255).astype(np.uint8)).resize((W, H), Image.BICUBIC), np.float32)
        lum = lum * (1 + (n - 128) / 128 * noise)
    out = col * lum[..., None] + 255 * s[..., None]
    if rim > 0:
        edge = np.clip(1 - nz, 0, 1) ** 2 * rim
        out = out * (1 - edge[..., None]) + np.array(rim_col, np.float32) * edge[..., None]
    out = np.clip(out, 0, 255)
    rgba = np.dstack([out, m * 255]).astype(np.uint8)
    layer = new()
    layer.paste(Image.fromarray(rgba, 'RGBA'), (x0, y0))
    return layer

def ellipse_mask(cx, cy, rx, ry, rot=0):
    m = mask_new()
    d = ImageDraw.Draw(m)
    if rot == 0:
        d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
        return m
    pts = []
    for i in range(120):
        a = i / 120 * 2 * math.pi
        x, y = rx * math.cos(a), ry * math.sin(a)
        pts.append((cx + x * math.cos(rot) - y * math.sin(rot), cy + x * math.sin(rot) + y * math.cos(rot)))
    d.polygon(pts, fill=255)
    return m

def poly_mask(pts, smooth=0):
    m = mask_new()
    ImageDraw.Draw(m).polygon(pts, fill=255)
    if smooth:
        m = m.filter(ImageFilter.GaussianBlur(smooth)).point(lambda v: 255 if v > 127 else 0)
    return m

def shadow(mask, offset=(0, 26), blur=26, alpha=110):
    m = ImageChops.offset(mask, offset[0], offset[1]).filter(ImageFilter.GaussianBlur(blur))
    layer = Image.new('RGBA', (S, S), (20, 6, 14, 0))
    layer.putalpha(m.point(lambda v: v * alpha // 255))
    return layer

def outline(mask, width=10, color=(25, 8, 16), alpha=200):
    grown = mask.filter(ImageFilter.MaxFilter(width * 2 + 1))
    layer = Image.new('RGBA', (S, S), color + (0,))
    layer.putalpha(grown.point(lambda v: v * alpha // 255))
    return layer

def leaf(cx, cy, length, width, angle, color=(76, 140, 52), vein=True):
    pts = []
    for i in range(41):
        t = i / 40
        w = math.sin(t * math.pi) ** 0.85 * width
        pts.append((t * length, -w))
    for i in range(40, -1, -1):
        t = i / 40
        w = math.sin(t * math.pi) ** 0.85 * width
        pts.append((t * length, w * 0.9))
    ca, sa = math.cos(angle), math.sin(angle)
    pts = [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]
    m = poly_mask(pts)
    layer = shade(m, color, base2=mix(color, (30, 70, 25), 0.6), grad_dir=(0.6, 0.6), spec=0.3, shin=18, tilt=1.2)
    if vein:
        d = ImageDraw.Draw(layer)
        d.line([(cx, cy), (cx + length * 0.92 * ca, cy + length * 0.92 * sa)], fill=(170, 210, 120, 150), width=max(3, int(width * 0.08)))
    return layer, m

def stem(points, width=18, color=(92, 58, 30)):
    layer = new()
    d = ImageDraw.Draw(layer)
    d.line(points, fill=color + (255,), width=width, joint='curve')
    for p in (points[0], points[-1]):
        d.ellipse((p[0] - width / 2, p[1] - width / 2, p[0] + width / 2, p[1] + width / 2), fill=color + (255,))
    hl = new()
    ImageDraw.Draw(hl).line([(x - width * 0.18, y) for x, y in points], fill=(190, 140, 90, 140), width=max(2, width // 4))
    return comp(layer, hl)

def dots(layer, mask, count, color, rmin, rmax, seed=3, alpha=120):
    rng = random.Random(seed)
    d = ImageDraw.Draw(layer)
    bbox = mask.getbbox()
    placed = 0
    tries = 0
    while placed < count and tries < count * 20:
        tries += 1
        x = rng.uniform(bbox[0], bbox[2]); y = rng.uniform(bbox[1], bbox[3])
        if mask.getpixel((int(x), int(y))) > 200:
            r = rng.uniform(rmin, rmax)
            d.ellipse((x - r, y - r, x + r, y + r), fill=color + (alpha,))
            placed += 1
    return layer

def clip_to(layer, mask):
    a = layer.getchannel('A')
    layer.putalpha(ImageChops.multiply(a, mask))
    return layer

def sparkle(layer, x, y, r, color=(255, 240, 190), alpha=255):
    d = ImageDraw.Draw(layer)
    pts = []
    for i in range(8):
        a = i / 8 * 2 * math.pi - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.22
        pts.append((x + rr * math.cos(a), y + rr * math.sin(a)))
    d.polygon(pts, fill=color + (alpha,))
    return layer

def glow(mask, color, blur=40, alpha=200, grow=0):
    m = mask.filter(ImageFilter.MaxFilter(grow * 2 + 1)) if grow else mask
    m = m.filter(ImageFilter.GaussianBlur(blur))
    layer = Image.new('RGBA', (S, S), color + (0,))
    layer.putalpha(m.point(lambda v: min(255, v * alpha // 255)))
    return layer

def finish(img, path, size=OUT):
    img = img.resize((size, size), Image.LANCZOS)
    img.save(path, optimize=True)

# ─────────────────────────────────────────────────────────────────────────
# Fruit painters (each returns an RGBA image and its silhouette mask)
# ─────────────────────────────────────────────────────────────────────────
def paint_orange(cx=512, cy=545, r=330, base=(242, 140, 30), seed=1):
    img = new()
    m = ellipse_mask(cx, cy, r, r * 0.96)
    img = comp(img, shadow(m))
    img = comp(img, outline(m))
    body = shade(m, base, base2=(214, 96, 18), grad_dir=(0.4, 0.8), noise=0.10, seed=seed, spec=0.45, shin=20)
    dots(body, m, 500, (255, 200, 120), 3, 6, seed=seed, alpha=35)
    dots(body, m, 220, (170, 80, 10), 2, 4, seed=seed + 1, alpha=25)
    img = comp(img, body)
    # navel / stem nub
    s = new(); ImageDraw.Draw(s).ellipse((cx - 26, cy - r + 8, cx + 26, cy - r + 50), fill=(110, 120, 40, 255))
    img = comp(img, s)
    lf, _ = leaf(cx + 10, cy - r + 20, r * 0.75, r * 0.24, -0.55)
    img = comp(img, lf)
    return img, m

def apple_mask(cx, cy, r):
    m = mask_new(); d = ImageDraw.Draw(m)
    d.ellipse((cx - r * 1.0, cy - r * 0.86, cx + r * 0.12, cy + r * 0.92), fill=255)
    d.ellipse((cx - r * 0.12, cy - r * 0.86, cx + r * 1.0, cy + r * 0.92), fill=255)
    d.ellipse((cx - r * 0.82, cy - r * 0.35, cx + r * 0.82, cy + r * 1.0), fill=255)
    d.ellipse((cx - r * 0.2, cy - r * 0.95, cx + r * 0.2, cy - r * 0.7), fill=0)
    return m.filter(ImageFilter.GaussianBlur(14)).point(lambda v: 255 if v > 127 else 0)

def paint_apple(cx=512, cy=560, r=330, base=(214, 30, 44), base2=(150, 14, 30), seed=2, golden=False):
    img = new()
    m = apple_mask(cx, cy, r)
    img = comp(img, shadow(m))
    img = comp(img, outline(m))
    body = shade(m, base, base2=base2, grad_dir=(0.9, 0.5), noise=0.06, seed=seed,
                 spec=0.9 if golden else 0.55, shin=40 if golden else 24)
    if not golden:
        # streaks
        st = new(); d = ImageDraw.Draw(st); rng = random.Random(seed)
        for _ in range(26):
            x = cx + rng.uniform(-r * 0.8, r * 0.8)
            d.line([(x, cy - r * 0.6), (x + rng.uniform(-40, 40), cy + r * 0.8)], fill=(255, 220, 160, 26), width=10)
        body = comp(body, clip_to(st, m))
    img = comp(img, body)
    img = comp(img, stem([(cx, cy - r * 0.72), (cx + 18, cy - r * 1.05), (cx + 42, cy - r * 1.22)], width=26))
    lf, _ = leaf(cx + 34, cy - r * 1.02, r * 0.72, r * 0.22, -0.25)
    img = comp(img, lf)
    return img, m

def paint_lemon(cx=512, cy=545, r=300, seed=3):
    img = new()
    pts = []
    for i in range(200):
        a = i / 200 * 2 * math.pi
        x = math.cos(a); y = math.sin(a)
        tip = max(0, abs(x) ** 10) * 0.28
        pts.append((cx + (x * (1.16 + tip)) * r, cy + y * r * 0.86))
    m = poly_mask(pts, smooth=6)
    img = comp(img, shadow(m))
    img = comp(img, outline(m))
    body = shade(m, (246, 212, 48), base2=(222, 170, 20), grad_dir=(0.3, 0.9), noise=0.10, seed=seed, spec=0.5, shin=22)
    dots(body, m, 380, (255, 245, 170), 2, 5, seed=seed, alpha=40)
    img = comp(img, body)
    lf, _ = leaf(cx - r * 0.95, cy - r * 0.25, r * 0.8, r * 0.24, -2.2)
    img = comp(img, lf)
    return img, m

def paint_cherry(seed=4):
    img = new()
    base = (168, 16, 40)
    masks = []
    for (cx, cy, r) in ((365, 640, 205), (650, 690, 215)):
        m = mask_new(); d = ImageDraw.Draw(m)
        d.ellipse((cx - r, cy - r * 0.92, cx + r, cy + r), fill=255)
        d.ellipse((cx - 28, cy - r * 0.98, cx + 28, cy - r * 0.78), fill=0)
        masks.append((cx, cy, r, m))
    for cx, cy, r, m in masks:
        img = comp(img, shadow(m))
    img = comp(img, stem([(380, 450), (430, 300), (515, 160)], width=20, color=(90, 110, 40)))
    img = comp(img, stem([(655, 490), (600, 300), (515, 160)], width=20, color=(90, 110, 40)))
    for cx, cy, r, m in masks:
        img = comp(img, outline(m))
        img = comp(img, shade(m, base, base2=(98, 6, 24), grad_dir=(0.6, 0.8), spec=0.95, shin=46, seed=seed))
    lf, _ = leaf(515, 160, 300, 90, -0.35)
    img = comp(img, lf)
    full = mask_new()
    for *_, m in masks:
        full = ImageChops.lighter(full, m)
    return img, full

def paint_peach(cx=512, cy=560, r=330, seed=5):
    img = new()
    m = apple_mask(cx, cy, r)
    img = comp(img, shadow(m))
    img = comp(img, outline(m))
    body = shade(m, (250, 178, 110), base2=(226, 72, 70), grad_dir=(0.95, 0.35), noise=0.05, seed=seed, spec=0.22, shin=12)
    img = comp(img, body)
    crease = new()
    ImageDraw.Draw(crease).arc((cx - r * 0.55, cy - r * 0.85, cx + r * 0.15, cy + r * 0.9), 300, 75, fill=(170, 60, 50, 110), width=14)
    img = comp(img, clip_to(crease, m))
    fuzz = new(); fuzz = dots(fuzz, m, 1600, (255, 230, 210), 2, 4, seed=seed, alpha=40)
    img = comp(img, fuzz)
    img = comp(img, stem([(cx, cy - r * 0.75), (cx + 8, cy - r * 0.98)], width=24))
    lf, _ = leaf(cx + 8, cy - r * 0.92, r * 0.75, r * 0.23, -0.5)
    img = comp(img, lf)
    lf2, _ = leaf(cx, cy - r * 0.92, r * 0.55, r * 0.18, -2.6)
    img = comp(img, lf2)
    return img, m

def paint_strawberry(cx=512, cy=560, r=360, seed=6):
    img = new()
    pts = []
    for i in range(200):
        t = i / 200 * 2 * math.pi
        x = math.sin(t)
        y = -math.cos(t)
        w = 0.88 * (1 - 0.18 * y) * (0.55 + 0.45 * math.sqrt(max(0, (1 - y) / 2) + 0.0))
        px = cx + x * r * w
        py = cy + y * r * 0.95 * (0.9 if y < 0 else 1.0)
        pts.append((px, py))
    m = poly_mask(pts, smooth=10)
    img = comp(img, shadow(m))
    img = comp(img, outline(m))
    body = shade(m, (230, 36, 54), base2=(160, 10, 32), grad_dir=(0.3, 1.0), spec=0.7, shin=34, seed=seed)
    # seeds in a lattice
    sd = new(); d = ImageDraw.Draw(sd)
    for row in range(-6, 7):
        for col in range(-6, 7):
            x = cx + col * 62 + (row % 2) * 31
            y = cy + row * 66
            if 0 <= x < S and 0 <= y < S and m.getpixel((int(x), int(y))) > 200 and y > cy - r * 0.68:
                d.ellipse((x - 9, y - 15, x + 9, y + 15), fill=(120, 6, 20, 150))
                d.ellipse((x - 7, y - 12, x + 7, y + 10), fill=(250, 214, 96, 255))
    body = comp(body, sd)
    img = comp(img, body)
    # calyx
    for i in range(7):
        a = -math.pi / 2 + (i - 3) * 0.48
        lf, _ = leaf(cx, cy - r * 0.72, r * 0.48, r * 0.11, a + math.pi + (0.0 if i % 2 else 0.1), color=(70, 150, 50), vein=False)
        img = comp(img, lf)
    img = comp(img, stem([(cx, cy - r * 0.8), (cx + 14, cy - r * 1.02)], width=26, color=(80, 130, 45)))
    return img, m

def berry_cluster(centres, rr, base, base2, seed, bloom=False, calyx=None, crown=False):
    img = new()
    union = mask_new()
    for (x, y, r) in centres:
        union = ImageChops.lighter(union, ellipse_mask(x, y, r, r))
    img = comp(img, shadow(union))
    img = comp(img, outline(union))
    order = sorted(centres, key=lambda c: c[1])
    for i, (x, y, r) in enumerate(order):
        m = ellipse_mask(x, y, r, r)
        layer = shade(m, base, base2=base2, grad_dir=(0.5, 0.8), spec=0.75 if not bloom else 0.25, shin=38, seed=seed + i)
        if bloom:
            fog = new(); ImageDraw.Draw(fog).ellipse((x - r, y - r, x + r, y + r), fill=(180, 190, 230, 50))
            layer = comp(layer, clip_to(fog, m))
        if crown:
            cr = new(); d = ImageDraw.Draw(cr)
            sx, sy = x + r * 0.15, y - r * 0.35
            pts = []
            for k in range(10):
                a = k / 10 * 2 * math.pi
                rad = r * 0.24 if k % 2 == 0 else r * 0.1
                pts.append((sx + rad * math.cos(a), sy + rad * math.sin(a)))
            d.polygon(pts, fill=(30, 26, 60, 230))
            layer = comp(layer, cr)
        img = comp(img, layer)
    if calyx:
        for i in range(5):
            a = -math.pi / 2 + (i - 2) * 0.55
            lf, _ = leaf(calyx[0], calyx[1], calyx[2], calyx[2] * 0.26, a, color=(80, 140, 50), vein=False)
            img = comp(img, lf)
    return img, union

def paint_blueberry(seed=7):
    centres = [(390, 600, 190), (640, 570, 200), (520, 760, 175), (520, 420, 160)]
    img, m = berry_cluster(centres, 0, (64, 84, 170), (34, 40, 100), seed, bloom=True, crown=True)
    lf, _ = leaf(560, 300, 260, 70, -0.6)
    img = comp(img, lf)
    return img, m

def drupelets(cx, cy, rx, ry, dr, base, base2, seed, calyx=True, cone=0.0):
    centres = []
    rows = int(ry * 2 / (dr * 1.45))
    for row in range(rows + 1):
        y = cy - ry + row * dr * 1.45
        t = (y - (cy - ry)) / (2 * ry)
        width = rx * math.sqrt(max(0.0, 1 - ((y - cy) / ry) ** 2)) * (1 - cone * t)
        n = max(1, int(width * 2 / (dr * 1.55)))
        for k in range(n + 1):
            x = cx - width + k * (2 * width / max(1, n)) + (row % 2) * dr * 0.4
            centres.append((x, y, dr))
    return berry_cluster(centres, dr, base, base2, seed, calyx=(cx, cy - ry - 20, rx * 0.9) if calyx else None)

def paint_blackberry(seed=8):
    img, m = drupelets(512, 580, 270, 330, 64, (58, 20, 70), (18, 6, 26), seed)
    return img, m

def paint_raspberry(seed=9):
    img, m = drupelets(512, 580, 290, 310, 66, (228, 54, 96), (170, 16, 56), seed, cone=0.35)
    return img, m

def paint_plum(cx=512, cy=560, r=320, seed=10):
    img = new()
    m = ellipse_mask(cx, cy, r * 0.92, r, rot=0.25)
    img = comp(img, shadow(m))
    img = comp(img, outline(m))
    body = shade(m, (120, 44, 120), base2=(54, 14, 60), grad_dir=(0.5, 0.9), spec=0.35, shin=18, seed=seed)
    fog = new(); ImageDraw.Draw(fog).ellipse((cx - r, cy - r, cx + r, cy + r), fill=(200, 170, 230, 36))
    body = comp(body, clip_to(fog, m))
    crease = new()
    ImageDraw.Draw(crease).arc((cx - r * 0.2, cy - r * 1.0, cx + r * 0.95, cy + r * 0.95), 140, 250, fill=(40, 6, 40, 120), width=14)
    body = comp(body, clip_to(crease, m))
    img = comp(img, body)
    img = comp(img, stem([(cx + 30, cy - r * 0.9), (cx + 52, cy - r * 1.15)], width=22))
    lf, _ = leaf(cx + 50, cy - r * 1.08, r * 0.7, r * 0.2, -0.3)
    img = comp(img, lf)
    return img, m

def paint_golden(seed=11):
    img, m = paint_apple(base=(255, 214, 92), base2=(196, 120, 20), seed=seed, golden=True)
    g = glow(m, (255, 210, 90), blur=50, alpha=170, grow=20)
    out = comp(new(), g)
    out = comp(out, img)
    sp = new()
    for (x, y, r) in ((230, 260, 70), (800, 330, 54), (820, 800, 64), (260, 820, 40), (690, 520, 36)):
        sparkle(sp, x, y, r)
    out = comp(out, sp)
    return out, m

FRUIT_PAINTERS = {
    'orange': paint_orange, 'apple': paint_apple, 'lemon': paint_lemon, 'cherry': paint_cherry,
    'peach': paint_peach, 'strawberry': paint_strawberry, 'blueberry': paint_blueberry,
    'blackberry': paint_blackberry, 'raspberry': paint_raspberry, 'plum': paint_plum,
}

# ─────────────────────────────────────────────────────────────────────────
# Specials & supplies
# ─────────────────────────────────────────────────────────────────────────
def rrect_mask(x0, y0, x1, y1, r):
    m = mask_new(); ImageDraw.Draw(m).rounded_rectangle((x0, y0, x1, y1), r, fill=255)
    return m

def ribbon_bow(img, cx, cy, size, color=(240, 106, 166)):
    for side in (-1, 1):
        pts = [(cx, cy), (cx + side * size, cy - size * 0.55), (cx + side * size * 1.05, cy + size * 0.45)]
        m = poly_mask(pts, smooth=8)
        img = comp(img, shade(m, color, spec=0.5, shin=20, tilt=1.0))
        tail = [(cx, cy), (cx + side * size * 0.45, cy + size * 1.0), (cx + side * size * 0.15, cy + size * 1.05)]
        img = comp(img, shade(poly_mask(tail, smooth=4), mix(color, (120, 20, 70), 0.3), spec=0.3, tilt=0.8))
    img = comp(img, shade(ellipse_mask(cx, cy, size * 0.2, size * 0.18), mix(color, (255, 255, 255), 0.1), spec=0.6))
    return img

def paint_cinnamon():
    img = new()
    union = mask_new()
    sticks = [(-0.5, 0), (-0.35, -70), (-0.62, 70)]
    layers = []
    for rot, off in sticks:
        cx, cy = 512, 520 + off
        L, W = 380, 62
        ca, sa = math.cos(rot), math.sin(rot)
        pts = [(-L, -W), (L, -W), (L, W), (-L, W)]
        pts = [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]
        m = poly_mask(pts, smooth=6)
        union = ImageChops.lighter(union, m)
        body = shade(m, (150, 82, 40), base2=(98, 46, 20), grad_dir=(0, 1), noise=0.18, seed=int(off) + 100, spec=0.25, tilt=1.2)
        lines = new(); d = ImageDraw.Draw(lines)
        for k in range(-5, 6):
            x = k * 70
            p0 = (cx + x * ca - (-W) * sa, cy + x * sa + (-W) * ca)
            p1 = (cx + x * ca - W * sa, cy + x * sa + W * ca)
            d.line([p0, p1], fill=(80, 36, 14, 70), width=6)
        body = comp(body, clip_to(lines, m))
        endc = (cx + L * ca, cy + L * sa)
        e = new(); d = ImageDraw.Draw(e)
        d.ellipse((endc[0] - 40, endc[1] - 62, endc[0] + 40, endc[1] + 62), fill=(120, 60, 28, 255))
        for k in range(4):
            rr = 50 - k * 12
            d.arc((endc[0] - rr * 0.65, endc[1] - rr, endc[0] + rr * 0.65, endc[1] + rr), 0, 300, fill=(200, 130, 80, 255), width=6)
        body = comp(body, e)
        layers.append(body)
    img = comp(img, shadow(union))
    img = comp(img, outline(union))
    for l in layers:
        img = comp(img, l)
    band = new(); ImageDraw.Draw(band).rectangle((470, 300, 560, 760), fill=(240, 106, 166, 255))
    img = comp(img, clip_to(band, union))
    img = ribbon_bow(img, 515, 470, 120)
    return img, union

def glass_jar(cx, cy, w, h, fill=None, fill2=None, fill_level=0.82, neck=0.86):
    """Returns (image, mask, label_box). Glass jar with optional jam fill."""
    img = new()
    x0, x1 = cx - w / 2, cx + w / 2
    y0, y1 = cy - h / 2, cy + h / 2
    body = rrect_mask(x0, y0 + h * 0.08, x1, y1, int(w * 0.16))
    neckm = rrect_mask(cx - w * neck / 2, y0, cx + w * neck / 2, y0 + h * 0.16, int(w * 0.05))
    m = ImageChops.lighter(body, neckm)
    img = comp(img, shadow(m))
    img = comp(img, outline(m, width=8, alpha=170))
    if fill:
        top = y0 + h * (1 - fill_level)
        fm = ImageChops.multiply(body, rrect_mask(x0, top, x1, y1 + 50, 10))
        inner = fm.filter(ImageFilter.MinFilter(17))
        jam = shade(inner, mix(fill, (255, 255, 255), 0.06), base2=mix(fill, (0, 0, 0), 0.35), grad_dir=(0.2, 1.0), amb=0.6, diff=0.55, spec=0.3, shin=20, tilt=0.6, seed=4)
        # fruit chunks / seeds
        chunks = new()
        dots(chunks, inner, 50, mix(fill, (255, 255, 255), 0.2), 10, 24, seed=9, alpha=50)
        dots(chunks, inner, 60, mix(fill, (0, 0, 0), 0.5), 6, 18, seed=10, alpha=110)
        if fill2:
            sw = new(); d = ImageDraw.Draw(sw)
            for k in range(3):
                yy = top + 60 + k * (h * 0.22)
                d.arc((x0 + 20, yy, x1 - 20, yy + h * 0.25), 200, 340, fill=fill2 + (150,), width=22)
            chunks = comp(chunks, sw)
        jam = comp(jam, clip_to(chunks, inner))
        img = comp(img, jam)
    # glass
    glass = Image.new('RGBA', (S, S), (230, 220, 235, 0))
    ga = m.point(lambda v: v * 20 // 255)
    glass.putalpha(ga)
    img = comp(img, glass)
    edge = m.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(2))
    el = Image.new('RGBA', (S, S), (255, 255, 255, 0)); el.putalpha(edge.point(lambda v: min(255, v * 2) * 150 // 255))
    img = comp(img, el)
    hl = new(); d = ImageDraw.Draw(hl)
    d.rounded_rectangle((x0 + w * 0.1, y0 + h * 0.22, x0 + w * 0.2, y1 - h * 0.12), 30, fill=(255, 255, 255, 120))
    d.rounded_rectangle((x1 - w * 0.16, y0 + h * 0.3, x1 - w * 0.11, y1 - h * 0.3), 20, fill=(255, 255, 255, 60))
    img = comp(img, hl.filter(ImageFilter.GaussianBlur(6)))
    # thread rings
    th = new(); d = ImageDraw.Draw(th)
    for k in range(3):
        yy = y0 + 12 + k * 22
        d.line([(cx - w * neck / 2 + 8, yy), (cx + w * neck / 2 - 8, yy + 6)], fill=(255, 255, 255, 70), width=6)
    img = comp(img, th)
    return img, m, (x0, y0, x1, y1)

def paint_jar_empty():
    img, m, _ = glass_jar(512, 560, 520, 640)
    return img, m

def paint_lid():
    img = new()
    cx, cy = 512, 540
    side = rrect_mask(cx - 360, cy - 90, cx + 360, cy + 130, 60)
    top = ellipse_mask(cx, cy - 90, 360, 150)
    union = ImageChops.lighter(side, top)
    img = comp(img, shadow(union))
    img = comp(img, outline(union))
    sl = shade(side, (214, 170, 84), base2=(140, 98, 36), grad_dir=(1, 0), spec=0.8, shin=30, tilt=0.8)
    rid = new(); d = ImageDraw.Draw(rid)
    for k in range(-20, 21):
        x = cx + k * 18
        d.line([(x, cy - 80), (x, cy + 130)], fill=(110, 76, 24, 90), width=6)
    sl = comp(sl, clip_to(rid, side))
    img = comp(img, sl)
    img = comp(img, shade(top, (236, 196, 110), base2=(186, 136, 52), grad_dir=(0.5, 1), spec=0.9, shin=40, tilt=0.6))
    inner = ellipse_mask(cx, cy - 90, 280, 112)
    img = comp(img, shade(inner, (226, 182, 96), spec=0.6, shin=30, tilt=0.5))
    t = new(); d = ImageDraw.Draw(t)
    f = font(FONT_CINZEL, 170)
    d.text((cx, cy - 90), 'V', font=f, anchor='mm', fill=(190, 40, 110, 255))
    t = t.transform((S, S), Image.AFFINE, (1, 0, 0, 0, 2.4, -(cy - 90) * 1.4), Image.BICUBIC)
    img = comp(img, t)
    return img, union

def paint_sugar():
    img = new()
    cx = 512
    pts = [(250, 300), (774, 300), (800, 900), (224, 900)]
    m = poly_mask(pts, smooth=10)
    top = poly_mask([(250, 300), (774, 300), (740, 190), (284, 190)], smooth=4)
    union = ImageChops.lighter(m, top)
    img = comp(img, shadow(union))
    img = comp(img, outline(union))
    img = comp(img, shade(m, (236, 222, 196), base2=(200, 180, 150), grad_dir=(1, 0.2), noise=0.08, spec=0.15, tilt=0.5))
    img = comp(img, shade(top, (214, 196, 168), spec=0.1, tilt=0.4))
    fold = new(); d = ImageDraw.Draw(fold)
    for k in range(6):
        d.line([(284 + k * 90, 196), (270 + k * 92, 300)], fill=(150, 130, 100, 120), width=6)
    img = comp(img, fold)
    lab = rrect_mask(300, 470, 724, 760, 40)
    img = comp(img, shade(lab, (240, 106, 166), base2=(190, 40, 110), spec=0.2, tilt=0.3))
    t = new(); d = ImageDraw.Draw(t)
    d.text((cx, 580), 'SUGAR', font=font(FONT_CINZEL, 108), anchor='mm', fill=(255, 245, 235, 255))
    d.text((cx, 680), 'Velora', font=font(FONT_SCRIPT, 92), anchor='mm', fill=(40, 10, 24, 255))
    img = comp(img, t)
    # cubes
    for (x, y) in ((680, 860), (790, 820)):
        cm = rrect_mask(x - 60, y - 60, x + 60, y + 60, 14)
        img = comp(img, outline(cm, 6))
        img = comp(img, shade(cm, (250, 248, 244), noise=0.2, spec=0.2, tilt=0.4, seed=x))
    return img, union

def paint_pectin():
    img = new()
    front = poly_mask([(280, 330), (690, 330), (690, 860), (280, 860)])
    side = poly_mask([(690, 330), (800, 260), (800, 780), (690, 860)])
    top = poly_mask([(280, 330), (390, 260), (800, 260), (690, 330)])
    union = ImageChops.lighter(ImageChops.lighter(front, side), top)
    img = comp(img, shadow(union))
    img = comp(img, outline(union))
    img = comp(img, shade(front, (252, 236, 242), spec=0.1, tilt=0.15))
    img = comp(img, shade(side, (210, 170, 186), spec=0.05, tilt=0.15))
    img = comp(img, shade(top, (255, 246, 250), spec=0.1, tilt=0.1))
    band = new(); ImageDraw.Draw(band).rectangle((280, 470, 690, 700), fill=(176, 26, 84, 255))
    img = comp(img, band)
    t = new(); d = ImageDraw.Draw(t)
    d.text((485, 585), 'PECTIN', font=font(FONT_CINZEL, 92), anchor='mm', fill=(255, 238, 246, 255))
    d.text((485, 400), 'Velora', font=font(FONT_SCRIPT, 86), anchor='mm', fill=(176, 26, 84, 255))
    d.text((485, 780), 'natural set', font=font(FONT_SERIF, 54), anchor='mm', fill=(120, 40, 70, 255))
    img = comp(img, t)
    return img, union

def paint_bowl():
    img = new()
    cx, cy = 512, 560
    rim = ellipse_mask(cx, cy - 120, 420, 120)
    bowl = mask_new(); d = ImageDraw.Draw(bowl)
    d.chord((cx - 420, cy - 420, cx + 420, cy + 330), 0, 180, fill=255)
    foot = rrect_mask(cx - 170, cy + 280, cx + 170, cy + 350, 30)
    union = ImageChops.lighter(ImageChops.lighter(rim, bowl), foot)
    img = comp(img, shadow(union))
    img = comp(img, outline(union))
    img = comp(img, shade(foot, (200, 186, 170), spec=0.3, tilt=0.5))
    img = comp(img, shade(bowl, (246, 236, 226), base2=(206, 190, 176), grad_dir=(1, 0.3), spec=0.6, shin=30))
    st = new(); d = ImageDraw.Draw(st)
    d.arc((cx - 410, cy - 360, cx + 410, cy + 250), 15, 165, fill=(240, 106, 166, 255), width=36)
    d.arc((cx - 410, cy - 320, cx + 410, cy + 290), 20, 160, fill=(40, 12, 26, 220), width=12)
    img = comp(img, clip_to(st, bowl))
    img = comp(img, shade(rim, (232, 220, 208), spec=0.4, tilt=0.3))
    inner = ellipse_mask(cx, cy - 112, 380, 96)
    img = comp(img, shade(inner, (176, 30, 60), base2=(120, 10, 40), spec=0.6, shin=30, tilt=0.3))
    # wooden spoon
    sp = poly_mask([(cx + 40, cy - 140), (cx + 360, cy - 520), (cx + 390, cy - 500), (cx + 80, cy - 120)], smooth=4)
    head = ellipse_mask(cx + 20, cy - 120, 80, 50, rot=-0.85)
    spoon = ImageChops.lighter(sp, head)
    img = comp(img, outline(spoon, 6))
    img = comp(img, shade(spoon, (206, 150, 92), base2=(150, 96, 50), noise=0.12, spec=0.3, tilt=0.8))
    return img, union

def paint_basket(fruit_imgs):
    img = new()
    cx, cy = 512, 600
    body = poly_mask([(170, 470), (854, 470), (760, 880), (264, 880)], smooth=12)
    handle = new(); d = ImageDraw.Draw(handle)
    d.arc((230, 120, 794, 820), 190, 350, fill=(150, 96, 50, 255), width=44)
    hm = handle.getchannel('A')
    img = comp(img, outline(hm, 6))
    img = comp(img, shade(hm, (170, 112, 60), noise=0.15, spec=0.3, tilt=0.9))
    # fruit peeking
    placements = [('orange', 340, 430, 0.42), ('apple', 520, 400, 0.44), ('strawberry', 680, 440, 0.38), ('lemon', 450, 470, 0.34)]
    for name, x, y, sc in placements:
        f = fruit_imgs[name].resize((int(S * sc), int(S * sc)), Image.LANCZOS)
        layer = new(); layer.paste(f, (int(x - S * sc / 2), int(y - S * sc / 2)), f)
        img = comp(img, layer)
    img = comp(img, shadow(body))
    img = comp(img, outline(body))
    wv = shade(body, (196, 142, 82), base2=(130, 84, 40), grad_dir=(0.2, 1), spec=0.2, tilt=0.7)
    pat = new(); d = ImageDraw.Draw(pat)
    for row in range(10):
        y = 480 + row * 42
        for col in range(-2, 20):
            x = 150 + col * 60 + (row % 2) * 30
            d.ellipse((x, y, x + 54, y + 34), outline=(110, 66, 30, 160), width=6)
    wv = comp(wv, clip_to(pat, body))
    img = comp(img, wv)
    band = new(); ImageDraw.Draw(band).rectangle((150, 520, 880, 560), fill=(240, 106, 166, 255))
    img = comp(img, clip_to(band, body))
    rimm = rrect_mask(150, 440, 874, 500, 30)
    img = comp(img, outline(rimm, 6))
    img = comp(img, shade(rimm, (180, 120, 64), noise=0.15, spec=0.3, tilt=0.8))
    img = ribbon_bow(img, 780, 470, 90)
    return img, body

def paint_honey():
    img, m, (x0, y0, x1, y1) = glass_jar(470, 600, 460, 520, fill=(236, 150, 20), fill2=(255, 200, 80), fill_level=0.86, neck=0.8)
    cloth = poly_mask([(x0 - 30, y0 + 10), (x1 + 30, y0 + 10), (x1 + 50, y0 + 110), (x0 - 50, y0 + 110)], smooth=8)
    img = comp(img, outline(cloth, 6))
    img = comp(img, shade(cloth, (240, 220, 160), spec=0.2, tilt=0.6))
    chk = new(); d = ImageDraw.Draw(chk)
    for k in range(12):
        d.line([(x0 - 40 + k * 50, y0 + 10), (x0 - 40 + k * 50, y0 + 110)], fill=(220, 120, 40, 120), width=10)
    img = comp(img, clip_to(chk, cloth))
    lab = rrect_mask(x0 + 60, 590, x1 - 60, 760, 30)
    img = comp(img, shade(lab, (250, 240, 220), spec=0.1, tilt=0.2))
    t = new(); ImageDraw.Draw(t).text((470, 672), 'Honey', font=font(FONT_SCRIPT, 110), anchor='mm', fill=(150, 70, 10, 255))
    img = comp(img, t)
    # dipper
    stick = poly_mask([(700, 140), (730, 130), (690, 620), (660, 620)])
    head = mask_new(); d = ImageDraw.Draw(head)
    for k in range(5):
        d.ellipse((610 - k * 2, 560 + k * 46, 760 + k * 2, 610 + k * 46), fill=255)
    dip = ImageChops.lighter(stick, head)
    img = comp(img, outline(dip, 6))
    img = comp(img, shade(dip, (198, 140, 80), base2=(130, 80, 36), noise=0.1, spec=0.3, tilt=0.9))
    drip = ellipse_mask(690, 860, 40, 60)
    img = comp(img, shade(drip, (240, 160, 30), spec=0.9, shin=40))
    return img, ImageChops.lighter(m, dip)

def paint_vanilla():
    img = new()
    union = mask_new()
    pods = []
    for k, off in enumerate((-60, 30, 110)):
        pts_top, pts_bot = [], []
        for i in range(60):
            t = i / 59
            x = 180 + t * 640
            y = 640 + off - math.sin(t * math.pi) * 180 + (t - 0.5) * 60 * k
            w = 26 * math.sin(t * math.pi) ** 0.5 + 4
            pts_top.append((x, y - w)); pts_bot.append((x, y + w))
        m = poly_mask(pts_top + pts_bot[::-1], smooth=4)
        union = ImageChops.lighter(union, m)
        pods.append(m)
    img = comp(img, shadow(union))
    img = comp(img, outline(union))
    for i, m in enumerate(pods):
        img = comp(img, shade(m, (78, 46, 30), base2=(40, 22, 14), grad_dir=(0, 1), noise=0.2, spec=0.5, shin=30, seed=i, tilt=1.0))
    # flower
    fc = (640, 330)
    for k in range(5):
        a = k / 5 * 2 * math.pi - math.pi / 2
        pm = ellipse_mask(fc[0] + math.cos(a) * 95, fc[1] + math.sin(a) * 95, 110, 62, rot=a)
        img = comp(img, outline(pm, 5, alpha=120))
        img = comp(img, shade(pm, (250, 242, 214), base2=(232, 214, 160), spec=0.3, tilt=0.8, seed=k))
    img = comp(img, shade(ellipse_mask(fc[0], fc[1], 46, 46), (240, 196, 80), spec=0.5))
    lf, _ = leaf(fc[0] - 60, fc[1] + 60, 250, 70, 2.5)
    img = comp(img, lf)
    return img, union

def paint_lavender():
    img = new()
    union = mask_new()
    sprigs = [(-0.32, 440), (0.0, 512), (0.3, 590)]
    for k, (ang, bx) in enumerate(sprigs):
        top = (bx + math.sin(ang) * 640, 900 - math.cos(ang) * 700)
        img = comp(img, stem([(bx, 900), ((bx + top[0]) / 2, (900 + top[1]) / 2 + 10), top], width=14, color=(96, 130, 70)))
        for i in range(12):
            t = 0.35 + i / 11 * 0.65
            x = bx + (top[0] - bx) * t
            y = 900 + (top[1] - 900) * t
            for side in (-1, 1):
                m = ellipse_mask(x + side * 26, y, 26, 36, rot=ang + side * 0.5)
                union = ImageChops.lighter(union, m)
                img = comp(img, shade(m, (150, 118, 214), base2=(96, 64, 168), spec=0.4, tilt=0.9, seed=i))
    tie = rrect_mask(430, 760, 600, 820, 20)
    img = comp(img, shade(tie, (240, 106, 166), spec=0.4))
    return img, union

def paint_rose_petals():
    img = new()
    union = mask_new()
    rng = random.Random(4)
    petals = [(380, 420, 0.4), (640, 400, -0.6), (500, 640, 1.2), (300, 700, -1.0), (720, 700, 0.3), (520, 260, 2.2)]
    for i, (x, y, rot) in enumerate(petals):
        pts = []
        for k in range(80):
            a = k / 80 * 2 * math.pi
            r = 150 * (1 - 0.25 * math.cos(a)) * (0.9 + 0.1 * math.cos(2 * a))
            px, py = r * math.cos(a) * 0.85, r * math.sin(a)
            if math.cos(a) > 0.92:
                px *= 0.92
            pts.append((x + px * math.cos(rot) - py * math.sin(rot), y + px * math.sin(rot) + py * math.cos(rot)))
        m = poly_mask(pts, smooth=6)
        union = ImageChops.lighter(union, m)
        img = comp(img, shadow(m, blur=18, alpha=70))
        img = comp(img, outline(m, 5, alpha=150))
        img = comp(img, shade(m, (236, 84, 138), base2=(160, 24, 78), grad_dir=(0.6, 0.6), spec=0.35, shin=16, tilt=0.35, blur=50, seed=i))
        vn = new(); ImageDraw.Draw(vn).line([(x - 90 * math.cos(rot), y - 90 * math.sin(rot)), (x + 70 * math.cos(rot), y + 70 * math.sin(rot))], fill=(120, 10, 50, 110), width=7)
        img = comp(img, clip_to(vn, m))
    return img, union

# ─────────────────────────────────────────────────────────────────────────
# Jam jars
# ─────────────────────────────────────────────────────────────────────────
RARITY_STYLE = {
    'experimental': {'ribbon': (150, 140, 140), 'tag': (214, 200, 180), 'glow': None},
    'common': {'ribbon': (240, 106, 166), 'tag': (232, 214, 182), 'glow': None},
    'uncommon': {'ribbon': (240, 106, 166), 'tag': (246, 226, 232), 'glow': (240, 106, 166)},
    'rare': {'ribbon': (226, 176, 72), 'tag': (250, 236, 200), 'glow': (245, 185, 66)},
    'epic': {'ribbon': (160, 92, 230), 'tag': (236, 226, 250), 'glow': (180, 108, 255)},
    'legendary': {'ribbon': (255, 211, 107), 'tag': (255, 244, 210), 'glow': (255, 211, 107)},
}

def lace_cover(cx, y_top, w, color=(22, 14, 18)):
    pts = []
    n = 14
    for i in range(n + 1):
        t = i / n
        x = cx - w / 2 - 40 + t * (w + 80)
        y = y_top + 140 + (30 if i % 2 else 0)
        pts.append((x, y))
    cap = [(cx - w / 2 + 10, y_top - 20), (cx + w / 2 - 10, y_top - 20)]
    m = poly_mask([cap[0], cap[1]] + [(cx + w / 2 + 40, y_top + 120)] + pts[::-1][:-1] + [(cx - w / 2 - 40, y_top + 120)], smooth=6)
    dome = ellipse_mask(cx, y_top - 10, w / 2 - 10, 60)
    m = ImageChops.lighter(m, dome)
    layer = shade(m, color, base2=(60, 30, 44), grad_dir=(1, 0.3), spec=0.35, shin=16, tilt=1.0, noise=0.15)
    holes = new(); d = ImageDraw.Draw(holes)
    for i in range(n):
        x = cx - w / 2 - 20 + (i + 0.5) / n * (w + 40)
        d.ellipse((x - 9, y_top + 112, x + 9, y_top + 130), fill=(0, 0, 0, 255))
    layer = Image.alpha_composite(layer, clip_to(holes, m))
    a = layer.getchannel('A')
    hm = holes.getchannel('A')
    layer.putalpha(ImageChops.subtract(a, hm))
    return layer, m

def paint_jam(recipe, fruit_imgs, special_imgs, mystery=False):
    rarity = recipe.get('rarity', 'common')
    style = RARITY_STYLE.get(rarity, RARITY_STYLE['common'])
    color = hexrgb(recipe.get('color', '#c8102e'))
    color2 = hexrgb(recipe['color2']) if recipe.get('color2') else None
    img = new()
    cx, cy, w, h = 512, 590, 500, 560
    jar, jm, (x0, y0, x1, y1) = glass_jar(cx, cy, w, h, fill=color, fill2=color2, fill_level=0.9)
    if style['glow'] and not mystery:
        strength = {'uncommon': 110, 'rare': 150, 'epic': 190, 'legendary': 230}.get(rarity, 120)
        img = comp(img, glow(jm, style['glow'], blur=46, alpha=strength, grow=24))
    img = comp(img, jar)
    cover, cm = lace_cover(cx, y0 + 10, w * 0.9)
    img = comp(img, outline(cm, 6, alpha=150))
    img = comp(img, cover)
    rb = new(); d = ImageDraw.Draw(rb)
    d.rectangle((x0 - 10, y0 + 112, x1 + 10, y0 + 146), fill=style['ribbon'] + (255,))
    img = comp(img, clip_to(rb, ImageChops.lighter(cm, jm)))
    img = ribbon_bow(img, cx + 60, y0 + 128, 95, color=style['ribbon'])
    # hanging tag
    tag = poly_mask([(cx + 120, y0 + 200), (cx + 230, y0 + 175), (cx + 270, y0 + 330), (cx + 160, y0 + 355)], smooth=4)
    string = new(); ImageDraw.Draw(string).line([(cx + 70, y0 + 140), (cx + 175, y0 + 205)], fill=(60, 30, 40, 255), width=6)
    img = comp(img, string)
    img = comp(img, outline(tag, 5, alpha=170))
    img = comp(img, shade(tag, style['tag'], spec=0.15, tilt=0.3))
    t = new(); ImageDraw.Draw(t).text((cx + 196, y0 + 268), 'V', font=font(FONT_CINZEL, 96), anchor='mm', fill=(150, 24, 80, 255))
    img = comp(img, t)
    # front label
    lab = rrect_mask(cx - 170, cy + 40, cx + 150, cy + 210, 36)
    img = comp(img, outline(lab, 5, alpha=140))
    img = comp(img, shade(lab, (240, 226, 200), base2=(214, 192, 158), grad_dir=(1, 0.2), spec=0.1, tilt=0.25, noise=0.08))
    t = new(); d = ImageDraw.Draw(t)
    if mystery:
        d.text((cx - 10, cy + 125), '?', font=font(FONT_CINZEL, 150), anchor='mm', fill=(150, 24, 80, 255))
    else:
        d.text((cx - 10, cy + 122), 'Jam', font=font(FONT_SCRIPT, 132), anchor='mm', fill=(70, 20, 30, 255))
    img = comp(img, t)
    # fruit garnish
    if not mystery:
        garnish = []
        for f in recipe.get('fruits', [])[:2]:
            garnish.append(fruit_imgs[f])
        if recipe.get('special') and recipe['special'] in special_imgs:
            garnish.append(special_imgs[recipe['special']])
        spots = [(cx - 300, cy + 220, 0.36), (cx + 300, cy + 240, 0.32), (cx - 120, cy + 300, 0.26)]
        for g, (x, y, sc) in zip(garnish, spots):
            gi = g.resize((int(S * sc), int(S * sc)), Image.LANCZOS)
            layer = new(); layer.paste(gi, (int(x - S * sc / 2), int(y - S * sc / 2)), gi)
            img = comp(img, layer)
    if rarity in ('epic', 'legendary') and not mystery:
        sp = new()
        for (x, y, r) in ((170, 220, 60), (860, 260, 48), (880, 640, 40), (150, 600, 34)):
            sparkle(sp, x, y, r, color=(255, 240, 200) if rarity == 'legendary' else (230, 200, 255))
        img = comp(img, sp)
    if mystery:
        dark = img.copy()
        arr = np.asarray(dark).astype(np.float32)
        arr[..., :3] = arr[..., :3] * 0.18 + np.array([30, 6, 20])
        img = Image.fromarray(arr.clip(0, 255).astype(np.uint8), 'RGBA')
        img = comp(glow(img.getchannel('A'), (240, 106, 166), blur=30, alpha=140, grow=6), img)
        t = new(); ImageDraw.Draw(t).text((cx, cy + 40), '?', font=font(FONT_CINZEL, 300), anchor='mm', fill=(240, 106, 166, 255))
        img = comp(img, t)
    return img

# ─────────────────────────────────────────────────────────────────────────
# Logo
# ─────────────────────────────────────────────────────────────────────────
def gradient_text(size, text, fnt, c1, c2):
    W, H = size
    m = Image.new('L', size, 0)
    ImageDraw.Draw(m).text((W // 2, H // 2), text, font=fnt, anchor='mm', fill=255)
    g = np.zeros((H, W, 4), np.uint8)
    t = np.linspace(0, 1, H)[:, None]
    for i in range(3):
        g[..., i] = (c1[i] * (1 - t) + c2[i] * t).astype(np.uint8)
    g[..., 3] = np.asarray(m)
    return Image.fromarray(g, 'RGBA')

def paint_logo(fruit_imgs, out_path):
    W, H = 2000, 760
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    # crest
    crest = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ring = ellipse_mask(512, 512, 440, 440)
    crest = comp(crest, glow(ring, (240, 106, 166), blur=40, alpha=120))
    crest = comp(crest, shade(ring, (32, 16, 26), base2=(14, 6, 12), spec=0.3, tilt=0.6))
    d = ImageDraw.Draw(crest)
    d.ellipse((92, 92, 932, 932), outline=(216, 178, 106, 255), width=16)
    d.ellipse((132, 132, 892, 892), outline=(240, 106, 166, 200), width=6)
    v = gradient_text((S, S), 'V', font(FONT_CINZEL, 600), (255, 190, 220), (200, 40, 120))
    crest = comp(crest, v)
    for name, x, y, sc in (('strawberry', 230, 780, 0.3), ('cherry', 800, 770, 0.3), ('raspberry', 512, 860, 0.26)):
        f = fruit_imgs[name].resize((int(S * sc), int(S * sc)), Image.LANCZOS)
        layer = new(); layer.paste(f, (int(x - S * sc / 2), int(y - S * sc / 2)), f)
        crest = comp(crest, layer)
    crest = crest.resize((640, 640), Image.LANCZOS)
    img.alpha_composite(crest, (40, 60))
    title = gradient_text((1300, 360), 'VELORA', font(FONT_CINZEL, 290), (255, 214, 232), (230, 80, 150))
    shadow_t = title.copy().filter(ImageFilter.GaussianBlur(14))
    img.alpha_composite(shadow_t, (690, 70))
    img.alpha_composite(title, (680, 60))
    sub = gradient_text((1300, 300), 'Jam Co.', font(FONT_SCRIPT, 230), (243, 215, 154), (205, 160, 80))
    img.alpha_composite(sub, (680, 360))
    d = ImageDraw.Draw(img)
    d.line([(760, 400), (1880, 400)], fill=(216, 178, 106, 200), width=4)
    img = img.resize((1000, 380), Image.LANCZOS)
    img.save(out_path, optimize=True)

# ─────────────────────────────────────────────────────────────────────────
def load_recipes():
    try:
        import lupa.lua54 as L
    except ImportError:
        import lupa as L
    lua = L.LuaRuntime(unpack_returned_tuples=True)
    src = open(os.path.join(RES, 'server', 'recipes.lua'), encoding='utf-8').read()
    lua.execute(src)
    out = []
    def conv(t):
        r = {}
        for k, v in t.items():
            if hasattr(v, 'items'):
                r[k] = [v[i] for i in range(1, len(v) + 1)]
            else:
                r[k] = v
        return r
    recipes = lua.globals().Recipes
    for i in range(1, len(recipes) + 1):
        out.append(conv(recipes[i]))
    out.append(conv(lua.globals().ExperimentalRecipe))
    return out

def main():
    items_dir = os.path.join(RES, 'web', 'images', 'items')
    jams_dir = os.path.join(RES, 'web', 'images', 'jams')
    ui_dir = os.path.join(RES, 'web', 'images', 'ui')
    for d in (items_dir, jams_dir, ui_dir):
        os.makedirs(d, exist_ok=True)

    fruit_imgs = {}
    for name, painter in FRUIT_PAINTERS.items():
        im, _ = painter()
        fruit_imgs[name] = im
        finish(im, os.path.join(items_dir, f'fruit_{name}.png'))
        print('fruit', name)
    golden, _ = paint_golden()
    finish(golden, os.path.join(items_dir, 'golden_fruit.png'))

    special_imgs = {}
    for key, painter, item in (
        ('cinnamon', paint_cinnamon, 'jam_cinnamon'), ('honey', paint_honey, 'jam_honey'),
        ('vanilla', paint_vanilla, 'jam_vanilla'), ('lavender', paint_lavender, 'jam_lavender'),
        ('rose_petals', paint_rose_petals, 'jam_rose_petals')):
        im, _ = painter()
        special_imgs[key] = im
        finish(im, os.path.join(items_dir, f'{item}.png'))
        print('special', key)
    special_imgs['golden'] = golden

    for painter, item in ((paint_sugar, 'jam_sugar'), (paint_jar_empty, 'jam_jar_empty'), (paint_lid, 'jam_jar_lid'),
                          (paint_pectin, 'jam_pectin'), (paint_bowl, 'jam_mixing_bowl')):
        im, _ = painter()
        finish(im, os.path.join(items_dir, f'{item}.png'))
        print('supply', item)
    im, _ = paint_basket(fruit_imgs)
    finish(im, os.path.join(items_dir, 'fruit_basket.png'))

    recipes = load_recipes()
    for r in recipes:
        im = paint_jam(r, fruit_imgs, special_imgs)
        finish(im, os.path.join(jams_dir, f"{r['image']}.png"))
        if r['id'] == 'strawberry_jam':
            finish(im, os.path.join(items_dir, 'velora_jam.png'))
        print('jam', r['image'], r['id'])
    myst = paint_jam({'rarity': 'common', 'color': '#3a1030'}, fruit_imgs, special_imgs, mystery=True)
    finish(myst, os.path.join(jams_dir, 'jar_mystery.png'))
    # rarity showcase jars for the "possible outcomes" card
    for rar, col, c2 in (('common', '#5a1a52', None), ('uncommon', '#d01849', '#ff7aa2'), ('rare', '#f5a623', '#ffe46b'),
                         ('epic', '#2b1f5e', '#9a7be0'), ('legendary', '#9e0a2e', '#ffd36b')):
        im = paint_jam({'rarity': rar, 'color': col, 'color2': c2}, fruit_imgs, special_imgs)
        finish(im, os.path.join(ui_dir, f'tier_{rar}.png'), size=200)
    paint_logo(fruit_imgs, os.path.join(ui_dir, 'logo.png'))
    print('done')

if __name__ == '__main__':
    main()
