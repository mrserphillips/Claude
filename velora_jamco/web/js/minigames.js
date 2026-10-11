/* Velora Jam Co. — crafting minigames
   Each minigame: Minigames[stage](host, params, info, done) -> { key(e, down), destroy() }
   `done(data)` sends RAW telemetry; the server turns it into a score. */
'use strict';

const MW = 1000, MH = 520;

function hexToRgb(h) { const n = parseInt(h.replace('#', ''), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; }
function jamColour(fruits, dark = 0) {
    const cols = fruits.map((f) => hexToRgb(f.color || '#c8102e'));
    const avg = [0, 1, 2].map((i) => cols.reduce((s, c) => s + c[i], 0) / cols.length);
    return avg.map((v) => Math.round(v * (1 - dark)));
}
const rgb = (c, a = 1) => `rgba(${c[0]},${c[1]},${c[2]},${a})`;

function makeCanvas(host) {
    const cv = document.createElement('canvas');
    host.appendChild(cv);
    const ctx = cv.getContext('2d');
    let fit = fitCanvas(cv, MW, MH);
    const onResize = () => { fit = fitCanvas(cv, MW, MH); };
    window.addEventListener('resize', onResize);
    return {
        cv, ctx,
        get fit() { return fit; },
        clear() { fit.apply(ctx); ctx.clearRect(-2000, -2000, 6000, 6000); },
        dispose() { window.removeEventListener('resize', onResize); cv.remove(); },
    };
}

function hud(host, html) {
    const h = el(`<div class="stage-hud">${html}</div>`);
    host.appendChild(h);
    return h;
}

function roundRect(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
}

function kitchenBackdrop(ctx) {
    const g = ctx.createLinearGradient(0, 0, 0, MH);
    g.addColorStop(0, '#1d0d18'); g.addColorStop(1, '#0a0508');
    ctx.fillStyle = g; ctx.fillRect(0, 0, MW, MH);
    ctx.fillStyle = 'rgba(255,255,255,.025)';
    for (let x = 0; x < MW; x += 50) for (let y = 0; y < 300; y += 50) { roundRect(ctx, x + 3, y + 3, 44, 44, 4); ctx.fill(); }
    const lamp = ctx.createRadialGradient(MW / 2, 80, 20, MW / 2, 160, 520);
    lamp.addColorStop(0, 'rgba(255,190,140,.16)'); lamp.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = lamp; ctx.fillRect(0, 0, MW, MH);
}

const Minigames = {};

/* ═══════════════ A: PREPARE — slice targets in sequence ═══════════════ */
Minigames.prepare = (host, p, info, done) => {
    const c = makeCanvas(host);
    const { ctx } = c;
    const imgs = info.fruits.map((f) => loadImage(itemImg(f.item)));
    const N = p.targets;
    const IDEAL = 34, START = 112, END = 8;
    const targets = [];
    const cols = Math.ceil(N / 2);
    for (let i = 0; i < N; i++) {
        const row = i < cols ? 0 : 1;
        const col = row === 0 ? i : i - cols;
        const x = 200 + (col + 0.5) * (600 / cols) + (row ? 30 : -30);
        const y = row === 0 ? 205 : 345;
        targets.push({ x, y, img: imgs[i % imgs.length], state: 'wait', t: 0, cut: 0, angle: (Math.random() - .5) * 1.2 });
    }
    let idx = 0, hits = 0, perfects = 0, misses = 0, raf = 0, last = performance.now(), gap = 0.5, finished = false;
    const parts = [], texts = [];
    const juice = rgb(jamColour(info.fruits));
    const h = hud(host, `<span class="hint">Click the glowing target when the ring meets the circle — or press <span class="kbd">Space</span></span><b id="pScore" style="font-family:Cinzel">0 / ${N}</b>`);

    function resolve(kind, x, y) {
        const t = targets[idx];
        if (kind === 'perfect') { perfects++; hits++; SFX.perfect(); texts.push({ s: 'Perfect!', x, y, c: '#ffd36b', t: 0 }); }
        else if (kind === 'good') { hits++; SFX.chop(); texts.push({ s: 'Good', x, y, c: '#ffb3d6', t: 0 }); }
        else { misses++; SFX.bad(); texts.push({ s: kind === 'off' ? 'Off target' : 'Miss', x, y, c: '#ff8a7a', t: 0 }); }
        t.state = kind === 'miss' || kind === 'off' ? 'missed' : 'cut';
        t.t = 0;
        if (t.state === 'cut') for (let i = 0; i < 16; i++) {
            const a = Math.random() * Math.PI * 2, s = 60 + Math.random() * 160;
            parts.push({ x: t.x, y: t.y, vx: Math.cos(a) * s, vy: Math.sin(a) * s - 80, life: 1 });
        }
        idx++; gap = 0.28;
        $('#pScore', h).textContent = `${hits} / ${N}`;
        if (idx >= N && !finished) { finished = true; setTimeout(() => done({ hits, perfects, misses }), 700); }
    }

    function attempt(px, py, keyboard) {
        if (idx >= N) return;
        const t = targets[idx];
        if (t.state !== 'active') return;
        const ring = START - (START - END) * (t.t / p.window);
        const err = Math.abs(ring - IDEAL);
        if (!keyboard && Math.hypot(px - t.x, py - t.y) > 52) return resolve('off', t.x, t.y - 60);
        if (err <= 7) resolve('perfect', t.x, t.y - 60);
        else if (err <= 20) resolve('good', t.x, t.y - 60);
        else resolve('miss', t.x, t.y - 60);
    }

    function frame(now) {
        const dt = Math.min(0.05, (now - last) / 1000); last = now;
        if (idx < N) {
            const t = targets[idx];
            if (t.state === 'wait') { gap -= dt; if (gap <= 0) { t.state = 'active'; t.t = 0; } }
            else if (t.state === 'active') { t.t += dt; if (t.t >= p.window) resolve('miss', t.x, t.y - 60); }
        }
        targets.forEach((t) => { if (t.state === 'cut' || t.state === 'missed') t.t += dt; });
        c.clear();
        kitchenBackdrop(ctx);
        // board
        ctx.save();
        ctx.shadowColor = 'rgba(0,0,0,.6)'; ctx.shadowBlur = 30; ctx.shadowOffsetY = 14;
        const wood = ctx.createLinearGradient(0, 120, 0, 440);
        wood.addColorStop(0, '#9a6638'); wood.addColorStop(1, '#5d3a1d');
        ctx.fillStyle = wood; roundRect(ctx, 150, 120, 700, 320, 36); ctx.fill();
        ctx.restore();
        ctx.strokeStyle = 'rgba(40,20,8,.35)'; ctx.lineWidth = 2;
        for (let i = 0; i < 14; i++) { ctx.beginPath(); ctx.moveTo(170, 140 + i * 22); ctx.bezierCurveTo(400, 130 + i * 22 + Math.sin(i) * 8, 600, 150 + i * 22, 830, 140 + i * 22); ctx.stroke(); }
        ctx.fillStyle = '#2a160a'; ctx.beginPath(); ctx.arc(805, 160, 12, 0, 7); ctx.fill();
        // fruit
        targets.forEach((t, i) => {
            const s = 92;
            if (t.state === 'cut') {
                const o = Math.min(26, t.t * 120);
                ctx.save(); ctx.translate(t.x, t.y); ctx.rotate(t.angle);
                ctx.save(); ctx.beginPath(); ctx.rect(-s, -s, s, s * 2); ctx.clip(); ctx.drawImage(t.img, -s / 2 - o, -s / 2, s, s); ctx.restore();
                ctx.save(); ctx.beginPath(); ctx.rect(0, -s, s, s * 2); ctx.clip(); ctx.drawImage(t.img, -s / 2 + o, -s / 2, s, s); ctx.restore();
                if (t.t < 0.3) { ctx.strokeStyle = `rgba(255,255,255,${1 - t.t / 0.3})`; ctx.lineWidth = 4; ctx.beginPath(); ctx.moveTo(0, -70); ctx.lineTo(0, 70); ctx.stroke(); }
                ctx.restore();
            } else {
                ctx.globalAlpha = t.state === 'missed' ? 0.45 : 1;
                ctx.drawImage(t.img, t.x - s / 2, t.y - s / 2, s, s);
                ctx.globalAlpha = 1;
            }
            if (i >= idx && i < idx + 3 && t.state !== 'cut') {
                ctx.font = '700 18px Cinzel'; ctx.textAlign = 'center';
                ctx.fillStyle = i === idx ? '#ffe3f0' : 'rgba(255,227,240,.45)';
                ctx.fillText(String(i + 1), t.x + 40, t.y - 40);
            }
        });
        // active target
        if (idx < N && targets[idx].state === 'active') {
            const t = targets[idx];
            const ring = START - (START - END) * (t.t / p.window);
            const near = Math.abs(ring - IDEAL) <= 20;
            ctx.strokeStyle = 'rgba(255,255,255,.85)'; ctx.setLineDash([6, 6]); ctx.lineWidth = 3;
            ctx.beginPath(); ctx.arc(t.x, t.y, IDEAL, 0, 7); ctx.stroke(); ctx.setLineDash([]);
            ctx.strokeStyle = near ? '#ffd36b' : '#f06aa6'; ctx.lineWidth = near ? 6 : 4;
            ctx.shadowColor = ctx.strokeStyle; ctx.shadowBlur = 16;
            ctx.beginPath(); ctx.arc(t.x, t.y, Math.max(2, ring), 0, 7); ctx.stroke();
            ctx.shadowBlur = 0;
            ctx.strokeStyle = 'rgba(255,255,255,.5)'; ctx.lineWidth = 2;
            ctx.beginPath(); ctx.moveTo(t.x - 50, t.y + 50); ctx.lineTo(t.x + 50, t.y - 50); ctx.stroke();
        }
        parts.forEach((q) => { q.x += q.vx * dt; q.y += q.vy * dt; q.vy += 600 * dt; q.life -= dt * 1.5; ctx.globalAlpha = Math.max(0, q.life); ctx.fillStyle = juice; ctx.beginPath(); ctx.arc(q.x, q.y, 3.5, 0, 7); ctx.fill(); });
        ctx.globalAlpha = 1;
        texts.forEach((x) => { x.t += dt; ctx.globalAlpha = Math.max(0, 1 - x.t); ctx.font = '700 26px Cinzel'; ctx.textAlign = 'center'; ctx.fillStyle = x.c; ctx.fillText(x.s, x.x, x.y - x.t * 40); });
        ctx.globalAlpha = 1;
        raf = requestAnimationFrame(frame);
    }
    raf = requestAnimationFrame(frame);
    const onDown = (e) => { const q = c.fit.toLogical(e.clientX, e.clientY); attempt(q.x, q.y, false); };
    c.cv.addEventListener('mousedown', onDown);
    return {
        key(e, down) { if (down && (e.code === 'Space' || e.code === 'Enter') && !e.repeat) { e.preventDefault(); attempt(0, 0, true); } },
        destroy() { cancelAnimationFrame(raf); c.cv.removeEventListener('mousedown', onDown); c.dispose(); h.remove(); },
    };
};

/* ═══════════════ B: HEAT — keep the temperature in the band ═══════════════ */
Minigames.heat = (host, p, info, done) => {
    const c = makeCanvas(host);
    const { ctx } = c;
    const jam = jamColour(info.fruits);
    const LO = 40, HI = 140;
    let temp = p.startTemp, burner = 0, holding = false, progress = 0, reached = false, raf = 0, last = performance.now(), finished = false;
    const ms = { inBand: 0, hot: 0, cold: 0, warm: 0 };
    const bubbles = [], steam = [];
    const h = hud(host, `<span class="hint" id="hHint">Hold to heat, release to cool. Keep it in the <b class="pink">pink band</b>.</span>
        <button class="btn hold-btn" id="hold">🔥 Hold to Heat</button>`);
    const btn = $('#hold', h);

    function frame(now) {
        const dt = Math.min(0.05, (now - last) / 1000); last = now;
        if (!finished) {
            burner += ((holding ? 1 : 0) - burner) * Math.min(1, dt * 1.4);
            temp += (burner * 10 - (temp - 20) * 0.05) * dt;
            const inBand = temp >= p.bandMin && temp <= p.bandMax;
            if (inBand) reached = true;
            const step = dt * 1000;
            if (inBand) { ms.inBand += step; progress += dt / p.cookSeconds; }
            else if (temp > p.bandMax) { ms.hot += step; progress += dt / p.cookSeconds; }
            else if (reached) { ms.cold += step; progress += dt * 0.3 / p.cookSeconds; }
            else ms.warm += step;
            if (progress >= 1) {
                finished = true; holding = false;
                setTimeout(() => done({ inBand: Math.round(ms.inBand), hot: Math.round(ms.hot), cold: Math.round(ms.cold), warm: Math.round(ms.warm) }), 500);
            }
            const hint = $('#hHint', h);
            if (hint) hint.innerHTML = !reached ? 'Bring the pot up to temperature...' : inBand ? '<b class="good">Perfect — hold it there!</b>' : temp > p.bandMax ? '<b class="bad">Too hot! Ease off the heat.</b>' : '<b class="gold">Too cold — add some heat.</b>';
        }
        c.clear();
        kitchenBackdrop(ctx);
        const cx = 500, cy = 250;
        // stove top
        ctx.fillStyle = '#1b1b1f'; roundRect(ctx, 300, 300, 400, 40, 10); ctx.fill();
        // flames
        const fl = burner;
        for (let i = 0; i < 16; i++) {
            const a = i / 16 * Math.PI * 2;
            const x = cx + Math.cos(a) * 110, y = 318 + Math.sin(a) * 10;
            const hgt = (10 + fl * 46) * (0.8 + Math.random() * 0.4);
            const g = ctx.createLinearGradient(x, y, x, y - hgt);
            g.addColorStop(0, 'rgba(80,140,255,.9)'); g.addColorStop(0.4, `rgba(255,${120 + fl * 60},40,.85)`); g.addColorStop(1, 'rgba(255,200,80,0)');
            ctx.fillStyle = g; ctx.beginPath(); ctx.ellipse(x, y - hgt / 2, 8, hgt / 2, 0, 0, 7); ctx.fill();
        }
        // pot body (copper)
        const body = ctx.createLinearGradient(330, 0, 670, 0);
        body.addColorStop(0, '#5a2a12'); body.addColorStop(0.25, '#d47a3c'); body.addColorStop(0.45, '#f5b07a'); body.addColorStop(0.7, '#a14a1e'); body.addColorStop(1, '#4a200c');
        ctx.fillStyle = body;
        ctx.beginPath(); ctx.moveTo(340, 150); ctx.lineTo(660, 150); ctx.quadraticCurveTo(662, 300, 610, 312); ctx.lineTo(390, 312); ctx.quadraticCurveTo(338, 300, 340, 150); ctx.fill();
        ctx.fillStyle = '#3a1608'; ctx.fillRect(300, 180, 44, 14); ctx.fillRect(656, 180, 44, 14);
        // rim + jam surface
        ctx.fillStyle = '#e09a62'; ctx.beginPath(); ctx.ellipse(cx, 150, 162, 34, 0, 0, 7); ctx.fill();
        const burnt = Math.min(1, ms.hot / (p.burnSeconds * 1000));
        const surf = [0, 1, 2].map((i) => jam[i] * (1 - burnt * 0.6));
        ctx.fillStyle = rgb(surf); ctx.beginPath(); ctx.ellipse(cx, 154, 148, 27, 0, 0, 7); ctx.fill();
        // bubbles & steam scale with temperature
        const heat = clamp((temp - 60) / 60, 0, 1.4);
        if (Math.random() < heat * 0.6) { bubbles.push({ x: cx + (Math.random() - .5) * 250, y: 154 + (Math.random() - .5) * 36, r: 0, max: 4 + Math.random() * 9 }); if (Math.random() < 0.3) SFX.bubble(); }
        if (Math.random() < heat * 0.35) steam.push({ x: cx + (Math.random() - .5) * 220, y: 140, r: 14 + Math.random() * 16, life: 1, vx: (Math.random() - .5) * 18 });
        for (let i = bubbles.length - 1; i >= 0; i--) {
            const b = bubbles[i]; b.r += dt * 18;
            ctx.strokeStyle = rgb(surf.map((v) => Math.min(255, v + 70)), 0.8); ctx.lineWidth = 1.5;
            ctx.beginPath(); ctx.ellipse(b.x, b.y, b.r, b.r * 0.45, 0, 0, 7); ctx.stroke();
            if (b.r >= b.max) bubbles.splice(i, 1);
        }
        for (let i = steam.length - 1; i >= 0; i--) {
            const s = steam[i]; s.y -= dt * 60; s.x += s.vx * dt; s.r += dt * 16; s.life -= dt * 0.5;
            const col = burnt > 0.5 ? '60,55,55' : '255,255,255';
            const g = ctx.createRadialGradient(s.x, s.y, 0, s.x, s.y, s.r);
            g.addColorStop(0, `rgba(${col},${0.22 * s.life})`); g.addColorStop(1, `rgba(${col},0)`);
            ctx.fillStyle = g; ctx.beginPath(); ctx.arc(s.x, s.y, s.r, 0, 7); ctx.fill();
            if (s.life <= 0) steam.splice(i, 1);
        }
        // gauge
        const gx = 200, gw = 600, gy = 400, gh = 26;
        const tx = (v) => gx + (clamp(v, LO, HI) - LO) / (HI - LO) * gw;
        ctx.fillStyle = 'rgba(0,0,0,.6)'; roundRect(ctx, gx - 6, gy - 6, gw + 12, gh + 12, 18); ctx.fill();
        const gg = ctx.createLinearGradient(gx, 0, gx + gw, 0);
        gg.addColorStop(0, '#3a5bd9'); gg.addColorStop(0.45, '#f5b942'); gg.addColorStop(1, '#e8321e');
        ctx.fillStyle = gg; roundRect(ctx, gx, gy, gw, gh, 13); ctx.fill();
        ctx.fillStyle = 'rgba(240,106,166,.85)'; ctx.fillRect(tx(p.bandMin), gy - 4, tx(p.bandMax) - tx(p.bandMin), gh + 8);
        ctx.strokeStyle = '#fff'; ctx.lineWidth = 2; ctx.strokeRect(tx(p.bandMin), gy - 4, tx(p.bandMax) - tx(p.bandMin), gh + 8);
        const nx = tx(temp);
        ctx.fillStyle = '#fff'; ctx.shadowColor = '#fff'; ctx.shadowBlur = 10;
        roundRect(ctx, nx - 5, gy - 14, 10, gh + 28, 4); ctx.fill(); ctx.shadowBlur = 0;
        ctx.font = '700 30px Cinzel'; ctx.textAlign = 'center'; ctx.fillStyle = '#ffe3f0';
        ctx.fillText(`${Math.round(temp)}°C`, cx, gy + 66);
        // progress ring
        ctx.lineWidth = 10; ctx.strokeStyle = 'rgba(255,255,255,.1)';
        ctx.beginPath(); ctx.arc(880, 110, 56, 0, 7); ctx.stroke();
        ctx.strokeStyle = '#f06aa6'; ctx.beginPath(); ctx.arc(880, 110, 56, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, progress)); ctx.stroke();
        ctx.font = '700 22px Cinzel'; ctx.fillStyle = '#fff'; ctx.fillText(`${Math.floor(Math.min(1, progress) * 100)}%`, 880, 118);
        ctx.font = '14px Cinzel'; ctx.fillStyle = '#b9a2ad'; ctx.fillText('COOKED', 880, 190);
        // scorch meter
        ctx.fillStyle = 'rgba(255,255,255,.08)'; roundRect(ctx, 60, 80, 22, 160, 11); ctx.fill();
        ctx.fillStyle = burnt >= 1 ? '#ff4d4d' : '#ff8a5a'; roundRect(ctx, 60, 80 + 160 * (1 - burnt), 22, 160 * burnt, 11); ctx.fill();
        ctx.font = '13px Cinzel'; ctx.fillStyle = '#b9a2ad'; ctx.fillText('SCORCH', 71, 262);
        raf = requestAnimationFrame(frame);
    }
    raf = requestAnimationFrame(frame);
    const press = (v) => { if (finished) v = false; holding = v; btn.classList.toggle('holding', v); };
    const down = () => press(true), up = () => press(false);
    btn.addEventListener('mousedown', down); c.cv.addEventListener('mousedown', down);
    window.addEventListener('mouseup', up);
    return {
        key(e, isDown) {
            if (['Space', 'KeyW', 'ArrowUp'].includes(e.code)) { e.preventDefault(); press(isDown); }
        },
        destroy() { cancelAnimationFrame(raf); window.removeEventListener('mouseup', up); c.dispose(); h.remove(); },
    };
};

