import QtQuick
import QtQuick.Controls
import "../Common"
import "../Services"

Rectangle {
    id: batteryWidget
    
    property bool batteryPopupVisible: false
    
    width: Theme.barHeight - Theme.spacingS
    height: Theme.barHeight - Theme.spacingS
    radius: Theme.cornerRadiusSmall
    color: batteryArea.containsMouse ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08) : "transparent"
    visible: BatteryService.batteryAvailable
    
    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingXS
        
        // Battery icon
        Text {
            text: BatteryService.getBatteryIcon()
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
            color: {
                if (!BatteryService.batteryAvailable) return Theme.surfaceText
                if (BatteryService.isLowBattery && !BatteryService.isCharging) return Theme.error
                if (BatteryService.isCharging) return Theme.primary
                return Theme.surfaceText
            }
            anchors.verticalCenter: parent.verticalCenter
            
            // Subtle animation for charging
            RotationAnimation on rotation {
                running: BatteryService.isCharging
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 8000
                easing.type: Easing.Linear
            }
        }
        
        // Battery percentage
        Text {
            text: BatteryService.batteryLevel + "%"
            font.pixelSize: Theme.fontSizeSmall
            color: {
                if (!BatteryService.batteryAvailable) return Theme.surfaceText
                if (BatteryService.isLowBattery && !BatteryService.isCharging) return Theme.error
                if (BatteryService.isCharging) return Theme.primary
                return Theme.surfaceText
            }
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
            visible: BatteryService.batteryAvailable
        }
    }
    
    MouseArea {
        id: batteryArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            batteryPopupVisible = !batteryPopupVisible
            root.batteryPopupVisible = batteryPopupVisible
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