.pragma library

const edges = ["top", "bottom", "left", "right"];

function edgeName(position) {
    return typeof position === "number" ? (edges[position] ?? "") : "";
}

function option(config, key, defaults, fallback) {
    return config?.[key] === undefined ? (defaults?.[key] ?? fallback) : config[key];
}

function screenModelIndex(screen, screens) {
    if (!screen?.model)
        return -1;
    const matches = screens.filter(candidate => candidate.model === screen.model).slice().sort((a, b) => a.x - b.x || a.y - b.y);
    return matches.length > 1 ? matches.findIndex(candidate => candidate.name === screen.name) : -1;
}

function screenMatches(screen, preferences, screens, displayNameMode) {
    if (!screen)
        return false;
    const modelIndex = screenModelIndex(screen, screens);
    const displayName = displayNameMode === "model" && screen.model ? screen.model + (modelIndex >= 0 ? "-" + modelIndex : "") : screen.name;
    return preferences.some(pref => {
        if (typeof pref === "string")
            return pref === "all" || pref === screen.name || pref === (displayNameMode === "model" ? displayName : screen.model);
        if (displayNameMode !== "model")
            return pref.name === screen.name;
        return !!pref.model && !!screen.model && pref.model === screen.model && (pref.modelIndex === undefined || pref.modelIndex === modelIndex);
    });
}

function coversScreen(config, screen, screens, displayNameMode) {
    const preferences = config?.screenPreferences || ["all"];
    return preferences.includes("all") || screenMatches(screen, preferences, screens, displayNameMode) || ((config?.showOnLastDisplay ?? false) && screens.length === 1);
}

function islandMetrics(config, defaults) {
    const value = key => config?.[key] ?? defaults[key];
    const reserve = Math.max(24, Math.min(128, value("islandReserveThickness")));
    const compact = Math.max(24, Math.min(72, value("islandCompactThickness")));
    const gap = Math.max(0, Math.min(48, value("islandOuterGap")));
    return { reserve, compact, gap, thickness: Math.max(reserve, gap + compact) };
}

function islandThickness(config, defaults) {
    return islandMetrics(config, defaults).thickness;
}

function resolveScreen(inputs, screen, options) {
    const assigned = inputs.filter(input => coversScreen(input.config, screen, options.screens, options.displayNameMode));
    const enabled = assigned.filter(input => input.config.enabled);
    const islands = enabled.filter(input => input.config.island === true);
    const bars = enabled.filter(input => input.config.island !== true);
    const frameConfigured = screenMatches(screen, options.framePreferences, options.screens, options.displayNameMode);
    const frameStyled = options.effectiveFrameEnabled && frameConfigured;
    const frameHosted = options.effectiveConnected && frameStyled;
    const bands = {};
    const instances = [];
    for (const edge of edges) {
        const selected = enabled.filter(input => (edgeName(input.config.position ?? 0) || "top") === edge);
        const active = selected.filter(input => input.config.island !== true);
        const hosted = active.filter(input => !input.config.useOverlayLayer);
        let offset = 0;
        let reservation = 0;
        for (const input of selected) {
            const config = input.config;
            const kind = config.island === true ? "island" : frameHosted && !config.useOverlayLayer ? "frame" : "bar";
            const spacing = frameStyled || config.attachToScreenEdge ? 0 : config.spacing ?? 4;
            const thickness = kind === "island" ? input.islandThickness : frameStyled ? Math.round(Math.round(options.frameBarSize * (screen.scale || 1)) / (screen.scale || 1)) : input.barThickness + spacing + (config.bottomGap ?? 0);
            const paintedThickness = thickness + (kind !== "island" && !frameStyled ? input.wingSize ?? 0 : 0);
            const reserves = kind === "island" ? !(input.islandFloating ?? config.islandFloating)
                : config.visible !== false && (!config.autoHide || frameStyled);
            const contribution = reserves ? Math.max(0, offset + thickness - reservation) : 0;
            instances.push({
                key: JSON.stringify([screen.name, config.id]), screenName: screen.name,
                barId: config.id, configOrder: inputs.indexOf(input), edge, kind,
                row: selected.indexOf(input), rowThickness: paintedThickness, rowOffset: offset,
                reservation: contribution
            });
            offset += paintedThickness;
            reservation += contribution;
        }
        const island = selected.find(input => input.config.island === true);
        bands[edge] = {
            island: island?.config ?? null,
            islandThickness: selected.filter(input => input.config.island === true).reduce((sum, input) => sum + input.islandThickness, 0),
            bars: active.map(input => input.config), hostedBars: hosted.map(input => input.config),
            occupancy: offset, reservation: Math.max(frameStyled ? options.frameThickness : 0, reservation),
            frameReservation: active.length ? Math.max(options.frameThickness, offset) : options.frameThickness,
            frameExclusionEnabled: frameStyled && (!active.length || (frameHosted && !active.some(input => input.config.useOverlayLayer)))
        };
    }
    const manualPlacement = edges.some(edge => instances.filter(instance => instance.edge === edge).length > 1);
    if (!manualPlacement && frameStyled) {
        for (const instance of instances) {
            if (instance.kind !== "island")
                continue;
            const band = bands[instance.edge];
            instance.rowOffset += options.frameThickness;
            band.occupancy += options.frameThickness;
            band.reservation = options.frameThickness + instance.reservation;
        }
    }
    for (const instance of instances) {
        const band = bands[instance.edge];
        instance.exclusiveZone = manualPlacement || instance.kind === "frame" ? -1 : instance.reservation || -1;
        instance.exclusionSize = manualPlacement && !frameStyled && instance.row === 0 ? band.reservation : 0;
        instance.paintedBounds = rowBounds(screen, instance.edge, instance.rowOffset, instance.rowThickness, bands);
        instance.margins = { top: 0, bottom: 0, left: 0, right: 0 };
        if (!manualPlacement)
            continue;
        instance.margins[instance.edge] = instance.rowOffset;
        if (instance.edge === "left" || instance.edge === "right") {
            instance.margins.top = bands.top.occupancy;
            instance.margins.bottom = bands.bottom.occupancy;
        }
    }
    if (manualPlacement && frameStyled) {
        for (const edge of edges)
            bands[edge].frameExclusionEnabled = true;
    }
    instances.sort((a, b) => a.configOrder - b.configOrder);
    return { screen, assigned, bars, islands, instances, edges: bands, frameConfigured, frameStyled, manualPlacement };
}

