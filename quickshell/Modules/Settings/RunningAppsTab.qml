import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

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

            SettingsCard {
                width: parent.width
                iconName: "apps"
                title: I18n.tr("Running Apps Settings")
                settingKey: "runningApps"

                SettingsToggleRow {
                    text: I18n.tr("Running Apps Only In Current Workspace")
                    description: I18n.tr("Show only apps running in current workspace")
                    checked: SettingsData.runningAppsCurrentWorkspace
                    onToggled: checked => SettingsData.set("runningAppsCurrentWorkspace", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "find_replace"
                title: I18n.tr("App ID Substitutions")
                settingKey: "appIdSubstitutions"
                tags: ["app", "icon", "substitution", "replacement", "pattern", "window", "class", "regex"]

                headerActions: [
                    DankActionButton {
                        buttonSize: 36
                        iconName: "restart_alt"
                        iconSize: 20
                        visible: JSON.stringify(SettingsData.appIdSubstitutions) !== JSON.stringify(SettingsData.getDefaultAppIdSubstitutions())
                        backgroundColor: Theme.surfaceContainer
                        iconColor: Theme.surfaceVariantText
                        onClicked: SettingsData.resetAppIdSubstitutions()
                    },
                    DankActionButton {
                        buttonSize: 36
                        iconName: "add"
                        iconSize: 20
                        backgroundColor: Theme.surfaceContainer
                        iconColor: Theme.primary
                        onClicked: SettingsData.addAppIdSubstitution("", "", "exact")
                    }
                ]

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: I18n.tr("Map window class names to icon names for proper icon display")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                        bottomPadding: Theme.spacingS
                    }

                    Repeater {
                        model: SettingsData.appIdSubstitutions

                        delegate: Rectangle {
                            id: subItem
                            width: parent.width
                            height: subColumn.implicitHeight + Theme.spacingM
                            radius: Theme.cornerRadius
                            color: Theme.withAlpha(Theme.surfaceContainer, 0.5)

                            Column {
                                id: subColumn
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                spacing: Theme.spacingS

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    Column {
                                        width: (parent.width - deleteBtn.width - Theme.spacingS) / 2
                                        spacing: 2

                                        StyledText {
                                            text: I18n.tr("Pattern")
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: Theme.surfaceVariantText
                                        }

                                        DankTextField {
                                            id: patternField
                                            width: parent.width
                                            text: modelData.pattern
                                            font.pixelSize: Theme.fontSizeSmall
                                            onEditingFinished: SettingsData.updateAppIdSubstitution(index, text, replacementField.text, modelData.type)
                                        }
                                    }

                                    Column {
                                        width: (parent.width - deleteBtn.width - Theme.spacingS) / 2
                                        spacing: 2

                                        StyledText {
                                            text: I18n.tr("Replacement")
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: Theme.surfaceVariantText
                                        }

                                        DankTextField {
                                            id: replacementField
                                            width: parent.width
                                            text: modelData.replacement
                                            font.pixelSize: Theme.fontSizeSmall
                                            onEditingFinished: SettingsData.updateAppIdSubstitution(index, patternField.text, text, modelData.type)
                                        }
                                    }

                                    Item {
                                        id: deleteBtn
                                        width: 32
                                        height: 40
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.cornerRadius
                                            color: deleteArea.containsMouse ? Theme.withAlpha(Theme.error, 0.2) : "transparent"
                                        }

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "delete"
                                            size: 18
                                            color: deleteArea.containsMouse ? Theme.error : Theme.surfaceVariantText
                                        }

                                        MouseArea {
                                            id: deleteArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: SettingsData.removeAppIdSubstitution(index)
                                        }
                                    }
                                }

                                Column {
                                    width: 120
                                    spacing: 2

                                    StyledText {
                                        text: I18n.tr("Type")
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        color: Theme.surfaceVariantText
                                    }

                                    DankDropdown {
                                        width: parent.width
                                        compactMode: true
                                        dropdownWidth: 120
                                        currentValue: modelData.type
                                        options: ["exact", "contains", "regex"]
                                        onValueChanged: value => SettingsData.updateAppIdSubstitution(index, modelData.pattern, modelData.replacement, value)
                                    }
                                }
                            }
                        }
                    }

                }
            }
        }
    }
}
