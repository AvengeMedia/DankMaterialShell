import QtQuick
import Quickshell.Services.Mpris
import "../../Common"

Rectangle {
    id: root
    
    property var activePlayer: null
    property bool hasActiveMedia: activePlayer && (activePlayer.trackTitle || activePlayer.trackArtist)
    
    signal clicked()
    
    visible: hasActiveMedia
    width: hasActiveMedia ? Math.min(200, mediaText.implicitWidth + Theme.spacingS * 2 + 20 + Theme.spacingXS) : 0
    height: 30
    radius: Theme.cornerRadius
    color: mediaArea.containsMouse ? 
           Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) :
           Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.08)
    
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
        anchors.centerIn: parent
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
            text: activePlayer?.trackTitle || "Unknown Track"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 150)
            elide: Text.ElideRight
        }
    }
    
    MouseArea {
        id: mediaArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: root.clicked()
    }
}