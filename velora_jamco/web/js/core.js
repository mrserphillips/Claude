/* Velora Jam Co. — NUI core: messaging, focus, helpers, overlays */
'use strict';

const UI_VERSION = '1.2.1';
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'velora_jamco';
const VJ = { app: null, apps: {}, data: null };

/* ── Lua bridge ─────────────────────────────────────────────────────── */
async function post(name, payload) {
    try {
        const res = await fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload ?? {}),
        });
        const text = await res.text();
        try { return JSON.parse(text); } catch { return text; }
    } catch (e) {
        return null;
    }
}
function server(name, ...args) { return post('server', { name, args }); }

/* ── Helpers ────────────────────────────────────────────────────────── */
const $ = (sel, el = document) => el.querySelector(sel);
const $$ = (sel, el = document) => Array.from(el.querySelectorAll(sel));
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => '$' + Math.floor(n || 0).toLocaleString('en-US');
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const lerp = (a, b, t) => a + (b - a) * t;
const itemImg = (item) => `images/items/${item}.png`;
const jamImg = (img) => `images/jams/${img || 'jar_mystery'}.png`;
const RARITY = {
    experimental: { label: 'Experimental', color: '#9c8f8f' },
    common: { label: 'Common', color: '#c9b8a8' },
    uncommon: { label: 'Uncommon', color: '#f06aa6' },
    rare: { label: 'Rare', color: '#f5b942' },
    epic: { label: 'Epic', color: '#b46cff' },
    legendary: { label: 'Legendary', color: '#ffd36b' },
};
const rarityOf = (id) => RARITY[id] || RARITY.common;
const pill = (id) => { const r = rarityOf(id); return `<span class="pill" style="color:${r.color}">${esc(r.label)}</span>`; };

function el(html) {
    const t = document.createElement('template');
    t.innerHTML = html.trim();
    return t.content.firstElementChild;
}

const CORNER_SVG = `<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">
  <g fill="none" stroke="#d8b26a" stroke-width="1.4" opacity=".85">
    <path d="M6 112 C6 60 20 24 60 10 M10 104 C24 70 44 48 84 40"/>
    <path d="M18 78 c-8-6-10-16-4-22 M30 52 c8-2 14 4 12 12 M52 30 c-6-8-2-18 8-18"/>
  </g>
  <g fill="#f06aa6"><circle cx="60" cy="10" r="5"/><circle cx="84" cy="40" r="4"/><circle cx="14" cy="56" r="4.5"/></g>
  <g fill="#c2185b"><circle cx="57" cy="8" r="2.2"/><circle cx="82" cy="38" r="1.8"/><circle cx="12" cy="54" r="2"/></g>
  <g fill="#5b8a46" opacity=".9"><path d="M40 22 q8-6 14 0 q-8 6-14 0z"/><path d="M22 42 q2-10 10-10 q-2 10-10 10z"/><path d="M70 34 q6-8 12-4 q-6 8-12 4z"/></g>
</svg>`;
function corners() {
    return ['tl', 'tr', 'bl', 'br'].map((c) => `<div class="corner ${c}">${CORNER_SVG}</div>`).join('');
}

/* ── Open / close ───────────────────────────────────────────────────── */
function openApp(app, data) {
    const root = $('#root');
    if (VJ.app && VJ.app !== app) closeApp(true);
    VJ.app = app;
    VJ.data = data;
    root.classList.remove('hidden');
    root.classList.toggle('clear', app === 'sell');
    $$('.app', root).forEach((s) => s.classList.add('hidden'));
    const section = $(`#app-${app}`);
    section.classList.remove('hidden');
    const mod = VJ.apps[app];
    if (mod && mod.open) mod.open(section, data || {});
}

function closeApp(silent) {
    const app = VJ.app;
    if (app && VJ.apps[app] && VJ.apps[app].close) {
        try { VJ.apps[app].close(); } catch (e) { console.error(e); }
    }
    VJ.app = null;
    $('#root').classList.add('hidden');
    $$('.app').forEach((s) => { s.classList.add('hidden'); s.innerHTML = ''; });
    hideReveal();
    if (!silent) { /* lua already knows */ }
}

/* Closing from the UI: hide immediately (never leave a black overlay) then tell Lua */
function requestClose() {
    if (!VJ.app) { post('close'); return; }
    closeApp(true);
    post('close');
}

window.addEventListener('message', (e) => {
    const msg = e.data || {};
    switch (msg.action) {
        case 'open': openApp(msg.app, msg.data); break;
        case 'close': if (VJ.app) closeApp(true); break;
        case 'version': {
            const v = $('#vj-version');
            v.textContent = `Velora Jam Co. UI v${UI_VERSION}`;
            v.classList.add('show');
            setTimeout(() => v.classList.remove('show'), 6000);
            break;
        }
        case 'achievements': (msg.data || []).forEach((a) => toast(a.label, a.description)); break;
        default: {
            const mod = VJ.app && VJ.apps[VJ.app];
            if (mod && mod.message) mod.message(msg.action, msg.data);
        }
    }
});

window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && VJ.app) {
        e.preventDefault();
        requestClose();
        return;
    }
    if (VJ.app && VJ.apps[VJ.app] && VJ.apps[VJ.app].key) VJ.apps[VJ.app].key(e, true);
});
window.addEventListener('keyup', (e) => {
    if (VJ.app && VJ.apps[VJ.app] && VJ.apps[VJ.app].key) VJ.apps[VJ.app].key(e, false);
});
document.addEventListener('click', (e) => {
    if (e.target.closest('[data-close]')) requestClose();
});

