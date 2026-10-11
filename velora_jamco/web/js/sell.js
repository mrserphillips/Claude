/* Velora Jam Co. — NPC selling & negotiation */
'use strict';

const PITCHES = [
    { id: 'compliment', label: 'Compliment them', line: 'You look like someone with excellent taste.' },
    { id: 'flavour', label: 'Describe the flavour', line: 'Slow-cooked, glossy and bursting with fruit.' },
    { id: 'rarity', label: 'Mention its rarity', line: 'You won\'t find this recipe anywhere else in the state.' },
    { id: 'deal', label: 'Offer a good deal', line: 'For you? I can make this worth your while.' },
    { id: 'quality', label: 'Boast the quality', line: 'Every jar is hand-stirred and perfectly set.' },
];

function avatarSvg(type) {
    const hue = { casual: 330, foodie: 20, bargain: 200, collector: 270, cafe: 40 }[type] ?? 330;
    return `<svg viewBox="0 0 80 80"><circle cx="40" cy="28" r="16" fill="hsl(${hue},25%,62%)"/>
        <path d="M10 80c2-20 14-30 30-30s28 10 30 30z" fill="hsl(${hue},45%,38%)"/>
        <path d="M24 24c2-12 10-16 16-16s14 4 16 16c-4-6-10-8-16-8s-12 2-16 8z" fill="hsl(${hue},30%,22%)"/></svg>`;
}

