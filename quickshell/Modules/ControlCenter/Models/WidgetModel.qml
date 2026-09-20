pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Modules.ControlCenter
import qs.Modules.ControlCenter.BuiltinPlugins
import qs.Modules.ControlCenter.Widgets
import "../utils/widgets.js" as WidgetUtils

QtObject {
    id: root

    property int columns: CcMetrics.gridColumns
    property int maximumRows: CcMetrics.rowCapFor(CcMetrics.fallbackScreenHeight)
    property var builtinInstances: ({})
    readonly property var _pluginWidgetsCache: ({})

    readonly property var builtinDefinitions: [
        {
            "id": "builtin_vpn",
            "component": vpnComponent
        },
        {
            "id": "builtin_cups",
            "component": cupsComponent
        },
        {
            "id": "builtin_tailscale",
            "component": tailscaleComponent
        },
        {
            "id": "builtin_display_profiles",
            "component": displayProfilesComponent
        }
    ]

    readonly property Component vpnComponent: Component {
        VpnWidget {}
    }
    readonly property Component cupsComponent: Component {
        CupsWidget {}
    }
    readonly property Component tailscaleComponent: Component {
        TailscaleWidget {}
    }
    readonly property Component displayProfilesComponent: Component {
        DisplayProfilesWidget {}
    }

    readonly property Instantiator builtinLoaders: Instantiator {
        model: root.builtinDefinitions

        delegate: Loader {
            required property var modelData

            active: (SettingsData.controlCenterWidgets || []).some(w => w.id === modelData.id)
            sourceComponent: modelData.component
            onItemChanged: root.setBuiltinInstance(modelData.id, item)
        }
    }

    function setBuiltinInstance(id, item) {
        const next = Object.assign({}, builtinInstances);
        if (item)
            next[id] = item;
        else
            delete next[id];
        builtinInstances = next;
    }

    readonly property Component networkTile: Component {
        NetworkTile {}
    }
    readonly property Component bluetoothTile: Component {
        BluetoothTile {}
    }
    readonly property Component audioOutputTile: Component {
        AudioDeviceTile {}
    }
    readonly property Component audioInputTile: Component {
        AudioDeviceTile {
            isInput: true
        }
    }
    readonly property Component nightModeTile: Component {
        NightModeTile {}
    }
    readonly property Component darkModeTile: Component {
        DarkModeTile {}
    }
    readonly property Component dndTile: Component {
        DndTile {}
    }
    readonly property Component idleInhibitTile: Component {
        IdleInhibitTile {}
    }
    readonly property Component batteryTile: Component {
        BatteryTile {}
    }
    readonly property Component diskUsageTile: Component {
        DiskUsageTile {}
    }
    readonly property Component colorPickerTile: Component {
        ColorPickerTile {}
    }
    readonly property Component pluginTile: Component {
        PluginTile {}
    }
    readonly property Component volumeSliderRow: Component {
        AudioSliderRow {
            node: AudioService.sink
            maxVolume: AudioService.sinkMaxVolume
            playFeedback: true
        }
    }
    readonly property Component inputVolumeSliderRow: Component {
        AudioSliderRow {
            node: AudioService.source
            isInput: true
        }
    }
    readonly property Component brightnessSliderRow: Component {
        BrightnessSliderRow {}
    }

    function componentForWidget(widgetData) {
        const id = widgetData.id || "";
        if (id.startsWith("builtin_") || id.startsWith("plugin_"))
            return pluginTile;
        switch (id) {
        case "wifi":
            return networkTile;
        case "bluetooth":
            return bluetoothTile;
        case "audioOutput":
            return audioOutputTile;
        case "audioInput":
            return audioInputTile;
        case "volumeSlider":
            return volumeSliderRow;
        case "inputVolumeSlider":
            return inputVolumeSliderRow;
        case "brightnessSlider":
            return brightnessSliderRow;
        case "nightMode":
            return nightModeTile;
        case "darkMode":
            return darkModeTile;
        case "doNotDisturb":
            return dndTile;
        case "idleInhibitor":
            return idleInhibitTile;
        case "battery":
            return batteryTile;
        case "diskUsage":
            return diskUsageTile;
        case "colorPicker":
            return colorPickerTile;
        default:
            return null;
        }
    }

    readonly property Connections pluginWatcher: Connections {
        target: PluginService

        function onPluginLoaded() {
            root._pluginWidgetsCache.widgets = null;
        }

        function onPluginUnloaded() {
            root._pluginWidgetsCache.widgets = null;
        }
    }

    readonly property var baseWidgetDefinitions: [
        {
            "id": "nightMode",
            "text": I18n.tr("Night mode"),
            "description": I18n.tr("Blue light filter"),
            "icon": "nightlight",
            "type": "toggle",
            "enabled": NightModeService.automationAvailable,
            "warning": !NightModeService.automationAvailable ? I18n.tr("Requires night mode support") : undefined
        },
        {
            "id": "darkMode",
            "text": I18n.tr("Dark mode"),
            "description": I18n.tr("System theme toggle"),
            "icon": "contrast",
            "type": "toggle",
            "enabled": true
        },
        {
            "id": "doNotDisturb",
            "text": I18n.tr("Do not disturb"),
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
            "enabled": BrightnessService.brightnessAvailable,
            "warning": !BrightnessService.brightnessAvailable ? I18n.tr("Brightness control not available") : undefined,
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
            "text": I18n.tr("Disk usage"),
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
            "text": I18n.tr("VPN", "virtual private network, widget and page title"),
            "description": I18n.tr("VPN Connections"),
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
            "enabled": CupsService.cupsAvailable,
            "warning": !CupsService.cupsAvailable ? I18n.tr("CUPS not available") : undefined,
            "isBuiltinPlugin": true
        },
        {
            "id": "builtin_tailscale",
            "text": I18n.tr("Tailscale", "Tailscale mesh VPN widget title"),
            "description": I18n.tr("Tailscale Network", "Tailscale control center widget description"),
            "icon": "device_hub",
            "type": "builtin_plugin",
            "enabled": TailscaleService.available,
            "warning": !TailscaleService.available ? I18n.tr("Tailscale not available", "Warning when Tailscale service is not running") : undefined,
            "isBuiltinPlugin": true
        },
        {
            "id": "builtin_display_profiles",
            "text": I18n.tr("Display Profiles"),
            "description": I18n.tr("Switch between display configurations"),
            "icon": "monitor",
            "type": "builtin_plugin",
            "enabled": true,
            "isBuiltinPlugin": true
        }
    ]

    function getPluginWidgets() {
        if (_pluginWidgetsCache.widgets)
            return _pluginWidgetsCache.widgets;
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

        _pluginWidgetsCache.widgets = plugins;
        return plugins;
    }

    function getWidgetForId(widgetId) {
        return baseWidgetDefinitions.find(w => w.id === widgetId);
    }

    function addWidget(widgetId) {
        WidgetUtils.addWidget(widgetId, columns);
    }

    function removeWidget(index) {
        WidgetUtils.removeWidget(index);
    }

    function setLayout(widgets) {
        WidgetUtils.setLayout(widgets);
    }

    function resetToDefault() {
        WidgetUtils.resetToDefault(columns);
    }

    function clearAll() {
        WidgetUtils.clearAll();
    }
}
