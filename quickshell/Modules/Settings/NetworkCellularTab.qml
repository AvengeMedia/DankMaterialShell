pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets
import qs.Services
import qs.Widgets

Item {
    id: networkCellularTab

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    Component.onCompleted: NetworkService.addRef()
    Component.onDestruction: NetworkService.removeRef()

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn

            topPadding: 4
            width: Math.min(600, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingL

            SettingsCard {
                id: root

                title: I18n.tr("Cellular")
                iconName: "network_cell"
                settingKey: "networkCellular"
                tags: ["cellular", "mobile", "modem", "wwan", "lte", "gsm", "cdma", "network"]
                width: parent.width

                Column {
                    width: parent.width
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            text: {
                                if (!NetworkService.cellularHardwareEnabled)
                                    return I18n.tr("Unavailable");
                                if (NetworkService.cellularToggling)
                                    return NetworkService.cellularEnabled ? I18n.tr("Disabling cellular...") : I18n.tr("Enabling cellular...");
                                if (!NetworkService.cellularEnabled)
                                    return I18n.tr("Disabled");
                                const devices = NetworkService.cellularDevices || [];
                                const connected = devices.filter(d => d.connected).length;
                                if (devices.length === 0)
                                    return I18n.tr("No devices found");
                                if (connected === 0)
                                    return I18n.tr("Disconnected");
                                return I18n.tr("%1 connected").arg(connected);
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: NetworkService.cellularConnected ? Theme.primary : Theme.surfaceVariantText
                            width: parent.width - cellularControls.width - Theme.spacingM
                            horizontalAlignment: Text.AlignLeft
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Row {
                            id: cellularControls
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankToggle {
                                checked: NetworkService.cellularEnabled
                                enabled: NetworkService.cellularHardwareEnabled && !NetworkService.cellularToggling
                                onToggled: NetworkService.toggleCellularRadio()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outlineStrong
                    }

                    Column {
                        width: parent.width
                        spacing: 4
                        visible: NetworkService.cellularEnabled && (NetworkService.cellularDevices?.length ?? 0) > 0

                        StyledText {
                            text: I18n.tr("Adapters")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        Repeater {
                            model: NetworkService.cellularDevices || []

                            delegate: Rectangle {
                                id: modemDelegate
                                required property var modelData

                                readonly property bool isConnected: modelData.connected || false

                                width: parent.width
                                height: 56
                                radius: Theme.cornerRadius
                                color: modemMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight
                                border.width: isConnected ? 2 : 0
                                border.color: Theme.primary

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.right: modemActions.left
                                    anchors.rightMargin: Theme.spacingS
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: "network_cell"
                                        size: 20
                                        color: modemDelegate.isConnected ? Theme.primary : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        width: parent.width - 20 - Theme.spacingS

                                        StyledText {
                                            text: modelData.name || I18n.tr("Unknown")
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: modemDelegate.isConnected ? Theme.primary : Theme.surfaceText
                                            font.weight: modemDelegate.isConnected ? Font.Medium : Font.Normal
                                            elide: Text.ElideRight
                                            width: parent.width
                                            horizontalAlignment: Text.AlignLeft
                                        }

                                        StyledText {
                                            text: {
                                                const state = modelData.state || I18n.tr("Unknown");
                                                const ip = modelData.ip || "";
                                                return ip.length > 0 ? state + " • " + ip : state;
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                            width: parent.width
                                            horizontalAlignment: Text.AlignLeft
                                        }
                                    }
                                }

                                Row {
                                    id: modemActions
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.spacingS
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingXS

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: modemActionBtn.containsMouse ? (modemDelegate.isConnected ? Theme.errorHover : Theme.primaryHover) : "transparent"

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: modemDelegate.isConnected ? "link_off" : "link"
                                            size: 18
                                            color: modemActionBtn.containsMouse ? (modemDelegate.isConnected ? Theme.error : Theme.primary) : Theme.surfaceVariantText
                                        }

                                        MouseArea {
                                            id: modemActionBtn
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (modemDelegate.isConnected)
                                                    NetworkService.disconnectCellularDevice(modelData.name);
                                                else
                                                    NetworkService.connectCellular();
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: modemMouseArea
                                    anchors.fill: parent
                                    anchors.rightMargin: modemActions.width + Theme.spacingM
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modemDelegate.isConnected)
                                            NetworkService.disconnectCellularDevice(modelData.name);
                                        else
                                            NetworkService.connectCellular();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            SettingsCard {
                title: I18n.tr("Saved Configurations")
                iconName: "sim_card"
                settingKey: "networkCellularProfiles"
                tags: ["cellular", "mobile", "profile", "apn", "sim"]
                width: parent.width
                visible: NetworkService.cellularEnabled && (NetworkService.cellularConnections?.length ?? 0) > 0

                Column {
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: NetworkService.cellularConnections || []

                        delegate: Rectangle {
                            id: profileDelegate
                            required property var modelData

                            readonly property bool isActive: modelData.isActive || false

                            width: parent.width
                            height: 56
                            radius: Theme.cornerRadius
                            color: profileMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight
                            border.color: isActive ? Theme.primary : Theme.outlineLight
                            border.width: isActive ? 2 : 1

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.right: profileAction.left
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: "sim_card"
                                    size: 20
                                    color: profileDelegate.isActive ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 20 - Theme.spacingS
                                    spacing: 2

                                    StyledText {
                                        text: modelData.id || I18n.tr("Unknown")
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: profileDelegate.isActive ? Theme.primary : Theme.surfaceText
                                        font.weight: profileDelegate.isActive ? Font.Medium : Font.Normal
                                        elide: Text.ElideRight
                                        width: parent.width
                                        horizontalAlignment: Text.AlignLeft
                                    }

                                    StyledText {
                                        text: profileDelegate.isActive ? I18n.tr("Connected") : (modelData.type || I18n.tr("Available"))
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        width: parent.width
                                        horizontalAlignment: Text.AlignLeft
                                    }
                                }
                            }

                            DankActionButton {
                                id: profileAction
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                iconName: profileDelegate.isActive ? "link_off" : "link"
                                buttonSize: 28
                                iconSize: 18
                                iconColor: profileDelegate.isActive ? Theme.error : Theme.primary
                                onClicked: {
                                    if (profileDelegate.isActive)
                                        NetworkService.toggleNetworkConnection("cellular");
                                    else
                                        NetworkService.connectToSpecificCellularConfig(modelData.uuid);
                                }
                            }

                            MouseArea {
                                id: profileMouseArea
                                anchors.fill: parent
                                anchors.rightMargin: profileAction.width + Theme.spacingS
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!profileDelegate.isActive)
                                        NetworkService.connectToSpecificCellularConfig(modelData.uuid);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
