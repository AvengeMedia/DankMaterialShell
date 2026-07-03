pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property string colorMode: "primary"
    property color customColor: "#ffffff"
    property string pickerTitle: I18n.tr("Choose Color")

    signal colorModeSelected(string mode)
    signal customColorSelected(color selectedColor)

    width: parent?.width ?? 0
    height: colorColumn.height + Theme.spacingM * 2

    Column {
        id: colorColumn
        width: parent.width - Theme.spacingM * 2
        x: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingM

        StyledText {
            text: I18n.tr("Color")
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
        }

        Row {
            width: parent.width
            spacing: Theme.spacingS

            Repeater {
                model: [
                    {
                        id: "primary",
                        label: I18n.tr("Primary"),
                        color: Theme.primary
                    },
                    {
                        id: "secondary",
                        label: I18n.tr("Secondary"),
                        color: Theme.secondary
                    },
                    {
                        id: "custom",
                        label: I18n.tr("Custom"),
                        color: root.customColor
                    }
                ]

                Rectangle {
                    required property var modelData
                    required property int index

                    width: (parent.width - Theme.spacingS * 2) / 3
                    height: 60
                    radius: Theme.cornerRadius
                    color: root.colorMode === modelData.id ? Theme.primarySelected : Theme.surfaceHover
                    border.color: root.colorMode === modelData.id ? Theme.primary : Theme.withAlpha(Theme.primary, 0)
                    border.width: 2

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS

                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            color: modelData.color
                            border.color: Theme.outline
                            border.width: 1
                            anchors.horizontalCenter: parent.horizontalCenter

                            DankIcon {
                                visible: modelData.id === "custom"
                                anchors.centerIn: parent
                                name: "colorize"
                                size: 14
                                color: Theme.background
                            }
                        }

                        StyledText {
                            text: modelData.label
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.id !== "custom") {
                                root.colorModeSelected(modelData.id);
                                return;
                            }
                            PopoutService.colorPickerModal.selectedColor = root.customColor;
                            PopoutService.colorPickerModal.pickerTitle = root.pickerTitle;
                            PopoutService.colorPickerModal.onColorSelectedCallback = function (selectedColor) {
                                root.customColorSelected(selectedColor);
                                root.colorModeSelected("custom");
                            };
                            PopoutService.colorPickerModal.show();
                        }
                    }
                }
            }
        }
    }
}
