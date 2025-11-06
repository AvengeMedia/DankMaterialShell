import QtQuick
import qs.Common
import qs.Services
import qs.Modules.ControlCenter.BuiltinPlugins
import "../utils/widgets.js" as WidgetUtils

QtObject {
    id: root

    property var vpnBuiltinInstance: null
    property var cupsBuiltinInstance: null

    property var vpnLoader: Loader {
        active: false
        sourceComponent: Component {
            VpnWidget {}
        }

        onItemChanged: {
            root.vpnBuiltinInstance = item
        }

        Connections {
            target: SettingsData
            function onControlCenterWidgetsChanged() {
                const widgets = SettingsData.controlCenterWidgets || []
                const hasVpnWidget = widgets.some(w => w.id === "builtin_vpn")
                if (!hasVpnWidget && vpnLoader.active) {
                    console.log("VpnWidget: No VPN widget in control center, deactivating loader")
                    vpnLoader.active = false
                }
            }
        }
    }

    property var cupsLoader: Loader {
        active: false
        sourceComponent: Component {
            CupsWidget {}
        }

        onItemChanged: {
            root.cupsBuiltinInstance = item
            if (item && !DMSService.activeSubscriptions.includes("cups") && !DMSService.activeSubscriptions.includes("all")) {
                DMSService.addSubscription("cups")
            }
        }

        onActiveChanged: {
            if (!active) {
                if (DMSService.activeSubscriptions.includes("cups")) {
                    DMSService.removeSubscription("cups")
                }
                root.cupsBuiltinInstance = null
            }
        }

        Connections {
            target: SettingsData
            function onControlCenterWidgetsChanged() {
                const widgets = SettingsData.controlCenterWidgets || []
                const hasCupsWidget = widgets.some(w => w.id === "builtin_cups")
                if (!hasCupsWidget && cupsLoader.active) {
                    console.log("CupsWidget: No CUPS widget in control center, deactivating loader")
                    cupsLoader.active = false
                }
            }
        }
    }

    readonly property var coreWidgetDefinitions: [{
            "id": "nightMode",
            "text": "Night Mode",
            "description": "Blue light filter",
            "icon": "nightlight",
            "type": "toggle",
            "enabled": DisplayService.automationAvailable,
            "warning": !DisplayService.automationAvailable ? "Requires night mode support" : undefined
        }, {
            "id": "darkMode",
            "text": "Dark Mode",
            "description": "System theme toggle",
            "icon": "contrast",
            "type": "toggle",
            "enabled": true
        }, {
            "id": "doNotDisturb",
            "text": "Do Not Disturb",
            "description": "Block notifications",
            "icon": "do_not_disturb_on",
            "type": "toggle",
            "enabled": true
        }, {
            "id": "idleInhibitor",
            "text": "Keep Awake",
            "description": "Prevent screen timeout",
            "icon": "motion_sensor_active",
            "type": "toggle",
            "enabled": true
        }, {
            "id": "wifi",
            "text": "Network",
            "description": "Wi-Fi and Ethernet connection",
            "icon": "wifi",
            "type": "connection",
            "enabled": NetworkService.wifiAvailable,
            "warning": !NetworkService.wifiAvailable ? "Wi-Fi not available" : undefined
        }, {
            "id": "bluetooth",
            "text": "Bluetooth",
            "description": "Device connections",
            "icon": "bluetooth",
            "type": "connection",
            "enabled": BluetoothService.available,
            "warning": !BluetoothService.available ? "Bluetooth not available" : undefined
        }, {
            "id": "audioOutput",
            "text": "Audio Output",
            "description": "Speaker settings",
            "icon": "volume_up",
            "type": "connection",
            "enabled": true
        }, {
            "id": "audioInput",
            "text": "Audio Input",
            "description": "Microphone settings",
            "icon": "mic",
            "type": "connection",
            "enabled": true
        }, {
            "id": "volumeSlider",
            "text": "Volume Slider",
            "description": "Audio volume control",
            "icon": "volume_up",
            "type": "slider",
            "enabled": true
        }, {
            "id": "brightnessSlider",
            "text": "Brightness Slider",
            "description": "Display brightness control",
            "icon": "brightness_6",
            "type": "slider",
            "enabled": DisplayService.brightnessAvailable,
            "warning": !DisplayService.brightnessAvailable ? "Brightness control not available" : undefined,
            "allowMultiple": true
        }, {
            "id": "inputVolumeSlider",
            "text": "Input Volume Slider",
            "description": "Microphone volume control",
            "icon": "mic",
            "type": "slider",
            "enabled": true
        }, {
            "id": "battery",
            "text": "Battery",
            "description": "Battery and power management",
            "icon": "battery_std",
            "type": "action",
            "enabled": true
        }, {
            "id": "diskUsage",
            "text": "Disk Usage",
            "description": "Filesystem usage monitoring",
            "icon": "storage",
            "type": "action",
            "enabled": DgopService.dgopAvailable,
            "warning": !DgopService.dgopAvailable ? "Requires 'dgop' tool" : undefined,
            "allowMultiple": true
        }, {
            "id": "colorPicker",
            "text": "Color Picker",
            "description": "Choose colors from palette",
            "icon": "palette",
            "type": "action",
            "enabled": true
        }, {
            "id": "builtin_vpn",
            "text": "VPN",
            "description": "VPN connections",
            "icon": "vpn_key",
            "type": "builtin_plugin",
            "enabled": DMSNetworkService.available,
            "warning": !DMSNetworkService.available ? "VPN not available" : undefined,
            "isBuiltinPlugin": true
        }, {
            "id": "builtin_cups",
            "text": "Printers",
            "description": "Print Server Management",
            "icon": "Print",
            "type": "builtin_plugin",
            "enabled": CupsService.available,
            "warning": !CupsService.available ? "CUPS not available" : undefined,
            "isBuiltinPlugin": true
        }]

    function getPluginWidgets() {
        const plugins = []
        const loadedPlugins = PluginService.getLoadedPlugins()

        for (var i = 0; i < loadedPlugins.length; i++) {
            const plugin = loadedPlugins[i]

            if (plugin.type === "daemon") {
                continue
            }

            const pluginComponent = PluginService.pluginWidgetComponents[plugin.id]
            if (!pluginComponent) {
                continue
            }

            const tempInstance = pluginComponent.createObject(null)
            if (!tempInstance) {
                continue
            }

            const hasCCWidget = tempInstance.ccWidgetIcon && tempInstance.ccWidgetIcon.length > 0
            tempInstance.destroy()

            if (!hasCCWidget) {
                continue
            }

            plugins.push({
                             "id": "plugin_" + plugin.id,
                             "pluginId": plugin.id,
                             "text": plugin.name || "Plugin",
                             "description": plugin.description || "",
                             "icon": plugin.icon || "extension",
                             "type": "plugin",
                             "enabled": true,
                             "isPlugin": true
                         })
        }

        return plugins
    }

    readonly property var baseWidgetDefinitions: coreWidgetDefinitions

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
