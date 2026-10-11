/* Velora Jam Co. — synthesised sound effects (no audio files required) */
'use strict';

const SFX = (() => {
    let ctx = null;
    let master = null;
    const ac = () => {
        if (!ctx) {
            const C = window.AudioContext || window.webkitAudioContext;
            if (!C) return null;
            ctx = new C();
            master = ctx.createGain();
            master.gain.value = 0.35;
            master.connect(ctx.destination);
        }
        if (ctx.state === 'suspended') ctx.resume();
        return ctx;
    };

    function tone(freq, dur, type = 'sine', vol = 0.5, slide = 0, delay = 0) {
        const a = ac(); if (!a) return;
        const t = a.currentTime + delay;
        const o = a.createOscillator();
        const g = a.createGain();
        o.type = type;
        o.frequency.setValueAtTime(freq, t);
        if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(30, freq + slide), t + dur);
        g.gain.setValueAtTime(0.0001, t);
        g.gain.exponentialRampToValueAtTime(vol, t + 0.01);
        g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
        o.connect(g); g.connect(master);
        o.start(t); o.stop(t + dur + 0.02);
    }

    function noise(dur, vol = 0.3, filter = 1200, type = 'lowpass', delay = 0) {
        const a = ac(); if (!a) return;
        const t = a.currentTime + delay;
        const len = Math.floor(a.sampleRate * dur);
        const buf = a.createBuffer(1, len, a.sampleRate);
        const d = buf.getChannelData(0);
        for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / len);
        const src = a.createBufferSource();
        src.buffer = buf;
        const f = a.createBiquadFilter();
        f.type = type; f.frequency.value = filter;
        const g = a.createGain();
        g.gain.value = vol;
        src.connect(f); f.connect(g); g.connect(master);
        src.start(t);
    }

    return {
        pop() { tone(520, 0.09, 'sine', 0.5, 380); noise(0.05, 0.15, 3000, 'highpass'); },
        pick() { tone(660, 0.07, 'triangle', 0.4, 300); tone(990, 0.09, 'sine', 0.25, 0, 0.05); },
        squish() { noise(0.18, 0.5, 500); tone(140, 0.15, 'sawtooth', 0.15, -60); },
        bad() { tone(220, 0.18, 'square', 0.18, -80); },
        chop() { noise(0.06, 0.45, 2500, 'bandpass'); tone(180, 0.05, 'square', 0.15); },
        perfect() { tone(880, 0.12, 'sine', 0.35); tone(1320, 0.18, 'sine', 0.3, 0, 0.07); },
        bubble() { tone(200 + Math.random() * 220, 0.08, 'sine', 0.12, 260); },
        click() { tone(1400, 0.03, 'square', 0.12); },
        twist() { noise(0.12, 0.35, 1800, 'bandpass'); tone(320, 0.06, 'triangle', 0.2, 120); },
        pour() { noise(0.25, 0.12, 900, 'bandpass'); },
        coin() { tone(988, 0.08, 'square', 0.18); tone(1319, 0.25, 'square', 0.18, 0, 0.08); },
        chime() { [784, 988, 1175].forEach((f, i) => tone(f, 0.4, 'sine', 0.22, 0, i * 0.09)); },
        reveal() { [523, 659, 784, 1047, 1319].forEach((f, i) => tone(f, 0.7, 'triangle', 0.2, 0, i * 0.12)); noise(1.4, 0.06, 6000, 'highpass', 0.1); },
        sizzle() { noise(0.3, 0.1, 4000, 'highpass'); },
    };
})();
window.SFX = SFX;
