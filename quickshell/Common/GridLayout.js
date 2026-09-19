function packCells(cards, order, columns, isAvailable, step = 1) {
    const steps = Math.round(columns / step);
    const cells = [];
    const heights = [];
    for (let c = 0; c < steps; c++)
        heights.push(0);
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
        let bestX = 0;
        let bestY = Infinity;
        for (let x = 0; x + w <= steps; x++) {
            let y = 0;
            for (let c = x; c < x + w; c++)
                y = Math.max(y, heights[c]);
            if (y >= bestY)
                continue;
            bestY = y;
            bestX = x;
        }
        for (let c = bestX; c < bestX + w; c++)
            heights[c] = bestY + h;
        rows = Math.max(rows, bestY + h);
        cells[sourceIndex] = {
            "col": bestX * step,
            "row": bestY * step,
            "cols": w * step,
            "rows": h * step
        };
    }

    return {
        "cells": cells,
        "rows": rows * step
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
        "totalHeight": packed.rows > 0 ? packed.rows * rowUnit + (packed.rows - 1) * gap : 0
    };
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

function dimension(value, minimum, maximum, fallback, step = 1) {
    const min = minimum ?? 1;
    const max = Math.max(min, maximum ?? fallback ?? min);
    return Math.max(min, Math.min(max, typeof value === "number" && Number.isInteger(value / step) ? value : (fallback ?? min)));
}
