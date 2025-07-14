import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import "../Common"

PanelWindow {
    id: powerConfirmDialog
    
    visible: root.powerConfirmVisible
    
    implicitWidth: 400
    implicitHeight: 300
    
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    
    color: "transparent"
    
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    
    // Darkened background
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.5
    }
    
    Rectangle {
        width: Math.min(400, parent.width - Theme.spacingL * 2)
        height: Math.min(200, parent.height - Theme.spacingL * 2)
        anchors.centerIn: parent
        color: Theme.surfaceContainer
        radius: Theme.cornerRadiusLarge
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        border.width: 1
        
        opacity: root.powerConfirmVisible ? 1.0 : 0.0
        scale: root.powerConfirmVisible ? 1.0 : 0.9
        
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
            anchors.centerIn: parent
            width: parent.width - Theme.spacingL * 2
            spacing: Theme.spacingL
            
            // Title
            Text {
                text: root.powerConfirmTitle
                font.pixelSize: Theme.fontSizeLarge
                color: {
                    switch(root.powerConfirmAction) {
                        case "poweroff": return Theme.error
                        case "reboot": return Theme.warning
                        default: return Theme.surfaceText
                    }
                }
                font.weight: Font.Medium
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }
            
            // Message
            Text {
                text: root.powerConfirmMessage
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
            
            Item { height: Theme.spacingL }
            
            // Buttons
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingM
                
                // Cancel button
                Rectangle {
                    width: 120
                    height: 40
                    radius: Theme.cornerRadius
                    color: cancelButton.containsMouse ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.12) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                    
                    Text {
                        text: "Cancel"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.centerIn: parent
                    }
                    
                    MouseArea {
                        id: cancelButton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.powerConfirmVisible = false
                        }
                    }
                }
                
                // Confirm button
                Rectangle {
                    width: 120
                    height: 40
                    radius: Theme.cornerRadius
                    color: {
                        let baseColor
                        switch(root.powerConfirmAction) {
                            case "poweroff": baseColor = Theme.error; break
                            case "reboot": baseColor = Theme.warning; break
                            default: baseColor = Theme.primary; break
                        }
                        return confirmButton.containsMouse ? 
                               Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.9) : 
                               baseColor
                    }
                    
                    Text {
                        text: "Confirm"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.primaryText
                        font.weight: Font.Medium
                        anchors.centerIn: parent
                    }
                    
                    MouseArea {
                        id: confirmButton
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.powerConfirmVisible = false
                            executePowerAction(root.powerConfirmAction)
                        }
                    }
                }
            }
        }
    }
    
    function executePowerAction(action) {
        console.log("Executing power action:", action)
        
        let command = []
        switch(action) {
            case "logout":
                command = ["niri", "msg", "action", "quit", "-s"]
                break
            case "suspend":
                command = ["systemctl", "suspend"]
                break
            case "reboot":
                command = ["systemctl", "reboot"]
                break
            case "poweroff":
                command = ["systemctl", "poweroff"]
                break
        }
        
        if (command.length > 0) {
            powerActionProcess.command = command
            powerActionProcess.running = true
        }
    }
    
    Process {
        id: powerActionProcess
        running: false
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.error("Power action failed with exit code:", exitCode)
            }
        }
    }
}