import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import "../Common"
import "../Services"

PanelWindow {
    id: controlCenterPopup
        
        visible: root.controlCenterVisible
        
        implicitWidth: 600
        implicitHeight: 500
        
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        
        color: "transparent"
        
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        
        property int currentTab: 0 // 0: Network, 1: Audio, 2: Bluetooth, 3: Display
        property int networkSubTab: 0 // 0: Ethernet, 1: WiFi
        property bool nightModeEnabled: false
        
        Rectangle {
            width: Math.min(600, parent.width - Theme.spacingL * 2)
            height: Math.min(500, parent.height - Theme.barHeight - Theme.spacingS * 2)
            x: Math.max(Theme.spacingL, parent.width - width - Theme.spacingL)
            y: Theme.barHeight + Theme.spacingS
            color: Theme.surfaceContainer
            radius: Theme.cornerRadiusLarge
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
            border.width: 1
            
            opacity: root.controlCenterVisible ? 1.0 : 0.0
            scale: root.controlCenterVisible ? 1.0 : 0.85
            
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.mediumDuration
                    easing.type: Theme.emphasizedEasing
                }
            }
            
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.mediumDuration
                    easing.type: Theme.emphasizedEasing
                }
            }
            
            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM
                
                // Header with tabs
                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    
                    Row {
                        width: parent.width
                        height: 32
                        
                        Text {
                            text: "Control Center"
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Item { width: parent.width - 200; height: 1 }
                    }
                    
                    // Tab buttons
                    Row {
                        width: parent.width
                        spacing: Theme.spacingXS
                        
                        Repeater {
                            model: {
                                let tabs = [
                                    {name: "Network", icon: "wifi", id: "network", available: true}
                                ]
                                
                                // Always show audio
                                tabs.push({name: "Audio", icon: "volume_up", id: "audio", available: true})
                                
                                // Show Bluetooth only if available
                                if (root.bluetoothAvailable) {
                                    tabs.push({name: "Bluetooth", icon: "bluetooth", id: "bluetooth", available: true})
                                }
                                
                                // Always show display
                                tabs.push({name: "Display", icon: "brightness_6", id: "display", available: true})
                                
                                return tabs
                            }
                            
                            Rectangle {
                                property int tabCount: {
                                    let count = 3 // Network + Audio + Display (always visible)
                                    if (root.bluetoothAvailable) count++
                                    return count
                                }
                                width: (parent.width - Theme.spacingXS * (tabCount - 1)) / tabCount
                                height: 40
                                radius: Theme.cornerRadius
                                color: controlCenterPopup.currentTab === index ? 
                                       Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : 
                                       tabArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                                
                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS
                                    
                                    Text {
                                        text: modelData.icon
                                        font.family: Theme.iconFont
                                        font.pixelSize: Theme.iconSize - 4
                                        color: controlCenterPopup.currentTab === index ? Theme.primary : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    Text {
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: controlCenterPopup.currentTab === index ? Theme.primary : Theme.surfaceText
                                        font.weight: controlCenterPopup.currentTab === index ? Font.Medium : Font.Normal
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                
                                MouseArea {
                                    id: tabArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onClicked: {
                                        controlCenterPopup.currentTab = index
                                    }
                                }
                                
                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Tab content area
                Rectangle {
                    width: parent.width
                    height: parent.height - 120
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                    
                    // Network Tab
                    Item {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        visible: controlCenterPopup.currentTab === 0
                        
                        Column {
                            anchors.fill: parent
                            spacing: Theme.spacingM
                            
                            // Network sub-tabs
                            Row {
                                width: parent.width
                                spacing: Theme.spacingXS
                                
                                Rectangle {
                                    width: (parent.width - Theme.spacingXS) / 2
                                    height: 36
                                    radius: Theme.cornerRadiusSmall
                                    color: controlCenterPopup.networkSubTab === 0 ? 
                                           Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : 
                                           ethernetTabArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                                    
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingXS
                                        
                                        Text {
                                            text: "lan"
                                            font.family: Theme.iconFont
                                            font.pixelSize: Theme.iconSize - 4
                                            color: controlCenterPopup.networkSubTab === 0 ? Theme.primary : Theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        
                                        Text {
                                            text: "Ethernet"
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: controlCenterPopup.networkSubTab === 0 ? Theme.primary : Theme.surfaceText
                                            font.weight: controlCenterPopup.networkSubTab === 0 ? Font.Medium : Font.Normal
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    
                                    MouseArea {
                                        id: ethernetTabArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            controlCenterPopup.networkSubTab = 0
                                            // Disable auto-refresh when switching to ethernet tab
                                            root.wifiAutoRefreshEnabled = false
                                        }
                                    }
                                }
                                
                                Rectangle {
                                    width: (parent.width - Theme.spacingXS) / 2
                                    height: 36
                                    radius: Theme.cornerRadiusSmall
                                    color: controlCenterPopup.networkSubTab === 1 ? 
                                           Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : 
                                           wifiTabArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                                    
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingXS
                                        
                                        Text {
                                            text: root.wifiEnabled ? "wifi" : "wifi_off"
                                            font.family: Theme.iconFont
                                            font.pixelSize: Theme.iconSize - 4
                                            color: controlCenterPopup.networkSubTab === 1 ? Theme.primary : Theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        
                                        Text {
                                            text: "Wi-Fi"
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: controlCenterPopup.networkSubTab === 1 ? Theme.primary : Theme.surfaceText
                                            font.weight: controlCenterPopup.networkSubTab === 1 ? Font.Medium : Font.Normal
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    
                                    MouseArea {
                                        id: wifiTabArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            controlCenterPopup.networkSubTab = 1
                                            // Enable auto-refresh and scan for WiFi networks when switching to WiFi tab
                                            root.wifiAutoRefreshEnabled = true
                                            WifiService.scanWifi()
                                        }
                                    }
                                }
                            }
                            
                            // Ethernet Tab Content
                            ScrollView {
                                width: parent.width
                                height: parent.height - 48
                                visible: controlCenterPopup.networkSubTab === 0
                                clip: true
                                
                                Column {
                                    width: parent.width
                                    spacing: Theme.spacingL
                                    
                                    // Ethernet status card
                                    Rectangle {
                                        width: parent.width
                                        height: 100
                                        radius: Theme.cornerRadius
                                        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                                        border.color: root.networkStatus === "ethernet" ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                        border.width: root.networkStatus === "ethernet" ? 2 : 1
                                        
                                        Column {
                                            anchors.centerIn: parent
                                            spacing: Theme.spacingS
                                            
                                            Row {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: Theme.spacingM
                                                
                                                Text {
                                                    text: "lan"
                                                    font.family: Theme.iconFont
                                                    font.pixelSize: Theme.iconSizeLarge
                                                    color: root.networkStatus === "ethernet" ? Theme.primary : Theme.surfaceText
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                
                                                Column {
                                                    spacing: 2
                                                    
                                                    Text {
                                                        text: "Ethernet"
                                                        font.pixelSize: Theme.fontSizeLarge
                                                        color: root.networkStatus === "ethernet" ? Theme.primary : Theme.surfaceText
                                                        font.weight: Font.Medium
                                                    }
                                                    
                                                    Text {
                                                        text: root.networkStatus === "ethernet" ? "Connected" : "Disconnected"
                                                        font.pixelSize: Theme.fontSizeMedium
                                                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Ethernet control button
                                    Rectangle {
                                        width: parent.width
                                        height: 50
                                        radius: Theme.cornerRadius
                                        color: ethernetControlArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                                        
                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: Theme.spacingM
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: Theme.spacingM
                                            
                                            Text {
                                                text: root.networkStatus === "ethernet" ? "link_off" : "link"
                                                font.family: Theme.iconFont
                                                font.pixelSize: Theme.iconSize
                                                color: root.networkStatus === "ethernet" ? Theme.error : Theme.primary
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            
                                            Text {
                                                text: root.networkStatus === "ethernet" ? "Disconnect Ethernet" : "Connect Ethernet"
                                                font.pixelSize: Theme.fontSizeMedium
                                                color: Theme.surfaceText
                                                font.weight: Font.Medium
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                        
                                        MouseArea {
                                            id: ethernetControlArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                NetworkService.toggleNetworkConnection("ethernet")
                                            }
                                        }
                                    }
                                    
                                    // Ethernet details
                                    Column {
                                        width: parent.width
                                        spacing: Theme.spacingM
                                        visible: root.networkStatus === "ethernet"
                                        
                                        Text {
                                            text: "Connection Details"
                                            font.pixelSize: Theme.fontSizeLarge
                                            color: Theme.surfaceText
                                            font.weight: Font.Medium
                                        }
                                        
                                        Rectangle {
                                            width: parent.width
                                            height: 50
                                            radius: Theme.cornerRadiusSmall
                                            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                                            
                                            Row {
                                                anchors.left: parent.left
                                                anchors.leftMargin: Theme.spacingM
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: Theme.spacingM
                                                
                                                Text {
                                                    text: "language"
                                                    font.family: Theme.iconFont
                                                    font.pixelSize: Theme.iconSize
                                                    color: Theme.surfaceText
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                
                                                Column {
                                                    spacing: 2
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    
                                                    Text {
                                                        text: "IP Address"
                                                        font.pixelSize: Theme.fontSizeMedium
                                                        color: Theme.surfaceText
                                                        font.weight: Font.Medium
                                                    }
                                                    
                                                    Text {
                                                        text: root.ethernetIP || "192.168.1.100"
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // WiFi Tab Content
                            ScrollView {
                                width: parent.width
                                height: parent.height - 48
                                visible: controlCenterPopup.networkSubTab === 1
                                clip: true
                                
                                Column {
                                    width: parent.width
                                    spacing: Theme.spacingL
                                    
                                    // WiFi toggle control (only show if WiFi hardware is available)
                                    Rectangle {
                                        width: parent.width
                                        height: 50
                                        radius: Theme.cornerRadius
                                        color: wifiToggleArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                                        visible: root.wifiAvailable
                                        
                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: Theme.spacingM
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: Theme.spacingM
                                            
                                            Text {
                                                text: "power_settings_new"
                                                font.family: Theme.iconFont
                                                font.pixelSize: Theme.iconSize
                                                color: root.wifiEnabled ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            
                                            Text {
                                                text: root.wifiEnabled ? "Turn WiFi Off" : "Turn WiFi On"
                                                font.pixelSize: Theme.fontSizeMedium
                                                color: Theme.surfaceText
                                                font.weight: Font.Medium
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                        
                                        MouseArea {
                                            id: wifiToggleArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                NetworkService.toggleWifiRadio()
                                            }
                                        }
                                    }
                                    
                                    // Current WiFi connection (if connected)
                                    Rectangle {
                                        width: parent.width
                                        height: 80
                                        radius: Theme.cornerRadius
                                        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                                        border.color: root.networkStatus === "wifi" ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                                        border.width: root.networkStatus === "wifi" ? 2 : 1
                                        visible: root.wifiAvailable && root.wifiEnabled
                                        
                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: Theme.spacingL
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: Theme.spacingM
                                            
                                            Text {
                                                text: root.networkStatus === "wifi" ? 
                                                    (root.wifiSignalStrength === "excellent" ? "wifi" :
                                                     root.wifiSignalStrength === "good" ? "wifi_2_bar" :
                                                     root.wifiSignalStrength === "fair" ? "wifi_1_bar" :
                                                     root.wifiSignalStrength === "poor" ? "wifi_calling_3" : "wifi") : "wifi"
                                                font.family: Theme.iconFont
                                                font.pixelSize: Theme.iconSizeLarge
                                                color: root.networkStatus === "wifi" ? Theme.primary : Theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            
                                            Column {
                                                spacing: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                
                                                Text {
                                                    text: root.networkStatus === "wifi" ? (root.currentWifiSSID || "Connected") : "Not Connected"
                                                    font.pixelSize: Theme.fontSizeLarge
                                                    color: root.networkStatus === "wifi" ? Theme.primary : Theme.surfaceText
                                                    font.weight: Font.Medium
                                                }
                                                
                                                Text {
                                                    text: root.networkStatus === "wifi" ? (root.wifiIP || "Connected") : "Select a network below"
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Available WiFi Networks
                                    Column {
                                        width: parent.width
                                        spacing: Theme.spacingM
                                        visible: root.wifiEnabled
                                        
                                        Row {
                                            width: parent.width
                                            
                                            Text {
                                                text: "Available Networks"
                                                font.pixelSize: Theme.fontSizeLarge
                                                color: Theme.surfaceText
                                                font.weight: Font.Medium
                                            }
                                            
                                            Item { width: parent.width - 200; height: 1 }
                                            
                                            Rectangle {
                                                width: 32
                                                height: 32
                                                radius: 16
                                                color: refreshArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "refresh"
                                                    font.family: Theme.iconFont
                                                    font.pixelSize: Theme.iconSize - 4
                                                    color: Theme.surfaceText
                                                }
                                                
                                                MouseArea {
                                                    id: refreshArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        WifiService.scanWifi()
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Connection status indicator
                                        Rectangle {
                                            width: parent.width
                                            height: 40
                                            radius: Theme.cornerRadius
                                            color: {
                                                if (root.wifiConnectionStatus === "connecting") {
                                                    return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
                                                } else if (root.wifiConnectionStatus === "failed") {
                                                    return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                                                } else if (root.wifiConnectionStatus === "connected") {
                                                    return Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.12)
                                                }
                                                return "transparent"
                                            }
                                            border.color: {
                                                if (root.wifiConnectionStatus === "connecting") {
                                                    return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.3)
                                                } else if (root.wifiConnectionStatus === "failed") {
                                                    return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.3)
                                                } else if (root.wifiConnectionStatus === "connected") {
                                                    return Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.3)
                                                }
                                                return "transparent"
                                            }
                                            border.width: root.wifiConnectionStatus !== "" ? 1 : 0
                                            visible: root.wifiConnectionStatus !== ""
                                            
                                            Row {
                                                anchors.centerIn: parent
                                                spacing: Theme.spacingS
                                                
                                                Text {
                                                    text: {
                                                        if (root.wifiConnectionStatus === "connecting") return "sync"
                                                        if (root.wifiConnectionStatus === "failed") return "error"
                                                        if (root.wifiConnectionStatus === "connected") return "check_circle"
                                                        return ""
                                                    }
                                                    font.family: Theme.iconFont
                                                    font.pixelSize: Theme.iconSize - 6
                                                    color: {
                                                        if (root.wifiConnectionStatus === "connecting") return Theme.warning
                                                        if (root.wifiConnectionStatus === "failed") return Theme.error
                                                        if (root.wifiConnectionStatus === "connected") return Theme.success
                                                        return Theme.surfaceText
                                                    }
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    
                                                    RotationAnimation {
                                                        target: parent
                                                        running: root.wifiConnectionStatus === "connecting"
                                                        from: 0
                                                        to: 360
                                                        duration: 1000
                                                        loops: Animation.Infinite
                                                    }
                                                }
                                                
                                                Text {
                                                    text: {
                                                        if (root.wifiConnectionStatus === "connecting") return "Connecting to " + root.wifiPasswordSSID
                                                        if (root.wifiConnectionStatus === "failed") return "Failed to connect to " + root.wifiPasswordSSID
                                                        if (root.wifiConnectionStatus === "connected") return "Connected to " + root.wifiPasswordSSID
                                                        return ""
                                                    }
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    color: {
                                                        if (root.wifiConnectionStatus === "connecting") return Theme.warning
                                                        if (root.wifiConnectionStatus === "failed") return Theme.error
                                                        if (root.wifiConnectionStatus === "connected") return Theme.success
                                                        return Theme.surfaceText
                                                    }
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                            
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: Theme.shortDuration
                                                    easing.type: Theme.standardEasing
                                                }
                                            }
                                        }
                                        
                                        // WiFi networks list (only show if WiFi is available and enabled)
                                        Repeater {
                                            model: root.wifiAvailable && root.wifiEnabled ? root.wifiNetworks : []
                                            
                                            Rectangle {
                                                width: parent.width
                                                height: 50
                                                radius: Theme.cornerRadiusSmall
                                                color: networkArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : 
                                                       modelData.connected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                                                border.color: modelData.connected ? Theme.primary : "transparent"
                                                border.width: modelData.connected ? 1 : 0
                                                
                                                Item {
                                                    anchors.fill: parent
                                                    anchors.margins: Theme.spacingM
                                                    
                                                    // Signal strength icon
                                                    Text {
                                                        id: signalIcon
                                                        anchors.left: parent.left
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: modelData.signalStrength === "excellent" ? "wifi" :
                                                              modelData.signalStrength === "good" ? "wifi_2_bar" :
                                                              modelData.signalStrength === "fair" ? "wifi_1_bar" :
                                                              modelData.signalStrength === "poor" ? "wifi_calling_3" : "wifi"
                                                        font.family: Theme.iconFont
                                                        font.pixelSize: Theme.iconSize
                                                        color: modelData.connected ? Theme.primary : Theme.surfaceText
                                                    }
                                                    
                                                    // Network info
                                                    Column {
                                                        anchors.left: signalIcon.right
                                                        anchors.leftMargin: Theme.spacingM
                                                        anchors.right: rightIcons.left
                                                        anchors.rightMargin: Theme.spacingM
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 2
                                                        
                                                        Text {
                                                            width: parent.width
                                                            text: modelData.ssid
                                                            font.pixelSize: Theme.fontSizeMedium
                                                            color: modelData.connected ? Theme.primary : Theme.surfaceText
                                                            font.weight: modelData.connected ? Font.Medium : Font.Normal
                                                            elide: Text.ElideRight
                                                        }
                                                        
                                                        Text {
                                                            width: parent.width
                                                            text: {
                                                                if (modelData.connected) return "Connected"
                                                                if (modelData.saved) return "Saved" + (modelData.secured ? " • Secured" : " • Open")
                                                                return modelData.secured ? "Secured" : "Open"
                                                            }
                                                            font.pixelSize: Theme.fontSizeSmall
                                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                                            elide: Text.ElideRight
                                                        }
                                                    }
                                                    
                                                    // Right side icons
                                                    Row {
                                                        id: rightIcons
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: Theme.spacingXS
                                                        
                                                        // Lock icon (if secured)
                                                        Text {
                                                            text: "lock"
                                                            font.family: Theme.iconFont
                                                            font.pixelSize: Theme.iconSize - 6
                                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                                            visible: modelData.secured
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                        
                                                        // Forget button (for saved networks)
                                                        Rectangle {
                                                            width: 28
                                                            height: 28
                                                            radius: 14
                                                            color: forgetArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) : "transparent"
                                                            visible: modelData.saved || modelData.connected
                                                            
                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: "delete"
                                                                font.family: Theme.iconFont
                                                                font.pixelSize: Theme.iconSize - 6
                                                                color: forgetArea.containsMouse ? Theme.error : Theme.surfaceText
                                                            }
                                                            
                                                            MouseArea {
                                                                id: forgetArea
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    WifiService.forgetWifiNetwork(modelData.ssid)
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                                MouseArea {
                                                    id: networkArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (modelData.connected) {
                                                            // Already connected, do nothing or show info
                                                            return
                                                        }
                                                        
                                                        if (modelData.saved) {
                                                            // Saved network, connect directly
                                                            WifiService.connectToWifi(modelData.ssid)
                                                        } else if (modelData.secured) {
                                                            // Secured network, need password
                                                            root.wifiPasswordSSID = modelData.ssid
                                                            root.wifiPasswordInput = ""
                                                            root.wifiPasswordDialogVisible = true
                                                        } else {
                                                            // Open network, connect directly
                                                            WifiService.connectToWifi(modelData.ssid)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    // WiFi disabled message
                                    Column {
                                        width: parent.width
                                        spacing: Theme.spacingM
                                        visible: !root.wifiEnabled
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "wifi_off"
                                            font.family: Theme.iconFont
                                            font.pixelSize: 48
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.3)
                                        }
                                        
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "WiFi is turned off"
                                            font.pixelSize: Theme.fontSizeLarge
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                        }
                                        
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "Turn on WiFi to see available networks"
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Audio Tab
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        visible: controlCenterPopup.currentTab === 1
                        clip: true
                        
                        Column {
                            width: parent.width
                            spacing: Theme.spacingL
                            
                            // Volume Control
                            Column {
                                width: parent.width
                                spacing: Theme.spacingM
                                
                                Text {
                                    text: "Volume"
                                    font.pixelSize: Theme.fontSizeLarge
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                }
                                
                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingM
                                    
                                    Text {
                                        text: "volume_down"
                                        font.family: Theme.iconFont
                                        font.pixelSize: Theme.iconSize
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    Rectangle {
                                        id: volumeSliderTrack
                                        width: parent.width - 80
                                        height: 8
                                        radius: 4
                                        color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        Rectangle {
                                            id: volumeSliderFill
                                            width: parent.width * (root.volumeLevel / 100)
                                            height: parent.height
                                            radius: parent.radius
                                            color: Theme.primary
                                            
                                            Behavior on width {
                                                NumberAnimation { duration: 100 }
                                            }
                                        }
                                        
                                        // Draggable handle
                                        Rectangle {
                                            id: volumeHandle
                                            width: 18
                                            height: 18
                                            radius: 9
                                            color: Theme.primary
                                            border.color: Qt.lighter(Theme.primary, 1.3)
                                            border.width: 2
                                            
                                            x: Math.max(0, Math.min(parent.width - width, volumeSliderFill.width - width/2))
                                            anchors.verticalCenter: parent.verticalCenter
                                            
                                            scale: volumeMouseArea.containsMouse || volumeMouseArea.pressed ? 1.2 : 1.0
                                            
                                            Behavior on scale {
                                                NumberAnimation { duration: 150 }
                                            }
                                        }
                                        
                                        MouseArea {
                                            id: volumeMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            
                                            onClicked: (mouse) => {
                                                let ratio = Math.max(0, Math.min(1, mouse.x / width))
                                                let newVolume = Math.round(ratio * 100)
                                                AudioService.setVolume(newVolume)
                                            }
                                            
                                            onPositionChanged: (mouse) => {
                                                if (pressed) {
                                                    let ratio = Math.max(0, Math.min(1, mouse.x / width))
                                                    let newVolume = Math.round(ratio * 100)
                                                    AudioService.setVolume(newVolume)
                                                }
                                            }
                                        }
                                    }
                                    
                                    Text {
                                        text: "volume_up"
                                        font.family: Theme.iconFont
                                        font.pixelSize: Theme.iconSize
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                
                                Text {
                                    text: root.volumeLevel + "%"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                            
                            // Output Devices
                            Column {
                                width: parent.width
                                spacing: Theme.spacingM
                                
                                Text {
                                    text: "Output Device"
                                    font.pixelSize: Theme.fontSizeLarge
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                }
                                
                                // Current device indicator
                                Rectangle {
                                    width: parent.width
                                    height: 35
                                    radius: Theme.cornerRadius
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                                    border.width: 1
                                    visible: root.currentAudioSink !== ""
                                    
                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.spacingM
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Theme.spacingS
                                        
                                        Text {
                                            text: "check_circle"
                                            font.family: Theme.iconFont
                                            font.pixelSize: Theme.iconSize - 4
                                            color: Theme.primary
                                        }
                                        
                                        Text {
                                            text: "Current: " + (function() {
                                                for (let sink of root.audioSinks) {
                                                    if (sink.name === root.currentAudioSink) {
                                                        return sink.displayName
                                                    }
                                                }
                                                return root.currentAudioSink
                                            })()
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: Theme.primary
                                            font.weight: Font.Medium
                                        }
                                    }
                                }
                                
                                // Real audio devices
                                Repeater {
                                    model: root.audioSinks
                                    
                                    Rectangle {
                                        width: parent.width
                                        height: 50
                                        radius: Theme.cornerRadius
                                        color: deviceArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : 
                                               (modelData.active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08))
                                        border.color: modelData.active ? Theme.primary : "transparent"
                                        border.width: 1
                                        
                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: Theme.spacingM
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: Theme.spacingM
                                            
                                            Text {
                                                text: {
                                                    if (modelData.name.includes("bluez")) return "headset"
                                                    else if (modelData.name.includes("hdmi")) return "tv"
                                                    else if (modelData.name.includes("usb")) return "headset"
                                                    else return "speaker"
                                                }
                                                font.family: Theme.iconFont
                                                font.pixelSize: Theme.iconSize
                                                color: modelData.active ? Theme.primary : Theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            
                                            Column {
                                                spacing: 2
                                                anchors.verticalCenter: parent.verticalCenter
                                                
                                                Text {
                                                    text: modelData.displayName
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    color: modelData.active ? Theme.primary : Theme.surfaceText
                                                    font.weight: modelData.active ? Font.Medium : Font.Normal
                                                }
                                                
                                                Text {
                                                    text: modelData.active ? "Selected" : ""
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.8)
                                                    visible: modelData.active
                                                }
                                            }
                                        }
                                        
                                        MouseArea {
                                            id: deviceArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            
                                            onClicked: {
                                                AudioService.setAudioSink(modelData.name)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Bluetooth Tab
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        visible: controlCenterPopup.currentTab === 2
                        clip: true
                        
                        Column {
                            width: parent.width
                            spacing: Theme.spacingL
                            
                            // Bluetooth toggle
                            Rectangle {
                                width: parent.width
                                height: 60
                                radius: Theme.cornerRadius
                                color: bluetoothToggle.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : 
                                       (root.bluetoothEnabled ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.12))
                                border.color: root.bluetoothEnabled ? Theme.primary : "transparent"
                                border.width: 2
                                
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingL
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingM
                                    
                                    Text {
                                        text: "bluetooth"
                                        font.family: Theme.iconFont
                                        font.pixelSize: Theme.iconSizeLarge
                                        color: root.bluetoothEnabled ? Theme.primary : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    Column {
                                        spacing: 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        Text {
                                            text: "Bluetooth"
                                            font.pixelSize: Theme.fontSizeLarge
                                            color: root.bluetoothEnabled ? Theme.primary : Theme.surfaceText
                                            font.weight: Font.Medium
                                        }
                                        
                                        Text {
                                            text: root.bluetoothEnabled ? "Enabled" : "Disabled"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                        }
                                    }
                                }
                                
                                MouseArea {
                                    id: bluetoothToggle
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onClicked: {
                                        BluetoothService.toggleBluetooth()
                                    }
                                }
                            }
                            
                            // Bluetooth devices (when enabled)
                            Column {
                                width: parent.width
                                spacing: Theme.spacingM
                                visible: root.bluetoothEnabled
                                
                                Text {
                                    text: "Paired Devices"
                                    font.pixelSize: Theme.fontSizeLarge
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                }
                                
                                // Real Bluetooth devices
                                Repeater {
                                    model: root.bluetoothDevices
                                    
                                    Rectangle {
                                        width: parent.width
                                        height: 60
                                        radius: Theme.cornerRadius
                                        color: btDeviceArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : 
                                               (modelData.connected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08))
                                        border.color: modelData.connected ? Theme.primary : "transparent"
                                        border.width: 1
                                        
                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: Theme.spacingM
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: Theme.spacingM
                                            
                                            Text {
                                                text: {
                                                    switch (modelData.type) {
                                                        case "headset": return "headset"
                                                        case "mouse": return "mouse"
                                                        case "keyboard": return "keyboard"
                                                        case "phone": return "smartphone"
                                                        default: return "bluetooth"
                                                    }
                                                }
                                                font.family: Theme.iconFont
                                                font.pixelSize: Theme.iconSize
                                                color: modelData.connected ? Theme.primary : Theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            
                                            Column {
                                                spacing: 2
                                                anchors.verticalCenter: parent.verticalCenter
                                                
                                                Text {
                                                    text: modelData.name
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    color: modelData.connected ? Theme.primary : Theme.surfaceText
                                                    font.weight: modelData.connected ? Font.Medium : Font.Normal
                                                }
                                                
                                                Row {
                                                    spacing: Theme.spacingXS
                                                    
                                                    Text {
                                                        text: modelData.connected ? "Connected" : "Disconnected"
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                                    }
                                                    
                                                    Text {
                                                        text: modelData.battery >= 0 ? "• " + modelData.battery + "%" : ""
                                                        font.pixelSize: Theme.fontSizeSmall
                                                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                                        visible: modelData.battery >= 0
                                                    }
                                                }
                                            }
                                        }
                                        
                                        MouseArea {
                                            id: btDeviceArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            
                                            onClicked: {
                                                BluetoothService.toggleBluetoothDevice(modelData.mac)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Display Tab
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        visible: controlCenterPopup.currentTab === 3
                        clip: true
                        
                        Column {
                            width: parent.width
                            spacing: Theme.spacingL
                            
                            // Brightness Control
                            Column {
                                width: parent.width
                                spacing: Theme.spacingM
                                visible: BrightnessService.brightnessAvailable
                                
                                Text {
                                    text: "Brightness"
                                    font.pixelSize: Theme.fontSizeLarge
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                }
                                
                                CustomSlider {
                                    width: parent.width
                                    value: BrightnessService.brightnessLevel
                                    leftIcon: "brightness_low"
                                    rightIcon: "brightness_high"
                                    enabled: BrightnessService.brightnessAvailable
                                    
                                    onSliderValueChanged: (newValue) => {
                                        BrightnessService.setBrightness(newValue)
                                    }
                                }
                            }
                            
                            // Display settings
                            Column {
                                width: parent.width
                                spacing: Theme.spacingM
                                
                                Text {
                                    text: "Display Settings"
                                    font.pixelSize: Theme.fontSizeLarge
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                }
                                
                                // Night mode toggle
                                Rectangle {
                                    width: parent.width
                                    height: 50
                                    radius: Theme.cornerRadius
                                    color: controlCenterPopup.nightModeEnabled ? 
                                        Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) :
                                        (nightModeToggle.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08))
                                    border.color: controlCenterPopup.nightModeEnabled ? Theme.primary : "transparent"
                                    border.width: controlCenterPopup.nightModeEnabled ? 1 : 0
                                    
                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.spacingM
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Theme.spacingM
                                        
                                        Text {
                                            text: controlCenterPopup.nightModeEnabled ? "nightlight" : "dark_mode"
                                            font.family: Theme.iconFont
                                            font.pixelSize: Theme.iconSize
                                            color: controlCenterPopup.nightModeEnabled ? Theme.primary : Theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        
                                        Text {
                                            text: "Night Mode" + (controlCenterPopup.nightModeEnabled ? " (On)" : "")
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: controlCenterPopup.nightModeEnabled ? Theme.primary : Theme.surfaceText
                                            font.weight: Font.Medium
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    
                                    MouseArea {
                                        id: nightModeToggle
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        
                                        onClicked: {
                                            if (controlCenterPopup.nightModeEnabled) {
                                                // Disable night mode - kill any running color temperature processes
                                                nightModeDisableProcess.running = true
                                                controlCenterPopup.nightModeEnabled = false
                                            } else {
                                                // Enable night mode using wlsunset or redshift
                                                nightModeEnableProcess.running = true
                                                controlCenterPopup.nightModeEnabled = true
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
    
    // Night mode processes
    Process {
        id: nightModeEnableProcess
        command: ["bash", "-c", "if command -v wlsunset > /dev/null; then pkill wlsunset; wlsunset -t 3000 & elif command -v redshift > /dev/null; then pkill redshift; redshift -P -O 3000 & else echo 'No night mode tool available'; fi"]
        running: false
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("Failed to enable night mode")
                controlCenterPopup.nightModeEnabled = false
            }
        }
    }
    
    Process {
        id: nightModeDisableProcess  
        command: ["bash", "-c", "pkill wlsunset; pkill redshift; if command -v wlsunset > /dev/null; then wlsunset -t 6500 -T 6500 & sleep 1; pkill wlsunset; elif command -v redshift > /dev/null; then redshift -P -O 6500; redshift -x; fi"]
        running: false
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("Failed to disable night mode")
            }
        }
    }
    
    // Click outside to close
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            root.controlCenterVisible = false
        }
    }
}
