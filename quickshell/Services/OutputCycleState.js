.pragma library

function emptyState() {
    return {
        ring: [],
        selected: "",
        pending: ""
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
    if (targetOutput.enabled)
        return result(withState(state, { selected: target }), "accepted", disableOthers(outputs, target));

    return result(withState(state, { pending: target }), "accepted", [{ id: target, enabled: true }]);
}

function handleOutputsChanged(state, outputs) {
    const ring = outputNames(outputs);
    if (ring.length === 0)
        return result(state, "", []);

    let nextState = state;
    let intents = [];
    if (state.pending) {
        const pendingOutput = findOutput(outputs, state.pending);
        if (!pendingOutput) {
            nextState = withState(nextState, { pending: "" });
        } else if (pendingOutput.enabled) {
            nextState = withState(nextState, {
                pending: "",
                selected: pendingOutput.id
            });
            intents = disableOthers(outputs, pendingOutput.id);
        }
    }

    if (!nextState.pending && nextState.selected && !findOutput(outputs, nextState.selected) && !firstEnabled(outputs)) {
        const fallback = previousConnectedOutput(state.ring, nextState.selected, outputs);
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

function previousConnectedOutput(ring, selected, outputs) {
    const selectedIndex = ring.indexOf(selected);
    if (selectedIndex < 0)
        return null;
    for (let offset = 1; offset < ring.length; offset++) {
        const candidate = findOutput(outputs, ring[(selectedIndex - offset + ring.length) % ring.length]);
        if (candidate)
            return candidate;
    }
    return null;
}

function withState(state, changes) {
    return {
        ring: changes.ring !== undefined ? changes.ring : state.ring,
        selected: changes.selected !== undefined ? changes.selected : state.selected,
        pending: changes.pending !== undefined ? changes.pending : state.pending
    };
}

function result(state, status, intents) {
    return {
        state: state,
        status: status,
        intents: intents
    };
}
