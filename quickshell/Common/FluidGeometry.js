.pragma library

function collapsed(target, side, center, extent) {
    const horizontal = side === "top" || side === "bottom";
    const vertical = side === "left" || side === "right";
    const span = Math.min(Math.max(1, extent), horizontal ? target.width : target.height);
    if (horizontal) {
        const x = Math.max(target.x, Math.min(center - span / 2, target.x + target.width - span));
        return Qt.rect(x, side === "top" ? target.y : target.y + target.height - 1, span, 1);
    }
    if (vertical) {
        const y = Math.max(target.y, Math.min(center - span / 2, target.y + target.height - span));
        return Qt.rect(side === "left" ? target.x : target.x + target.width - 1, y, 1, span);
    }
    const width = Math.min(target.width, Math.max(1, extent));
    return Qt.rect(target.x + (target.width - width) / 2, target.y + (target.height - 1) / 2, width, 1);
}

// Only floored: an open top end lets spring bounce through, limitOvershoot() bounds it.
function interpolate(from, to, progress) {
    const p = Math.max(0, progress);
    return Qt.rect(from.x + (to.x - from.x) * p, from.y + (to.y - from.y) * p,
                   Math.max(1, from.width + (to.width - from.width) * p),
                   Math.max(1, from.height + (to.height - from.height) * p));
}

function limitOvershoot(body, target, maxPx) {
    const cap = Math.max(0, maxPx);
    const left = Math.max(target.x - cap, Math.min(body.x, target.x + target.width + cap - 1));
    const top = Math.max(target.y - cap, Math.min(body.y, target.y + target.height + cap - 1));
    const right = Math.min(body.x + body.width, target.x + target.width + cap);
    const bottom = Math.min(body.y + body.height, target.y + target.height + cap);
    return Qt.rect(left, top, Math.max(1, right - left), Math.max(1, bottom - top));
}

function contentOpacity(body, target) {
    return Math.max(0, Math.min(1, (Math.min(body.width / Math.max(1, target.width), body.height / Math.max(1, target.height)) - 0.5) * 2));
}

function chromeOpacity(progress) {
    return Math.max(0, Math.min(1, progress * 4));
}
