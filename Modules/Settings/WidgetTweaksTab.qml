import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: widgetTweaksTab

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
                height: workspaceSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: workspaceSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "view_module"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Workspace Settings")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Workspace Index Numbers")
                        description: "Show workspace index numbers in the top bar workspace switcher"
                        checked: SettingsData.showWorkspaceIndex
                        onToggled: checked => {
                                       return SettingsData.setShowWorkspaceIndex(
                                           checked)
                                   }
                    }

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Workspace Padding")
                        description: "Always show a minimum of 3 workspaces, even if fewer are available"
                        checked: SettingsData.showWorkspacePadding
                        onToggled: checked => {
                                       return SettingsData.setShowWorkspacePadding(
                                           checked)
                                   }
                    }

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Show Workspace Apps")
                        description: "Display application icons in workspace indicators"
                        checked: SettingsData.showWorkspaceApps
                        onToggled: checked => {
                                       return SettingsData.setShowWorkspaceApps(
                                           checked)
                                   }
                    }

		    Row {
                        width: parent.width - Theme.spacingL
                        spacing: Theme.spacingL
                        visible: SettingsData.showWorkspaceApps
                        opacity: visible ? 1 : 0
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingL

                        Column {
                            width: 120
                            spacing: Theme.spacingS

                            StyledText {
                                text: I18n.tr("Max apps to show")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            DankTextField {
                                width: 100
                                height: 28
                                placeholderText: "#ffffff"
                                text: SettingsData.maxWorkspaceIcons
                                maximumLength: 7
                                font.pixelSize: Theme.fontSizeSmall
                                topPadding: Theme.spacingXS
                                bottomPadding: Theme.spacingXS
                                onEditingFinished: {
                                    SettingsData.setMaxWorkspaceIcons(parseInt(text, 10))
                                }
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.mediumDuration
                                easing.type: Theme.emphasizedEasing
                            }
                        }
                    }

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Per-Monitor Workspaces")
                        description: "Show only workspaces belonging to each specific monitor."
                        checked: SettingsData.workspacesPerMonitor
                        onToggled: checked => {
                            return SettingsData.setWorkspacesPerMonitor(checked);
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: mediaSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: mediaSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "music_note"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Media Player Settings")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Wave Progress Bars")
                        description: "Use animated wave progress bars for media playback"
                        checked: SettingsData.waveProgressEnabled
                        onToggled: checked => {
                            return SettingsData.setWaveProgressEnabled(checked)
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: runningAppsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: runningAppsSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "apps"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Running Apps Settings")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Running Apps Only In Current Workspace")
                        description: "Show only apps running in current workspace"
                        checked: SettingsData.runningAppsCurrentWorkspace
                        onToggled: checked => {
                                       return SettingsData.setRunningAppsCurrentWorkspace(
                                           checked)
                                   }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: workspaceIconsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0
                visible: SettingsData.hasNamedWorkspaces()

                Column {
                    id: workspaceIconsSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "label"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Named Workspace Icons")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Configure icons for named workspaces. Icons take priority over numbers when both are enabled.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.outline
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: SettingsData.getNamedWorkspaces()

                        Rectangle {
                            width: parent.width
                            height: workspaceIconRow.implicitHeight + Theme.spacingM
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.surfaceContainer.r,
                                           Theme.surfaceContainer.g,
                                           Theme.surfaceContainer.b, 0.5)
                            border.color: Qt.rgba(Theme.outline.r,
                                                  Theme.outline.g,
                                                  Theme.outline.b, 0.3)
                            border.width: 0

                            Row {
                                id: workspaceIconRow

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingM
                                spacing: Theme.spacingM

                                StyledText {
                                    text: "\"" + modelData + "\""
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 150
                                    elide: Text.ElideRight
                                }

                                DankIconPicker {
                                    id: iconPicker
                                    anchors.verticalCenter: parent.verticalCenter

                                    Component.onCompleted: {
                                        var iconData = SettingsData.getWorkspaceNameIcon(
                                                    modelData)
                                        if (iconData) {
                                            setIcon(iconData.value,
                                                    iconData.type)
                                        }
                                    }

                                    onIconSelected: (iconName, iconType) => {
                                                        SettingsData.setWorkspaceNameIcon(
                                                            modelData, {
                                                                "type": iconType,
                                                                "value": iconName
                                                            })
                                                        setIcon(iconName,
                                                                iconType)
                                                    }

                                    Connections {
                                        target: SettingsData
                                        function onWorkspaceIconsUpdated() {
                                            var iconData = SettingsData.getWorkspaceNameIcon(
                                                        modelData)
                                            if (iconData) {
                                                iconPicker.setIcon(
                                                            iconData.value,
                                                            iconData.type)
                                            } else {
                                                iconPicker.setIcon("", "icon")
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: Theme.cornerRadius
                                    color: clearMouseArea.containsMouse ? Theme.errorHover : Theme.surfaceContainer
                                    border.color: clearMouseArea.containsMouse ? Theme.error : Theme.outline
                                    border.width: 0
                                    anchors.verticalCenter: parent.verticalCenter

                                    DankIcon {
                                        name: "close"
                                        size: 16
                                        color: clearMouseArea.containsMouse ? Theme.error : Theme.outline
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        id: clearMouseArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            SettingsData.removeWorkspaceNameIcon(
                                                        modelData)
                                        }
                                    }
                                }

                                Item {
                                    width: parent.width - 150 - 240 - 28 - Theme.spacingM * 4
                                    height: 1
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
