import QtQuick
import "../../Common"
import "../../Services"

Rectangle {
    id: root
    
    property string networkStatus: "disconnected"
    property string wifiSignalStrength: "good"
    property int volumeLevel: 50
    property bool volumeMuted: false
    property bool bluetoothAvailable: false
    property bool bluetoothEnabled: false
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
                if (root.networkStatus === "ethernet") return "lan"
                else if (root.networkStatus === "wifi") {
                    switch (root.wifiSignalStrength) {
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
            color: root.networkStatus !== "disconnected" ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
            anchors.verticalCenter: parent.verticalCenter
            visible: true
        }
        
        // Bluetooth Icon (when available and enabled) - moved next to network
        Text {
            text: "bluetooth"
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize - 8
            font.weight: Theme.iconFontWeight
            color: root.bluetoothEnabled ? Theme.primary : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
            anchors.verticalCenter: parent.verticalCenter
            visible: root.bluetoothAvailable && root.bluetoothEnabled
        }
        
        // Audio Icon with scroll wheel support
        Rectangle {
            width: audioIcon.implicitWidth + 4
            height: audioIcon.implicitHeight + 4
            color: "transparent"
            anchors.verticalCenter: parent.verticalCenter
            
            Text {
                id: audioIcon
                text: root.volumeMuted ? "volume_off" : 
                      root.volumeLevel < 33 ? "volume_down" : "volume_up"
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
                    let currentVolume = root.volumeLevel
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