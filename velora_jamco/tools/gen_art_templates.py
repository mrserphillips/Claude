#!/usr/bin/env python3
"""Writes sizing templates for the minigame artwork into install/art-templates/.
Each template is the exact pixel size to deliver, with guides showing where the
game draws jam, where the pivot points are, etc. Usage: python3 tools/gen_art_templates.py"""
import os
from PIL import Image, ImageDraw, ImageFont
OUT = os.path.join(os.path.dirname(__file__), '..', 'install', 'art-templates')
os.makedirs(OUT, exist_ok=True)
try:
    F = ImageFont.truetype('DejaVuSans.ttf', 26); FS = ImageFont.truetype('DejaVuSans.ttf', 18)
except OSError:
    F = FS = ImageFont.load_default()
PINK, GOLD, CYAN = (240, 106, 166, 255), (243, 215, 154, 255), (90, 220, 255, 255)

def tpl(name, w, h, title, notes, guides, opaque=False):
    im = Image.new('RGBA', (w, h), (40, 32, 38, 255) if opaque else (60, 60, 60, 70))
    d = ImageDraw.Draw(im)
    for x in range(0, w, 40):
        d.line([(x, 0), (x, h)], fill=(255, 255, 255, 18))
    for y in range(0, h, 40):
        d.line([(0, y), (w, y)], fill=(255, 255, 255, 18))
    d.rectangle((0, 0, w - 1, h - 1), outline=GOLD, width=3)
    for g in guides:
        kind = g[0]
        if kind == 'ellipse':
            _, cx, cy, rx, ry, label = g
            d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), outline=PINK, width=4)
            d.text((cx, cy), label, font=FS, fill=PINK, anchor='mm')
        elif kind == 'rect':
            _, x, y, rw, rh, label = g
            d.rounded_rectangle((x, y, x + rw, y + rh), 20, outline=PINK, width=4)
            d.text((x + rw / 2, y + rh / 2), label, font=FS, fill=PINK, anchor='mm')
        elif kind == 'point':
            _, x, y, label = g
            d.ellipse((x - 10, y - 10, x + 10, y + 10), outline=CYAN, width=4)
            d.line([(x - 22, y), (x + 22, y)], fill=CYAN, width=2); d.line([(x, y - 22), (x, y + 22)], fill=CYAN, width=2)
            d.text((x + 16, y - 26), label, font=FS, fill=CYAN)
        elif kind == 'arrow':
            _, x0, y0, x1, y1, label = g
            d.line([(x0, y0), (x1, y1)], fill=CYAN, width=4)
            d.text(((x0 + x1) / 2, (y0 + y1) / 2 - 22), label, font=FS, fill=CYAN, anchor='mm')
    d.text((14, 12), f'{name}   {w} x {h} px', font=F, fill=GOLD)
    for i, n in enumerate(notes):
        d.text((14, 48 + i * 24), n, font=FS, fill=(255, 255, 255, 230))
    path = os.path.join(OUT, name.replace('/', '__') + '.png')
    im.save(path)
    print(path)

tpl('kitchen_bg.jpg', 2000, 1040, '', ['Background behind every crafting stage (no UI, no text).', 'Kitchen wall / worktop, soft focus. Also usable per stage: prepare/bg.jpg, heat/bg.jpg ...'], [], True)
tpl('prepare/board.png', 1400, 680, '', ['Top-down wooden chopping board, transparent around it.'], [])
tpl('prepare/knife.png', 440, 120, '', ['Knife pointing LEFT, transparent. Tip at the marked point.'], [('point', 35, 60, 'tip')])
tpl('heat/stove.png', 960, 220, '', ['Front view of a hob / burner the pot sits on. Transparent.'], [])
tpl('heat/pot.png', 800, 460, '', ['Copper jam pot, front view, transparent. Open top must match the pink ellipse:', 'the game paints bubbling jam into it.'], [('ellipse', 400, 116, 296, 54, 'jam surface')])
tpl('heat/pot_front.png', 800, 460, '', ['OPTIONAL: only the front lip of the rim (everything else transparent).', 'Drawn over the jam so it looks inside the pot.'], [('ellipse', 400, 116, 296, 54, 'rim')])
tpl('stir/pot_top.png', 924, 924, '', ['Pot seen from directly above, transparent outside.', 'Jam is painted inside the pink circle.'], [('ellipse', 462, 462, 410, 410, 'jam')])
tpl('stir/spoon.png', 600, 160, '', ['Wooden spoon, top view, bowl on the LEFT, handle to the right. Transparent.'], [('point', 78, 80, 'bowl centre')])
tpl('fill/jar.png', 560, 704, '', ['Empty glass jar, front view. Glass must be SEE-THROUGH where the jam fills (pink box).', 'Drawn over the jam, so keep highlights/reflections in it.'], [('rect', 60, 96, 440, 580, 'jam fills here')])
tpl('fill/jar_back.png', 560, 704, '', ['OPTIONAL: back wall of the jar, drawn behind the jam.'], [('rect', 60, 96, 440, 580, '')])
tpl('fill/ladle.png', 620, 220, '', ['Ladle, side view, bowl on the LEFT, handle to the right. Transparent.'], [('point', 100, 110, 'bowl centre (pivot)')])
tpl('seal/jar_top.png', 1000, 1000, '', ['Open jar seen from above, transparent. The lid is placed on the centre.'], [('ellipse', 500, 500, 330, 330, 'lid sits here')])
tpl('seal/lid.png', 760, 760, '', ['Jar lid seen from directly above, centred, transparent. It rotates as you twist.'], [('ellipse', 380, 380, 370, 370, '')])
tpl('harvest/bg.jpg', 2000, 1120, '', ['Orchard background behind the branches. Soft focus, no fruit in focus.'], [], True)
tpl('harvest/branch.png', 2400, 240, '', ['One long leafy branch, base on the LEFT, tip on the RIGHT, transparent.', 'The game bends it to fit each branch.'], [('arrow', 60, 140, 2340, 120, 'base  ->  tip')])
tpl('harvest/basket.png', 300, 300, '', ['Fruit basket, transparent.'], [])
tpl('fruit/<fruit>.png', 256, 256, '', ['One fruit, centred, transparent. Also <fruit>_unripe.png,', '<fruit>_rotten.png and <fruit>_cut.png (sliced open).'], [('ellipse', 128, 128, 100, 100, '')])
