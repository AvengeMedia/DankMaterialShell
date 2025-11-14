import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals

Rectangle {
    id: root

    implicitHeight: {
        if (NetworkService.wifiToggling) {
            return headerRow.height + wifiToggleContent.height + Theme.spacingM
        }
        if (NetworkService.wifiEnabled) {
            return headerRow.height + wifiContent.height + Theme.spacingM
        }
        return headerRow.height + wifiOffContent.height + Theme.spacingM
    }
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 0

    Component.onCompleted: {
        NetworkService.addRef()
    }

    Component.onDestruction: {
        NetworkService.removeRef()
    }

    property int currentPreferenceIndex: {
        if (DMSService.apiVersion < 5) {
            return 1
        }

        if (NetworkService.backend !== "networkmanager" || DMSService.apiVersion <= 10) {
            return 1
        }

        const pref = NetworkService.userPreference
        const status = NetworkService.networkStatus
        let index = 1

        if (pref === "ethernet") {
            index = 0
        } else if (pref === "wifi") {
            index = 1
        } else {
            index = status === "ethernet" ? 0 : 1
        }

        return index
    }

    Row {
        id: headerRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.topMargin: Theme.spacingS
        height: 40

        StyledText {
            id: headerText
            text: I18n.tr("Network Settings")
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.surfaceText
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            width: Math.max(0, parent.width - headerText.implicitWidth - preferenceControls.width - Theme.spacingM)
            height: parent.height
        }

        DankButtonGroup {
            id: preferenceControls
            anchors.verticalCenter: parent.verticalCenter
            visible: NetworkService.backend === "networkmanager" && DMSService.apiVersion > 10

            model: ["Ethernet", "WiFi"]
            currentIndex: currentPreferenceIndex
            selectionMode: "single"
            onSelectionChanged: (index, selected) => {
                if (!selected) return
                console.log("NetworkDetail: Setting preference to", index === 0 ? "ethernet" : "wifi")
                NetworkService.setNetworkPreference(index === 0 ? "ethernet" : "wifi")
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
        height: visible ? 80 : 0

        Column {
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
                text: NetworkService.wifiEnabled ? "Disabling WiFi..." : "Enabling WiFi..."
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
        height: visible ? 120 : 0

        Column {
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
                width: 120
                height: 36
                radius: 18
                color: enableWifiButton.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                border.width: 0
                border.color: Theme.primary

                StyledText {
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
                model: ScriptModel {
                    values: {
                        const currentUuid = NetworkService.ethernetConnectionUuid
                        const networks = NetworkService.wiredConnections
                        let sorted = [...networks]
                        sorted.sort((a, b) => {
                            if (a.isActive && !b.isActive) return -1
                            if (!a.isActive && b.isActive) return 1
                            return a.id.localeCompare(b.id)
                        })
                        return sorted
                    }
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: wiredNetworkMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                    border.color: Theme.primary
                    border.width: 0

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "lan"
                            size: Theme.iconSize - 4
                            color: modelData.isActive ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 200

                            StyledText {
                                text: modelData.id || "Unknown Config"
                                font.pixelSize: Theme.fontSizeMedium
                                color: modelData.isActive ? Theme.primary : Theme.surfaceText
                                font.weight: modelData.isActive ? Font.Medium : Font.Normal
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
                                wiredNetworkContextMenu.close()
                            } else {
                                wiredNetworkContextMenu.currentID = modelData.id
                                wiredNetworkContextMenu.currentUUID = modelData.uuid                               
                                wiredNetworkContextMenu.currentConnected = modelData.isActive
                                wiredNetworkContextMenu.popup(wiredOptionsButton, -wiredNetworkContextMenu.width + wiredOptionsButton.width, wiredOptionsButton.height + Theme.spacingXS)
                            }
                        }
                    }

                    MouseArea {
                        id: wiredNetworkMouseArea
                        anchors.fill: parent
                        anchors.rightMargin: wiredOptionsButton.width + Theme.spacingS
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(event) {
                            if (modelData.uuid !== NetworkService.ethernetConnectionUuid) {
                                NetworkService.connectToSpecificWiredConfig(modelData.uuid)
                            }
                            event.accepted = true
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
            text: "Activate"
            height: !wiredNetworkContextMenu.currentConnected ? 32 : 0

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
                if (!networkContextMenu.currentConnected) {
                    NetworkService.connectToSpecificWiredConfig(wiredNetworkContextMenu.currentUUID)
                }
            }
        }

        MenuItem {
            text: I18n.tr("Network Info")
            height: wiredNetworkContextMenu.currentConnected ? 32 : 0

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
                let networkData = NetworkService.getWiredNetworkInfo(wiredNetworkContextMenu.currentUUID)
                networkWiredInfoModal.showNetworkInfo(wiredNetworkContextMenu.currentID, networkData)
            }
        }
    }

    DankFlickable {
        id: wifiContent
        anchors.top: headerRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingM
        anchors.topMargin: Theme.spacingM
        visible: currentPreferenceIndex === 1 && NetworkService.wifiEnabled && !NetworkService.wifiToggling
        contentHeight: wifiColumn.height
        clip: true

        property var frozenNetworks: []
        property bool menuOpen: false

        Column {
            id: wifiColumn
            width: parent.width
            spacing: Theme.spacingS

            Item {
                width: parent.width
                height: 200
                visible: NetworkService.wifiInterface && NetworkService.wifiNetworks?.length < 1 && !NetworkService.wifiToggling && NetworkService.isScanning

                DankIcon {
                    anchors.centerIn: parent
                    name: "refresh"
                    size: 48
                    color: Qt.rgba(Theme.surfaceText.r || 0.8, Theme.surfaceText.g || 0.8, Theme.surfaceText.b || 0.8, 0.3)

                    RotationAnimation on rotation {
                        running: NetworkService.isScanning
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1000
                    }
                }
            }

            Repeater {
                model: ScriptModel {
                    values: {
                        const ssid = NetworkService.currentWifiSSID
                        const networks = NetworkService.wifiNetworks
                        const pins = SettingsData.wifiNetworkPins || {}
                        const pinnedSSID = pins["preferredWifi"]
                        
                        let sorted = [...networks]
                        sorted.sort((a, b) => {
                            // Pinned network first
                            if (a.ssid === pinnedSSID && b.ssid !== pinnedSSID) return -1
                            if (b.ssid === pinnedSSID && a.ssid !== pinnedSSID) return 1
                            // Then currently connected
                            if (a.ssid === ssid) return -1
                            if (b.ssid === ssid) return 1
                            // Then by signal strength
                            return b.signal - a.signal
                        })
                        if (!wifiContent.menuOpen) {
                            wifiContent.frozenNetworks = sorted
                        }
                        return wifiContent.menuOpen ? wifiContent.frozenNetworks : sorted
                    }
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: networkMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                    border.color: modelData.ssid === NetworkService.currentWifiSSID ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: 0

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        DankIcon {
                            name: {
                                let strength = modelData.signal || 0
                                if (strength >= 50) return "wifi"
                                if (strength >= 25) return "wifi_2_bar"
                                return "wifi_1_bar"
                            }
                            size: Theme.iconSize - 4
                            color: modelData.ssid === NetworkService.currentWifiSSID ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 200

                            StyledText {
                                text: modelData.ssid || "Unknown Network"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: modelData.ssid === NetworkService.currentWifiSSID ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Row {
                                spacing: Theme.spacingXS

                                StyledText {
                                    text: modelData.ssid === NetworkService.currentWifiSSID ? "Connected •" : (modelData.secured ? "Secured •" : "Open •")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }

                                StyledText {
                                    text: modelData.saved ? "Saved" : ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.primary
                                    visible: text.length > 0
                                }

                                StyledText {
                                    text: (modelData.saved ? "• " : "") + modelData.signal + "%"
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
                                networkContextMenu.close()
                            } else {
                                wifiContent.menuOpen = true
                                networkContextMenu.currentSSID = modelData.ssid
                                networkContextMenu.currentSecured = modelData.secured
                                networkContextMenu.currentConnected = modelData.ssid === NetworkService.currentWifiSSID
                                networkContextMenu.currentSaved = modelData.saved
                                networkContextMenu.currentSignal = modelData.signal
                                networkContextMenu.currentAutoconnect = modelData.autoconnect || false
                                networkContextMenu.popup(optionsButton, -networkContextMenu.width + optionsButton.width, optionsButton.height + Theme.spacingXS)
                            }
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: optionsButton.width + Theme.spacingM + Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        width: pinWifiRow.width + Theme.spacingS * 2
                        height: 28
                        radius: height / 2
                        color: {
                            const isThisNetworkPinned = (SettingsData.wifiNetworkPins || {})["preferredWifi"] === modelData.ssid
                            return isThisNetworkPinned ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Theme.withAlpha(Theme.surfaceText, 0.05)
                        }

                        Row {
                            id: pinWifiRow
                            anchors.centerIn: parent
                            spacing: 4

                            DankIcon {
                                name: "push_pin"
                                size: 16
                                color: {
                                    const isThisNetworkPinned = (SettingsData.wifiNetworkPins || {})["preferredWifi"] === modelData.ssid
                                    return isThisNetworkPinned ? Theme.primary : Theme.surfaceText
                                }
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: {
                                    const isThisNetworkPinned = (SettingsData.wifiNetworkPins || {})["preferredWifi"] === modelData.ssid
                                    return isThisNetworkPinned ? "Pinned" : "Pin"
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: {
                                    const isThisNetworkPinned = (SettingsData.wifiNetworkPins || {})["preferredWifi"] === modelData.ssid
                                    return isThisNetworkPinned ? Theme.primary : Theme.surfaceText
                                }
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const pins = JSON.parse(JSON.stringify(SettingsData.wifiNetworkPins || {}))
                                const isCurrentlyPinned = pins["preferredWifi"] === modelData.ssid
                                
                                if (isCurrentlyPinned) {
                                    delete pins["preferredWifi"]
                                } else {
                                    pins["preferredWifi"] = modelData.ssid
                                }
                                
                                SettingsData.set("wifiNetworkPins", pins)
                            }
                        }
                    }

                    MouseArea {
                        id: networkMouseArea
                        anchors.fill: parent
                        anchors.rightMargin: optionsButton.width + Theme.spacingM + Theme.spacingS + pinWifiRow.width + Theme.spacingS * 4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(event) {
                            if (modelData.ssid !== NetworkService.currentWifiSSID) {
                                if (modelData.secured && !modelData.saved) {
                                    if (DMSService.apiVersion >= 7) {
                                        NetworkService.connectToWifi(modelData.ssid)
                                    } else if (PopoutService.wifiPasswordModal) {
                                        PopoutService.wifiPasswordModal.show(modelData.ssid)
                                    }
                                } else {
                                    NetworkService.connectToWifi(modelData.ssid)
                                }
                            }
                            event.accepted = true
                        }
                    }

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

        onClosed: {
            wifiContent.menuOpen = false
        }

        background: Rectangle {
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            radius: Theme.cornerRadius
            border.width: 0
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        }

        MenuItem {
            text: networkContextMenu.currentConnected ? "Disconnect" : "Connect"
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
                    NetworkService.disconnectWifi()
                } else {
                    if (networkContextMenu.currentSecured && !networkContextMenu.currentSaved) {
                        if (DMSService.apiVersion >= 7) {
                            NetworkService.connectToWifi(networkContextMenu.currentSSID)
                        } else if (PopoutService.wifiPasswordModal) {
                            PopoutService.wifiPasswordModal.show(networkContextMenu.currentSSID)
                        }
                    } else {
                        NetworkService.connectToWifi(networkContextMenu.currentSSID)
                    }
                }
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
                let networkData = NetworkService.getNetworkInfo(networkContextMenu.currentSSID)
                networkInfoModal.showNetworkInfo(networkContextMenu.currentSSID, networkData)
            }
        }

        MenuItem {
            text: networkContextMenu.currentAutoconnect ? I18n.tr("Disable Autoconnect") : I18n.tr("Enable Autoconnect")
            height: (networkContextMenu.currentSaved || networkContextMenu.currentConnected) && DMSService.apiVersion > 13 ? 32 : 0
            visible: (networkContextMenu.currentSaved || networkContextMenu.currentConnected) && DMSService.apiVersion > 13

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
                NetworkService.setWifiAutoconnect(networkContextMenu.currentSSID, !networkContextMenu.currentAutoconnect)
            }
        }

        MenuItem {
            text: I18n.tr("Forget Network")
            height: networkContextMenu.currentSaved || networkContextMenu.currentConnected ? 32 : 0
            visible: networkContextMenu.currentSaved || networkContextMenu.currentConnected

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
                NetworkService.forgetWifiNetwork(networkContextMenu.currentSSID)
            }
        }
    }

    NetworkInfoModal {
        id: networkInfoModal
    }

    NetworkWiredInfoModal {
        id: networkWiredInfoModal
    }
}