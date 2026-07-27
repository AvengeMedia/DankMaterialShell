.pragma library

function findParentFlickable(item) {
    while (item) {
        if (item.hasOwnProperty("contentY") && item.hasOwnProperty("contentItem"))
            return item;
        item = item.parent;
    }
    return null;
}

function findSettings(item) {
    while (item) {
        if (item.saveValue !== undefined && item.loadValue !== undefined)
            return item;
        item = item.parent;
    }
    return null;
}

function normalizePinList(value) {
    if (Array.isArray(value))
        return value.filter(v => v);
    if (typeof value === "string" && value.length > 0)
        return [value];
    return [];
}
