.pragma library

function key(screenName, instanceId) {
    return JSON.stringify([screenName, instanceId]);
}

function release(entries, registration) {
    if (!registration || entries[registration.key] !== registration)
        return entries;
    const next = Object.assign({}, entries);
    delete next[registration.key];
    return next;
}

function compare(a, b, configs, screens) {
    const index = (values, value) => {
        const found = values.indexOf(value);
        return found < 0 ? values.length : found;
    };
    const ac = a.context;
    const bc = b.context;
    const kind = context => context?.kind === "dock" ? 1 : 0;
    const vertical = context => [2, 3].includes(context?.surface?.config?.position) ? 1 : 0;
    return index(screens, a.screenName) - index(screens, b.screenName)
        || kind(ac) - kind(bc)
        || vertical(ac) - vertical(bc)
        || index(configs, ac?.barId) - index(configs, bc?.barId)
        || index(["left", "center", "right"], ac?.section) - index(["left", "center", "right"], bc?.section)
        || (ac?.occurrenceOrder ?? 0) - (bc?.occurrenceOrder ?? 0)
        || a.instanceId.localeCompare(b.instanceId);
}

function select(entries, widgetId, target, configs, screens, eligible) {
    return Object.values(entries).filter(entry => entry.widgetId === widgetId && entry.item
        && (!target?.screenName || entry.screenName === target.screenName)
        && (!target?.instanceId || entry.instanceId === target.instanceId)
        && (!target?.barId || entry.context?.barId === target.barId)
        && (!target?.kind || entry.context?.kind === target.kind)
        && (!target?.section || entry.context?.section === target.section)
        && (!target?.occurrenceId || entry.context?.occurrenceId === target.occurrenceId)
        && (!eligible || eligible(entry)))
        .sort((a, b) => compare(a, b, configs, screens))[0] ?? null;
}
