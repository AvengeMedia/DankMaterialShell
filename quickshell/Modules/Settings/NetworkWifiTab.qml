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
                                    text: I18n.tr("Signal") + ":"
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
                                                            text: isConnecting ? I18n.tr("Connecting...") : (isConnected ? I18n.tr("Connected") : (modelData.secured ? I18n.tr("Secured") : I18n.tr("Open", "network security type", true)))
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
                                                                    value: net.secured ? (net.enterprise ? I18n.tr("Enterprise") : I18n.tr("WPA/WPA2")) : I18n.tr("Open", "network security type", true)
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
                                                    const parts = [isConnected ? I18n.tr("Connected") : (modelData.secured ? I18n.tr("Secured") : I18n.tr("Open", "network security type", true))];
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
                                                            value: net.secured ? (net.enterprise ? I18n.tr("Enterprise") : I18n.tr("WPA/WPA2")) : I18n.tr("Open", "network security type", true)
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

            SettingsCard {
                id: hotspotCard

                width: parent.width
                title: I18n.tr("Hotspot", "hotspot settings card title")
                iconName: "wifi_tethering"
                settingKey: "networkHotspot"
                tags: ["wifi", "wi-fi", "wireless", "network", "hotspot", "access point", "sharing", "ssid"]
                visible: NetworkService.hotspotAvailable

                property string ssid: NetworkService.hotspotSSID || ""
                property string password: ""
                property string device: NetworkService.hotspotDevice || ""
                property string band: NetworkService.hotspotBand || ""
                property bool editing: false
                property bool passwordLoading: false
                property bool passwordResolved: true
                property int passwordRequestId: 0
                property int passwordEditRevision: 0
                readonly property bool showForm: !NetworkService.hotspotConfigured || editing
                readonly property bool starting: NetworkService.hotspotBusy || NetworkService.hotspotActivating
                property var startConfirm: ConfirmModal {}

                function confirmThenStart(targetDevice, targetBand, startFn) {
                    if (!NetworkService.hotspotTargetWouldDisconnectWifi(targetDevice, targetBand)) {
                        startFn();
                        return;
                    }
                    startConfirm.showWithOptions({
                        title: I18n.tr("Start Hotspot?", "hotspot start confirmation title"),
                        message: I18n.tr("This will disconnect WiFi from \"%1\" — the radio can't host a hotspot and stay connected at the same time. Internet sharing will need another connection, such as Ethernet.", "hotspot WiFi disconnection confirmation message").arg(NetworkService.currentWifiSSID),
                        confirmText: I18n.tr("Start", "hotspot start confirmation action"),
                        onConfirm: startFn
                    });
                }

                function bandLabel(value) {
                    switch (value) {
                    case "bg":
                        return I18n.tr("2.4 GHz", "hotspot WiFi band option");
                    case "a":
                        return I18n.tr("5 GHz", "hotspot WiFi band option");
                    default:
                        return I18n.tr("Auto", "hotspot device or band option");
                    }
                }

                function bandValue(label) {
                    if (label === I18n.tr("2.4 GHz", "hotspot WiFi band option"))
                        return "bg";
                    if (label === I18n.tr("5 GHz", "hotspot WiFi band option"))
                        return "a";
                    return "";
                }

                function syncFromService() {
                    ssid = NetworkService.hotspotSSID || ssid || "";
                    device = NetworkService.hotspotDevice || "";
                    band = NetworkService.hotspotBand || "";
                }

                function beginEditing() {
                    syncFromService();
                    password = "";
                    editing = true;
                    passwordRequestId++;
                    const requestId = passwordRequestId;
                    const editRevision = passwordEditRevision;
                    passwordLoading = NetworkService.hotspotSecured;
                    passwordResolved = !NetworkService.hotspotSecured;
                    if (NetworkService.hotspotSecured) {
                        NetworkService.getHotspotSecrets(response => {
                            if (!editing || requestId !== passwordRequestId)
                                return;
                            passwordLoading = false;
                            if (response.error) {
                                ToastService.showError(I18n.tr("Couldn't load hotspot password", "hotspot password error title"), I18n.tr("Re-enter the password before saving.", "hotspot password recovery message"));
                            } else {
                                const storedPassword = response.result?.password ?? response.password ?? "";
                                if (!storedPassword) {
                                    ToastService.showError(I18n.tr("Couldn't load hotspot password", "hotspot password error title"), I18n.tr("Re-enter the password before saving.", "hotspot password recovery message"));
                                } else {
                                    passwordResolved = true;
                                    if (editRevision === passwordEditRevision) {
                                        password = storedPassword;
                                    }
                                }
                            }
                        });
                    }
                }

                function stopEditing() {
                    passwordRequestId++;
                    editing = false;
                    password = "";
                    passwordLoading = false;
                    passwordResolved = true;
                }

                function buildCanConfigure() {
                    return ssid.trim().length > 0 && passwordResolved && !passwordLoading && !NetworkService.hotspotBusy && !NetworkService.hotspotEnabled && !NetworkService.hotspotActivating;
                }

                function explainWiFiDisabled() {
                    ToastService.showError(I18n.tr("WiFi is disabled", "hotspot start error title"), I18n.tr("Enable WiFi before starting the hotspot.", "hotspot WiFi requirement message"));
                }

                function saveOnly() {
                    if (!buildCanConfigure())
                        return;
                    NetworkService.configureHotspot(ssid.trim(), password, device, band, response => {
                        if (!response.error) {
                            stopEditing();
                            ToastService.showInfo(I18n.tr("Hotspot saved", "hotspot configuration success message"));
                        }
                    });
                }

                function startOrStop() {
                    if (NetworkService.hotspotEnabled) {
                        NetworkService.stopHotspot(response => {
                            if (!response.error)
                                ToastService.showInfo(I18n.tr("Hotspot stopped", "hotspot stop success message"));
                        });
                        return;
                    }

                    if (!NetworkService.wifiEnabled) {
                        explainWiFiDisabled();
                        return;
                    }

                    if (showForm) {
                        if (!buildCanConfigure())
                            return;
                        confirmThenStart(device, band, () => {
                            NetworkService.configureAndStartHotspot(ssid.trim(), password, device, band, response => {
                                if (!response.error)
                                    stopEditing();
                            });
                        });
                        return;
                    }

                    confirmThenStart(NetworkService.hotspotDevice, NetworkService.hotspotBand, () => NetworkService.startHotspot());
                }

                onVisibleChanged: if (visible)
                    syncFromService()

                Column {
                    width: parent.width
                    spacing: Theme.spacingM

                    StyledText {
                        width: parent.width
                        text: {
                            if (NetworkService.hotspotEnabled)
                                return I18n.tr("Your hotspot is running.", "hotspot active status message");
                            if (hotspotCard.starting)
                                return I18n.tr("Starting hotspot...", "hotspot activation status message");
                            if (NetworkService.hotspotConfigured)
                                return I18n.tr("Your hotspot profile is saved and ready to start.", "configured hotspot status message");
                            return I18n.tr("Set up a WiFi hotspot for sharing this connection.", "unconfigured hotspot description");
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: NetworkService.hotspotEnabled ? Theme.primary : Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("WiFi is disabled. You can still edit and save hotspot settings, but starting the hotspot requires WiFi to be enabled.", "hotspot WiFi requirement explanation")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.warning
                        wrapMode: Text.WordWrap
                        visible: !NetworkService.wifiEnabled
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Starting the hotspot will disconnect WiFi from \"%1\" — the radio can't do both at once. Sharing internet then requires another connection, such as Ethernet.", "hotspot WiFi disconnection warning").arg(NetworkService.currentWifiSSID)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.warning
                        wrapMode: Text.WordWrap
                        visible: NetworkService.wifiEnabled && !NetworkService.hotspotEnabled && !hotspotCard.starting && (hotspotCard.showForm ? NetworkService.hotspotTargetWouldDisconnectWifi(hotspotCard.device, hotspotCard.band) : NetworkService.hotspotWouldDisconnectWifi)
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: !hotspotCard.showForm

                        DankIcon {
                            name: NetworkService.hotspotEnabled ? "wifi_tethering" : "wifi_tethering_off"
                            size: Theme.iconSize
                            color: NetworkService.hotspotEnabled ? Theme.primary : Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                width: parent.width
                                text: NetworkService.hotspotSSID
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                            }

                            StyledText {
                                width: parent.width
                                text: {
                                    const parts = [NetworkService.hotspotSecured ? I18n.tr("WPA2 password", "hotspot security summary") : I18n.tr("Open network", "hotspot security summary"), hotspotCard.bandLabel(NetworkService.hotspotBand)];
                                    if (NetworkService.hotspotDevice)
                                        parts.push(NetworkService.hotspotDevice);
                                    return parts.join(" • ");
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: hotspotCard.showForm

                        DankTextField {
                            width: parent.width
                            labelText: I18n.tr("Hotspot name", "hotspot SSID field label")
                            placeholderText: I18n.tr("SSID", "hotspot network name placeholder")
                            text: hotspotCard.ssid
                            leftIconName: "badge"
                            showClearButton: true
                            onTextEdited: hotspotCard.ssid = text
                            onAccepted: hotspotCard.saveOnly()
                        }

                        DankTextField {
                            width: parent.width
                            labelText: I18n.tr("Password", "hotspot password field label")
                            placeholderText: I18n.tr("Optional; leave blank for open hotspot", "hotspot password field placeholder")
                            text: hotspotCard.password
                            leftIconName: "key"
                            showPasswordToggle: true
                            echoMode: passwordVisible ? TextInput.Normal : TextInput.Password
                            onTextEdited: {
                                hotspotCard.password = text;
                                hotspotCard.passwordEditRevision++;
                                if (text.length > 0)
                                    hotspotCard.passwordResolved = true;
                            }
                            onAccepted: hotspotCard.saveOnly()
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            DankDropdown {
                                width: (parent.width - Theme.spacingM) / 2
                                text: I18n.tr("Device", "hotspot WiFi device field label")
                                description: I18n.tr("Optional", "hotspot WiFi device field description")
                                currentValue: hotspotCard.device || I18n.tr("Auto", "hotspot device or band option")
                                options: {
                                    const devices = NetworkService.wifiDevices || [];
                                    return [I18n.tr("Auto", "hotspot device or band option")].concat(devices.filter(d => d.apCapable).map(d => d.name));
                                }
                                onValueChanged: value => hotspotCard.device = value === I18n.tr("Auto", "hotspot device or band option") ? "" : value
                            }

                            DankDropdown {
                                width: (parent.width - Theme.spacingM) / 2
                                text: I18n.tr("Band", "hotspot WiFi band field label")
                                description: I18n.tr("Optional", "hotspot WiFi band field description")
                                currentValue: hotspotCard.bandLabel(hotspotCard.band)
                                options: [I18n.tr("Auto", "hotspot device or band option"), I18n.tr("2.4 GHz", "hotspot WiFi band option"), I18n.tr("5 GHz", "hotspot WiFi band option")]
                                onValueChanged: value => hotspotCard.band = hotspotCard.bandValue(value)
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        Item {
                            width: Math.max(0, parent.width - (cancelButton.visible ? cancelButton.width + Theme.spacingS : 0) - (editButton.visible ? editButton.width + Theme.spacingS : 0) - (saveButton.visible ? saveButton.width + Theme.spacingS : 0) - (startStopButton.width + Theme.spacingS))
                            height: 1
                        }

                        DankButton {
                            id: cancelButton
                            visible: hotspotCard.editing
                            text: I18n.tr("Cancel", "cancel hotspot editing action")
                            buttonHeight: 36
                            backgroundColor: Theme.surfaceVariant
                            textColor: Theme.surfaceText
                            onClicked: hotspotCard.stopEditing()
                        }

                        DankButton {
                            id: editButton
                            visible: !hotspotCard.showForm
                            text: I18n.tr("Edit", "edit hotspot action")
                            iconName: "edit"
                            buttonHeight: 36
                            enabled: !NetworkService.hotspotEnabled && !hotspotCard.starting
                            backgroundColor: Theme.surfaceVariant
                            textColor: Theme.surfaceText
                            onClicked: hotspotCard.beginEditing()
                        }

                        DankButton {
                            id: saveButton
                            visible: hotspotCard.showForm
                            text: hotspotCard.passwordLoading ? I18n.tr("Loading...", "hotspot password loading status") : (NetworkService.hotspotBusy ? I18n.tr("Saving...", "hotspot configuration saving status") : I18n.tr("Save", "save hotspot configuration action"))
                            iconName: "save"
                            buttonHeight: 36
                            enabled: hotspotCard.buildCanConfigure()
                            backgroundColor: Theme.surfaceVariant
                            textColor: Theme.surfaceText
                            onClicked: hotspotCard.saveOnly()
                        }

                        DankButton {
                            id: startStopButton
                            text: {
                                if (NetworkService.hotspotEnabled)
                                    return I18n.tr("Stop", "stop hotspot action");
                                if (hotspotCard.starting)
                                    return I18n.tr("Starting...", "hotspot activation status");
                                return hotspotCard.showForm ? I18n.tr("Save & Start", "save and start hotspot action") : I18n.tr("Start", "start hotspot action");
                            }
                            iconName: NetworkService.hotspotEnabled ? "stop" : "wifi_tethering"
                            buttonHeight: 36
                            enabled: !hotspotCard.starting && (NetworkService.hotspotEnabled || hotspotCard.buildCanConfigure())
                            backgroundColor: NetworkService.hotspotEnabled ? Theme.error : Theme.primary
                            textColor: NetworkService.hotspotEnabled ? Theme.surfaceText : Theme.onPrimary
                            onClicked: hotspotCard.startOrStop()
                        }
                    }
                }
            }
        }
    }
}
