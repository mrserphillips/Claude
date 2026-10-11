/* Velora Jam Co. — business office (Rosalind's menu) */
'use strict';

const ICONS = {
    shift: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M3 17h2l1-5h9l3 5h3v-3l-3-5H6"/><circle cx="7" cy="18" r="2"/><circle cx="17" cy="18" r="2"/></svg>',
    orchard: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><circle cx="12" cy="9" r="6"/><path d="M12 15v7M8 22h8"/><circle cx="10" cy="8" r="1"/><circle cx="14" cy="10" r="1"/></svg>',
    pantry: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M4 7h16l-1.5 13h-13z"/><path d="M8 7a4 4 0 0 1 8 0"/></svg>',
    book: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M4 4h7a3 3 0 0 1 3 3v13a2 2 0 0 0-2-2H4z"/><path d="M20 4h-4a3 3 0 0 0-2 1"/><path d="M20 4v14h-6"/></svg>',
    stats: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/></svg>',
    shop: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M3 9l2-5h14l2 5M4 9v11h16V9M3 9h18"/><path d="M9 20v-6h6v6"/></svg>',
};

function vanSvg(colour, accent, variant) {
    const roof = [18, 26, 22][variant % 3];
    return `<svg viewBox="0 0 220 110" xmlns="http://www.w3.org/2000/svg">
        <ellipse cx="110" cy="100" rx="96" ry="6" fill="rgba(0,0,0,.45)"/>
        <path d="M14 84 V${roof + 14} Q14 ${roof} 30 ${roof} H140 Q156 ${roof} 166 ${roof + 18} L196 56 Q206 60 206 72 V84 Z" fill="${colour}" stroke="rgba(255,255,255,.25)" stroke-width="1.5"/>
        <path d="M150 ${roof + 8} H162 L184 56 H150 Z" fill="rgba(180,210,240,.55)"/>
        <rect x="30" y="${roof + 8}" width="104" height="${46 - roof / 2}" rx="5" fill="rgba(0,0,0,.18)"/>
        <path d="M14 70 H206" stroke="${accent}" stroke-width="5"/>
        <text x="74" y="${roof + 34}" font-family="GreatVibes" font-size="22" fill="${accent}" text-anchor="middle">Velora</text>
        <circle cx="52" cy="86" r="14" fill="#151015" stroke="#555" stroke-width="3"/><circle cx="52" cy="86" r="5" fill="#999"/>
        <circle cx="168" cy="86" r="14" fill="#151015" stroke="#555" stroke-width="3"/><circle cx="168" cy="86" r="5" fill="#999"/>
        <rect x="198" y="64" width="8" height="5" rx="2" fill="#ffe9a8"/>
    </svg>`;
}

