import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals

Rectangle {
    id: root

    implicitHeight: BluetoothService.adapter && BluetoothService.adapter.enabled ? headerRow.height + bluetoothContent.height + Theme.spacingM : headerRow.height
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 0

    property var bluetoothCodecModalRef: null
    property var devicesBeingPaired: new Set()

    signal showCodecSelector(var device)

    function isDeviceBeingPaired(deviceAddress) {
        return devicesBeingPaired.has(deviceAddress)
    }

    function handlePairDevice(device) {
        if (!device) return

        const deviceAddr = device.address
        devicesBeingPaired.add(deviceAddr)
        devicesBeingPairedChanged()

        BluetoothService.pairDevice(device, function(response) {
            devicesBeingPaired.delete(deviceAddr)
            devicesBeingPairedChanged()

            if (response.error) {
                ToastService.showError(I18n.tr("Pairing failed"), response.error)
            } else if (!BluetoothService.enhancedPairingAvailable) {
                ToastService.showSuccess(I18n.tr("Device paired"))
            }
        })
    }

    function updateDeviceCodecDisplay(deviceAddress, codecName) {
        for (let i = 0; i < pairedRepeater.count; i++) {
            let item = pairedRepeater.itemAt(i)
            if (item && item.modelData && item.modelData.address === deviceAddress) {
                item.currentCodec = codecName
                break
            }
        }
    }



    Row {
        id: headerRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.topMargin: Theme.spacingS
        height: 40

        StyledText {
            id: headerText
            text: I18n.tr("Bluetooth Settings")
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.surfaceText
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            width: Math.max(0, parent.width - headerText.implicitWidth - scanButton.width - Theme.spacingM)
            height: parent.height
        }

        Rectangle {
            id: scanButton
            width: 100
            height: 36
            radius: 18
            color: {
                if (!BluetoothService.adapter || !BluetoothService.adapter.enabled)
                    return Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                return scanMouseArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : "transparent"
            }
            border.color: BluetoothService.adapter && BluetoothService.adapter.enabled ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
            border.width: 0
            visible: BluetoothService.adapter && BluetoothService.adapter.enabled

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: BluetoothService.adapter && BluetoothService.adapter.discovering ? "stop" : "bluetooth_searching"
                    size: 18
                    color: BluetoothService.adapter && BluetoothService.adapter.enabled ? Theme.primary : Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: BluetoothService.adapter && BluetoothService.adapter.discovering ? "Scanning" : "Scan"
                    color: BluetoothService.adapter && BluetoothService.adapter.enabled ? Theme.primary : Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: scanMouseArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: BluetoothService.adapter && BluetoothService.adapter.enabled
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (BluetoothService.adapter)
                        BluetoothService.adapter.discovering = !BluetoothService.adapter.discovering
                }
            }
        }
    }

    DankFlickable {
        id: bluetoothContent
        anchors.top: headerRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingM
        anchors.topMargin: Theme.spacingM
        visible: BluetoothService.adapter && BluetoothService.adapter.enabled
        contentHeight: bluetoothColumn.height
        clip: true

        Column {
            id: bluetoothColumn
            width: parent.width
            spacing: Theme.spacingS


            Repeater {
                id: pairedRepeater
                model: {
                    if (!BluetoothService.adapter || !BluetoothService.adapter.devices)
                        return []

                    const pins = SettingsData.bluetoothDevicePins || {}
                    const pinnedAddr = pins["preferredDevice"]
                    
                    let devices = [...BluetoothService.adapter.devices.values.filter(dev => dev && (dev.paired || dev.trusted))]
                    devices.sort((a, b) => {
                        // Pinned device first
                        if (a.address === pinnedAddr && b.address !== pinnedAddr) return -1
                        if (b.address === pinnedAddr && a.address !== pinnedAddr) return 1
                        // Then connected devices
                        if (a.connected && !b.connected) return -1
                        if (!a.connected && b.connected) return 1
                        // Then by signal strength
                        return (b.signalStrength || 0) - (a.signalStrength || 0)
                    })
                    return devices
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    property string currentCodec: BluetoothService.deviceCodecs[modelData.address] || ""

                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius

                    Component.onCompleted: {
                        if (modelData.connected && BluetoothService.isAudioDevice(modelData)) {
                            BluetoothService.refreshDeviceCodec(modelData)
                        }
                    }
                    color: {
                        if (modelData.state === BluetoothDeviceState.Connecting)
                            return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
                        if (deviceMouseArea.containsMouse)
                            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                        return Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                    }
                    border.color: {
                        if (modelData.state === BluetoothDeviceState.Connecting)
                            return Theme.warning
                        if (modelData.connected)
                            return Theme.primary
                        return Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    }
                    border.width: 0

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        DankIcon {
                            name: BluetoothService.getDeviceIcon(modelData)
                            size: Theme.iconSize - 4
                            color: {
                                if (modelData.state === BluetoothDeviceState.Connecting)
                                    return Theme.warning
                                if (modelData.connected)
                                    return Theme.primary
                                return Theme.surfaceText
                            }
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 200

                            StyledText {
                                text: modelData.name || modelData.deviceName || "Unknown Device"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: modelData.connected ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Row {
                                spacing: Theme.spacingXS

                                StyledText {
                                    text: {
                                        if (modelData.state === BluetoothDeviceState.Connecting)
                                            return "Connecting..."
                                        if (modelData.connected) {
                                            let status = "Connected"
                                            if (currentCodec) {
                                                status += " • " + currentCodec
                                            }
                                            return status
                                        }
                                        return "Paired"
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: {
                                        if (modelData.state === BluetoothDeviceState.Connecting)
                                            return Theme.warning
                                        return Theme.surfaceVariantText
                                    }
                                }

                                StyledText {
                                    text: {
                                        if (modelData.batteryAvailable && modelData.battery > 0)
                                            return "• " + Math.round(modelData.battery * 100) + "%"

                                        var btBattery = BatteryService.bluetoothDevices.find(dev => {
                                            return dev.name === (modelData.name || modelData.deviceName) ||
                                                   dev.name.toLowerCase().includes((modelData.name || modelData.deviceName).toLowerCase()) ||
                                                   (modelData.name || modelData.deviceName).toLowerCase().includes(dev.name.toLowerCase())
                                        })
                                        return btBattery ? "• " + btBattery.percentage + "%" : ""
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    visible: text.length > 0
                                }

                                StyledText {
                                    text: modelData.signalStrength !== undefined && modelData.signalStrength > 0 ? "• " + modelData.signalStrength + "%" : ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    visible: text.length > 0
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.right: pairedOptionsButton.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: pinBluetoothRow.width + Theme.spacingS * 2
                        height: 28
                        radius: height / 2
                        color: {
                            const isThisDevicePinned = (SettingsData.bluetoothDevicePins || {})["preferredDevice"] === modelData.address
                            return isThisDevicePinned ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Theme.withAlpha(Theme.surfaceText, 0.05)
                        }

                        Row {
                            id: pinBluetoothRow
                            anchors.centerIn: parent
                            spacing: 4

                            DankIcon {
                                name: "push_pin"
                                size: 16
                                color: {
                                    const isThisDevicePinned = (SettingsData.bluetoothDevicePins || {})["preferredDevice"] === modelData.address
                                    return isThisDevicePinned ? Theme.primary : Theme.surfaceText
                                }
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: {
                                    const isThisDevicePinned = (SettingsData.bluetoothDevicePins || {})["preferredDevice"] === modelData.address
                                    return isThisDevicePinned ? "Pinned" : "Pin"
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: {
                                    const isThisDevicePinned = (SettingsData.bluetoothDevicePins || {})["preferredDevice"] === modelData.address
                                    return isThisDevicePinned ? Theme.primary : Theme.surfaceText
                                }
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const pins = JSON.parse(JSON.stringify(SettingsData.bluetoothDevicePins || {}))
                                const isCurrentlyPinned = pins["preferredDevice"] === modelData.address
                                
                                if (isCurrentlyPinned) {
                                    delete pins["preferredDevice"]
                                } else {
                                    pins["preferredDevice"] = modelData.address
                                }
                                
                                SettingsData.set("bluetoothDevicePins", pins)
                            }
                        }
                    }

                    DankActionButton {
                        id: pairedOptionsButton
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "more_horiz"
                        buttonSize: 28
                        onClicked: {
                            if (bluetoothContextMenu.visible) {
                                bluetoothContextMenu.close()
                            } else {
                                bluetoothContextMenu.currentDevice = modelData
                                bluetoothContextMenu.popup(pairedOptionsButton, -bluetoothContextMenu.width + pairedOptionsButton.width, pairedOptionsButton.height + Theme.spacingXS)
                            }
                        }
                    }

                    MouseArea {
                        id: deviceMouseArea
                        anchors.fill: parent
                        anchors.rightMargin: pairedOptionsButton.width + Theme.spacingM + pinBluetoothRow.width + Theme.spacingS * 4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.connected) {
                                modelData.disconnect()
                            } else {
                                BluetoothService.connectDeviceWithTrust(modelData)
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                visible: pairedRepeater.count > 0 && availableRepeater.count > 0
            }


            Item {
                width: parent.width
                height: 80
                visible: BluetoothService.adapter && BluetoothService.adapter.discovering && availableRepeater.count === 0

                DankIcon {
                    anchors.centerIn: parent
                    name: "sync"
                    size: 24
                    color: Qt.rgba(Theme.surfaceText.r || 0.8, Theme.surfaceText.g || 0.8, Theme.surfaceText.b || 0.8, 0.4)

                    RotationAnimation on rotation {
                        running: parent.visible && BluetoothService.adapter && BluetoothService.adapter.discovering && availableRepeater.count === 0
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1500
                    }
                }
            }

            Repeater {
                id: availableRepeater
                model: {
                    if (!BluetoothService.adapter || !BluetoothService.adapter.discovering || !Bluetooth.devices)
                        return []

                    var filtered = Bluetooth.devices.values.filter(dev => {
                        return dev && !dev.paired && !dev.pairing && !dev.blocked &&
                               (dev.signalStrength === undefined || dev.signalStrength > 0)
                    })
                    return BluetoothService.sortDevices(filtered)
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    property bool canConnect: BluetoothService.canConnect(modelData)
                    property bool isBusy: BluetoothService.isDeviceBusy(modelData) || isDeviceBeingPaired(modelData.address)

                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: availableMouseArea.containsMouse && !isBusy ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: 0
                    opacity: (canConnect && !isBusy) ? 1 : 0.6

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        DankIcon {
                            name: BluetoothService.getDeviceIcon(modelData)
                            size: Theme.iconSize - 4
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 200

                            StyledText {
                                text: modelData.name || modelData.deviceName || "Unknown Device"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Row {
                                spacing: Theme.spacingXS

                                StyledText {
                                    text: {
                                        if (modelData.pairing || isBusy) return "Pairing..."
                                        if (modelData.blocked) return "Blocked"
                                        return BluetoothService.getSignalStrength(modelData)
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }

                                StyledText {
                                    text: modelData.signalStrength !== undefined && modelData.signalStrength > 0 ? "• " + modelData.signalStrength + "%" : ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    visible: text.length > 0 && !modelData.pairing && !modelData.blocked
                                }
                            }
                        }
                    }

                    StyledText {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (isBusy) return "Pairing..."
                            if (!canConnect) return "Cannot pair"
                            return "Pair"
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: (canConnect && !isBusy) ? Theme.primary : Theme.surfaceVariantText
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: availableMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: canConnect && !isBusy ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: canConnect && !isBusy
                        onClicked: {
                            root.handlePairDevice(modelData)
                        }
                    }

                }
            }

            Item {
                width: parent.width
                height: 60
                visible: !BluetoothService.adapter

                StyledText {
                    anchors.centerIn: parent
                    text: I18n.tr("No Bluetooth adapter found")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                }
            }
        }
    }

    Menu {
        id: bluetoothContextMenu
        width: 150
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        property var currentDevice: null

        background: Rectangle {
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            radius: Theme.cornerRadius
            border.width: 0
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        }

        MenuItem {
            text: bluetoothContextMenu.currentDevice && bluetoothContextMenu.currentDevice.connected ? "Disconnect" : "Connect"
            height: 32

            contentItem: StyledText {
                text: parent.text
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                leftPadding: Theme.spacingS
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: parent.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                radius: Theme.cornerRadius / 2
            }

            onTriggered: {
                if (bluetoothContextMenu.currentDevice) {
                    if (bluetoothContextMenu.currentDevice.connected) {
                        bluetoothContextMenu.currentDevice.disconnect()
                    } else {
                        BluetoothService.connectDeviceWithTrust(bluetoothContextMenu.currentDevice)
                    }
                }
            }
        }

        MenuItem {
            text: I18n.tr("Audio Codec")
            height: bluetoothContextMenu.currentDevice && BluetoothService.isAudioDevice(bluetoothContextMenu.currentDevice) && bluetoothContextMenu.currentDevice.connected ? 32 : 0
            visible: bluetoothContextMenu.currentDevice && BluetoothService.isAudioDevice(bluetoothContextMenu.currentDevice) && bluetoothContextMenu.currentDevice.connected

            contentItem: StyledText {
                text: parent.text
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                leftPadding: Theme.spacingS
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: parent.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                radius: Theme.cornerRadius / 2
            }

            onTriggered: {
                if (bluetoothContextMenu.currentDevice) {
                    showCodecSelector(bluetoothContextMenu.currentDevice)
                }
            }
        }

        MenuItem {
            text: I18n.tr("Forget Device")
            height: 32

            contentItem: StyledText {
                text: parent.text
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.error
                leftPadding: Theme.spacingS
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: parent.hovered ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.08) : "transparent"
                radius: Theme.cornerRadius / 2
            }

            onTriggered: {
                if (bluetoothContextMenu.currentDevice) {
                    if (BluetoothService.enhancedPairingAvailable) {
                        const devicePath = BluetoothService.getDevicePath(bluetoothContextMenu.currentDevice)
                        DMSService.bluetoothRemove(devicePath, response => {
                            if (response.error) {
                                ToastService.showError(I18n.tr("Failed to remove device"), response.error)
                            }
                        })
                    } else {
                        bluetoothContextMenu.currentDevice.forget()
                    }
                }
            }
        }
    }

    BluetoothPairingModal {
        id: bluetoothPairingModal
    }

    Connections {
        target: DMSService

        function onBluetoothPairingRequest(data) {
            bluetoothPairingModal.show(data)
        }
    }
}