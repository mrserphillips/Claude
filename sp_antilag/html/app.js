// 2-Step panel. Talks to client.lua through NUI callbacks.
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'sp_antilag';
const $ = (id) => document.getElementById(id);
const post = (name, data) => fetch(`https://${RES}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {})
}).catch(() => {});

// localStorage can be missing or throw; positions are only a convenience.
const store = {
    get(k) { try { return JSON.parse(localStorage.getItem(k)); } catch (e) { return null; } },
    set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) {} }
};

let cfg = null;       // uiConfig() from client.lua
let saved = null;     // last saved settings
let draft = null;     // what the panel is editing
let hotbar = [false, false, false];
let testing = false;
let repositioning = false;

const clone = (o) => JSON.parse(JSON.stringify(o));
const INTENSITY_ICONS = { soft: 'fa-arrow-down', moderate: 'fa-gauge', max: 'fa-gauge-high' };

function colourOf(key) {
    if (key && key[0] === '#') return { key, label: key, hex: key };
    return (cfg.colours.find(c => c.key === key)) || cfg.colours[0];
}

function applyTheme() {
    const ui = cfg.ui || {};
    const root = document.documentElement.style;
    if (ui.Accent) {
        root.setProperty('--accent', ui.Accent);
        const n = parseInt(ui.Accent.slice(1), 16);
        const rgb = `${n >> 16 & 255}, ${n >> 8 & 255}, ${n & 255}`;
        root.setProperty('--accent-soft', `rgba(${rgb}, 0.14)`);
        root.setProperty('--accent-line', `rgba(${rgb}, 0.35)`);
    }
    if (ui.AccentGlow) root.setProperty('--accent-glow', ui.AccentGlow);
    if (ui.Title) $('title').textContent = ui.Title;
}

// ---------- building ----------
function buildStatic() {
    const sel = $('soundSelect');
    sel.innerHTML = '';
    cfg.sounds.forEach(s => {
        const o = document.createElement('option');
        o.value = s.key; o.textContent = s.label;
        sel.appendChild(o);
    });
    sel.disabled = !cfg.synth;
    $('soundHint').textContent = cfg.synth ? 'Select to hear preview before saving' : 'Sound types need Config.SoundMode = \'synth\'';

    document.querySelectorAll('[data-seg]').forEach(seg => {
        const field = seg.dataset.seg;
        seg.innerHTML = '';
        cfg.intensity.forEach(it => {
            const b = document.createElement('button');
            b.dataset.value = it.key;
            b.innerHTML = `<i class="fa-solid ${INTENSITY_ICONS[it.key] || 'fa-gauge'}"></i>${it.label.toUpperCase()}`;
            b.onclick = () => { draft[field] = it.key; changed(); };
            seg.appendChild(b);
        });
    });

    const sw = $('swatches');
    sw.innerHTML = '';
    cfg.colours.forEach(c => {
        const d = document.createElement('button');
        d.className = 'swatch' + (c.hex === 'rainbow' ? ' rainbow' : '');
        d.style.setProperty('--c', c.hex);
        d.title = c.label;
        d.dataset.key = c.key;
        d.onclick = () => { draft.colour = c.key; changed(); };
        sw.appendChild(d);
    });

    const rpm = $('rpmSlider');
    rpm.min = cfg.launch.min; rpm.max = cfg.launch.max;
    const size = $('sizeSlider');
    size.min = cfg.size.Min; size.max = cfg.size.Max;

    $('popsRow').classList.toggle('hidden', !cfg.popsEnabled);
    $('gearRow').classList.toggle('hidden', !cfg.gearEnabled);
    $('hotbarHint').textContent = cfg.hotbarKey
        ? `Quick preset switch. Press ${cfg.hotbarKey} (configurable) in the vehicle to open the hotbar, then 1 / 2 / 3. Save the current config to a slot below.`
        : 'Quick preset switch. Save the current config to a slot below.';
}

function summaryHtml(p) {
    if (!p) return '<span>Empty</span>';
    const c = colourOf(p.colour);
    const it = cfg.intensity.find(i => i.key === p.intensity);
    const snd = cfg.sounds.find(s => s.key === p.sound);
    return `<span class="dot" style="--c:${c.hex === 'rainbow' ? '#fff' : c.hex}"></span>${c.label} · ${it ? it.label : ''} · ${snd ? snd.label.replace(/^Antilag \d+ - /, '') : ''}${p.launch ? ' · LC' : ''}`;
}

function renderPresets() {
    const rows = $('presetRows');
    rows.innerHTML = '';
    for (let i = 0; i < 3; i++) {
        const r = document.createElement('div');
        r.className = 'preset-row';
        r.innerHTML = `<span class="name">Preset</span><span class="num">${i + 1}</span>
            <span class="summary">${summaryHtml(hotbar[i])}</span>
            <span class="actions">${hotbar[i] ? '<button class="clear"><i class="fa-solid fa-trash"></i></button>' : ''}
            <button class="save"><i class="fa-solid fa-floppy-disk"></i> Save</button></span>`;
        r.querySelector('.save').onclick = () => {
            hotbar[i] = clone(draft);
            post('save', { settings: saved, hotbar, message: `Saved to preset ${i + 1}.` });
            renderPresets();
        };
        const clear = r.querySelector('.clear');
        if (clear) clear.onclick = () => {
            hotbar[i] = false;
            post('save', { settings: saved, hotbar, message: `Preset ${i + 1} cleared.` });
            renderPresets();
        };
        rows.appendChild(r);
    }
}

// ---------- rendering the draft ----------
function render() {
    document.querySelectorAll('[data-bind]').forEach(el => { el.checked = !!draft[el.dataset.bind]; });
    $('soundSelect').value = draft.sound;
    document.querySelectorAll('[data-seg]').forEach(seg => {
        seg.querySelectorAll('button').forEach(b => b.classList.toggle('active', b.dataset.value === draft[seg.dataset.seg]));
    });
    document.querySelectorAll('.swatch').forEach(s => s.classList.toggle('active', s.dataset.key === draft.colour));
    $('colourName').textContent = colourOf(draft.colour).label.toUpperCase();

    $('rpmSlider').value = draft.launchRpm;
    $('rpmValue').textContent = Math.round(draft.launchRpm * 100) + '%';
    $('sizeSlider').value = draft.size;
    $('sizeValue').textContent = Number(draft.size).toFixed(2) + 'x';
    document.querySelectorAll('[data-pill]').forEach(p => p.classList.toggle('on', !!draft[p.dataset.pill]));

    const lt = $('launchTab');
    lt.classList.toggle('locked', !draft.launch);
    if (!draft.launch && lt.classList.contains('active')) showTab('twostep');

    $('testBtn').classList.toggle('testing', testing);
    $('testBtn').innerHTML = testing ? 'TESTING' : '<i class="fa-solid fa-fire"></i> TEST';
}

function changed() {
    render();
    if (testing) post('updateTest', { draft });
}

// ---------- inputs ----------
document.querySelectorAll('[data-bind]').forEach(el => {
    el.addEventListener('change', () => { draft[el.dataset.bind] = el.checked; changed(); });
});
document.querySelectorAll('[data-pill]').forEach(p => {
    p.onclick = () => { draft[p.dataset.pill] = !draft[p.dataset.pill]; changed(); };
});
$('soundSelect').addEventListener('change', (e) => {
    draft.sound = e.target.value;
    changed();
    previewSound(draft.sound);
});
$('rpmSlider').addEventListener('input', (e) => { draft.launchRpm = parseFloat(e.target.value); changed(); });
$('sizeSlider').addEventListener('input', (e) => { draft.size = parseFloat(e.target.value); changed(); });

function previewSound(key) {
    const prof = cfg.sounds.find(s => s.key === key);
    const vol = Math.min(cfg.volume || 0.9, 1.0) * 0.8;
    [['pop', 0], ['pop', 110], ['bang', 230], ['mega', 520]].forEach(([kind, delay]) => {
        setTimeout(() => playShot(kind, vol, 0, prof), delay);
    });
}

function showTab(name) {
    document.querySelectorAll('.tab').forEach(t => t.classList.toggle('active', t.dataset.tab === name));
    document.querySelectorAll('.page').forEach(p => p.classList.toggle('active', p.dataset.page === name));
}
document.querySelectorAll('.tab').forEach(t => { t.onclick = () => showTab(t.dataset.tab); });

$('saveBtn').onclick = () => {
    saved = clone(draft);
    post('save', { settings: saved, hotbar });
};
$('resetBtn').onclick = () => { draft = clone(saved); changed(); };
$('closeBtn').onclick = () => post('close');

$('testBtn').onclick = () => {
    if (testing) return post('endTest');
    testing = true;
    $('panel').classList.add('testing');
    $('testPrompt').classList.remove('hidden');
    render();
    post('startTest', { draft });
};

function testEnded() {
    testing = false;
    $('panel').classList.remove('testing');
    $('testPrompt').classList.add('hidden');
    if (draft) render();
}

document.addEventListener('keydown', (e) => {
    if ($('panel').classList.contains('hidden')) return;
    if (e.key === 'Backspace' && testing) { e.preventDefault(); post('endTest'); }
    else if (e.key === 'Escape') { if (testing) post('endTest'); else post('close'); }
});

// ---------- dragging (panel + hotbar) ----------
function makeDraggable(el, handle, key, canDrag) {
    handle.addEventListener('mousedown', (e) => {
        if (!canDrag() || e.target.closest('button')) return;
        const r = el.getBoundingClientRect();
        const dx = e.clientX - r.left, dy = e.clientY - r.top;
        el.classList.add('placed');
        const move = (ev) => {
            const x = Math.max(0, Math.min(window.innerWidth - r.width, ev.clientX - dx));
            const y = Math.max(0, Math.min(window.innerHeight - r.height, ev.clientY - dy));
            el.style.left = x + 'px'; el.style.top = y + 'px'; el.style.bottom = 'auto';
        };
        const up = () => {
            document.removeEventListener('mousemove', move);
            document.removeEventListener('mouseup', up);
            store.set(key, { left: el.style.left, top: el.style.top });
        };
        move(e);
        document.addEventListener('mousemove', move);
        document.addEventListener('mouseup', up);
    });
}

function restorePosition(el, key) {
    const p = store.get(key);
    if (p && p.left) {
        el.classList.add('placed');
        el.style.left = p.left; el.style.top = p.top; el.style.bottom = 'auto';
    }
}

makeDraggable($('panel'), $('dragHandle'), 'sp_antilag_panel', () => !testing);
makeDraggable($('hotbar'), $('hotbar'), 'sp_antilag_hotbar', () => repositioning);

$('centerBtn').onclick = () => {
    const p = $('panel');
    p.classList.remove('placed');
    p.style.left = p.style.top = '';
    store.set('sp_antilag_panel', null);
};

// ---------- hotbar ----------
function renderHotbar(presets) {
    const hb = $('hotbar');
    hb.innerHTML = '';
    for (let i = 0; i < 3; i++) {
        const p = presets[i];
        const d = document.createElement('div');
        d.className = 'hb-slot' + (p ? '' : ' empty');
        d.dataset.slot = i + 1;
        let body = '<div class="line">Empty</div>';
        if (p) {
            const c = colourOf(p.colour);
            const it = cfg.intensity.find(x => x.key === p.intensity);
            body = `<div class="line"><span class="dot" style="--c:${c.hex === 'rainbow' ? '#fff' : c.hex}"></span>${c.label}</div>
                    <div class="line">${it ? it.label : ''}${p.launch ? ' · LC' : ''}</div>`;
        }
        d.innerHTML = `<div class="top"><span>PRESET</span><span class="key">${i + 1}</span></div>${body}`;
        hb.appendChild(d);
    }
}

$('repositionBtn').onclick = () => {
    repositioning = !repositioning;
    const hb = $('hotbar');
    $('repositionBtn').querySelector('span').textContent = repositioning ? 'Done' : 'Reposition Hotbar';
    if (repositioning) {
        renderHotbar(hotbar);
        restorePosition(hb, 'sp_antilag_hotbar');
        hb.classList.add('editing');
        hb.classList.remove('hidden');
    } else {
        hb.classList.remove('editing');
        hb.classList.add('hidden');
    }
};

// ---------- messages from client.lua ----------
window.addEventListener('message', (e) => {
    const m = e.data;
    if (!m || !m.action) return;
    switch (m.action) {
        case 'open': {
            cfg = m.config;
            applyTheme();
            buildStatic();
            saved = clone(m.settings);
            draft = clone(m.settings);
            hotbar = (m.hotbar || []).map(h => h || false);
            while (hotbar.length < 3) hotbar.push(false);
            const v = m.vehicle || {};
            $('vName').textContent = (v.name || '-').toUpperCase();
            $('vPlate').textContent = v.plate || '-';
            $('vFuel').textContent = (v.fuel ?? '-') + '%';
            $('vEngine').textContent = (v.engine ?? '-') + '%';
            $('vTurbo').textContent = v.turbo ? 'Yes' : 'No';
            renderPresets();
            showTab('twostep');
            testEnded();
            restorePosition($('panel'), 'sp_antilag_panel');
            $('panel').classList.remove('hidden');
            render();
            break;
        }
        case 'close':
            testEnded();
            if (repositioning) $('repositionBtn').click();
            $('panel').classList.add('hidden');
            break;
        case 'testEnded':
            testEnded();
            break;
        case 'testDevice':
            $('kHold').textContent = m.keyboard ? 'SPACE' : 'RB';
            $('kGas').textContent = m.keyboard ? 'W' : 'RT';
            $('kExit').textContent = m.keyboard ? 'BACKSPACE' : 'B';
            break;
        case 'hotbar':
            if (repositioning) break;
            if (m.show) {
                cfg = m.config || cfg;
                applyTheme();
                renderHotbar(m.presets || []);
                restorePosition($('hotbar'), 'sp_antilag_hotbar');
                $('hotbar').classList.remove('hidden');
            } else {
                $('hotbar').classList.add('hidden');
            }
            break;
        case 'hotbarPick':
            document.querySelectorAll('.hb-slot').forEach(s => s.classList.toggle('picked', Number(s.dataset.slot) === m.slot));
            break;
    }
});
