import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    implicitHeight: {
        if (height > 0)
            return height;
        if (NetworkService.wifiToggling)
            return headerRow.height + wifiToggleContent.height + Theme.spacingM;
        if (NetworkService.wifiEnabled)
            return headerRow.height + wifiContent.height + Theme.spacingM;
        return headerRow.height + wifiOffContent.height + Theme.spacingM;
    }
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 0

    Component.onCompleted: {
        NetworkService.addRef();
    }

    Component.onDestruction: {
        NetworkService.removeRef();
    }

    property bool hasEthernetAvailable: (NetworkService.ethernetDevices?.length ?? 0) > 0
    property bool hasWifiAvailable: (NetworkService.wifiDevices?.length ?? 0) > 0
    property bool hasBothConnectionTypes: hasEthernetAvailable && hasWifiAvailable
    property int maxPinnedNetworks: 3

    function normalizePinList(value) {
        if (Array.isArray(value))
            return value.filter(v => v);
        if (typeof value === "string" && value.length > 0)
            return [value];
        return [];
    }

    function getPinnedNetworks() {
        const pins = SettingsData.wifiNetworkPins || {};
        return normalizePinList(pins["preferredWifi"]);
    }

    property int currentPreferenceIndex: {
        if (DMSService.apiVersion < 5)
            return 1;
        if (NetworkService.backend !== "networkmanager" || DMSService.apiVersion <= 10)
            return 1;
        if (!hasEthernetAvailable)
            return 1;
        if (!hasWifiAvailable)
            return 0;

        const pref = NetworkService.userPreference;
        switch (pref) {
        case "ethernet":
            return 0;
        case "wifi":
            return 1;
        default:
            return NetworkService.networkStatus === "ethernet" ? 0 : 1;
        }
    }

    Row {
        id: headerRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.topMargin: Theme.spacingS
        height: Math.max(headerLeft.implicitHeight, rightControls.implicitHeight) + Theme.spacingS * 2

        StyledText {
            id: headerLeft
            text: I18n.tr("Network")
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.surfaceText
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            height: 1
            width: parent.width - headerLeft.width - rightControls.width
        }

        Row {
            id: rightControls
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            DankDropdown {
                id: wifiDeviceDropdown
                anchors.verticalCenter: parent.verticalCenter
                visible: currentPreferenceIndex === 1 && (NetworkService.wifiDevices?.length ?? 0) > 1
                compactMode: true
                dropdownWidth: 120
                popupWidth: 160
                alignPopupRight: true

                options: {
                    const devices = NetworkService.wifiDevices;
                    if (!devices || devices.length === 0)
                        return [I18n.tr("Auto")];
                    return [I18n.tr("Auto")].concat(devices.map(d => d.name));
                }

                currentValue: NetworkService.wifiDeviceOverride || I18n.tr("Auto")

                onValueChanged: value => {
                    const deviceName = value === I18n.tr("Auto") ? "" : value;
                    NetworkService.setWifiDeviceOverride(deviceName);
                }
            }

            DankButtonGroup {
                id: preferenceControls
                anchors.verticalCenter: parent.verticalCenter
                visible: hasBothConnectionTypes && NetworkService.backend === "networkmanager" && DMSService.apiVersion > 10
                buttonHeight: 28
                textSize: Theme.fontSizeSmall

                model: [I18n.tr("Ethernet"), I18n.tr("WiFi")]
                currentIndex: currentPreferenceIndex
                selectionMode: "single"
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    NetworkService.setNetworkPreference(index === 0 ? "ethernet" : "wifi");
                }
            }

            DankActionButton {
                anchors.verticalCenter: parent.verticalCenter
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
    }

    Item {
        id: wifiToggleContent
        anchors.top: headerRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingM
        anchors.topMargin: Theme.spacingM
        visible: currentPreferenceIndex === 1 && NetworkService.wifiToggling
        height: visible ? wifiToggleColumn.implicitHeight + Theme.spacingM * 2 : 0

        Column {
            id: wifiToggleColumn
            anchors.centerIn: parent
            spacing: Theme.spacingM

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "sync"
                size: 32
                color: Theme.primary

                RotationAnimation on rotation {
                    running: NetworkService.wifiToggling
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 1000
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: NetworkService.wifiEnabled ? I18n.tr("Disabling WiFi...") : I18n.tr("Enabling WiFi...")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Item {
        id: wifiOffContent
        anchors.top: headerRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingM
        anchors.topMargin: Theme.spacingM
        visible: currentPreferenceIndex === 1 && !NetworkService.wifiEnabled && !NetworkService.wifiToggling
        height: visible ? wifiOffColumn.implicitHeight + Theme.spacingM * 2 : 0

        Column {
            id: wifiOffColumn
            anchors.centerIn: parent
            spacing: Theme.spacingL
            width: parent.width

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "wifi_off"
                size: 48
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.tr("WiFi is off")
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.surfaceText
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: enableWifiLabel.implicitWidth + Theme.spacingL * 2
                height: enableWifiLabel.implicitHeight + Theme.spacingM * 2
                radius: height / 2
                color: enableWifiButton.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                border.width: 0
                border.color: Theme.primary

                StyledText {
                    id: enableWifiLabel
                    anchors.centerIn: parent
                    text: I18n.tr("Enable WiFi")
                    color: Theme.primary
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: enableWifiButton
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NetworkService.toggleWifiRadio()
                }
            }
        }
    }

    ScriptModel {
        id: wiredConnectionsModel
        objectProp: "uuid"
        values: {
            const networks = NetworkService.wiredConnections;
            if (!networks)
                return [];
            let sorted = [...networks];
            sorted.sort((a, b) => {
                if (a.isActive && !b.isActive)
                    return -1;
                if (!a.isActive && b.isActive)
                    return 1;
                return a.id.localeCompare(b.id);
            });
            return sorted;
        }
    }

    DankFlickable {
        id: wiredContent
        anchors.top: headerRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingM
        anchors.topMargin: Theme.spacingM
        visible: currentPreferenceIndex === 0 && NetworkService.backend === "networkmanager" && DMSService.apiVersion > 10
        contentHeight: wiredColumn.height
        clip: true

        Column {
            id: wiredColumn
            width: parent.width
            spacing: Theme.spacingS

            Repeater {
                model: wiredConnectionsModel

                delegate: Rectangle {
                    id: wiredDelegate
                    required property var modelData
                    required property int index

                    readonly property bool isActive: modelData.isActive
                    readonly property string configName: modelData.id || I18n.tr("Unknown Config")

                    width: parent.width
                    height: wiredContentRow.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: wiredNetworkMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                    border.color: Theme.primary
                    border.width: 0

                    Row {
                        id: wiredContentRow
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "lan"
                            size: Theme.iconSize - 4
                            color: wiredDelegate.isActive ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 200

                            StyledText {
                                text: wiredDelegate.configName
                                font.pixelSize: Theme.fontSizeMedium
                                color: wiredDelegate.isActive ? Theme.primary : Theme.surfaceText
                                font.weight: wiredDelegate.isActive ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }

                    DankActionButton {
                        id: wiredOptionsButton
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "more_horiz"
                        buttonSize: 28
                        onClicked: {
                            if (wiredNetworkContextMenu.visible) {
                                wiredNetworkContextMenu.close();
                                return;
                            }
                            wiredNetworkContextMenu.currentID = modelData.id;
                            wiredNetworkContextMenu.currentUUID = modelData.uuid;
                            wiredNetworkContextMenu.currentConnected = wiredDelegate.isActive;
                            wiredNetworkContextMenu.popup(wiredOptionsButton, -wiredNetworkContextMenu.width + wiredOptionsButton.width, wiredOptionsButton.height + Theme.spacingXS);
                        }
                    }

                    DankRipple {
                        id: wiredRipple
                        cornerRadius: parent.radius
                    }

                    MouseArea {
                        id: wiredNetworkMouseArea
                        anchors.fill: parent
                        anchors.rightMargin: wiredOptionsButton.width + Theme.spacingS
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => wiredRipple.trigger(mouse.x, mouse.y)
                        onClicked: function (event) {
                            if (modelData.uuid !== NetworkService.ethernetConnectionUuid)
                                NetworkService.connectToSpecificWiredConfig(modelData.uuid);
                            event.accepted = true;
                        }
                    }
                }
            }
        }
    }

    Menu {
        id: wiredNetworkContextMenu
        width: 150
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        property string currentID: ""
        property string currentUUID: ""
        property bool currentConnected: false

        background: Rectangle {
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            radius: Theme.cornerRadius
            border.width: 0
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        }

        MenuItem {
            text: I18n.tr("Activate")
            height: !wiredNetworkContextMenu.currentConnected ? 32 : 0
            visible: !wiredNetworkContextMenu.currentConnected

            contentItem: StyledText {
                text: parent.text
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                leftPadding: Theme.spacingS
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: parent.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                radius: Theme.cornerRadius / 2
            }

            onTriggered: {
                if (!wiredNetworkContextMenu.currentConnected)
                    NetworkService.connectToSpecificWiredConfig(wiredNetworkContextMenu.currentUUID);
            }
        }

        MenuItem {
            text: I18n.tr("Disconnect")
            height: wiredNetworkContextMenu.currentConnected ? 32 : 0
            visible: wiredNetworkContextMenu.currentConnected

            contentItem: StyledText {
                text: parent.text
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.error
                leftPadding: Theme.spacingS
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: parent.hovered ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.08) : "transparent"
                radius: Theme.cornerRadius / 2
            }

            onTriggered: {
                NetworkService.toggleNetworkConnection("ethernet");
            }
        }

        MenuItem {
            text: I18n.tr("Network Info")
            height: wiredNetworkContextMenu.currentConnected ? 32 : 0
            visible: wiredNetworkContextMenu.currentConnected

            contentItem: StyledText {
                text: parent.text
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                leftPadding: Theme.spacingS
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: parent.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                radius: Theme.cornerRadius / 2
            }

            onTriggered: {
                const networkData = NetworkService.getWiredNetworkInfo(wiredNetworkContextMenu.currentUUID);
                networkWiredInfoModalLoader.active = true;
                networkWiredInfoModalLoader.item.showNetworkInfo(wiredNetworkContextMenu.currentID, networkData);
            }
        }
    }

    ScriptModel {
        id: wifiNetworksModel
        objectProp: "ssid"
        values: wifiContent.menuOpen ? wifiContent.frozenNetworks : wifiContent.sortedNetworks
    }

    Item {
        id: wifiScanningOverlay
        anchors.top: headerRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingM
        anchors.topMargin: Theme.spacingM
        visible: currentPreferenceIndex === 1 && NetworkService.wifiEnabled && !NetworkService.wifiToggling && NetworkService.wifiInterface && (NetworkService.wifiNetworks?.length ?? 0) < 1 && NetworkService.isScanning

        DankIcon {
            anchors.centerIn: parent
            name: "refresh"
            size: 48
            color: Qt.rgba(Theme.surfaceText.r || 0.8, Theme.surfaceText.g || 0.8, Theme.surfaceText.b || 0.8, 0.3)

            RotationAnimation on rotation {
                running: wifiScanningOverlay.visible
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 1000
            }
        }
    }

    DankListView {
        id: wifiContent
        anchors.top: headerRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingM
        anchors.topMargin: Theme.spacingM
        visible: currentPreferenceIndex === 1 && NetworkService.wifiEnabled && !NetworkService.wifiToggling && !wifiScanningOverlay.visible
        clip: true
        spacing: Theme.spacingS
        model: wifiNetworksModel

        property var frozenNetworks: []
        property bool menuOpen: false
        property var sortedNetworks: {
            const ssid = NetworkService.currentWifiSSID;
            const networks = NetworkService.wifiNetworks;
            const pinnedList = root.getPinnedNetworks();

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
        onSortedNetworksChanged: {
            if (!menuOpen)
                frozenNetworks = sortedNetworks;
        }
        onMenuOpenChanged: {
            if (menuOpen)
                frozenNetworks = sortedNetworks;
        }

        delegate: Rectangle {
            id: wifiDelegate
            required property var modelData
            required property int index

            readonly property bool isConnected: modelData.ssid === NetworkService.currentWifiSSID
            readonly property bool isPinned: root.getPinnedNetworks().includes(modelData.ssid)
            readonly property string networkName: modelData.ssid || I18n.tr("Unknown Network")
            readonly property int signalStrength: modelData.signal || 0

            width: wifiContent.width
            height: wifiContentRow.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: networkMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
            border.color: wifiDelegate.isConnected ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
            border.width: 0

            Row {
                id: wifiContentRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.spacingM
                spacing: Theme.spacingS

                DankIcon {
                    name: {
                        if (wifiDelegate.signalStrength >= 50)
                            return "wifi";
                        if (wifiDelegate.signalStrength >= 25)
                            return "wifi_2_bar";
                        return "wifi_1_bar";
                    }
                    size: Theme.iconSize - 4
                    color: wifiDelegate.isConnected ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 200

                    StyledText {
                        text: wifiDelegate.networkName
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        font.weight: wifiDelegate.isConnected ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Row {
                        spacing: Theme.spacingXS

                        StyledText {
                            text: wifiDelegate.isConnected ? I18n.tr("Connected") + " \u2022" : (modelData.secured ? I18n.tr("Secured") + " \u2022" : I18n.tr("Open") + " \u2022")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            text: modelData.saved ? I18n.tr("Saved") : ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            visible: text.length > 0
                        }

                        StyledText {
                            text: (modelData.saved ? "\u2022 " : "") + wifiDelegate.signalStrength + "%"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }
            }

            DankActionButton {
                id: optionsButton
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                iconName: "more_horiz"
                buttonSize: 28
                onClicked: {
                    if (networkContextMenu.visible) {
                        networkContextMenu.close();
                        return;
                    }
                    wifiContent.menuOpen = true;
                    networkContextMenu.currentSSID = modelData.ssid;
                    networkContextMenu.currentSecured = modelData.secured;
                    networkContextMenu.currentConnected = wifiDelegate.isConnected;
                    networkContextMenu.currentSaved = modelData.saved;
                    networkContextMenu.currentSignal = modelData.signal;
                    networkContextMenu.currentAutoconnect = modelData.autoconnect || false;
                    networkContextMenu.popup(optionsButton, -networkContextMenu.width + optionsButton.width, optionsButton.height + Theme.spacingXS);
                }
            }

            Rectangle {
                id: pinButton
                anchors.right: parent.right
                anchors.rightMargin: optionsButton.width + Theme.spacingM + Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                width: pinWifiRow.width + Theme.spacingS * 2
                height: pinWifiRow.implicitHeight + Theme.spacingXS * 2
                radius: height / 2
                color: wifiDelegate.isPinned ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Theme.withAlpha(Theme.surfaceText, 0.05)

                Row {
                    id: pinWifiRow
                    anchors.centerIn: parent
                    spacing: 4

                    DankIcon {
                        name: "push_pin"
                        size: 16
                        color: wifiDelegate.isPinned ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: wifiDelegate.isPinned ? I18n.tr("Pinned") : I18n.tr("Pin")
                        font.pixelSize: Theme.fontSizeSmall
                        color: wifiDelegate.isPinned ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                DankRipple {
                    id: pinRipple
                    cornerRadius: parent.radius
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => pinRipple.trigger(mouse.x, mouse.y)
                    onClicked: {
                        const pins = JSON.parse(JSON.stringify(SettingsData.wifiNetworkPins || {}));
                        let pinnedList = root.normalizePinList(pins["preferredWifi"]);
                        const pinIndex = pinnedList.indexOf(modelData.ssid);

                        if (pinIndex !== -1) {
                            pinnedList.splice(pinIndex, 1);
                        } else {
                            pinnedList.unshift(modelData.ssid);
                            if (pinnedList.length > root.maxPinnedNetworks)
                                pinnedList = pinnedList.slice(0, root.maxPinnedNetworks);
                        }

                        if (pinnedList.length > 0)
                            pins["preferredWifi"] = pinnedList;
                        else
                            delete pins["preferredWifi"];

                        SettingsData.set("wifiNetworkPins", pins);
                    }
                }
            }

            DankActionButton {
                id: qrCodeButton
                visible: modelData.secured && modelData.saved
                anchors.right: parent.right
                anchors.rightMargin: optionsButton.width + pinWifiRow.width + 3 * Theme.spacingM + Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                iconName: "qr_code"
                buttonSize: 28
                onClicked: {
                    PopoutService.showWifiQRCodeModal(modelData.ssid);
                }
            }

            DankRipple {
                id: wifiRipple
                cornerRadius: parent.radius
            }

            MouseArea {
                id: networkMouseArea
                anchors.fill: parent
                anchors.rightMargin: optionsButton.width + pinWifiRow.width + (qrCodeButton.visible ? qrCodeButton.width : 0) + Theme.spacingS * 5 + Theme.spacingM
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => wifiRipple.trigger(mouse.x, mouse.y)
                onClicked: function (event) {
                    if (wifiDelegate.isConnected) {
                        event.accepted = true;
                        return;
                    }
                    if (modelData.secured && !modelData.saved && DMSService.apiVersion < 7) {
                        PopoutService.showWifiPasswordModal(modelData.ssid);
                    } else {
                        NetworkService.connectToWifi(modelData.ssid);
                    }
                    event.accepted = true;
                }
            }
        }
    }

    Menu {
        id: networkContextMenu
        width: 150
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        property string currentSSID: ""
        property bool currentSecured: false
        property bool currentConnected: false
        property bool currentSaved: false
        property int currentSignal: 0
        property bool currentAutoconnect: false

        readonly property bool showSavedOptions: currentSaved || currentConnected

        onClosed: {
            wifiContent.menuOpen = false;
        }

        background: Rectangle {
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            radius: Theme.cornerRadius
            border.width: 0
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        }

        MenuItem {
            text: networkContextMenu.currentConnected ? I18n.tr("Disconnect") : I18n.tr("Connect")
            height: 32

            contentItem: StyledText {
                text: parent.text
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                leftPadding: Theme.spacingS
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: parent.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                radius: Theme.cornerRadius / 2
            }

            onTriggered: {
                if (networkContextMenu.currentConnected) {
                    NetworkService.disconnectWifi();
                    return;
                }
                if (networkContextMenu.currentSecured && !networkContextMenu.currentSaved && DMSService.apiVersion < 7) {
                    PopoutService.showWifiPasswordModal(networkContextMenu.currentSSID);
                    return;
                }
                NetworkService.connectToWifi(networkContextMenu.currentSSID);
            }
        }

        MenuItem {
            text: I18n.tr("Network Info")
            height: 32

            contentItem: StyledText {
                text: parent.text
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                leftPadding: Theme.spacingS
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: parent.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                radius: Theme.cornerRadius / 2
            }

            onTriggered: {
                const networkData = NetworkService.getNetworkInfo(networkContextMenu.currentSSID);
                networkInfoModalLoader.active = true;
                networkInfoModalLoader.item.showNetworkInfo(networkContextMenu.currentSSID, networkData);
            }
        }

        MenuItem {
            text: networkContextMenu.currentAutoconnect ? I18n.tr("Disable Autoconnect") : I18n.tr("Enable Autoconnect")
            height: networkContextMenu.showSavedOptions && DMSService.apiVersion > 13 ? 32 : 0
            visible: networkContextMenu.showSavedOptions && DMSService.apiVersion > 13

            contentItem: StyledText {
                text: parent.text
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                leftPadding: Theme.spacingS
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: parent.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                radius: Theme.cornerRadius / 2
            }

            onTriggered: {
                NetworkService.setWifiAutoconnect(networkContextMenu.currentSSID, !networkContextMenu.currentAutoconnect);
            }
        }

        MenuItem {
            text: I18n.tr("Forget Network")
            height: networkContextMenu.showSavedOptions ? 32 : 0
            visible: networkContextMenu.showSavedOptions

            contentItem: StyledText {
                text: parent.text
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.error
                leftPadding: Theme.spacingS
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: parent.hovered ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.08) : "transparent"
                radius: Theme.cornerRadius / 2
            }

            onTriggered: {
                NetworkService.forgetWifiNetwork(networkContextMenu.currentSSID);
            }
        }
    }

    Loader {
        id: networkInfoModalLoader
        active: false
        sourceComponent: NetworkInfoModal {}
    }

    Loader {
        id: networkWiredInfoModalLoader
        active: false
        sourceComponent: NetworkWiredInfoModal {}
    }
}
