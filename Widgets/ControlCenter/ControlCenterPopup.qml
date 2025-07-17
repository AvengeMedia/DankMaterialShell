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
    id: root
    
    property bool controlCenterVisible: false
        
    visible: controlCenterVisible
    
    onVisibleChanged: {
        // Enable/disable WiFi auto-refresh based on control center visibility
        WifiService.autoRefreshEnabled = visible && NetworkService.wifiEnabled
    }
    
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
        width: Math.min(600, Screen.width - Theme.spacingL * 2)
        height: root.powerOptionsExpanded ? 570 : 500
        x: Math.max(Theme.spacingL, Screen.width - width - Theme.spacingL)
        y: Theme.barHeight + Theme.spacingXS
        color: Theme.popupBackground()
        radius: Theme.cornerRadiusLarge
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1
        
        // TopBar dropdown animation - optimized for performance
        transform: [
            Scale {
                id: scaleTransform
                origin.x: 600  // Use fixed width since popup is max 600px wide
                origin.y: 0
                xScale: controlCenterVisible ? 1.0 : 0.95
                yScale: controlCenterVisible ? 1.0 : 0.8
            },
            Translate {
                id: translateTransform
                x: controlCenterVisible ? 0 : 15  // Slide slightly left when hidden
                y: controlCenterVisible ? 0 : -30
            }
        ]
        
        // Single coordinated animation for better performance
        states: [
            State {
                name: "visible"
                when: controlCenterVisible
                PropertyChanges { target: scaleTransform; xScale: 1.0; yScale: 1.0 }
                PropertyChanges { target: translateTransform; x: 0; y: 0 }
            },
            State {
                name: "hidden"
                when: !controlCenterVisible
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
        
        opacity: controlCenterVisible ? 1.0 : 0.0
        
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
                            color: powerButton.containsMouse || root.powerOptionsExpanded ? 
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
                                    text: root.powerOptionsExpanded ? "expand_less" : "power_settings_new"
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize - 2
                                    color: powerButton.containsMouse || root.powerOptionsExpanded ? Theme.error : Theme.surfaceText
                                    
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
                                    root.powerOptionsExpanded = !root.powerOptionsExpanded
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
                                    controlCenterVisible = false
                                    settingsPopup.settingsVisible = true
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
                    height: root.powerOptionsExpanded ? 60 : 0
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.4)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                    border.width: root.powerOptionsExpanded ? 1 : 0
                    opacity: root.powerOptionsExpanded ? 1.0 : 0.0
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
                        visible: root.powerOptionsExpanded
                        
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
                                    root.powerOptionsExpanded = false
                                    if (typeof root !== "undefined" && root.powerConfirmDialog) {
                                        root.powerConfirmDialog.powerConfirmAction = "logout"
                                        root.powerConfirmDialog.powerConfirmTitle = "Logout"
                                        root.powerConfirmDialog.powerConfirmMessage = "Are you sure you want to logout?"
                                        root.powerConfirmDialog.powerConfirmVisible = true
                                    }
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
                                    root.powerOptionsExpanded = false
                                    if (typeof root !== "undefined" && root.powerConfirmDialog) {
                                        root.powerConfirmDialog.powerConfirmAction = "reboot"
                                        root.powerConfirmDialog.powerConfirmTitle = "Restart"
                                        root.powerConfirmDialog.powerConfirmMessage = "Are you sure you want to restart?"
                                        root.powerConfirmDialog.powerConfirmVisible = true
                                    }
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
                                    root.powerOptionsExpanded = false
                                    if (typeof root !== "undefined" && root.powerConfirmDialog) {
                                        root.powerConfirmDialog.powerConfirmAction = "poweroff"
                                        root.powerConfirmDialog.powerConfirmTitle = "Shutdown"
                                        root.powerConfirmDialog.powerConfirmMessage = "Are you sure you want to shutdown?"
                                        root.powerConfirmDialog.powerConfirmVisible = true
                                    }
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
                            if (BluetoothService.available) {
                                tabs.push({name: "Bluetooth", icon: "bluetooth", id: "bluetooth", available: true})
                            }
                            
                            // Always show display
                            tabs.push({name: "Display", icon: "brightness_6", id: "display", available: true})
                            
                            return tabs
                        }
                        
                        Rectangle {
                            property int tabCount: {
                                let count = 3 // Network + Audio + Display (always visible)
                                if (BluetoothService.available) count++
                                return count
                            }
                            width: (parent.width - Theme.spacingXS * (tabCount - 1)) / tabCount
                            height: 40
                            radius: Theme.cornerRadius
                            color: root.currentTab === modelData.id ? 
                                   Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : 
                                   tabArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                            
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS
                                
                                Text {
                                    text: modelData.icon
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize - 4
                                    color: root.currentTab === modelData.id ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: modelData.name
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: root.currentTab === modelData.id ? Theme.primary : Theme.surfaceText
                                    font.weight: root.currentTab === modelData.id ? Font.Medium : Font.Normal
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            MouseArea {
                                id: tabArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: {
                                    root.currentTab = modelData.id
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
                height: root.powerOptionsExpanded ? 240 : 300
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
                    visible: root.currentTab === "network"
                    
                }
                
                // Audio Tab
                AudioTab {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    visible: root.currentTab === "audio"
                }
                
                // Bluetooth Tab
                BluetoothTab {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    visible: BluetoothService.available && root.currentTab === "bluetooth"
                }
                
                // Display Tab
                DisplayTab {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    visible: root.currentTab === "display"
                    
                }
            }
        }
    }

    // Click outside to close
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            controlCenterVisible = false
        }
    }
}