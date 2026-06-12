pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Settings.Widgets
import qs.Modals.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

SettingsCard {
    id: root

    property string expandedVpnUuid: ""

    title: I18n.tr("VPN")
    iconName: DMSNetworkService.connected ? "vpn_lock" : "vpn_key_off"
    settingKey: "networkVpn"
    tags: ["vpn", "network", "profiles", "import", "openvpn", "wireguard"]

    function openVpnFileBrowser() {
        vpnFileBrowserLoader.active = true;
        if (vpnFileBrowserLoader.item)
            vpnFileBrowserLoader.item.open();
    }

    property var vpnFileBrowserLoader: LazyLoader {
        active: false

        FileBrowserModal {
            browserTitle: I18n.tr("Import VPN")
            browserIcon: "vpn_key"
            browserType: "vpn"
            fileExtensions: VPNService.getFileFilter()

            onFileSelected: path => {
                VPNService.importVpn(path.replace("file://", ""));
            }
        }
    }

    property var deleteVpnConfirm: ConfirmModal {}

    width: parent.width

    Column {
        id: vpnSection

        width: parent.width
        spacing: Theme.spacingM

        StyledText {
            text: I18n.tr("Unavailable")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: parent.width
            horizontalAlignment: Text.AlignLeft
            visible: !DMSNetworkService.vpnAvailable
        }

        Row {
            width: parent.width
            spacing: Theme.spacingM
            visible: DMSNetworkService.vpnAvailable

            StyledText {
                text: {
                    if (!DMSNetworkService.connected)
                        return I18n.tr("Disconnected");
                    const names = DMSNetworkService.activeNames || [];
                    if (names.length <= 1)
                        return names[0] || I18n.tr("Connected");
                    return names[0] + " +" + (names.length - 1);
                }
                font.pixelSize: Theme.fontSizeSmall
                color: DMSNetworkService.connected ? Theme.primary : Theme.surfaceVariantText
                width: parent.width - vpnHeaderControls.width - Theme.spacingM
                horizontalAlignment: Text.AlignLeft
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                id: vpnHeaderControls
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                Rectangle {
                    height: 28
                    radius: 14
                    width: importVpnRow.width + Theme.spacingM * 2
                    color: importVpnArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight
                    opacity: VPNService.importing ? 0.5 : 1.0

                    Row {
                        id: importVpnRow
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: VPNService.importing ? "sync" : "add"
                            size: Theme.fontSizeSmall
                            color: Theme.primary
                        }

                        StyledText {
                            text: I18n.tr("Import")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: importVpnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: VPNService.importing ? Qt.BusyCursor : Qt.PointingHandCursor
                        enabled: !VPNService.importing
                        onClicked: root.openVpnFileBrowser()
                    }
                }

                Rectangle {
                    height: 28
                    radius: 14
                    width: disconnectAllRow.width + Theme.spacingM * 2
                    color: disconnectAllArea.containsMouse ? Theme.errorHover : Theme.surfaceLight
                    visible: DMSNetworkService.connected
                    opacity: DMSNetworkService.isBusy ? 0.5 : 1.0

                    Row {
                        id: disconnectAllRow
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
                        id: disconnectAllArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: DMSNetworkService.isBusy ? Qt.BusyCursor : Qt.PointingHandCursor
                        enabled: !DMSNetworkService.isBusy
                        onClicked: DMSNetworkService.disconnectAllActive()
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
            visible: DMSNetworkService.vpnAvailable
        }

        Item {
            width: parent.width
            height: 100
            visible: DMSNetworkService.vpnAvailable && DMSNetworkService.profiles.length === 0

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DankIcon {
                    name: "vpn_key_off"
                    size: 36
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: I18n.tr("No VPN profiles")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: I18n.tr("Click Import to add a .ovpn or .conf")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        Column {
            width: parent.width
            spacing: 4
            visible: DMSNetworkService.vpnAvailable && DMSNetworkService.profiles.length > 0

            Repeater {
                model: DMSNetworkService.profiles

                delegate: Rectangle {
                    id: vpnProfileRow
                    required property var modelData
                    required property int index

                    readonly property bool isActive: DMSNetworkService.isActiveUuid(modelData.uuid)
                    readonly property bool isTransient: !!modelData.transient
                    readonly property bool canExpand: modelData.canExpand !== false
                    readonly property bool canDelete: modelData.canDelete !== false
                    readonly property bool isExpanded: root.expandedVpnUuid === modelData.uuid
                    readonly property var configData: (!isTransient && isExpanded) ? VPNService.editConfig : null

                    width: parent.width
                    height: isExpanded ? 56 + vpnExpandedContent.height : 56
                    radius: Theme.cornerRadius
                    color: vpnRowArea.containsMouse ? Theme.primaryHoverLight : (isActive ? Theme.primaryPressed : Theme.surfaceLight)
                    border.width: isActive ? 2 : 0
                    border.color: Theme.primary
                    opacity: DMSNetworkService.isBusy ? 0.6 : 1.0
                    clip: true

                    Behavior on height {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }

                    MouseArea {
                        id: vpnRowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: DMSNetworkService.isBusy ? Qt.BusyCursor : Qt.PointingHandCursor
                        enabled: !DMSNetworkService.isBusy
                        onClicked: DMSNetworkService.toggle(modelData.uuid)
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingS

                        Row {
                            width: parent.width
                            height: 56 - Theme.spacingS * 2
                            spacing: Theme.spacingS

                            DankIcon {
                                name: isActive ? "vpn_lock" : "vpn_key_off"
                                size: 20
                                color: isActive ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 20 - ((canExpand ? 28 : 0) + (canDelete ? 28 : 0)) - Theme.spacingS * 4

                                StyledText {
                                    text: modelData.name
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: isActive ? Theme.primary : Theme.surfaceText
                                    elide: Text.ElideRight
                                    width: parent.width
                                    horizontalAlignment: Text.AlignLeft
                                }

                                StyledText {
                                    text: VPNService.getVpnTypeFromProfile(modelData)
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.left: parent.left
                                }
                            }

                            Item {
                                width: Theme.spacingXS
                                height: 1
                            }

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 14
                                color: vpnExpandBtn.containsMouse ? Theme.surfacePressed : "transparent"
                                anchors.verticalCenter: parent.verticalCenter
                                visible: canExpand

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: isExpanded ? "expand_less" : "expand_more"
                                    size: 18
                                    color: Theme.surfaceText
                                }

                                MouseArea {
                                    id: vpnExpandBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (isExpanded) {
                                            root.expandedVpnUuid = "";
                                        } else {
                                            root.expandedVpnUuid = modelData.uuid;
                                            VPNService.getConfig(modelData.uuid);
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 14
                                color: vpnDeleteBtn.containsMouse ? Theme.errorHover : "transparent"
                                anchors.verticalCenter: parent.verticalCenter
                                visible: canDelete

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "delete"
                                    size: 18
                                    color: vpnDeleteBtn.containsMouse ? Theme.error : Theme.surfaceVariantText
                                }

                                MouseArea {
                                    id: vpnDeleteBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        deleteVpnConfirm.showWithOptions({
                                            title: I18n.tr("Delete VPN"),
                                            message: I18n.tr("Delete \"%1\"?").arg(modelData.name),
                                            confirmText: I18n.tr("Delete"),
                                            confirmColor: Theme.error,
                                            onConfirm: () => VPNService.deleteVpn(modelData.uuid)
                                        });
                                    }
                                }
                            }
                        }

                        Column {
                            id: vpnExpandedContent
                            width: parent.width
                            spacing: Theme.spacingXS
                            visible: !isTransient && isExpanded

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Theme.outlineLight
                            }

                            Item {
                                width: parent.width
                                height: VPNService.configLoading ? 40 : 0
                                visible: VPNService.configLoading

                                DankSpinner {
                                    anchors.centerIn: parent
                                    size: 20
                                }
                            }

                            Flow {
                                width: parent.width
                                spacing: Theme.spacingXS
                                visible: !VPNService.configLoading && configData

                                Repeater {
                                    model: {
                                        if (!configData)
                                            return [];
                                        const fields = [];
                                        const data = configData.data || {};

                                        if (data.remote)
                                            fields.push({
                                                label: I18n.tr("Server"),
                                                value: data.remote
                                            });
                                        if (configData.username || data.username)
                                            fields.push({
                                                label: I18n.tr("Username"),
                                                value: configData.username || data.username
                                            });
                                        if (data.cipher)
                                            fields.push({
                                                label: I18n.tr("Cipher"),
                                                value: data.cipher
                                            });
                                        if (data.auth)
                                            fields.push({
                                                label: I18n.tr("Auth"),
                                                value: data.auth
                                            });
                                        if (data["proto-tcp"] === "yes" || data["proto-tcp"] === "no")
                                            fields.push({
                                                label: I18n.tr("Protocol"),
                                                value: data["proto-tcp"] === "yes" ? "TCP" : "UDP"
                                            });
                                        if (data["tunnel-mtu"])
                                            fields.push({
                                                label: I18n.tr("MTU"),
                                                value: data["tunnel-mtu"]
                                            });
                                        if (data["connection-type"])
                                            fields.push({
                                                label: I18n.tr("Auth Type"),
                                                value: data["connection-type"]
                                            });
                                        return fields;
                                    }

                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index

                                        width: vpnFieldContent.width + Theme.spacingM * 2
                                        height: 32
                                        radius: Theme.cornerRadius - 2
                                        color: Theme.surfaceContainerHigh
                                        border.width: 1
                                        border.color: Theme.outlineLight

                                        Row {
                                            id: vpnFieldContent
                                            anchors.centerIn: parent
                                            spacing: Theme.spacingXS

                                            StyledText {
                                                text: modelData.label + ":"
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            StyledText {
                                                text: modelData.value
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceText
                                                font.weight: Font.Medium
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                    }
                                }
                            }

                            DankToggle {
                                width: parent.width
                                text: I18n.tr("Autoconnect")
                                checked: configData ? (configData.autoconnect || false) : false
                                visible: !VPNService.configLoading && configData !== null
                                onToggled: checked => {
                                    VPNService.updateConfig(modelData.uuid, {
                                        autoconnect: checked
                                    });
                                }
                            }

                            Item {
                                width: 1
                                height: Theme.spacingXS
                            }
                        }
                    }
                }
            }
        }
    }
}
