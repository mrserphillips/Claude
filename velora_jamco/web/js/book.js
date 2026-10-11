/* Velora Jam Co. — personal recipe book (shared by the business and kitchen UIs) */
'use strict';

const Book = {
    render(container, book, achievements) {
        if (!book) { container.innerHTML = '<div class="spinner"></div>'; return; }
        let filter = 'all';
        let selected = null;
        const discovered = book.recipes.filter((r) => r.discovered);

        container.innerHTML = `
            <div class="progress-head">
                <div class="h2" style="margin:0">Recipe Book</div>
                <div class="bar"><i style="width:${book.percent}%"></i></div>
                <div class="gold" style="font-family:Cinzel">${book.found} / ${book.total} · ${book.percent}%</div>
            </div>
            <div class="row between" style="margin-bottom:14px">
                <div class="row" style="gap:6px">
                    <button class="tab active" data-f="all">All Recipes</button>
                    <button class="tab" data-f="found">Discovered</button>
                    <button class="tab" data-f="locked">Undiscovered</button>
                </div>
                <div class="muted small">Experimental batches: ${book.experiments || 0}</div>
            </div>
            <div class="book">
                <div class="book-grid scroll"></div>
                <div class="book-detail card gold-edge"></div>
            </div>`;

        const grid = $('.book-grid', container);
        const detail = $('.book-detail', container);

        const drawDetail = () => {
            const r = selected;
            if (!r) {
                detail.innerHTML = `<img class="big" src="${jamImg('jar_mystery')}" alt="">
                    <div class="h3" style="margin-top:10px">Your Collection</div>
                    <p class="muted">Combine fruits at the kitchen to discover new flavours. Hidden recipes stay secret until you create them.</p>
                    <div class="divider"></div>
                    ${['common', 'uncommon', 'rare', 'epic', 'legendary'].map((id) => {
                        const total = book.recipes.filter((x) => x.discovered && x.rarity === id).length;
                        return `<div class="row between small"><span>${pill(id)}</span><span>${total} found</span></div>`;
                    }).join('<div style="height:6px"></div>')}`;
                return;
            }
            const ingr = [...r.fruits.map((f) => ({ ...f })), ...(r.special ? [r.special] : [])];
            detail.innerHTML = `<img class="big" src="${jamImg(r.image)}" alt="">
                <div class="name">${esc(r.label)}</div>
                <div style="margin:6px 0">${pill(r.rarity)}</div>
                <p class="muted small">${esc(r.description || '')}</p>
                <div class="h3" style="margin-top:12px">Ingredients</div>
                <div class="ingr">${ingr.map((i) => `<div class="i"><img src="${itemImg(i.item)}" alt="">${esc(i.label)}</div>`).join('')}</div>
                <div class="divider"></div>
                <div class="row between small"><span class="muted">Best quality</span><b class="pink">${r.best}%</b></div>
                <div class="row between small"><span class="muted">Jars crafted</span><b>${r.crafted}</b></div>
                <div class="row between small"><span class="muted">Sells for</span><b class="good">${money(r.priceMin)} – ${money(r.priceMax)}</b></div>`;
        };

        const drawGrid = () => {
            const list = book.recipes.filter((r) => filter === 'all' || (filter === 'found' ? r.discovered : !r.discovered));
            if (!list.length) {
                grid.innerHTML = `<div class="empty" style="grid-column:1/-1">${filter === 'found' ? 'No recipes discovered yet. Get mixing!' : 'You have discovered every recipe. Incredible!'}</div>`;
                return;
            }
            grid.innerHTML = list.map((r) => {
                if (!r.discovered) {
                    return `<div class="jar-card locked"><img src="${jamImg('jar_mystery')}" alt=""><div class="nm">???</div><div class="pr">Undiscovered</div></div>`;
                }
                const rc = rarityOf(r.rarity).color;
                return `<div class="jar-card ${selected && selected.index === r.index ? 'active' : ''}" data-i="${r.index}" style="--rc:${rc}55;--rg:${rc}">
                    <img src="${jamImg(r.image)}" alt=""><div class="nm">${esc(r.label)}</div>
                    <div class="pr">${money(r.priceMin)} – ${money(r.priceMax)}</div></div>`;
            }).join('');
        };

        container.addEventListener('click', (e) => {
            const f = e.target.closest('[data-f]');
            if (f) {
                filter = f.dataset.f;
                $$('[data-f]', container).forEach((b) => b.classList.toggle('active', b === f));
                drawGrid();
                return;
            }
            const card = e.target.closest('.jar-card[data-i]');
            if (card) {
                selected = discovered.find((r) => r.index === Number(card.dataset.i)) || null;
                if (window.SFX) SFX.click();
                drawGrid();
                drawDetail();
            }
        });
        drawGrid();
        drawDetail();
    },

    achievements(list) {
        return `<div class="grid c2">${(list || []).map((a) => `
            <div class="card ach ${a.unlocked ? 'on' : ''}"><div class="medal">${a.unlocked ? '★' : '?'}</div>
            <div><b style="font-family:Cinzel;letter-spacing:.06em">${esc(a.label)}</b><div class="muted small">${esc(a.description)}</div></div></div>`).join('')}</div>`;
    },

    stats(s) {
        if (!s) return '';
        const tiles = [
            ['Jars Crafted', s.jars_crafted], ['Jars Sold', s.jars_sold], ['Total Earned', money(s.total_earned)], ['Best Sale', money(s.best_sale)],
            ['Fruit Picked', s.fruit_harvested], ['Golden Fruit', s.golden_found], ['Perfect Batches', s.perfect_batches], ['Experiments', s.experiments],
        ];
        return `<div class="grid c4">${tiles.map(([l, v]) => `<div class="card stat"><div class="val">${esc(v ?? 0)}</div><div class="lbl">${esc(l)}</div></div>`).join('')}</div>`;
    },
};
window.Book = Book;
