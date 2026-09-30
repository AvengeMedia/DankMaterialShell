.import qs.Common as Common
.import qs.Services as Services
.import qs.Modules.ControlCenter as ControlCenter
.import "../../../Common/GridLayout.js" as GridLayout

var OPTION_IDS = ["diskUsage", "brightnessSlider", "idleInhibitor", "user", "runningApps"];
var ACTION_IDS = ["settings", "lock", "power"];
var BUTTON_IDS = ACTION_IDS.concat(["edit"]);
var SMALL_BY_DEFAULT = BUTTON_IDS.concat(["runningApps"]);
var CARD_IDENTITY = "user";
var USER_SHAPES = ["circle", "cookie4", "cookie7", "cookie12", "clover4", "clover8", "sunny", "pentagon", "arch", "slanted", "gem", "square"];

function isSliderWidget(id) {
    return id === "volumeSlider" || id === "brightnessSlider" || id === "inputVolumeSlider";
}

function isButton(id) {
    return BUTTON_IDS.includes(id);
}

// A "user" entry marks where the identity sits among the card's buttons.
function cardOrder(widget) {
    const saved = Array.isArray(widget?.actions) ? widget.actions : [];
    const order = saved.filter((id, i) => (id === CARD_IDENTITY || BUTTON_IDS.includes(id)) && saved.indexOf(id) === i);
    return order.includes(CARD_IDENTITY) ? order : [CARD_IDENTITY].concat(order);
}

function cardActions(widget) {
    return cardOrder(widget).filter(id => id !== CARD_IDENTITY);
}

function actionColumns(rows, count) {
    return count > 0 ? Math.ceil(count / Math.max(1, Math.min(count, Math.floor(Number(rows) || 1)))) : 0;
}

function cardColumns(order, rows) {
    const split = order.indexOf(CARD_IDENTITY);
    return actionColumns(rows, split) + actionColumns(rows, order.length - split - 1);
}

function moveInOrder(order, id, targetId) {
    const from = order.indexOf(id);
    const to = order.indexOf(targetId);
    if (from < 0 || to < 0 || from === to)
        return order;
    const moved = order.slice();
    moved.splice(from, 1);
    moved.splice(to, 0, id);
    return moved;
}

function placedIds(widgets) {
    return (widgets || []).reduce((ids, widget) => ids.concat([widget?.id], cardActions(widget)), []);
}

function triggerButton(host, id) {
    switch (id) {
    case "lock":
        host?.lockRequested();
        return;
    case "power":
        host?.powerRequested();
        return;
    case "settings":
        host?.settingsRequested();
        return;
    case "edit":
        host?.editRequested();
        return;
    }
}

function canShrink(id) {
    return id !== "user" && !isSliderWidget(id);
}

function isSmall(widget, rows) {
    return widget?.small === true && rows === 1 && canShrink(widget.id);
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
    if (widget?.id === "user") {
        spec.w = (Number.isFinite(columns) ? columns : ControlCenter.CcMetrics.defaultColumns) - ACTION_IDS.length;
        spec.minW = Math.min(columns, 1 + cardColumns(cardOrder(widget), widget.h));
    }
    if (widget?.id === "runningApps")
        spec.w = Number.isFinite(columns) ? columns : ControlCenter.CcMetrics.defaultColumns;
    if (isButton(widget?.id))
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
    if (SMALL_BY_DEFAULT.includes(widgetId))
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

// A button lives in the card or the grid, never both; returns the card's index since tiles moving in or out shift it.
function setCardAction(index, id, enabled, columns) {
    const widgets = Common.SettingsData.controlCenterWidgets.slice();
    const card = widgets[index];
    if (!card)
        return index;
    const before = cardOrder(card);
    const order = before.filter(action => action !== id).concat(enabled ? [id] : []);
    const width = clampSize(card, columns).w;
    const w = Math.max(1, Math.min(columns, width + cardColumns(order, card.h) - cardColumns(before, card.h)));
    const updated = Object.assign({}, card, {
        "actions": order,
        "w": w
    });
    widgets[index] = updated;
    if (enabled)
        return commitCard(widgets.filter(widget => widget?.id !== id), updated);
    if (!before.includes(id) || placedIds(widgets).includes(id))
        return commitCard(widgets, updated);

    const tile = Object.assign(defaultWidget(id, columns), {
        "small": true
    });
    const leading = before.indexOf(id) < before.indexOf(CARD_IDENTITY);
    const freed = width - w;
    if (isUnplaced(card)) {
        widgets.splice(leading ? index : index + 1, 0, tile);
    } else if (freed > 0) {
        tile.col = leading ? card.col : card.col + w;
        tile.row = card.row;
        if (leading)
            updated.col = card.col + freed;
        widgets.splice(index + 1, 0, tile);
    } else {
        widgets.push(tile);
    }
    return commitCard(widgets, updated);
}

function commitCard(widgets, card) {
    Common.SettingsData.set("controlCenterWidgets", widgets);
    return widgets.indexOf(card);
}

function setLayout(widgets) {
    Common.SettingsData.set("controlCenterWidgets", widgets);
}

function resetToDefault() {
    Common.SettingsData.resetToDefault(["controlCenterWidgets", "controlCenterColumns"]);
}

function clearAll() {
    Common.SettingsData.set("controlCenterWidgets", []);
}
