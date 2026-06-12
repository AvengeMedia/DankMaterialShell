pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets
import qs.Services
import qs.Widgets

SettingsCard {
    id: root

    property string expandedEthDevice: ""

    title: I18n.tr("Ethernet")
    iconName: "settings_ethernet"
    settingKey: "networkEthernet"
    tags: ["ethernet", "wired", "network", "adapters", "connection"]

    width: parent.width

    Column {
        id: ethernetSection

        width: parent.width
        spacing: Theme.spacingM

        StyledText {
            text: {
                const devices = NetworkService.ethernetDevices;
                const connected = devices.filter(d => d.connected).length;
                if (devices.length === 0)
                    return I18n.tr("No adapters");
                if (connected === 0)
                    return devices.length === 1 ? I18n.tr("%1 adapter, none connected").arg(devices.length) : I18n.tr("%1 adapters, none connected").arg(devices.length);
                return I18n.tr("%1 connected").arg(connected);
            }
            font.pixelSize: Theme.fontSizeSmall
            color: NetworkService.ethernetConnected ? Theme.primary : Theme.surfaceVariantText
            width: parent.width
            horizontalAlignment: Text.AlignLeft
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        }

        Column {
            width: parent.width
            spacing: 4
            visible: NetworkService.ethernetDevices.length > 0

            StyledText {
                text: I18n.tr("Adapters")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                width: parent.width
                horizontalAlignment: Text.AlignLeft
            }

            Repeater {
                model: NetworkService.ethernetDevices

                delegate: Rectangle {
                    id: ethDeviceDelegate
                    required property var modelData
                    required property int index

                    readonly property bool isConnected: modelData.connected || false
                    readonly property bool isExpanded: root.expandedEthDevice === modelData.name

                    width: parent.width
                    height: isExpanded ? 56 + ethExpandedContent.height : 56
                    radius: Theme.cornerRadius
                    color: ethDeviceMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight
                    border.width: isConnected ? 2 : 0
                    border.color: Theme.primary
                    clip: true

                    Behavior on height {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }

                    Column {
                        anchors.fill: parent
                        spacing: 0

                        Item {
                            width: parent.width
                            height: 56

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: ethDeviceActions.left
                                anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: "lan"
                                    size: 20
                                    color: isConnected ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    width: parent.width - 20 - Theme.spacingS

                                    StyledText {
                                        text: modelData.name || I18n.tr("Unknown")
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: isConnected ? Theme.primary : Theme.surfaceText
                                        font.weight: isConnected ? Font.Medium : Font.Normal
                                        elide: Text.ElideRight
                                        width: parent.width
                                        horizontalAlignment: Text.AlignLeft
                                    }

                                    Row {
                                        anchors.left: parent.left
                                        spacing: Theme.spacingXS

                                        StyledText {
                                            text: {
                                                switch (modelData.state) {
                                                case "activated":
                                                    return I18n.tr("Connected");
                                                case "disconnected":
                                                    return I18n.tr("Disconnected");
                                                case "unavailable":
                                                    return I18n.tr("Unavailable");
                                                default:
                                                    return modelData.state || I18n.tr("Unknown");
                                                }
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: isConnected ? Theme.primary : Theme.surfaceVariantText
                                        }

                                        StyledText {
                                            text: "•"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            visible: (modelData.ip || "").length > 0
                                        }

                                        StyledText {
                                            text: modelData.ip || ""
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            visible: (modelData.ip || "").length > 0
                                        }
                                    }
                                }
                            }

                            Row {
                                id: ethDeviceActions
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingXS

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: ethExpandBtn.containsMouse ? Theme.surfacePressed : "transparent"
                                    visible: isConnected

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: isExpanded ? "expand_less" : "expand_more"
                                        size: 18
                                        color: Theme.surfaceText
                                    }

                                    MouseArea {
                                        id: ethExpandBtn
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (isExpanded) {
                                                root.expandedEthDevice = "";
                                            } else {
                                                root.expandedEthDevice = modelData.name;
                                                NetworkService.fetchWiredNetworkInfo(NetworkService.ethernetConnectionUuid);
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: ethDisconnectBtn.containsMouse ? Theme.errorHover : "transparent"
                                    visible: isConnected

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "link_off"
                                        size: 18
                                        color: ethDisconnectBtn.containsMouse ? Theme.error : Theme.surfaceVariantText
                                    }

                                    MouseArea {
                                        id: ethDisconnectBtn
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: NetworkService.disconnectEthernetDevice(modelData.name)
                                    }
                                }
                            }

                            MouseArea {
                                id: ethDeviceMouseArea
                                anchors.fill: parent
                                anchors.rightMargin: ethDeviceActions.width + Theme.spacingM
                                hoverEnabled: true
                            }
                        }

                        Column {
                            id: ethExpandedContent
                            width: parent.width
                            visible: isExpanded

                            Rectangle {
                                width: parent.width - Theme.spacingM * 2
                                height: 1
                                x: Theme.spacingM
                                color: Theme.outlineLight
                            }

                            Item {
                                width: parent.width
                                height: ethDetailsColumn.implicitHeight + Theme.spacingM * 2

                                Column {
                                    id: ethDetailsColumn
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingS

                                    Flow {
                                        width: parent.width
                                        spacing: Theme.spacingXS

                                        Repeater {
                                            model: {
                                                const fields = [];
                                                const dev = modelData;
                                                if (!dev)
                                                    return fields;

                                                if (dev.ip)
                                                    fields.push({
                                                        label: I18n.tr("IP"),
                                                        value: dev.ip
                                                    });
                                                if (dev.speed && dev.speed > 0)
                                                    fields.push({
                                                        label: I18n.tr("Speed"),
                                                        value: dev.speed + " Mbps"
                                                    });
                                                if (dev.hwAddress)
                                                    fields.push({
                                                        label: I18n.tr("MAC"),
                                                        value: dev.hwAddress
                                                    });
                                                if (dev.driver)
                                                    fields.push({
                                                        label: I18n.tr("Driver"),
                                                        value: dev.driver
                                                    });
                                                fields.push({
                                                    label: I18n.tr("State"),
                                                    value: dev.state || I18n.tr("Unknown")
                                                });

                                                return fields;
                                            }

                                            delegate: Rectangle {
                                                required property var modelData
                                                required property int index

                                                width: ethFieldContent.width + Theme.spacingM * 2
                                                height: 32
                                                radius: Theme.cornerRadius - 2
                                                color: Theme.surfaceContainerHigh
                                                border.width: 1
                                                border.color: Theme.outlineLight

                                                Row {
                                                    id: ethFieldContent
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
                                        width: parent.width
                                        height: NetworkService.networkWiredInfoLoading ? 40 : 0
                                        visible: NetworkService.networkWiredInfoLoading

                                        DankSpinner {
                                            anchors.centerIn: parent
                                            size: 20
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: NetworkService.wiredConnections.length > 0

            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
            }

            StyledText {
                text: I18n.tr("Saved Configurations")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                width: parent.width
                horizontalAlignment: Text.AlignLeft
            }

            Repeater {
                model: NetworkService.wiredConnections

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: parent.width
                    height: 48
                    radius: Theme.cornerRadius
                    color: wiredMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight
                    border.width: modelData.isActive ? 2 : 0
                    border.color: Theme.primary

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "lan"
                            size: 20
                            color: modelData.isActive ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            StyledText {
                                text: modelData.id || I18n.tr("Unknown")
                                font.pixelSize: Theme.fontSizeMedium
                                color: modelData.isActive ? Theme.primary : Theme.surfaceText
                                font.weight: modelData.isActive ? Font.Medium : Font.Normal
                            }

                            StyledText {
                                text: modelData.isActive ? I18n.tr("Active") : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.primary
                                visible: modelData.isActive
                            }
                        }
                    }

                    MouseArea {
                        id: wiredMouseArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!modelData.isActive) {
                                NetworkService.connectToSpecificWiredConfig(modelData.uuid);
                            }
                        }
                    }
                }
            }
        }
    }
}
