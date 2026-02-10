import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    implicitHeight: {
        if (height > 0)
            return height;
        if (!BluetoothService.adapter?.enabled)
            return headerRow.height;
        return headerRow.height + bluetoothContent.height + Theme.spacingM;
    }
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 0

    property var bluetoothCodecModalRef: null
    property var devicesBeingPaired: new Set()

    signal showCodecSelector(var device)

    function isDeviceBeingPaired(deviceAddress) {
        return devicesBeingPaired.has(deviceAddress);
    }

    function handlePairDevice(device) {
        if (!device)
            return;
        const deviceAddr = device.address;
        const pairingSet = devicesBeingPaired;

        pairingSet.add(deviceAddr);
        devicesBeingPairedChanged();

        BluetoothService.pairDevice(device, function (response) {
            pairingSet.delete(deviceAddr);
            devicesBeingPairedChanged();

            if (response.error) {
                ToastService.showError(I18n.tr("Pairing failed"), response.error);
                return;
            }
            if (!BluetoothService.enhancedPairingAvailable) {
                ToastService.showSuccess(I18n.tr("Device paired"));
            }
        });
    }

    function updateDeviceCodecDisplay(deviceAddress, codecName) {
        for (let i = 0; i < pairedRepeater.count; i++) {
            const item = pairedRepeater.itemAt(i);
            if (!item?.modelData)
                continue;
            if (item.modelData.address !== deviceAddress)
                continue;
            item.currentCodec = codecName;
            break;
        }
    }

    function normalizePinList(value) {
        if (Array.isArray(value))
            return value.filter(v => v);
        if (typeof value === "string" && value.length > 0)
            return [value];
        return [];
    }

    function getPinnedDevices() {
        const pins = SettingsData.bluetoothDevicePins || {};
        return normalizePinList(pins["preferredDevice"]);
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

            readonly property bool adapterEnabled: BluetoothService.adapter?.enabled ?? false
            readonly property bool isDiscovering: BluetoothService.adapter?.discovering ?? false

            width: 100
            height: 36
            radius: 18
            color: scanMouseArea.containsMouse && adapterEnabled ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : "transparent"
            border.color: adapterEnabled ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
            border.width: 0
            visible: adapterEnabled

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: scanButton.isDiscovering ? "stop" : "bluetooth_searching"
                    size: 18
                    color: scanButton.adapterEnabled ? Theme.primary : Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: scanButton.isDiscovering ? I18n.tr("Scanning") : I18n.tr("Scan")
                    color: scanButton.adapterEnabled ? Theme.primary : Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            DankRipple {
                id: scanRipple
                cornerRadius: scanButton.radius
            }

            MouseArea {
                id: scanMouseArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: scanButton.adapterEnabled
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onPressed: mouse => scanRipple.trigger(mouse.x, mouse.y)
                onClicked: {
                    if (!BluetoothService.adapter)
                        return;
                    BluetoothService.adapter.discovering = !BluetoothService.adapter.discovering;
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
        visible: BluetoothService.adapter?.enabled ?? false
        contentHeight: bluetoothColumn.height
        clip: true

        readonly property int maxPinnedDevices: 3

        Column {
            id: bluetoothColumn
            width: parent.width
            spacing: Theme.spacingS

            ScriptModel {
                id: pairedDevicesModel
                objectProp: "address"
                values: {
                    if (!BluetoothService.adapter?.devices)
                        return [];

                    const pinnedList = root.getPinnedDevices();
                    const devices = [...BluetoothService.adapter.devices.values.filter(dev => dev && (dev.paired || dev.trusted))];

                    devices.sort((a, b) => {
                        const aPinnedIndex = pinnedList.indexOf(a.address);
                        const bPinnedIndex = pinnedList.indexOf(b.address);

                        if (aPinnedIndex !== -1 || bPinnedIndex !== -1) {
                            if (aPinnedIndex === -1)
                                return 1;
                            if (bPinnedIndex === -1)
                                return -1;
                            return aPinnedIndex - bPinnedIndex;
                        }

                        if (a.connected !== b.connected)
                            return a.connected ? -1 : 1;

                        return (b.signalStrength || 0) - (a.signalStrength || 0);
                    });

                    return devices;
                }
            }

            Repeater {
                id: pairedRepeater
                model: pairedDevicesModel

                delegate: Rectangle {
                    id: pairedDelegate
                    required property var modelData
                    required property int index

                    readonly property string currentCodec: BluetoothService.deviceCodecs[modelData.address] || ""
                    readonly property bool isConnecting: modelData.state === BluetoothDeviceState.Connecting
                    readonly property bool isConnected: modelData.connected
                    readonly property bool isPinned: root.getPinnedDevices().includes(modelData.address)
                    readonly property string deviceName: modelData.name || modelData.deviceName || I18n.tr("Unknown Device")

                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    border.width: 0

                    Component.onCompleted: {
                        if (!isConnected)
                            return;
                        if (!BluetoothService.isAudioDevice(modelData))
                            return;
                        BluetoothService.refreshDeviceCodec(modelData);
                    }

                    color: {
                        if (isConnecting)
                            return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12);
                        if (deviceMouseArea.containsMouse)
                            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08);
                        return Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency);
                    }

                    border.color: {
                        if (isConnecting)
                            return Theme.warning;
                        if (isConnected)
                            return Theme.primary;
                        return Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12);
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        DankIcon {
                            name: BluetoothService.getDeviceIcon(pairedDelegate.modelData)
                            size: Theme.iconSize - 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: {
                                if (pairedDelegate.isConnecting)
                                    return Theme.warning;
                                if (pairedDelegate.isConnected)
                                    return Theme.primary;
                                return Theme.surfaceText;
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 200

                            StyledText {
                                text: pairedDelegate.deviceName
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: pairedDelegate.isConnected ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                                width: parent.width
                                horizontalAlignment: Text.AlignLeft
                            }

                            Row {
                                spacing: Theme.spacingXS

                                StyledText {
                                    text: {
                                        if (pairedDelegate.isConnecting)
                                            return I18n.tr("Connecting...");
                                        if (!pairedDelegate.isConnected)
                                            return I18n.tr("Paired");
                                        if (!pairedDelegate.currentCodec)
                                            return I18n.tr("Connected");
                                        return I18n.tr("Connected") + " • " + pairedDelegate.currentCodec;
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: pairedDelegate.isConnecting ? Theme.warning : Theme.surfaceVariantText
                                }

                                StyledText {
                                    readonly property var btBattery: {
                                        const name = pairedDelegate.deviceName;
                                        return BatteryService.bluetoothDevices.find(dev => dev.name === name || dev.name.toLowerCase().includes(name.toLowerCase()) || name.toLowerCase().includes(dev.name.toLowerCase()));
                                    }
                                    text: {
                                        if (pairedDelegate.modelData.batteryAvailable && pairedDelegate.modelData.battery > 0)
                                            return "• " + Math.round(pairedDelegate.modelData.battery * 100) + "%";
                                        if (btBattery)
                                            return "• " + btBattery.percentage + "%";
                                        return "";
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    visible: text.length > 0
                                }

                                StyledText {
                                    text: pairedDelegate.modelData.signalStrength > 0 ? "• " + pairedDelegate.modelData.signalStrength + "%" : ""
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
                        color: pairedDelegate.isPinned ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Theme.withAlpha(Theme.surfaceText, 0.05)

                        Row {
                            id: pinBluetoothRow
                            anchors.centerIn: parent
                            spacing: 4

                            DankIcon {
                                name: "push_pin"
                                size: 16
                                color: pairedDelegate.isPinned ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: pairedDelegate.isPinned ? I18n.tr("Pinned") : I18n.tr("Pin")
                                font.pixelSize: Theme.fontSizeSmall
                                color: pairedDelegate.isPinned ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const pins = JSON.parse(JSON.stringify(SettingsData.bluetoothDevicePins || {}));
                                let pinnedList = root.normalizePinList(pins["preferredDevice"]);
                                const pinIndex = pinnedList.indexOf(pairedDelegate.modelData.address);

                                if (pinIndex !== -1) {
                                    pinnedList.splice(pinIndex, 1);
                                } else {
                                    pinnedList.unshift(pairedDelegate.modelData.address);
                                    if (pinnedList.length > bluetoothContent.maxPinnedDevices)
                                        pinnedList = pinnedList.slice(0, bluetoothContent.maxPinnedDevices);
                                }

                                if (pinnedList.length > 0) {
                                    pins["preferredDevice"] = pinnedList;
                                } else {
                                    delete pins["preferredDevice"];
                                }

                                SettingsData.set("bluetoothDevicePins", pins);
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
                                bluetoothContextMenu.close();
                                return;
                            }
                            bluetoothContextMenu.currentDevice = pairedDelegate.modelData;
                            bluetoothContextMenu.popup(pairedOptionsButton, -bluetoothContextMenu.width + pairedOptionsButton.width, pairedOptionsButton.height + Theme.spacingXS);
                        }
                    }

                    DankRipple {
                        id: deviceRipple
                        cornerRadius: pairedDelegate.radius
                    }

                    MouseArea {
                        id: deviceMouseArea
                        anchors.fill: parent
                        anchors.rightMargin: pairedOptionsButton.width + Theme.spacingM + pinBluetoothRow.width + Theme.spacingS * 4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => {
                            const pos = mapToItem(pairedDelegate, mouse.x, mouse.y);
                            deviceRipple.trigger(pos.x, pos.y);
                        }
                        onClicked: {
                            if (pairedDelegate.isConnected) {
                                pairedDelegate.modelData.disconnect();
                                return;
                            }
                            BluetoothService.connectDeviceWithTrust(pairedDelegate.modelData);
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
                visible: (BluetoothService.adapter?.discovering ?? false) && availableRepeater.count === 0

                DankIcon {
                    anchors.centerIn: parent
                    name: "sync"
                    size: 24
                    color: Qt.rgba(Theme.surfaceText.r || 0.8, Theme.surfaceText.g || 0.8, Theme.surfaceText.b || 0.8, 0.4)

                    RotationAnimation on rotation {
                        running: parent.visible
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1500
                    }
                }
            }

            ScriptModel {
                id: availableDevicesModel
                objectProp: "address"
                values: {
                    if (!BluetoothService.adapter?.discovering)
                        return [];
                    if (!Bluetooth.devices)
                        return [];

                    const filtered = Bluetooth.devices.values.filter(dev => dev && !dev.paired && !dev.pairing && !dev.blocked && (dev.signalStrength === undefined || dev.signalStrength > 0));
                    return BluetoothService.sortDevices(filtered);
                }
            }

            Repeater {
                id: availableRepeater
                model: availableDevicesModel

                delegate: Rectangle {
                    id: availableDelegate
                    required property var modelData
                    required property int index

                    readonly property bool canConnect: BluetoothService.canConnect(modelData)
                    readonly property bool isBusy: BluetoothService.isDeviceBusy(modelData) || root.isDeviceBeingPaired(modelData.address)
                    readonly property bool isInteractive: canConnect && !isBusy
                    readonly property string deviceName: modelData.name || modelData.deviceName || I18n.tr("Unknown Device")

                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: availableMouseArea.containsMouse && isInteractive ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: 0
                    opacity: isInteractive ? 1 : 0.6

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        DankIcon {
                            name: BluetoothService.getDeviceIcon(availableDelegate.modelData)
                            size: Theme.iconSize - 4
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 200

                            StyledText {
                                text: availableDelegate.deviceName
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                                width: parent.width
                                horizontalAlignment: Text.AlignLeft
                            }

                            Row {
                                spacing: Theme.spacingXS

                                StyledText {
                                    text: {
                                        if (availableDelegate.modelData.pairing || availableDelegate.isBusy)
                                            return I18n.tr("Pairing...");
                                        if (availableDelegate.modelData.blocked)
                                            return I18n.tr("Blocked");
                                        return BluetoothService.getSignalStrength(availableDelegate.modelData);
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }

                                StyledText {
                                    text: availableDelegate.modelData.signalStrength > 0 ? "• " + availableDelegate.modelData.signalStrength + "%" : ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    visible: text.length > 0 && !availableDelegate.modelData.pairing && !availableDelegate.modelData.blocked
                                }
                            }
                        }
                    }

                    StyledText {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (availableDelegate.isBusy)
                                return I18n.tr("Pairing...");
                            if (!availableDelegate.canConnect)
                                return I18n.tr("Cannot pair");
                            return I18n.tr("Pair");
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: availableDelegate.isInteractive ? Theme.primary : Theme.surfaceVariantText
                        font.weight: Font.Medium
                    }

                    DankRipple {
                        id: availableRipple
                        cornerRadius: availableDelegate.radius
                    }

                    MouseArea {
                        id: availableMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: availableDelegate.isInteractive ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: availableDelegate.isInteractive
                        onPressed: mouse => availableRipple.trigger(mouse.x, mouse.y)
                        onClicked: root.handlePairDevice(availableDelegate.modelData)
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

        readonly property bool hasDevice: currentDevice !== null
        readonly property bool deviceConnected: currentDevice?.connected ?? false
        readonly property bool showCodecOption: hasDevice && deviceConnected && BluetoothService.isAudioDevice(currentDevice)

        background: Rectangle {
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            radius: Theme.cornerRadius
            border.width: 0
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        }

        MenuItem {
            text: bluetoothContextMenu.deviceConnected ? I18n.tr("Disconnect") : I18n.tr("Connect")
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
                if (!bluetoothContextMenu.hasDevice)
                    return;
                if (bluetoothContextMenu.deviceConnected) {
                    bluetoothContextMenu.currentDevice.disconnect();
                    return;
                }
                BluetoothService.connectDeviceWithTrust(bluetoothContextMenu.currentDevice);
            }
        }

        MenuItem {
            text: I18n.tr("Audio Codec")
            height: bluetoothContextMenu.showCodecOption ? 32 : 0
            visible: bluetoothContextMenu.showCodecOption

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
                if (!bluetoothContextMenu.hasDevice)
                    return;
                if (!bluetoothContextMenu.currentDevice.connected)
                    return;
                if (!BluetoothService.isAudioDevice(bluetoothContextMenu.currentDevice))
                    return;
                showCodecSelector(bluetoothContextMenu.currentDevice);
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
                if (!bluetoothContextMenu.hasDevice)
                    return;
                if (!BluetoothService.enhancedPairingAvailable) {
                    bluetoothContextMenu.currentDevice.forget();
                    return;
                }

                const devicePath = BluetoothService.getDevicePath(bluetoothContextMenu.currentDevice);
                DMSService.bluetoothRemove(devicePath, response => {
                    if (!response.error)
                        return;
                    ToastService.showError(I18n.tr("Failed to remove device"), response.error);
                });
            }
        }
    }

    Connections {
        target: DMSService

        function onBluetoothPairingRequest(data) {
            const modal = PopoutService.bluetoothPairingModal;
            if (!modal)
                return;
            if (modal.token === data.token)
                return;
            modal.show(data);
        }
    }
}
