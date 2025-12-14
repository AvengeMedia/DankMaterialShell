import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    required property var profile
    property bool isExpanded: false

    signal toggleExpand
    signal deleteRequested

    readonly property bool isActive: DMSNetworkService.activeUuids?.includes(profile?.uuid) ?? false
    readonly property bool isHovered: rowArea.containsMouse || expandBtn.containsMouse || deleteBtn.containsMouse
    readonly property var configData: isExpanded ? VPNService.editConfig : null
    readonly property var configFields: buildConfigFields()

    height: isExpanded ? 46 + expandedContent.height : 46
    radius: Theme.cornerRadius
    color: isHovered ? Theme.primaryHoverLight : (isActive ? Theme.primaryPressed : Theme.surfaceLight)
    border.width: isActive ? 2 : 1
    border.color: isActive ? Theme.primary : Theme.outlineLight
    opacity: DMSNetworkService.isBusy ? 0.5 : 1.0
    clip: true

    function buildConfigFields() {
        if (!configData)
            return [];
        const fields = [];
        const data = configData.data || {};
        if (data.remote)
            fields.push({
                "key": "server",
                "label": I18n.tr("Server"),
                "value": data.remote
            });
        if (configData.username || data.username)
            fields.push({
                "key": "user",
                "label": I18n.tr("Username"),
                "value": configData.username || data.username
            });
        if (data.cipher)
            fields.push({
                "key": "cipher",
                "label": I18n.tr("Cipher"),
                "value": data.cipher
            });
        if (data.auth)
            fields.push({
                "key": "auth",
                "label": I18n.tr("Auth"),
                "value": data.auth
            });
        if (data["proto-tcp"] === "yes" || data["proto-tcp"] === "no")
            fields.push({
                "key": "proto",
                "label": I18n.tr("Protocol"),
                "value": data["proto-tcp"] === "yes" ? "TCP" : "UDP"
            });
        if (data["tunnel-mtu"])
            fields.push({
                "key": "mtu",
                "label": I18n.tr("MTU"),
                "value": data["tunnel-mtu"]
            });
        if (data["connection-type"])
            fields.push({
                "key": "conntype",
                "label": I18n.tr("Auth Type"),
                "value": data["connection-type"]
            });
        fields.push({
            "key": "auto",
            "label": I18n.tr("Autoconnect"),
            "value": configData.autoconnect ? I18n.tr("Yes") : I18n.tr("No")
        });
        return fields;
    }

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
        onClicked: DMSNetworkService.toggle(profile.uuid)
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
                    text: profile?.name ?? ""
                    font.pixelSize: Theme.fontSizeMedium
                    color: isActive ? Theme.primary : Theme.surfaceText
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    width: parent.width
                }

                StyledText {
                    text: VPNService.getVpnTypeFromProfile(profile)
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
                    onClicked: root.toggleExpand()
                }
            }

            Rectangle {
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
                    onClicked: root.deleteRequested()
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
                    model: configFields

                    delegate: Rectangle {
                        required property var modelData

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
