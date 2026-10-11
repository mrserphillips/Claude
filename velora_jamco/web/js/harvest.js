/* Velora Jam Co. — fruit picking minigame */
'use strict';

VJ.apps.harvest = (() => {
    const W = 1000, H = 560;
    let root, spec, cv, ctx, fit, raf = 0, st = null, scene = null, sprites = null, ended = false, started = false;

    function rng(seed) { let s = seed >>> 0; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296); }

    /* ── Scene: branches, leaves and hanging points ───────────────────── */
    function buildScene() {
        const r = rng(Math.floor(Math.random() * 1e9));
        const branches = [];
        const anchors = [];
        const leaves = [];
        const defs = [
            { x0: -20, y0: 70, x1: 560, y1: 120, c: 260 },
            { x0: 1020, y0: 150, x1: 380, y1: 220, c: 300 },
            { x0: -20, y0: 300, x1: 620, y1: 330, c: 240 },
            { x0: 1020, y0: 380, x1: 470, y1: 420, c: 200 },
        ];
        const bush = spec.kind === 'bush';
        defs.forEach((d, bi) => {
            const cx = (d.x0 + d.x1) / 2, cy = Math.min(d.y0, d.y1) - 40 - r() * 40;
            const br = { ...d, cx, cy, w: bush ? 10 : 22 - bi * 2 };
            branches.push(br);
            const pt = (t) => ({
                x: (1 - t) * (1 - t) * d.x0 + 2 * (1 - t) * t * cx + t * t * d.x1,
                y: (1 - t) * (1 - t) * d.y0 + 2 * (1 - t) * t * cy + t * t * d.y1,
            });
            for (let i = 0; i < 26; i++) {
                const t = 0.08 + r() * 0.92;
                const p = pt(t);
                leaves.push({ x: p.x + (r() - .5) * 40, y: p.y + (r() - .5) * 30, a: r() * Math.PI * 2, s: 16 + r() * 18, c: r(), ph: r() * 6 });
            }
            for (let i = 0; i < 5; i++) {
                const t = 0.18 + i * 0.17 + (r() - .5) * 0.06;
                const p = pt(t);
                anchors.push({ x: p.x, y: p.y + 6, len: 30 + r() * 40, busy: false });
            }
        });
        return { branches, anchors, leaves, motes: Array.from({ length: 40 }, () => ({ x: r() * W, y: r() * H, s: r() * 2 + .5, v: r() * 10 + 4 })) };
    }

    /* ── Sprites: ripe / unripe / rotten variants of the fruit image ──── */
    function variant(img, mode) {
        const c = document.createElement('canvas');
        c.width = 128; c.height = 128;
        const x = c.getContext('2d');
        if (mode === 'unripe') x.filter = 'grayscale(1) brightness(1.15) contrast(.9)';
        if (mode === 'rotten') x.filter = 'grayscale(.5) sepia(1) brightness(.42) contrast(1.3)';
        x.drawImage(img, 0, 0, 128, 128);
        x.filter = 'none';
        x.globalCompositeOperation = 'source-atop';
        if (mode === 'unripe') { x.fillStyle = 'rgba(110,175,60,.62)'; x.fillRect(0, 0, 128, 128); }
        if (mode === 'rotten') {
            x.fillStyle = 'rgba(40,28,10,.85)';
            for (let i = 0; i < 7; i++) { x.beginPath(); x.arc(30 + Math.random() * 70, 40 + Math.random() * 60, 5 + Math.random() * 9, 0, 7); x.fill(); }
        }
        return c;
    }

    function prepareSprites(done) {
        const fruit = loadImage(itemImg(spec.fruit.item));
        const golden = loadImage(itemImg('golden_fruit'));
        const basket = loadImage(itemImg('fruit_basket'));
        const ready = () => fruit.complete && golden.complete && basket.complete;
        const go = () => {
            sprites = { ripe: fruit, unripe: variant(fruit, 'unripe'), rotten: variant(fruit, 'rotten'), golden, basket };
            done();
        };
        if (ready()) go();
        else { let n = 0; const iv = setInterval(() => { if (ready() || ++n > 40) { clearInterval(iv); go(); } }, 50); }
    }

    /* ── Game state ───────────────────────────────────────────────────── */
    function newGame() {
        const d = spec.difficulty;
        const T = d.time;
        const fruits = [];
        const span = Math.max(4, T - d.ripeWindow - d.unripeTime - 1.4);
        for (let i = 0; i < spec.ripe; i++) {
            fruits.push({ kind: 'ripe', spawn: 0.5 + (i + Math.random() * 0.6) * (span / spec.ripe) });
        }
        for (let i = 0; i < spec.rotten; i++) fruits.push({ kind: 'rotten', spawn: 1 + Math.random() * (T - 4.5) });
        if (spec.golden) fruits.push({ kind: 'golden', spawn: T * (0.3 + Math.random() * 0.35) });
        fruits.sort((a, b) => a.spawn - b.spawn);
        fruits.forEach((f) => Object.assign(f, { state: 'hidden', t: 0, ph: Math.random() * 6, x: 0, y: 0, scale: 0, vy: 0, rot: 0 }));
        return { time: 0, T, fruits, picked: 0, rotten: 0, golden: false, texts: [], parts: [], last: performance.now() };
    }

    function freeAnchor() {
        const free = scene.anchors.filter((a) => !a.busy);
        if (!free.length) return null;
        const a = free[Math.floor(Math.random() * free.length)];
        a.busy = true;
        return a;
    }

    function release(f) { if (f.anchor) { f.anchor.busy = false; f.anchor = null; } }

    function float(text, x, y, color) { st.texts.push({ text, x, y, color, t: 0 }); }
    function burst(x, y, color, n = 14) {
        for (let i = 0; i < n; i++) {
            const a = Math.random() * Math.PI * 2, s = 80 + Math.random() * 180;
            st.parts.push({ x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s - 60, life: 1, color, r: 2 + Math.random() * 3 });
        }
    }

    function update(dt) {
        const d = spec.difficulty;
        st.time += dt;
        for (const f of st.fruits) {
            f.t += dt;
            if (f.state === 'hidden') {
                if (st.time >= f.spawn) {
                    f.anchor = freeAnchor();
                    if (f.anchor) { f.state = 'grow'; f.t = 0; } else { f.spawn += 0.4; }
                }
                continue;
            }
            if (f.anchor) {
                const sway = d.sway * (f.kind === 'golden' ? 2.2 : 1);
                f.x = f.anchor.x + Math.sin(st.time * 1.7 + f.ph) * sway * 18;
                f.y = f.anchor.y + f.anchor.len + Math.cos(st.time * 1.3 + f.ph) * sway * 6;
            }
            if (f.state === 'grow') {
                f.scale = Math.min(1, f.t / 0.35);
                if (f.t >= 0.35) { f.t = 0; f.state = f.kind === 'ripe' ? 'unripe' : f.kind === 'rotten' ? 'rot' : 'ripe'; }
            } else if (f.state === 'unripe' && f.t >= d.unripeTime) {
                f.state = 'ripe'; f.t = 0;
            } else if (f.state === 'ripe' && f.t >= (f.kind === 'golden' ? 2.4 : d.ripeWindow)) {
                drop(f);
            } else if (f.state === 'rot' && f.t >= 3.2) {
                drop(f);
            } else if (f.state === 'fall') {
                f.vy += 1400 * dt; f.y += f.vy * dt; f.rot += dt * 4;
                if (f.y > H + 60) f.state = 'done';
            } else if (f.state === 'fly') {
                const k = Math.min(1, f.t / 0.45);
                f.x = lerp(f.fx, W - 90, k * k); f.y = lerp(f.fy, H - 70, k) - Math.sin(k * Math.PI) * 120;
                f.scale = 1 - k * 0.6;
                if (k >= 1) f.state = 'done';
            }
        }
        for (const p of st.parts) { p.x += p.vx * dt; p.y += p.vy * dt; p.vy += 500 * dt; p.life -= dt * 1.6; }
        st.parts = st.parts.filter((p) => p.life > 0);
        for (const t of st.texts) t.t += dt;
        st.texts = st.texts.filter((t) => t.t < 1.1);

        const pending = st.fruits.some((f) => f.kind !== 'rotten' && ['hidden', 'grow', 'unripe', 'ripe'].includes(f.state));
        if (st.time >= st.T || !pending) finish();
    }

    function drop(f) { f.state = 'fall'; f.t = 0; f.vy = -60; release(f); }

    /* ── Drawing ──────────────────────────────────────────────────────── */
    function drawScene(t) {
        const sky = ctx.createLinearGradient(0, 0, 0, H);
        sky.addColorStop(0, '#1a0a1e'); sky.addColorStop(0.55, '#4a1a3a'); sky.addColorStop(1, '#c2577a');
        ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H);
        const sun = ctx.createRadialGradient(780, 470, 10, 780, 470, 320);
        sun.addColorStop(0, 'rgba(255,200,150,.55)'); sun.addColorStop(1, 'rgba(255,200,150,0)');
        ctx.fillStyle = sun; ctx.fillRect(0, 0, W, H);
        ctx.fillStyle = '#2a0f22';
        ctx.beginPath(); ctx.moveTo(0, H);
        for (let x = 0; x <= W; x += 40) ctx.lineTo(x, 470 + Math.sin(x * 0.008) * 26 + Math.sin(x * 0.021) * 10);
        ctx.lineTo(W, H); ctx.fill();
        ctx.fillStyle = '#170812';
        ctx.beginPath(); ctx.moveTo(0, H);
        for (let x = 0; x <= W; x += 40) ctx.lineTo(x, 515 + Math.sin(x * 0.012 + 2) * 18);
        ctx.lineTo(W, H); ctx.fill();
        for (const m of scene.motes) {
            m.y -= m.v * 0.016; if (m.y < -5) m.y = H + 5;
            ctx.fillStyle = `rgba(255,220,240,${0.25 + Math.sin(t * 2 + m.x) * 0.15})`;
            ctx.beginPath(); ctx.arc(m.x, m.y, m.s, 0, 7); ctx.fill();
        }
        for (const b of scene.branches) {
            const g = ctx.createLinearGradient(0, b.y0 - 20, 0, b.y0 + 30);
            g.addColorStop(0, '#5a3a26'); g.addColorStop(1, '#2a160c');
            ctx.strokeStyle = g; ctx.lineCap = 'round'; ctx.lineWidth = b.w;
            ctx.beginPath(); ctx.moveTo(b.x0, b.y0); ctx.quadraticCurveTo(b.cx, b.cy, b.x1, b.y1); ctx.stroke();
            ctx.strokeStyle = 'rgba(255,220,180,.12)'; ctx.lineWidth = b.w * 0.25;
            ctx.beginPath(); ctx.moveTo(b.x0, b.y0 - b.w * 0.25); ctx.quadraticCurveTo(b.cx, b.cy - b.w * 0.25, b.x1, b.y1 - b.w * 0.25); ctx.stroke();
        }
        for (const l of scene.leaves) {
            ctx.save();
            ctx.translate(l.x, l.y); ctx.rotate(l.a + Math.sin(t * 1.2 + l.ph) * 0.08);
            const lg = ctx.createLinearGradient(-l.s, 0, l.s, 0);
            lg.addColorStop(0, `hsl(${100 + l.c * 30},45%,${18 + l.c * 10}%)`); lg.addColorStop(1, `hsl(${95 + l.c * 30},50%,${30 + l.c * 12}%)`);
            ctx.fillStyle = lg;
            ctx.beginPath(); ctx.ellipse(0, 0, l.s, l.s * 0.42, 0, 0, 7); ctx.fill();
            ctx.strokeStyle = 'rgba(200,240,160,.25)'; ctx.lineWidth = 1;
            ctx.beginPath(); ctx.moveTo(-l.s * 0.9, 0); ctx.lineTo(l.s * 0.9, 0); ctx.stroke();
            ctx.restore();
        }
    }

    function drawFruit(f, t) {
        if (f.state === 'hidden' || f.state === 'done') return;
        const size = 62 * (f.kind === 'golden' ? 1.05 : 1) * (f.state === 'grow' ? f.scale : f.state === 'fly' ? f.scale : 1);
        const d = spec.difficulty;
        if (f.anchor && f.state !== 'fly') {
            ctx.strokeStyle = '#3d5a22'; ctx.lineWidth = 2.5;
            ctx.beginPath(); ctx.moveTo(f.anchor.x, f.anchor.y); ctx.lineTo(f.x, f.y - size * 0.35); ctx.stroke();
        }
        if (f.state === 'ripe') {
            const life = 1 - f.t / (f.kind === 'golden' ? 2.4 : d.ripeWindow);
            const pulse = 0.6 + Math.sin(t * 8) * 0.25;
            const col = f.kind === 'golden' ? '255,211,107' : '240,106,166';
            const g = ctx.createRadialGradient(f.x, f.y, size * 0.2, f.x, f.y, size * 0.95);
            g.addColorStop(0, `rgba(${col},${0.45 * pulse})`); g.addColorStop(1, `rgba(${col},0)`);
            ctx.fillStyle = g; ctx.beginPath(); ctx.arc(f.x, f.y, size * 0.95, 0, 7); ctx.fill();
            ctx.strokeStyle = `rgba(${col},.95)`; ctx.lineWidth = 3.5;
            ctx.beginPath(); ctx.arc(f.x, f.y, size * 0.66, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * life); ctx.stroke();
        }
        ctx.save();
        ctx.translate(f.x, f.y); ctx.rotate(f.rot);
        const img = f.kind === 'golden' ? sprites.golden : f.kind === 'rotten' ? sprites.rotten : (f.state === 'unripe' || f.state === 'grow') ? sprites.unripe : sprites.ripe;
        ctx.drawImage(img, -size / 2, -size / 2, size, size);
        ctx.restore();
        if (f.kind === 'rotten' && f.state === 'rot') {
            ctx.fillStyle = '#111';
            for (let i = 0; i < 3; i++) {
                const a = t * (3 + i) + i * 2;
                ctx.beginPath(); ctx.arc(f.x + Math.cos(a) * 34, f.y - 10 + Math.sin(a * 1.3) * 22, 2.4, 0, 7); ctx.fill();
            }
        }
    }

    function draw(now) {
        const t = now / 1000;
        fit.apply(ctx);
        ctx.clearRect(-2000, -2000, 6000, 6000);
        drawScene(t);
        for (const f of st.fruits) drawFruit(f, t);
        // basket
        ctx.drawImage(sprites.basket, W - 170, H - 150, 150, 150);
        ctx.font = '700 26px Cinzel'; ctx.textAlign = 'center';
        ctx.fillStyle = '#ffe3f0'; ctx.strokeStyle = 'rgba(0,0,0,.7)'; ctx.lineWidth = 5;
        const label = `${st.picked}/${spec.ripe}`;
        ctx.strokeText(label, W - 95, H - 14); ctx.fillText(label, W - 95, H - 14);
        for (const p of st.parts) {
            ctx.globalAlpha = Math.max(0, p.life); ctx.fillStyle = p.color;
            ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, 7); ctx.fill();
        }
        ctx.globalAlpha = 1;
        for (const tx of st.texts) {
            ctx.globalAlpha = 1 - tx.t / 1.1;
            ctx.font = '700 24px Cinzel'; ctx.fillStyle = tx.color;
            ctx.strokeStyle = 'rgba(0,0,0,.6)'; ctx.lineWidth = 4;
            ctx.strokeText(tx.text, tx.x, tx.y - tx.t * 50); ctx.fillText(tx.text, tx.x, tx.y - tx.t * 50);
        }
        ctx.globalAlpha = 1;
        const v = ctx.createRadialGradient(W / 2, H / 2, H * 0.4, W / 2, H / 2, W * 0.7);
        v.addColorStop(0, 'rgba(0,0,0,0)'); v.addColorStop(1, 'rgba(0,0,0,.55)');
        ctx.fillStyle = v; ctx.fillRect(0, 0, W, H);
    }

    function hud() {
        const left = Math.max(0, st.T - st.time);
        const bar = $('#hTimer i', root);
        if (bar) bar.style.width = `${(left / st.T) * 100}%`;
        const c = $('#hCount', root);
        if (c) c.textContent = `${st.picked} picked · ${st.rotten} rotten`;
    }

    function loop(now) {
        if (!st) return;
        const dt = Math.min(0.05, (now - st.last) / 1000);
        st.last = now;
        if (started && !ended) update(dt);
        draw(now);
        hud();
        raf = requestAnimationFrame(loop);
    }

    /* ── Input ────────────────────────────────────────────────────────── */
    function onClick(e) {
        if (!started || ended) return;
        const p = fit.toLogical(e.clientX, e.clientY);
        for (let i = st.fruits.length - 1; i >= 0; i--) {
            const f = st.fruits[i];
            if (!['grow', 'unripe', 'ripe', 'rot'].includes(f.state)) continue;
            if (Math.hypot(p.x - f.x, p.y - f.y) > 38) continue;
            if (f.kind === 'rotten') {
                st.rotten++;
                SFX.squish();
                burst(f.x, f.y, '#5a3a14', 18);
                float('Rotten!', f.x, f.y - 30, '#ff8a7a');
                drop(f);
            } else if (f.state === 'ripe') {
                if (f.kind === 'golden') { st.golden = true; SFX.perfect(); float('Golden!', f.x, f.y - 30, '#ffd36b'); burst(f.x, f.y, '#ffd36b', 30); }
                else { st.picked++; SFX.pick(); float('+1', f.x, f.y - 30, '#ffb3d6'); burst(f.x, f.y, '#f06aa6'); }
                f.state = 'fly'; f.t = 0; f.fx = f.x; f.fy = f.y; release(f);
            } else {
                SFX.bad();
                float('Not ripe yet!', f.x, f.y - 30, '#b7e08a');
                drop(f);
            }
            return;
        }
    }

    async function finish() {
        if (ended) return;
        ended = true;
        const overlay = el(`<div class="harvest-summary"><div class="card gold-edge"><div class="spinner"></div><div class="muted">Filling your basket...</div></div></div>`);
        $('.harvest-wrap', root).appendChild(overlay);
        const res = await post('harvest:finish', { picked: st.picked, rotten: st.rotten, golden: st.golden });
        if (!VJ.app || VJ.app !== 'harvest') return;
        const card = $('.card', overlay);
        if (!res || !res.ok) {
            card.innerHTML = `<div class="h2">Harvest lost</div><p class="muted" style="margin:10px 0 18px">${esc(res && res.msg || 'Something went wrong.')}</p><button class="btn" data-close>Close</button>`;
            return;
        }
        SFX.chime();
        card.innerHTML = `<img src="${itemImg(spec.fruit.item)}" alt="">
            <div class="gain">+${res.amount}</div><div class="h3">${esc(res.label)}</div>
            <div>${res.perfect ? `<span class="badge">Perfect harvest +${res.bonus}</span>` : ''}${res.golden ? '<span class="badge">Golden fruit found!</span>' : ''}${res.rotten ? `<span class="badge" style="color:#ff8a7a;border-color:#ff8a7a55">${res.rotten} rotten · -${res.rotten}</span>` : ''}</div>
            ${res.golden ? `<img src="${itemImg('golden_fruit')}" style="width:70px;height:70px" alt="">` : ''}
            ${res.overflow ? '<p class="small bad">Your pockets were full — the rest is waiting on the kitchen cooling rack.</p>' : ''}
            <div style="margin-top:16px"><button class="btn big" data-close>Collect</button></div>`;
    }

    function start() {
        if (started) return;
        started = true;
        const tut = $('.tutorial', root);
        if (tut) tut.remove();
        st.last = performance.now();
        SFX.pop();
    }

    function onResize() { if (cv) fit = fitCanvas(cv, W, H); }

    return {
        open(section, d) {
            root = section; spec = d; ended = false; started = false;
            const diff = d.difficulty;
            root.innerHTML = `
                <div class="harvest-top">
                    <div><h1>FRUIT ORCHARD</h1><div class="muted small">Pick fresh ${esc(d.fruit.plural.toLowerCase())} for your jams</div></div>
                    <span class="chip">${esc(diff.label)}</span>
                    ${d.basket ? '<span class="chip">Basket +bonus</span>' : ''}
                    <div class="timer"><div class="bar" id="hTimer"><i style="width:100%"></i></div><div class="small muted" id="hCount" style="margin-top:4px">0 picked</div></div>
                    <button class="close-btn" data-close title="Stop harvesting (Esc)">✕</button>
                </div>
                <div class="harvest-wrap"><canvas></canvas>
                    <div class="tutorial"><div class="card gold-edge">
                        <div class="h2">Harvesting ${esc(d.fruit.plural)}</div>
                        <ul>
                            <li>Fruit grows <b style="color:#b7e08a">green</b> first — picking it early ruins it.</li>
                            <li>Click fruit when it <b class="pink">glows</b>. The ring shows how long before it drops.</li>
                            <li>Avoid <b style="color:#c08a5a">rotten fruit</b> buzzing with flies — each one costs you a piece.</li>
                            <li>Collect every ripe fruit without a mistake for a <b class="gold">perfect bonus</b>.${d.golden ? ' Something <b class="gold">golden</b> glimmers in the branches today...' : ''}</li>
                        </ul>
                        <button class="btn big" data-start>Start Picking</button><div class="muted small" style="margin-top:8px">or press <span class="kbd">Space</span></div>
                    </div></div>
                </div>`;
            cv = $('canvas', root);
            ctx = cv.getContext('2d');
            scene = buildScene();
            st = newGame();
            fit = fitCanvas(cv, W, H);
            if (window.__VJ_TEST) window.__vjh = () => ({ st, fit, rect: cv.getBoundingClientRect() });
            prepareSprites(() => { if (VJ.app === 'harvest') raf = requestAnimationFrame(loop); });
            cv.addEventListener('mousedown', onClick);
            root.addEventListener('click', (e) => { if (e.target.closest('[data-start]')) start(); });
            window.addEventListener('resize', onResize);
        },
        key(e, down) {
            if (down && (e.code === 'Space' || e.code === 'Enter') && !started) { e.preventDefault(); start(); }
        },
        close() {
            cancelAnimationFrame(raf);
            window.removeEventListener('resize', onResize);
            st = null; scene = null; sprites = null; cv = null;
        },
    };
})();
