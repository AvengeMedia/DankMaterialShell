import QtQuick
import qs.Common
import qs.Services

Rectangle {
    id: root
    
    property bool isActive: false
    
    signal clicked()
    
    width: Math.max(80, controlIndicators.implicitWidth + Theme.spacingS * 2)
    height: 30
    radius: Theme.cornerRadius
    color: controlCenterArea.containsMouse || root.isActive ? 
           Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : 
           Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08)
    
    Row {
        id: controlIndicators
        anchors.centerIn: parent
        spacing: Theme.spacingXS
        
        // Network Status Icon
        Text {
            text: {
                if (NetworkService.networkStatus === "ethernet") return "lan"
                else if (NetworkService.networkStatus === "wifi") {
                    switch (WifiService.wifiSignalStrength) {
                        case "excellent": return "wifi"
                        case "good": return "wifi_2_bar"
                        case "fair": return "wifi_1_bar"
                        case "poor": return "wifi_calling_3"
                        default: return "wifi"
                    }
                }
                else return "wifi_off"
            }
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize - 8
            font.weight: Theme.iconFontWeight
            color: NetworkService.networkStatus !== "disconnected" ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
            anchors.verticalCenter: parent.verticalCenter
            visible: true
        }
        
        // Bluetooth Icon (when available and enabled) - moved next to network
        Text {
            text: "bluetooth"
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize - 8
            font.weight: Theme.iconFontWeight
            color: BluetoothService.enabled ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
            anchors.verticalCenter: parent.verticalCenter
            visible: BluetoothService.available && BluetoothService.enabled
        }
        
        // Audio Icon with scroll wheel support
        Rectangle {
            width: audioIcon.implicitWidth + 4
            height: audioIcon.implicitHeight + 4
            color: "transparent"
            anchors.verticalCenter: parent.verticalCenter
            
            Text {
                id: audioIcon
                text: AudioService.sinkMuted ? "volume_off" : 
                      AudioService.volumeLevel < 33 ? "volume_down" : "volume_up"
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSize - 8
                font.weight: Theme.iconFontWeight
                color: audioWheelArea.containsMouse || controlCenterArea.containsMouse || root.isActive ? 
                       Theme.primary : Theme.surfaceText
                anchors.centerIn: parent
            }
            
            MouseArea {
                id: audioWheelArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                
                onWheel: function(wheelEvent) {
                    let delta = wheelEvent.angleDelta.y
                    let currentVolume = AudioService.volumeLevel
                    let newVolume
                    
                    if (delta > 0) {
                        // Scroll up - increase volume
                        newVolume = Math.min(100, currentVolume + 5)
                    } else {
                        // Scroll down - decrease volume
                        newVolume = Math.max(0, currentVolume - 5)
                    }
                    
                    AudioService.setVolume(newVolume)
                    wheelEvent.accepted = true
                }
            }
        }
        
        // Microphone Icon (when active)
        Text {
            text: "mic"
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize - 8
            font.weight: Theme.iconFontWeight
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
            visible: false // TODO: Add mic detection
        }
    }
    
    MouseArea {
        id: controlCenterArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            root.clicked()
        }
    }
    
    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}