/* ==========================================================================
   VELORA CITY — Starter Pack UI logic
   The UI only ever sends { path, token } to the game. All rewards shown here
   are display data sent by the server; nothing here decides what is granted.
   ========================================================================== */
(() => {
    'use strict';

    const IN_GAME = typeof window.GetParentResourceName === 'function';
    const RESOURCE = IN_GAME ? window.GetParentResourceName() : 'velora_starterpack';

    const $ = (id) => document.getElementById(id);
    const app = $('app');

    const state = {
        data: null,
        phase: 'hidden', // hidden | select | confirm | processing | reward
        selected: null,
        resumePath: null,
    };

    // ------------------------------------------------------------------
    // Communication with the game client
    // ------------------------------------------------------------------
    async function post(name, body = {}) {
        if (!IN_GAME) return devPost(name, body);
        try {
            const res = await fetch(`https://${RESOURCE}/${name}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(body),
            });
            return await res.json();
        } catch (e) {
            return { ok: false, message: 'Connection to the game was lost. Please try again.' };
        }
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    const el = (tag, cls, text) => {
        const node = document.createElement(tag);
        if (cls) node.className = cls;
        if (text !== undefined && text !== null) node.textContent = String(text);
        return node;
    };
    const svg = (markup, cls) => {
        const wrap = document.createElement('div');
        wrap.innerHTML = markup.trim(); // static, trusted markup only
        const node = wrap.firstChild;
        if (cls) node.setAttribute('class', cls);
        return node;
    };
    const money = (n) => '$' + Math.max(0, Math.floor(Number(n) || 0)).toLocaleString('en-US');
    const txt = (key, fallback) => (state.data && state.data.ui && state.data.ui.text && state.data.ui.text[key]) || fallback;
    const themeOf = (path) => (path && path.theme === 'criminal') ? 'criminal' : 'civilian';
    const setText = (id, value) => { const n = $(id); if (n && value !== undefined) n.textContent = value; };

    const ICONS = {
        cash: '<svg viewBox="0 0 24 24"><rect x="2.5" y="6" width="19" height="12" rx="2"/><circle cx="12" cy="12" r="2.6"/><path d="M6 9.5v5M18 9.5v5"/></svg>',
        bank: '<svg viewBox="0 0 24 24"><path d="M3 10l9-6 9 6M5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 20h18"/></svg>',
        briefcase: '<svg viewBox="0 0 24 24"><rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V5a2 2 0 012-2h2a2 2 0 012 2v2M3 13h18"/></svg>',
        bag: '<svg viewBox="0 0 24 24"><path d="M5 8h14l-1.2 12H6.2L5 8z"/><path d="M9 8V6a3 3 0 016 0v2"/></svg>',
        diamond: '<svg viewBox="0 0 24 24"><path d="M6 3h12l3 6-9 12L3 9l3-6z"/><path d="M3 9h18M9 3l3 18 3-18"/></svg>',
        mask: '<svg viewBox="0 0 24 24"><path d="M3 8c3-2 15-2 18 0 0 6-3 10-9 10S3 14 3 8z"/><path d="M7 11h3M14 11h3"/></svg>',
        dice: '<svg viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="16" rx="3"/><circle cx="9" cy="9" r=".9"/><circle cx="15" cy="15" r=".9"/><circle cx="15" cy="9" r=".9"/><circle cx="9" cy="15" r=".9"/></svg>',
        lamp: '<svg viewBox="0 0 24 24"><path d="M12 21V8M8 8h8l-2-4h-4L8 8zM9 21h6"/></svg>',
        car: '<svg viewBox="0 0 24 24"><path d="M5 16h14v-3.5l-1.6-4.2A2 2 0 0015.5 7h-7a2 2 0 00-1.9 1.3L5 12.5V16z"/><path d="M5 12.5h14M3.5 11l1.5 1.5M20.5 11L19 12.5"/><circle cx="8" cy="16.5" r="1.6"/><circle cx="16" cy="16.5" r="1.6"/></svg>',
        journey: '<svg viewBox="0 0 24 24"><path d="M12 2l2.5 6.5L21 9l-5 4.5L17.5 21 12 17l-5.5 4L8 13.5 3 9l6.5-.5L12 2z"/></svg>',
    };

    // Procedural skyline art for each card (no external images needed).
    function skyline(theme) {
        const ns = 'http://www.w3.org/2000/svg';
        const s = document.createElementNS(ns, 'svg');
        s.setAttribute('viewBox', '0 0 400 150');
        s.setAttribute('preserveAspectRatio', 'none');
        s.setAttribute('class', 'skyline');

        // Deterministic pseudo-random so both cards always look the same.
        let seed = theme === 'criminal' ? 7 : 3;
        const rnd = () => { seed = (seed * 9301 + 49297) % 233280; return seed / 233280; };

        let x = 0;
        while (x < 400) {
            const w = 18 + Math.floor(rnd() * 34);
            const h = theme === 'criminal' ? 40 + rnd() * 70 : 50 + rnd() * 95;
            const b = document.createElementNS(ns, 'rect');
            b.setAttribute('x', x); b.setAttribute('y', 150 - h);
            b.setAttribute('width', w); b.setAttribute('height', h);
            s.appendChild(b);

            for (let wy = 150 - h + 8; wy < 142; wy += 11) {
                for (let wx = x + 4; wx < x + w - 5; wx += 8) {
                    if (rnd() > (theme === 'criminal' ? 0.86 : 0.62)) {
                        const win = document.createElementNS(ns, 'rect');
                        win.setAttribute('x', wx); win.setAttribute('y', wy);
                        win.setAttribute('width', 3); win.setAttribute('height', 4);
                        win.setAttribute('class', 'win');
                        s.appendChild(win);
                    }
                }
            }
            x += w + 2;
        }
        return s;
    }

    // ------------------------------------------------------------------
    // Rendering
    // ------------------------------------------------------------------
    function applyTheme(colors = {}) {
        const map = {
            primary: '--pink', primaryGlow: '--pink-glow', accent: '--pink-soft', roseGold: '--rose-gold',
            background: '--bg', surface: '--surface', text: '--text', textMuted: '--muted',
            criminal: '--crim', criminalRed: '--crim-red',
        };
        for (const [key, cssVar] of Object.entries(map)) {
            if (typeof colors[key] === 'string') document.documentElement.style.setProperty(cssVar, colors[key]);
        }
    }

    function applyText() {
        setText('txtBrand', txt('brand', 'VELORA CITY'));
        setText('txtBrand2', txt('brand', 'VELORA CITY'));
        setText('txtWelcomeTitle', txt('welcomeTitle', 'WELCOME TO VELORA CITY'));
        setText('txtWelcomeSubtitle', txt('welcomeSubtitle', 'Every story has a beginning. What will yours be?'));
        setText('txtStandardHeading', txt('standardHeading', 'Included With Every Path'));
        setText('txtStandardSubtitle', txt('standardSubtitle', 'Whichever path you choose, you also receive all of these.'));
        setText('txtConfirmTitle', txt('confirmTitle', 'Begin Your Journey?'));
        setText('txtConfirm', txt('confirmButton', 'Confirm My Journey'));
        setText('txtBack', txt('backButton', 'Go Back'));
        setText('txtProcessing', txt('processing', 'Preparing your rewards…'));
        setText('txtRewardTitle', txt('rewardTitle', 'YOUR VELORA JOURNEY BEGINS!'));
        setText('txtRewardSubtitle', txt('rewardSubtitle', 'Your rewards have been delivered.'));
        setText('txtFinish', txt('finishButton', 'WELCOME TO VELORA'));
        setText('txtResume', txt('resumeNotice', ''));
        const allowClose = !state.data || !state.data.ui || state.data.ui.allowClose !== false;
        setText('txtCloseHint', allowClose ? txt('closeHint', '') : '');
        $('closeBtn').classList.toggle('hidden', !allowClose);
    }

    function itemTile(item) {
        const tile = el('div', 'tile');
        const imgWrap = el('div', 'tile-img');
        const img = document.createElement('img');
        img.alt = '';
        img.draggable = false;
        img.onerror = () => {
            img.remove();
            imgWrap.appendChild(el('span', 'fallback', (item.label || item.name || '?').charAt(0).toUpperCase()));
        };
        if (typeof item.image === 'string') img.src = item.image;
        imgWrap.appendChild(img);

        const info = el('div', 'tile-info');
        info.appendChild(el('div', 'tile-label', item.label || item.name));
        info.appendChild(el('div', 'tile-count', 'x' + (Number(item.count) || 0)));
        tile.append(imgWrap, info);
        return tile;
    }

    function moneyTile(kind, amount) {
        const tile = el('div', 'tile money');
        const imgWrap = el('div', 'tile-img');
        imgWrap.appendChild(svg(ICONS[kind]));
        const info = el('div', 'tile-info');
        info.appendChild(el('div', 'tile-label', kind === 'cash' ? txt('cashLabel', 'Cash') : txt('bankLabel', 'Bank')));
        info.appendChild(el('div', 'tile-count', money(amount)));
        tile.append(imgWrap, info);
        return tile;
    }

    function vehicleImage(vehicle, wrapClass) {
        const wrap = el('div', wrapClass);
        const img = document.createElement('img');
        img.alt = '';
        img.draggable = false;
        img.onerror = () => {
            img.remove();
            wrap.classList.add('no-image');
            wrap.appendChild(svg(ICONS.car));
        };
        if (typeof vehicle.image === 'string') img.src = vehicle.image;
        wrap.appendChild(img);
        return wrap;
    }

    const garageText = (vehicle) => vehicle.garage ? txt('vehicleGarage', 'Waiting in: %s').replace('%s', vehicle.garage) : '';

    function vehicleTile(vehicle) {
        const tile = el('div', 'tile vehicle');
        tile.appendChild(vehicleImage(vehicle, 'tile-img'));
        const info = el('div', 'tile-info');
        info.appendChild(el('div', 'tile-tag', txt('vehicleHeading', 'Your First Ride')));
        info.appendChild(el('div', 'tile-label', vehicle.label || vehicle.model));
        info.appendChild(el('div', 'tile-sub', garageText(vehicle)));
        tile.appendChild(info);
        return tile;
    }

    function renderCards() {
        const container = $('paths');
        container.innerHTML = '';
        const paths = (state.data && state.data.paths) || [];

        paths.forEach((path) => {
            const theme = themeOf(path);
            const card = el('article', `card theme-${theme}`);
            card.dataset.path = path.key;

            if (state.resumePath) {
                if (state.resumePath === path.key) card.classList.add('chosen');
                else card.classList.add('locked');
            }

            const inner = el('div', 'card-inner');

            // Art
            const art = el('div', 'card-art');
            art.appendChild(el('div', 'sky'));
            if (theme === 'criminal') {
                const smoke = el('div', 'smoke');
                smoke.append(el('span'), el('span'), el('span'));
                art.appendChild(smoke);
            }
            art.appendChild(skyline(theme));
            const icons = el('div', 'card-icons');
            (theme === 'criminal' ? ['mask', 'dice', 'lamp'] : ['briefcase', 'bag', 'diamond']).forEach((k) => {
                const ic = el('div', 'ic');
                ic.appendChild(svg(ICONS[k]));
                icons.appendChild(ic);
            });
            art.appendChild(icons);
            art.appendChild(el('div', 'card-label', String(path.label || path.key).toUpperCase()));
            inner.appendChild(art);

            // Body
            const body = el('div', 'card-body');
            body.appendChild(el('h2', 'card-title', path.title));
            body.appendChild(el('div', 'card-subtitle', path.subtitle));
            body.appendChild(el('p', 'card-desc', path.description));

            if (Array.isArray(path.tags) && path.tags.length) {
                const tags = el('div', 'tags');
                path.tags.forEach((t) => tags.appendChild(el('span', 'tag', t)));
                body.appendChild(tags);
            }

            const bonus = el('div', 'bonus');
            bonus.appendChild(el('div', 'section-label', txt('bonusHeading', 'Path Bonus')));
            const list = el('div', 'bonus-list');
            (path.items || []).forEach((item) => list.appendChild(itemTile(item)));
            (path.vehicles || []).forEach((v) => list.appendChild(vehicleTile(v)));
            if (path.money) {
                if (path.money.cash > 0) list.appendChild(moneyTile('cash', path.money.cash));
                if (path.money.bank > 0) list.appendChild(moneyTile('bank', path.money.bank));
            }
            bonus.appendChild(list);
            body.appendChild(bonus);

            const resuming = state.resumePath === path.key;
            const btn = el('button', 'btn btn-primary btn-select');
            btn.appendChild(el('span', null, resuming ? txt('resumeButton', 'COLLECT MY REWARDS') : txt('selectButton', 'SELECT PATH')));
            btn.appendChild(svg('<svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6"/></svg>'));
            btn.addEventListener('click', () => onSelect(path));
            body.appendChild(btn);

            inner.appendChild(body);
            card.appendChild(inner);
            container.appendChild(card);
        });
    }

    function renderStandard() {
        const grid = $('standardGrid');
        grid.innerHTML = '';
        const std = (state.data && state.data.standard) || {};
        (std.vehicles || []).forEach((v) => grid.appendChild(vehicleTile(v)));
        (std.items || []).forEach((item) => grid.appendChild(itemTile(item)));
        if (std.money) {
            if (std.money.cash > 0) grid.appendChild(moneyTile('cash', std.money.cash));
            if (std.money.bank > 0) grid.appendChild(moneyTile('bank', std.money.bank));
        }
    }

    // ------------------------------------------------------------------
    // Flow
    // ------------------------------------------------------------------
    function findPath(key) {
        return ((state.data && state.data.paths) || []).find((p) => p.key === key);
    }

    function onSelect(path) {
        if (state.phase !== 'select') return;
        state.selected = path.key;

        // Path already locked in: no need to confirm again, just collect.
        if (state.resumePath === path.key) {
            claim();
            return;
        }
        if (state.resumePath) return;

        const theme = themeOf(path);
        const box = $('confirmBox');
        box.classList.remove('theme-civilian', 'theme-criminal');
        box.classList.add(`theme-${theme}`);

        const icon = $('confirmIcon');
        icon.innerHTML = '';
        icon.appendChild(svg(theme === 'criminal' ? ICONS.mask : ICONS.diamond));

        // Bold the path name inside the configurable sentence.
        const template = txt('confirmText', 'Are you sure you want to begin your Velora journey as a %s? This choice cannot be changed.');
        const parts = template.split('%s');
        const p = $('confirmText');
        p.innerHTML = '';
        p.appendChild(document.createTextNode(parts[0] || ''));
        p.appendChild(el('strong', null, path.label || path.key));
        p.appendChild(document.createTextNode(parts.slice(1).join('%s')));

        $('confirmModal').classList.remove('hidden');
        state.phase = 'confirm';
        setTimeout(() => $('confirmBtn').focus(), 50);
    }

    function closeConfirm() {
        $('confirmModal').classList.add('hidden');
        if (state.phase === 'confirm') state.phase = 'select';
    }

    let toastTimer = null;
    function toast(message) {
        if (!message) return;
        const t = $('toast');
        t.textContent = message;
        t.classList.remove('hidden');
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => t.classList.add('hidden'), 7000);
    }

    async function claim() {
        if (!state.selected || !state.data) return;
        if (state.phase === 'processing') return;

        $('confirmModal').classList.add('hidden');
        $('processing').classList.remove('hidden');
        $('confirmBtn').disabled = true;
        state.phase = 'processing';

        const started = Date.now();
        const result = await post('claim', { path: state.selected, token: state.data.token });

        // Keep the loader visible briefly so the transition feels intentional.
        const elapsed = Date.now() - started;
        if (elapsed < 900) await new Promise((r) => setTimeout(r, 900 - elapsed));

        $('processing').classList.add('hidden');
        $('confirmBtn').disabled = false;

        if (state.phase !== 'processing') return; // UI was closed meanwhile

        if (result && result.ok) {
            showReward(result);
            return;
        }

        state.phase = 'select';
        if (result && result.lockedPath && findPath(result.lockedPath)) {
            state.resumePath = result.lockedPath;
            $('resumeBanner').classList.remove('hidden');
            renderCards();
        }
        if (!result || result.error !== 'busy') {
            toast((result && result.message) || 'Something went wrong. Please try again.');
        }
    }

    function countUp(node, target, duration = 1600) {
        const start = performance.now();
        const step = (now) => {
            const t = Math.min(1, (now - start) / duration);
            const eased = 1 - Math.pow(1 - t, 3);
            node.textContent = money(target * eased);
            if (t < 1 && state.phase === 'reward') requestAnimationFrame(step);
            else node.textContent = money(target);
        };
        requestAnimationFrame(step);
    }

    function showReward(result) {
        state.phase = 'reward';
        const path = findPath(result.path) || { label: result.pathLabel, key: result.path };
        const theme = themeOf(path);

        $('screenSelect').classList.add('hidden');
        $('closeBtn').classList.add('hidden');
        $('screenReward').classList.remove('hidden');
        $('screenReward').scrollTop = 0;

        const badge = $('rewardPathBadge');
        badge.className = `path-badge theme-${theme}`;
        badge.innerHTML = '';
        badge.appendChild(svg(ICONS.journey, ''));
        badge.firstChild.style.cssText = 'width:14px;height:14px;fill:none;stroke:currentColor;stroke-width:2';
        badge.appendChild(el('span', null, path.title || path.label || ''));

        const moneyRow = $('rewardMoney');
        moneyRow.innerHTML = '';
        const rewards = result.rewards || {};
        const m = rewards.money || {};
        [['cash', m.cash], ['bank', m.bank]].forEach(([kind, amount], i) => {
            if (!(amount > 0)) return;
            const card = el('div', 'money-card');
            card.style.animationDelay = `${0.45 + i * 0.12}s`;
            card.appendChild(el('div', 'm-label', kind === 'cash' ? txt('cashLabel', 'Cash') : txt('bankLabel', 'Bank')));
            const value = el('div', 'm-value', money(0));
            card.appendChild(value);
            moneyRow.appendChild(card);
            setTimeout(() => countUp(value, amount), 600 + i * 150);
        });

        const vehicleRow = $('rewardVehicles');
        vehicleRow.innerHTML = '';
        (rewards.vehicles || []).forEach((vehicle, i) => {
            const card = el('div', 'vehicle-card');
            card.style.animationDelay = `${0.6 + i * 0.15}s`;
            card.appendChild(vehicleImage(vehicle, 'vehicle-img'));
            const info = el('div', 'vehicle-info');
            info.appendChild(el('div', 'm-label', txt('vehicleHeading', 'Your First Ride')));
            info.appendChild(el('div', 'vehicle-name', vehicle.label || vehicle.model));
            info.appendChild(el('div', 'vehicle-garage', garageText(vehicle)));
            card.appendChild(info);
            vehicleRow.appendChild(card);
        });

        const grid = $('rewardGrid');
        grid.innerHTML = '';
        (rewards.items || []).forEach((item, i) => {
            const tile = itemTile(item);
            tile.style.animationDelay = `${0.8 + i * 0.08}s`;
            grid.appendChild(tile);
        });

        const note = $('reviewNote');
        if (result.needsReview && result.message) {
            note.textContent = result.message;
            note.classList.remove('hidden');
        } else {
            note.classList.add('hidden');
        }

        burstParticles();
        setTimeout(() => $('finishBtn').focus(), 400);
    }

    async function requestClose() {
        if (state.phase === 'processing') return;
        if (state.phase === 'reward') {
            hide();
            await post('close');
            return;
        }
        const allowClose = !state.data || !state.data.ui || state.data.ui.allowClose !== false;
        if (!allowClose) return;
        hide();
        await post('close');
    }

    // ------------------------------------------------------------------
    // Show / hide
    // ------------------------------------------------------------------
    function show(data) {
        state.data = data || {};
        state.selected = null;
        state.resumePath = data && data.resume && data.resume.path ? data.resume.path : null;
        state.phase = 'select';

        applyTheme((data.ui && data.ui.colors) || {});
        applyText();
        renderCards();
        renderStandard();

        $('resumeBanner').classList.toggle('hidden', !state.resumePath);
        $('screenSelect').classList.remove('hidden');
        $('screenReward').classList.add('hidden');
        $('confirmModal').classList.add('hidden');
        $('processing').classList.add('hidden');
        $('toast').classList.add('hidden');
        $('screenSelect').scrollTop = 0;

        app.classList.remove('hidden');
        app.setAttribute('aria-hidden', 'false');
        requestAnimationFrame(() => app.classList.add('visible'));
        particles.start();
    }

    let hideTimer = null;
    function hide() {
        state.phase = 'hidden';
        app.classList.remove('visible');
        app.setAttribute('aria-hidden', 'true');
        clearTimeout(hideTimer);
        hideTimer = setTimeout(() => {
            if (state.phase !== 'hidden') return;
            app.classList.add('hidden');
            particles.stop();
        }, 600);
    }

    // ------------------------------------------------------------------
    // Particles (only animate while visible)
    // ------------------------------------------------------------------
    const particles = (() => {
        const canvas = $('particles');
        const ctx = canvas.getContext('2d');
        let list = [];
        let raf = null;
        let w = 0, h = 0, dpr = 1;

        function resize() {
            dpr = Math.min(window.devicePixelRatio || 1, 2);
            w = canvas.clientWidth; h = canvas.clientHeight;
            canvas.width = w * dpr; canvas.height = h * dpr;
            ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        }

        function make(burst) {
            const pink = Math.random() > 0.3;
            return {
                x: burst ? w / 2 + (Math.random() - 0.5) * 120 : Math.random() * w,
                y: burst ? h * 0.42 : h + Math.random() * h,
                r: Math.random() * 2.2 + 0.6,
                vx: burst ? (Math.random() - 0.5) * 7 : (Math.random() - 0.5) * 0.25,
                vy: burst ? (Math.random() - 0.7) * 7 : -(Math.random() * 0.45 + 0.15),
                a: Math.random() * 0.6 + 0.25,
                hue: pink ? 330 : 275,
                life: burst ? 120 + Math.random() * 60 : Infinity,
                burst,
            };
        }

        function frame() {
            ctx.clearRect(0, 0, w, h);
            for (let i = list.length - 1; i >= 0; i--) {
                const p = list[i];
                p.x += p.vx; p.y += p.vy;
                if (p.burst) { p.vy += 0.06; p.vx *= 0.985; p.life -= 1; }
                if ((p.burst && p.life <= 0) || p.y < -20 || p.x < -20 || p.x > w + 20) {
                    if (p.burst) { list.splice(i, 1); continue; }
                    Object.assign(p, make(false), { y: h + 10 });
                }
                const alpha = p.burst ? Math.min(1, p.life / 60) * p.a : p.a;
                ctx.beginPath();
                ctx.fillStyle = `hsla(${p.hue}, 100%, 72%, ${alpha})`;
                ctx.shadowBlur = 12;
                ctx.shadowColor = `hsla(${p.hue}, 100%, 65%, ${alpha})`;
                ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
                ctx.fill();
            }
            raf = requestAnimationFrame(frame);
        }

        return {
            start() {
                resize();
                if (!list.length) list = Array.from({ length: 70 }, () => make(false)).map((p) => ({ ...p, y: Math.random() * h }));
                if (!raf) raf = requestAnimationFrame(frame);
            },
            stop() {
                if (raf) cancelAnimationFrame(raf);
                raf = null;
                list = [];
                ctx.clearRect(0, 0, w, h);
            },
            burst(n = 140) {
                for (let i = 0; i < n; i++) list.push(make(true));
            },
            resize,
        };
    })();

    function burstParticles() {
        particles.burst(160);
        setTimeout(() => state.phase === 'reward' && particles.burst(90), 450);
    }

    window.addEventListener('resize', () => { if (state.phase !== 'hidden') particles.resize(); });

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------
    $('confirmBtn').addEventListener('click', claim);
    $('backBtn').addEventListener('click', closeConfirm);
    $('closeBtn').addEventListener('click', requestClose);
    $('finishBtn').addEventListener('click', requestClose);
    $('confirmModal').addEventListener('click', (e) => { if (e.target === $('confirmModal')) closeConfirm(); });

    document.addEventListener('keydown', (e) => {
        if (state.phase === 'hidden') return;
        if (e.key === 'Escape' || e.key === 'Backspace') {
            e.preventDefault();
            if (state.phase === 'confirm') closeConfirm();
            else requestClose();
        }
    });

    window.addEventListener('message', (event) => {
        const msg = event.data;
        if (!msg || typeof msg !== 'object') return;
        if (msg.action === 'open') show(msg.data || {});
        else if (msg.action === 'close') hide();
    });

    // ------------------------------------------------------------------
    // Browser preview (opening web/index.html outside FiveM)
    // ------------------------------------------------------------------
    function devPost(name, body) {
        if (name === 'claim') {
            const path = findPath(body.path);
            return new Promise((resolve) => setTimeout(() => resolve({
                ok: true, path: body.path, pathLabel: path.label,
                rewards: {
                    items: [...state.data.standard.items, ...path.items],
                    vehicles: [...state.data.standard.vehicles, ...(path.vehicles || [])],
                    money: { cash: state.data.standard.money.cash, bank: state.data.standard.money.bank },
                },
            }), 600));
        }
        if (name === 'close') setTimeout(() => show(DEV_DATA), 1500);
        return Promise.resolve({ ok: true });
    }

    const img = (n) => `nui://ox_inventory/web/images/${n}.png`;
    const DEV_DATA = {
        token: 'dev',
        ui: { allowClose: true, text: { closeHint: 'Browser preview — press ESC to decide later.' } },
        paths: [
            {
                key: 'civilian', label: 'Civilian', theme: 'civilian', title: 'THE CIVILIAN DREAM',
                subtitle: 'Build your future. Create your empire.',
                description: 'Every empire starts somewhere. Set up your business, sell your products, meet new people and make your fortune in Velora City.',
                tags: ['Business', 'Shopping', 'Luxury'],
                items: [{ name: 'bodywavewigs', label: 'Body Wave Wigs', count: 25, image: img('bodywavewigs') }, { name: 'pink_messenger_bag', label: 'Pink Messenger Bag', count: 25, image: img('pink_messenger_bag') }],
                money: { cash: 0, bank: 0 },
            },
            {
                key: 'criminal', label: 'Criminal', theme: 'criminal', title: 'THE CRIMINAL UNDERWORLD',
                subtitle: 'Fortune favours the fearless.',
                description: 'Not every fortune is made legally. Start your underground hustle, build connections, take risks and make a name for yourself in Velora.',
                tags: ['Underground', 'Street', 'Hustle'],
                items: [{ name: 'ls_og_kush_bag', label: 'OG Kush Bag', count: 25, image: img('ls_og_kush_bag') }, { name: 'ls_og_kush_seed', label: 'OG Kush Seed', count: 25, image: img('ls_og_kush_seed') }],
                money: { cash: 0, bank: 0 },
            },
        ],
        standard: {
            items: [
                { name: 'phone', label: 'Phone', count: 1, image: img('phone') },
                { name: 'cos_sprunk', label: 'Sprunk', count: 10, image: img('cos_sprunk') },
                { name: 'bbs_double_cheese_goat', label: 'Double Cheese Goat', count: 10, image: img('bbs_double_cheese_goat') },
                { name: 'lockpick', label: 'Lockpick', count: 3, image: img('lockpick') },
                { name: 'pumpkin_patch_card', label: 'Pumpkin Patch Card', count: 1, image: img('pumpkin_patch_card') },
            ],
            vehicles: [{ model: 'issi8', label: 'Weeny Issi Rally', image: 'https://docs.fivem.net/vehicles/issi8.webp', garage: 'Legion Square car park' }],
            money: { cash: 25000, bank: 15000 },
        },
    };

    if (!IN_GAME) {
        document.body.style.background = '#000';
        show(DEV_DATA);
    }
})();
