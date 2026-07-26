pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Card {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    readonly property var device: DankConnectService.primaryDevice
    readonly property var pairingRequest: DankConnectService.pairingRequest
    readonly property bool hasBattery: !!device && typeof device.batteryCharge === "number" && device.batteryCharge >= 0

    function statusText() {
        if (!DankConnectService.connected)
            return I18n.tr("Disconnected");
        if (!device)
            return I18n.tr("No devices");
        const connection = device.isReachable ? I18n.tr("Connected") : I18n.tr("Disconnected");
        const pairing = device.isPaired ? I18n.tr("Paired") : I18n.tr("Not paired");
        return connection + " • " + pairing;
    }

    function batteryText() {
        if (!hasBattery)
            return "";
        const charge = Math.round(device.batteryCharge) + "%";
        return device.batteryCharging ? charge + " • " + I18n.tr("Charging") : charge;
    }

    function reportError(title, response) {
        if (response?.error)
            ToastService.showError(title, response.error);
    }

    Row {
        id: contentRow

        anchors.fill: parent
        spacing: Theme.spacingL

        Item {
            width: Math.max(180, contentRow.width - actionRow.width - trailingPanel.width - contentRow.spacing * 2)
            height: parent.height

            Row {
                anchors.fill: parent
                spacing: Theme.spacingM

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "smartphone"
                    size: 36
                    color: root.device?.isReachable ? Theme.primary : Theme.surfaceTextSecondary
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 36 - parent.spacing
                    spacing: Theme.spacingXS

                    StyledText {
                        width: parent.width
                        text: root.device?.name || "DankConnect"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    StyledText {
                        width: parent.width
                        text: root.statusText()
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    StyledText {
                        width: parent.width
                        visible: root.hasBattery
                        text: root.batteryText()
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }
        }

        Row {
            id: actionRow

            anchors.verticalCenter: parent.verticalCenter
            width: implicitWidth
            spacing: Theme.spacingXS

            DankActionButton {
                buttonSize: 34
                iconSize: 17
                iconName: "ring_volume"
                iconColor: Theme.primary
                tooltipText: I18n.tr("Ring")
                enabled: DankConnectService.canRing(root.device)
                onClicked: DankConnectService.ringDevice(root.device.id, response => root.reportError(I18n.tr("Ring"), response))
            }

            DankActionButton {
                buttonSize: 34
                iconSize: 17
                iconName: "network_ping"
                iconColor: Theme.primary
                tooltipText: I18n.tr("Ping")
                enabled: DankConnectService.canPing(root.device)
                onClicked: DankConnectService.pingDevice(root.device.id, response => root.reportError(I18n.tr("Ping"), response))
            }

            DankActionButton {
                buttonSize: 34
                iconSize: 17
                iconName: "content_paste_go"
                iconColor: Theme.primary
                tooltipText: I18n.tr("Send Clipboard")
                enabled: DankConnectService.canSendClipboard(root.device)
                onClicked: DankConnectService.sendClipboard(root.device.id, response => root.reportError(I18n.tr("Send Clipboard"), response))
            }

            DankActionButton {
                buttonSize: 34
                iconSize: 17
                iconName: "open_in_new"
                iconColor: Theme.primary
                tooltipText: I18n.tr("Open App")
                onClicked: DankConnectService.openApp()
            }
        }

        Item {
            id: trailingPanel

            width: root.pairingRequest ? 270 : 52
            height: parent.height

            DankIcon {
                anchors.centerIn: parent
                visible: !root.pairingRequest && root.hasBattery
                name: root.hasBattery ? Theme.getBatteryIcon(root.device.batteryCharge, root.device.batteryCharging, true) : "battery_std"
                size: 28
                color: Theme.primary
            }

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: Theme.spacingXS
                visible: root.pairingRequest !== null

                StyledText {
                    width: parent.width
                    text: I18n.tr("Pairing request from %1").arg(root.pairingRequest?.name || I18n.tr("Device"))
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledText {
                    width: parent.width
                    text: root.pairingRequest?.verificationKey || I18n.tr("Unknown")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    color: Theme.primary
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingS

                    DankButton {
                        text: I18n.tr("Reject")
                        buttonHeight: 30
                        horizontalPadding: Theme.spacingM
                        onClicked: DankConnectService.rejectPairing(root.pairingRequest.deviceId, response => root.reportError(I18n.tr("Failed to reject pairing"), response))
                    }

                    DankButton {
                        text: I18n.tr("Accept")
                        buttonHeight: 30
                        horizontalPadding: Theme.spacingM
                        backgroundColor: Theme.primary
                        textColor: Theme.primaryText
                        onClicked: DankConnectService.acceptPairing(root.pairingRequest.deviceId, response => root.reportError(I18n.tr("Failed to accept pairing"), response))
                    }
                }
            }
        }
    }
}