/* ═══════════════ C: STIR — real circular mouse motion ═══════════════ */
Minigames.stir = (host, p, info, done) => {
    const c = makeCanvas(host);
    const { ctx } = c;
    const jam = jamColour(info.fruits);
    const cx = 500, cy = 260, R = 205;
    let accum = 0, lastA = null, speed = 0, burn = 0, maxBurn = 0, burnInt = 0, goodT = 0, totalT = 0, raf = 0, last = performance.now(), finished = false;
    let mouse = null, moved = 0, keyStep = -1;
    const splash = [];
    const KEYS = ['ArrowUp', 'ArrowRight', 'ArrowDown', 'ArrowLeft'];
    const h = hud(host, `<span class="hint">Move your mouse in <b class="pink">smooth circles</b> inside the pot, or tap <span class="kbd">↑</span><span class="kbd">→</span><span class="kbd">↓</span><span class="kbd">←</span> in rotation.</span><b id="sRev" style="font-family:Cinzel">0 / ${p.revolutions}</b>`);

    // raw motion is queued and applied in the frame loop, capped at 3 revolutions per second
    let pendingMouse = 0, pendingKeys = 0;
    function applyMotion(dt) {
        const cap = 3.0 * Math.PI * 2 * dt;
        const m = clamp(pendingMouse, -cap, cap);
        pendingMouse = 0;
        const keyCap = Math.min(cap - Math.abs(m), 1.3 * Math.PI * 2 * dt);
        const k = clamp(pendingKeys, -keyCap, keyCap);
        pendingKeys -= k;
        accum += m + k;
        moved += Math.abs(m + k);
    }

    function onMove(e) {
        const q = c.fit.toLogical(e.clientX, e.clientY);
        mouse = q;
        const r = Math.hypot(q.x - cx, q.y - cy);
        if (r < 40 || r > R + 10) { lastA = null; return; }
        const a = Math.atan2(q.y - cy, q.x - cx);
        if (lastA !== null) {
            let da = a - lastA;
            while (da > Math.PI) da -= Math.PI * 2;
            while (da < -Math.PI) da += Math.PI * 2;
            if (Math.abs(da) < 1.4) pendingMouse += da;
        }
        lastA = a;
    }

    function frame(now) {
        const dt = Math.min(0.05, (now - last) / 1000); last = now;
        if (!finished) applyMotion(dt);
        const progress = Math.min(1, Math.abs(accum) / (Math.PI * 2) / p.revolutions);
        if (!finished) {
            const inst = moved / (Math.PI * 2) / Math.max(dt, 0.001);
            moved = 0;
            speed = lerp(speed, inst, 0.12);
            const maxSpeed = 2.2 * (1 - 0.4 * progress);
            const ideal = speed >= 0.45 && speed <= maxSpeed;
            totalT += dt;
            if (ideal) goodT += dt;
            if (speed > maxSpeed && Math.random() < 0.5) splash.push({ x: cx + (Math.random() - .5) * 300, y: cy + (Math.random() - .5) * 300, vx: (Math.random() - .5) * 200, vy: -100 - Math.random() * 160, life: 1 });
            burn = clamp(burn + p.burnRate * dt * (speed < 0.3 ? 1.6 : ideal ? -2.2 : -0.6), 0, 1);
            maxBurn = Math.max(maxBurn, burn);
            burnInt += burn * dt;
            $('#sRev', h).textContent = `${Math.floor(Math.abs(accum) / (Math.PI * 2))} / ${p.revolutions}`;
            if (progress >= 1) {
                finished = true;
                SFX.perfect();
                setTimeout(() => done({ revs: Math.abs(accum) / (Math.PI * 2), smooth: totalT > 0 ? goodT / totalT : 0, avgBurn: totalT > 0 ? burnInt / totalT : 0, maxBurn }), 600);
            }
        }
        c.clear();
        kitchenBackdrop(ctx);
        // pot from above
        const rim = ctx.createRadialGradient(cx - 60, cy - 60, 40, cx, cy, R + 30);
        rim.addColorStop(0, '#f5b07a'); rim.addColorStop(0.7, '#b55a26'); rim.addColorStop(1, '#4a200c');
        ctx.fillStyle = rim; ctx.beginPath(); ctx.arc(cx, cy, R + 26, 0, 7); ctx.fill();
        const thick = progress;
        const base = jam.map((v) => v * (1 - thick * 0.25));
        const g = ctx.createRadialGradient(cx - 40, cy - 50, 10, cx, cy, R);
        g.addColorStop(0, rgb(base.map((v) => Math.min(255, v + 60 + thick * 40)))); g.addColorStop(1, rgb(base.map((v) => v * 0.6)));
        ctx.fillStyle = g; ctx.beginPath(); ctx.arc(cx, cy, R, 0, 7); ctx.fill();
        // swirl
        ctx.save(); ctx.beginPath(); ctx.arc(cx, cy, R, 0, 7); ctx.clip();
        ctx.translate(cx, cy); ctx.rotate(accum * 0.6);
        for (let k = 0; k < 3; k++) {
            ctx.strokeStyle = `rgba(255,255,255,${0.08 + thick * 0.14})`; ctx.lineWidth = 6 - k;
            ctx.beginPath();
            for (let t = 0; t < 14; t += 0.1) { const r = 10 + t * 13; const a = t + k * 2.1; ctx.lineTo(Math.cos(a) * r, Math.sin(a) * r); }
            ctx.stroke();
        }
        ctx.restore();
        // scorched edge
        if (burn > 0.05) {
            const sg = ctx.createRadialGradient(cx, cy, R * 0.55, cx, cy, R);
            sg.addColorStop(0, 'rgba(20,8,4,0)'); sg.addColorStop(1, `rgba(20,8,4,${burn * 0.85})`);
            ctx.fillStyle = sg; ctx.beginPath(); ctx.arc(cx, cy, R, 0, 7); ctx.fill();
        }
        // guide ring
        if (speed < 0.3 && !finished) {
            ctx.strokeStyle = 'rgba(240,106,166,.55)'; ctx.setLineDash([10, 12]); ctx.lineWidth = 3;
            ctx.beginPath(); ctx.arc(cx, cy, 130, now / 400, now / 400 + Math.PI * 1.6); ctx.stroke(); ctx.setLineDash([]);
        }
        // spoon
        const sp = mouse && Math.hypot(mouse.x - cx, mouse.y - cy) < R + 10 ? mouse : { x: cx + Math.cos(accum) * 130, y: cy + Math.sin(accum) * 130 };
        const ang = Math.atan2(sp.y - cy, sp.x - cx);
        ctx.save(); ctx.translate(sp.x, sp.y); ctx.rotate(ang);
        ctx.fillStyle = '#c99257'; ctx.fillRect(10, -7, 260, 14);
        ctx.fillStyle = '#b07a40'; ctx.beginPath(); ctx.ellipse(0, 0, 34, 24, 0, 0, 7); ctx.fill();
        ctx.fillStyle = 'rgba(255,255,255,.18)'; ctx.beginPath(); ctx.ellipse(-6, -6, 18, 9, 0, 0, 7); ctx.fill();
        ctx.restore();
        splash.forEach((s) => { s.x += s.vx * dt; s.y += s.vy * dt; s.vy += 600 * dt; s.life -= dt * 2; ctx.globalAlpha = Math.max(0, s.life); ctx.fillStyle = rgb(jam); ctx.beginPath(); ctx.arc(s.x, s.y, 5, 0, 7); ctx.fill(); });
        ctx.globalAlpha = 1;
        // meters
        const meter = (x, label, v, col) => {
            ctx.fillStyle = 'rgba(255,255,255,.08)'; roundRect(ctx, x, 80, 22, 260, 11); ctx.fill();
            ctx.fillStyle = col; roundRect(ctx, x, 80 + 260 * (1 - v), 22, 260 * v, 11); ctx.fill();
            ctx.font = '13px Cinzel'; ctx.textAlign = 'center'; ctx.fillStyle = '#b9a2ad'; ctx.fillText(label, x + 11, 362);
        };
        meter(70, 'BURN', burn, burn > 0.7 ? '#ff4d4d' : '#ff8a5a');
        meter(910, 'THICK', thick, '#f06aa6');
        ctx.font = '700 16px Cinzel'; ctx.textAlign = 'center';
        const maxSpeed = 2.2 * (1 - 0.4 * progress);
        ctx.fillStyle = speed > maxSpeed ? '#ff8a7a' : speed >= 0.45 ? '#7fdc9a' : '#ffc66b';
        ctx.fillText(speed > maxSpeed ? 'Too fast — it\'s splashing!' : speed >= 0.45 ? 'Silky and glossy' : 'Keep it moving!', cx, 34);
        raf = requestAnimationFrame(frame);
    }
    raf = requestAnimationFrame(frame);
    c.cv.addEventListener('mousemove', onMove);
    return {
        key(e, down) {
            if (!down || !KEYS.includes(e.code) || finished) return;
            e.preventDefault();
            if (e.repeat) return;
            const i = KEYS.indexOf(e.code);
            if (keyStep === -1 || i === (keyStep + 1) % 4) pendingKeys = Math.min(Math.PI, pendingKeys + Math.PI / 2);
            else if (i === (keyStep + 3) % 4) pendingKeys = Math.max(-Math.PI, pendingKeys - Math.PI / 2);
            keyStep = i;
        },
        destroy() { cancelAnimationFrame(raf); c.cv.removeEventListener('mousemove', onMove); c.dispose(); h.remove(); },
    };
};

