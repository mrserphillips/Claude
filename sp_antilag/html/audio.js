// Synthesised exhaust pops / bangs. Nothing is prerecorded: every shot is built from
// noise + a sub "thump" with slight randomisation so no two hits sound identical.
let ctx = null, master = null, noise = null, shaper = null, hardShaper = null;
const reverbs = {};

function makeCurve(k) {
    const n = 2048, curve = new Float32Array(n);
    for (let i = 0; i < n; i++) { const x = i / (n - 1) * 2 - 1; curve[i] = Math.tanh(x * k); }
    return curve;
}

// Decaying-noise impulse = the echo of a bang bouncing off the street.
function makeReverb(seconds) {
    const len = Math.floor(ctx.sampleRate * seconds);
    const buf = ctx.createBuffer(2, len, ctx.sampleRate);
    for (let c = 0; c < 2; c++) {
        const d = buf.getChannelData(c);
        for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 3);
    }
    const conv = ctx.createConvolver();
    conv.buffer = buf;
    conv.connect(master);
    return conv;
}

function init(existing) {
    if (ctx) return;
    ctx = existing || new (window.AudioContext || window.webkitAudioContext)();

    // Limiter only: catches clipping but leaves bangs much louder than pops.
    master = ctx.createDynamicsCompressor();
    master.threshold.value = -2; master.knee.value = 0; master.ratio.value = 20;
    master.attack.value = 0.001; master.release.value = 0.1;
    // Soft clipper after the limiter so stacked bangs never hard-clip.
    const clip = ctx.createWaveShaper();
    const n = 2048, c = new Float32Array(n), norm = Math.tanh(1.5);
    for (let i = 0; i < n; i++) { const x = i / (n - 1) * 2 - 1; c[i] = Math.tanh(x * 1.5) / norm * 0.98; }
    clip.curve = c;
    master.connect(clip); clip.connect(ctx.destination);

    noise = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
    const d = noise.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;

    shaper = makeCurve(4);
    hardShaper = makeCurve(12);
    reverbs.short = makeReverb(0.7);
    reverbs.long = makeReverb(1.4);
}

const rnd = (a, b) => a + Math.random() * (b - a);

// crack = sharp bright front edge, body = the main report, boom = low thump, echo = tail.
const KINDS = {
    pop:  { crack: [0.30, 0.010, 2500], body: ['bandpass', [900, 1900], 0.9, 0.07, 0.45, false],
            boom: [140, 60, 0.06, 0.35], echo: null },
    bang: { crack: [1.60, 0.028, 700],  body: ['lowpass', [2800, 3800], 0.8, 0.20, 1.30, true],
            boom: [120, 42, 0.26, 1.00], echo: ['short', 0.35] },
    mega: { crack: [2.20, 0.040, 500],  body: ['lowpass', [3000, 4200], 0.7, 0.34, 1.60, true],
            boom: [100, 32, 0.40, 1.20], echo: ['long', 0.45] },
};

function envGain(t, peak, dur) {
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t);
    g.gain.linearRampToValueAtTime(peak, t + 0.0015);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    return g;
}

function noiseBurst(t, dur, filterType, freq, q, curve, peak, dest) {
    const src = ctx.createBufferSource();
    src.buffer = noise;
    const f = ctx.createBiquadFilter();
    f.type = filterType; f.frequency.value = freq; f.Q.value = q;
    const ws = ctx.createWaveShaper(); ws.curve = curve;
    const g = envGain(t, peak, dur);
    src.connect(f); f.connect(ws); ws.connect(g); g.connect(dest);
    src.start(t, Math.random() * 0.5); src.stop(t + dur + 0.02);
}

