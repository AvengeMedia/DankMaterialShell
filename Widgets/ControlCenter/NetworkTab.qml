import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import "../../Common"
import "../../Services"

Item {
    id: networkTab
    
    property int networkSubTab: 0 // 0: Ethernet, 1: WiFi
    
    // Expose properties that the parent needs to bind to
    property bool wifiAutoRefreshEnabled: false
    
    // These should be bound from parent
    property string networkStatus: ""
    property bool wifiAvailable: false
    property bool wifiEnabled: false
    property string ethernetIP: ""
    property string currentWifiSSID: ""
    property string wifiIP: ""
    property string wifiSignalStrength: ""
    property var wifiNetworks: []
    property string wifiConnectionStatus: ""
    property string wifiPasswordSSID: ""
    property string wifiPasswordInput: ""
    property bool wifiPasswordDialogVisible: false
    
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
                color: networkTab.networkSubTab === 0 ? 
                       Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : 
                       ethernetTabArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                
                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS
                    
                    Text {
                        text: "lan"
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSize - 4
                        color: networkTab.networkSubTab === 0 ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Text {
                        text: "Ethernet"
                        font.pixelSize: Theme.fontSizeMedium
                        color: networkTab.networkSubTab === 0 ? Theme.primary : Theme.surfaceText
                        font.weight: networkTab.networkSubTab === 0 ? Font.Medium : Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                MouseArea {
                    id: ethernetTabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        networkTab.networkSubTab = 0
                        networkTab.wifiAutoRefreshEnabled = false
                    }
                }
            }
            
            Rectangle {
                width: (parent.width - Theme.spacingXS) / 2
                height: 36
                radius: Theme.cornerRadiusSmall
                color: networkTab.networkSubTab === 1 ? 
                       Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : 
                       wifiTabArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                
                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS
                    
                    Text {
                        text: networkTab.wifiEnabled ? "wifi" : "wifi_off"
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSize - 4
                        color: networkTab.networkSubTab === 1 ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Text {
                        text: "Wi-Fi"
                        font.pixelSize: Theme.fontSizeMedium
                        color: networkTab.networkSubTab === 1 ? Theme.primary : Theme.surfaceText
                        font.weight: networkTab.networkSubTab === 1 ? Font.Medium : Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                MouseArea {
                    id: wifiTabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        networkTab.networkSubTab = 1
                        networkTab.wifiAutoRefreshEnabled = true
                        WifiService.scanWifi()
                    }
                }
            }
        }
        
        // Ethernet Tab Content
        ScrollView {
            width: parent.width
            height: parent.height - 48
            visible: networkTab.networkSubTab === 0
            clip: true
            
            Column {
                width: parent.width
                spacing: Theme.spacingL
                
                // Ethernet status card
                Rectangle {
                    width: parent.width
                    height: 60
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.3)
                    border.color: networkTab.networkStatus === "ethernet" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : "transparent"
                    border.width: networkTab.networkStatus === "ethernet" ? 1 : 0
                    
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM
                        
                        Text {
                            text: "lan"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            color: networkTab.networkStatus === "ethernet" ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Column {
                            spacing: 2
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                text: "Ethernet"
                                font.pixelSize: Theme.fontSizeMedium
                                color: networkTab.networkStatus === "ethernet" ? Theme.primary : Theme.surfaceText
                                font.weight: Font.Medium
                            }
                            
                            Text {
                                text: networkTab.networkStatus === "ethernet" ? "Connected" : "Disconnected"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
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
                            text: networkTab.networkStatus === "ethernet" ? "link_off" : "link"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            color: networkTab.networkStatus === "ethernet" ? Theme.error : Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: networkTab.networkStatus === "ethernet" ? "Disconnect Ethernet" : "Connect Ethernet"
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
                    visible: networkTab.networkStatus === "ethernet"
                    
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
                                    text: networkTab.ethernetIP || "192.168.1.100"
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
            visible: networkTab.networkSubTab === 1
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
                    visible: networkTab.wifiAvailable
                    
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM
                        
                        Text {
                            text: "power_settings_new"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            color: networkTab.wifiEnabled ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: networkTab.wifiEnabled ? "Turn WiFi Off" : "Turn WiFi On"
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
                    border.color: networkTab.networkStatus === "wifi" ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: networkTab.networkStatus === "wifi" ? 2 : 1
                    visible: networkTab.wifiAvailable && networkTab.wifiEnabled
                    
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingL
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM
                        
                        Text {
                            text: networkTab.networkStatus === "wifi" ? 
                                (networkTab.wifiSignalStrength === "excellent" ? "wifi" :
                                 networkTab.wifiSignalStrength === "good" ? "wifi_2_bar" :
                                 networkTab.wifiSignalStrength === "fair" ? "wifi_1_bar" :
                                 networkTab.wifiSignalStrength === "poor" ? "wifi_calling_3" : "wifi") : "wifi"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSizeLarge
                            color: networkTab.networkStatus === "wifi" ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Column {
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                text: networkTab.networkStatus === "wifi" ? (networkTab.currentWifiSSID || "Connected") : "Not Connected"
                                font.pixelSize: Theme.fontSizeLarge
                                color: networkTab.networkStatus === "wifi" ? Theme.primary : Theme.surfaceText
                                font.weight: Font.Medium
                            }
                            
                            Text {
                                text: networkTab.networkStatus === "wifi" ? (networkTab.wifiIP || "Connected") : "Select a network below"
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
                    visible: networkTab.wifiEnabled
                    
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
                            if (networkTab.wifiConnectionStatus === "connecting") {
                                return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
                            } else if (networkTab.wifiConnectionStatus === "failed") {
                                return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                            } else if (networkTab.wifiConnectionStatus === "connected") {
                                return Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.12)
                            }
                            return "transparent"
                        }
                        border.color: {
                            if (networkTab.wifiConnectionStatus === "connecting") {
                                return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.3)
                            } else if (networkTab.wifiConnectionStatus === "failed") {
                                return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.3)
                            } else if (networkTab.wifiConnectionStatus === "connected") {
                                return Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.3)
                            }
                            return "transparent"
                        }
                        border.width: networkTab.wifiConnectionStatus !== "" ? 1 : 0
                        visible: networkTab.wifiConnectionStatus !== ""
                        
                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS
                            
                            Text {
                                text: {
                                    if (networkTab.wifiConnectionStatus === "connecting") return "sync"
                                    if (networkTab.wifiConnectionStatus === "failed") return "error"
                                    if (networkTab.wifiConnectionStatus === "connected") return "check_circle"
                                    return ""
                                }
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.iconSize - 6
                                color: {
                                    if (networkTab.wifiConnectionStatus === "connecting") return Theme.warning
                                    if (networkTab.wifiConnectionStatus === "failed") return Theme.error
                                    if (networkTab.wifiConnectionStatus === "connected") return Theme.success
                                    return Theme.surfaceText
                                }
                                anchors.verticalCenter: parent.verticalCenter
                                
                                RotationAnimation {
                                    target: parent
                                    running: networkTab.wifiConnectionStatus === "connecting"
                                    from: 0
                                    to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                }
                            }
                            
                            Text {
                                text: {
                                    if (networkTab.wifiConnectionStatus === "connecting") return "Connecting to " + networkTab.wifiPasswordSSID
                                    if (networkTab.wifiConnectionStatus === "failed") return "Failed to connect to " + networkTab.wifiPasswordSSID
                                    if (networkTab.wifiConnectionStatus === "connected") return "Connected to " + networkTab.wifiPasswordSSID
                                    return ""
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                color: {
                                    if (networkTab.wifiConnectionStatus === "connecting") return Theme.warning
                                    if (networkTab.wifiConnectionStatus === "failed") return Theme.error
                                    if (networkTab.wifiConnectionStatus === "connected") return Theme.success
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
                        model: networkTab.wifiAvailable && networkTab.wifiEnabled ? networkTab.wifiNetworks : []
                        
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
                                        networkTab.wifiPasswordSSID = modelData.ssid
                                        networkTab.wifiPasswordInput = ""
                                        networkTab.wifiPasswordDialogVisible = true
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
                    visible: !networkTab.wifiEnabled
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