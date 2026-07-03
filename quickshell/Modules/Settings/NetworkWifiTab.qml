pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Modules.Network
import qs.Modules.Settings.Widgets
import qs.Modals.Common
import qs.Services
import qs.Widgets

Item {
    id: networkWifiTab

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    Component.onCompleted: {
        NetworkService.addRef();
        Qt.callLater(() => NetworkService.refreshSavedWifiNetworks());
    }

    Component.onDestruction: {
        NetworkService.removeRef();
    }

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

                property string expandedWifiSsid: ""
                property string expandedSavedWifiSsid: ""
                property int maxPinnedWifiNetworks: 3

                function normalizePinList(value) {
                    if (Array.isArray(value))
                        return value.filter(v => v);
                    if (typeof value === "string" && value.length > 0)
                        return [value];
                    return [];
                }

                function getPinnedWifiNetworks() {
                    const pins = SettingsData.wifiNetworkPins || {};
                    return normalizePinList(pins["preferredWifi"]);
                }

                function toggleWifiPin(ssid) {
                    const pins = JSON.parse(JSON.stringify(SettingsData.wifiNetworkPins || {}));
                    let pinnedList = normalizePinList(pins["preferredWifi"]);
                    const pinIndex = pinnedList.indexOf(ssid);

                    if (pinIndex !== -1) {
                        pinnedList.splice(pinIndex, 1);
                    } else {
                        pinnedList.unshift(ssid);
                        if (pinnedList.length > maxPinnedWifiNetworks)
                            pinnedList = pinnedList.slice(0, maxPinnedWifiNetworks);
                    }

                    if (pinnedList.length > 0)
                        pins["preferredWifi"] = pinnedList;
                    else
                        delete pins["preferredWifi"];

                    SettingsData.set("wifiNetworkPins", pins);
                }

                property var forgetNetworkConfirm: ConfirmModal {}

                width: parent.width
                title: I18n.tr("WiFi")
                iconName: "wifi"
                settingKey: "networkWifi"
                tags: ["wifi", "wi-fi", "wireless", "network", "ssid", "adapter", "radio"]

                function visibleWifiBySsid(ssid) {
                    const networks = NetworkService.wifiNetworks || [];
                    return networks.find(network => network.ssid === ssid) || null;
                }

                function mergedSavedWifiNetworks() {
                    const saved = NetworkService.savedWifiNetworks || [];
                    const supportsSavedWifiState = DMSService.apiVersion >= NetworkService.savedWifiStateApiVersion;
                    const result = [];
                    const seen = new Set();

                    for (const network of saved) {
                        if (!network?.ssid || seen.has(network.ssid))
                            continue;
                        const isOutOfRange = supportsSavedWifiState ? network.outOfRange === true : false;
                        const visibleNetwork = !isOutOfRange ? visibleWifiBySsid(network.ssid) : null;
                        if (visibleNetwork) {
                            result.push(Object.assign({}, network, visibleNetwork, {
                                saved: true,
                                autoconnect: network.autoconnect ?? visibleNetwork.autoconnect,
                                hidden: (network.hidden || false) || (visibleNetwork.hidden || false),
                                outOfRange: false
                            }));
                        } else {
                            result.push(Object.assign({}, network, {
                                saved: true,
                                outOfRange: isOutOfRange
                            }));
                        }
                        seen.add(network.ssid);
                    }

                    return result;
                }

                function sortedSavedWifiNetworks() {
                    const ssid = NetworkService.currentWifiSSID;
                    const pinnedList = root.getPinnedWifiNetworks();
                    let sorted = root.mergedSavedWifiNetworks();

                    sorted.sort((a, b) => {
                        const aPinnedIndex = pinnedList.indexOf(a.ssid);
                        const bPinnedIndex = pinnedList.indexOf(b.ssid);
                        if (aPinnedIndex !== -1 || bPinnedIndex !== -1) {
                            if (aPinnedIndex === -1)
                                return 1;
                            if (bPinnedIndex === -1)
                                return -1;
                            return aPinnedIndex - bPinnedIndex;
                        }
                        if (a.ssid === ssid)
                            return -1;
                        if (b.ssid === ssid)
                            return 1;
                        if ((a.outOfRange || false) !== (b.outOfRange || false))
                            return (a.outOfRange || false) ? 1 : -1;
                        if ((a.signal || 0) !== (b.signal || 0))
                            return (b.signal || 0) - (a.signal || 0);
                        return (a.ssid || "").localeCompare(b.ssid || "");
                    });
                    return sorted;
                }

                function showForgetNetworkConfirm(ssid) {
                    forgetNetworkConfirm.showWithOptions({
                        title: I18n.tr("Forget Network"),
                        message: I18n.tr("Forget \"%1\"?").arg(ssid),
                        confirmText: I18n.tr("Forget"),
                        confirmColor: Theme.error,
                        onConfirm: () => NetworkService.forgetWifiNetwork(ssid)
                    });
                }

                Column {
                    id: wifiSection

                    width: parent.width
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

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
                            width: parent.width - wifiControls.width - Theme.spacingM
                            horizontalAlignment: Text.AlignLeft
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Row {
                            id: wifiControls
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankActionButton {
                                iconName: "wifi_find"
                                buttonSize: 32
                                visible: NetworkService.backend === "networkmanager" && NetworkService.wifiEnabled && !NetworkService.wifiToggling
                                onClicked: PopoutService.showHiddenNetworkModal()
                            }

                            DankActionButton {
                                iconName: "refresh"
                                buttonSize: 32
                                visible: NetworkService.wifiEnabled && !NetworkService.wifiToggling && !NetworkService.isScanning
                                onClicked: NetworkService.scanWifi()
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
                        color: Theme.outlineStrong
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
                                    id: scanningIcon
                                    name: "wifi_find"
                                    size: 32
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    SequentialAnimation {
                                        running: NetworkService.isScanning
                                        loops: Animation.Infinite
                                        OpacityAnimator {
                                            target: scanningIcon
                                            to: 0.3
                                            duration: 400
                                            easing.type: Easing.InOutQuad
                                        }
                                        OpacityAnimator {
                                            target: scanningIcon
                                            to: 1.0
                                            duration: 400
                                            easing.type: Easing.InOutQuad
                                        }
                                        onRunningChanged: if (!running)
                                            scanningIcon.opacity = 1.0
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
                            spacing: Theme.spacingXS
                            visible: (NetworkService.wifiNetworks?.length ?? 0) > 0

                            Repeater {
                                model: {
                                    const ssid = NetworkService.currentWifiSSID;
                                    const networks = NetworkService.wifiNetworks || [];
                                    const pinnedList = root.getPinnedWifiNetworks();

                                    let sorted = [...networks];
                                    sorted.sort((a, b) => {
                                        const aPinnedIndex = pinnedList.indexOf(a.ssid);
                                        const bPinnedIndex = pinnedList.indexOf(b.ssid);
                                        if (aPinnedIndex !== -1 || bPinnedIndex !== -1) {
                                            if (aPinnedIndex === -1)
                                                return 1;
                                            if (bPinnedIndex === -1)
                                                return -1;
                                            return aPinnedIndex - bPinnedIndex;
                                        }
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
                                    readonly property bool isConnecting: NetworkService.isWifiConnecting && NetworkService.connectingSSID === modelData.ssid
                                    readonly property bool isPinned: root.getPinnedWifiNetworks().includes(modelData.ssid)
                                    readonly property bool isExpanded: root.expandedWifiSsid === modelData.ssid

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

                                                DankSpinner {
                                                    size: 20
                                                    strokeWidth: 2
                                                    color: Theme.warning
                                                    running: isConnecting
                                                    visible: isConnecting
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                DankIcon {
                                                    visible: !isConnecting
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
                                                    spacing: Theme.spacingXXS
                                                    width: parent.width - 20 - Theme.spacingS

                                                    Row {
                                                        anchors.left: parent.left
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

                                                        DankIcon {
                                                            name: "visibility_off"
                                                            size: 14
                                                            color: Theme.surfaceVariantText
                                                            visible: modelData.hidden || false
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }

                                                    Row {
                                                        anchors.left: parent.left
                                                        spacing: Theme.spacingXS

                                                        StyledText {
                                                            text: isConnecting ? I18n.tr("Connecting...") : (isConnected ? I18n.tr("Connected") : (modelData.secured ? I18n.tr("Secured") : I18n.tr("Open")))
                                                            font.pixelSize: Theme.fontSizeSmall
                                                            color: isConnecting ? Theme.warning : (isConnected ? Theme.primary : Theme.surfaceVariantText)
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
                                                            visible: modelData.hidden || false
                                                        }

                                                        StyledText {
                                                            text: I18n.tr("Hidden")
                                                            font.pixelSize: Theme.fontSizeSmall
                                                            color: Theme.surfaceVariantText
                                                            visible: modelData.hidden || false
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
                                                    color: wifiExpandBtn.containsMouse ? Theme.surfacePressed : Theme.withAlpha(Theme.surfacePressed, 0)
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
                                                                root.expandedWifiSsid = "";
                                                            } else {
                                                                root.expandedWifiSsid = modelData.ssid;
                                                                NetworkService.fetchNetworkInfo(modelData.ssid);
                                                            }
                                                        }
                                                    }
                                                }

                                                DankActionButton {
                                                    iconName: "qr_code"
                                                    buttonSize: 28
                                                    visible: modelData.secured && modelData.saved && !(modelData.enterprise || false)
                                                    onClicked: {
                                                        PopoutService.showWifiQRCodeModal(modelData.ssid);
                                                    }
                                                }

                                                DankActionButton {
                                                    iconName: isPinned ? "push_pin" : "push_pin"
                                                    buttonSize: 28
                                                    iconColor: isPinned ? Theme.primary : Theme.surfaceVariantText
                                                    onClicked: {
                                                        root.toggleWifiPin(modelData.ssid);
                                                    }
                                                }

                                                DankActionButton {
                                                    iconName: "delete"
                                                    buttonSize: 28
                                                    iconColor: Theme.error
                                                    visible: modelData.saved || isConnected
                                                    onClicked: {
                                                        root.showForgetNetworkConfirm(modelData.ssid);
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: wifiNetworkMouseArea

                                                anchors.fill: parent
                                                anchors.rightMargin: wifiNetworkActions.width + Theme.spacingM
                                                hoverEnabled: true
                                                enabled: !NetworkService.isWifiConnecting || isConnected
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.BusyCursor
                                                onClicked: {
                                                    WifiConnectionActions.connectToNetwork(modelData, {
                                                        connected: isConnected,
                                                        disconnectWhenConnected: true
                                                    });
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

                                                        DankSpinner {
                                                            anchors.centerIn: parent
                                                            size: 20
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
            SettingsCard {
                id: savedWifiCard

                readonly property var savedNetworks: root.sortedSavedWifiNetworks()

                width: parent.width
                title: I18n.tr("Saved Networks")
                iconName: "bookmark"
                settingKey: "networkSavedWifi"
                tags: ["wifi", "wi-fi", "wireless", "network", "saved", "known", "ssid", "autoconnect", "forget"]
                collapsible: true
                expanded: false
                visible: savedNetworks.length > 0

                headerActions: [
                    StyledText {
                        text: savedWifiCard.savedNetworks.length
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        verticalAlignment: Text.AlignVCenter
                    }
                ]

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    Repeater {
                        model: savedWifiCard.expanded ? savedWifiCard.savedNetworks : []

                        delegate: Rectangle {
                            id: savedWifiDelegate

                            required property var modelData
                            required property int index

                            readonly property bool isConnected: modelData.ssid === NetworkService.currentWifiSSID
                            readonly property bool isConnecting: NetworkService.isWifiConnecting && NetworkService.connectingSSID === modelData.ssid
                            readonly property bool isPinned: root.getPinnedWifiNetworks().includes(modelData.ssid)
                            readonly property bool isOutOfRange: modelData.outOfRange || false
                            readonly property bool isExpanded: !isOutOfRange && root.expandedSavedWifiSsid === modelData.ssid

                            width: parent.width
                            height: isExpanded ? 56 + savedWifiExpandedContent.height : 56
                            radius: Theme.cornerRadius
                            color: savedWifiMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight
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
                                        anchors.right: savedWifiActions.left
                                        anchors.rightMargin: Theme.spacingS
                                        spacing: Theme.spacingS

                                        DankSpinner {
                                            size: 20
                                            strokeWidth: 2
                                            color: Theme.warning
                                            running: isConnecting
                                            visible: isConnecting
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        DankIcon {
                                            visible: !isConnecting
                                            name: {
                                                if (isOutOfRange)
                                                    return "wifi_off";
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
                                            spacing: Theme.spacingXXS
                                            width: parent.width - 20 - Theme.spacingS

                                            Row {
                                                anchors.left: parent.left
                                                spacing: Theme.spacingXS
                                                width: parent.width

                                                StyledText {
                                                    text: modelData.ssid || I18n.tr("Unknown")
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    color: isConnected ? Theme.primary : Theme.surfaceText
                                                    font.weight: isConnected ? Font.Medium : Font.Normal
                                                    elide: Text.ElideRight
                                                    width: Math.max(0, parent.width - (savedWifiHiddenIcon.visible ? savedWifiHiddenIcon.width + Theme.spacingXS : 0))
                                                }

                                                DankIcon {
                                                    id: savedWifiHiddenIcon
                                                    name: "visibility_off"
                                                    size: 14
                                                    color: Theme.surfaceVariantText
                                                    visible: modelData.hidden || false
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            StyledText {
                                                text: {
                                                    if (isConnecting)
                                                        return I18n.tr("Connecting...");
                                                    const parts = [isConnected ? I18n.tr("Connected") : (modelData.secured ? I18n.tr("Secured") : I18n.tr("Open"))];
                                                    parts.push(isOutOfRange ? I18n.tr("Unavailable") : (modelData.signal || 0) + "%");
                                                    if (modelData.hidden || false)
                                                        parts.push(I18n.tr("Hidden"));
                                                    return parts.join(" • ");
                                                }
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: isConnecting ? Theme.warning : (isConnected ? Theme.primary : Theme.surfaceVariantText)
                                                width: parent.width
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    Row {
                                        id: savedWifiActions
                                        anchors.right: parent.right
                                        anchors.rightMargin: Theme.spacingS
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Theme.spacingXS

                                        Rectangle {
                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: savedWifiExpandBtn.containsMouse ? Theme.surfacePressed : Theme.withAlpha(Theme.surfacePressed, 0)
                                            visible: !isOutOfRange

                                            DankIcon {
                                                anchors.centerIn: parent
                                                name: isExpanded ? "expand_less" : "expand_more"
                                                size: 18
                                                color: Theme.surfaceText
                                            }

                                            MouseArea {
                                                id: savedWifiExpandBtn
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (isExpanded) {
                                                        root.expandedSavedWifiSsid = "";
                                                    } else {
                                                        root.expandedSavedWifiSsid = modelData.ssid;
                                                    }
                                                }
                                            }
                                        }

                                        DankActionButton {
                                            iconName: "qr_code"
                                            buttonSize: 28
                                            visible: modelData.secured && !(modelData.enterprise || false)
                                            onClicked: {
                                                PopoutService.showWifiQRCodeModal(modelData.ssid);
                                            }
                                        }

                                        DankActionButton {
                                            iconName: "push_pin"
                                            buttonSize: 28
                                            iconColor: isPinned ? Theme.primary : Theme.surfaceVariantText
                                            onClicked: {
                                                root.toggleWifiPin(modelData.ssid);
                                            }
                                        }

                                        DankActionButton {
                                            id: savedWifiMoreButton
                                            iconName: "more_horiz"
                                            buttonSize: 28
                                            onClicked: {
                                                if (savedWifiMenu.visible) {
                                                    savedWifiMenu.close();
                                                    return;
                                                }
                                                savedWifiMenu.popup(savedWifiMoreButton, -savedWifiMenu.width + savedWifiMoreButton.width, savedWifiMoreButton.height + Theme.spacingXS);
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: savedWifiMouseArea
                                        anchors.fill: parent
                                        anchors.rightMargin: savedWifiActions.width + Theme.spacingM
                                        hoverEnabled: true
                                        enabled: !NetworkService.isWifiConnecting || isConnected
                                        cursorShape: isOutOfRange ? Qt.ArrowCursor : (enabled ? Qt.PointingHandCursor : Qt.BusyCursor)
                                        onClicked: {
                                            if (isOutOfRange)
                                                return;
                                            if (isExpanded) {
                                                root.expandedSavedWifiSsid = "";
                                            } else {
                                                root.expandedSavedWifiSsid = modelData.ssid;
                                            }
                                        }
                                    }
                                }

                                Column {
                                    id: savedWifiExpandedContent
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
                                        height: savedWifiDetailsColumn.implicitHeight + Theme.spacingM * 2

                                        Column {
                                            id: savedWifiDetailsColumn
                                            anchors.fill: parent
                                            anchors.margins: Theme.spacingM
                                            spacing: Theme.spacingS

                                            Flow {
                                                width: parent.width
                                                spacing: Theme.spacingXS

                                                Repeater {
                                                    model: {
                                                        const fields = [];
                                                        const net = modelData;
                                                        if (!net)
                                                            return fields;

                                                        fields.push({
                                                            label: I18n.tr("Signal"),
                                                            value: (net.signal || 0) + "%"
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

                                                        width: savedWifiFieldContent.width + Theme.spacingM * 2
                                                        height: 32
                                                        radius: Theme.cornerRadius - 2
                                                        color: Theme.surfaceContainerHigh
                                                        border.width: 1
                                                        border.color: Theme.outlineLight

                                                        Row {
                                                            id: savedWifiFieldContent
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
                                        }
                                    }
                                }
                            }

                            Menu {
                                id: savedWifiMenu
                                width: 170
                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                                background: Rectangle {
                                    color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                                    radius: Theme.cornerRadius
                                    border.width: 0
                                }

                                MenuItem {
                                    text: isConnecting ? I18n.tr("Connecting...") : (isConnected ? I18n.tr("Disconnect") : I18n.tr("Connect"))
                                    height: isOutOfRange ? 0 : 32
                                    visible: !isOutOfRange
                                    enabled: !isConnecting

                                    contentItem: StyledText {
                                        text: parent.text
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: parent.enabled ? Theme.surfaceText : Theme.surfaceVariantText
                                        leftPadding: Theme.spacingS
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    background: Rectangle {
                                        color: parent.hovered ? Theme.primaryHoverLight : Theme.withAlpha(Theme.primaryHoverLight, 0)
                                        radius: Theme.cornerRadius / 2
                                    }

                                    onTriggered: {
                                        WifiConnectionActions.connectToNetwork(modelData, {
                                            connected: isConnected,
                                            disconnectWhenConnected: true
                                        });
                                    }
                                }

                                MenuItem {
                                    text: modelData.autoconnect ? I18n.tr("Disable Autoconnect") : I18n.tr("Enable Autoconnect")
                                    height: DMSService.apiVersion > 13 ? 32 : 0
                                    visible: DMSService.apiVersion > 13

                                    contentItem: StyledText {
                                        text: parent.text
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        leftPadding: Theme.spacingS
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    background: Rectangle {
                                        color: parent.hovered ? Theme.primaryHoverLight : Theme.withAlpha(Theme.primaryHoverLight, 0)
                                        radius: Theme.cornerRadius / 2
                                    }

                                    onTriggered: {
                                        NetworkService.setWifiAutoconnect(modelData.ssid, !(modelData.autoconnect || false));
                                    }
                                }

                                MenuItem {
                                    text: I18n.tr("Forget Network")
                                    height: 32

                                    contentItem: StyledText {
                                        text: parent.text
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.error
                                        leftPadding: Theme.spacingS
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    background: Rectangle {
                                        color: parent.hovered ? Theme.errorHover : Theme.withAlpha(Theme.errorHover, 0)
                                        radius: Theme.cornerRadius / 2
                                    }

                                    onTriggered: {
                                        root.showForgetNetworkConfirm(modelData.ssid);
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
