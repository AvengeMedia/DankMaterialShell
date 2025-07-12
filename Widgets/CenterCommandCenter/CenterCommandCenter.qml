import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../../Common"
import "../../Services"

PanelWindow {
    id: centerCommandCenter
    
    property var theme: Theme
    property bool hasActiveMedia: root.hasActiveMedia
    property var weather: root.weather
    property bool useFahrenheit: false
    
    // Prevent media player from disappearing during track changes
    property bool showMediaPlayer: hasActiveMedia || hideMediaTimer.running
    
    Timer {
        id: hideMediaTimer
        interval: 3000  // 3 second grace period
        running: false
        repeat: false
    }
    
    onHasActiveMediaChanged: {
        if (hasActiveMedia) {
            hideMediaTimer.stop()
        } else {
            hideMediaTimer.start()
        }
    }
    
    visible: root.calendarVisible
    
    implicitWidth: 320
    implicitHeight: 400
    
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    
    color: "transparent"
    
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    
    Rectangle {
        width: 400
        height: showMediaPlayer ? 540 : (weather?.available ? 480 : 400)
        x: (parent.width - width) / 2
        y: theme.barHeight + theme.spacingS
        color: theme.surfaceContainer
        radius: theme.cornerRadiusLarge
        border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.12)
        border.width: 1
        
        opacity: root.calendarVisible ? 1.0 : 0.0
        scale: root.calendarVisible ? 1.0 : 0.85
        
        Behavior on opacity {
            NumberAnimation {
                duration: theme.mediumDuration
                easing.type: theme.emphasizedEasing
            }
        }
        
        Behavior on scale {
            NumberAnimation {
                duration: theme.mediumDuration
                easing.type: theme.emphasizedEasing
            }
        }
        
        Column {
            anchors.fill: parent
            anchors.margins: theme.spacingL
            spacing: theme.spacingM
            
            // Media Player (when active)
            MediaPlayerWidget {
                visible: showMediaPlayer
                theme: centerCommandCenter.theme
            }
            
            // Weather header (when available and no media)
            WeatherWidget {
                visible: weather?.available && !showMediaPlayer
                theme: centerCommandCenter.theme
                weather: centerCommandCenter.weather
                useFahrenheit: centerCommandCenter.useFahrenheit
            }
            
            // Calendar
            CalendarWidget {
                width: parent.width
                height: showMediaPlayer ? parent.height - 200 : (weather?.available ? parent.height - 120 : parent.height - 40)
                theme: centerCommandCenter.theme
            }
        }
    }
    
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            root.calendarVisible = false
        }
    }
}