VJ.apps.business = (() => {
    let root, data, tab = 'shift', vanChoice = { van: true, model: 1, colour: 1 }, timer = null, busy = false;

    function shell() {
        root.innerHTML = `${corners()}
            <div class="panel-head">
                <img class="logo" src="images/ui/logo.png" alt="">
                <div class="titles"><h1>${esc(data.businessName || 'Velora Jam Co.')}</h1>
                <div class="sub">${esc(data.npcName)} · Proprietor &amp; head jam-maker</div></div>
                ${data.shop ? `<button class="btn gold sm" data-act="shop">${ICONS.shop.replace('<svg', '<svg width="16" height="16"')} Pantry Supplier</button>` : ''}
                <button class="close-btn" data-close title="Close (Esc)">✕</button>
            </div>
            <div class="panel-body">
                <nav class="side-nav">
                    ${[['shift', 'Shift & Van'], ['orchard', 'Orchards'], ['pantry', 'Ingredients'], ['book', 'Recipe Book'], ['stats', 'Statistics']]
                        .map(([id, l]) => `<button class="tab ${tab === id ? 'active' : ''}" data-tab="${id}">${ICONS[id]}<span>${l}</span></button>`).join('')}
                    <div class="spacer"></div>
                    <div class="muted small" style="padding:8px">No job required — everyone is welcome in Rosalind's kitchen.</div>
                </nav>
                <div class="view"></div>
            </div>`;
        draw();
    }

    function view() { return $('.view', root); }

    function draw() {
        clearInterval(timer);
        $$('[data-tab]', root).forEach((b) => b.classList.toggle('active', b.dataset.tab === tab));
        const v = view();
        if (tab === 'shift') return drawShift(v);
        if (tab === 'orchard') return drawOrchards(v);
        if (tab === 'pantry') return drawPantry(v);
        if (tab === 'book') return Book.render(v, data.book);
        if (tab === 'stats') {
            v.innerHTML = `<div class="h2">Your Jam Journey</div><p class="npc-quote">“Every jar tells a story, darling. Here's yours.”</p>
                ${Book.stats(data.stats)}<div class="divider"></div><div class="h3">Achievements</div>${Book.achievements(data.achievements)}`;
        }
    }

    function fmtTime(sec) {
        const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
        return (h ? h + ':' : '') + String(m).padStart(2, '0') + ':' + String(s).padStart(2, '0');
    }

    function drawShift(v) {
        const s = data.shift;
        if (s) {
            let elapsed = s.elapsed;
            const van = s.van;
            v.innerHTML = `<div class="h2">You're on shift</div>
                <p class="npc-quote">“Pick the ripest fruit, mind the rotten ones, and bring it all back to my stove.”</p>
                <div class="card gold-edge shift-banner"><div><div class="muted small">SHIFT TIME</div><div class="clock" id="clock">${fmtTime(elapsed)}</div></div>
                    <div class="grow">${van ? `
                        <div class="row between"><b>${esc(van.model)}</b><span class="pill" style="color:var(--gold-2)">${esc(van.plate)}</span></div>
                        ${van.exists ? `<div class="small muted" style="margin-top:8px">Body</div><div class="bar"><i style="width:${van.body}%"></i></div>
                        <div class="small muted" style="margin-top:6px">Engine</div><div class="bar"><i style="width:${van.engine}%"></i></div>
                        <div class="small" style="margin-top:8px">${van.nearby ? '<span class="good">Van is parked at the depot.</span>' : '<span class="bad">Van is not at the depot.</span>'}</div>`
                        : '<div class="bad small" style="margin-top:8px">Your van could not be found.</div>'}
                        <div class="small muted" style="margin-top:4px">Deposit held: ${money(s.deposit)}</div>` : '<div class="muted">Working on foot — no van hired.</div>'}
                    </div></div>
                <div class="row" style="margin-top:20px;gap:12px"><button class="btn big" data-act="end">End Shift${van ? ' & Return Van' : ''}</button></div>`;
            timer = setInterval(() => { elapsed++; const c = $('#clock', root); if (c) c.textContent = fmtTime(elapsed); }, 1000);
            return;
        }
        v.innerHTML = `<div class="h2">Start a Jam-Making Shift</div>
            <p class="npc-quote">“Fancy helping out, sweetheart? Take one of my vans to the Grapeseed orchard and bring me the best fruit you can find.”</p>
            <div class="toggle ${vanChoice.van || data.vanRequired ? 'on' : ''}" data-act="toggleVan"><div class="sw"></div>
                <div><b>Hire a company van</b><div class="muted small">${data.deposit > 0 ? `${money(data.deposit)} deposit from your ${esc(data.depositAccount)} account — refunded when returned undamaged.` : 'No deposit required.'}${data.vanRequired ? ' (required)' : ''}</div></div></div>
            <div class="${vanChoice.van || data.vanRequired ? '' : 'hidden'}" id="vanOpts">
                <div class="h3" style="margin-top:18px">Choose your van</div>
                <div class="grid c3" id="vans"></div>
                <div class="h3" style="margin-top:18px">Livery colour</div>
                <div class="swatches" id="swatches"></div>
            </div>
            <div class="row" style="margin-top:22px"><button class="btn big" data-act="start">Start Shift</button><span class="muted small" id="shiftMsg"></span></div>`;
        drawVans();
    }

    function drawVans() {
        const vans = $('#vans', root), sw = $('#swatches', root);
        if (!vans) return;
        const col = data.colours[vanChoice.colour - 1] || data.colours[0];
        vans.innerHTML = data.vans.map((m, i) => `<div class="card van-card ${vanChoice.model === i + 1 ? 'selected' : ''}" data-model="${i + 1}">
            ${vanSvg(col.swatch, col.accent, i)}<b>${esc(m.label)}</b><div class="muted small">${esc(m.description || '')}</div></div>`).join('');
        sw.innerHTML = data.colours.map((c, i) => `<div class="swatch ${vanChoice.colour === i + 1 ? 'selected' : ''}" data-colour="${i + 1}" title="${esc(c.label)}" style="background:${c.swatch};--acc:${c.accent}"></div>`).join('')
            + `<span class="muted small" style="align-self:center">${esc(col.label)}</span>`;
    }

    function drawOrchards(v) {
        v.innerHTML = `<div class="h2">Orchards</div><p class="npc-quote">“The Grapeseed groves off Seaview Road have the sweetest fruit in the county.”</p>
            <div class="grid c2">${data.orchards.map((o) => `<div class="card orchard-card gold-edge">
                <div class="row between"><b style="font-family:Cinzel;letter-spacing:.06em">${esc(o.label)}</b><span class="muted small">${(o.distance / 1000).toFixed(1)} km</span></div>
                <div class="muted small">${esc(o.description || '')}</div>
                <div class="fruits">${o.fruits.map((f) => `<img src="${itemImg(f.item)}" title="${esc(f.label)}" alt="">`).join('')}</div>
                <div class="row between"><span class="small muted">${o.trees} harvest spots</span><button class="btn sm" data-wp="${o.x},${o.y}">Set Waypoint</button></div>
            </div>`).join('')}</div>`;
    }

    function tiles(order, cfg) {
        return order.map((id) => {
            const c = cfg[id];
            const n = data.counts[c.item] || 0;
            return `<div class="item-tile ${n ? '' : 'zero'}"><span class="count">${n}</span><img src="${itemImg(c.item)}" alt=""><div class="name">${esc(c.label)}</div></div>`;
        }).join('');
    }

    function drawPantry(v) {
        const supplyOrder = Object.keys(data.supplies);
        v.innerHTML = `<div class="h2">Your Ingredients</div><p class="muted small" style="margin-bottom:14px">What you are carrying right now.</p>
            <div class="h3">Fruit</div><div class="grid auto">${tiles(data.fruitOrder, data.fruitsCfg)}</div>
            <div class="h3" style="margin-top:18px">Special Ingredients</div><div class="grid auto">${tiles(data.specialOrder, data.specialsCfg)}</div>
            <div class="h3" style="margin-top:18px">Supplies</div><div class="grid auto">${tiles(supplyOrder, data.supplies)}</div>`;
    }

    async function refresh() {
        const fresh = await server('business:getData');
        if (fresh) Object.assign(data, fresh);
    }

    async function onClick(e) {
        const t = e.target;
        const tabBtn = t.closest('[data-tab]');
        if (tabBtn) { tab = tabBtn.dataset.tab; SFX.click(); return draw(); }
        const m = t.closest('[data-model]');
        if (m) { vanChoice.model = Number(m.dataset.model); SFX.click(); return drawVans(); }
        const c = t.closest('[data-colour]');
        if (c) { vanChoice.colour = Number(c.dataset.colour); SFX.click(); return drawVans(); }
        const wp = t.closest('[data-wp]');
        if (wp) { const [x, y] = wp.dataset.wp.split(',').map(Number); post('business:waypoint', { x, y }); SFX.chime(); return; }
        const act = t.closest('[data-act]');
        if (!act || busy) return;
        const a = act.dataset.act;
        if (a === 'toggleVan' && !data.vanRequired) {
            vanChoice.van = !vanChoice.van;
            act.classList.toggle('on', vanChoice.van);
            $('#vanOpts', root).classList.toggle('hidden', !vanChoice.van);
        } else if (a === 'shop') {
            post('business:shop');
        } else if (a === 'start') {
            busy = true; act.disabled = true;
            const res = await post('business:startShift', { van: vanChoice.van || data.vanRequired, model: vanChoice.model, colour: vanChoice.colour });
            busy = false;
            if (!VJ.app) return;
            if (res && res.ok) {
                SFX.chime();
                await refresh();
                draw();
            } else {
                act.disabled = false;
                const msg = $('#shiftMsg', root); if (msg) msg.innerHTML = `<span class="bad">${esc(res && res.msg || 'Could not start shift.')}</span>`;
                SFX.bad();
            }
        } else if (a === 'end') {
            busy = true; act.disabled = true;
            let res = await post('business:endShift', {});
            if (res && res.needForfeit && VJ.app) {
                const yes = await confirmBox(root, res.msg, 'End shift', 'Keep working');
                res = yes ? await post('business:endShift', { forfeit: true }) : null;
            }
            busy = false;
            if (!VJ.app) return;
            act.disabled = false;
            if (res && res.ok) { await refresh(); data.shift = null; draw(); }
            else if (res && res.msg) { toast('Velora Jam Co.', res.msg); }
        }
    }

    return {
        open(section, d) {
            root = section; data = d; tab = d.shift ? 'shift' : 'shift';
            vanChoice = { van: true, model: 1, colour: 1 };
            shell();
            root.addEventListener('click', onClick);
        },
        close() { clearInterval(timer); if (root) root.removeEventListener('click', onClick); },
    };
})();
