function resolve(definitions, saved) {
    const source = Array.isArray(saved) ? saved : definitions.filter(d => d.enabled !== false);
    const seen = Object.create(null);
    return source.filter(item => {
        if (!item || typeof item.id !== "string" || seen[item.id])
            return false;
        seen[item.id] = true;
        return true;
    }).map(item => {
        const spec = definitions.find(d => d.id === item.id);
        if (!spec)
            return item;
        return {
            id: item.id,
            w: dimension(item.w, spec.minW, spec.maxW, spec.w),
            h: dimension(item.h, spec.minH, spec.maxH, spec.h),
            graphics: typeof item.graphics === "boolean" ? item.graphics : true
        };
    });
}

function dimension(value, minimum, maximum, fallback) {
    const min = minimum ?? 1;
    const max = Math.max(min, maximum ?? fallback ?? min);
    return Math.max(min, Math.min(max, Number.isInteger(value) ? value : (fallback ?? min)));
}

function replace(items, index, changes) {
    if (index < 0 || index >= items.length)
        return items;
    return items.map((item, i) => i === index ? Object.assign({}, item, changes) : item);
}

function move(items, index, delta) {
    const target = index + delta;
    if (index < 0 || index >= items.length || target < 0 || target >= items.length)
        return items;
    const result = items.slice();
    result.splice(target, 0, result.splice(index, 1)[0]);
    return result;
}