/* ── Toasts ─────────────────────────────────────────────────────────── */
function toast(title, text, icon = 'V') {
    const box = $('#toasts');
    const t = el(`<div class="toast"><div class="ach on"><div class="medal">${esc(icon)}</div></div><div><b>${esc(title)}</b><span class="small">${esc(text)}</span></div></div>`);
    box.appendChild(t);
    if (window.SFX) SFX.chime();
    setTimeout(() => { t.style.transition = '.4s'; t.style.opacity = '0'; t.style.transform = 'translateX(30px)'; }, 4600);
    setTimeout(() => t.remove(), 5100);
}

/* ── Confirm dialog (inside a panel) ────────────────────────────────── */
function confirmBox(container, text, okLabel = 'Yes', cancelLabel = 'Cancel') {
    return new Promise((resolve) => {
        const box = el(`<div class="confirm"><div class="card gold-edge"><p style="margin-bottom:18px">${esc(text)}</p>
            <div class="row" style="justify-content:center"><button class="btn ghost" data-a="no">${esc(cancelLabel)}</button><button class="btn" data-a="yes">${esc(okLabel)}</button></div></div></div>`);
        container.appendChild(box);
        box.addEventListener('click', (e) => {
            const a = e.target.closest('[data-a]');
            if (!a) return;
            box.remove();
            resolve(a.dataset.a === 'yes');
        });
    });
}

/* ── Discovery reveal ───────────────────────────────────────────────── */
let revealAnim = null;
function showReveal(recipe, onDone) {
    const box = $('#reveal');
    const r = rarityOf(recipe.rarity);
    box.innerHTML = `<canvas></canvas><div class="rays"></div><div class="content">
        <div class="kicker">NEW RECIPE DISCOVERED</div>
        <img src="${jamImg(recipe.image)}" alt="">
        <div class="name">${esc(recipe.label)}</div>
        <span class="pill" style="color:${r.color}">${esc(r.label)}</span>
        <div class="desc">${esc(recipe.description || '')}</div>
        <button class="btn big">Add to Recipe Book</button></div>`;
    box.classList.remove('hidden');
    if (window.SFX) SFX.reveal();
    const cv = $('canvas', box);
    const ctx = cv.getContext('2d');
    const parts = [];
    const resize = () => { cv.width = innerWidth; cv.height = innerHeight; };
    resize();
    const tint = recipe.rarity === 'legendary' ? [255, 211, 107] : recipe.rarity === 'epic' ? [190, 120, 255] : [255, 110, 175];
    for (let i = 0; i < 160; i++) {
        parts.push({ x: innerWidth / 2, y: innerHeight / 2, vx: (Math.random() - .5) * 14, vy: (Math.random() - .5) * 14 - 2, r: Math.random() * 3 + 1, life: 1, d: Math.random() * .006 + .004 });
    }
    let t0 = performance.now();
    const tick = (now) => {
        ctx.clearRect(0, 0, cv.width, cv.height);
        if (now - t0 > 120 && parts.length < 260) {
            parts.push({ x: Math.random() * cv.width, y: cv.height + 10, vx: (Math.random() - .5) * .6, vy: -Math.random() * 1.8 - .6, r: Math.random() * 2.5 + .8, life: 1, d: .003 });
            t0 = now;
        }
        for (let i = parts.length - 1; i >= 0; i--) {
            const p = parts[i];
            p.x += p.vx; p.y += p.vy; p.vx *= .985; p.vy *= .985; p.life -= p.d;
            if (p.life <= 0) { parts.splice(i, 1); continue; }
            const g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, p.r * 5);
            g.addColorStop(0, `rgba(${tint[0]},${tint[1]},${tint[2]},${p.life})`);
            g.addColorStop(1, `rgba(${tint[0]},${tint[1]},${tint[2]},0)`);
            ctx.fillStyle = g;
            ctx.beginPath(); ctx.arc(p.x, p.y, p.r * 5, 0, Math.PI * 2); ctx.fill();
        }
        revealAnim = requestAnimationFrame(tick);
    };
    revealAnim = requestAnimationFrame(tick);
    $('.btn', box).addEventListener('click', () => { hideReveal(); if (onDone) onDone(); });
}
function hideReveal() {
    if (revealAnim) cancelAnimationFrame(revealAnim);
    revealAnim = null;
    const box = $('#reveal');
    box.classList.add('hidden');
    box.innerHTML = '';
}

/* ── Canvas helper: crisp, responsive canvas inside a container ─────── */
function fitCanvas(canvas, logicalW, logicalH) {
    const parent = canvas.parentElement;
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = parent.clientWidth, h = parent.clientHeight;
    canvas.width = Math.max(1, Math.floor(w * dpr));
    canvas.height = Math.max(1, Math.floor(h * dpr));
    const scale = Math.min(w / logicalW, h / logicalH);
    const ox = (w - logicalW * scale) / 2, oy = (h - logicalH * scale) / 2;
    return { dpr, scale, ox, oy, w, h,
        apply(ctx) { ctx.setTransform(dpr * scale, 0, 0, dpr * scale, dpr * ox, dpr * oy); },
        toLogical(clientX, clientY) {
            const r = canvas.getBoundingClientRect();
            return { x: (clientX - r.left - ox) / scale, y: (clientY - r.top - oy) / scale };
        } };
}

const IMG_CACHE = {};
function loadImage(src) {
    if (IMG_CACHE[src]) return IMG_CACHE[src];
    const img = new Image();
    img.src = src;
    IMG_CACHE[src] = img;
    return img;
}

/* Signal readiness (Lua side ignores unknown callbacks safely) */
window.addEventListener('load', () => {
    document.body.dataset.ready = '1';
    // tell Lua which UI build actually loaded (shown by /jamversion)
    post('uiVersion', { version: UI_VERSION });
});
