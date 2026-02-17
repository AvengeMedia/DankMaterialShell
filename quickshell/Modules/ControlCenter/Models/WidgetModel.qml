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
            root.vpnBuiltinInstance = item;
        }

        Connections {
            target: SettingsData
            function onControlCenterWidgetsChanged() {
                const widgets = SettingsData.controlCenterWidgets || [];
                const hasVpnWidget = widgets.some(w => w.id === "builtin_vpn");
                if (!hasVpnWidget && vpnLoader.active) {
                    console.log("VpnWidget: No VPN widget in control center, deactivating loader");
                    vpnLoader.active = false;
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
            root.cupsBuiltinInstance = item;
        }

        onActiveChanged: {
            if (!active) {
                root.cupsBuiltinInstance = null;
            }
        }

        Connections {
            target: SettingsData
            function onControlCenterWidgetsChanged() {
                const widgets = SettingsData.controlCenterWidgets || [];
                const hasCupsWidget = widgets.some(w => w.id === "builtin_cups");
                if (!hasCupsWidget && cupsLoader.active) {
                    console.log("CupsWidget: No CUPS widget in control center, deactivating loader");
                    cupsLoader.active = false;
                }
            }
        }
    }

    readonly property var coreWidgetDefinitions: [
        {
            "id": "nightMode",
            "text": I18n.tr("Night Mode"),
            "description": I18n.tr("Blue light filter"),
            "icon": "nightlight",
            "type": "toggle",
            "enabled": DisplayService.automationAvailable,
            "warning": !DisplayService.automationAvailable ? I18n.tr("Requires night mode support") : undefined
        },
        {
            "id": "darkMode",
            "text": I18n.tr("Dark Mode"),
            "description": I18n.tr("System theme toggle"),
            "icon": "contrast",
            "type": "toggle",
            "enabled": true
        },
        {
            "id": "doNotDisturb",
            "text": I18n.tr("Do Not Disturb"),
            "description": I18n.tr("Block notifications"),
            "icon": "do_not_disturb_on",
            "type": "toggle",
            "enabled": true
        },
        {
            "id": "idleInhibitor",
            "text": I18n.tr("Keep Awake"),
            "description": I18n.tr("Prevent screen timeout"),
            "icon": "motion_sensor_active",
            "type": "toggle",
            "enabled": true
        },
        {
            "id": "wifi",
            "text": I18n.tr("Network"),
            "description": I18n.tr("Wi-Fi and Ethernet connection"),
            "icon": "wifi",
            "type": "connection",
            "enabled": NetworkService.wifiAvailable,
            "warning": !NetworkService.wifiAvailable ? I18n.tr("Wi-Fi not available") : undefined
        },
        {
            "id": "bluetooth",
            "text": I18n.tr("Bluetooth"),
            "description": I18n.tr("Device connections"),
            "icon": "bluetooth",
            "type": "connection",
            "enabled": BluetoothService.available,
            "warning": !BluetoothService.available ? I18n.tr("Bluetooth not available") : undefined
        },
        {
            "id": "audioOutput",
            "text": I18n.tr("Audio Output"),
            "description": I18n.tr("Speaker settings"),
            "icon": "volume_up",
            "type": "connection",
            "enabled": true
        },
        {
            "id": "audioInput",
            "text": I18n.tr("Audio Input"),
            "description": I18n.tr("Microphone settings"),
            "icon": "mic",
            "type": "connection",
            "enabled": true
        },
        {
            "id": "volumeSlider",
            "text": I18n.tr("Volume Slider"),
            "description": I18n.tr("Audio volume control"),
            "icon": "volume_up",
            "type": "slider",
            "enabled": true
        },
        {
            "id": "brightnessSlider",
            "text": I18n.tr("Brightness Slider"),
            "description": I18n.tr("Display brightness control"),
            "icon": "brightness_6",
            "type": "slider",
            "enabled": DisplayService.brightnessAvailable,
            "warning": !DisplayService.brightnessAvailable ? I18n.tr("Brightness control not available") : undefined,
            "allowMultiple": true
        },
        {
            "id": "inputVolumeSlider",
            "text": I18n.tr("Input Volume Slider"),
            "description": I18n.tr("Microphone volume control"),
            "icon": "mic",
            "type": "slider",
            "enabled": true
        },
        {
            "id": "battery",
            "text": I18n.tr("Battery"),
            "description": I18n.tr("Battery and power management"),
            "icon": "battery_std",
            "type": "action",
            "enabled": true
        },
        {
            "id": "diskUsage",
            "text": I18n.tr("Disk Usage"),
            "description": I18n.tr("Filesystem usage monitoring"),
            "icon": "storage",
            "type": "action",
            "enabled": DgopService.dgopAvailable,
            "warning": !DgopService.dgopAvailable ? I18n.tr("Requires 'dgop' tool") : undefined,
            "allowMultiple": true
        },
        {
            "id": "colorPicker",
            "text": I18n.tr("Color Picker"),
            "description": I18n.tr("Choose colors from palette"),
            "icon": "palette",
            "type": "action",
            "enabled": true
        },
        {
            "id": "builtin_vpn",
            "text": I18n.tr("VPN"),
            "description": I18n.tr("VPN connections"),
            "icon": "vpn_key",
            "type": "builtin_plugin",
            "enabled": DMSNetworkService.available,
            "warning": !DMSNetworkService.available ? I18n.tr("VPN not available") : undefined,
            "isBuiltinPlugin": true
        },
        {
            "id": "builtin_cups",
            "text": I18n.tr("Printers"),
            "description": I18n.tr("Print Server Management"),
            "icon": "Print",
            "type": "builtin_plugin",
            "enabled": CupsService.available,
            "warning": !CupsService.available ? I18n.tr("CUPS not available") : undefined,
            "isBuiltinPlugin": true
        }
    ]

    function getPluginWidgets() {
        const plugins = [];
        const loadedPlugins = PluginService.getLoadedPlugins();

        for (var i = 0; i < loadedPlugins.length; i++) {
            const plugin = loadedPlugins[i];

            if (plugin.type === "daemon") {
                continue;
            }

            const pluginComponent = PluginService.pluginWidgetComponents[plugin.id];
            if (!pluginComponent)
                continue;

            let tempInstance;
            try {
                tempInstance = pluginComponent.createObject(null);
            } catch (e) {
                PluginService.reloadPlugin(plugin.id);
                continue;
            }
            if (!tempInstance)
                continue;

            const hasCCWidget = tempInstance.ccWidgetIcon && tempInstance.ccWidgetIcon.length > 0;
            tempInstance.destroy();

            if (!hasCCWidget) {
                continue;
            }

            plugins.push({
                "id": "plugin_" + plugin.id,
                "pluginId": plugin.id,
                "text": plugin.name || I18n.tr("Plugin"),
                "description": plugin.description || "",
                "icon": plugin.icon || "extension",
                "type": "plugin",
                "enabled": true,
                "isPlugin": true
            });
        }

        return plugins;
    }

    readonly property var baseWidgetDefinitions: coreWidgetDefinitions

    function getWidgetForId(widgetId) {
        return WidgetUtils.getWidgetForId(baseWidgetDefinitions, widgetId);
    }

    function addWidget(widgetId) {
        WidgetUtils.addWidget(widgetId);
    }

    function removeWidget(index) {
        WidgetUtils.removeWidget(index);
    }

    function toggleWidgetSize(index) {
        WidgetUtils.toggleWidgetSize(index);
    }

    function moveWidget(fromIndex, toIndex) {
        WidgetUtils.moveWidget(fromIndex, toIndex);
    }

    function resetToDefault() {
        WidgetUtils.resetToDefault();
    }

    function clearAll() {
        WidgetUtils.clearAll();
    }
}
