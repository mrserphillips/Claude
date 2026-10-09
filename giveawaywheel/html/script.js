// Fallback only - the real duration is sent from Lua (Config.SpinDurationMs) with every spin event
const SPIN_DURATION_MS = 8000;
const FULL_SPINS = 6;
const COLORS = ['#e63946', '#f1a208', '#2a9d8f', '#457b9d', '#8338ec', '#ff006e', '#3a86ff', '#06d6a0'];

const overlay = document.getElementById('overlay');
const wheelCanvas = document.getElementById('wheel');
const wheelWrap = document.getElementById('wheel-wrap');
const resultEl = document.getElementById('result');
const ctx = wheelCanvas.getContext('2d');

// Segment 0 starts at the top (12 o'clock, where the pointer is) and segments are laid
// out clockwise from there - this offset keeps the canvas drawing lined up with the
// pointer/rotation math below.
const TOP_OFFSET = -Math.PI / 2;

function drawWheel(entrants) {
    const size = wheelCanvas.width;
    const radius = size / 2;
    const segAngle = (2 * Math.PI) / entrants.length;

    ctx.clearRect(0, 0, size, size);

    entrants.forEach((entrant, i) => {
        const start = TOP_OFFSET + i * segAngle;
        const end = start + segAngle;

        ctx.beginPath();
        ctx.moveTo(radius, radius);
        ctx.arc(radius, radius, radius - 4, start, end);
        ctx.closePath();
        ctx.fillStyle = COLORS[i % COLORS.length];
        ctx.fill();
        ctx.strokeStyle = 'rgba(0,0,0,0.35)';
        ctx.lineWidth = 2;
        ctx.stroke();

        ctx.save();
        ctx.translate(radius, radius);
        ctx.rotate(start + segAngle / 2);
        ctx.textAlign = 'right';
        ctx.fillStyle = '#fff';
        ctx.font = 'bold 20px sans-serif';
        ctx.shadowColor = 'rgba(0,0,0,0.6)';
        ctx.shadowBlur = 4;
        let label = entrant.name || '???';
        if (label.length > 16) label = label.slice(0, 15) + '…';
        ctx.fillText(label, radius - 16, 6);
        ctx.restore();
    });
}

function spin(entrants, winnerIndex, durationMs) {
    if (!entrants || entrants.length === 0) return;

    drawWheel(entrants);
    resultEl.textContent = '';
    overlay.classList.add('visible');

    const segAngleDeg = 360 / entrants.length;
    // winnerIndex arrives 1-based from Lua
    const winnerCenterDeg = (winnerIndex - 1) * segAngleDeg + segAngleDeg / 2;

    // rotating the wheel clockwise by targetRotation brings winnerCenterDeg under the
    // fixed top pointer - identical inputs (entrants order + winnerIndex) always produce
    // the identical targetRotation, so every client's wheel lands on the same name.
    const targetRotation = FULL_SPINS * 360 + (360 - winnerCenterDeg);

    wheelWrap.style.transition = 'none';
    wheelWrap.style.transform = 'rotate(0deg)';
    // force reflow so the transition below actually restarts from 0deg
    void wheelWrap.offsetHeight;

    wheelWrap.style.transition = `transform ${durationMs}ms cubic-bezier(0.12, 0.65, 0.15, 1)`;
    wheelWrap.style.transform = `rotate(${targetRotation}deg)`;

    setTimeout(() => {
        const winner = entrants[winnerIndex - 1];
        resultEl.textContent = `🎉 Winner: ${winner.name} (ID: ${winner.id}) 🎉`;
    }, durationMs);
}

function hide() {
    overlay.classList.remove('visible');
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;

    if (data.action === 'spin') {
        spin(data.entrants, data.winnerIndex, data.duration || SPIN_DURATION_MS);
    } else if (data.action === 'hide') {
        hide();
    }
});
