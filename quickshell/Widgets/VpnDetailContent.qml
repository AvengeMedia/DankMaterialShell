import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Modals.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property var parentPopout: null
    property string expandedUuid: ""
    property int listHeight: 180

    implicitHeight: contentColumn.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

    FileBrowserSurfaceModal {
        id: fileBrowser
        browserTitle: I18n.tr("Import VPN")
        browserIcon: "vpn_key"
        browserType: "vpn"
        fileExtensions: VPNService.getFileFilter()
        parentPopout: root.parentPopout

        onFileSelected: path => {
            VPNService.importVpn(path.replace("file://", ""));
        }
    }

    ConfirmModal {
        id: deleteConfirm
    }

    Column {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        RowLayout {
            spacing: Theme.spacingS
            width: parent.width

            StyledText {
                text: {
                    if (!DMSNetworkService.connected)
                        return I18n.tr("Active: None");
                    const names = DMSNetworkService.activeNames || [];
                    if (names.length <= 1)
                        return I18n.tr("Active: ") + (names[0] || "VPN");
                    return I18n.tr("Active: ") + names[0] + " +" + (names.length - 1);
                }
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                Layout.fillWidth: true
            }

            Rectangle {
                height: 28
                radius: 14
                color: importArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight
                width: 90
                Layout.alignment: Qt.AlignVCenter
                opacity: VPNService.importing ? 0.5 : 1.0

                Row {
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
                    id: importArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: VPNService.importing ? Qt.BusyCursor : Qt.PointingHandCursor
                    enabled: !VPNService.importing
                    onClicked: fileBrowser.open()
                }
            }

            Rectangle {
                height: 28
                radius: 14
                color: discAllArea.containsMouse ? Theme.errorHover : Theme.surfaceLight
                visible: DMSNetworkService.connected
                width: 100
                Layout.alignment: Qt.AlignVCenter
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

            DankActionButton {
                Layout.alignment: Qt.AlignVCenter
                iconName: "settings"
                buttonSize: 28
                iconSize: 16
                iconColor: Theme.surfaceVariantText
                onClicked: {
                    PopoutService.closeControlCenter();
                    PopoutService.openSettingsWithTab("network");
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
            height: root.listHeight
            contentHeight: listCol.height
            clip: true

            Column {
                id: listCol
                width: parent.width
                spacing: 4

                Item {
                    width: parent.width
                    height: DMSNetworkService.profiles.length === 0 ? 100 : 0
                    visible: height > 0

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

                Repeater {
                    model: DMSNetworkService.profiles

                    delegate: Rectangle {
                        id: profileRow
                        required property var modelData
                        required property int index

                        readonly property bool isActive: DMSNetworkService.isActiveUuid(modelData.uuid)
                        readonly property bool isExpanded: root.expandedUuid === modelData.uuid
                        readonly property bool isHovered: rowArea.containsMouse || expandBtn.containsMouse || deleteBtn.containsMouse
                        readonly property var configData: isExpanded ? VPNService.editConfig : null

                        width: listCol.width
                        height: isExpanded ? 46 + expandedContent.height : 46
                        radius: Theme.cornerRadius
                        color: isHovered ? Theme.primaryHoverLight : (isActive ? Theme.primaryPressed : Theme.surfaceLight)
                        border.width: isActive ? 2 : 1
                        border.color: isActive ? Theme.primary : Theme.outlineLight
                        opacity: DMSNetworkService.isBusy ? 0.5 : 1.0
                        clip: true

                        Behavior on height {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
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

                        Column {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            spacing: Theme.spacingS

                            Row {
                                width: parent.width
                                height: 46 - Theme.spacingS * 2
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: isActive ? "vpn_lock" : "vpn_key_off"
                                    size: 20
                                    color: isActive ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    spacing: 1
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 20 - 28 - 28 - Theme.spacingS * 4

                                    StyledText {
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: isActive ? Theme.primary : Theme.surfaceText
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                        width: parent.width
                                    }

                                    StyledText {
                                        text: VPNService.getVpnTypeFromProfile(modelData)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceTextMedium
                                        wrapMode: Text.NoWrap
                                        width: parent.width
                                        elide: Text.ElideRight
                                    }
                                }

                                Item {
                                    width: Theme.spacingXS
                                    height: 1
                                }

                                Rectangle {
                                    id: expandBtnRect
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: expandBtn.containsMouse ? Theme.surfacePressed : "transparent"
                                    anchors.verticalCenter: parent.verticalCenter

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: isExpanded ? "expand_less" : "expand_more"
                                        size: 18
                                        color: Theme.surfaceText
                                    }

                                    MouseArea {
                                        id: expandBtn
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (isExpanded) {
                                                root.expandedUuid = "";
                                            } else {
                                                root.expandedUuid = modelData.uuid;
                                                VPNService.getConfig(modelData.uuid);
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: deleteBtnRect
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: deleteBtn.containsMouse ? Theme.errorHover : "transparent"
                                    anchors.verticalCenter: parent.verticalCenter

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "delete"
                                        size: 18
                                        color: deleteBtn.containsMouse ? Theme.error : Theme.surfaceVariantText
                                    }

                                    MouseArea {
                                        id: deleteBtn
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            deleteConfirm.showWithOptions({
                                                title: I18n.tr("Delete VPN"),
                                                message: I18n.tr("Delete \"") + modelData.name + "\"?",
                                                confirmText: I18n.tr("Delete"),
                                                confirmColor: Theme.error,
                                                onConfirm: () => VPNService.deleteVpn(modelData.uuid)
                                            });
                                        }
                                    }
                                }
                            }

                            Column {
                                id: expandedContent
                                width: parent.width
                                spacing: Theme.spacingXS
                                visible: isExpanded

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: Theme.outlineLight
                                }

                                Item {
                                    width: parent.width
                                    height: VPNService.configLoading ? 40 : 0
                                    visible: VPNService.configLoading

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingS

                                        DankIcon {
                                            name: "sync"
                                            size: 16
                                            color: Theme.surfaceVariantText
                                        }

                                        StyledText {
                                            text: I18n.tr("Loading...")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
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
                                            fields.push({
                                                label: I18n.tr("Autoconnect"),
                                                value: configData.autoconnect ? I18n.tr("Yes") : I18n.tr("No")
                                            });

                                            return fields;
                                        }

                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index

                                            width: fieldContent.width + Theme.spacingM * 2
                                            height: 32
                                            radius: Theme.cornerRadius - 2
                                            color: Theme.surfaceContainerHigh
                                            border.width: 1
                                            border.color: Theme.outlineLight

                                            Row {
                                                id: fieldContent
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

        Item {
            width: 1
            height: Theme.spacingS
        }
    }
}
