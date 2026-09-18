.pragma library

var MIN_CHANNEL_DELTA = 0.1;

function distinct(a, b) {
    const ca = Qt.color(a);
    const cb = Qt.color(b);
    return Math.max(Math.abs(ca.r - cb.r), Math.abs(ca.g - cb.g), Math.abs(ca.b - cb.b)) >= MIN_CHANNEL_DELTA;
}

function firstDistinct(candidates, taken) {
    return candidates.find(c => c && taken.every(t => distinct(c, t)));
}

function pick(scheme) {
    if (!scheme?.primary)
        return null;
    const primary = scheme.primary;
    const secondary = firstDistinct([scheme.secondary, scheme.tertiary, scheme.primaryContainer, scheme.info], [primary]) ?? primary;
    const tertiary = firstDistinct([scheme.tertiary, scheme.info, scheme.error, scheme.warning, scheme.primaryContainer], [primary, secondary]) ?? secondary;
    return {
        primary,
        secondary,
        tertiary
    };
}
