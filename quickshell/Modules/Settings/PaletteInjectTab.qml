import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    Component.onCompleted: {
        if (!PaletteInjectService.loaded)
            PaletteInjectService.load();
    }

    SettingsPage {
        id: mainColumn

        SettingsCard {
            width: parent.width
            iconName: "colorize"
            title: I18n.tr("Injected palettes")
            settingKey: "paletteInject"
            tags: ["palette", "matugen", "inject", "namespace", "command", "template", "color"]
            visible: Theme.matugenAvailable

            headerActions: [
                DankActionButton {
                    buttonSize: 36
                    iconName: "add"
                    iconSize: 20
                    Accessible.name: I18n.tr("Add")
                    iconColor: Theme.primary
                    onClicked: PaletteInjectService.addPalette()
                }
            ]

            SettingsRow {
                body: Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: I18n.tr("Run an external command on each wallpaper change and merge its JSON palette into matugen under a namespace, so templates can use e.g. {{name.color0}}. The command receives the wallpaper as {image} / $DMS_WALLPAPER and the mode as {mode} / $DMS_MODE.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                        bottomPadding: Theme.spacingS
                    }

                    StyledText {
                        visible: PaletteInjectService.palettes.length === 0
                        text: I18n.tr("No palettes configured. Use + to add one.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    Repeater {
                        model: PaletteInjectService.palettes

                        delegate: Rectangle {
                            id: paletteItem
                            required property var modelData
                            required property int index

                            width: parent.width
                            height: paletteColumn.implicitHeight + Theme.spacingM * 2
                            radius: Theme.cornerRadius
                            color: Theme.floatingWindowFieldColor

                            Column {
                                id: paletteColumn
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    StyledText {
                                        id: paletteLabel
                                        text: paletteItem.modelData.namespace ? paletteItem.modelData.namespace : I18n.tr("Palette %1", "palette heading, %1 is the palette number").arg(paletteItem.index + 1)
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Theme.fontWeightMedium
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Item {
                                        width: Math.max(0, parent.width - paletteLabel.implicitWidth - enableToggle.width - deleteBtn.width - Theme.spacingS * 2)
                                        height: 1
                                    }

                                    DankToggle {
                                        id: enableToggle
                                        width: 40
                                        height: 24
                                        hideText: true
                                        checked: paletteItem.modelData.enabled !== false
                                        onToggled: checked => PaletteInjectService.updatePalette(paletteItem.index, "enabled", checked)
                                    }

                                    Item {
                                        id: deleteBtn
                                        Accessible.role: Accessible.Button
                                        Accessible.name: I18n.tr("Remove")
                                        width: 28
                                        height: 28
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.cornerRadius
                                            color: deleteArea.containsMouse ? Theme.withAlpha(Theme.error, 0.2) : Theme.withAlpha(Theme.error, 0)
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
                                            onClicked: PaletteInjectService.removePalette(paletteItem.index)
                                        }
                                    }
                                }

                                DankTextField {
                                    outlined: true
                                    leftIconName: "label"
                                    labelText: I18n.tr("Name")
                                    placeholderText: I18n.tr("Palette name")
                                    width: parent.width
                                    text: paletteItem.modelData.namespace || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    onEditingFinished: PaletteInjectService.updatePalette(paletteItem.index, "namespace", text)
                                }

                                DankTextField {
                                    outlined: true
                                    leftIconName: "terminal"
                                    labelText: I18n.tr("Command")
                                    width: parent.width
                                    text: paletteItem.modelData.command || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    onEditingFinished: PaletteInjectService.updatePalette(paletteItem.index, "command", text)
                                }

                                DankTextField {
                                    outlined: true
                                    leftIconName: "data_array"
                                    labelText: I18n.tr("Arguments")
                                    supportingText: I18n.tr("Space-separated; {image} and {mode} are substituted")
                                    width: parent.width
                                    text: PaletteInjectService.argsText(paletteItem.modelData)
                                    font.pixelSize: Theme.fontSizeSmall
                                    onEditingFinished: PaletteInjectService.updatePalette(paletteItem.index, "args", PaletteInjectService.argsFromText(text))
                                }

                                DankTextField {
                                    outlined: true
                                    leftIconName: "description"
                                    labelText: I18n.tr("JSON output path")
                                    supportingText: I18n.tr("File the command writes; leave empty to read stdout")
                                    width: parent.width
                                    text: paletteItem.modelData.output_file || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    onEditingFinished: PaletteInjectService.updatePalette(paletteItem.index, "output_file", text)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