/* ═══════════════ D: FILL — stop pouring in the ideal range ═══════════════ */
Minigames.fill = (host, p, info, done) => {
    const c = makeCanvas(host);
    const { ctx } = c;
    const jam = jamColour(info.fruits);
    let fill = 0, flow = 0, pouring = false, released = false, finished = false, raf = 0, last = performance.now();
    const drips = [];
    const h = hud(host, `<span class="hint">Hold <span class="kbd">Space</span> or the button to pour. Release in the <b class="pink">perfect</b> zone — the ladle drips a little after you stop!</span>
        <button class="btn hold-btn" id="pour">Hold to Pour</button>`);
    const btn = $('#pour', h);
    const JX = 470, JY = 140, JW = 220, JH = 290;

    function frame(now) {
        const dt = Math.min(0.05, (now - last) / 1000); last = now;
        if (!finished) {
            const target = pouring && !released ? 1 : 0;
            flow += (target - flow) * Math.min(1, dt * (target ? 9 : 6));
            if (flow < 0.01 && released) flow = 0;
            fill += flow * p.speed * dt;
            if (pouring && Math.random() < 0.2) SFX.pour();
            if (fill > 100 && Math.random() < 0.4) drips.push({ x: JX + (Math.random() < .5 ? 0 : JW), y: JY + 4, vy: 30 });
            if (released && flow === 0) {
                finished = true;
                setTimeout(() => done({ fill: Math.round(fill * 10) / 10 }), 600);
            }
        }
        c.clear();
        kitchenBackdrop(ctx);
        ctx.fillStyle = '#2a1a12'; ctx.fillRect(0, 440, MW, 80);
        // gauge
        const gy0 = JY, gy1 = JY + JH;
        const gy = (v) => gy1 - clamp(v, 0, 110) / 110 * (gy1 - gy0);
        ctx.fillStyle = 'rgba(0,0,0,.55)'; roundRect(ctx, 316, gy0 - 8, 34, gy1 - gy0 + 16, 16); ctx.fill();
        ctx.fillStyle = '#5a3a3a'; ctx.fillRect(322, gy(p.idealMin), 22, gy1 - gy(p.idealMin));
        ctx.fillStyle = 'rgba(240,106,166,.55)'; ctx.fillRect(322, gy(p.idealMax), 22, gy(p.idealMin) - gy(p.idealMax));
        ctx.fillStyle = '#f06aa6'; ctx.fillRect(322, gy(p.perfectMax), 22, gy(p.perfectMin) - gy(p.perfectMax));
        ctx.fillStyle = '#c0392b'; ctx.fillRect(322, gy(110), 22, gy(p.idealMax) - gy(110));
        ctx.font = '15px Cinzel'; ctx.textAlign = 'right'; ctx.fillStyle = '#b9a2ad';
        ctx.fillText('Too Full', 300, gy(104) + 5);
        ctx.fillStyle = '#ff9cc8'; ctx.fillText('Perfect!', 300, gy((p.perfectMin + p.perfectMax) / 2) + 5);
        ctx.fillStyle = '#b9a2ad'; ctx.fillText('Too Low', 300, gy(p.idealMin / 2) + 5);
        ctx.fillStyle = '#fff'; ctx.fillRect(312, gy(fill) - 2, 42, 4);
        // jar
        ctx.save();
        roundRect(ctx, JX, JY, JW, JH, 26); ctx.clip();
        const lv = JY + JH - clamp(fill, 0, 100) / 100 * JH;
        const jg = ctx.createLinearGradient(0, lv, 0, JY + JH);
        jg.addColorStop(0, rgb(jam.map((v) => Math.min(255, v + 40)))); jg.addColorStop(1, rgb(jam.map((v) => v * 0.55)));
        ctx.fillStyle = jg; ctx.fillRect(JX, lv + Math.sin(now / 120) * 1.5, JW, JY + JH - lv);
        ctx.restore();
        ctx.fillStyle = 'rgba(230,220,235,.08)'; roundRect(ctx, JX, JY, JW, JH, 26); ctx.fill();
        ctx.strokeStyle = 'rgba(255,255,255,.55)'; ctx.lineWidth = 3; roundRect(ctx, JX, JY, JW, JH, 26); ctx.stroke();
        ctx.fillStyle = 'rgba(255,255,255,.22)'; roundRect(ctx, JX + 18, JY + 30, 16, JH - 70, 8); ctx.fill();
        ctx.strokeStyle = 'rgba(255,255,255,.35)'; ctx.lineWidth = 2;
        for (let i = 0; i < 3; i++) { ctx.beginPath(); ctx.moveTo(JX + 6, JY - 6 - i * 8); ctx.lineTo(JX + JW - 6, JY - 4 - i * 8); ctx.stroke(); }
        // ladle & stream
        const tilt = 0.25 + flow * 0.55;
        ctx.save(); ctx.translate(640, 70); ctx.rotate(-tilt);
        ctx.fillStyle = '#9aa3ad'; ctx.fillRect(0, -6, 230, 12);
        ctx.fillStyle = '#c5ccd3'; ctx.beginPath(); ctx.arc(-20, 10, 46, 0, Math.PI); ctx.fill();
        ctx.fillStyle = rgb(jam); ctx.beginPath(); ctx.ellipse(-20, 10, 40, 10, 0, 0, 7); ctx.fill();
        ctx.restore();
        if (flow > 0.02) {
            ctx.strokeStyle = rgb(jam, 0.95); ctx.lineWidth = 4 + flow * 12; ctx.lineCap = 'round';
            ctx.beginPath(); ctx.moveTo(588, 90); ctx.quadraticCurveTo(586, 130, JX + JW / 2 + 40, lv);
            ctx.stroke();
        }
        drips.forEach((d) => { d.vy += 500 * dt; d.y += d.vy * dt; ctx.fillStyle = rgb(jam); ctx.beginPath(); ctx.ellipse(d.x, d.y, 5, 8, 0, 0, 7); ctx.fill(); });
        ctx.font = '700 34px Cinzel'; ctx.textAlign = 'center'; ctx.fillStyle = '#ffe3f0';
        ctx.fillText(`${Math.floor(fill)}%`, 820, 300);
        ctx.font = '14px Cinzel'; ctx.fillStyle = '#b9a2ad'; ctx.fillText('FILL LEVEL', 820, 326);
        raf = requestAnimationFrame(frame);
    }
    raf = requestAnimationFrame(frame);
    const set = (v) => {
        if (released || finished) return;
        if (v) { pouring = true; btn.classList.add('holding'); }
        else if (pouring) { pouring = false; if (fill > 2) released = true; btn.classList.remove('holding'); }
    };
    const down = () => set(true), up = () => set(false);
    btn.addEventListener('mousedown', down); c.cv.addEventListener('mousedown', down);
    window.addEventListener('mouseup', up);
    return {
        key(e, isDown) { if (e.code === 'Space' || e.code === 'ArrowDown') { e.preventDefault(); if (!e.repeat || !isDown) set(isDown); } },
        destroy() { cancelAnimationFrame(raf); window.removeEventListener('mouseup', up); c.dispose(); h.remove(); },
    };
};

