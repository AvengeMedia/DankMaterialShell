.import qs.Common as Common
.import qs.Services as Services
.import qs.Modules.ControlCenter as ControlCenter
.import "../../../Common/GridLayout.js" as GridLayout

var OPTION_IDS = ["diskUsage", "brightnessSlider", "idleInhibitor", "user"];
var ACTION_IDS = ["settings", "lock", "power"];
var FOOTER_CELLS = {
    "runningApps": 4,
    "user": 3,
    "volumeSlider": 4,
    "inputVolumeSlider": 4,
    "brightnessSlider": 4
};
var USER_SHAPES = ["circle", "cookie4", "cookie7", "cookie12", "clover4", "clover8", "sunny", "pentagon", "arch", "slanted", "gem", "square"];

function isSliderWidget(id) {
    return id === "volumeSlider" || id === "brightnessSlider" || id === "inputVolumeSlider";
}

function canShrink(id) {
    return id !== "user" && !isSliderWidget(id);
}

function isSmall(widget, rows) {
    return widget?.small === true && rows === 1 && canShrink(widget.id);
}

function inFooter(widget) {
    return !!widget?.footer;
}

function footerMinCells(id) {
    return isSliderWidget(id) ? 3 : 1;
}

// `footerW` outlives the footer flag, so an item dragged back in returns at the width it left with.
function footerCells(widget) {
    return Math.max(footerMinCells(widget?.id), Math.round(Number(widget?.footerW) || FOOTER_CELLS[widget?.id] || 1));
}

function footerFills(widget) {
    return widget?.footerFill === true;
}

function footerEnds(widget) {
    return widget?.footerEnd === true;
}

function fitFooterCells(sizes, mins, capacity) {
    const fitted = sizes.slice();
    let over = fitted.reduce((sum, cells) => sum + cells, 0) - capacity;
    while (over > 0) {
        const widest = fitted.reduce((best, cells, i) => cells > mins[i] && (best < 0 || cells > fitted[best]) ? i : best, -1);
        if (widest < 0)
            break;
        fitted[widest]--;
        over--;
    }
    for (let i = fitted.length - 1; over > 0 && i >= 0; i--) {
        over -= fitted[i];
        fitted[i] = 0;
    }
    return fitted;
}

function isShown(widget) {
    switch (widget?.id) {
    case "battery":
        return Services.BatteryService.batteryAvailable || Services.PowerProfileWatcher.available;
    case "diskUsage":
        return Services.DgopService.dgopAvailable;
    default:
        return true;
    }
}

function isUnplaced(widget) {
    return !Number.isFinite(widget?.col) || !Number.isFinite(widget?.row);
}

function hasOptions(id) {
    return OPTION_IDS.includes(id) || String(id ?? "").startsWith("plugin_");
}

function filterWidgets(widgets, query) {
    const needle = query.trim().toLowerCase();
    if (!needle)
        return widgets;
    return widgets.filter(widget => [widget.text, widget.description, widget.id].some(value => (value || "").toLowerCase().includes(needle)));
}

function nextUserShape(shape) {
    return USER_SHAPES[(USER_SHAPES.indexOf(shape) + 1) % USER_SHAPES.length];
}

function defaultWidget(id, columns) {
    return Object.assign({
        "id": id,
        "enabled": true
    }, clampSize({
        "id": id
    }, columns));
}

function sizeSpec(widget, columns, rows = Infinity) {
    const spec = {
        "w": 4,
        "h": 1,
        "minW": 1,
        "maxW": columns,
        "minH": 1,
        "maxH": rows,
        "step": ControlCenter.CcMetrics.gridStep
    };
    if (widget?.id === "user")
        spec.w = (Number.isFinite(columns) ? columns : ControlCenter.CcMetrics.defaultColumns) - ACTION_IDS.length;
    if (ACTION_IDS.includes(widget?.id))
        spec.w = 1;
    return spec;
}

