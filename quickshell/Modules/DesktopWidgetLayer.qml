import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Plugins
import qs.Modules.BuiltinDesktopPlugins

Variants {
    id: root
    model: Quickshell.screens

    Component.onCompleted: Qt.callLater(autoEnablePluginsForInstances)

    function autoEnablePluginsForInstances() {
        const instances = SettingsData.desktopWidgetInstances || [];
        const pluginTypes = new Set();

        for (const inst of instances) {
            if (!inst.enabled)
                continue;
            if (inst.widgetType === "desktopClock" || inst.widgetType === "systemMonitor")
                continue;
            pluginTypes.add(inst.widgetType);
        }

        for (const pluginId of pluginTypes) {
            if (PluginService.isPluginLoaded(pluginId))
                continue;
            if (!PluginService.availablePlugins[pluginId])
                continue;
            PluginService.enablePlugin(pluginId);
        }
    }

    Connections {
        target: PluginService
        function onPluginListUpdated() {
            Qt.callLater(root.autoEnablePluginsForInstances);
        }
    }

    QtObject {
        id: screenDelegate

        required property var modelData

        readonly property var screen: modelData
        readonly property string screenKey: SettingsData.getScreenDisplayName(screen)

        function shouldShowOnScreen(prefs) {
            if (!Array.isArray(prefs) || prefs.length === 0 || prefs.includes("all"))
                return true;
            return prefs.some(p => {
                if (typeof p === "string")
                    return p === screenKey || p === modelData.name;
                return p?.name === modelData.name || p === screenKey;
            });
        }

        // Layer surfaces stack by map order, so recreate them in list order on
        // reorder/enable/display-pref changes or once a plugin component loads (#2715).
        property bool rebuilding: false

        readonly property string orderSignature: {
            const instances = SettingsData.desktopWidgetInstances || [];
            let sig = "";
            for (const inst of instances) {
                const prefs = inst.config?.displayPreferences ?? ["all"];
                const prefsKey = Array.isArray(prefs) ? prefs.join(",") : "all";
                sig += inst.id + ":" + (inst.enabled ? "1" : "0") + ":" + prefsKey + "|";
            }
            return sig;
        }

        readonly property string pluginReadyKey: {
            const instances = SettingsData.desktopWidgetInstances || [];
            const comps = PluginService.pluginDesktopComponents;
            let key = "";
            for (const inst of instances) {
                if (!inst.enabled)
                    continue;
                if (inst.widgetType === "desktopClock" || inst.widgetType === "systemMonitor")
                    continue;
                key += inst.widgetType + (comps[inst.widgetType] ? ":1" : ":0") + ",";
            }
            return key;
        }

        onOrderSignatureChanged: rebuildDebounce.restart()
        onPluginReadyKeyChanged: rebuildDebounce.restart()

        property Timer rebuildDebounce: Timer {
            interval: 150
            repeat: false
            onTriggered: {
                screenDelegate.rebuilding = true;
                rebuildApply.restart();
            }
        }

        property Timer rebuildApply: Timer {
            interval: 32
            repeat: false
            onTriggered: screenDelegate.rebuilding = false
        }

        property Component clockComponent: Component {
            DesktopClockWidget {}
        }

        property Component systemMonitorComponent: Component {
            SystemMonitorWidget {}
        }

        property Instantiator widgetInstantiator: Instantiator {
            model: ScriptModel {
                objectProp: "id"
                // Reversed so the top of the list maps last and renders in front.
                values: screenDelegate.rebuilding ? [] : [...(SettingsData.desktopWidgetInstances || [])].reverse()
            }

            DesktopPluginWrapper {
                required property var modelData
                required property int index

                readonly property string instanceIdRef: modelData.id
                readonly property var liveInstanceData: {
                    const instances = SettingsData.desktopWidgetInstances || [];
                    return instances.find(inst => inst.id === instanceIdRef) ?? modelData;
                }

                readonly property bool shouldBeVisible: {
                    if (!liveInstanceData.enabled)
                        return false;
                    const prefs = liveInstanceData.config?.displayPreferences ?? ["all"];
                    return screenDelegate.shouldShowOnScreen(prefs);
                }

                pluginId: liveInstanceData.widgetType
                instanceId: instanceIdRef
                instanceData: liveInstanceData
                builtinComponent: {
                    switch (liveInstanceData.widgetType) {
                    case "desktopClock":
                        return screenDelegate.clockComponent;
                    case "systemMonitor":
                        return screenDelegate.systemMonitorComponent;
                    default:
                        return null;
                    }
                }
                pluginService: (liveInstanceData.widgetType !== "desktopClock" && liveInstanceData.widgetType !== "systemMonitor") ? PluginService : null
                screen: screenDelegate.screen
                widgetEnabled: shouldBeVisible
            }
        }
    }
}
