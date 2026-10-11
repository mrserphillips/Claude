/* Velora Jam Co. — jam kitchen: mixing, recipe book, cooling rack and the crafting flow */
'use strict';

const STAGE_INFO = [
    { id: 'prepare', label: 'Prepare', icon: '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M4 20 18 6l2 2L6 22z"/><path d="M14 4l6 6"/></svg>' },
    { id: 'heat', label: 'Cook', icon: '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 2c3 4 6 6 6 11a6 6 0 0 1-12 0c0-3 2-5 3-7 1 2 2 3 3 3 0-3-1-5 0-7z"/></svg>' },
    { id: 'stir', label: 'Stir', icon: '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="9" cy="15" r="5"/><path d="M12 12l8-8"/></svg>' },
    { id: 'fill', label: 'Jar', icon: '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="6" y="7" width="12" height="14" rx="3"/><path d="M7 4h10v3H7z"/></svg>' },
    { id: 'seal', label: 'Seal', icon: '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.8"><ellipse cx="12" cy="9" rx="8" ry="3"/><path d="M4 9v4c0 2 4 3 8 3s8-1 8-3V9"/></svg>' },
    { id: 'complete', label: 'Complete', icon: '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M5 12l5 5 9-10"/></svg>' },
];

VJ.apps.kitchen = (() => {
    let root, data, tab = 'mix', mix, preview = null, previewTimer = null, previewSeq = 0;
    let craft = null;       // active batch { res, stageIndex, game }
    let busy = false;

    const counts = () => data.counts || {};
    const fruitById = (id) => data.fruits.find((f) => f.id === id);
    const specialById = (id) => data.specials.find((s) => s.id === id);

    function shell() {
        root.innerHTML = `${corners()}
            <div class="panel-head">
                <img class="logo" src="images/ui/logo.png" alt="">
                <div class="titles"><h1>MAKE JAM</h1><div class="sub">Turn your fresh fruit into something special · ${esc(data.kitchen || '')}</div></div>
                <button class="close-btn" data-close title="Close (Esc)">✕</button>
            </div>
            <div class="tabs" id="kTabs">
                ${[['mix', 'Mix Fruits'], ['book', 'Recipe Book'], ['rack', `Cooling Rack${data.rack && data.rack.length ? ` (${data.rack.length})` : ''}`], ['ach', 'Achievements']]
                    .map(([id, l]) => `<button class="tab ${tab === id ? 'active' : ''}" data-tab="${id}">${l}</button>`).join('')}
            </div>
            <div class="panel-body"><div class="view" id="kView"></div></div>`;
        draw();
    }

    function draw() {
        const v = $('#kView', root);
        if (!v) return;
        $$('[data-tab]', root).forEach((b) => b.classList.toggle('active', b.dataset.tab === tab));
        if (tab === 'mix') return drawMix(v);
        if (tab === 'book') return Book.render(v, data.book);
        if (tab === 'rack') return drawRack(v);
        if (tab === 'ach') v.innerHTML = `${Book.stats(data.stats)}<div class="divider"></div>${Book.achievements(data.achievements)}`;
    }

    /* ── Mixing ───────────────────────────────────────────────────────── */
    function maxJars() {
        if (!mix.fruits.length) return data.rules.maxJars;
        const per = data.rules.fruitPerJar[String(mix.fruits.length)] || 2;
        let m = data.rules.maxJars;
        mix.fruits.forEach((id) => { m = Math.min(m, Math.floor((counts()[fruitById(id).item] || 0) / per)); });
        return Math.max(1, m);
    }

    function drawMix(v) {
        const c = counts();
        const bowlItem = data.supplies.bowl.item;
        const tile = (x, kind) => {
            const n = c[x.item] || 0;
            const sel = kind === 'fruit' ? mix.fruits.includes(x.id) : mix.special === x.id;
            return `<div class="item-tile clickable ${n ? '' : 'zero'} ${sel ? 'selected' : ''}" data-${kind}="${x.id}"><span class="count">${n}</span><img src="${itemImg(x.item)}" alt=""><div class="name">${esc(x.label)}</div></div>`;
        };
        const slot = (i) => {
            const id = mix.fruits[i];
            if (!id) return `<div class="slot"><span class="ph">+</span><span class="lbl muted">Fruit ${i + 1}</span></div>`;
            const f = fruitById(id);
            return `<div class="slot filled"><button class="x" data-rm="${i}">✕</button><img src="${itemImg(f.item)}" alt=""><span class="lbl">${esc(f.label)}</span></div>`;
        };
        const sp = mix.special ? specialById(mix.special) : null;
        v.innerHTML = `<div class="kitchen-mix">
            <div class="pantry scroll">
                <div class="h3">Your Fruit</div><div class="grid">${data.fruits.map((f) => tile(f, 'fruit')).join('')}</div>
                <div class="h3" style="margin-top:14px">Special Touch</div><div class="grid">${data.specials.map((s) => tile(s, 'special')).join('')}</div>
            </div>
            <div class="mixer">
                <div class="h2" style="text-align:center">MIX FRUITS</div>
                <div class="muted small" style="margin-top:-12px">Try different combinations to discover unique jams</div>
                <div class="slots">
                    ${slot(0)}<span class="op">+</span>${slot(1)}<span class="op">+</span>${slot(2)}
                    <span class="op">+</span>
                    ${sp ? `<div class="slot filled special"><button class="x" data-rm="special">✕</button><img src="${itemImg(sp.item)}" alt=""><span class="lbl">${esc(sp.label)}</span></div>`
                        : '<div class="slot special"><span class="ph">✦</span><span class="lbl muted">Special</span></div>'}
                    <span class="op">→</span>
                    <div class="slot result-slot" id="resultSlot"><img src="${jamImg('jar_mystery')}" alt=""><span class="lbl">?</span></div>
                </div>
                <div class="preview-text" id="previewText"><span class="muted">Add fruit to begin.</span></div>
                <div class="batch">
                    <span class="h3" style="margin:0">Batch</span>
                    <div class="stepper"><button data-jars="-1">−</button><span id="jarCount">${mix.jars}</span><button data-jars="1">+</button></div>
                    <span class="muted small">jar${mix.jars > 1 ? 's' : ''}</span>
                    <div class="toggle ${mix.pectin ? 'on' : ''}" data-pectin style="margin-left:14px"><div class="sw"></div><div class="small">Pectin <span class="muted">(${c[data.supplies.pectin.item] || 0}) +${data.rules.pectinBonus}% quality</span></div></div>
                </div>
                <div class="reqs" id="reqs"></div>
                ${data.rules.requireBowl && !(c[bowlItem] > 0) ? '<div class="bad small">You need a Mixing Bowl — buy one from Rosalind\'s pantry.</div>' : ''}
                <button class="btn big" id="createBtn" disabled>Create Jam</button>
            </div>
            <div class="outcomes">
                <div class="parchment">
                    <div class="h3">→ Possible Outcomes ←</div>
                    <div class="tiers">${['common', 'uncommon', 'rare', 'epic', 'legendary'].map((r) => `<div><img src="images/ui/tier_${r}.png" alt=""><div style="color:${r === 'legendary' ? '#9a6a10' : '#5a2a3a'}">${rarityOf(r).label}</div></div>`).join('')}
                        <div><img src="${jamImg('jar_mystery')}" alt=""><div>Experimental</div></div></div>
                    <div class="note">The more you experiment, the more recipes you'll discover!</div>
                </div>
                <div class="card" style="margin-top:14px">
                    <div class="h3">Kitchen Notes</div>
                    <div class="small muted">Single fruit: ${data.rules.fruitPerJar['1']} per jar · Two fruits: ${data.rules.fruitPerJar['2']} each · Three fruits: ${data.rules.fruitPerJar['3']} each.<br>Every jar needs sugar, an empty jar and a lid. Special ingredients are used once per batch.</div>
                </div>
            </div>
        </div>`;
        requestPreview();
    }

    function requestPreview() {
        clearTimeout(previewTimer);
        if (!mix.fruits.length) { preview = null; renderPreview(); return; }
        previewTimer = setTimeout(async () => {
            const seq = ++previewSeq;
            const res = await server('kitchen:preview', { fruits: mix.fruits, special: mix.special, jars: mix.jars, pectin: mix.pectin });
            if (seq !== previewSeq || !VJ.app || tab !== 'mix' || craft) return;
            preview = res && res.ok ? res : null;
            renderPreview();
        }, 180);
    }

    function renderPreview() {
        const slotEl = $('#resultSlot', root), text = $('#previewText', root), reqs = $('#reqs', root), btn = $('#createBtn', root);
        if (!slotEl) return;
        slotEl.classList.remove('mystery', 'promising');
        if (!preview) {
            slotEl.innerHTML = `<img src="${jamImg('jar_mystery')}" alt=""><span class="lbl">?</span>`;
            text.innerHTML = '<span class="muted">Add fruit to begin.</span>';
            reqs.innerHTML = '';
            btn.disabled = true;
            return;
        }
        const pv = preview.preview;
        if (pv.known) {
            slotEl.innerHTML = `<img src="${jamImg(pv.image)}" alt=""><span class="lbl">${pill(pv.rarity)}</span>`;
            text.innerHTML = `<div class="nm">${esc(pv.label)}</div><div class="muted small">Best quality so far: ${pv.best}%</div>`;
        } else {
            slotEl.classList.add('mystery');
            if (pv.promising) slotEl.classList.add('promising');
            slotEl.innerHTML = `<img src="${jamImg('jar_mystery')}" alt=""><span class="lbl">???</span>`;
            text.innerHTML = pv.promising ? '<div class="pink">Something sweet stirs... an undiscovered recipe?</div><div class="muted small">Only one way to find out.</div>'
                : '<div class="muted">An unusual blend. This may become an experimental preserve.</div>';
        }
        let ok = true;
        reqs.innerHTML = preview.requirements.map((r) => {
            const enough = r.have >= r.count;
            if (!enough) ok = false;
            return `<div class="r ${enough ? 'ok' : 'no'}"><span>${esc(r.label)}</span><b>${r.have}/${r.count}</b></div>`;
        }).join('');
        const c = counts();
        if (data.rules.requireBowl && !(c[data.supplies.bowl.item] > 0)) ok = false;
        btn.disabled = !ok || busy;
    }

    function drawRack(v) {
        const rack = data.rack || [];
        v.innerHTML = `<div class="h2">Cooling Rack</div><p class="muted small" style="margin-bottom:14px">Jars that didn't fit in your pockets wait here safely until you collect them.</p>
            ${rack.length ? `<div class="col">${rack.map((r) => `<div class="card rack-item"><img src="${itemImg('velora_jam')}" style="width:56px;height:56px" alt="">
                <div class="grow"><b>${esc(r.label)}</b><div class="muted small">${r.count} item${r.count === 1 ? '' : 's'}</div></div>
                <button class="btn sm" data-collect="${r.id}">Collect</button></div>`).join('')}</div>` : '<div class="empty">The cooling rack is empty.</div>'}`;
    }

    async function refresh() {
        const fresh = await server('kitchen:getData');
        if (fresh && !fresh.error) {
            Object.assign(data, fresh);
            mix.fruits = mix.fruits.filter((id) => fruitById(id));
        }
    }

    /* ── Crafting flow ────────────────────────────────────────────────── */
    function stagesBar(active, doneUntil) {
        return `<div class="stages">${STAGE_INFO.map((s, i) => `${i ? `<div class="stage-link ${i <= doneUntil ? 'done' : ''}"></div>` : ''}
            <div class="stage ${i < doneUntil ? 'done' : ''} ${i === active ? 'active' : ''}"><div class="dot">${s.icon}</div>${s.label}</div>`).join('')}</div>`;
    }

    function startCraftView(res) {
        craft = { res, stageIndex: 0, game: null, done: false };
        const v = $('#kView', root);
        $('#kTabs', root).classList.add('hidden');
        v.innerHTML = `<div class="craft">
            <div class="row between"><div id="stagesBar" class="grow">${stagesBar(0, 0)}</div>
            <button class="btn ghost sm" id="abandon">Abandon batch</button></div>
            <div class="craft-stage" id="stageHost"></div></div>`;
        runStage();
    }

    function runStage() {
        if (!craft) return;
        const stage = craft.res.stages[craft.stageIndex];
        $('#stagesBar', root).innerHTML = stagesBar(craft.stageIndex, craft.stageIndex);
        const host = $('#stageHost', root);
        host.innerHTML = '';
        const tut = TUTORIALS[stage];
        const tutEl = el(`<div class="tutorial"><div class="card gold-edge">
            <div class="muted small" style="letter-spacing:.3em">STEP ${craft.stageIndex + 1} OF ${craft.res.stages.length}</div>
            <div class="h2">${esc(tut.title)}</div>
            <ul>${tut.steps.map((s) => `<li>${s}</li>`).join('')}</ul>
            <button class="btn big" data-begin>Begin</button><div class="muted small" style="margin-top:8px">or press <span class="kbd">Enter</span></div></div></div>`);
        host.appendChild(tutEl);
        craft.waiting = true;
        const begin = () => {
            if (!craft || !craft.waiting) return;
            craft.waiting = false;
            tutEl.remove();
            const info = { fruits: craft.res.fruits, special: craft.res.special, jars: craft.res.jars };
            craft.game = Minigames[stage](host, craft.res.params[stage], info, (result) => submitStage(stage, result));
        };
        craft.begin = begin;
        $('[data-begin]', tutEl).addEventListener('click', begin);
    }

    async function submitStage(stage, result) {
        if (!craft || craft.submitting) return;
        craft.submitting = true;
        const res = await post('kitchen:stage', { stage, data: result });
        if (!craft || !VJ.app) return;
        craft.submitting = false;
        if (craft.game) { craft.game.destroy(); craft.game = null; }
        const host = $('#stageHost', root);
        if (!res || !res.ok) {
            if (res && res.ended) return endCraft(res.msg || 'The batch was ruined.');
            toast('Kitchen', (res && res.msg) || 'Could not verify that step.');
            return runStage();
        }
        const label = res.score >= 95 ? 'PERFECT' : res.score >= 80 ? 'EXCELLENT' : res.score >= 60 ? 'GOOD' : res.score >= 40 ? 'OKAY' : 'ROUGH';
        host.appendChild(el(`<div class="score-pop"><div class="big">${res.score}%</div><div class="lbl">${label}${res.burned ? ' · SCORCHED' : ''}${res.wasted ? ' · SPILLED' : ''}</div></div>`));
        if (res.score >= 80) SFX.perfect(); else SFX.click();
        setTimeout(() => {
            if (!craft || !VJ.app) return;
            if (res.finished) return finishCraft(res.finished);
            craft.stageIndex++;
            runStage();
        }, 1300);
    }

    function finishCraft(result) {
        if (!result.ok) return endCraft(result.msg || 'Something went wrong.');
        craft.done = true;
        $('#stagesBar', root).innerHTML = stagesBar(5, 6);
        const show = () => showResult(result);
        if (result.isNew) showReveal(result.recipe, show);
        else show();
    }

    function showResult(r) {
        const host = $('#stageHost', root);
        if (!host) return;
        const rr = rarityOf(r.recipe.rarity);
        const base = Math.round(r.value / Math.max(0.01, (data.tiers.find((t) => t.label === r.tier.label) || { mult: 1 }).mult));
        host.innerHTML = `<div class="result">
            <div class="jar"><img src="${jamImg(r.recipe.image)}" alt=""></div>
            <div>
                <div class="title">JAR YOUR JAM</div><div class="done">Completed!</div>
                <div class="h2" style="font-family:GreatVibes;font-size:2.2em;letter-spacing:0;text-transform:none">${esc(r.recipe.label)}</div>
                <div class="row" style="margin:6px 0 10px"><span class="pill" style="color:${rr.color}">${rr.label}</span><span class="pill" style="color:${r.tier.color}">${esc(r.tier.label)}</span><span class="muted small">${r.jars} jar${r.jars > 1 ? 's' : ''} · Batch ${esc(r.batch)}</span></div>
                <div class="scores">${STAGE_INFO.slice(0, 5).map((s) => `<div><b>${r.scores[s.id] ?? 0}</b>${s.label}</div>`).join('')}</div>
                <div class="card ledger">
                    <div class="r"><span>Base value</span><b>${money(base)}</b></div>
                    <div class="r"><span>Quality (${r.quality}%)</span><b>×${(r.value / Math.max(1, base)).toFixed(2)}</b></div>
                    <div class="r total"><span>Est. value per jar</span><b>${money(r.value)}</b></div>
                </div>
                ${r.notes && r.notes.length ? `<div class="small muted" style="margin-top:8px">${r.notes.map(esc).join('<br>')}</div>` : ''}
                ${r.rack ? '<div class="small bad" style="margin-top:6px">Your pockets were full — the jars are on the cooling rack.</div>' : ''}
                <div class="row" style="margin-top:16px"><button class="btn big" id="continueBtn">Continue</button></div>
            </div></div>`;
        SFX.chime();
        $('#continueBtn', host).addEventListener('click', async () => {
            craft = null;
            await refresh();
            $('#kTabs', root).classList.remove('hidden');
            shell();
        });
    }

    async function endCraft(msg) {
        if (craft && craft.game) craft.game.destroy();
        craft = null;
        toast('Kitchen', msg);
        await refresh();
        if (!VJ.app) return;
        shell();
    }

    /* ── Events ───────────────────────────────────────────────────────── */
    async function onClick(e) {
        const t = e.target;
        if (craft) {
            if (t.closest('#abandon')) {
                const yes = await confirmBox(root, craft.stageIndex === 0 ? 'Abandon this batch? Your ingredients will be returned.' : 'Abandon this batch? The fruit and sugar are already cooking — only unused jars and lids come back.', 'Abandon', 'Keep cooking');
                if (yes && craft) {
                    if (craft.game) craft.game.destroy();
                    craft = null;
                    await post('kitchen:cancel');
                    await refresh();
                    if (VJ.app) shell();
                }
            }
            return;
        }
        const tabBtn = t.closest('[data-tab]');
        if (tabBtn) { tab = tabBtn.dataset.tab; SFX.click(); return draw(); }
        const f = t.closest('[data-fruit]');
        if (f) {
            const id = f.dataset.fruit;
            if (mix.fruits.includes(id)) mix.fruits = mix.fruits.filter((x) => x !== id);
            else if (mix.fruits.length < 3) { mix.fruits.push(id); SFX.pop(); }
            else return SFX.bad();
            mix.jars = Math.min(mix.jars, maxJars());
            return drawMix($('#kView', root));
        }
        const s = t.closest('[data-special]');
        if (s) { mix.special = mix.special === s.dataset.special ? null : s.dataset.special; SFX.pop(); return drawMix($('#kView', root)); }
        const rm = t.closest('[data-rm]');
        if (rm) {
            if (rm.dataset.rm === 'special') mix.special = null;
            else mix.fruits.splice(Number(rm.dataset.rm), 1);
            return drawMix($('#kView', root));
        }
        const j = t.closest('[data-jars]');
        if (j) {
            mix.jars = clamp(mix.jars + Number(j.dataset.jars), 1, data.rules.maxJars);
            $('#jarCount', root).textContent = mix.jars;
            SFX.click();
            return requestPreview();
        }
        if (t.closest('[data-pectin]')) { mix.pectin = !mix.pectin; t.closest('[data-pectin]').classList.toggle('on', mix.pectin); return requestPreview(); }
        const col = t.closest('[data-collect]');
        if (col && !busy) {
            busy = true; col.disabled = true;
            const res = await server('kitchen:collect', Number(col.dataset.collect));
            busy = false;
            if (res) { toast('Cooling Rack', res.msg || ''); data.rack = res.rack || []; await refresh(); shell(); }
            return;
        }
        if (t.closest('#createBtn') && !busy) {
            busy = true;
            const btn = $('#createBtn', root); btn.disabled = true; btn.textContent = 'Preparing...';
            const res = await post('kitchen:start', { fruits: mix.fruits, special: mix.special, jars: mix.jars, pectin: mix.pectin });
            busy = false;
            if (!VJ.app) return;
            if (res && res.ok) { SFX.chime(); startCraftView(res); }
            else { toast('Kitchen', (res && res.msg) || 'Could not start the batch.'); btn.textContent = 'Create Jam'; renderPreview(); }
        }
    }

    return {
        open(section, d) {
            root = section; data = d; tab = 'mix'; craft = null; busy = false; preview = null;
            mix = { fruits: [], special: null, jars: 1, pectin: false };
            shell();
            root.addEventListener('click', onClick);
        },
        key(e, down) {
            if (!craft) return;
            if (craft.waiting && down && (e.code === 'Enter' || e.code === 'Space')) { e.preventDefault(); craft.begin(); return; }
            if (craft.game && craft.game.key) craft.game.key(e, down);
        },
        close() {
            clearTimeout(previewTimer);
            if (craft && craft.game) craft.game.destroy();
            craft = null;
            if (root) root.removeEventListener('click', onClick);
        },
    };
})();
