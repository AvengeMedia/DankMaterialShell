import QtQuick
import Quickshell.Services.Mpris
import "../../Common"

Rectangle {
    id: root
    
    property var activePlayer: null
    property bool hasActiveMedia: false
    
    // Add a stable visibility property that doesn't flicker during track changes
    property bool stableVisible: false
    
    signal clicked()
    
    // Use a timer to stabilize visibility during track changes
    Timer {
        id: visibilityTimer
        interval: 1000 // 1 second delay before hiding
        onTriggered: root.stableVisible = root.hasActiveMedia
    }
    
    onHasActiveMediaChanged: {
        if (hasActiveMedia) {
            // Show immediately when media becomes available
            stableVisible = true
            visibilityTimer.stop()
        } else {
            // Delay hiding to avoid flicker during track changes
            visibilityTimer.restart()
        }
    }
    
    visible: stableVisible
    width: stableVisible ? Math.min(280, mediaRow.implicitWidth + Theme.spacingS * 2) : 0
    height: 30
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
    
    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
    
    Behavior on width {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
    
    Row {
        id: mediaRow
        anchors.centerIn: parent
        spacing: Theme.spacingXS
        
        // Media info section (clickable to open full player)
        Row {
            id: mediaInfo
            spacing: Theme.spacingXS
            
            AudioVisualization {
                width: 20
                height: Theme.iconSize
                anchors.verticalCenter: parent.verticalCenter
                hasActiveMedia: root.hasActiveMedia
                activePlayer: root.activePlayer
            }
            
            Text {
                id: mediaText
                anchors.verticalCenter: parent.verticalCenter
                width: 140
                
                text: {
                    // Handle the case when activePlayer is temporarily null during track changes
                    if (!activePlayer || !activePlayer.trackTitle) {
                        return "Loading..."
                    }
                    
                    // Check if it's web media by looking at player identity
                    let identity = activePlayer.identity || ""
                    let isWebMedia = identity.toLowerCase().includes("firefox") || 
                                   identity.toLowerCase().includes("chrome") || 
                                   identity.toLowerCase().includes("chromium") ||
                                   identity.toLowerCase().includes("edge") ||
                                   identity.toLowerCase().includes("safari")
                    
                    let title = ""
                    let subtitle = ""
                    
                    if (isWebMedia && activePlayer.trackTitle) {
                        title = activePlayer.trackTitle
                        subtitle = activePlayer.trackArtist || identity
                    } else {
                        title = activePlayer.trackTitle || "Unknown Track"
                        subtitle = activePlayer.trackArtist || ""
                    }
                    
                    // Truncate title and subtitle to fit in available space - more generous limits
                    if (title.length > 20) title = title.substring(0, 20) + "..."
                    if (subtitle.length > 22) subtitle = subtitle.substring(0, 22) + "..."
                    
                    return subtitle.length > 0 ? title + " • " + subtitle : title
                }
                
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                font.weight: Font.Medium
                elide: Text.ElideRight
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clicked()
                }
            }
        }
        
        // Control buttons
        Row {
            spacing: Theme.spacingXS
            anchors.verticalCenter: parent.verticalCenter
            
            // Previous button
            Rectangle {
                width: 20
                height: 20
                radius: 10
                anchors.verticalCenter: parent.verticalCenter
                color: prevArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                visible: stableVisible
                opacity: (activePlayer && activePlayer.canGoPrevious) ? 1.0 : 0.3
                
                Text {
                    anchors.centerIn: parent
                    text: "skip_previous"
                    font.family: Theme.iconFont
                    font.pixelSize: 12
                    color: Theme.surfaceText
                }
                
                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (activePlayer) activePlayer.previous()
                    }
                }
            }
            
            // Play/Pause button
            Rectangle {
                width: 24
                height: 24
                radius: 12
                anchors.verticalCenter: parent.verticalCenter
                color: activePlayer?.playbackState === 1 ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                visible: stableVisible
                opacity: activePlayer ? 1.0 : 0.3
                
                Text {
                    anchors.centerIn: parent
                    text: activePlayer?.playbackState === 1 ? "pause" : "play_arrow"
                    font.family: Theme.iconFont
                    font.pixelSize: 14
                    color: activePlayer?.playbackState === 1 ? Theme.background : Theme.primary
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (activePlayer) activePlayer.togglePlaying()
                    }
                }
            }
            
            // Next button
            Rectangle {
                width: 20
                height: 20
                radius: 10
                anchors.verticalCenter: parent.verticalCenter
                color: nextArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                visible: stableVisible
                opacity: (activePlayer && activePlayer.canGoNext) ? 1.0 : 0.3
                
                Text {
                    anchors.centerIn: parent
                    text: "skip_next"
                    font.family: Theme.iconFont
                    font.pixelSize: 12
                    color: Theme.surfaceText
                }
                
                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (activePlayer) activePlayer.next()
                    }
                }
            }
        }
    }
}