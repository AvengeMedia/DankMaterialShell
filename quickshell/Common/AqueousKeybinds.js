function copy(value) {
    return JSON.parse(JSON.stringify(value));
}

function inventory(snapshot) {
    if (snapshot?.provider !== "aqueous" || typeof snapshot.generation !== "string" || !snapshot.generation || !snapshot.binds || Array.isArray(snapshot.binds))
        throw new Error("invalid Aqueous keybind snapshot");
    if (!Array.isArray(snapshot.binds.Compositor) || !Array.isArray(snapshot.binds.Custom))
        throw new Error("missing Aqueous keybind inventory");
    return Object.keys(snapshot.binds).sort().map(category => {
        if (!Array.isArray(snapshot.binds[category]))
            throw new Error("invalid Aqueous keybind category");
        return [category, snapshot.binds[category].map(bind => {
            if (typeof bind.key !== "string" || typeof bind.action !== "string")
                throw new Error("invalid Aqueous binding");
            return [bind.key, bind.action, bind.source || ""];
        })];
    });
}

function unchanged(baseline, current) {
    return JSON.stringify(inventory(baseline)) === JSON.stringify(inventory(current));
}

function changes(baseline, current) {
    const flatten = snapshot => inventory(snapshot).reduce((all, group) => all.concat(group[1].map(bind => [group[0], bind])), []);
    const before = flatten(baseline);
    const after = flatten(current);
    const differences = [];
    for (let i = 0; i < Math.max(before.length, after.length); i++) {
        if (JSON.stringify(before[i]) === JSON.stringify(after[i]))
            continue;
        differences.push({before: before[i]?.[1] || null, after: after[i]?.[1] || null});
    }
    return differences;
}

function bindings(snapshot, key) {
    if (!key)
        return [];
    inventory(snapshot);
    return Object.values(snapshot.binds).reduce((matches, category) => matches.concat(category.filter(bind => bind.key === key)), []);
}

function issue(draft, current, reviewing) {
    inventory(current);
    if (!["set", "remove", "reset"].includes(draft.operation))
        return "invalid_binding";
    const original = bindings(current, draft.originalKey);
    if (draft.originalKey && original.length !== 1)
        return original.length ? "ambiguous_target" : "target_removed";
    if (!reviewing && draft.originalKey && original[0].action !== draft.originalAction)
        return "target_changed";
    if (draft.operation !== "set")
        return draft.originalKey ? "" : "target_removed";
    const data = draft.data;
    if (!data?.key || !data.action)
        return "invalid_binding";
    if (data.key !== draft.originalKey && bindings(current, data.key).length)
        return "destination_occupied";
    if (!data.action.startsWith("spawn ") && !current.binds.Compositor.some(bind => bind.action === data.action))
        return "invalid_action";
    return "";
}

function argumentsFor(draft, generation) {
    const args = ["dms", "keybinds", draft.operation, "aqueous", draft.operation === "set" ? draft.data.key : draft.originalKey];
    if (draft.operation === "set") {
        args.push(draft.data.action);
        if (draft.originalKey && draft.originalKey !== draft.data.key)
            args.push("--replace-key", draft.originalKey);
    }
    args.push("--expected-generation", generation, "--json");
    return args;
}
