import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import "../../Common"
import "../../Services"

Rectangle {
    id: mediaPlayerWidget
    
    property MprisPlayer activePlayer: MprisController.activePlayer
    property var theme: Theme
    
    width: parent.width
    height: 160  // Reduced height to prevent overflow
    radius: theme.cornerRadius
    color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08)
    border.color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.2)
    border.width: 1
    
    property real currentPosition: 0
    
    // Simple progress ratio calculation
    function ratio() { 
        return activePlayer && activePlayer.length > 0 ? currentPosition / activePlayer.length : 0 
    }
    
    // Updates progress bar every second
    Timer {
        id: positionTimer
        interval: 1000
        running: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing && activePlayer.length > 0 && !progressMouseArea.isSeeking
        repeat: true
        onTriggered: {
            if (activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing && !progressMouseArea.isSeeking) {
                currentPosition = activePlayer.position
            }
        }
    }
    
    // Initialize when player changes
    onActivePlayerChanged: {
        if (activePlayer) {
            currentPosition = activePlayer.position || 0
        } else {
            currentPosition = 0
        }
    }
    
    // Backend events
    Connections {
        target: activePlayer
        
        function onPositionChanged() {
            if (!progressMouseArea.isSeeking) {
                currentPosition = activePlayer.position
            }
        }
        
        function onPostTrackChanged() {
            currentPosition = activePlayer?.position || 0
        }
        
        function onTrackTitleChanged() {
            currentPosition = activePlayer?.position || 0
        }
    }
    
    Column {
        anchors.fill: parent
        anchors.margins: theme.spacingM
        spacing: theme.spacingM
        
        // Album art and track info
        Row {
            width: parent.width
            height: 70  // Reduced height
            spacing: theme.spacingM
            
            // Album Art
            Rectangle {
                width: 70
                height: 70
                radius: theme.cornerRadius
                color: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.3)
                
                Item {
                    anchors.fill: parent
                    clip: true
                    
                    Image {
                        id: albumArt
                        anchors.fill: parent
                        source: activePlayer?.trackArtUrl || ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                    }
                    
                    Rectangle {
                        anchors.fill: parent
                        visible: albumArt.status !== Image.Ready
                        color: "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "album"
                            font.family: theme.iconFont
                            font.pixelSize: 28
                            color: theme.surfaceVariantText
                        }
                    }
                }
            }
            
            // Track Info
            Column {
                width: parent.width - 70 - theme.spacingM
                spacing: theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                
                Text {
                    text: activePlayer?.trackTitle || "Unknown Track"
                    font.pixelSize: theme.fontSizeMedium
                    font.weight: Font.Bold
                    color: theme.surfaceText
                    width: parent.width
                    elide: Text.ElideRight
                }
                
                Text {
                    text: activePlayer?.trackArtist || "Unknown Artist"
                    font.pixelSize: theme.fontSizeSmall
                    color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.8)
                    width: parent.width
                    elide: Text.ElideRight
                }
                
                Text {
                    text: activePlayer?.trackAlbum || ""
                    font.pixelSize: theme.fontSizeSmall
                    color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.6)
                    width: parent.width
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }
        }
        
        // Progress bar
        Rectangle {
            id: progressBarBackground
            width: parent.width
            height: 6
            radius: 3
            color: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.3)
            
            Rectangle {
                id: progressFill
                height: parent.height
                radius: parent.radius
                color: theme.primary
                
                width: parent.width * ratio()
                
                Behavior on width {
                    NumberAnimation { duration: 100 }
                }
            }
            
            // Drag handle
            Rectangle {
                id: progressHandle
                width: 12
                height: 12
                radius: 6
                color: theme.primary
                border.color: Qt.lighter(theme.primary, 1.3)
                border.width: 1
                
                x: Math.max(0, Math.min(parent.width - width, progressFill.width - width/2))
                anchors.verticalCenter: parent.verticalCenter
                
                visible: activePlayer && activePlayer.length > 0
                scale: progressMouseArea.containsMouse || progressMouseArea.pressed ? 1.2 : 1.0
                
                Behavior on scale {
                    NumberAnimation { duration: 150 }
                }
            }
            
            MouseArea {
                id: progressMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: activePlayer && activePlayer.length > 0 && activePlayer.canSeek
                
                property bool isSeeking: false
                
                onClicked: function(mouse) {
                    if (activePlayer && activePlayer.length > 0) {
                        let ratio = mouse.x / width
                        let seekPosition = ratio * activePlayer.length
                        activePlayer.position = seekPosition
                        currentPosition = seekPosition
                    }
                }
                
                onPressed: function(mouse) {
                    isSeeking = true
                    if (activePlayer && activePlayer.length > 0) {
                        let ratio = Math.max(0, Math.min(1, mouse.x / width))
                        let seekPosition = ratio * activePlayer.length
                        activePlayer.position = seekPosition
                        currentPosition = seekPosition
                    }
                }
                
                onReleased: {
                    isSeeking = false
                }
                
                onPositionChanged: function(mouse) {
                    if (pressed && activePlayer && activePlayer.length > 0) {
                        let ratio = Math.max(0, Math.min(1, mouse.x / width))
                        let seekPosition = ratio * activePlayer.length
                        activePlayer.position = seekPosition
                        currentPosition = seekPosition
                    }
                }
            }
        }
        
        // Control buttons - compact to fit
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: theme.spacingL
            
            // Previous button  
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: prevBtnArea.containsMouse ? Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.12) : "transparent"
                
                Text {
                    anchors.centerIn: parent
                    text: "skip_previous"
                    font.family: theme.iconFont
                    font.pixelSize: 16
                    color: theme.surfaceText
                }
                
                MouseArea {
                    id: prevBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!activePlayer) return
                        
                        // >8 s → jump to start, otherwise previous track
                        if (currentPosition > 8 && activePlayer.canSeek) {
                            activePlayer.position = 0
                            currentPosition = 0
                        } else {
                            activePlayer.previous()
                        }
                    }
                }
            }
            
            // Play/Pause button
            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: theme.primary
                
                Text {
                    anchors.centerIn: parent
                    text: activePlayer?.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                    font.family: theme.iconFont
                    font.pixelSize: 20
                    color: theme.background
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: activePlayer?.togglePlaying()
                }
            }
            
            // Next button
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: nextBtnArea.containsMouse ? Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.12) : "transparent"
                
                Text {
                    anchors.centerIn: parent
                    text: "skip_next"
                    font.family: theme.iconFont
                    font.pixelSize: 16
                    color: theme.surfaceText
                }
                
                MouseArea {
                    id: nextBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: activePlayer?.next()
                }
            }
        }
    }
}