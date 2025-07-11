import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
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
    
    // Timer to update MPRIS position
    property bool justSeeked: false
    property real seekTargetPosition: 0
    
    Timer {
        id: positionTimer
        running: activePlayer?.playbackState === MprisPlaybackState.Playing && !justSeeked
        interval: 1000
        repeat: true
        onTriggered: {
            if (activePlayer) {
                activePlayer.positionChanged()
            }
        }
    }
    
    // Timer to resume position updates after seeking
    Timer {
        id: seekCooldownTimer
        interval: 1000  // Reduced from 2000
        repeat: false
        onTriggered: {
            justSeeked = false
            // Force position update after seek
            if (activePlayer) {
                activePlayer.positionChanged()
            }
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
        
        // Simple progress bar - click to seek only
        Rectangle {
            width: parent.width
            height: 6
            radius: 3
            color: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.3)
            
            Rectangle {
                width: {
                    if (!activePlayer || !activePlayer.length || activePlayer.length === 0) return 0
                    
                    // Use seek target position if we just seeked
                    const currentPos = justSeeked ? seekTargetPosition : activePlayer.position
                    return Math.max(0, Math.min(parent.width, parent.width * (currentPos / activePlayer.length)))
                }
                height: parent.height
                radius: parent.radius
                color: theme.primary
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                
                onClicked: (mouse) => {
                    if (activePlayer && activePlayer.length > 0 && activePlayer.canSeek) {
                        const ratio = mouse.x / width
                        const targetPosition = Math.floor(ratio * activePlayer.length)
                        const currentPosition = activePlayer.position || 0
                        const seekOffset = targetPosition - currentPosition
                        console.log("Simple seek - offset:", seekOffset, "target:", targetPosition, "current:", currentPosition)
                        
                        // Store target position for visual feedback
                        seekTargetPosition = targetPosition
                        justSeeked = true
                        seekCooldownTimer.restart()
                        
                        activePlayer.seek(seekOffset)
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
                        if (activePlayer.position > 8000000) {
                            console.log("Jumping to start - current position:", activePlayer.position)
                            
                            // Store target position for visual feedback
                            seekTargetPosition = 0
                            justSeeked = true
                            seekCooldownTimer.restart()
                            
                            // Seek to the beginning
                            activePlayer.seek(-activePlayer.position)
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