/* ═══════════════ E: SEAL — twist the lid on with precise timing ═══════════════ */
Minigames.seal = (host, p, info, done) => {
    const c = makeCanvas(host);
    const { ctx } = c;
    const cx = 500, cy = 255, R = 165;
    let needle = 0, speed = p.speed, attempt = 0, zone = Math.random() * 360, lidRot = 0, lidTarget = 0, raf = 0, last = performance.now(), cooldown = 0, finished = false;
    const offsets = [], texts = [];
    const h = hud(host, `<span class="hint">Press <span class="kbd">Space</span> or click when the needle is inside the <b class="pink">pink arc</b>. Three twists to seal.</span><b id="sCount" style="font-family:Cinzel">0 / ${p.attempts}</b>`);

    function press() {
        if (finished || cooldown > 0) return;
        let off = ((needle - zone + 540) % 360) - 180;
        offsets.push(Math.round(off * 10) / 10);
        const a = Math.abs(off);
        if (a <= p.perfect) { SFX.perfect(); texts.push({ s: 'Perfect seal!', c: '#ffd36b', t: 0 }); }
        else if (a <= p.zone / 2) { SFX.twist(); texts.push({ s: 'Tight', c: '#ffb3d6', t: 0 }); }
        else { SFX.bad(); texts.push({ s: 'Cross-threaded', c: '#ff8a7a', t: 0 }); }
        lidTarget += 40;
        attempt++;
        $('#sCount', h).textContent = `${attempt} / ${p.attempts}`;
        cooldown = 0.45;
        if (attempt >= p.attempts) { finished = true; setTimeout(() => done({ offsets }), 800); }
        else { zone = (zone + 120 + Math.random() * 120) % 360; speed *= 1.12; }
    }

    function frame(now) {
        const dt = Math.min(0.05, (now - last) / 1000); last = now;
        if (!finished) needle = (needle + speed * dt) % 360;
        cooldown = Math.max(0, cooldown - dt);
        lidRot += (lidTarget - lidRot) * Math.min(1, dt * 10);
        c.clear();
        kitchenBackdrop(ctx);
        // jar glimpse
        ctx.fillStyle = 'rgba(255,255,255,.06)'; ctx.beginPath(); ctx.arc(cx, cy, R + 40, 0, 7); ctx.fill();
        // zone arc
        if (!finished) {
            const z0 = (zone - p.zone / 2 - 90) * Math.PI / 180, z1 = (zone + p.zone / 2 - 90) * Math.PI / 180;
            ctx.strokeStyle = 'rgba(240,106,166,.85)'; ctx.lineWidth = 26;
            ctx.beginPath(); ctx.arc(cx, cy, R + 24, z0, z1); ctx.stroke();
            const p0 = (zone - p.perfect - 90) * Math.PI / 180, p1 = (zone + p.perfect - 90) * Math.PI / 180;
            ctx.strokeStyle = '#ffd36b'; ctx.beginPath(); ctx.arc(cx, cy, R + 24, p0, p1); ctx.stroke();
        }
        // lid
        ctx.save(); ctx.translate(cx, cy); ctx.rotate(lidRot * Math.PI / 180);
        const gold = ctx.createRadialGradient(-R * 0.35, -R * 0.4, R * 0.1, 0, 0, R);
        gold.addColorStop(0, '#fbe6b4'); gold.addColorStop(0.55, '#d6a95a'); gold.addColorStop(1, '#7a5520');
        ctx.fillStyle = gold; ctx.beginPath(); ctx.arc(0, 0, R, 0, 7); ctx.fill();
        ctx.strokeStyle = 'rgba(80,50,15,.55)'; ctx.lineWidth = 3;
        for (let i = 0; i < 72; i++) { const a = i / 72 * Math.PI * 2; ctx.beginPath(); ctx.moveTo(Math.cos(a) * (R - 14), Math.sin(a) * (R - 14)); ctx.lineTo(Math.cos(a) * R, Math.sin(a) * R); ctx.stroke(); }
        ctx.strokeStyle = 'rgba(255,240,200,.5)'; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(0, 0, R * 0.72, 0, 7); ctx.stroke();
        ctx.font = `700 ${Math.round(R * 0.8)}px Cinzel`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        ctx.fillStyle = 'rgba(120,20,70,.35)'; ctx.fillText('V', 3, 6);
        ctx.fillStyle = '#c2185b'; ctx.fillText('V', 0, 0);
        ctx.textBaseline = 'alphabetic';
        ctx.restore();
        ctx.strokeStyle = 'rgba(255,255,255,.2)'; ctx.lineWidth = 2;
        for (let i = 0; i < 36; i++) { const a = i / 36 * Math.PI * 2; ctx.beginPath(); ctx.moveTo(cx + Math.cos(a) * (R + 10), cy + Math.sin(a) * (R + 10)); ctx.lineTo(cx + Math.cos(a) * (R + 38), cy + Math.sin(a) * (R + 38)); ctx.stroke(); }
        // needle
        const na = (needle - 90) * Math.PI / 180;
        ctx.strokeStyle = '#fff'; ctx.lineWidth = 5; ctx.shadowColor = '#fff'; ctx.shadowBlur = 12;
        ctx.beginPath(); ctx.moveTo(cx + Math.cos(na) * (R + 4), cy + Math.sin(na) * (R + 4)); ctx.lineTo(cx + Math.cos(na) * (R + 48), cy + Math.sin(na) * (R + 48)); ctx.stroke();
        ctx.shadowBlur = 0;
        texts.forEach((x) => { x.t += dt; ctx.globalAlpha = Math.max(0, 1 - x.t / 1.2); ctx.font = '700 30px Cinzel'; ctx.textAlign = 'center'; ctx.fillStyle = x.c; ctx.fillText(x.s, cx, 60 - x.t * 20); });
        ctx.globalAlpha = 1;
        raf = requestAnimationFrame(frame);
    }
    raf = requestAnimationFrame(frame);
    c.cv.addEventListener('mousedown', press);
    return {
        key(e, down) { if (down && (e.code === 'Space' || e.code === 'Enter') && !e.repeat) { e.preventDefault(); press(); } },
        destroy() { cancelAnimationFrame(raf); c.cv.removeEventListener('mousedown', press); c.dispose(); h.remove(); },
    };
};

