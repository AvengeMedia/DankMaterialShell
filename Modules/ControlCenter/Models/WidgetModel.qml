import QtQuick
import qs.Common
import qs.Services
import "../utils/widgets.js" as WidgetUtils

QtObject {
    id: root

    readonly property var baseWidgetDefinitions: [
        {
            "id": "nightMode",
            "text": "Night Mode",
            "description": "Blue light filter",
            "icon": "nightlight",
            "type": "toggle",
            "enabled": DisplayService.automationAvailable,
            "warning": !DisplayService.automationAvailable ? "Requires night mode support" : undefined
        },
        {
            "id": "darkMode",
            "text": "Dark Mode",
            "description": "System theme toggle",
            "icon": "contrast",
            "type": "toggle",
            "enabled": true
        },
        {
            "id": "doNotDisturb",
            "text": "Do Not Disturb",
            "description": "Block notifications",
            "icon": "do_not_disturb_on",
            "type": "toggle",
            "enabled": true
        },
        {
            "id": "idleInhibitor",
            "text": "Keep Awake",
            "description": "Prevent screen timeout",
            "icon": "motion_sensor_active",
            "type": "toggle",
            "enabled": true
        },
        {
            "id": "wifi",
            "text": "Network",
            "description": "Wi-Fi and Ethernet connection",
            "icon": "wifi",
            "type": "connection",
            "enabled": NetworkService.wifiAvailable,
            "warning": !NetworkService.wifiAvailable ? "Wi-Fi not available" : undefined
        },
        {
            "id": "bluetooth",
            "text": "Bluetooth",
            "description": "Device connections",
            "icon": "bluetooth",
            "type": "connection",
            "enabled": BluetoothService.available,
            "warning": !BluetoothService.available ? "Bluetooth not available" : undefined
        },
        {
            "id": "audioOutput",
            "text": "Audio Output",
            "description": "Speaker settings",
            "icon": "volume_up",
            "type": "connection",
            "enabled": true
        },
        {
            "id": "audioInput",
            "text": "Audio Input",
            "description": "Microphone settings",
            "icon": "mic",
            "type": "connection",
            "enabled": true
        },
        {
            "id": "volumeSlider",
            "text": "Volume Slider",
            "description": "Audio volume control",
            "icon": "volume_up",
            "type": "slider",
            "enabled": true
        },
        {
            "id": "brightnessSlider",
            "text": "Brightness Slider",
            "description": "Display brightness control",
            "icon": "brightness_6",
            "type": "slider",
            "enabled": DisplayService.brightnessAvailable,
            "warning": !DisplayService.brightnessAvailable ? "Brightness control not available" : undefined
        },
        {
            "id": "inputVolumeSlider",
            "text": "Input Volume Slider",
            "description": "Microphone volume control",
            "icon": "mic",
            "type": "slider",
            "enabled": true
        },
        {
            "id": "diskUsage",
            "text": "Disk Usage",
            "description": "Filesystem usage monitoring",
            "icon": "storage",
            "type": "action",
            "enabled": DgopService.dgopAvailable,
            "warning": !DgopService.dgopAvailable ? "Requires 'dgop' tool" : undefined
        },
        {
            "id": "battery",
            "text": "Battery",
            "description": "Battery and power management",
            "icon": "battery_std",
            "type": "action",
            "enabled": true
        }
    ]

    function getWidgetForId(widgetId) {
        return WidgetUtils.getWidgetForId(baseWidgetDefinitions, widgetId)
    }

    function addWidget(widgetId) {
        WidgetUtils.addWidget(widgetId)
    }

    function removeWidget(index) {
        WidgetUtils.removeWidget(index)
    }

    function toggleWidgetSize(index) {
        WidgetUtils.toggleWidgetSize(index)
    }

    function moveWidget(fromIndex, toIndex) {
        WidgetUtils.moveWidget(fromIndex, toIndex)
    }

    function resetToDefault() {
        WidgetUtils.resetToDefault()
    }

    function clearAll() {
        WidgetUtils.clearAll()
    }
}