import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

FocusScope {
    id: pluginsTab

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string expandedPluginId: ""
    property bool isRefreshingPlugins: false
    property var parentModal: null
    property var installedPluginsData: ({})
    property bool isReloading: false
    property alias sharedTooltip: sharedTooltip

    focus: true

    DankTooltipV2 {
        id: sharedTooltip
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4

            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
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
                            width: parent.width - Theme.iconSize - Theme.spacingM

                            StyledText {
                                text: I18n.tr("Plugin Management")
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                                width: parent.width
                                horizontalAlignment: Text.AlignLeft
                            }

                            StyledText {
                                text: I18n.tr("Manage and configure plugins for extending DMS functionality")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                                horizontalAlignment: Text.AlignLeft
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: dmsWarningColumn.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.warning, 0.1)
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
                                horizontalAlignment: Text.AlignLeft
                            }
                        }
                    }

                    StyledRect {
                        id: incompatWarning
                        property var incompatPlugins: []
                        width: parent.width
                        height: incompatWarningColumn.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.error, 0.1)
                        border.color: Theme.error
                        border.width: 1
                        visible: incompatPlugins.length > 0

                        function refresh() {
                            incompatPlugins = PluginService.getIncompatiblePlugins();
                        }

                        Component.onCompleted: Qt.callLater(refresh)

                        Column {
                            id: incompatWarningColumn
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingXS

                            Row {
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: "error"
                                    size: 16
                                    color: Theme.error
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: I18n.tr("Incompatible Plugins Loaded")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.error
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            StyledText {
                                text: I18n.tr("Some plugins require a newer version of DMS:") + " " + incompatWarning.incompatPlugins.map(p => p.name + " (" + p.requires_dms + ")").join(", ")
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                                horizontalAlignment: Text.AlignLeft
                            }
                        }

                        Connections {
                            target: PluginService
                            function onPluginLoaded() {
                                incompatWarning.refresh();
                            }
                            function onPluginUnloaded() {
                                incompatWarning.refresh();
                            }
                        }

                        Connections {
                            target: SystemUpdateService
                            function onSemverVersionChanged() {
                                incompatWarning.refresh();
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
                                showPluginBrowser();
                            }
                        }

                        DankButton {
                            text: I18n.tr("Scan")
                            iconName: "refresh"
                            onClicked: {
                                pluginsTab.isRefreshingPlugins = true;
                                PluginService.scanPlugins();
                                if (DMSService.dmsAvailable) {
                                    DMSService.listInstalled();
                                }
                                pluginsTab.refreshPluginList();
                            }
                        }

                        DankButton {
                            text: I18n.tr("Create Dir")
                            iconName: "create_new_folder"
                            onClicked: {
                                PluginService.createPluginDirectory();
                                ToastService.showInfo("Created plugin directory: " + PluginService.pluginDirectory);
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
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
                    }

                    StyledText {
                        text: PluginService.pluginDirectory
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        font.family: "monospace"
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
                    }

                    StyledText {
                        text: I18n.tr("Place plugin directories here. Each plugin should have a plugin.json manifest file.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
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
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM

                        Repeater {
                            id: pluginRepeater
                            model: PluginService.availablePluginsList

                            PluginListItem {
                                pluginData: modelData
                                expandedPluginId: pluginsTab.expandedPluginId
                                hasUpdate: {
                                    if (DMSService.apiVersion < 8)
                                        return false;
                                    return pluginsTab.installedPluginsData[pluginId] || pluginsTab.installedPluginsData[pluginName] || false;
                                }
                                isReloading: pluginsTab.isReloading
                                sharedTooltip: pluginsTab.sharedTooltip
                                onExpandedPluginIdChanged: {
                                    pluginsTab.expandedPluginId = expandedPluginId;
                                }
                                onIsReloadingChanged: {
                                    pluginsTab.isReloading = isReloading;
                                }
                            }
                        }

                        StyledText {
                            width: parent.width
                            text: I18n.tr("No plugins found.") + "\n" + I18n.tr("Place plugins in %1").arg(PluginService.pluginDirectory)
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
        pluginsTab.isRefreshingPlugins = false;
    }

    Connections {
        target: PluginService
        function onPluginLoaded() {
            refreshPluginList();
            if (isReloading) {
                isReloading = false;
            }
        }
        function onPluginUnloaded() {
            refreshPluginList();
            if (!isReloading && pluginsTab.expandedPluginId !== "" && !PluginService.isPluginLoaded(pluginsTab.expandedPluginId)) {
                pluginsTab.expandedPluginId = "";
            }
        }
        function onPluginListUpdated() {
            if (DMSService.apiVersion >= 8) {
                DMSService.listInstalled();
            }
            refreshPluginList();
        }
        function onPluginDataChanged(pluginId) {
            var plugin = PluginService.availablePlugins[pluginId];
            if (!plugin || !PluginService.isPluginLoaded(pluginId))
                return;
            var isLauncher = plugin.type === "launcher" || (plugin.capabilities && plugin.capabilities.includes("launcher"));
            if (isLauncher)
                PluginService.reloadPlugin(pluginId);
        }
    }

    Connections {
        target: DMSService
        function onPluginsListReceived(plugins) {
            if (!pluginBrowserLoader.item)
                return;
            pluginBrowserLoader.item.isLoading = false;
            pluginBrowserLoader.item.allPlugins = plugins;
            pluginBrowserLoader.item.updateFilteredPlugins();
        }
        function onInstalledPluginsReceived(plugins) {
            var pluginMap = {};
            for (var i = 0; i < plugins.length; i++) {
                var plugin = plugins[i];
                var hasUpdate = plugin.hasUpdate || false;
                if (plugin.id) {
                    pluginMap[plugin.id] = hasUpdate;
                }
                if (plugin.name) {
                    pluginMap[plugin.name] = hasUpdate;
                }
            }
            installedPluginsData = pluginMap;
            Qt.callLater(refreshPluginList);
        }
        function onOperationSuccess(message) {
            ToastService.showInfo(message);
        }
        function onOperationError(error) {
            ToastService.showError(error);
        }
    }

    Component.onCompleted: {
        if (DMSService.dmsAvailable && DMSService.apiVersion >= 8)
            DMSService.listInstalled();
        if (PopoutService.pendingPluginInstall)
            Qt.callLater(showPluginBrowser);
    }

    Connections {
        target: PopoutService
        function onPendingPluginInstallChanged() {
            if (PopoutService.pendingPluginInstall)
                showPluginBrowser();
        }
    }

    LazyLoader {
        id: pluginBrowserLoader
        active: false

        PluginBrowser {
            id: pluginBrowserItem

            Component.onCompleted: {
                pluginBrowserItem.parentModal = pluginsTab.parentModal;
            }
        }
    }

    function showPluginBrowser() {
        pluginBrowserLoader.active = true;
        if (pluginBrowserLoader.item)
            pluginBrowserLoader.item.show();
    }
}
