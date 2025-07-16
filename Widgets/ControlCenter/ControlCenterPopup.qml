import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import qs.Common
import qs.Services

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
    
    property string currentTab: "network" // "network", "audio", "bluetooth", "display"
    property bool powerOptionsExpanded: false
    
    Rectangle {
        width: Math.min(600, parent.width - Theme.spacingL * 2)
        height: controlCenterPopup.powerOptionsExpanded ? 570 : 500
        x: Math.max(Theme.spacingL, parent.width - width - Theme.spacingL)
        y: Theme.barHeight + Theme.spacingXS
        color: Theme.popupBackground()
        radius: Theme.cornerRadiusLarge
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1
        
        // TopBar dropdown animation - optimized for performance
        transform: [
            Scale {
                id: scaleTransform
                origin.x: parent.width  // Scale from top-right corner
                origin.y: 0
                xScale: root.controlCenterVisible ? 1.0 : 0.95
                yScale: root.controlCenterVisible ? 1.0 : 0.8
            },
            Translate {
                id: translateTransform
                x: root.controlCenterVisible ? 0 : 15  // Slide slightly left when hidden
                y: root.controlCenterVisible ? 0 : -30
            }
        ]
        
        // Single coordinated animation for better performance
        states: [
            State {
                name: "visible"
                when: root.controlCenterVisible
                PropertyChanges { target: scaleTransform; xScale: 1.0; yScale: 1.0 }
                PropertyChanges { target: translateTransform; x: 0; y: 0 }
            },
            State {
                name: "hidden"
                when: !root.controlCenterVisible
                PropertyChanges { target: scaleTransform; xScale: 0.95; yScale: 0.8 }
                PropertyChanges { target: translateTransform; x: 15; y: -30 }
            }
        ]
        
        // Power menu height animation
        Behavior on height {
            NumberAnimation {
                duration: Theme.shortDuration  // Faster for height changes
                easing.type: Theme.standardEasing
            }
        }
        
        transitions: [
            Transition {
                from: "*"; to: "*"
                ParallelAnimation {
                    NumberAnimation {
                        targets: [scaleTransform, translateTransform]
                        properties: "xScale,yScale,x,y"
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
            }
        ]
        
        opacity: root.controlCenterVisible ? 1.0 : 0.0
        
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }
                
        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM
            
            // Elegant User Header
            Column {
                width: parent.width
                spacing: Theme.spacingL
                
                Rectangle {
                    width: parent.width
                    height: 90
                    radius: Theme.cornerRadiusLarge
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.4)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                    border.width: 1
                    
                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingL
                        anchors.rightMargin: Theme.spacingL
                        spacing: Theme.spacingL
                        
                        // Profile Picture Container
                        Item {
                            id: avatarContainer
                            width: 64
                            height: 64

                            property bool hasImage: profileImageLoader.status === Image.Ready

                            // This rectangle provides the themed ring via its border.
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "transparent"
                                border.color: Theme.primary
                                border.width: 1 // The ring is 1px thick.
                                visible: parent.hasImage
                            }

                            // Hidden Image loader. Its only purpose is to load the texture.
                            Image {
                                id: profileImageLoader
                                source: {
                                    if (Prefs.profileImage === "") return ""
                                    if (Prefs.profileImage.startsWith("/")) {
                                        return "file://" + Prefs.profileImage
                                    }
                                    return Prefs.profileImage
                                }
                                smooth: true
                                asynchronous: true
                                mipmap: true
                                cache: true
                                visible: false // This item is never shown directly.
                            }

                            MultiEffect {
                                anchors.fill: parent
                                anchors.margins: 5
                                source: profileImageLoader
                                maskEnabled: true
                                maskSource: circularMask
                                visible: avatarContainer.hasImage
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1.0
                            }

                            Item {
                                id: circularMask
                                width: 64 - 10
                                height: 64 - 10
                                layer.enabled: true
                                layer.smooth: true
                                visible: false

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "black"
                                    antialiasing: true
                                }
                            }

                            // Fallback for when there is no image.
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Theme.primary
                                visible: !parent.hasImage

                                Text {
                                    anchors.centerIn: parent
                                    text: "person"
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize + 8
                                    color: Theme.primaryText
                                }
                            }

                            // Error icon for when the image fails to load.
                            Text {
                                anchors.centerIn: parent
                                text: "warning"
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.iconSize + 8
                                color: Theme.primaryText
                                visible: Prefs.profileImage !== "" && profileImageLoader.status === Image.Error
                            }
                        }
                        
                        // User Info Text
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS
                            
                            
                            Text {
                                text: UserInfoService.fullName || UserInfoService.username || "User"
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }
                            
                            Text {
                                text: "Uptime: " + (UserInfoService.uptime || "Unknown")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                font.weight: Font.Normal
                            }
                        }
                    }
                    
                    // Action Buttons - Power and Settings
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: Theme.spacingL
                        spacing: Theme.spacingS
                        
                        // Power Button
                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            color: powerButton.containsMouse || controlCenterPopup.powerOptionsExpanded ? 
                                   Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) :
                                   Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                            
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.height
                                radius: parent.radius
                                color: "transparent"
                                clip: true
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: controlCenterPopup.powerOptionsExpanded ? "expand_less" : "power_settings_new"
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize - 2
                                    color: powerButton.containsMouse || controlCenterPopup.powerOptionsExpanded ? Theme.error : Theme.surfaceText
                                    
                                    Behavior on text {
                                        // Smooth icon transition
                                        SequentialAnimation {
                                            NumberAnimation {
                                                target: parent
                                                property: "opacity"
                                                to: 0.0
                                                duration: Theme.shortDuration / 2
                                                easing.type: Theme.standardEasing
                                            }
                                            PropertyAction { target: parent; property: "text" }
                                            NumberAnimation {
                                                target: parent
                                                property: "opacity"
                                                to: 1.0
                                                duration: Theme.shortDuration / 2
                                                easing.type: Theme.standardEasing
                                            }
                                        }
                                    }
                                }
                            }
                            
                            MouseArea {
                                id: powerButton
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: {
                                    controlCenterPopup.powerOptionsExpanded = !controlCenterPopup.powerOptionsExpanded
                                }
                            }
                            
                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                        
                        // Settings Button
                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            color: settingsButton.containsMouse ? 
                                   Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) :
                                   Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                            
                            Text {
                                anchors.centerIn: parent
                                text: "settings"
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.iconSize - 2
                                color: Theme.surfaceText
                            }
                            
                            MouseArea {
                                id: settingsButton
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: {
                                    root.controlCenterVisible = false
                                    root.settingsVisible = true
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
                
                // Animated Collapsible Power Options (optimized)
                Rectangle {
                    width: parent.width
                    height: controlCenterPopup.powerOptionsExpanded ? 60 : 0
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.4)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                    border.width: controlCenterPopup.powerOptionsExpanded ? 1 : 0
                    opacity: controlCenterPopup.powerOptionsExpanded ? 1.0 : 0.0
                    clip: true
                    
                    // Single coordinated animation for power options
                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                    
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingL
                        visible: controlCenterPopup.powerOptionsExpanded
                        
                        // Logout
                        Rectangle {
                            width: 100
                            height: 34
                            radius: Theme.cornerRadius
                            color: logoutButton.containsMouse ? 
                                   Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12) :
                                   Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                            
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS
                                
                                Text {
                                    text: "logout"
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: logoutButton.containsMouse ? Theme.warning : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: "Logout"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: logoutButton.containsMouse ? Theme.warning : Theme.surfaceText
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            MouseArea {
                                id: logoutButton
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: {
                                    controlCenterPopup.powerOptionsExpanded = false
                                    root.powerConfirmAction = "logout"
                                    root.powerConfirmTitle = "Logout"
                                    root.powerConfirmMessage = "Are you sure you want to logout?"
                                    root.powerConfirmVisible = true
                                }
                            }
                            
                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                        
                        // Reboot
                        Rectangle {
                            width: 100
                            height: 34
                            radius: Theme.cornerRadius
                            color: rebootButton.containsMouse ? 
                                   Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12) :
                                   Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                            
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS
                                
                                Text {
                                    text: "restart_alt"
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: rebootButton.containsMouse ? Theme.warning : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: "Restart"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: rebootButton.containsMouse ? Theme.warning : Theme.surfaceText
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            MouseArea {
                                id: rebootButton
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: {
                                    controlCenterPopup.powerOptionsExpanded = false
                                    root.powerConfirmAction = "reboot"
                                    root.powerConfirmTitle = "Restart"
                                    root.powerConfirmMessage = "Are you sure you want to restart?"
                                    root.powerConfirmVisible = true
                                }
                            }
                            
                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                        
                        // Shutdown
                        Rectangle {
                            width: 100
                            height: 34
                            radius: Theme.cornerRadius
                            color: shutdownButton.containsMouse ? 
                                   Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) :
                                   Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                            
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS
                                
                                Text {
                                    text: "power_settings_new"
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: shutdownButton.containsMouse ? Theme.error : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: "Shutdown"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: shutdownButton.containsMouse ? Theme.error : Theme.surfaceText
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            MouseArea {
                                id: shutdownButton
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: {
                                    controlCenterPopup.powerOptionsExpanded = false
                                    root.powerConfirmAction = "poweroff"
                                    root.powerConfirmTitle = "Shutdown"
                                    root.powerConfirmMessage = "Are you sure you want to shutdown?"
                                    root.powerConfirmVisible = true
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
                            color: controlCenterPopup.currentTab === modelData.id ? 
                                   Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : 
                                   tabArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                            
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS
                                
                                Text {
                                    text: modelData.icon
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize - 4
                                    color: controlCenterPopup.currentTab === modelData.id ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: modelData.name
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: controlCenterPopup.currentTab === modelData.id ? Theme.primary : Theme.surfaceText
                                    font.weight: controlCenterPopup.currentTab === modelData.id ? Font.Medium : Font.Normal
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            MouseArea {
                                id: tabArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: {
                                    controlCenterPopup.currentTab = modelData.id
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
                height: controlCenterPopup.powerOptionsExpanded ? 240 : 300
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.1)
                
                Behavior on height {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
                
                // Network Tab
                NetworkTab {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    visible: controlCenterPopup.currentTab === "network"
                    
                    // Bind properties from root
                    networkStatus: root.networkStatus
                    wifiAvailable: root.wifiAvailable
                    wifiEnabled: root.wifiEnabled
                    wifiToggling: root.wifiToggling
                    ethernetIP: root.ethernetIP
                    ethernetInterface: root.ethernetInterface
                    ethernetConnected: root.ethernetConnected
                    currentWifiSSID: root.currentWifiSSID
                    wifiIP: root.wifiIP
                    wifiSignalStrength: root.wifiSignalStrength
                    wifiNetworks: root.wifiNetworks
                    wifiScanning: root.wifiScanning
                    wifiConnectionStatus: root.wifiConnectionStatus
                    wifiPasswordSSID: root.wifiPasswordSSID
                    wifiPasswordInput: root.wifiPasswordInput
                    wifiPasswordDialogVisible: root.wifiPasswordDialogVisible
                    changingNetworkPreference: root.changingNetworkPreference
                    
                    // Bind the auto-refresh flag
                    onWifiAutoRefreshEnabledChanged: {
                        root.wifiAutoRefreshEnabled = wifiAutoRefreshEnabled
                    }
                }
                
                // Audio Tab
                AudioTab {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    visible: controlCenterPopup.currentTab === "audio"
                }
                
                // Bluetooth Tab
                BluetoothTab {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    visible: root.bluetoothAvailable && controlCenterPopup.currentTab === "bluetooth"
                    
                    // Bind properties from root
                    bluetoothEnabled: root.bluetoothEnabled
                    bluetoothDevices: root.bluetoothDevices
                }
                
                // Display Tab
                DisplayTab {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    visible: controlCenterPopup.currentTab === "display"
                    
                }
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