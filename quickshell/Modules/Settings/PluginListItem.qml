import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

StyledRect {
    id: root

    property var pluginData: null
    property string expandedPluginId: ""
    property bool hasUpdate: false
    property bool isReloading: false
    property var sharedTooltip: null

    property string pluginId: pluginData ? pluginData.id : ""
    property string pluginDirectoryName: {
        if (pluginData && pluginData.pluginDirectory) {
            var path = pluginData.pluginDirectory;
            return path.substring(path.lastIndexOf('/') + 1);
        }
        return pluginId;
    }
    property string pluginName: pluginData ? (pluginData.name || pluginData.id) : ""
    property string pluginVersion: pluginData ? (pluginData.version || "1.0.0") : ""
    property string pluginAuthor: pluginData ? (pluginData.author || "Unknown") : ""
    property string pluginDescription: pluginData ? (pluginData.description || "") : ""
    property string pluginIcon: pluginData ? (pluginData.icon || "extension") : "extension"
    property string pluginSettingsPath: pluginData ? (pluginData.settingsPath || "") : ""
    property var pluginPermissions: pluginData ? (pluginData.permissions || []) : []
    property bool hasSettings: pluginData && pluginData.settings !== undefined && pluginData.settings !== ""
    property bool isDesktopPlugin: pluginData ? (pluginData.type === "desktop") : false
    property bool showSettings: hasSettings && !isDesktopPlugin
    property bool isSystemPlugin: pluginData ? (pluginData.source === "system") : false
    property string requiresDms: pluginData ? (pluginData.requires_dms || "") : ""
    property bool meetsRequirements: requiresDms ? PluginService.checkPluginCompatibility(requiresDms) : true

    Connections {
        target: SystemUpdateService
        function onSemverVersionChanged() {
            root.meetsRequirementsChanged();
        }
    }
    property bool isExpanded: expandedPluginId === pluginId
    property bool isLoaded: {
        PluginService.loadedPlugins;
        return PluginService.loadedPlugins[pluginId] !== undefined;
    }

    width: parent.width
    height: pluginItemColumn.implicitHeight + Theme.spacingM * 2 + settingsContainer.height
    radius: Theme.cornerRadius
    color: (pluginMouseArea.containsMouse || updateArea.containsMouse || uninstallArea.containsMouse || reloadArea.containsMouse) ? Theme.surfacePressed : (isExpanded ? Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency) : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency))
    border.width: 0

    MouseArea {
        id: pluginMouseArea
        anchors.fill: parent
        anchors.bottomMargin: root.isExpanded ? settingsContainer.height : 0
        hoverEnabled: true
        cursorShape: root.showSettings ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.showSettings
        onClicked: {
            root.expandedPluginId = root.expandedPluginId === root.pluginId ? "" : root.pluginId;
        }
    }

    Column {
        id: pluginItemColumn
        width: parent.width
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM

        Row {
            width: parent.width
            spacing: Theme.spacingM

            DankIcon {
                name: root.pluginIcon
                size: Theme.iconSize
                color: root.isLoaded ? Theme.primary : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - Theme.iconSize - Theme.spacingM - toggleRow.width - Theme.spacingM
                spacing: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    spacing: Theme.spacingXS
                    width: parent.width

                    StyledText {
                        text: root.pluginName
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: incompatIcon.width + Theme.spacingXS * 2
                        height: 18
                        radius: 9
                        color: Theme.withAlpha(Theme.error, 0.15)
                        visible: !root.meetsRequirements
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            anchors.centerIn: parent
                            spacing: 2

                            DankIcon {
                                id: incompatIcon
                                name: "warning"
                                size: 12
                                color: Theme.error
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: {
                                if (root.sharedTooltip)
                                    root.sharedTooltip.show(I18n.tr("Requires DMS %1").arg(root.requiresDms), parent, 0, 0, "top");
                            }
                            onExited: {
                                if (root.sharedTooltip)
                                    root.sharedTooltip.hide();
                            }
                        }
                    }

                    DankIcon {
                        name: root.showSettings ? (root.isExpanded ? "expand_less" : "expand_more") : ""
                        size: 16
                        color: root.showSettings ? Theme.primary : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.showSettings
                    }

                    Rectangle {
                        width: desktopLabel.implicitWidth + Theme.spacingXS * 2
                        height: 18
                        radius: 9
                        color: Theme.withAlpha(Theme.secondary, 0.15)
                        visible: root.isDesktopPlugin
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            id: desktopLabel
                            anchors.centerIn: parent
                            text: I18n.tr("Desktop Widget")
                            font.pixelSize: Theme.fontSizeSmall - 2
                            color: Theme.secondary
                        }
                    }
                }

                StyledText {
                    text: "v" + root.pluginVersion + " by " + root.pluginAuthor
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                }
            }

            Row {
                id: toggleRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: updateArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency) : "transparent"
                    visible: DMSService.dmsAvailable && root.isLoaded && root.hasUpdate && !root.isSystemPlugin

                    DankIcon {
                        anchors.centerIn: parent
                        name: "download"
                        size: 16
                        color: updateArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                    }

                    MouseArea {
                        id: updateArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const currentPluginName = root.pluginName;
                            const currentPluginId = root.pluginId;
                            DMSService.update(currentPluginName, response => {
                                if (response.error) {
                                    ToastService.showError("Update failed: " + response.error);
                                    return;
                                }
                                ToastService.showInfo("Plugin updated: " + currentPluginName);
                                PluginService.forceRescanPlugin(currentPluginId);
                                if (DMSService.apiVersion >= 8)
                                    DMSService.listInstalled();
                            });
                        }
                        onEntered: {
                            if (root.sharedTooltip)
                                root.sharedTooltip.show(I18n.tr("Update Plugin"), parent, 0, 0, "top");
                        }
                        onExited: {
                            if (root.sharedTooltip)
                                root.sharedTooltip.hide();
                        }
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: uninstallArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency) : "transparent"
                    visible: DMSService.dmsAvailable && !root.isSystemPlugin

                    DankIcon {
                        anchors.centerIn: parent
                        name: "delete"
                        size: 16
                        color: uninstallArea.containsMouse ? Theme.error : Theme.surfaceVariantText
                    }

                    MouseArea {
                        id: uninstallArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const currentPluginName = root.pluginName;
                            DMSService.uninstall(currentPluginName, response => {
                                if (response.error) {
                                    ToastService.showError("Uninstall failed: " + response.error);
                                    return;
                                }
                                ToastService.showInfo("Plugin uninstalled: " + currentPluginName);
                                PluginService.scanPlugins();
                                if (root.isExpanded)
                                    root.expandedPluginId = "";
                            });
                        }
                        onEntered: {
                            if (root.sharedTooltip)
                                root.sharedTooltip.show(I18n.tr("Uninstall Plugin"), parent, 0, 0, "top");
                        }
                        onExited: {
                            if (root.sharedTooltip)
                                root.sharedTooltip.hide();
                        }
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: reloadArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency) : "transparent"
                    visible: root.isLoaded

                    DankIcon {
                        anchors.centerIn: parent
                        name: "refresh"
                        size: 16
                        color: reloadArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                    }

                    MouseArea {
                        id: reloadArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const currentPluginId = root.pluginId;
                            const currentPluginName = root.pluginName;
                            root.isReloading = true;
                            if (PluginService.reloadPlugin(currentPluginId)) {
                                ToastService.showInfo("Plugin reloaded: " + currentPluginName);
                                return;
                            }
                            ToastService.showError("Failed to reload plugin: " + currentPluginName);
                            root.isReloading = false;
                        }
                        onEntered: {
                            if (root.sharedTooltip)
                                root.sharedTooltip.show(I18n.tr("Reload Plugin"), parent, 0, 0, "top");
                        }
                        onExited: {
                            if (root.sharedTooltip)
                                root.sharedTooltip.hide();
                        }
                    }
                }

                DankToggle {
                    id: pluginToggle
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.isLoaded
                    onToggled: isChecked => {
                        const currentPluginId = root.pluginId;
                        const currentPluginName = root.pluginName;

                        if (isChecked) {
                            if (PluginService.enablePlugin(currentPluginId)) {
                                ToastService.showInfo("Plugin enabled: " + currentPluginName);
                                return;
                            }
                            ToastService.showError("Failed to enable plugin: " + currentPluginName);
                            return;
                        }
                        if (PluginService.disablePlugin(currentPluginId)) {
                            ToastService.showInfo("Plugin disabled: " + currentPluginName);
                            if (root.isExpanded)
                                root.expandedPluginId = "";
                            return;
                        }
                        ToastService.showError("Failed to disable plugin: " + currentPluginName);
                    }
                }
            }
        }

        StyledText {
            width: parent.width
            text: root.pluginDescription
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
            visible: root.pluginDescription !== ""
        }

        Flow {
            width: parent.width
            spacing: Theme.spacingXS
            visible: root.pluginPermissions && Array.isArray(root.pluginPermissions) && root.pluginPermissions.length > 0

            Repeater {
                model: root.pluginPermissions

                Rectangle {
                    height: 20
                    width: permissionText.implicitWidth + Theme.spacingXS * 2
                    radius: 10
                    color: Theme.withAlpha(Theme.primary, 0.1)
                    border.color: Theme.withAlpha(Theme.primary, 0.3)
                    border.width: 1

                    StyledText {
                        id: permissionText
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: Theme.fontSizeSmall - 1
                        color: Theme.primary
                    }
                }
            }
        }
    }

    FocusScope {
        id: settingsContainer
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.isExpanded && root.showSettings ? (settingsLoader.item ? settingsLoader.item.implicitHeight + Theme.spacingL * 2 : 0) : 0
        clip: true
        focus: root.isExpanded && root.showSettings

        Keys.onPressed: event => {
            event.accepted = true;
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
            radius: Theme.cornerRadius
            anchors.topMargin: Theme.spacingXS
            border.width: 0
        }

        Loader {
            id: settingsLoader
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            active: root.isExpanded && root.showSettings && root.isLoaded
            asynchronous: false

            source: {
                if (active && root.pluginSettingsPath) {
                    var path = root.pluginSettingsPath;
                    if (!path.startsWith("file://")) {
                        path = "file://" + path;
                    }
                    return path;
                }
                return "";
            }

            onLoaded: {
                if (item && typeof PluginService !== "undefined") {
                    item.pluginService = PluginService;
                }
                if (item && typeof PopoutService !== "undefined" && "popoutService" in item) {
                    item.popoutService = PopoutService;
                }
                if (item) {
                    Qt.callLater(() => {
                        settingsContainer.focus = true;
                        item.forceActiveFocus();
                    });
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            text: !root.isLoaded ? "Enable plugin to access settings" : (settingsLoader.status === Loader.Error ? "Failed to load settings" : "No configurable settings")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            visible: root.isExpanded && (!settingsLoader.active || settingsLoader.status === Loader.Error)
        }
    }
}
