pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals.Common
import qs.Modules.Settings.Widgets

FocusScope {
    id: root

    property string pluginId: ""
    property var parentModal: null
    property bool isReloading: false
    property bool operationPending: false
    property string actionError: ""

    readonly property var pluginData: PluginService.availablePlugins[pluginId] ?? null
    readonly property bool isLoaded: PluginService.loadedPlugins[pluginId] !== undefined
    readonly property bool isDesktopPlugin: pluginData?.type === "desktop"
    readonly property bool hasSettings: !!pluginData?.settings && !isDesktopPlugin
    readonly property bool isSystemPlugin: pluginData?.source === "system"
    readonly property string pluginName: pluginData?.name || pluginId
    readonly property string requiresDms: pluginData?.requires_dms || ""
    readonly property bool meetsRequirements: requiresDms ? PluginService.checkPluginCompatibility(requiresDms) : true
    readonly property var permissions: Array.isArray(pluginData?.permissions) ? pluginData.permissions : []
    readonly property bool hasUpdate: {
        if (DMSService.apiVersion < 8)
            return false;
        const installed = DMSService.installedPlugins || [];
        return installed.some(plugin => plugin.hasUpdate === true && (plugin.id === root.pluginId || plugin.name === root.pluginName));
    }
    readonly property string settingsStatus: {
        if (!root.isLoaded)
            return I18n.tr("Enable plugin to access settings");
        if (!root.hasSettings)
            return I18n.tr("No configurable settings");
        if (settingsHost.status === Loader.Error)
            return I18n.tr("Failed to load settings");
        return "";
    }

    onPluginIdChanged: flickable.contentY = 0

    Connections {
        target: PluginService

        function onPluginLoaded(loadedId) {
            if (loadedId === root.pluginId)
                root.isReloading = false;
        }

        function onPluginLoadFailed(failedId, error) {
            if (failedId !== root.pluginId)
                return;
            root.isReloading = false;
            root.actionError = error;
        }

        function onPluginDataChanged(changedId) {
            if (changedId !== root.pluginId || !root.isLoaded)
                return;
            const plugin = PluginService.availablePlugins[changedId];
            const isLauncher = plugin?.type === "launcher" || (plugin?.capabilities?.includes("launcher") ?? false);
            if (!isLauncher)
                return;
            root.isReloading = true;
            PluginService.reloadPlugin(changedId);
        }
    }

    function setEnabled(enabled) {
        actionError = "";
        if (enabled) {
            PluginService.enablePlugin(pluginId, ok => {
                if (ok)
                    return;
                const error = PluginService.pluginLoadErrors[pluginId];
                actionError = error ? [error.title, error.details].filter(Boolean).join("\n") : I18n.tr("Failed to enable plugin: %1").arg(pluginName);
            });
            return;
        }
        if (!PluginService.disablePlugin(pluginId))
            actionError = I18n.tr("Failed to disable plugin: %1", "plugin error message, %1 is the plugin name").arg(pluginName);
    }

    function reload() {
        actionError = "";
        isReloading = true;
        if (PluginService.reloadPlugin(pluginId))
            return;
        actionError = I18n.tr("Failed to reload plugin: %1", "plugin error message, %1 is the plugin name").arg(pluginName);
        isReloading = false;
    }

    function requestUpdate() {
        const plugin = DMSService.installedPlugins.find(entry => entry.id === pluginId);
        operationConfirm.showWithOptions({
            title: I18n.tr("Update %1?", "plugin update confirmation").arg(pluginName),
            message: I18n.tr("Plugin updates can change the code running in your session. Review the changes before updating.", "plugin update audit reminder"),
            reviewUrl: plugin?.diffUrl || plugin?.repo || "",
            confirmText: I18n.tr("Update"),
            onConfirm: () => update()
        });
    }

    function update() {
        if (operationPending)
            return;
        const id = pluginId;
        operationPending = true;
        actionError = "";
        PluginService.updatePlugin(id, response => {
            operationPending = false;
            if (response.error) {
                actionError = I18n.tr("Update failed: %1", "plugin update error, %1 is the error message").arg(response.error);
                return;
            }
            PluginService.pendingSettingsRevealPluginId = id;
        });
    }

    function requestUninstall() {
        operationConfirm.showWithOptions({
            title: I18n.tr("Uninstall"),
            message: I18n.tr("Uninstall %1?", "plugin removal confirmation").arg(pluginName),
            confirmText: I18n.tr("Uninstall"),
            confirmColor: Theme.error,
            onConfirm: () => uninstall()
        });
    }

    function uninstall() {
        if (operationPending)
            return;
        const id = pluginId;
        operationPending = true;
        actionError = "";
        DMSService.uninstall(id, response => {
            operationPending = false;
            if (response.error) {
                actionError = I18n.tr("Uninstall failed: %1").arg(response.error);
                return;
            }
            PluginService.scanPlugins();
            root.parentModal?.setPage("plugins");
        });
    }

    ConfirmDialogOverlay {
        id: operationConfirm
        parent: root.parentModal?.modalFocusScope ?? root
    }

    SettingsPage {
        id: flickable

        SettingsCard {
            settingKey: "pluginHeader"
            visible: root.pluginData !== null

            SettingsToggleRow {
                iconName: root.pluginData?.icon || "extension"
                text: root.pluginName
                enabled: !root.operationPending
                checked: root.isLoaded
                onToggled: checked => root.setEnabled(checked)
            }

            SettingsRow {
                iconName: "error"
                title: I18n.tr("Requires DMS %1", "plugin incompatibility notice, %1 is the required DMS version").arg(root.requiresDms)
                subtitleColor: Theme.error
                visible: !root.meetsRequirements
            }

            SettingsRow {
                visible: root.actionError !== ""
                subtitle: root.actionError
                subtitleColor: Theme.error
            }
        }

        SettingsCard {
            settingKey: "pluginMissing"
            visible: root.pluginData === null

            SettingsRow {
                iconName: "error"
                title: I18n.tr("Plugin not found: %1", "plugin settings page error, %1 is the plugin id").arg(root.pluginId)
            }
        }

        SettingsCard {
            settingKey: "pluginDesktopWidgets"
            visible: root.pluginData !== null && root.isDesktopPlugin

            SettingsNavRow {
                iconName: "widgets"
                title: I18n.tr("Desktop widgets")
                hint: I18n.tr("Desktop widget plugins are configured per widget instance")
                onClicked: root.parentModal?.navigateTo("desktop_widgets")
            }
        }

        SettingsCard {
            title: I18n.tr("Settings")
            settingKey: "pluginSettings"
            visible: root.pluginData !== null && !root.isDesktopPlugin

            SettingsRow {
                subtitle: root.settingsStatus
                visible: root.settingsStatus !== ""
            }

            PluginSettingsHost {
                id: settingsHost
                width: parent.width
                height: implicitHeight
                active: root.isLoaded && root.hasSettings
                settingsPath: PluginService.pluginComponentUrl(root.pluginId, root.pluginData?.settingsPath)
                visible: loaded
            }
        }

        DankCollapsibleSection {
            id: pluginDetails
            width: parent.width
            title: I18n.tr("Plugin details", "plugin metadata and maintenance")
            visible: root.pluginData !== null

            SettingsCard {
                Layout.fillWidth: true
                visible: pluginDetails.expanded
                settingKey: "pluginDetails"

                SettingsRow {
                    title: [root.pluginData?.version, root.pluginData?.author].filter(Boolean).join(" · ")
                }
                SettingsRow {
                    subtitle: root.pluginData?.description || ""
                    visible: subtitle !== ""
                }

                SettingsRow {
                    visible: root.permissions.length > 0
                    body: Flow {
                        width: parent.width
                        spacing: Theme.spacingXS

                        Repeater {
                            model: root.permissions

                            Rectangle {
                                required property string modelData

                                height: Theme.iconSizeMedium
                                width: permissionText.implicitWidth + Theme.spacingS * 2
                                radius: Theme.fullRadius(width, height)
                                color: Theme.withAlpha(Theme.primary, Theme.tonalTintAlpha)

                                StyledText {
                                    id: permissionText
                                    anchors.centerIn: parent
                                    text: parent.modelData
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.primary
                                }
                            }
                        }
                    }
                }

                SettingsRow {
                    iconName: "download"
                    title: I18n.tr("Update plugin")
                    clickable: true
                    visible: DMSService.dmsAvailable && root.isLoaded && root.hasUpdate && !root.isSystemPlugin
                    enabled: !root.operationPending
                    onClicked: root.requestUpdate()
                }

                SettingsRow {
                    iconName: "refresh"
                    title: I18n.tr("Reload plugin")
                    clickable: true
                    visible: root.isLoaded
                    enabled: !root.isReloading && !root.operationPending
                    onClicked: root.reload()
                }

                SettingsRow {
                    iconName: "delete"
                    title: I18n.tr("Uninstall plugin")
                    clickable: true
                    visible: DMSService.dmsAvailable && !root.isSystemPlugin
                    enabled: !root.operationPending
                    onClicked: root.requestUninstall()
                }
            }
        }
    }
}
