import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Row {
    id: root

    property string deviceName: ""
    property string instanceId: ""

    signal iconClicked()

    height: 40
    spacing: 0

    property string targetDeviceName: {
        if (!DisplayService.brightnessAvailable || !DisplayService.devices || DisplayService.devices.length === 0) {
            return ""
        }

        if (deviceName && deviceName.length > 0) {
            const found = DisplayService.devices.find(dev => dev.name === deviceName)
            return found ? found.name : ""
        }

        const currentDeviceName = DisplayService.currentDevice
        if (currentDeviceName) {
            const found = DisplayService.devices.find(dev => dev.name === currentDeviceName)
            return found ? found.name : ""
        }

        return DisplayService.devices.length > 0 ? DisplayService.devices[0].name : ""
    }

    property var targetDevice: {
        if (!targetDeviceName || !DisplayService.devices) {
            return null
        }

        return DisplayService.devices.find(dev => dev.name === targetDeviceName) || null
    }

    property real targetBrightness: {
        if (!targetDeviceName) {
            return 0
        }

        return DisplayService.getDeviceBrightness(targetDeviceName)
    }

    Rectangle {
        width: Theme.iconSize + Theme.spacingS * 2
        height: Theme.iconSize + Theme.spacingS * 2
        anchors.verticalCenter: parent.verticalCenter
        radius: (Theme.iconSize + Theme.spacingS * 2) / 2
        color: iconArea.containsMouse
               ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
               : Theme.withAlpha(Theme.primary, 0)

        MouseArea {
            id: iconArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: DisplayService.devices && DisplayService.devices.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor

            onClicked: {
                if (DisplayService.devices && DisplayService.devices.length > 1) {
                    root.iconClicked()
                }
            }

            onEntered: {
                tooltipLoader.active = true
                if (tooltipLoader.item) {
                    const tooltipText = targetDevice ? "bl device: " + targetDevice.name : "Backlight Control"
                    const p = iconArea.mapToItem(null, iconArea.width / 2, 0)
                    tooltipLoader.item.show(tooltipText, p.x, p.y - 40, null)
                }
            }

            onExited: {
                if (tooltipLoader.item) {
                    tooltipLoader.item.hide()
                }
                tooltipLoader.active = false
            }

            DankIcon {
                anchors.centerIn: parent
                name: {
                    if (!DisplayService.brightnessAvailable || !targetDevice) {
                        return "brightness_low"
                    }

                    if (targetDevice.class === "backlight" || targetDevice.class === "ddc") {
                        const brightness = targetBrightness
                        if (brightness <= 33) return "brightness_low"
                        if (brightness <= 66) return "brightness_medium"
                        return "brightness_high"
                    } else if (targetDevice.name.includes("kbd")) {
                        return "keyboard"
                    } else {
                        return "lightbulb"
                    }
                }
                size: Theme.iconSize
                color: DisplayService.brightnessAvailable && targetDevice && targetBrightness > 0 ? Theme.primary : Theme.surfaceText
            }
        }
    }

    DankSlider {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - (Theme.iconSize + Theme.spacingS * 2)
        enabled: DisplayService.brightnessAvailable && targetDeviceName.length > 0
        minimum: 1
        maximum: 100
        value: targetBrightness
        onSliderValueChanged: function(newValue) {
            if (DisplayService.brightnessAvailable && targetDeviceName) {
                DisplayService.setBrightness(newValue, targetDeviceName)
            }
        }
        thumbOutlineColor: Theme.surfaceContainer
        trackColor: Theme.surfaceContainerHigh
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }
}