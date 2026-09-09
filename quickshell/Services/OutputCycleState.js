.pragma library

function emptyState() {
    return {
        ring: [],
        selected: "",
        pending: "",
        original: {}
    };
}

function requestCycle(state, outputs, currentOutput) {
    if (state.pending)
        return result(state, "busy", []);

    const ring = outputNames(outputs);
    if (ring.length < 2)
        return result(state, "no-op", []);

    const current = findOutput(outputs, currentOutput) ? currentOutput : (firstEnabled(outputs) || ring[0]);
    const target = ring[(ring.indexOf(current) + 1) % ring.length];
    const targetOutput = findOutput(outputs, target);
    if (targetOutput.enabled) {
        const intents = disableOthers(outputs, target);
        return result(withState(state, { selected: target, original: recordOriginal(state.original, outputs, intents) }), "accepted", intents);
    }

    const intents = [{ id: target, enabled: true }];
    return result(withState(state, { pending: target, original: recordOriginal(state.original, outputs, intents) }), "accepted", intents);
}

function handleOutputsChanged(state, outputs) {
    const ring = outputNames(outputs);
    if (ring.length === 0)
        return result(state, "", []);

    let nextState = withState(state, { original: pruneRestored(state.original, outputs) });
    let intents = [];
    if (state.pending) {
        const pendingOutput = findOutput(outputs, state.pending);
        if (!pendingOutput) {
            nextState = withState(nextState, { pending: "" });
        } else if (pendingOutput.enabled) {
            intents = disableOthers(outputs, pendingOutput.id);
            nextState = withState(nextState, {
                pending: "",
                selected: pendingOutput.id,
                original: recordOriginal(nextState.original, outputs, intents)
            });
        }
    }

    if (!nextState.pending && nextState.selected && !findOutput(outputs, nextState.selected) && !firstEnabled(outputs)) {
        const fallback = previousConnectedOutput(state.ring, nextState.selected, outputs, nextState.original);
        if (fallback) {
            nextState = withState(nextState, { selected: fallback.id });
            intents = intents.concat([{ id: fallback.id, enabled: true }]);
        }
    }

    nextState = withState(nextState, { ring: ring });
    const enabled = firstEnabled(outputs);
    if (enabled && enabledOutputCount(outputs) === 1)
        nextState = withState(nextState, { selected: enabled });
    return result(nextState, "", intents);
}

function clearPending(state) {
    return withState(state, { pending: "" });
}

function outputNames(outputs) {
    return outputs.map(output => output.id).sort((a, b) => a.localeCompare(b));
}

function findOutput(outputs, id) {
    return outputs.find(output => output.id === id);
}

function firstEnabled(outputs) {
    return outputNames(outputs).find(id => findOutput(outputs, id).enabled) || "";
}

function enabledOutputCount(outputs) {
    return outputs.filter(output => output.enabled).length;
}

function disableOthers(outputs, selected) {
    return outputs
        .filter(output => output.enabled && output.id !== selected)
        .map(output => ({ id: output.id, enabled: false }));
}

function previousConnectedOutput(ring, selected, outputs, original) {
    const selectedIndex = ring.indexOf(selected);
    if (selectedIndex < 0)
        return null;
    for (let offset = 1; offset < ring.length; offset++) {
        const candidate = findOutput(outputs, ring[(selectedIndex - offset + ring.length) % ring.length]);
        if (candidate && original[candidate.id] === true)
            return candidate;
    }
    return null;
}

function recordOriginal(original, outputs, intents) {
    const next = Object.assign({}, original);
    for (const intent of intents) {
        if (next[intent.id] === undefined)
            next[intent.id] = findOutput(outputs, intent.id).enabled;
    }
    return next;
}

function pruneRestored(original, outputs) {
    const next = {};
    for (const id in original) {
        const output = findOutput(outputs, id);
        if (!output || output.enabled !== original[id])
            next[id] = original[id];
    }
    return next;
}

function withState(state, changes) {
    return {
        ring: changes.ring !== undefined ? changes.ring : state.ring,
        selected: changes.selected !== undefined ? changes.selected : state.selected,
        pending: changes.pending !== undefined ? changes.pending : state.pending,
        original: changes.original !== undefined ? changes.original : (state.original || {})
    };
}

function result(state, status, intents) {
    return {
        state: state,
        status: status,
        intents: intents
    };
}
