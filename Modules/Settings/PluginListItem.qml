import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

StyledRect {
    id: root

    property var pluginData: null
    property string expandedPluginId: ""
    property bool hasUpdate: false
    property bool isReloading: false

    property string pluginId: pluginData ? pluginData.id : ""
    property string pluginDirectoryName: {
        if (pluginData && pluginData.pluginDirectory) {
            var path = pluginData.pluginDirectory
            return path.substring(path.lastIndexOf('/') + 1)
        }
        return pluginId
    }
    property string pluginName: pluginData ? (pluginData.name || pluginData.id) : ""
    property string pluginVersion: pluginData ? (pluginData.version || "1.0.0") : ""
    property string pluginAuthor: pluginData ? (pluginData.author || "Unknown") : ""
    property string pluginDescription: pluginData ? (pluginData.description || "") : ""
    property string pluginIcon: pluginData ? (pluginData.icon || "extension") : "extension"
    property string pluginSettingsPath: pluginData ? (pluginData.settingsPath || "") : ""
    property var pluginPermissions: pluginData ? (pluginData.permissions || []) : []
    property bool hasSettings: pluginData && pluginData.settings !== undefined && pluginData.settings !== ""
    property bool isExpanded: expandedPluginId === pluginId

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
        cursorShape: root.hasSettings ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.hasSettings
        onClicked: {
            root.expandedPluginId = root.expandedPluginId === root.pluginId ? "" : root.pluginId
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
                color: PluginService.isPluginLoaded(root.pluginId) ? Theme.primary : Theme.surfaceVariantText
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

                    DankIcon {
                        name: root.hasSettings ? (root.isExpanded ? "expand_less" : "expand_more") : ""
                        size: 16
                        color: root.hasSettings ? Theme.primary : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.hasSettings
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
                    visible: DMSService.dmsAvailable && PluginService.isPluginLoaded(root.pluginId) && root.hasUpdate

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
                            const currentPluginName = root.pluginName
                            const currentPluginId = root.pluginId
                            DMSService.update(currentPluginName, response => {
                                if (response.error) {
                                    ToastService.showError("Update failed: " + response.error)
                                } else {
                                    ToastService.showInfo("Plugin updated: " + currentPluginName)
                                    PluginService.forceRescanPlugin(currentPluginId)
                                    if (DMSService.apiVersion >= 8) {
                                        DMSService.listInstalled()
                                    }
                                }
                            })
                        }
                        onEntered: {
                            tooltipLoader.active = true
                            if (tooltipLoader.item) {
                                const p = mapToItem(null, width / 2, 0)
                                tooltipLoader.item.show(I18n.tr("Update Plugin"), p.x, p.y - 40, null)
                            }
                        }
                        onExited: {
                            if (tooltipLoader.item) {
                                tooltipLoader.item.hide()
                            }
                            tooltipLoader.active = false
                        }
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: uninstallArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency) : "transparent"
                    visible: DMSService.dmsAvailable

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
                            const currentPluginName = root.pluginName
                            DMSService.uninstall(currentPluginName, response => {
                                if (response.error) {
                                    ToastService.showError("Uninstall failed: " + response.error)
                                } else {
                                    ToastService.showInfo("Plugin uninstalled: " + currentPluginName)
                                    PluginService.scanPlugins()
                                    if (root.isExpanded) {
                                        root.expandedPluginId = ""
                                    }
                                }
                            })
                        }
                        onEntered: {
                            tooltipLoader.active = true
                            if (tooltipLoader.item) {
                                const p = mapToItem(null, width / 2, 0)
                                tooltipLoader.item.show(I18n.tr("Uninstall Plugin"), p.x, p.y - 40, null)
                            }
                        }
                        onExited: {
                            if (tooltipLoader.item) {
                                tooltipLoader.item.hide()
                            }
                            tooltipLoader.active = false
                        }
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: reloadArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency) : "transparent"
                    visible: PluginService.isPluginLoaded(root.pluginId)

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
                            const currentPluginId = root.pluginId
                            const currentPluginName = root.pluginName
                            root.isReloading = true
                            if (PluginService.reloadPlugin(currentPluginId)) {
                                ToastService.showInfo("Plugin reloaded: " + currentPluginName)
                            } else {
                                ToastService.showError("Failed to reload plugin: " + currentPluginName)
                                root.isReloading = false
                            }
                        }
                        onEntered: {
                            tooltipLoader.active = true
                            if (tooltipLoader.item) {
                                const p = mapToItem(null, width / 2, 0)
                                tooltipLoader.item.show(I18n.tr("Reload Plugin"), p.x, p.y - 40, null)
                            }
                        }
                        onExited: {
                            if (tooltipLoader.item) {
                                tooltipLoader.item.hide()
                            }
                            tooltipLoader.active = false
                        }
                    }
                }

                DankToggle {
                    id: pluginToggle
                    anchors.verticalCenter: parent.verticalCenter
                    checked: PluginService.isPluginLoaded(root.pluginId)
                    onToggled: isChecked => {
                        const currentPluginId = root.pluginId
                        const currentPluginName = root.pluginName

                        if (isChecked) {
                            if (PluginService.enablePlugin(currentPluginId)) {
                                ToastService.showInfo("Plugin enabled: " + currentPluginName)
                            } else {
                                ToastService.showError("Failed to enable plugin: " + currentPluginName)
                                checked = false
                            }
                        } else {
                            if (PluginService.disablePlugin(currentPluginId)) {
                                ToastService.showInfo("Plugin disabled: " + currentPluginName)
                                if (root.isExpanded) {
                                    root.expandedPluginId = ""
                                }
                            } else {
                                ToastService.showError("Failed to disable plugin: " + currentPluginName)
                                checked = true
                            }
                        }
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
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
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
        height: root.isExpanded && root.hasSettings ? (settingsLoader.item ? settingsLoader.item.implicitHeight + Theme.spacingL * 2 : 0) : 0
        clip: true
        focus: root.isExpanded && root.hasSettings

        Keys.onPressed: event => {
            event.accepted = true
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
            active: root.isExpanded && root.hasSettings && PluginService.isPluginLoaded(root.pluginId)
            asynchronous: false

            source: {
                if (active && root.pluginSettingsPath) {
                    var path = root.pluginSettingsPath
                    if (!path.startsWith("file://")) {
                        path = "file://" + path
                    }
                    return path
                }
                return ""
            }

            onLoaded: {
                if (item && typeof PluginService !== "undefined") {
                    item.pluginService = PluginService
                }
                if (item && typeof PopoutService !== "undefined" && "popoutService" in item) {
                    item.popoutService = PopoutService
                }
                if (item) {
                    Qt.callLater(() => {
                        settingsContainer.focus = true
                        item.forceActiveFocus()
                    })
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            text: !PluginService.isPluginLoaded(root.pluginId) ?
                  "Enable plugin to access settings" :
                  (settingsLoader.status === Loader.Error ?
                   "Failed to load settings" :
                   "No configurable settings")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            visible: root.isExpanded && (!settingsLoader.active || settingsLoader.status === Loader.Error)
        }
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }
}
