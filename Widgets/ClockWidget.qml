import QtQuick
import QtQuick.Controls
import Quickshell.Services.Mpris

Rectangle {
    id: clockContainer
    
    property var theme
    property var root
    
    width: Math.min(root.hasActiveMedia ? 500 : (root.weather.available ? 280 : 200), parent.width - theme.spacingL * 2)
    height: root.hasActiveMedia ? 80 : 32
    radius: theme.cornerRadius
    color: clockMouseArea.containsMouse && root.hasActiveMedia ? 
           Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) :
           Qt.rgba(theme.secondary.r, theme.secondary.g, theme.secondary.b, 0.08)
    
    Behavior on color {
        ColorAnimation {
            duration: theme.shortDuration
            easing.type: theme.standardEasing
        }
    }
    
    property date currentDate: new Date()
    
    // Media player content (when active)
    Column {
        visible: root.hasActiveMedia
        anchors.centerIn: parent
        width: parent.width - theme.spacingM * 2
        spacing: theme.spacingXS
        
        Row {
            width: parent.width
            spacing: theme.spacingS
            
            Rectangle {
                width: 48
                height: 48
                radius: theme.cornerRadiusSmall
                color: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.3)
                
                Item {
                    anchors.fill: parent
                    clip: true
                    
                    Image {
                        anchors.fill: parent
                        source: root.activePlayer?.trackArtUrl || ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                    }
                    
                    Rectangle {
                        anchors.fill: parent
                        visible: parent.children[0].status !== Image.Ready
                        color: "transparent"
                        
                        // Animated equalizer bars
                        Row {
                            anchors.centerIn: parent
                            spacing: 2
                            
                            Repeater {
                                model: 5
                                
                                Rectangle {
                                    property real targetHeight: root.activePlayer?.playbackState === MprisPlaybackState.Playing ? 
                                        4 + Math.random() * 12 : 4
                                    
                                    width: 3
                                    height: targetHeight
                                    radius: 1.5
                                    color: theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    Behavior on height {
                                        NumberAnimation {
                                            duration: 100 + index * 50
                                            easing.type: Easing.OutQuad
                                        }
                                    }
                                    
                                    Timer {
                                        running: root.activePlayer?.playbackState === MprisPlaybackState.Playing
                                        interval: 150 + index * 30
                                        repeat: true
                                        onTriggered: {
                                            parent.targetHeight = 4 + Math.random() * 12
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Column {
                width: parent.width - 48 - theme.spacingS - 120
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter
                
                Text {
                    text: root.activePlayer?.trackTitle || "Unknown Track"
                    font.pixelSize: theme.fontSizeMedium
                    color: theme.surfaceText
                    font.weight: Font.Medium
                    width: parent.width
                    elide: Text.ElideRight
                }
                
                Text {
                    text: root.activePlayer?.trackArtist || "Unknown Artist"
                    font.pixelSize: theme.fontSizeSmall
                    color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.7)
                    width: parent.width
                    elide: Text.ElideRight
                }
            }
            
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: theme.spacingS
                
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
                        onClicked: root.activePlayer?.previous()
                    }
                }
                
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: theme.primary
                    
                    Text {
                        anchors.centerIn: parent
                        text: root.activePlayer?.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                        font.family: theme.iconFont
                        font.pixelSize: 16
                        color: theme.background
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activePlayer?.togglePlaying()
                    }
                }
                
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
                        onClicked: root.activePlayer?.next()
                    }
                }
            }
        }
        
        Rectangle {
            width: parent.width
            height: 4
            radius: 2
            color: Qt.rgba(theme.surfaceVariant.r, theme.surfaceVariant.g, theme.surfaceVariant.b, 0.3)
            
            Rectangle {
                id: progressFill
                width: parent.width * (root.activePlayer?.position / Math.max(root.activePlayer?.length || 1, 1))
                height: parent.height
                radius: parent.radius
                color: theme.primary
                
                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutQuad
                    }
                }
            }
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                
                onClicked: (mouse) => {
                    if (root.activePlayer && root.activePlayer.length > 0) {
                        const newPosition = (mouse.x / width) * root.activePlayer.length
                        root.activePlayer.setPosition(newPosition)
                    }
                }
            }
        }
    }
    
    // Normal clock/weather content (when no media)
    Row {
        anchors.centerIn: parent
        spacing: theme.spacingM
        visible: !root.hasActiveMedia
        
        // Weather info (when available)
        Row {
            spacing: theme.spacingXS
            visible: root.weather.available
            anchors.verticalCenter: parent.verticalCenter
            
            Text {
                text: root.weatherIcons[root.weather.wCode] || "clear_day"
                font.family: theme.iconFont
                font.pixelSize: theme.iconSize - 2
                color: theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Text {
                text: (root.useFahrenheit ? root.weather.tempF : root.weather.temp) + "°" + (root.useFahrenheit ? "F" : "C")
                font.pixelSize: theme.fontSizeMedium
                color: theme.surfaceText
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        
        // Separator when weather is available
        Text {
            text: "•"
            font.pixelSize: theme.fontSizeMedium
            color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.5)
            anchors.verticalCenter: parent.verticalCenter
            visible: root.weather.available
        }
        
        // Time and date
        Row {
            spacing: theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
            
            Text {
                text: Qt.formatTime(clockContainer.currentDate, "h:mm AP")
                font.pixelSize: theme.fontSizeMedium
                color: theme.surfaceText
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Text {
                text: "•"
                font.pixelSize: theme.fontSizeMedium
                color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.5)
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Text {
                text: Qt.formatDate(clockContainer.currentDate, "ddd d")
                font.pixelSize: theme.fontSizeMedium
                color: theme.surfaceText
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
    
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            clockContainer.currentDate = new Date()
        }
    }
    
    MouseArea {
        id: clockMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: !root.hasActiveMedia ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: !root.hasActiveMedia
        
        onClicked: {
            root.calendarVisible = !root.calendarVisible
        }
    }
}