function clampSize(widget, columns, rows = Infinity) {
    const spec = sizeSpec(widget, columns, rows);
    const size = {
        "w": GridLayout.dimension(widget.w, spec.minW, spec.maxW, spec.w, spec.step),
        "h": GridLayout.dimension(widget.h, spec.minH, spec.maxH, spec.h, spec.step)
    };
    if (!isSliderWidget(widget.id) || size.w >= 2 || size.h >= 2)
        return size;
    if (rows > 1)
        return {
            "w": 1,
            "h": 2
        };
    return {
        "w": Math.min(2, columns),
        "h": 1
    };
}

function addWidget(widgetId, columns) {
    const widgets = Common.SettingsData.controlCenterWidgets.slice();
    const widget = defaultWidget(widgetId, columns);
    if (ACTION_IDS.includes(widgetId))
        widget.small = true;

    if (widgetId === "diskUsage") {
        widget.instanceId = generateUniqueId();
        widget.mountPath = "/";
        widget.showMountPath = true;
    }

    if (widgetId === "brightnessSlider") {
        widget.instanceId = generateUniqueId();
        widget.deviceName = "";
    }

    widgets.push(widget);
    Common.SettingsData.set("controlCenterWidgets", widgets);
}

function generateUniqueId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
}

function removeWidget(index) {
    const widgets = Common.SettingsData.controlCenterWidgets.slice();
    if (index < 0 || index >= widgets.length)
        return;
    widgets.splice(index, 1);
    Common.SettingsData.set("controlCenterWidgets", widgets);
}

function setOption(index, key, value) {
    const widgets = Common.SettingsData.controlCenterWidgets.slice();
    if (index < 0 || index >= widgets.length)
        return;
    widgets[index] = Object.assign({}, widgets[index], {
        [key]: value
    });
    Common.SettingsData.set("controlCenterWidgets", widgets);
}

// Footer order is the saved order of footer entries, so the moved entry lands just before `beforeIndex`.
function moveToFooter(index, beforeIndex, cells, end) {
    const widgets = Common.SettingsData.controlCenterWidgets.slice();
    const widget = widgets[index];
    if (!widget)
        return;
    const before = beforeIndex === index ? null : widgets[beforeIndex] ?? null;
    widgets.splice(index, 1);
    const at = before ? widgets.indexOf(before) : widgets.length;
    const moved = Object.assign({}, widget, {
        "footer": true,
        "footerW": cells
    });
    if (end)
        moved.footerEnd = true;
    else
        delete moved.footerEnd;
    widgets.splice(at, 0, moved);
    Common.SettingsData.set("controlCenterWidgets", widgets);
}

// Hands spare cells to fill items, the earlier ones taking the remainder.
function spreadFooterFill(cells, fills, spare) {
    const count = fills.filter(Boolean).length;
    if (count === 0 || spare <= 0)
        return cells;
    let left = spare;
    return cells.map((size, i) => {
        if (!fills[i] || size === 0)
            return size;
        const share = Math.ceil(left / count);
        left -= share;
        return size + Math.max(0, share);
    });
}

function setFooterSize(index, cells, fill) {
    const widgets = Common.SettingsData.controlCenterWidgets.slice();
    if (!widgets[index])
        return;
    const widget = Object.assign({}, widgets[index], {
        "footerW": cells
    });
    if (fill)
        widget.footerFill = true;
    else
        delete widget.footerFill;
    widgets[index] = widget;
    Common.SettingsData.set("controlCenterWidgets", widgets);
}

function placeFromFooter(widgets, index, col, row) {
    const tile = Object.assign({}, widgets[index], {
        "col": col,
        "row": row
    });
    delete tile.footer;
    delete tile.footerEnd;
    const placed = widgets.slice();
    placed[index] = tile;
    return placed;
}

function setLayout(widgets) {
    Common.SettingsData.set("controlCenterWidgets", widgets);
}

function resetToDefault() {
    Common.SettingsData.resetToDefault(["controlCenterWidgets", "controlCenterColumns", "controlCenterFooterPosition"]);
}

function clearAll() {
    Common.SettingsData.set("controlCenterWidgets", []);
}