const TUTORIALS = {
    prepare: { title: 'Prepare the Fruit', steps: ['Targets light up one at a time, in numbered order.', 'A ring shrinks towards the dashed circle — click the fruit (or press <span class="kbd">Space</span>) as they meet.', 'Gold timing is <b class="gold">Perfect</b>. Missing or slicing off-target lowers quality.'] },
    heat: { title: 'Heat the Jam', steps: ['Hold the button, the mouse or <span class="kbd">Space</span> to turn up the burner. Release to let it cool.', 'The burner takes a moment to respond — feather it gently.', 'Stay inside the <b class="pink">pink band</b> until the pot is fully cooked. Too hot scorches it; too cold cooks slowly.'] },
    stir: { title: 'Stir the Mixture', steps: ['Move your mouse in steady circles inside the pot (or tap the arrow keys in rotation).', 'Stirring too slowly lets the jam catch and burn. Too fast splashes it.', 'The jam thickens as you go — slow down a touch for a silky, glossy finish.'] },
    fill: { title: 'Fill the Jar', steps: ['Hold <span class="kbd">Space</span> or the button to pour from the ladle.', 'Release inside the <b class="pink">Perfect</b> band on the gauge. The ladle keeps dripping briefly after you let go.', 'Under-filling lowers quality; overfilling wastes jam.'] },
    seal: { title: 'Seal the Lid', steps: ['A needle sweeps around the lid.', 'Press <span class="kbd">Space</span> or click while it is inside the <b class="pink">pink arc</b> — the gold centre is perfect.', 'Three twists to seal. Each twist gets a little faster.'] },
};

window.Minigames = Minigames;
window.TUTORIALS = TUTORIALS;
