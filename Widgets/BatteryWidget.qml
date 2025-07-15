import QtQuick
import "../Common"
import "../Services"

Rectangle {
    id: batteryWidget
    
    property bool batteryPopupVisible: false
    
    signal toggleBatteryPopup()
    
    width: 70  // Increased width to accommodate percentage text
    height: 30
    radius: Theme.cornerRadius
    color: batteryArea.containsMouse || batteryPopupVisible ? 
           Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : 
           Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08)
    visible: BatteryService.batteryAvailable
    
    Row {
        anchors.centerIn: parent
        spacing: 4
        
        // Battery icon - Material Design icons already show level visually
        Text {
            text: BatteryService.getBatteryIcon()
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize - 6
            color: {
                if (!BatteryService.batteryAvailable) return Theme.surfaceText
                if (BatteryService.isLowBattery && !BatteryService.isCharging) return Theme.error
                if (BatteryService.isCharging) return Theme.primary
                return Theme.surfaceText
            }
            anchors.verticalCenter: parent.verticalCenter
            
            // Subtle pulse animation for charging
            SequentialAnimation on opacity {
                running: BatteryService.isCharging
                loops: Animation.Infinite
                NumberAnimation { to: 0.6; duration: 1000; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutQuad }
            }
        }
        
        // Battery percentage text
        Text {
            text: BatteryService.batteryLevel + "%"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: {
                if (!BatteryService.batteryAvailable) return Theme.surfaceText
                if (BatteryService.isLowBattery && !BatteryService.isCharging) return Theme.error
                if (BatteryService.isCharging) return Theme.primary
                return Theme.surfaceText
            }
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    
    MouseArea {
        id: batteryArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            toggleBatteryPopup()
        }
    }
    
    // Tooltip on hover
    Rectangle {
        id: batteryTooltip
        width: Math.max(120, tooltipText.contentWidth + Theme.spacingM * 2)
        height: tooltipText.contentHeight + Theme.spacingS * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
        border.width: 1
        visible: batteryArea.containsMouse && !batteryPopupVisible && BatteryService.batteryAvailable
        
        anchors.bottom: parent.top
        anchors.bottomMargin: Theme.spacingS
        anchors.horizontalCenter: parent.horizontalCenter
        
        opacity: batteryArea.containsMouse ? 1.0 : 0.0
        
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
        
        Column {
            anchors.centerIn: parent
            spacing: 2
            
            Text {
                id: tooltipText
                text: {
                    if (!BatteryService.batteryAvailable) return "No battery"
                    
                    let status = BatteryService.batteryStatus
                    let level = BatteryService.batteryLevel + "%"
                    let time = BatteryService.formatTimeRemaining()
                    
                    if (time !== "Unknown") {
                        return status + " • " + level + " • " + time
                    } else {
                        return status + " • " + level
                    }
                }
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                horizontalAlignment: Text.AlignHCenter
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