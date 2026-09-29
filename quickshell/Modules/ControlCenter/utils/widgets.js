.import qs.Common as Common
.import qs.Modules.ControlCenter as ControlCenter
.import "../../../Common/GridLayout.js" as GridLayout

var PINNED_IDS = ["quickActions"];
var OPTION_IDS = ["diskUsage", "brightnessSlider", "idleInhibitor", "userCard", "quickActions"];
var QUICK_ACTIONS = [
    {
        "id": "lock",
        "icon": "lock",
        "label": "Lock"
    },
    {
        "id": "power",
        "icon": "power_settings_new",
        "label": "Power"
    },
    {
        "id": "settings",
        "icon": "settings",
        "label": "Settings"
    },
    {
        "id": "edit",
        "icon": "edit",
        "label": "Edit"
    }
];
var QUICK_ACTION_IDS = QUICK_ACTIONS.map(action => action.id);

function isSliderWidget(id) {
    return id === "volumeSlider" || id === "brightnessSlider" || id === "inputVolumeSlider";
}

function isPinned(id) {
    return PINNED_IDS.includes(id);
}

function hasOptions(id) {
    return OPTION_IDS.includes(id) || String(id ?? "").startsWith("plugin_");
}

function quickActions(widgetData) {
    const saved = Array.isArray(widgetData?.actions) ? widgetData.actions : [];
    const out = saved.filter(action => QUICK_ACTION_IDS.includes(action?.id)).map(action => ({
                "id": action.id,
                "enabled": action.id === "edit" || action.enabled !== false
            }));
    for (const id of QUICK_ACTION_IDS) {
        if (!out.some(action => action.id === id))
            out.push({
                "id": id,
                "enabled": true
            });
    }
    return out;
}

function enabledQuickActions(widgetData) {
    return quickActions(widgetData).filter(action => action.enabled);
}

function quickActionIcon(id) {
    return QUICK_ACTIONS.find(action => action.id === id)?.icon ?? "";
}

function quickActionLabel(id) {
    return QUICK_ACTIONS.find(action => action.id === id)?.label ?? "";
}

function defaultWidget(id, columns) {
    return Object.assign({
        "id": id,
        "enabled": true
    }, clampSize({
        "id": id
    }, columns));
}

function pinnedWidgets(columns) {
    return PINNED_IDS.map(id => defaultWidget(id, columns));
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
    switch (widget?.id) {
    case "userCard":
        spec.w = Math.max(1, (Number.isFinite(columns) ? columns : ControlCenter.CcMetrics.defaultColumns) - ControlCenter.CcMetrics.actionSpan(2));
        spec.h = ControlCenter.CcMetrics.actionSpan(2);
        return spec;
    case "quickActions":
        spec.w = ControlCenter.CcMetrics.actionSpan(2);
        spec.h = ControlCenter.CcMetrics.actionSpan(2);
        return spec;
    default:
        return spec;
    }
}

function clampSize(widget, columns, rows = Infinity) {
    const spec = sizeSpec(widget, columns, rows);
    const size = {
        "w": GridLayout.dimension(widget.w, spec.minW, spec.maxW, spec.w, spec.step),
        "h": GridLayout.dimension(widget.h, spec.minH, spec.maxH, spec.h, spec.step)
    };
    if (widget.id === "quickActions") {
        const count = enabledQuickActions(widget).length;
        const capacity = ControlCenter.CcMetrics.actionCapacity(size.w);
        const neededRows = ControlCenter.CcMetrics.actionSpan(Math.ceil(count / capacity));
        if (neededRows <= rows) {
            size.h = Math.max(size.h, neededRows);
            return size;
        }
        size.h = rows;
        size.w = Math.min(columns, Math.max(size.w, ControlCenter.CcMetrics.actionSpan(Math.ceil(count / ControlCenter.CcMetrics.actionCapacity(rows)))));
        return size;
    }
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
    if (index < 0 || index >= widgets.length || isPinned(widgets[index]?.id))
        return;
    widgets.splice(index, 1);
    Common.SettingsData.set("controlCenterWidgets", widgets);
}

function setLayout(widgets) {
    Common.SettingsData.set("controlCenterWidgets", widgets);
}

function resetToDefault(columns) {
    const ids = ["userCard", "quickActions", "volumeSlider", "brightnessSlider", "wifi", "bluetooth", "audioOutput", "audioInput", "nightMode", "darkMode"];
    Common.SettingsData.set("controlCenterWidgets", ids.map(id => defaultWidget(id, columns)));
}

function clearAll(columns) {
    Common.SettingsData.set("controlCenterWidgets", pinnedWidgets(columns));
}
