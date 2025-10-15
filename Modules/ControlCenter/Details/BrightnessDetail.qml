import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property string currentDeviceName: ""
    property string instanceId: ""

    signal deviceNameChanged(string newDeviceName)

    implicitHeight: brightnessContent.height + Theme.spacingM
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 0

    DankFlickable {
        id: brightnessContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingM
        anchors.topMargin: Theme.spacingM
        contentHeight: brightnessColumn.height
        clip: true

        Column {
            id: brightnessColumn
            width: parent.width
            spacing: Theme.spacingS

            Item {
                width: parent.width
                height: 100
                visible: !DisplayService.brightnessAvailable || !DisplayService.devices || DisplayService.devices.length === 0

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM

                    DankIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: DisplayService.brightnessAvailable ? "brightness_6" : "error"
                        size: 32
                        color: DisplayService.brightnessAvailable ? Theme.primary : Theme.error
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: DisplayService.brightnessAvailable ? "No brightness devices available" : "Brightness control not available"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Repeater {
                model: DisplayService.devices || []
                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: parent.width
                    height: 80
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHighest
                    border.color: modelData.name === currentDeviceName ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: modelData.name === currentDeviceName ? 2 : 0

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            DankIcon {
                                name: {
                                    const deviceClass = modelData.class || ""
                                    const deviceName = modelData.name || ""

                                    if (deviceClass === "backlight" || deviceClass === "ddc") {
                                        const brightness = modelData.percentage || 50
                                        if (brightness <= 33) return "brightness_low"
                                        if (brightness <= 66) return "brightness_medium"
                                        return "brightness_high"
                                    } else if (deviceName.includes("kbd")) {
                                        return "keyboard"
                                    } else {
                                        return "lightbulb"
                                    }
                                }
                                size: Theme.iconSize
                                color: modelData.name === currentDeviceName ? Theme.primary : Theme.surfaceText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: (modelData.percentage || 50) + "%"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.parent.width - parent.parent.anchors.leftMargin - parent.spacing - 50 - Theme.spacingM

                            StyledText {
                                text: {
                                    const name = modelData.name || ""
                                    const deviceClass = modelData.class || ""
                                    if (deviceClass === "backlight") {
                                        return name.replace("_", " ").replace(/\b\w/g, c => c.toUpperCase())
                                    }
                                    return name
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: modelData.name === currentDeviceName ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            StyledText {
                                text: modelData.name
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            StyledText {
                                text: {
                                    const deviceClass = modelData.class || ""
                                    if (deviceClass === "backlight") return "Backlight device"
                                    if (deviceClass === "ddc") return "DDC/CI monitor"
                                    if (deviceClass === "leds") return "LED device"
                                    return deviceClass
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            currentDeviceName = modelData.name
                            deviceNameChanged(modelData.name)
                        }
                    }

                }
            }
        }
    }
}
