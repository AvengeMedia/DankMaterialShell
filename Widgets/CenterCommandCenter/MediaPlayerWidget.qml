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
    height: parent.height
    radius: theme.cornerRadiusLarge
    color: Qt.rgba(theme.surfaceContainer.r, theme.surfaceContainer.g, theme.surfaceContainer.b, 0.4)
    border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.08)
    border.width: 1
    
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 2
        shadowBlur: 0.5
        shadowColor: Qt.rgba(0, 0, 0, 0.1)
        shadowOpacity: 0.1
    }
    
    property real currentPosition: 0
    
    // Simple progress ratio calculation
    function ratio() { 
        return activePlayer && activePlayer.length > 0 ? currentPosition / activePlayer.length : 0 
    }
    
    // Updates progress bar every 2 seconds when playing
    Timer {
        id: positionTimer
        interval: 2000
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
        anchors.centerIn: parent
        width: parent.width - theme.spacingM * 2
        spacing: theme.spacingM
        
        // Show different content based on whether we have active media
        Item {
            width: parent.width
            height: 80
            
            // Placeholder when no media
            Column {
                anchors.centerIn: parent
                spacing: theme.spacingS
                visible: !activePlayer || !activePlayer.trackTitle || activePlayer.trackTitle === ""
                
                Text {
                    text: "music_note"
                    font.family: theme.iconFont
                    font.pixelSize: theme.iconSize + 8
                    color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.5)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "No Media Playing"
                    font.pixelSize: theme.fontSizeMedium
                    color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.7)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
            
            // Normal media info when playing
            Row {
                anchors.fill: parent
                spacing: theme.spacingM
                visible: activePlayer && activePlayer.trackTitle && activePlayer.trackTitle !== ""
                
                // Album Art
                Rectangle {
                    width: 80
                    height: 80
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
                    width: parent.width - 80 - theme.spacingM
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
        }
        
        // Progress bar
        Rectangle {
            id: progressBarBackground
            width: parent.width
            height: 6
            radius: 3
            color: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.3)
            visible: activePlayer !== null
            
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
        
        // Control buttons - always visible
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: theme.spacingL
            visible: activePlayer !== null
            
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