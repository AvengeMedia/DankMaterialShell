import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

FocusScope {
    id: pluginsTab

    property string expandedPluginId: ""
    property bool isRefreshingPlugins: false
    property var parentModal: null
    property var installedPluginsData: ({})
    property bool isReloading: false

    focus: true

    DankFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn

            width: parent.width
            spacing: Theme.spacingXL

            StyledRect {
                width: parent.width
                height: headerColumn.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.width: 0

                Column {
                    id: headerColumn

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "extension"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Plugin Management")
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            StyledText {
                                text: I18n.tr("Manage and configure plugins for extending DMS functionality")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: dmsWarningColumn.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.1)
                        border.color: Theme.warning
                        border.width: 1
                        visible: !DMSService.dmsAvailable

                        Column {
                            id: dmsWarningColumn
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingXS

                            Row {
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: "warning"
                                    size: 16
                                    color: Theme.warning
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: I18n.tr("DMS Plugin Manager Unavailable")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.warning
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            StyledText {
                                text: I18n.tr("The DMS_SOCKET environment variable is not set or the socket is unavailable. Automated plugin management requires the DMS_SOCKET.")
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankButton {
                            text: I18n.tr("Browse")
                            iconName: "store"
                            enabled: DMSService.dmsAvailable
                            onClicked: {
                                pluginBrowserModal.show()
                            }
                        }

                        DankButton {
                            text: I18n.tr("Scan")
                            iconName: "refresh"
                            onClicked: {
                                pluginsTab.isRefreshingPlugins = true
                                PluginService.scanPlugins()
                                if (DMSService.dmsAvailable) {
                                    DMSService.listInstalled()
                                }
                                pluginsTab.refreshPluginList()
                            }
                        }

                        DankButton {
                            text: I18n.tr("Create Dir")
                            iconName: "create_new_folder"
                            onClicked: {
                                PluginService.createPluginDirectory()
                                ToastService.showInfo("Created plugin directory: " + PluginService.pluginDirectory)
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: directoryColumn.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.width: 0

                Column {
                    id: directoryColumn

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    StyledText {
                        text: I18n.tr("Plugin Directory")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }

                    StyledText {
                        text: PluginService.pluginDirectory
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        font.family: "monospace"
                    }

                    StyledText {
                        text: I18n.tr("Place plugin directories here. Each plugin should have a plugin.json manifest file.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: Math.max(200, availableColumn.implicitHeight + Theme.spacingL * 2)
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.width: 0

                Column {
                    id: availableColumn

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    StyledText {
                        text: I18n.tr("Available Plugins")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM

                        Repeater {
                            id: pluginRepeater
                            model: PluginService.getAvailablePlugins()

                            PluginListItem {
                                pluginData: modelData
                                expandedPluginId: pluginsTab.expandedPluginId
                                hasUpdate: {
                                    if (DMSService.apiVersion < 8) return false
                                    return pluginsTab.installedPluginsData[pluginId] || pluginsTab.installedPluginsData[pluginName] || false
                                }
                                isReloading: pluginsTab.isReloading
                                onExpandedPluginIdChanged: {
                                    pluginsTab.expandedPluginId = expandedPluginId
                                }
                                onIsReloadingChanged: {
                                    pluginsTab.isReloading = isReloading
                                }
                            }
                        }

                        StyledText {
                            width: parent.width
                            text: I18n.tr("No plugins found.") + "\n" + I18n.tr("Place plugins in") + " " + PluginService.pluginDirectory
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            horizontalAlignment: Text.AlignHCenter
                            visible: pluginRepeater.model && pluginRepeater.model.length === 0
                        }
                    }
                }
            }
        }
    }

    function refreshPluginList() {
        Qt.callLater(() => {
            var plugins = PluginService.getAvailablePlugins()
            pluginRepeater.model = null
            pluginRepeater.model = plugins
            pluginsTab.isRefreshingPlugins = false
        })
    }

    Connections {
        target: PluginService
        function onPluginLoaded() {
            refreshPluginList()
            if (isReloading) {
                isReloading = false
            }
        }
        function onPluginUnloaded() {
            refreshPluginList()
            if (!isReloading && pluginsTab.expandedPluginId !== "" && !PluginService.isPluginLoaded(pluginsTab.expandedPluginId)) {
                pluginsTab.expandedPluginId = ""
            }
        }
        function onPluginListUpdated() {
            if (DMSService.apiVersion >= 8) {
                DMSService.listInstalled()
            }
            refreshPluginList()
        }
    }

    Connections {
        target: DMSService
        function onPluginsListReceived(plugins) {
            pluginBrowserModal.isLoading = false
            pluginBrowserModal.allPlugins = plugins
            pluginBrowserModal.updateFilteredPlugins()
        }
        function onInstalledPluginsReceived(plugins) {
            var pluginMap = {}
            for (var i = 0; i < plugins.length; i++) {
                var plugin = plugins[i]
                var hasUpdate = plugin.hasUpdate || false
                if (plugin.id) {
                    pluginMap[plugin.id] = hasUpdate
                }
                if (plugin.name) {
                    pluginMap[plugin.name] = hasUpdate
                }
            }
            installedPluginsData = pluginMap
            Qt.callLater(refreshPluginList)
        }
        function onOperationSuccess(message) {
            ToastService.showInfo(message)
        }
        function onOperationError(error) {
            ToastService.showError(error)
        }
    }

    Component.onCompleted: {
        pluginBrowserModal.parentModal = pluginsTab.parentModal
        if (DMSService.dmsAvailable && DMSService.apiVersion >= 8) {
            DMSService.listInstalled()
        }
    }

    PluginBrowser {
        id: pluginBrowserModal
    }
}
