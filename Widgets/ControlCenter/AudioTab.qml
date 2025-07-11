import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import "../../Common"
import "../../Services"

Item {
    id: audioTab
    
    property int audioSubTab: 0 // 0: Output, 1: Input
    
    // These should be bound from parent
    property real volumeLevel: 50
    property real micLevel: 50
    property string currentAudioSink: ""
    property string currentAudioSource: ""
    property var audioSinks: []
    property var audioSources: []
    
    Column {
        anchors.fill: parent
        spacing: Theme.spacingM
        
        // Audio Sub-tabs
        Row {
            width: parent.width
            height: 40
            spacing: 2
            
            Rectangle {
                width: parent.width / 2 - 1
                height: parent.height
                radius: Theme.cornerRadius
                color: audioTab.audioSubTab === 0 ? Theme.primary : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                
                Text {
                    anchors.centerIn: parent
                    text: "Output"
                    font.pixelSize: Theme.fontSizeMedium
                    color: audioTab.audioSubTab === 0 ? Theme.primaryText : Theme.surfaceText
                    font.weight: Font.Medium
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: audioTab.audioSubTab = 0
                }
            }
            
            Rectangle {
                width: parent.width / 2 - 1
                height: parent.height
                radius: Theme.cornerRadius
                color: audioTab.audioSubTab === 1 ? Theme.primary : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                
                Text {
                    anchors.centerIn: parent
                    text: "Input"
                    font.pixelSize: Theme.fontSizeMedium
                    color: audioTab.audioSubTab === 1 ? Theme.primaryText : Theme.surfaceText
                    font.weight: Font.Medium
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: audioTab.audioSubTab = 1
                }
            }
        }
        
        // Output Tab Content
        ScrollView {
            width: parent.width
            height: parent.height - 48
            visible: audioTab.audioSubTab === 0
            clip: true
            
            Column {
                width: parent.width
                spacing: Theme.spacingL
                
                // Volume Control
                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    
                    Text {
                        text: "Volume"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }
                    
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        
                        Text {
                            text: "volume_down"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Rectangle {
                            id: volumeSliderTrack
                            width: parent.width - 80
                            height: 8
                            radius: 4
                            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Rectangle {
                                id: volumeSliderFill
                                width: parent.width * (audioTab.volumeLevel / 100)
                                height: parent.height
                                radius: parent.radius
                                color: Theme.primary
                                
                                Behavior on width {
                                    NumberAnimation { duration: 100 }
                                }
                            }
                            
                            // Draggable handle
                            Rectangle {
                                id: volumeHandle
                                width: 18
                                height: 18
                                radius: 9
                                color: Theme.primary
                                border.color: Qt.lighter(Theme.primary, 1.3)
                                border.width: 2
                                
                                x: Math.max(0, Math.min(parent.width - width, volumeSliderFill.width - width/2))
                                anchors.verticalCenter: parent.verticalCenter
                                
                                scale: volumeMouseArea.containsMouse || volumeMouseArea.pressed ? 1.2 : 1.0
                                
                                Behavior on scale {
                                    NumberAnimation { duration: 150 }
                                }
                            }
                            
                            MouseArea {
                                id: volumeMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: (mouse) => {
                                    let ratio = Math.max(0, Math.min(1, mouse.x / width))
                                    let newVolume = Math.round(ratio * 100)
                                    AudioService.setVolume(newVolume)
                                }
                                
                                onPositionChanged: (mouse) => {
                                    if (pressed) {
                                        let ratio = Math.max(0, Math.min(1, mouse.x / width))
                                        let newVolume = Math.round(ratio * 100)
                                        AudioService.setVolume(newVolume)
                                    }
                                }
                            }
                        }
                        
                        Text {
                            text: "volume_up"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    Text {
                        text: audioTab.volumeLevel + "%"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
                
                // Output Devices
                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    
                    Text {
                        text: "Output Device"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }
                    
                    // Current device indicator
                    Rectangle {
                        width: parent.width
                        height: 35
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                        border.width: 1
                        visible: audioTab.currentAudioSink !== ""
                        
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS
                            
                            Text {
                                text: "check_circle"
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.iconSize - 4
                                color: Theme.primary
                            }
                            
                            Text {
                                text: "Current: " + (function() {
                                    for (let sink of audioTab.audioSinks) {
                                        if (sink.name === audioTab.currentAudioSink) {
                                            return sink.displayName
                                        }
                                    }
                                    return audioTab.currentAudioSink
                                })()
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.primary
                                font.weight: Font.Medium
                            }
                        }
                    }
                    
                    // Real audio devices
                    Repeater {
                        model: audioTab.audioSinks
                        
                        Rectangle {
                            width: parent.width
                            height: 50
                            radius: Theme.cornerRadius
                            color: deviceArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : 
                                   (modelData.active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08))
                            border.color: modelData.active ? Theme.primary : "transparent"
                            border.width: 1
                            
                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingM
                                
                                Text {
                                    text: {
                                        if (modelData.name.includes("bluez")) return "headset"
                                        else if (modelData.name.includes("hdmi")) return "tv"
                                        else if (modelData.name.includes("usb")) return "headset"
                                        else return "speaker"
                                    }
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize
                                    color: modelData.active ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Column {
                                    spacing: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    Text {
                                        text: modelData.displayName
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: modelData.active ? Theme.primary : Theme.surfaceText
                                        font.weight: modelData.active ? Font.Medium : Font.Normal
                                    }
                                    
                                    Text {
                                        text: modelData.active ? "Selected" : ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.8)
                                        visible: modelData.active
                                    }
                                }
                            }
                            
                            MouseArea {
                                id: deviceArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: {
                                    console.log("Clicked audio device:", JSON.stringify(modelData))
                                    console.log("Device name to set:", modelData.name)
                                    AudioService.setAudioSink(modelData.name)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Input Tab Content
        ScrollView {
            width: parent.width
            height: parent.height - 48
            visible: audioTab.audioSubTab === 1
            clip: true
            
            Column {
                width: parent.width
                spacing: Theme.spacingL
                
                // Microphone Level Control
                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    
                    Text {
                        text: "Microphone Level"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }
                    
                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        
                        Text {
                            text: "mic"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Rectangle {
                            id: micSliderTrack
                            width: parent.width - 80
                            height: 8
                            radius: 4
                            color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Rectangle {
                                id: micSliderFill
                                width: parent.width * (audioTab.micLevel / 100)
                                height: parent.height
                                radius: parent.radius
                                color: Theme.primary
                                
                                Behavior on width {
                                    NumberAnimation { duration: 100 }
                                }
                            }
                            
                            // Draggable handle
                            Rectangle {
                                id: micHandle
                                width: 18
                                height: 18
                                radius: 9
                                color: Theme.primary
                                border.color: Qt.lighter(Theme.primary, 1.3)
                                border.width: 2
                                
                                x: Math.max(0, Math.min(parent.width - width, micSliderFill.width - width/2))
                                anchors.verticalCenter: parent.verticalCenter
                                
                                scale: micMouseArea.containsMouse || micMouseArea.pressed ? 1.2 : 1.0
                                
                                Behavior on scale {
                                    NumberAnimation { duration: 150 }
                                }
                            }
                            
                            MouseArea {
                                id: micMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: (mouse) => {
                                    let ratio = Math.max(0, Math.min(1, mouse.x / width))
                                    let newMicLevel = Math.round(ratio * 100)
                                    AudioService.setMicLevel(newMicLevel)
                                }
                                
                                onPositionChanged: (mouse) => {
                                    if (pressed) {
                                        let ratio = Math.max(0, Math.min(1, mouse.x / width))
                                        let newMicLevel = Math.round(ratio * 100)
                                        AudioService.setMicLevel(newMicLevel)
                                    }
                                }
                            }
                        }
                        
                        Text {
                            text: "mic"
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    Text {
                        text: audioTab.micLevel + "%"
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
                
                // Input Devices
                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    
                    Text {
                        text: "Input Device"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }
                    
                    // Current device indicator
                    Rectangle {
                        width: parent.width
                        height: 35
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                        border.width: 1
                        visible: audioTab.currentAudioSource !== ""
                        
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS
                            
                            Text {
                                text: "check_circle"
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.iconSize - 4
                                color: Theme.primary
                            }
                            
                            Text {
                                text: "Current: " + (function() {
                                    for (let source of audioTab.audioSources) {
                                        if (source.name === audioTab.currentAudioSource) {
                                            return source.displayName
                                        }
                                    }
                                    return audioTab.currentAudioSource
                                })()
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.primary
                                font.weight: Font.Medium
                            }
                        }
                    }
                    
                    // Real audio input devices
                    Repeater {
                        model: audioTab.audioSources
                        
                        Rectangle {
                            width: parent.width
                            height: 50
                            radius: Theme.cornerRadius
                            color: sourceArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : 
                                   (modelData.active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08))
                            border.color: modelData.active ? Theme.primary : "transparent"
                            border.width: 1
                            
                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingM
                                
                                Text {
                                    text: {
                                        if (modelData.name.includes("bluez")) return "headset_mic"
                                        else if (modelData.name.includes("usb")) return "headset_mic"
                                        else return "mic"
                                    }
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize
                                    color: modelData.active ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Column {
                                    spacing: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    Text {
                                        text: modelData.displayName
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: modelData.active ? Theme.primary : Theme.surfaceText
                                        font.weight: modelData.active ? Font.Medium : Font.Normal
                                    }
                                    
                                    Text {
                                        text: modelData.active ? "Selected" : ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.8)
                                        visible: modelData.active
                                    }
                                }
                            }
                            
                            MouseArea {
                                id: sourceArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onClicked: {
                                    console.log("Clicked audio source:", JSON.stringify(modelData))
                                    console.log("Source name to set:", modelData.name)
                                    AudioService.setAudioSource(modelData.name)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}