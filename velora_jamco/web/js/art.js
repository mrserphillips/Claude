/* Velora Jam Co. — optional artwork for the minigames.
   Drop images into web/images/minigames/ (see install/ART_GUIDE.md). Anything missing falls back to
   the built-in drawings, so you can add art one piece at a time.

   ART_LAYOUT positions are in minigame canvas units (crafting: 1000 × 520, orchard: 1000 × 560).
   If a painted image doesn't line up perfectly, nudge the numbers here — no other code needs changing. */
'use strict';

const ART_BASE = 'images/minigames/';
const ART_VERSION = window.VJ_LOAD_T || Date.now(); // fresh every session so changed artwork always shows

const ART_FILES = {
    // shared
    kitchenBg: 'kitchen_bg.jpg',          // backdrop behind every crafting stage
    jamTexture: 'jam_texture.jpg',        // greyscale jam surface, tinted with the recipe colour
    // A: prepare
    prepareBg: 'prepare/bg.jpg',
    board: 'prepare/board.png',
    knife: 'prepare/knife.png',
    // B: heat
    heatBg: 'heat/bg.jpg',
    stove: 'heat/stove.png',
    pot: 'heat/pot.png',
    potFront: 'heat/pot_front.png',       // optional: front lip drawn OVER the jam for depth
    // C: stir
    stirBg: 'stir/bg.jpg',
    potTop: 'stir/pot_top.png',           // alternative top-down pot (used only if heat/pot.png is missing)
    spoon: 'stir/spoon.png',
    // D: fill
    fillBg: 'fill/bg.jpg',
    jarBack: 'fill/jar_back.png',         // optional: back wall of the jar (drawn behind the jam)
    jar: 'fill/jar.png',                  // glass jar drawn OVER the jam
    ladle: 'fill/ladle.png',
    pourPot: 'fill/pour_pot.png',         // tipped pot used instead of the ladle
    pourStream: 'fill/pour_stream.png',   // the jam stream falling from it
    // E: seal
    sealBg: 'seal/bg.jpg',
    jarTop: 'seal/jar_top.png',
    lid: 'seal/lid.png',
    // orchard
    harvestBg: 'harvest/bg.jpg',
    branch: 'harvest/branch.png',
    basket: 'harvest/basket.png',
};

const ART_LAYOUT = {
    prepare: {
        board: { x: 120, y: 118, w: 760, h: 261 },
        // where fruit is laid out on the board image (two rows)
        targets: { x0: 190, x1: 715, row1: 182, row2: 282, size: 84 },
        knife: { w: 220, h: 60, tipX: 0.08, tipY: 0.5 },
    },
    heat: {
        pot: { x: 305, y: 58, w: 390, h: 300 },               // whole pot image box
        surface: { x: 500, y: 149, rx: 148, ry: 61 },         // the open top of the pot where jam shows
        stove: { x: 260, y: 345, w: 480, h: 50 },
        flameY: 352, flameRadius: 120,
    },
    stir: {
        pot: { x: 205, y: 30, w: 590, h: 454 },               // same pot image, larger
        surface: { x: 500, y: 167, rx: 223, ry: 92 },
        spoon: { height: 270, bowlY: 0.86, lean: 0.32 },      // bowl position as a fraction of spoon height
        potTop: { x: 269, y: 29, w: 462, h: 462 }, surfaceTop: { x: 500, y: 260, r: 205 },
        spoonTop: { w: 300, h: 80, headX: 0.13, headY: 0.5 },
    },
    fill: {
        jar: { x: 380, y: 200, w: 280, h: 297 },              // jar image box
        inside: { x: 400, y: 271, w: 240, h: 208, r: 30 },    // where jam fills (inside the glass)
        pour: { x: 456, y: 2, scale: 0.28, streamStart: 480, idleTilt: 0.45, pivotX: 300, pivotY: 300 },
        ladle: { w: 310, h: 110, pivotX: 50, pivotY: 55 },
    },
    seal: { jarTop: { x: 250, y: 10, w: 500, h: 500 }, lid: { size: 380 } },
    harvest: { branchThickness: 150, basket: { x: 830, y: 410, w: 150, h: 150 } },
};

// Geometry used when the matching image is NOT present (the built-in drawings)
const ART_FALLBACK = {
    heatSurface: { x: 500, y: 154, rx: 148, ry: 27 },
    fillInside: { x: 470, y: 140, w: 220, h: 290, r: 26 },
};

