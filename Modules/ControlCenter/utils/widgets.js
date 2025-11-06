function getWidgetForId(baseWidgetDefinitions, widgetId) {
    return baseWidgetDefinitions.find(w => w.id === widgetId)
}

function addWidget(widgetId) {
    var widgets = SettingsData.controlCenterWidgets.slice()
    var widget = {
        "id": widgetId,
        "enabled": true,
        "width": 50
    }

    if (widgetId === "diskUsage") {
        widget.instanceId = generateUniqueId()
        widget.mountPath = "/"
    }

    if (widgetId === "brightnessSlider") {
        widget.instanceId = generateUniqueId()
        widget.deviceName = ""
    }

    widgets.push(widget)
    SettingsData.set("controlCenterWidgets", widgets)
}

function generateUniqueId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2)
}

function removeWidget(index) {
    var widgets = SettingsData.controlCenterWidgets.slice()
    if (index >= 0 && index < widgets.length) {
        widgets.splice(index, 1)
        SettingsData.set("controlCenterWidgets", widgets)
    }
}

function toggleWidgetSize(index) {
    var widgets = SettingsData.controlCenterWidgets.slice()
    if (index >= 0 && index < widgets.length) {
        const currentWidth = widgets[index].width || 50
        const id = widgets[index].id || ""

        if (id === "wifi" || id === "bluetooth" || id === "audioOutput" || id === "audioInput") {
            widgets[index].width = currentWidth <= 50 ? 100 : 50
        } else {
            if (currentWidth <= 25) {
                widgets[index].width = 50
            } else if (currentWidth <= 50) {
                widgets[index].width = 100
            } else {
                widgets[index].width = 25
            }
        }

        SettingsData.set("controlCenterWidgets", widgets)
    }
}

function reorderWidgets(newOrder) {
    SettingsData.set("controlCenterWidgets", newOrder)
}

function moveWidget(fromIndex, toIndex) {
    let widgets = [...(SettingsData.controlCenterWidgets || [])]
    if (fromIndex >= 0 && fromIndex < widgets.length && toIndex >= 0 && toIndex < widgets.length) {
        const movedWidget = widgets.splice(fromIndex, 1)[0]
        widgets.splice(toIndex, 0, movedWidget)
        SettingsData.set("controlCenterWidgets", widgets)
    }
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
    SettingsData.set("controlCenterWidgets", defaultWidgets)
}

function clearAll() {
    SettingsData.set("controlCenterWidgets", [])
}