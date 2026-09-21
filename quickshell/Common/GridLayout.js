function packCells(cards, order, columns, isAvailable, step = 1) {
    const steps = Math.round(columns / step);
    const cells = [];
    const taken = [];
    let rows = 0;

    for (let p = 0; p < order.length; p++) {
        const sourceIndex = order[p];
        const card = cards[sourceIndex];
        if (!card)
            continue;
        if (isAvailable && !isAvailable(card.id)) {
            cells[sourceIndex] = null;
            continue;
        }

        const w = Math.max(1, Math.min(steps, Math.round((card.w || 1) / step)));
        const h = Math.max(1, Math.round((card.h || 1) / step));
        const cell = positioned(card) ? settle(taken, Math.max(0, Math.min(steps - w, Math.round(card.col / step))), Math.max(0, Math.round(card.row / step)), w, h) : firstFit(taken, steps, w, h);
        taken.push(cell);
        rows = Math.max(rows, cell.y + cell.h);
        cells[sourceIndex] = {
            "col": cell.x * step,
            "row": cell.y * step,
            "cols": w * step,
            "rows": h * step
        };
    }

    return {
        "cells": cells,
        "rows": rows * step
    };
}

function positioned(card) {
    return Number.isFinite(card.col) && Number.isFinite(card.row);
}

function overlaps(taken, x, y, w, h) {
    return taken.some(cell => x < cell.x + cell.w && cell.x < x + w && y < cell.y + cell.h && cell.y < y + h);
}

function settle(taken, x, y, w, h) {
    while (overlaps(taken, x, y, w, h))
        y++;
    return {
        "x": x,
        "y": y,
        "w": w,
        "h": h
    };
}

function firstFit(taken, steps, w, h) {
    const ceiling = taken.reduce((top, cell) => Math.max(top, cell.y + cell.h), 0);
    for (let y = 0; y < ceiling; y++) {
        for (let x = 0; x + w <= steps; x++) {
            if (!overlaps(taken, x, y, w, h))
                return {
                    "x": x,
                    "y": y,
                    "w": w,
                    "h": h
                };
        }
    }
    return {
        "x": 0,
        "y": ceiling,
        "w": w,
        "h": h
    };
}

function packCards(cards, order, columns, width, gap, rowUnit, mirror, isAvailable, step = 1) {
    const packed = packCells(cards, order, columns, isAvailable, step);
    const colW = (width - gap * (columns - 1)) / columns;
    const slots = packed.cells.map(cell => {
        if (!cell)
            return null;
        const px = cell.col * (colW + gap);
        const pw = cell.cols * colW + (cell.cols - 1) * gap;
        return {
            "x": mirror ? width - px - pw : px,
            "y": cell.row * (rowUnit + gap),
            "w": pw,
            "h": cell.rows * rowUnit + (cell.rows - 1) * gap,
            "col": cell.col,
            "row": cell.row,
            "cols": cell.cols,
            "rows": cell.rows
        };
    });

    return {
        "slots": slots,
        "rows": packed.rows,
        "totalHeight": packed.rows > 0 ? packed.rows * rowUnit + (packed.rows - 1) * gap : 0,
        "columns": columns,
        "width": width,
        "colW": colW,
        "rowUnit": rowUnit,
        "gap": gap,
        "step": step,
        "mirror": mirror
    };
}

function cellAt(layout, x, y, cols, rows) {
    const px = layout.mirror ? layout.width - x - (cols * layout.colW + (cols - 1) * layout.gap) : x;
    const col = Math.round(px / (layout.colW + layout.gap) / layout.step) * layout.step;
    const row = Math.round(y / (layout.rowUnit + layout.gap) / layout.step) * layout.step;
    return {
        "col": Math.max(0, Math.min(layout.columns - cols, col)),
        "row": Math.max(0, row)
    };
}

function placedItems(items, slots) {
    return items.map((item, i) => slots[i] ? Object.assign({}, item, {
            "col": slots[i].col,
            "row": slots[i].row
        }) : item);
}

function rowLimit(cards, order, columns, rows, isAvailable) {
    return Math.max(rows, packCells(cards, order, columns, isAvailable).rows);
}

function fitWithin(cards, order, columns, limit, index, want, min, isAvailable) {
    let best = null;
    for (let w = Math.min(columns, want.w); w >= min.w; w--) {
        for (let h = want.h; h >= min.h; h--) {
            const trial = cards.slice();
            trial[index] = Object.assign({}, cards[index], {
                "w": w,
                "h": h
            });
            if (packCells(trial, order, columns, isAvailable).rows > limit)
                continue;
            const distance = want.w - w + want.h - h;
            const better = !best || distance < best.distance || (distance === best.distance && w * h > best.w * best.h);
            if (better)
                best = {
                    "w": w,
                    "h": h,
                    "distance": distance
                };
            break;
        }
    }
    return best ? {
        "w": best.w,
        "h": best.h
    } : null;
}

function fitResize(cards, order, columns, rows, index, want, min, isAvailable) {
    const limit = rowLimit(cards, order, columns, rows, isAvailable);
    return fitWithin(cards, order, columns, limit, index, want, min, isAvailable);
}

function fitNewCard(cards, columns, rows, id, want, min, isAvailable) {
    const order = cards.map((card, i) => i);
    const limit = rowLimit(cards, order, columns, rows, isAvailable);
    const trial = cards.concat([
        {
            "id": id,
            "w": want.w,
            "h": want.h
        }
    ]);
    return fitWithin(trial, order.concat([cards.length]), columns, limit, cards.length, want, min, isAvailable);
}

function neighborInDirection(rects, index, direction) {
    const from = rects[index];
    let best = -1;
    let bestScore = Infinity;
    rects.forEach((rect, i) => {
        if (i === index)
            return;
        const score = directionalScore(from, rect, direction);
        if (score >= bestScore)
            return;
        bestScore = score;
        best = i;
    });
    return best;
}

function directionalScore(from, to, direction) {
    switch (direction) {
    case "left":
        return axisScore(from.x - (to.x + to.w), crossGap(from.y, from.h, to.y, to.h));
    case "right":
        return axisScore(to.x - (from.x + from.w), crossGap(from.y, from.h, to.y, to.h));
    case "up":
        return axisScore(from.y - (to.y + to.h), crossGap(from.x, from.w, to.x, to.w));
    case "down":
        return axisScore(to.y - (from.y + from.h), crossGap(from.x, from.w, to.x, to.w));
    }
    return Infinity;
}

function axisScore(gap, cross) {
    return gap < 0 ? Infinity : gap + cross * 2;
}

function crossGap(a, aSize, b, bSize) {
    return Math.max(0, b - (a + aSize), a - (b + bSize));
}

function nearestStep(edgeFor, from, minStep, maxStep, wanted) {
    const distance = step => Math.abs(edgeFor(step) - wanted);
    let best = Math.max(minStep, Math.min(maxStep, from));
    for (const direction of [1, -1]) {
        for (let step = best + direction; step >= minStep && step <= maxStep; step += direction) {
            const gap = distance(step);
            if (gap > distance(best))
                break;
            if (gap < distance(best))
                best = step;
        }
    }
    return best;
}

function dimension(value, minimum, maximum, fallback, step = 1) {
    const min = minimum ?? 1;
    const max = Math.max(min, maximum ?? fallback ?? min);
    return Math.max(min, Math.min(max, typeof value === "number" && Number.isInteger(value / step) ? value : (fallback ?? min)));
}
