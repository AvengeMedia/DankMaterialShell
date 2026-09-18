.import qs.Common as Common
.import "layout.js" as LayoutUtils

function addWidget(widgetId) {
    var widgets = Common.SettingsData.controlCenterWidgets.slice()
    var widget = {
        "id": widgetId,
        "enabled": true,
        "width": 50
    }

    if (widgetId === "diskUsage") {
        widget.instanceId = generateUniqueId()
        widget.mountPath = "/"
        widget.showMountPath = true
    }

    if (widgetId === "brightnessSlider") {
        widget.instanceId = generateUniqueId()
        widget.deviceName = ""
    }

    widgets.push(widget)
    Common.SettingsData.set("controlCenterWidgets", widgets)
}

function generateUniqueId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2)
}

function removeWidget(index) {
    var widgets = Common.SettingsData.controlCenterWidgets.slice()
    if (index >= 0 && index < widgets.length) {
        widgets.splice(index, 1)
        Common.SettingsData.set("controlCenterWidgets", widgets)
    }
}

function setWidgetWidth(index, width) {
    const widgets = Common.SettingsData.controlCenterWidgets.slice()
    const widget = widgets[index]
    if (!widget || !LayoutUtils.widgetWidths(widget.id).includes(width) || (widget.width || 50) === width)
        return
    widgets[index] = Object.assign({}, widget, { "width": width })
    Common.SettingsData.set("controlCenterWidgets", widgets)
}

function reorderWidgets(newOrder) {
    Common.SettingsData.set("controlCenterWidgets", newOrder)
}

function resetToDefault() {
    const defaultWidgets = [
        {"id": "volumeSlider", "enabled": true, "width": 50},
        {"id": "brightnessSlider", "enabled": true, "width": 50},
        {"id": "wifi", "enabled": true, "width": 50},
        {"id": "bluetooth", "enabled": true, "width": 50},
        {"id": "audioOutput", "enabled": true, "width": 50},
        {"id": "audioInput", "enabled": true, "width": 50},
        {"id": "nightMode", "enabled": true, "width": 50},
        {"id": "darkMode", "enabled": true, "width": 50}
    ]
    Common.SettingsData.set("controlCenterWidgets", defaultWidgets)
}

function clearAll() {
    Common.SettingsData.set("controlCenterWidgets", [])
}
