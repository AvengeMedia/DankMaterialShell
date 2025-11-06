import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    Ref {
        service: DMSNetworkService
    }


    ccWidgetIcon: DMSNetworkService.isBusy ? "sync" : (DMSNetworkService.connected ? "vpn_lock" : "vpn_key_off")
    ccWidgetPrimaryText: "VPN"
    ccWidgetSecondaryText: {
        if (!DMSNetworkService.connected)
            return "Disconnected"
        const names = DMSNetworkService.activeNames || []
        if (names.length <= 1)
            return names[0] || "Connected"
        return names[0] + " +" + (names.length - 1)
    }
    ccWidgetIsActive: DMSNetworkService.connected

    onCcWidgetToggled: {
        DMSNetworkService.toggleVpn()
    }

    ccDetailContent: Component {
        Rectangle {
            id: detailRoot
            implicitHeight: detailColumn.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

            Column {
                id: detailColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                RowLayout {
                    spacing: Theme.spacingS
                    width: parent.width

                    StyledText {
                        text: {
                            if (!DMSNetworkService.connected)
                                return "Active: None"
                            const names = DMSNetworkService.activeNames || []
                            if (names.length <= 1)
                                return "Active: " + (names[0] || "VPN")
                            return "Active: " + names[0] + " +" + (names.length - 1)
                        }
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                        Layout.fillWidth: true
                        Layout.maximumWidth: parent.width - 120
                    }

                    Rectangle {
                        height: 28
                        radius: 14
                        color: discAllArea.containsMouse ? Theme.errorHover : Theme.surfaceLight
                        visible: DMSNetworkService.connected
                        width: 110
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                        opacity: DMSNetworkService.isBusy ? 0.5 : 1.0

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS

                            DankIcon {
                                name: "link_off"
                                size: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Disconnect")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }
                        }

                        MouseArea {
                            id: discAllArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: DMSNetworkService.isBusy ? Qt.BusyCursor : Qt.PointingHandCursor
                            enabled: !DMSNetworkService.isBusy
                            onClicked: DMSNetworkService.disconnectAllActive()
                        }
                    }
                }

                Rectangle {
                    height: 1
                    width: parent.width
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                }

                DankFlickable {
                    width: parent.width
                    height: 160
                    contentHeight: listCol.height
                    clip: true

                    Column {
                        id: listCol
                        width: parent.width
                        spacing: Theme.spacingXS

                        Item {
                            width: parent.width
                            height: DMSNetworkService.profiles.length === 0 ? 120 : 0
                            visible: height > 0

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: "playlist_remove"
                                    size: 36
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: I18n.tr("No VPN profiles found")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: I18n.tr("Add a VPN in NetworkManager")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        Repeater {
                            model: DMSNetworkService.profiles

                            delegate: Rectangle {
                                required property var modelData

                                width: parent ? parent.width : 300
                                height: 50
                                radius: Theme.cornerRadius
                                color: rowArea.containsMouse ? Theme.primaryHoverLight : (DMSNetworkService.isActiveUuid(modelData.uuid) ? Theme.primaryPressed : Theme.surfaceLight)
                                border.width: DMSNetworkService.isActiveUuid(modelData.uuid) ? 2 : 1
                                border.color: DMSNetworkService.isActiveUuid(modelData.uuid) ? Theme.primary : Theme.outlineLight
                                opacity: DMSNetworkService.isBusy ? 0.5 : 1.0

                                RowLayout {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: DMSNetworkService.isActiveUuid(modelData.uuid) ? "vpn_lock" : "vpn_key_off"
                                        size: Theme.iconSize - 4
                                        color: DMSNetworkService.isActiveUuid(modelData.uuid) ? Theme.primary : Theme.surfaceText
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Column {
                                        spacing: 2
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.fillWidth: true

                                        StyledText {
                                            text: modelData.name
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: DMSNetworkService.isActiveUuid(modelData.uuid) ? Theme.primary : Theme.surfaceText
                                            elide: Text.ElideRight
                                            wrapMode: Text.NoWrap
                                            width: parent.width
                                        }

                                        StyledText {
                                            text: {
                                                if (modelData.type === "wireguard")
                                                    return "WireGuard"
                                                const svc = modelData.serviceType || ""
                                                if (svc.indexOf("openvpn") !== -1)
                                                    return "OpenVPN"
                                                if (svc.indexOf("wireguard") !== -1)
                                                    return "WireGuard (plugin)"
                                                if (svc.indexOf("openconnect") !== -1)
                                                    return "OpenConnect"
                                                if (svc.indexOf("fortissl") !== -1 || svc.indexOf("forti") !== -1)
                                                    return "Fortinet"
                                                if (svc.indexOf("strongswan") !== -1)
                                                    return "IPsec (strongSwan)"
                                                if (svc.indexOf("libreswan") !== -1)
                                                    return "IPsec (Libreswan)"
                                                if (svc.indexOf("l2tp") !== -1)
                                                    return "L2TP/IPsec"
                                                if (svc.indexOf("pptp") !== -1)
                                                    return "PPTP"
                                                if (svc.indexOf("vpnc") !== -1)
                                                    return "Cisco (vpnc)"
                                                if (svc.indexOf("sstp") !== -1)
                                                    return "SSTP"
                                                if (svc)
                                                    return svc.split('.').pop()
                                                return "VPN"
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceTextMedium
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }
                                }

                                MouseArea {
                                    id: rowArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: DMSNetworkService.isBusy ? Qt.BusyCursor : Qt.PointingHandCursor
                                    enabled: !DMSNetworkService.isBusy
                                    onClicked: DMSNetworkService.toggle(modelData.uuid)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
