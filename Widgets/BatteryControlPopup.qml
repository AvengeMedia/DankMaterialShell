import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.Common
import qs.Services

PanelWindow {
    id: batteryControlPopup
        
    visible: root.batteryPopupVisible
        
    implicitWidth: 400
    implicitHeight: 300
        
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
    
    // Click outside to dismiss overlay
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.batteryPopupVisible = false
        }
    }
        
    Rectangle {
        width: Math.min(380, parent.width - Theme.spacingL * 2)
        height: Math.min(450, parent.height - Theme.barHeight - Theme.spacingS * 2)
        x: Math.max(Theme.spacingL, parent.width - width - Theme.spacingL)
        y: Theme.barHeight + Theme.spacingS
        color: Theme.popupBackground()
        radius: Theme.cornerRadiusLarge
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1
        
        opacity: root.batteryPopupVisible ? 1.0 : 0.0
        scale: root.batteryPopupVisible ? 1.0 : 0.85
        
        // Prevent click-through to background
        MouseArea {
            anchors.fill: parent
            onClicked: {
                // Consume the click to prevent it from reaching the background
            }
        }
        
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
        
        ScrollView {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            clip: true
            
            Column {
                width: parent.width
                spacing: Theme.spacingL
                
                // Header
                Row {
                    width: parent.width
                    
                    Text {
                        text: BatteryService.batteryAvailable ? "Battery Information" : "Power Management"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Item { width: parent.width - 200; height: 1 }
                    
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: closeBatteryArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) : "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "close"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize - 4
                            color: closeBatteryArea.containsMouse ? Theme.error : Theme.surfaceText
                        }
                        
                        MouseArea {
                            id: closeBatteryArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.batteryPopupVisible = false
                            }
                        }
                    }
                }
                
                Rectangle {
                    width: parent.width
                    height: 120
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                    border.color: BatteryService.isCharging ? Theme.primary : (BatteryService.isLowBattery ? Theme.error : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12))
                    border.width: BatteryService.isCharging || BatteryService.isLowBattery ? 2 : 1
                    visible: BatteryService.batteryAvailable
                    
                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        spacing: Theme.spacingL
                        
                        Text {
                            text: BatteryService.getBatteryIcon()
                            font.family: Theme.iconFont
                            font.pixelSize: 48
                            color: {
                                if (BatteryService.isLowBattery && !BatteryService.isCharging) return Theme.error
                                if (BatteryService.isCharging) return Theme.primary
                                return Theme.surfaceText
                            }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Column {
                            spacing: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                text: BatteryService.batteryLevel + "%"
                                font.pixelSize: Theme.fontSizeXLarge
                                color: {
                                    if (BatteryService.isLowBattery && !BatteryService.isCharging) return Theme.error
                                    if (BatteryService.isCharging) return Theme.primary
                                    return Theme.surfaceText
                                }
                                font.weight: Font.Bold
                            }
                            
                            Text {
                                text: BatteryService.batteryStatus
                                font.pixelSize: Theme.fontSizeLarge
                                color: {
                                    if (BatteryService.isLowBattery && !BatteryService.isCharging) return Theme.error
                                    if (BatteryService.isCharging) return Theme.primary
                                    return Theme.surfaceText
                                }
                                font.weight: Font.Medium
                            }
                            
                            Text {
                                text: {
                                    let time = BatteryService.formatTimeRemaining()
                                    if (time !== "Unknown") {
                                        return BatteryService.isCharging ? "Time until full: " + time : "Time remaining: " + time
                                    }
                                    return ""
                                }
                                font.pixelSize: Theme.fontSizeMedium
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                visible: text.length > 0
                            }
                        }
                    }
                }
                
                // No battery info card
                Rectangle {
                    width: parent.width
                    height: 80
                    radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: 1
                    visible: !BatteryService.batteryAvailable
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingL
                        
                        Text {
                            text: BatteryService.getBatteryIcon()
                            font.family: Theme.iconFont
                            font.pixelSize: 36
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Column {
                            spacing: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                text: "No Battery Detected"
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }
                            
                            Text {
                                text: "Power profile management is available"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                            }
                        }
                    }
                }
                
                // Battery details
                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: BatteryService.batteryAvailable
                    
                    Text {
                        text: "Battery Details"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }
                    
                    Grid {
                        width: parent.width
                        columns: 2
                        columnSpacing: Theme.spacingL
                        rowSpacing: Theme.spacingM
                        
                        // Technology
                        Column {
                            spacing: 2
                            
                            Text {
                                text: "Technology"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                font.weight: Font.Medium
                            }
                            
                            Text {
                                text: BatteryService.batteryTechnology
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                            }
                        }
                        
                        
                        // Health
                        Column {
                            spacing: 2
                            
                            Text {
                                text: "Health"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                font.weight: Font.Medium
                            }
                            
                            Text {
                                text: BatteryService.batteryHealth + "%"
                                font.pixelSize: Theme.fontSizeMedium
                                color: BatteryService.batteryHealth < 80 ? Theme.error : Theme.surfaceText
                            }
                        }
                        
                        // Capacity
                        Column {
                            spacing: 2
                            
                            Text {
                                text: "Capacity"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                font.weight: Font.Medium
                            }
                            
                            Text {
                                text: BatteryService.batteryCapacity > 0 ? BatteryService.batteryCapacity + " mWh" : "Unknown"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                            }
                        }
                    }
                }
                
                // Power profiles
                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: true
                    
                    Text {
                        text: "Power Profile"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }
                    
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        
                        Repeater {
                            model: BatteryService.powerProfiles
                            
                            Rectangle {
                                width: parent.width
                                height: 50
                                radius: Theme.cornerRadius
                                color: profileArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : 
                                       (modelData === BatteryService.activePowerProfile ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08))
                                border.color: modelData === BatteryService.activePowerProfile ? Theme.primary : "transparent"
                                border.width: 2
                                
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingL
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingM
                                    
                                    Text {
                                        text: {
                                            switch (modelData) {
                                                case "power-saver": return "battery_saver"
                                                case "balanced": return "battery_std"
                                                case "performance": return "flash_on"
                                                default: return "settings"
                                            }
                                        }
                                        font.family: Theme.iconFont
                                        font.pixelSize: Theme.iconSize
                                        color: modelData === BatteryService.activePowerProfile ? Theme.primary : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    Column {
                                        spacing: 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        Text {
                                            text: {
                                                switch (modelData) {
                                                    case "power-saver": return "Power Saver"
                                                    case "balanced": return "Balanced"
                                                    case "performance": return "Performance"
                                                    default: return modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                                }
                                            }
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: modelData === BatteryService.activePowerProfile ? Theme.primary : Theme.surfaceText
                                            font.weight: modelData === BatteryService.activePowerProfile ? Font.Medium : Font.Normal
                                        }
                                        
                                        Text {
                                            text: {
                                                switch (modelData) {
                                                    case "power-saver": return "Extend battery life"
                                                    case "balanced": return "Balance power and performance"
                                                    case "performance": return "Prioritize performance"
                                                    default: return "Custom power profile"
                                                }
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                        }
                                    }
                                }
                                
                                MouseArea {
                                    id: profileArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onClicked: {
                                        BatteryService.setBatteryProfile(modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Error toast
    Rectangle {
        id: errorToast
        width: Math.min(300, parent.width - Theme.spacingL * 2)
        height: 50
        radius: Theme.cornerRadius
        color: Theme.error
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.spacingL
        visible: false
        z: 1000
        
        Text {
            anchors.centerIn: parent
            text: "power-profiles-daemon not available"
            color: "white"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
        }
        
        Timer {
            id: hideTimer
            interval: 3000
            onTriggered: errorToast.visible = false
        }
        
        function show() {
            visible = true
            hideTimer.restart()
        }
    }
    
    Connections {
        target: BatteryService
        function onShowErrorMessage(message) {
            errorToast.show()
        }
    }
}