const Art = (() => {
    const cache = {};
    function load(path) {
        if (cache[path]) return cache[path];
        const entry = { img: new Image(), ok: false, failed: false };
        entry.img.onload = () => { entry.ok = true; };
        entry.img.onerror = () => { entry.failed = true; };
        entry.img.src = ART_BASE + path + '?v=' + ART_VERSION;
        cache[path] = entry;
        return entry;
    }
    return {
        /** returns a loaded image or null (never blocks, never throws) */
        get(key) {
            const file = ART_FILES[key];
            if (!file) return null;
            const e = load(file);
            return e.ok ? e.img : null;
        },
        /** per-fruit art: fruit/<id>.png, fruit/<id>_unripe.png, fruit/<id>_rotten.png, fruit/<id>_cut.png */
        fruit(id, variant) {
            const e = load(`fruit/${id}${variant ? '_' + variant : ''}.png`);
            return e.ok ? e.img : null;
        },
        preload(keys) { (keys || Object.keys(ART_FILES)).forEach((k) => ART_FILES[k] && load(ART_FILES[k])); },
        preloadFruit(ids) { ids.forEach((id) => ['', 'unripe', 'rotten', 'cut'].forEach((v) => load(`fruit/${id}${v ? '_' + v : ''}.png`))); },
        /** draw an image to cover a box (like CSS object-fit: cover) */
        cover(ctx, img, x, y, w, h) {
            const s = Math.max(w / img.width, h / img.height);
            const sw = w / s, sh = h / s;
            ctx.drawImage(img, (img.width - sw) / 2, (img.height - sh) / 2, sw, sh, x, y, w, h);
        },
    };
})();

/* Tinted, glossy jam surface: greyscale texture × recipe colour, clipped to a shape.
   Falls back to a flat colour when no texture is present. */
const JamPaint = (() => {
    const off = document.createElement('canvas');
    off.width = off.height = 512;
    const octx = off.getContext('2d');
    let lastKey = '';
    let highlights = null, highlightSrc = null;

    // Pull only the brightest parts of the texture out as a glossy highlight layer (computed once)
    function highlightLayer(tex) {
        if (highlightSrc === tex) return highlights;
        highlightSrc = tex;
        highlights = null;
        try {
            const c = document.createElement('canvas');
            c.width = c.height = 512;
            const x = c.getContext('2d');
            x.drawImage(tex, 0, 0, 512, 512);
            const data = x.getImageData(0, 0, 512, 512);
            const p = data.data;
            for (let i = 0; i < p.length; i += 4) {
                const v = (p[i] + p[i + 1] + p[i + 2]) / 765;
                const h = Math.max(0, (v - 0.9) / 0.1);
                p[i] = p[i + 1] = p[i + 2] = 255;
                p[i + 3] = Math.round(h * 255);
            }
            x.putImageData(data, 0, 0);
            highlights = c;
        } catch (e) { highlights = null; }
        return highlights;
    }

    function tinted(color) {
        const tex = Art.get('jamTexture');
        if (!tex) return null;
        const key = color.join(',') + (tex.src || '');
        if (key !== lastKey) {
            // cooked jam is deeper than the raw fruit colour
            const c = color.map((v) => Math.round(v * 0.72));
            octx.globalCompositeOperation = 'source-over';
            octx.clearRect(0, 0, 512, 512);
            octx.drawImage(tex, 0, 0, 512, 512);
            octx.globalCompositeOperation = 'multiply';
            octx.fillStyle = `rgb(${c[0]},${c[1]},${c[2]})`;
            octx.fillRect(0, 0, 512, 512);
            octx.globalCompositeOperation = 'source-over';
            const hl = highlightLayer(tex);
            if (hl) { octx.globalAlpha = 0.8; octx.drawImage(hl, 0, 0); octx.globalAlpha = 1; }
            lastKey = key;
        }
        return off;
    }
    return {
        texture: tinted,
        /** fill the current path (call ctx.beginPath()/ellipse/arc first) with jam */
        fill(ctx, color, box, rotation = 0, darken = 0) {
            const t = tinted(color);
            ctx.save();
            ctx.clip();
            if (t) {
                const cx = box.x + box.w / 2, cy = box.y + box.h / 2;
                const size = Math.max(box.w, box.h) * 1.5;
                ctx.translate(cx, cy); ctx.rotate(rotation);
                ctx.drawImage(t, -size / 2, -size / 2, size, size);
            } else {
                ctx.fillStyle = `rgb(${color[0]},${color[1]},${color[2]})`;
                ctx.fillRect(box.x - 50, box.y - 50, box.w + 100, box.h + 100);
            }
            ctx.restore();
            if (darken > 0) {
                ctx.save(); ctx.clip(); ctx.fillStyle = `rgba(25,10,6,${darken})`; ctx.fillRect(box.x - 50, box.y - 50, box.w + 100, box.h + 100); ctx.restore();
            }
        },
    };
})();

window.Art = Art;
window.ART_LAYOUT = ART_LAYOUT;
window.JamPaint = JamPaint;
window.ART_FALLBACK = ART_FALLBACK;
