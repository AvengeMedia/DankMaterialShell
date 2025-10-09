import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals

Rectangle {
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
    color: Theme.surfaceContainerHigh
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 0

    Component.onCompleted: {
        NetworkService.addRef()
    }

    Component.onDestruction: {
        NetworkService.removeRef()
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
            visible: NetworkService.ethernetConnected

            property int currentPreferenceIndex: {
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
        visible: NetworkService.wifiToggling
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
        visible: !NetworkService.wifiEnabled && !NetworkService.wifiToggling
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
        id: wifiContent
        anchors.top: headerRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingM
        anchors.topMargin: Theme.spacingM
        visible: NetworkService.wifiInterface && NetworkService.wifiEnabled && !NetworkService.wifiToggling
        contentHeight: wifiColumn.height
        clip: true
        
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
                model: sortedNetworks

                property var sortedNetworks: {
                    const ssid = NetworkService.currentWifiSSID
                    const networks = NetworkService.wifiNetworks
                    let sorted = [...networks]
                    sorted.sort((a, b) => {
                        if (a.ssid === ssid) return -1
                        if (b.ssid === ssid) return 1
                        return b.signal - a.signal
                    })
                    return sorted
                }
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: networkMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Theme.surfaceContainerHighest
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
                                    text: modelData.ssid === NetworkService.currentWifiSSID ? "Connected" : (modelData.secured ? "Secured" : "Open")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                                
                                StyledText {
                                    text: modelData.saved ? "• Saved" : ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.primary
                                    visible: text.length > 0
                                }
                                
                                StyledText {
                                    text: "• " + modelData.signal + "%"
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
                                networkContextMenu.currentSSID = modelData.ssid
                                networkContextMenu.currentSecured = modelData.secured
                                networkContextMenu.currentConnected = modelData.ssid === NetworkService.currentWifiSSID
                                networkContextMenu.currentSaved = modelData.saved
                                networkContextMenu.currentSignal = modelData.signal
                                networkContextMenu.popup(optionsButton, -networkContextMenu.width + optionsButton.width, optionsButton.height + Theme.spacingXS)
                            }
                        }
                    }
                    
                    MouseArea {
                        id: networkMouseArea
                        anchors.fill: parent
                        anchors.rightMargin: optionsButton.width + Theme.spacingS
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(event) {
                            if (modelData.ssid !== NetworkService.currentWifiSSID) {
                                if (modelData.secured && !modelData.saved) {
                                    wifiPasswordModal.show(modelData.ssid)
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
        
        background: Rectangle {
            color: Theme.popupBackground()
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
                        wifiPasswordModal.show(networkContextMenu.currentSSID)
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
    
    WifiPasswordModal {
        id: wifiPasswordModal
    }

    NetworkInfoModal {
        id: networkInfoModal
    }


}