.import qs.Common as Common
.import qs.Modules.ControlCenter as ControlCenter
.import "../../../Common/GridLayout.js" as GridLayout

function isSliderWidget(id) {
    return id === "volumeSlider" || id === "brightnessSlider" || id === "inputVolumeSlider";
}

function sizeSpec(id, columns, rows = Infinity) {
    return {
        "w": 4,
        "h": 1,
        "minW": 1,
        "maxW": columns,
        "minH": 1,
        "maxH": rows,
        "step": ControlCenter.CcMetrics.gridStep
    };
}

function clampSize(widget, columns, rows = Infinity) {
    const spec = sizeSpec(widget.id || "", columns, rows);
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
    const widget = Object.assign({
        "id": widgetId,
        "enabled": true
    }, clampSize({
        "id": widgetId
    }, columns));

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

function setLayout(widgets) {
    Common.SettingsData.set("controlCenterWidgets", widgets);
}

function resetToDefault(columns) {
    const ids = ["volumeSlider", "brightnessSlider", "wifi", "bluetooth", "audioOutput", "audioInput", "nightMode", "darkMode"];
    Common.SettingsData.set("controlCenterWidgets", ids.map(id => Object.assign({
            "id": id,
            "enabled": true
        }, clampSize({
            "id": id
        }, columns))));
}

function clearAll() {
    Common.SettingsData.set("controlCenterWidgets", []);
}