// BIG bang: a separate, much deeper explosion on top of the normal crackle sounds.
// Hard crack, two overdriven tones dropping to 25Hz, a sub you feel, low rumble,
// then the long street echo.
function bigBang(volume, muffle, at, prof) {
    const t = at || ctx.currentTime + 0.005;
    const P = prof.pitch, L = prof.length, C = prof.crack;
    const scale = rnd(0.94, 1.06) * L;

    const out = ctx.createBiquadFilter();
    out.type = 'lowpass';
    out.frequency.value = 600 + 17000 * Math.pow(1 - Math.min(Math.max(muffle, 0), 1), 2);
    const vol = ctx.createGain();
    vol.gain.value = volume;
    out.connect(vol); vol.connect(master);
    const wet = ctx.createGain();
    wet.gain.value = 0.55;
    vol.connect(wet); wet.connect(reverbs.long);

    noiseBurst(t, 0.035, 'highpass', 400 * P, 0.7, hardShaper, 2.6 * C, out);   // crack
    noiseBurst(t, 0.30 * scale, 'lowpass', 320 * P, 0.9, hardShaper, 1.6, out); // low rumble

    for (const detune of [1, 1.06]) {
        const o = ctx.createOscillator(); o.type = 'triangle';
        o.frequency.setValueAtTime(95 * P * detune, t);
        o.frequency.exponentialRampToValueAtTime(25, t + 0.35 * L);
        const pre = ctx.createGain(); pre.gain.value = 4;
        const ws = ctx.createWaveShaper(); ws.curve = hardShaper;
        const og = envGain(t, 1.5, 0.38 * scale);
        o.connect(pre); pre.connect(ws); ws.connect(og); og.connect(out);
        o.start(t); o.stop(t + 0.4 * scale);
    }

    const sub = ctx.createOscillator(); sub.type = 'sine';
    sub.frequency.setValueAtTime(58 * P, t);
    sub.frequency.exponentialRampToValueAtTime(20, t + 0.6);
    const sg = envGain(t, 1.6, 0.6);
    sub.connect(sg); sg.connect(out);
    sub.start(t); sub.stop(t + 0.62);
}

// prof = sound type from Config.SoundTypes: { pitch, length, crack } multipliers.
const DEFAULT_PROFILE = { pitch: 1, length: 1, crack: 1 };

function shot(kind, volume, muffle, at, prof) {
    prof = Object.assign({}, DEFAULT_PROFILE, prof || {});
    if (kind === 'big') return bigBang(volume, muffle, at, prof);
    const k = KINDS[kind] || KINDS.pop;
    const t = at || ctx.currentTime + 0.005;
    const P = prof.pitch;
    const scale = rnd(0.88, 1.12) * prof.length;
    const hard = k.body[5];

    // Distance muffling: further away = duller.
    const out = ctx.createBiquadFilter();
    out.type = 'lowpass';
    out.frequency.value = 600 + 17000 * Math.pow(1 - Math.min(Math.max(muffle, 0), 1), 2);
    const vol = ctx.createGain();
    vol.gain.value = volume;
    out.connect(vol); vol.connect(master);
    if (k.echo) {
        const wet = ctx.createGain();
        wet.gain.value = k.echo[1];
        vol.connect(wet); wet.connect(reverbs[k.echo[0]]);
    }

    const [cPeak, cDur, cHp] = k.crack;
    noiseBurst(t, cDur, 'highpass', cHp * P, 0.7, hard ? hardShaper : shaper, cPeak * prof.crack, out);

    const [bType, bF, bQ, bDur, bGain] = k.body;
    noiseBurst(t, bDur * scale, bType, rnd(bF[0], bF[1]) * P, bQ, hard ? hardShaper : shaper, bGain, out);

    const [f0, f1, oDur, oGain] = k.boom;
    const o = ctx.createOscillator();
    o.type = 'sine';
    o.frequency.setValueAtTime(f0 * P, t);
    o.frequency.exponentialRampToValueAtTime(f1 * P, t + oDur * prof.length);
    const og = envGain(t, oGain, oDur * scale);
    o.connect(og); og.connect(out);
    o.start(t); o.stop(t + oDur * scale + 0.02);

    // Mega gets a second, slightly delayed report.
    if (kind === 'mega' && !at) shot('bang', volume * 0.75, muffle, t + rnd(0.05, 0.09), prof);
}

function playShot(kind, volume, muffle, prof) {
    init();
    if (ctx.state === 'suspended') ctx.resume();
    shot(kind, Math.max(0, Math.min(volume || 0, 1.5)), muffle || 0, null, prof);
}

window.addEventListener('message', (e) => {
    const m = e.data;
    if (!m || m.action !== 'sp_antilag') return;
    playShot(m.kind, m.volume, m.muffle, m.profile);
});
