import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import qs.Common

PanelWindow {
    id: root
    
    property bool powerMenuVisible: false
    
    visible: powerMenuVisible
    
    implicitWidth: 400
    implicitHeight: 320
    
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
            powerMenuVisible = false
        }
    }
    
    Rectangle {
        width: Math.min(320, parent.width - Theme.spacingL * 2)
        height: 320  // Fixed height to prevent cropping
        x: Math.max(Theme.spacingL, parent.width - width - Theme.spacingL)
        y: Theme.barHeight + Theme.spacingXS
        color: Theme.popupBackground()
        radius: Theme.cornerRadiusLarge
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
        border.width: 1
        
        opacity: powerMenuVisible ? 1.0 : 0.0
        scale: powerMenuVisible ? 1.0 : 0.85
        
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
        
        // Prevent click-through to background
        MouseArea {
            anchors.fill: parent
            onClicked: {
                // Consume the click to prevent it from reaching the background
            }
        }
        
        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM
            
            // Header
            Row {
                width: parent.width
                
                Text {
                    text: "Power Options"
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Item { width: parent.width - 150; height: 1 }
                
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: closePowerArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "close"
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconSize - 4
                        color: closePowerArea.containsMouse ? Theme.error : Theme.surfaceText
                    }
                    
                    MouseArea {
                        id: closePowerArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerMenuVisible = false
                        }
                    }
                }
            }
            
            // Power options
            Column {
                width: parent.width
                spacing: Theme.spacingS
                
                // Log Out
                Rectangle {
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: logoutArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                    
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM
                        
                        Text {
                            text: "logout"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: "Log Out"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    MouseArea {
                        id: logoutArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerMenuVisible = false
                            root.powerConfirmAction = "logout"
                            root.powerConfirmTitle = "Log Out"
                            root.powerConfirmMessage = "Are you sure you want to log out?"
                            root.powerConfirmVisible = true
                        }
                    }
                }
                
                // Suspend
                Rectangle {
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: suspendArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                    
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM
                        
                        Text {
                            text: "bedtime"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: "Suspend"
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    MouseArea {
                        id: suspendArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerMenuVisible = false
                            root.powerConfirmAction = "suspend"
                            root.powerConfirmTitle = "Suspend"
                            root.powerConfirmMessage = "Are you sure you want to suspend the system?"
                            root.powerConfirmVisible = true
                        }
                    }
                }
                
                // Reboot
                Rectangle {
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: rebootArea.containsMouse ? Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                    
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM
                        
                        Text {
                            text: "restart_alt"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            color: rebootArea.containsMouse ? Theme.warning : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: "Reboot"
                            font.pixelSize: Theme.fontSizeMedium
                            color: rebootArea.containsMouse ? Theme.warning : Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    MouseArea {
                        id: rebootArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerMenuVisible = false
                            root.powerConfirmAction = "reboot"
                            root.powerConfirmTitle = "Reboot"
                            root.powerConfirmMessage = "Are you sure you want to reboot the system?"
                            root.powerConfirmVisible = true
                        }
                    }
                }
                
                // Power Off
                Rectangle {
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: powerOffArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.08) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08)
                    
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM
                        
                        Text {
                            text: "power_settings_new"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            color: powerOffArea.containsMouse ? Theme.error : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: "Power Off"
                            font.pixelSize: Theme.fontSizeMedium
                            color: powerOffArea.containsMouse ? Theme.error : Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    MouseArea {
                        id: powerOffArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerMenuVisible = false
                            root.powerConfirmAction = "poweroff"
                            root.powerConfirmTitle = "Power Off"
                            root.powerConfirmMessage = "Are you sure you want to power off the system?"
                            root.powerConfirmVisible = true
                        }
                    }
                }
            }
        }
    }
}