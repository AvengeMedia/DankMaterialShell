.pragma library

function stableStringify(value) {
    if (value === null || typeof value !== "object")
        return JSON.stringify(value);
    if (Array.isArray(value))
        return "[" + value.map(stableStringify).join(",") + "]";
    return "{" + Object.keys(value).sort().map(function (k) {
        return JSON.stringify(k) + ":" + stableStringify(value[k]);
    }).join(",") + "}";
}

function isDefault(value, def) {
    return stableStringify(value) === stableStringify(def);
}

function cloneDef(def) {
    if (def === null || typeof def !== "object")
        return def;
    return JSON.parse(JSON.stringify(def));
}

function stripDefaults(obj, SPEC) {
    for (var k in SPEC) {
        if (!(k in obj))
            continue;
        if (isDefault(obj[k], SPEC[k].def))
            delete obj[k];
    }
}
