import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import "Services"

PanelWindow {
    id: mediaPlayer
    
    property var theme
    property bool isVisible: false
    property MprisPlayer activePlayer: MprisController.activePlayer
    property bool hasActiveMedia: MprisController.isPlaying && (activePlayer?.trackTitle || activePlayer?.trackArtist)
    
    property var defaultTheme: QtObject {
        property color primary: "#D0BCFF"
        property color background: "#10121E"
        property color surfaceContainer: "#1D1B20"
        property color surfaceText: "#E6E0E9"
        property color surfaceVariant: "#49454F"
        property color surfaceVariantText: "#CAC4D0"
        property color outline: "#938F99"
        property color error: "#F2B8B5"
        property real cornerRadius: 12
        property real cornerRadiusLarge: 16
        property real cornerRadiusXLarge: 24
        property real cornerRadiusSmall: 8
        property real spacingXS: 4
        property real spacingS: 8
        property real spacingM: 12
        property real spacingL: 16
        property real spacingXL: 24
        property real fontSizeLarge: 16
        property real fontSizeMedium: 14
        property real fontSizeSmall: 12
        property real iconSize: 24
        property real iconSizeLarge: 32
        property string iconFont: "Material Symbols Rounded"
        property int iconFontWeight: Font.Normal
        property int shortDuration: 150
        property int mediumDuration: 300
        property int standardEasing: Easing.OutCubic
        property int emphasizedEasing: Easing.OutQuart
    }
    
    property var activeTheme: theme || defaultTheme
    
    onHasActiveMediaChanged: {
        if (!hasActiveMedia && isVisible) {
            hide()
        }
    }
    
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: isVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-media-player"
    
    visible: isVisible
    color: "transparent"
    
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.3)
        opacity: mediaPlayer.isVisible ? 1.0 : 0.0
        visible: mediaPlayer.isVisible
        
        Behavior on opacity {
            NumberAnimation {
                duration: activeTheme.shortDuration
                easing.type: activeTheme.standardEasing
            }
        }
        
        MouseArea {
            anchors.fill: parent
            enabled: mediaPlayer.isVisible
            onClicked: mediaPlayer.hide()
        }
    }
    
    Rectangle {
        id: mediaPanel
        
        width: 480
        height: 320
        
        anchors.centerIn: parent
        
        color: Qt.rgba(activeTheme.surfaceContainer.r, activeTheme.surfaceContainer.g, activeTheme.surfaceContainer.b, 0.98)
        radius: activeTheme.cornerRadiusXLarge
        
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            color: "transparent"
            radius: parent.radius + 2
            border.color: Qt.rgba(0, 0, 0, 0.08)
            border.width: 1
            z: -2
        }
        
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: Qt.rgba(activeTheme.outline.r, activeTheme.outline.g, activeTheme.outline.b, 0.12)
            border.width: 1
            radius: parent.radius
            z: -1
        }
        
        transform: [
            Scale {
                origin.x: mediaPanel.width / 2
                origin.y: mediaPanel.height / 2
                xScale: mediaPlayer.isVisible ? 1.0 : 0.9
                yScale: mediaPlayer.isVisible ? 1.0 : 0.9
                
                Behavior on xScale {
                    NumberAnimation {
                        duration: activeTheme.mediumDuration
                        easing.type: activeTheme.emphasizedEasing
                    }
                }
                
                Behavior on yScale {
                    NumberAnimation {
                        duration: activeTheme.mediumDuration
                        easing.type: activeTheme.emphasizedEasing
                    }
                }
            }
        ]
        
        opacity: mediaPlayer.isVisible ? 1.0 : 0.0
        
        Behavior on opacity {
            NumberAnimation {
                duration: activeTheme.mediumDuration
                easing.type: activeTheme.emphasizedEasing
            }
        }
        
        Column {
            anchors.fill: parent
            anchors.margins: activeTheme.spacingXL
            spacing: activeTheme.spacingL
            
            Row {
                width: parent.width
                height: 32
                
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Now Playing"
                    font.pixelSize: activeTheme.fontSizeLarge + 4
                    font.weight: Font.Bold
                    color: activeTheme.surfaceText
                }
                
                Item { width: parent.width - 200; height: 1 }
                
                Rectangle {
                    width: 32
                    height: 32
                    radius: activeTheme.cornerRadius
                    color: closeArea.containsMouse ? Qt.rgba(activeTheme.error.r, activeTheme.error.g, activeTheme.error.b, 0.12) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Text {
                        anchors.centerIn: parent
                        text: "close"
                        font.family: activeTheme.iconFont
                        font.pixelSize: activeTheme.iconSize
                        color: closeArea.containsMouse ? activeTheme.error : activeTheme.surfaceText
                    }
                    
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mediaPlayer.hide()
                    }
                }
            }
            
            Row {
                width: parent.width
                height: parent.height - 80
                spacing: activeTheme.spacingXL
                
                Rectangle {
                    width: 180
                    height: parent.height
                    radius: activeTheme.cornerRadiusLarge
                    color: Qt.rgba(activeTheme.surfaceVariant.r, activeTheme.surfaceVariant.g, activeTheme.surfaceVariant.b, 0.3)
                    
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
                                font.family: activeTheme.iconFont
                                font.pixelSize: 48
                                color: activeTheme.surfaceVariantText
                            }
                        }
                    }
                }
                
                Column {
                    width: parent.width - 180 - activeTheme.spacingXL
                    height: parent.height
                    spacing: activeTheme.spacingM
                    
                    Column {
                        width: parent.width
                        spacing: activeTheme.spacingS
                        
                        Text {
                            text: activePlayer?.trackTitle || "No title"
                            font.pixelSize: activeTheme.fontSizeLarge + 2
                            font.weight: Font.Bold
                            color: activeTheme.surfaceText
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        
                        Text {
                            text: activePlayer?.trackArtist || "Unknown artist"
                            font.pixelSize: activeTheme.fontSizeLarge
                            color: activeTheme.surfaceVariantText
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        
                        Text {
                            text: activePlayer?.trackAlbum || ""
                            font.pixelSize: activeTheme.fontSizeMedium
                            color: activeTheme.surfaceVariantText
                            elide: Text.ElideRight
                            width: parent.width
                            visible: text.length > 0
                        }
                    }
                    
                    Item { height: activeTheme.spacingM }
                    
                    Column {
                        width: parent.width
                        spacing: activeTheme.spacingS
                        
                        Rectangle {
                            width: parent.width
                            height: 6
                            radius: 3
                            color: Qt.rgba(activeTheme.surfaceVariant.r, activeTheme.surfaceVariant.g, activeTheme.surfaceVariant.b, 0.3)
                            
                            Rectangle {
                                width: parent.width * (activePlayer?.position / Math.max(activePlayer?.length || 1, 1))
                                height: parent.height
                                radius: parent.radius
                                color: activeTheme.primary
                            }
                        }
                        
                        Row {
                            width: parent.width
                            
                            Text {
                                text: formatTime(activePlayer?.position || 0)
                                font.pixelSize: activeTheme.fontSizeSmall
                                color: activeTheme.surfaceVariantText
                            }
                            
                            Item { width: parent.width - 100; height: 1 }
                            
                            Text {
                                text: formatTime(activePlayer?.length || 0)
                                font.pixelSize: activeTheme.fontSizeSmall
                                color: activeTheme.surfaceVariantText
                            }
                        }
                    }
                    
                    Item { height: activeTheme.spacingL }
                    
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: activeTheme.spacingL
                        
                        Rectangle {
                            width: 48
                            height: 48
                            radius: 24
                            color: prevArea.containsMouse ? Qt.rgba(activeTheme.surfaceVariant.r, activeTheme.surfaceVariant.g, activeTheme.surfaceVariant.b, 0.12) : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "skip_previous"
                                font.family: activeTheme.iconFont
                                font.pixelSize: activeTheme.iconSize
                                color: activeTheme.surfaceText
                            }
                            
                            MouseArea {
                                id: prevArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: activePlayer?.previous()
                            }
                        }
                        
                        Rectangle {
                            width: 56
                            height: 56
                            radius: 28
                            color: activeTheme.primary
                            
                            Text {
                                anchors.centerIn: parent
                                text: activePlayer?.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                                font.family: activeTheme.iconFont
                                font.pixelSize: activeTheme.iconSizeLarge
                                color: activeTheme.background
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: activePlayer?.togglePlaying()
                            }
                        }
                        
                        Rectangle {
                            width: 48
                            height: 48
                            radius: 24
                            color: nextArea.containsMouse ? Qt.rgba(activeTheme.surfaceVariant.r, activeTheme.surfaceVariant.g, activeTheme.surfaceVariant.b, 0.12) : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "skip_next"
                                font.family: activeTheme.iconFont
                                font.pixelSize: activeTheme.iconSize
                                color: activeTheme.surfaceText
                            }
                            
                            MouseArea {
                                id: nextArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: activePlayer?.next()
                            }
                        }
                    }
                }
            }
        }
    }
    
    Timer {
        running: activePlayer?.playbackState === MprisPlaybackState.Playing
        interval: 1000
        repeat: true
        onTriggered: activePlayer?.positionChanged()
    }
    
    function formatTime(seconds) {
        const mins = Math.floor(seconds / 60)
        const secs = Math.floor(seconds % 60)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }
    
    function show() {
        mediaPlayer.isVisible = true
    }
    
    function hide() {
        mediaPlayer.isVisible = false
    }
    
    function toggle() {
        if (mediaPlayer.isVisible) {
            hide()
        } else {
            show()
        }
    }
}