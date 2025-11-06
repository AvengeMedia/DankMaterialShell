import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property string initialDeviceName: ""
    property string instanceId: ""
    property string screenName: ""

    signal deviceNameChanged(string newDeviceName)

    property string currentDeviceName: ""

    function resolveDeviceName() {
        if (!DisplayService.brightnessAvailable || !DisplayService.devices || DisplayService.devices.length === 0) {
            return ""
        }

        if (screenName && screenName.length > 0) {
            const pins = SettingsData.brightnessDevicePins || {}
            const pinnedDevice = pins[screenName]
            if (pinnedDevice && pinnedDevice.length > 0) {
                const found = DisplayService.devices.find(dev => dev.name === pinnedDevice)
                if (found) {
                    return found.name
                }
            }
        }

        if (initialDeviceName && initialDeviceName.length > 0) {
            const found = DisplayService.devices.find(dev => dev.name === initialDeviceName)
            if (found) {
                return found.name
            }
        }

        const currentDeviceNameFromService = DisplayService.currentDevice
        if (currentDeviceNameFromService) {
            const found = DisplayService.devices.find(dev => dev.name === currentDeviceNameFromService)
            if (found) {
                return found.name
            }
        }

        const backlight = DisplayService.devices.find(d => d.class === "backlight")
        if (backlight) {
            return backlight.name
        }

        const ddc = DisplayService.devices.find(d => d.class === "ddc")
        if (ddc) {
            return ddc.name
        }

        return DisplayService.devices.length > 0 ? DisplayService.devices[0].name : ""
    }

    Component.onCompleted: {
        currentDeviceName = resolveDeviceName()
    }

    property bool isPinnedToScreen: {
        if (!screenName || screenName.length === 0) {
            return false
        }
        const pins = SettingsData.brightnessDevicePins || {}
        return pins[screenName] === currentDeviceName
    }

    function togglePinToScreen() {
        if (!screenName || screenName.length === 0 || !currentDeviceName || currentDeviceName.length === 0) {
            return
        }

        const pins = JSON.parse(JSON.stringify(SettingsData.brightnessDevicePins || {}))

        if (isPinnedToScreen) {
            delete pins[screenName]
        } else {
            pins[screenName] = currentDeviceName
        }

        SettingsData.set("brightnessDevicePins", pins)
    }

    implicitHeight: brightnessContent.height + Theme.spacingM
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
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

            Rectangle {
                width: parent.width
                height: 40
                visible: screenName && screenName.length > 0 && DisplayService.devices && DisplayService.devices.length > 1
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)

                Item {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "monitor"
                            size: Theme.iconSize
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: screenName || "Unknown Monitor"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: pinRow.width + Theme.spacingS * 2
                        height: 28
                        radius: height / 2
                        color: isPinnedToScreen ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Theme.withAlpha(Theme.surfaceText, 0.05)

                        Row {
                            id: pinRow
                            anchors.centerIn: parent
                            spacing: 4

                            DankIcon {
                                name: isPinnedToScreen ? "push_pin" : "push_pin"
                                size: 16
                                color: isPinnedToScreen ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: isPinnedToScreen ? "Pinned" : "Pin"
                                font.pixelSize: Theme.fontSizeSmall
                                color: isPinnedToScreen ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePinToScreen()
                        }
                    }
                }
            }

            Repeater {
                model: DisplayService.devices || []
                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    property real deviceBrightness: {
                        DisplayService.brightnessVersion
                        return DisplayService.getDeviceBrightness(modelData.name)
                    }

                    width: parent.width
                    height: 100
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                    border.color: modelData.name === currentDeviceName ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: modelData.name === currentDeviceName ? 2 : 0

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        Item {
                            width: parent.width
                            height: Math.max(deviceIconColumn.height, deviceInfoColumn.height, exponentControls.height)

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingM

                                Column {
                                    id: deviceIconColumn
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    DankIcon {
                                        name: {
                                            const deviceClass = modelData.class || ""
                                            const deviceName = modelData.name || ""

                                            if (deviceClass === "backlight" || deviceClass === "ddc") {
                                                if (deviceBrightness <= 33)
                                                    return "brightness_low"
                                                if (deviceBrightness <= 66)
                                                    return "brightness_medium"
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
                                        text: Math.round(deviceBrightness) + "%"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }

                                Column {
                                    id: deviceInfoColumn
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.parent.width - deviceIconColumn.width - exponentControls.width - Theme.spacingM * 3

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
                                            if (deviceClass === "backlight")
                                                return "Backlight device"
                                            if (deviceClass === "ddc")
                                                return "DDC/CI monitor"
                                            if (deviceClass === "leds")
                                                return "LED device"
                                            return deviceClass
                                        }
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }
                            }

                            Row {
                                id: exponentControls
                                width: 140
                                height: 28
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingXS
                                visible: SessionData.getBrightnessExponential(modelData.name)
                                z: 1

                                StyledRect {
                                    width: 28
                                    height: 28
                                    radius: Theme.cornerRadius
                                    color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                                    opacity: SessionData.getBrightnessExponent(modelData.name) > 1.0 ? 1.0 : 0.4

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "remove"
                                        size: 14
                                        color: Theme.surfaceText
                                    }

                                    StateLayer {
                                        stateColor: Theme.primary
                                        cornerRadius: parent.radius
                                        enabled: SessionData.getBrightnessExponent(modelData.name) > 1.0
                                        onClicked: {
                                            const current = SessionData.getBrightnessExponent(modelData.name)
                                            const newValue = Math.max(1.0, Math.round((current - 0.1) * 10) / 10)
                                            SessionData.setBrightnessExponent(modelData.name, newValue)
                                        }
                                    }
                                }

                                StyledRect {
                                    width: 50
                                    height: 28
                                    radius: Theme.cornerRadius
                                    color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                                    border.width: 0

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: SessionData.getBrightnessExponent(modelData.name).toFixed(1)
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                        color: Theme.primary
                                    }
                                }

                                StyledRect {
                                    width: 28
                                    height: 28
                                    radius: Theme.cornerRadius
                                    color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                                    opacity: SessionData.getBrightnessExponent(modelData.name) < 2.5 ? 1.0 : 0.4

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "add"
                                        size: 14
                                        color: Theme.surfaceText
                                    }

                                    StateLayer {
                                        stateColor: Theme.primary
                                        cornerRadius: parent.radius
                                        enabled: SessionData.getBrightnessExponent(modelData.name) < 2.5
                                        onClicked: {
                                            const current = SessionData.getBrightnessExponent(modelData.name)
                                            const newValue = Math.min(2.5, Math.round((current + 0.1) * 10) / 10)
                                            SessionData.setBrightnessExponent(modelData.name, newValue)
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 24
                            radius: height / 2
                            color: SessionData.getBrightnessExponential(modelData.name) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Theme.withAlpha(Theme.surfaceText, 0.05)

                            Row {
                                anchors.centerIn: parent
                                spacing: 4

                                DankIcon {
                                    name: "show_chart"
                                    size: 14
                                    color: SessionData.getBrightnessExponential(modelData.name) ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: SessionData.getBrightnessExponential(modelData.name) ? "Exponential" : "Linear"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: SessionData.getBrightnessExponential(modelData.name) ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const currentState = SessionData.getBrightnessExponential(modelData.name)
                                    SessionData.setBrightnessExponential(modelData.name, !currentState)
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.bottomMargin: 28
                        anchors.rightMargin: SessionData.getBrightnessExponential(modelData.name) ? 145 : 0
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (screenName && screenName.length > 0 && modelData.name !== currentDeviceName) {
                                const pins = JSON.parse(JSON.stringify(SettingsData.brightnessDevicePins || {}))
                                if (pins[screenName]) {
                                    delete pins[screenName]
                                    SettingsData.set("brightnessDevicePins", pins)
                                }
                            }
                            currentDeviceName = modelData.name
                            deviceNameChanged(modelData.name)
                        }
                    }
                }
            }
        }
    }
}
