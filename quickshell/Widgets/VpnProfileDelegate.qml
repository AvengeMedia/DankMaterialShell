import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    required property var profile
    property bool isExpanded: false
    readonly property bool isTransient: !!profile?.transient
    readonly property bool canExpand: profile?.canExpand !== false
    readonly property bool canDelete: profile?.canDelete !== false

    signal toggleExpand
    signal deleteRequested

    readonly property bool isActive: DMSNetworkService.vpnStateForUuid(profile?.uuid) === "activated"
    readonly property bool isConnecting: DMSNetworkService.isVpnConnectingUuid(profile?.uuid)
    readonly property bool hasError: !isConnecting && DMSNetworkService.vpnError !== "" && DMSNetworkService.vpnErrorUuid === (profile?.uuid ?? "")
    readonly property bool isHovered: rowArea.containsMouse || expandBtn.containsMouse || deleteBtn.containsMouse
    readonly property var configData: (!isTransient && isExpanded) ? VPNService.editConfig : null
    readonly property var configFields: buildConfigFields()

    height: isExpanded ? 46 + expandedContent.height : 46
    radius: Theme.cornerRadius
    color: isHovered ? Theme.primaryHoverLight : (isActive ? Theme.primaryPressed : Theme.surfaceLight)
    border.width: isActive ? 2 : 1
    border.color: isActive ? Theme.primary : Theme.outlineLight
    opacity: (DMSNetworkService.isBusy && !isConnecting) ? 0.5 : 1.0
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

            DankSpinner {
                size: 18
                strokeWidth: 2
                color: Theme.warning
                running: root.isConnecting
                visible: root.isConnecting
                anchors.verticalCenter: parent.verticalCenter
            }

            DankIcon {
                visible: !root.isConnecting
                name: isActive ? "vpn_lock" : (root.hasError ? "error" : "vpn_key_off")
                size: 20
                color: root.hasError ? Theme.error : (isActive ? Theme.primary : Theme.surfaceText)
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                spacing: 1
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 20 - ((canExpand ? 28 : 0) + (canDelete ? 28 : 0)) - Theme.spacingS * 4

                StyledText {
                    text: profile?.name ?? ""
                    font.pixelSize: Theme.fontSizeMedium
                    color: isActive ? Theme.primary : Theme.surfaceText
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
                }

                StyledText {
                    text: root.isConnecting ? I18n.tr("Connecting...") : (root.hasError ? DMSNetworkService.vpnError : VPNService.getVpnTypeFromProfile(profile))
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.isConnecting ? Theme.warning : (root.hasError ? Theme.error : Theme.surfaceTextMedium)
                    wrapMode: Text.NoWrap
                    width: parent.width
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignLeft
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
                color: expandBtn.containsMouse ? Theme.surfacePressed : Theme.withAlpha(Theme.surfacePressed, 0)
                anchors.verticalCenter: parent.verticalCenter
                visible: canExpand

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
                color: deleteBtn.containsMouse ? Theme.errorHover : Theme.withAlpha(Theme.errorHover, 0)
                anchors.verticalCenter: parent.verticalCenter
                visible: canDelete

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

                DankSpinner {
                    anchors.centerIn: parent
                    size: 20
                }
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingXS
                visible: !isTransient && !VPNService.configLoading && configData

                Repeater {
                    model: configFields

                    delegate: Rectangle {
                        required property var modelData

                        width: fieldContent.width + Theme.spacingM * 2
                        height: 32
                        radius: Theme.cornerRadius - 2
                        color: Theme.surfaceLight
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

            DankToggle {
                width: parent.width
                text: I18n.tr("Autoconnect")
                checked: configData ? (configData.autoconnect || false) : false
                visible: !VPNService.configLoading && configData !== null
                onToggled: checked => {
                    VPNService.updateConfig(profile.uuid, {
                        autoconnect: checked
                    });
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS
                visible: !isTransient && !VPNService.configLoading && profile?.type !== "wireguard"

                StyledText {
                    text: root.hasError ? DMSNetworkService.vpnError : I18n.tr("Credentials")
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.hasError ? Theme.error : Theme.surfaceVariantText
                }

                DankTextField {
                    id: usernameField
                    width: parent.width
                    placeholderText: I18n.tr("Username")
                    text: (configData && (configData.username || (configData.data && configData.data.username))) || ""
                }

                DankTextField {
                    id: passwordField
                    width: parent.width
                    placeholderText: I18n.tr("Password")
                    echoMode: TextInput.Password
                    showPasswordToggle: true
                    normalBorderColor: root.hasError ? Theme.error : Theme.outlineMedium
                }

                DankButton {
                    text: I18n.tr("Save credentials")
                    opacity: passwordField.text.length > 0 ? 1 : 0.5
                    onClicked: {
                        if (passwordField.text.length === 0)
                            return;
                        VPNService.setCredentials(profile.uuid, usernameField.text, passwordField.text, true);
                        passwordField.text = "";
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