function adjacentBar(layout, edge, config) {
    if (!layout || config?.autoHide)
        return null;
    const position = edges.indexOf(edge);
    return layout.bars.find(input => input.config.id !== config?.id && !input.config.autoHide && (input.config.visible ?? true) && input.config.position === position) ?? null;
}

function adjacentInfo(layout, config, defaults) {
    const result = { topBar: 0, bottomBar: 0, leftBar: 0, rightBar: 0 };
    if (!layout || !config || config.autoHide)
        return result;
    for (const edge of edges) {
        const rows = layout.instances.filter(instance => instance.edge === edge && instance.barId !== config.id);
        result[edge + "Bar"] = rows.reduce((sum, instance) => {
            const input = layout.assigned.find(input => input.config.id === instance.barId);
            const other = input.config;
            if (instance.kind === "island")
                return sum + instance.rowThickness;
            if (other.autoHide || other.visible === false)
                return sum;
            const spacing = option(other, "spacing", defaults, 4);
            const gap = option(other, "popupGapsAuto", defaults, true) ? Math.max(4, spacing) : option(other, "popupGapsManual", defaults, 4);
            return sum + input.popupThickness + spacing + gap;
        }, 0);
    }
    return result;
}

function barBounds(layout, thickness, position, config, defaults, connected, wingSize) {
    const empty = { x: 0, y: 0, width: 0, height: 0, wingSize: 0 };
    if (!layout || !edgeName(position))
        return empty;
    const instance = layout.instances.find(instance => instance.barId === config?.id);
    return Object.assign(rowBounds(layout.screen, edgeName(position), instance?.rowOffset ?? 0, thickness + wingSize, layout.edges), { wingSize });
}

function rowBounds(screen, edge, offset, thickness, bands) {
    const horizontal = edge === "top" || edge === "bottom";
    const width = horizontal ? screen.width : thickness;
    const height = horizontal ? thickness : Math.max(0, screen.height - bands.top.occupancy - bands.bottom.occupancy);
    return {
        x: horizontal ? 0 : edge === "right" ? screen.width - width - offset : offset,
        y: horizontal ? edge === "bottom" ? screen.height - height - offset : offset : bands.top.occupancy,
        width, height
    };
}

function surfaceOrigin(layout, width, height, anchors, margins) {
    const screen = layout.screen;
    const left = margins?.left ?? 0;
    const right = margins?.right ?? 0;
    const top = margins?.top ?? 0;
    const bottom = margins?.bottom ?? 0;
    let x = anchors.right && !anchors.left ? screen.width - width - right : left;
    let y = anchors.bottom && !anchors.top ? screen.height - height - bottom : top;
    if (anchors.left && anchors.right)
        x += Math.min(Math.max(0, screen.width - width - left - right), layout.edges?.left?.reservation ?? 0);
    if (anchors.top && anchors.bottom)
        y += Math.min(Math.max(0, screen.height - height - top - bottom), layout.edges?.top?.reservation ?? 0);
    return { x, y };
}

function popupTrigger(pos, screen, thickness, width, spacing, position, config, defaults, connected) {
    const bottomGap = connected ? 0 : Math.max(0, option(config, "bottomGap", defaults, 0));
    const autoGap = option(config, "popupGapsAuto", defaults, true);
    const gap = connected ? 0 : autoGap ? Math.max(4, spacing) : option(config, "popupGapsManual", defaults, 4);
    const offset = thickness + (connected ? 0 : spacing) + gap;
    switch (position) {
    case 2:
        return { x: offset, y: pos.y, width };
    case 3:
        return { x: (screen?.width || 0) - offset, y: pos.y, width };
    case 1:
        return { x: pos.x, y: (screen?.height || 0) - offset - bottomGap, width };
    default:
        return { x: pos.x, y: offset + bottomGap, width };
    }
}

function availablePositions(layouts, config) {
    return [0, 1, 2, 3];
}
