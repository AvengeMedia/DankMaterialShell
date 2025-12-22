pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Column {
    id: root

    property string instanceId: ""
    property var instanceData: null
    property string widgetType: ""
    property var widgetDef: null

    readonly property var cfg: instanceData?.config ?? {}
    readonly property string settingsPath: widgetDef?.settingsComponent ?? ""

    function updateConfig(key, value) {
        if (!instanceId)
            return;
        var updates = {};
        updates[key] = value;
        SettingsData.updateDesktopWidgetInstanceConfig(instanceId, updates);
    }

    QtObject {
        id: instanceScopedPluginService

        readonly property var availablePlugins: PluginService.availablePlugins
        readonly property var loadedPlugins: PluginService.loadedPlugins
        readonly property var pluginDesktopComponents: PluginService.pluginDesktopComponents

        signal pluginDataChanged(string pluginId)
        signal pluginLoaded(string pluginId)
        signal pluginUnloaded(string pluginId)

        function loadPluginData(pluginId, key, defaultValue) {
            const cfg = root.instanceData?.config;
            if (cfg && key in cfg)
                return cfg[key];
            return SettingsData.getPluginSetting(root.widgetType, key, defaultValue);
        }

        function savePluginData(pluginId, key, value) {
            root.updateConfig(key, value);
            Qt.callLater(() => pluginDataChanged(root.widgetType));
            return true;
        }

        function getPluginVariants(pluginId) {
            return PluginService.getPluginVariants(pluginId);
        }

        function isPluginLoaded(pluginId) {
            return PluginService.isPluginLoaded(pluginId);
        }
    }

    width: parent?.width ?? 400
    spacing: 0

    Loader {
        id: pluginSettingsLoader
        width: parent.width
        active: root.settingsPath !== ""

        source: root.settingsPath

        onLoaded: {
            if (!item)
                return;
            if (item.instanceId !== undefined)
                item.instanceId = root.instanceId;
            if (item.instanceData !== undefined)
                item.instanceData = Qt.binding(() => root.instanceData);
            if (item.pluginService !== undefined)
                item.pluginService = instanceScopedPluginService;
            if (item.reloadChildValues)
                Qt.callLater(item.reloadChildValues);
        }
    }

    Column {
        width: parent.width
        spacing: 0
        visible: root.settingsPath === ""

        SettingsDisplayPicker {
            displayPreferences: cfg.displayPreferences ?? ["all"]
            onPreferencesChanged: prefs => root.updateConfig("displayPreferences", prefs)
        }

        SettingsDivider {}

        Item {
            width: parent.width
            height: resetRow.height + Theme.spacingM * 2

            Row {
                id: resetRow
                x: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingM

                DankButton {
                    text: I18n.tr("Reset Position")
                    backgroundColor: Theme.surfaceHover
                    textColor: Theme.surfaceText
                    buttonHeight: 36
                    onClicked: {
                        if (!root.instanceId)
                            return;
                        SettingsData.updateDesktopWidgetInstance(root.instanceId, {
                            positions: {}
                        });
                    }
                }

                DankButton {
                    text: I18n.tr("Reset Size")
                    backgroundColor: Theme.surfaceHover
                    textColor: Theme.surfaceText
                    buttonHeight: 36
                    onClicked: {
                        if (!root.instanceId)
                            return;
                        SettingsData.updateDesktopWidgetInstance(root.instanceId, {
                            positions: {}
                        });
                    }
                }
            }
        }
    }
}