VJ.apps.sell = (() => {
    let root, cust, jars, offer = null, qty = 1, mood = 55, patience = 0, maxPatience = 0, pitched = false, busy = false, typeTimer = 0;

    function say(text, emote) {
        const b = $('#bubble', root);
        if (!b) return;
        clearInterval(typeTimer);
        b.textContent = '“';
        let i = 0;
        typeTimer = setInterval(() => {
            i++;
            b.textContent = '“' + text.slice(0, i) + (i >= text.length ? '”' : '');
            if (i >= text.length) clearInterval(typeTimer);
        }, 18);
        if (emote) {
            const a = $('.avatar', root);
            $$('.emote', a).forEach((x) => x.remove());
            a.appendChild(el(`<span class="emote">${emote}</span>`));
        }
    }

    function moodUi() {
        const a = $('.avatar', root);
        if (a) a.style.setProperty('--moodc', mood > 65 ? 'rgba(127,220,154,.55)' : mood > 35 ? 'rgba(255,198,107,.5)' : 'rgba(255,107,122,.6)');
        const m = $('#moodBar', root); if (m) m.style.width = `${mood}%`;
        const p = $('#pat', root);
        if (p) p.innerHTML = Array.from({ length: maxPatience }, (_, i) => `<i class="${i < patience ? '' : 'off'}"></i>`).join('');
    }

    function shell() {
        root.innerHTML = `
            <div class="sell-head">
                <div class="avatar">${avatarSvg(cust.type)}</div>
                <div class="grow">
                    <div class="row between"><div><b style="font-family:Cinzel;font-size:1.3em;letter-spacing:.06em">${esc(cust.name)}</b>
                        <div class="muted small">${esc(cust.typeLabel)}${cust.preference ? ` · loves ${esc(cust.preference.toLowerCase())}` : ''}${cust.bulk ? ` · wants ${cust.bulk} jars` : ''}</div></div>
                        <button class="close-btn" data-close title="Walk away (Esc)">✕</button></div>
                    <div class="row" style="margin-top:8px;gap:18px"><div class="mood">Mood <div class="bar"><i id="moodBar" style="width:${mood}%"></i></div></div>
                        <div class="mood">Patience <div class="patience" id="pat"></div></div></div>
                </div>
            </div>
            <div class="bubble" id="bubble"></div>
            <div class="sell-body" id="sellBody"></div>`;
        moodUi();
        say(cust.line, '🙂');
        drawPick();
    }

    function drawPick() {
        const body = $('#sellBody', root);
        if (!jars.length) { body.innerHTML = '<div class="empty">You have no jam left to offer.</div>'; return; }
        body.innerHTML = `<div class="h3">Offer a jar</div><div class="jar-pick">${jars.map((j) => `
            <div class="jar-opt" data-slot="${j.slot}"><img src="${jamImg(j.image)}" alt="">
            <div class="t"><b>${esc(j.label)}</b><br><span style="color:${j.rarityColor}">${esc(j.rarityLabel)}</span> · ${j.quality}%<br><span class="muted">×${j.count}</span></div></div>`).join('')}</div>`;
    }

    function drawOffer() {
        const body = $('#sellBody', root);
        const hi = Math.max(offer + 10, Math.round(offer * 1.6));
        body.innerHTML = `
            <div class="offer"><div><div class="muted small">THEIR OFFER${qty > 1 ? ` · ${qty} JARS` : ''}</div><div class="price" id="price">${money(offer)}</div></div>
                <div class="grow col">
                    <div class="row"><button class="btn" data-a="accept">Accept ${money(offer)}</button><button class="btn ghost" data-a="other">Show another jar</button></div>
                </div></div>
            <div class="divider"></div>
            <div class="h3">Make your pitch ${pitched ? '<span class="muted small">(used)</span>' : ''}</div>
            <div class="pitches">${PITCHES.map((p) => `<button class="btn ghost sm" data-pitch="${p.id}" ${pitched ? 'disabled' : ''}>${p.label}</button>`).join('')}</div>
            <div class="divider"></div>
            <div class="h3">Counteroffer</div>
            <div class="counter"><input type="range" id="cRange" min="${offer}" max="${hi}" value="${Math.round(offer * 1.1)}">
                <input type="number" id="cNum" min="1" max="100000" value="${Math.round(offer * 1.1)}">
                <button class="btn" data-a="counter">Counter</button></div>`;
        const r = $('#cRange', body), n = $('#cNum', body);
        r.addEventListener('input', () => { n.value = r.value; });
        n.addEventListener('input', () => { r.value = n.value; });
    }

    function sold(res) {
        clearInterval(typeTimer);
        SFX.coin();
        root.innerHTML = `<div class="coins">${Array.from({ length: 24 }, (_, i) => `<i style="left:${4 + Math.random() * 92}%;animation-delay:${i * 0.04}s"></i>`).join('')}</div>
            <div class="sold"><div class="h3">Sale Complete</div>
            <div class="cash">+${money(res.price)}</div>
            <p style="margin:8px 0">${res.qty} × ${esc(res.label)}</p>
            <p class="muted" style="font-style:italic">“${esc(res.line)}”</p>
            <p class="small muted" style="margin:10px 0 18px">${res.remaining} jar${res.remaining === 1 ? '' : 's'} left${res.sellingActive ? '' : ' · selling mode ended'}</p>
            <button class="btn big" data-close>Done</button></div>`;
    }

    function ended(text) {
        clearInterval(typeTimer);
        say(text || 'Bye then.', '😤');
        $('#sellBody', root).innerHTML = '<div class="row" style="justify-content:center"><button class="btn ghost" data-close>Leave</button></div>';
    }

    function apply(res) {
        if (typeof res.mood === 'number') mood = res.mood;
        if (typeof res.patience === 'number') patience = res.patience;
        if (typeof res.offer === 'number') offer = res.offer;
        moodUi();
    }

    async function act(name, payload) {
        if (busy) return null;
        busy = true;
        $$('button', root).forEach((b) => { if (!b.hasAttribute('data-close')) b.disabled = true; });
        const res = await post(name, payload);
        busy = false;
        if (!VJ.app || VJ.app !== 'sell') return null;
        $$('button', root).forEach((b) => { b.disabled = false; });
        if (!res) { toast('Selling', 'No response.'); return null; }
        if (res.sold) { sold(res); return null; }
        if (res.ended) { mood = 0; patience = 0; moodUi(); ended(res.line || res.msg); return null; }
        if (!res.ok) { say(res.msg || 'Hmm?', '🤨'); return null; }
        return res;
    }

    async function onClick(e) {
        const t = e.target;
        const slot = t.closest('[data-slot]');
        if (slot) {
            const res = await act('sell:offer', { slot: Number(slot.dataset.slot) });
            if (!res) return;
            qty = res.qty; apply(res);
            say(res.line, '🤔');
            drawOffer();
            return;
        }
        const p = t.closest('[data-pitch]');
        if (p && !pitched) {
            const pitch = PITCHES.find((x) => x.id === p.dataset.pitch);
            say(pitch.line);
            const res = await act('sell:pitch', { pitch: pitch.id });
            if (!res) return;
            pitched = true; apply(res);
            setTimeout(() => { if (VJ.app === 'sell') say(res.line, res.effect === 'good' ? '😍' : res.effect === 'bad' ? '🙄' : '😐'); }, 700);
            if (res.effect === 'good') SFX.perfect(); else if (res.effect === 'bad') SFX.bad();
            drawOffer();
            return;
        }
        const a = t.closest('[data-a]');
        if (!a) return;
        if (a.dataset.a === 'accept') {
            await act('sell:accept');
        } else if (a.dataset.a === 'other') {
            offer = null; drawPick(); say('Alright, what else have you got?', '🙂');
        } else if (a.dataset.a === 'counter') {
            const amount = Number($('#cNum', root).value);
            if (!amount || amount < 1) return;
            const res = await act('sell:counter', { amount });
            if (!res) return;
            apply(res);
            say(res.line, res.reaction === 'insult' ? '😠' : '🤨');
            if (res.reaction === 'insult') SFX.bad();
            drawOffer();
        }
    }

    return {
        open(section, d) {
            root = section; cust = d.customer; jars = d.jars || [];
            offer = null; qty = 1; mood = cust.mood; patience = cust.patience; maxPatience = cust.maxPatience || cust.patience; pitched = false; busy = false;
            shell();
            root.addEventListener('click', onClick);
        },
        close() { clearInterval(typeTimer); if (root) root.removeEventListener('click', onClick); },
    };
})();
