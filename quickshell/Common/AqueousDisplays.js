.pragma library

function fingerprint(outputs) {
    return JSON.stringify(outputs.map(o => ({name: o.name, id: o.id, enabled: o.enabled,
        x: o.x, y: o.y, scale: o.scale, transform: o.transform,
        mode: o.currentMode ? [o.currentMode.width, o.currentMode.height, o.currentMode.refresh] : null,
        adaptiveSync: o.adaptiveSync})).sort((a, b) => a.name.localeCompare(b.name)));
}

function heads(outputs) {
    return outputs.map(o => ({name: o.name, enabled: o.enabled,
        modeId: o.currentMode?.id, position: {x: o.x, y: o.y},
        scale: o.scale, transform: o.transform, adaptiveSync: o.adaptiveSync}));
}

function matches(candidate, actual, original) {
    if (original.length !== actual.length || original.some(o => !actual.some(a => a.id === o.id && a.name === o.name)))
        return false;
    return candidate.every(h => {
        const output = actual.find(o => o.name === h.name);
        if (!output || output.enabled !== h.enabled)
            return false;
        if (!h.enabled)
            return true;
        const mode = h.customMode || original.find(o => o.name === h.name)?.modes?.find(m => m.id === h.modeId);
        return output.x === h.position.x && output.y === h.position.y
            && Math.abs(output.scale - h.scale) < 0.0001 && output.transform === h.transform
            && !!mode && output.currentMode?.width === mode.width && output.currentMode?.height === mode.height
            && output.currentMode?.refresh === mode.refresh;
    });
}

function request(snapshot, outputs, original) {
    if (!snapshot.capabilities?.includes("monitor_modes"))
        throw new Error("unsupported: monitor_modes");
    const raw = (snapshot.raw_files?.outputs || "") + "\n" + (snapshot.raw_files?.wm || "");
    if (/^\s*edid\s*=/m.test(raw))
        throw new Error("unsupported: this aqueous-config version does not expose EDID monitor edits");
    const transforms = ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"];
    const changes = [];
    if ((snapshot.monitors || []).some(m => /[*?\[]/.test(m.name)))
        throw new Error("unsupported: reconcile wildcard monitor configuration before persisting displays");
    for (const output of outputs) {
        const before = original.find(o => o.name === output.name);
        if (!before)
            throw new Error("conflict: output changed during preview");
        if (output.enabled !== before.enabled)
            throw new Error("unsupported: this aqueous-config version cannot persist output enablement");
        if (output.adaptiveSync !== before.adaptiveSync)
            throw new Error("unsupported: this aqueous-config version cannot persist adaptive sync");
        if (!output.enabled)
            continue;
        const configured = (snapshot.monitors || []).filter(m => m.name === output.name);
        if (configured.length > 1)
            throw new Error("conflict: multiple configured monitor entries");
        const monitor = configured[0];
        if (Math.abs(output.scale - (monitor?.scale ?? 1)) > 0.0001)
            throw new Error("unsupported: this aqueous-config version cannot persist output scale");
        const mode = output.currentMode;
        if (!mode)
            throw new Error("unavailable: output mode");
        changes.push({id: monitor?.id || "live:" + output.name, name: output.name,
            x: output.x, y: output.y, transform: transforms[output.transform],
            mode: mode.width + "x" + mode.height + "@" + (mode.refresh / 1000)});
    }
    return {expected_generation: snapshot.generation, monitor_changes: changes, create_user_override: true};
}
