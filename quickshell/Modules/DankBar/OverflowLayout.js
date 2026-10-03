.pragma library
.import "CenterLayout.js" as CenterLayout

function pinned(widgetId) {
    return ["spacer", "separator", "island"].includes(widgetId);
}

function placement(entry, fallback = "bar") {
    if (pinned(entry?.widgetId))
        return "bar";
    const mode = entry?.overflowMode === "section" ? fallback : (entry?.overflowMode ?? fallback);
    return mode === "auto" || mode === "always" ? mode : "bar";
}

function defaultPosition(name, count) {
    return name === "right" ? 0 : count;
}

function expanderIcon(edge, open) {
    switch (edge) {
    case "left":
        return open ? "keyboard_arrow_left" : "keyboard_arrow_right";
    case "right":
        return open ? "keyboard_arrow_right" : "keyboard_arrow_left";
    case "bottom":
        return open ? "keyboard_arrow_down" : "keyboard_arrow_up";
    default:
        return open ? "keyboard_arrow_up" : "keyboard_arrow_down";
    }
}

function section(entries, hidden, spacing, triggerSize, triggerIndex) {
    const sizes = [];
    const indices = [];
    const hasOverflow = hidden.some(index => entries[index]?.size > 0);
    const insertion = Math.max(0, Math.min(entries.length, triggerIndex));
    for (let index = 0; index <= entries.length; index++) {
        if (index === insertion && hasOverflow) {
            sizes.push(triggerSize);
            indices.push(-1);
        }
        if (index === entries.length)
            break;
        sizes.push(entries[index]?.size > 0 && !hidden.includes(index) ? entries[index].size : null);
        indices.push(index);
    }
    const layout = CenterLayout.resolve(sizes, 0, spacing, "geometric");
    const positions = entries.map(() => null);
    let buttonPosition = null;
    const start = -layout.totalSize / 2;
    for (let index = 0; index < indices.length; index++) {
        const position = layout.positions[index] === null ? null : layout.positions[index] - start;
        if (indices[index] === -1)
            buttonPosition = position;
        else
            positions[indices[index]] = position;
    }
    const middle = Math.floor(entries.length / 2);
    const anchor = { count: entries.length, middle: indices.indexOf(middle), previous: indices.indexOf(middle - 1) };
    return { sizes, indices, positions, buttonPosition, totalSize: layout.totalSize, anchor };
}

function measure(sections, hidden, options) {
    const names = ["left", "center", "right"];
    const layouts = {};
    for (const name of names) {
        layouts[name] = section(sections[name], hidden[name], options.spacing, options.triggerSize,
            options.positions?.[name] ?? defaultPosition(name, sections[name].length));
    }
    const min = options.start ?? 0;
    const max = options.length - (options.end ?? 0);
    const gap = options.spacing;
    const leading = layouts.left.totalSize;
    const trailing = layouts.right.totalSize;
    const center = layouts.center;
    const bounds = options.confineCenter ? {
        min: min + (leading > 0 ? leading + gap : 0),
        max: max - (trailing > 0 ? trailing + gap : 0)
    } : null;
    const centered = CenterLayout.resolve(center.sizes, options.length, gap, options.centeringMode ?? "geometric", bounds, center.anchor);
    const livePositions = centered.positions.filter(position => position !== null);
    const centerStart = livePositions.length ? Math.min(...livePositions) : 0;
    const intervals = {
        left: { start: min, end: min + leading, size: leading },
        center: { start: centerStart, end: centerStart + centered.totalSize, size: centered.totalSize },
        right: { start: max - trailing, end: max, size: trailing }
    };
    const collisions = new Set();
    for (const name of names) {
        const interval = intervals[name];
        if (interval.size > 0 && (interval.start < min || interval.end > max))
            collisions.add(name);
    }
    const live = names.filter(name => intervals[name].size > 0);
    for (let index = 0; index < live.length; index++) {
        for (let other = index + 1; other < live.length; other++) {
            const a = live[index];
            const b = live[other];
            if (intervals[a].end + gap > intervals[b].start) {
                collisions.add(a);
                collisions.add(b);
            }
        }
    }
    return { fits: collisions.size === 0, collisions: [...collisions], layouts, intervals };
}

function resolve(sections, options, previous = {}) {
    const names = ["left", "center", "right"];
    const hidden = {};
    for (const name of names) {
        hidden[name] = [];
        for (let index = 0; index < sections[name].length; index++) {
            const entry = sections[name][index];
            if (entry.size > 0 && entry.mode === "always")
                hidden[name].push(index);
        }
    }

    let measured = measure(sections, hidden, options);
    while (!measured.fits) {
        // The center anchors the bar, so the sides yield first; between them the longer one gives up a widget.
        const colliding = measured.collisions.slice().sort((a, b) => (a === "center") - (b === "center") || measured.intervals[b].size - measured.intervals[a].size);
        let candidate = null;
        for (const name of colliding) {
            const position = options.positions?.[name] ?? defaultPosition(name, sections[name].length);
            const eligible = [];
            for (let index = 0; index < sections[name].length; index++) {
                const entry = sections[name][index];
                if (entry.size > 0 && entry.mode === "auto" && !hidden[name].includes(index))
                    eligible.push(index);
            }
            eligible.sort((a, b) => Math.abs(a + 0.5 - position) - Math.abs(b + 0.5 - position));
            if (eligible.length) {
                candidate = { name, index: eligible[0] };
                break;
            }
        }
        if (!candidate)
            break;
        hidden[candidate.name].push(candidate.index);
        measured = measure(sections, hidden, options);
    }

    const fresh = {};
    for (const name of names)
        fresh[name] = hidden[name].slice();
    const freshFits = measured.fits;

    // Hysteresis: a restored widget must also fit the margin, or it would bounce in and out at the boundary.
    const restoring = [];
    for (const name of names) {
        for (const index of previous[name] ?? []) {
            if (sections[name][index]?.size > 0 && sections[name][index].mode === "auto" && !hidden[name].includes(index)) {
                hidden[name].push(index);
                restoring.push({ name, index });
            }
        }
    }
    for (const { name, index } of restoring) {
        const trial = {};
        for (const key of names)
            trial[key] = hidden[key].filter(value => key !== name || value !== index);
        const padded = Object.assign({}, sections, {
            [name]: sections[name].map((entry, entryIndex) => entryIndex === index ? Object.assign({}, entry, { size: entry.size + (options.restoreMargin ?? 0) }) : entry)
        });
        if (measure(padded, trial, options).fits)
            hidden[name] = trial[name];
    }
    const result = freshFits && !measure(sections, hidden, options).fits ? fresh : hidden;
    for (const name of names)
        result[name].sort((a, b) => a - b);
    return Object.assign({ hidden: result }, measure(sections, result, options));
}
