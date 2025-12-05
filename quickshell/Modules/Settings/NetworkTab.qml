pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Modals.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

Item {
    id: networkTab

    property string expandedVpnUuid: ""
    property string expandedWifiSsid: ""
    property string expandedEthDevice: ""

    Component.onCompleted: {
        NetworkService.addRef();
    }

    Component.onDestruction: {
        NetworkService.removeRef();
    }

    FileBrowserSurfaceModal {
        id: vpnFileBrowser
        browserTitle: I18n.tr("Import VPN")
        browserIcon: "vpn_key"
        browserType: "vpn"
        fileExtensions: VPNService.getFileFilter()

        onFileSelected: path => {
            VPNService.importVpn(path.replace("file://", ""));
        }
    }

    ConfirmModal {
        id: deleteVpnConfirm
    }

    ConfirmModal {
        id: forgetNetworkConfirm
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn

            width: Math.min(600, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingL

            StyledRect {
                width: parent.width
                height: overviewSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                Column {
                    id: overviewSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "lan"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Network Status")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Overview of your network connections")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    }

                    Grid {
                        columns: 2
                        columnSpacing: Theme.spacingL
                        rowSpacing: Theme.spacingS
                        width: parent.width

                        StyledText {
                            text: I18n.tr("Backend")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                        }
                        StyledText {
                            text: NetworkService.backend || I18n.tr("Unknown")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: I18n.tr("Status")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                        }
                        Row {
                            spacing: Theme.spacingS

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: {
                                    switch (NetworkService.networkStatus) {
                                    case "ethernet":
                                    case "wifi":
                                        return Theme.success;
                                    case "disconnected":
                                        return Theme.error;
                                    default:
                                        return Theme.warning;
                                    }
                                }
                            }

                            StyledText {
                                text: {
                                    switch (NetworkService.networkStatus) {
                                    case "ethernet":
                                        return I18n.tr("Ethernet");
                                    case "wifi":
                                        return I18n.tr("WiFi");
                                    case "disconnected":
                                        return I18n.tr("Disconnected");
                                    default:
                                        return NetworkService.networkStatus || I18n.tr("Unknown");
                                    }
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }
                        }

                        StyledText {
                            text: I18n.tr("Primary")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            visible: NetworkService.primaryConnection.length > 0
                        }
                        StyledText {
                            text: NetworkService.primaryConnection || "-"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                            visible: NetworkService.primaryConnection.length > 0
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: NetworkService.backend === "networkmanager" && NetworkService.ethernetConnected && NetworkService.wifiConnected

                        StyledText {
                            text: I18n.tr("Preference")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            width: parent.width - preferenceLabel.width - preferenceButtons.width - Theme.spacingM * 2
                            height: 1
                        }

                        DankButtonGroup {
                            id: preferenceButtons
                            model: [I18n.tr("Auto"), I18n.tr("Ethernet"), I18n.tr("WiFi")]
                            currentIndex: {
                                switch (NetworkService.userPreference) {
                                case "ethernet":
                                    return 1;
                                case "wifi":
                                    return 2;
                                default:
                                    return 0;
                                }
                            }
                            onSelectionChanged: (index, selected) => {
                                if (!selected)
                                    return;
                                switch (index) {
                                case 0:
                                    NetworkService.setNetworkPreference("auto");
                                    break;
                                case 1:
                                    NetworkService.setNetworkPreference("ethernet");
                                    break;
                                case 2:
                                    NetworkService.setNetworkPreference("wifi");
                                    break;
                                }
                            }
                        }
                    }

                    StyledText {
                        id: preferenceLabel
                        visible: false
                        text: I18n.tr("Preference")
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: ethernetSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                visible: NetworkService.ethernetConnected || (NetworkService.ethernetDevices?.length ?? 0) > 0

                Column {
                    id: ethernetSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "settings_ethernet"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Ethernet")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: {
                                    const devices = NetworkService.ethernetDevices;
                                    const connected = devices.filter(d => d.connected).length;
                                    if (devices.length === 0)
                                        return I18n.tr("No adapters");
                                    if (connected === 0)
                                        return I18n.tr("%1 adapter(s), none connected").arg(devices.length);
                                    return I18n.tr("%1 connected").arg(connected);
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: NetworkService.ethernetConnected ? Theme.primary : Theme.surfaceVariantText
                            }
                        }
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
                        }

                        Repeater {
                            model: NetworkService.ethernetDevices

                            delegate: Rectangle {
                                id: ethDeviceDelegate
                                required property var modelData
                                required property int index

                                readonly property bool isConnected: modelData.connected || false
                                readonly property bool isExpanded: networkTab.expandedEthDevice === modelData.name

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
                                                }

                                                Row {
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
                                                        visible: modelData.ip && modelData.ip.length > 0
                                                    }

                                                    StyledText {
                                                        text: modelData.ip || ""
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        color: Theme.surfaceVariantText
                                                        visible: modelData.ip && modelData.ip.length > 0
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
                                                            networkTab.expandedEthDevice = "";
                                                        } else {
                                                            networkTab.expandedEthDevice = modelData.name;
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

                                                    Row {
                                                        anchors.centerIn: parent
                                                        spacing: Theme.spacingS

                                                        DankIcon {
                                                            name: "sync"
                                                            size: 16
                                                            color: Theme.surfaceVariantText

                                                            RotationAnimation on rotation {
                                                                running: NetworkService.networkWiredInfoLoading
                                                                loops: Animation.Infinite
                                                                from: 0
                                                                to: 360
                                                                duration: 1000
                                                            }
                                                        }

                                                        StyledText {
                                                            text: I18n.tr("Loading...")
                                                            font.pixelSize: Theme.fontSizeSmall
                                                            color: Theme.surfaceVariantText
                                                        }
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

            StyledRect {
                width: parent.width
                height: wifiSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                Column {
                    id: wifiSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: NetworkService.wifiEnabled ? "wifi" : "wifi_off"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM - wifiControls.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("WiFi")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: {
                                    if (NetworkService.wifiToggling)
                                        return I18n.tr("Toggling...");
                                    if (!NetworkService.wifiEnabled)
                                        return I18n.tr("Disabled");
                                    if (NetworkService.wifiConnected)
                                        return NetworkService.currentWifiSSID;
                                    return I18n.tr("Not connected");
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: NetworkService.wifiConnected ? Theme.primary : Theme.surfaceVariantText
                            }
                        }

                        Row {
                            id: wifiControls
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankActionButton {
                                iconName: "refresh"
                                buttonSize: 32
                                visible: NetworkService.wifiEnabled && !NetworkService.wifiToggling
                                enabled: !NetworkService.isScanning
                                onClicked: NetworkService.scanWifi()

                                RotationAnimation on rotation {
                                    running: NetworkService.isScanning
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 1000
                                }
                            }

                            DankToggle {
                                checked: NetworkService.wifiEnabled
                                enabled: !NetworkService.wifiToggling
                                onToggled: NetworkService.toggleWifiRadio()
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: NetworkService.wifiEnabled && (NetworkService.wifiDevices?.length ?? 0) > 1

                        StyledText {
                            text: I18n.tr("WiFi Device")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            width: parent.width - wifiDeviceLabel.width - wifiDeviceDropdown.width - Theme.spacingM * 2
                            height: 1
                        }

                        DankDropdown {
                            id: wifiDeviceDropdown
                            dropdownWidth: 150
                            popupWidth: 180
                            currentValue: NetworkService.wifiDeviceOverride || I18n.tr("Auto")
                            options: {
                                const devices = NetworkService.wifiDevices;
                                if (!devices || devices.length === 0)
                                    return [I18n.tr("Auto")];
                                return [I18n.tr("Auto")].concat(devices.map(d => d.name));
                            }
                            onValueChanged: value => {
                                const deviceName = value === I18n.tr("Auto") ? "" : value;
                                NetworkService.setWifiDeviceOverride(deviceName);
                            }
                        }
                    }

                    StyledText {
                        id: wifiDeviceLabel
                        visible: false
                        text: I18n.tr("WiFi Device")
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                        visible: NetworkService.wifiEnabled
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: NetworkService.wifiEnabled && !NetworkService.wifiToggling

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS
                            visible: NetworkService.wifiInterface.length > 0

                            Row {
                                width: parent.width
                                height: 24

                                StyledText {
                                    text: I18n.tr("Interface:")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceVariantText
                                    width: 100
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: NetworkService.wifiInterface || "-"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Row {
                                width: parent.width
                                height: 24
                                visible: NetworkService.wifiIP.length > 0

                                StyledText {
                                    text: I18n.tr("IP Address:")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceVariantText
                                    width: 100
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: NetworkService.wifiIP || "-"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Row {
                                width: parent.width
                                height: 24
                                visible: NetworkService.wifiConnected

                                StyledText {
                                    text: I18n.tr("Signal:")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceVariantText
                                    width: 100
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Row {
                                    spacing: Theme.spacingXS
                                    anchors.verticalCenter: parent.verticalCenter

                                    DankIcon {
                                        name: {
                                            const s = NetworkService.wifiSignalStrength;
                                            if (s >= 50)
                                                return "wifi";
                                            if (s >= 25)
                                                return "wifi_2_bar";
                                            return "wifi_1_bar";
                                        }
                                        size: 18
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: NetworkService.wifiSignalStrength + "%"
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                    }
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: Theme.spacingS
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            StyledText {
                                text: I18n.tr("Available Networks")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item {
                                width: 1
                                height: 1
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: NetworkService.wifiNetworks?.length ?? 0
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Item {
                            width: parent.width
                            height: 80
                            visible: NetworkService.isScanning && (NetworkService.wifiNetworks?.length ?? 0) === 0

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: "refresh"
                                    size: 32
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    RotationAnimation on rotation {
                                        running: true
                                        loops: Animation.Infinite
                                        from: 0
                                        to: 360
                                        duration: 1000
                                    }
                                }

                                StyledText {
                                    text: I18n.tr("Scanning...")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 4
                            visible: (NetworkService.wifiNetworks?.length ?? 0) > 0

                            Repeater {
                                model: {
                                    const ssid = NetworkService.currentWifiSSID;
                                    const networks = NetworkService.wifiNetworks || [];
                                    const pins = SettingsData.wifiNetworkPins || {};
                                    const pinnedSSID = pins["preferredWifi"];

                                    let sorted = [...networks];
                                    sorted.sort((a, b) => {
                                        if (a.ssid === pinnedSSID && b.ssid !== pinnedSSID)
                                            return -1;
                                        if (b.ssid === pinnedSSID && a.ssid !== pinnedSSID)
                                            return 1;
                                        if (a.ssid === ssid)
                                            return -1;
                                        if (b.ssid === ssid)
                                            return 1;
                                        return b.signal - a.signal;
                                    });
                                    return sorted;
                                }

                                delegate: Rectangle {
                                    id: wifiNetworkDelegate
                                    required property var modelData
                                    required property int index

                                    readonly property bool isConnected: modelData.ssid === NetworkService.currentWifiSSID
                                    readonly property bool isPinned: (SettingsData.wifiNetworkPins || {})["preferredWifi"] === modelData.ssid
                                    readonly property bool isExpanded: networkTab.expandedWifiSsid === modelData.ssid

                                    width: parent.width
                                    height: isExpanded ? 56 + wifiExpandedContent.height : 56
                                    radius: Theme.cornerRadius
                                    color: wifiNetworkMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight
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
                                                anchors.right: wifiNetworkActions.left
                                                anchors.rightMargin: Theme.spacingS
                                                spacing: Theme.spacingS

                                                DankIcon {
                                                    name: {
                                                        const s = modelData.signal || 0;
                                                        if (s >= 50)
                                                            return "wifi";
                                                        if (s >= 25)
                                                            return "wifi_2_bar";
                                                        return "wifi_1_bar";
                                                    }
                                                    size: 20
                                                    color: isConnected ? Theme.primary : Theme.surfaceText
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Column {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 2
                                                    width: parent.width - 20 - Theme.spacingS

                                                    Row {
                                                        spacing: Theme.spacingXS

                                                        StyledText {
                                                            text: modelData.ssid || I18n.tr("Unknown")
                                                            font.pixelSize: Theme.fontSizeMedium
                                                            color: isConnected ? Theme.primary : Theme.surfaceText
                                                            font.weight: isConnected ? Font.Medium : Font.Normal
                                                            elide: Text.ElideRight
                                                        }

                                                        DankIcon {
                                                            name: "push_pin"
                                                            size: 14
                                                            color: Theme.primary
                                                            visible: isPinned
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }

                                                    Row {
                                                        spacing: Theme.spacingXS

                                                        StyledText {
                                                            text: isConnected ? I18n.tr("Connected") : (modelData.secured ? I18n.tr("Secured") : I18n.tr("Open"))
                                                            font.pixelSize: Theme.fontSizeSmall
                                                            color: isConnected ? Theme.primary : Theme.surfaceVariantText
                                                        }

                                                        StyledText {
                                                            text: "•"
                                                            font.pixelSize: Theme.fontSizeSmall
                                                            color: Theme.surfaceVariantText
                                                            visible: modelData.saved
                                                        }

                                                        StyledText {
                                                            text: I18n.tr("Saved")
                                                            font.pixelSize: Theme.fontSizeSmall
                                                            color: Theme.primary
                                                            visible: modelData.saved
                                                        }

                                                        StyledText {
                                                            text: "•"
                                                            font.pixelSize: Theme.fontSizeSmall
                                                            color: Theme.surfaceVariantText
                                                        }

                                                        StyledText {
                                                            text: modelData.signal + "%"
                                                            font.pixelSize: Theme.fontSizeSmall
                                                            color: Theme.surfaceVariantText
                                                        }
                                                    }
                                                }
                                            }

                                            Row {
                                                id: wifiNetworkActions
                                                anchors.right: parent.right
                                                anchors.rightMargin: Theme.spacingS
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: Theme.spacingXS

                                                Rectangle {
                                                    width: 28
                                                    height: 28
                                                    radius: 14
                                                    color: wifiExpandBtn.containsMouse ? Theme.surfacePressed : "transparent"
                                                    visible: isConnected || modelData.saved

                                                    DankIcon {
                                                        anchors.centerIn: parent
                                                        name: isExpanded ? "expand_less" : "expand_more"
                                                        size: 18
                                                        color: Theme.surfaceText
                                                    }

                                                    MouseArea {
                                                        id: wifiExpandBtn
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (isExpanded) {
                                                                networkTab.expandedWifiSsid = "";
                                                            } else {
                                                                networkTab.expandedWifiSsid = modelData.ssid;
                                                                NetworkService.fetchNetworkInfo(modelData.ssid);
                                                            }
                                                        }
                                                    }
                                                }

                                                DankActionButton {
                                                    iconName: isPinned ? "push_pin" : "push_pin"
                                                    buttonSize: 28
                                                    iconColor: isPinned ? Theme.primary : Theme.surfaceVariantText
                                                    onClicked: {
                                                        const pins = JSON.parse(JSON.stringify(SettingsData.wifiNetworkPins || {}));
                                                        if (isPinned) {
                                                            delete pins["preferredWifi"];
                                                        } else {
                                                            pins["preferredWifi"] = modelData.ssid;
                                                        }
                                                        SettingsData.set("wifiNetworkPins", pins);
                                                    }
                                                }

                                                DankActionButton {
                                                    iconName: "delete"
                                                    buttonSize: 28
                                                    iconColor: Theme.error
                                                    visible: modelData.saved || isConnected
                                                    onClicked: {
                                                        forgetNetworkConfirm.showWithOptions({
                                                            title: I18n.tr("Forget Network"),
                                                            message: I18n.tr("Forget \"") + modelData.ssid + "\"?",
                                                            confirmText: I18n.tr("Forget"),
                                                            confirmColor: Theme.error,
                                                            onConfirm: () => NetworkService.forgetWifiNetwork(modelData.ssid)
                                                        });
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: wifiNetworkMouseArea

                                                anchors.fill: parent
                                                anchors.rightMargin: wifiNetworkActions.width + Theme.spacingM
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (isConnected) {
                                                        NetworkService.disconnectWifi();
                                                        return;
                                                    }
                                                    NetworkService.connectToWifi(modelData.ssid);
                                                }
                                            }
                                        }

                                        Column {
                                            id: wifiExpandedContent
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
                                                height: wifiDetailsColumn.implicitHeight + Theme.spacingM * 2

                                                Column {
                                                    id: wifiDetailsColumn
                                                    anchors.fill: parent
                                                    anchors.margins: Theme.spacingM
                                                    spacing: Theme.spacingS

                                                    Item {
                                                        width: parent.width
                                                        height: NetworkService.networkInfoLoading ? 40 : 0
                                                        visible: NetworkService.networkInfoLoading

                                                        Row {
                                                            anchors.centerIn: parent
                                                            spacing: Theme.spacingS

                                                            DankIcon {
                                                                name: "sync"
                                                                size: 16
                                                                color: Theme.surfaceVariantText

                                                                RotationAnimation on rotation {
                                                                    running: NetworkService.networkInfoLoading
                                                                    loops: Animation.Infinite
                                                                    from: 0
                                                                    to: 360
                                                                    duration: 1000
                                                                }
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
                                                        visible: !NetworkService.networkInfoLoading

                                                        Repeater {
                                                            model: {
                                                                const fields = [];
                                                                const net = modelData;
                                                                if (!net)
                                                                    return fields;

                                                                fields.push({
                                                                    label: I18n.tr("Signal"),
                                                                    value: net.signal + "%"
                                                                });
                                                                if (net.frequency)
                                                                    fields.push({
                                                                        label: I18n.tr("Frequency"),
                                                                        value: (net.frequency / 1000).toFixed(1) + " GHz"
                                                                    });
                                                                if (net.channel)
                                                                    fields.push({
                                                                        label: I18n.tr("Channel"),
                                                                        value: String(net.channel)
                                                                    });
                                                                if (net.rate)
                                                                    fields.push({
                                                                        label: I18n.tr("Rate"),
                                                                        value: net.rate + " Mbps"
                                                                    });
                                                                if (net.mode)
                                                                    fields.push({
                                                                        label: I18n.tr("Mode"),
                                                                        value: net.mode
                                                                    });
                                                                if (net.bssid)
                                                                    fields.push({
                                                                        label: I18n.tr("BSSID"),
                                                                        value: net.bssid
                                                                    });
                                                                fields.push({
                                                                    label: I18n.tr("Security"),
                                                                    value: net.secured ? (net.enterprise ? I18n.tr("Enterprise") : I18n.tr("WPA/WPA2")) : I18n.tr("Open")
                                                                });

                                                                return fields;
                                                            }

                                                            delegate: Rectangle {
                                                                required property var modelData
                                                                required property int index

                                                                width: wifiFieldContent.width + Theme.spacingM * 2
                                                                height: 32
                                                                radius: Theme.cornerRadius - 2
                                                                color: Theme.surfaceContainerHigh
                                                                border.width: 1
                                                                border.color: Theme.outlineLight

                                                                Row {
                                                                    id: wifiFieldContent
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

                                                    Row {
                                                        spacing: Theme.spacingS
                                                        visible: (modelData.saved || isConnected) && DMSService.apiVersion > 13

                                                        DankToggle {
                                                            id: autoconnectToggle
                                                            text: I18n.tr("Autoconnect")
                                                            checked: modelData.autoconnect || false
                                                            onToggled: checked => {
                                                                NetworkService.setWifiAutoconnect(modelData.ssid, checked);
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: vpnSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                visible: DMSNetworkService.vpnAvailable

                Column {
                    id: vpnSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: DMSNetworkService.connected ? "vpn_lock" : "vpn_key_off"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM - vpnHeaderControls.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("VPN")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

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
                            }
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
                                    onClicked: vpnFileBrowser.open()
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
                    }

                    Item {
                        width: parent.width
                        height: 100
                        visible: DMSNetworkService.profiles.length === 0

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
                        visible: DMSNetworkService.profiles.length > 0

                        Repeater {
                            model: DMSNetworkService.profiles

                            delegate: Rectangle {
                                id: vpnProfileRow
                                required property var modelData
                                required property int index

                                readonly property bool isActive: DMSNetworkService.isActiveUuid(modelData.uuid)
                                readonly property bool isExpanded: networkTab.expandedVpnUuid === modelData.uuid
                                readonly property var configData: isExpanded ? VPNService.editConfig : null

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
                                            width: parent.width - 20 - 28 - 28 - Theme.spacingS * 4

                                            StyledText {
                                                text: modelData.name
                                                font.pixelSize: Theme.fontSizeMedium
                                                color: isActive ? Theme.primary : Theme.surfaceText
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }

                                            StyledText {
                                                text: VPNService.getVpnTypeFromProfile(modelData)
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
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
                                                        networkTab.expandedVpnUuid = "";
                                                    } else {
                                                        networkTab.expandedVpnUuid = modelData.uuid;
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
                                        id: vpnExpandedContent
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
        }
    }
}
