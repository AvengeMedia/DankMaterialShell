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
    
    property bool showMediaPlayer: hasActiveMedia || hideMediaTimer.running
    
    Timer {
        id: hideMediaTimer
        interval: 3000
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
    
    implicitWidth: 480
    implicitHeight: 600
    
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
        id: mainContainer
        width: calculateWidth()
        height: calculateHeight()
        x: (parent.width - width) / 2
        y: Theme.barHeight + 4
        
        function calculateWidth() {
            let baseWidth = 320
            if (leftWidgets.hasAnyWidgets) {
                return Math.min(parent.width * 0.9, 600)
            }
            return Math.min(parent.width * 0.7, 400)
        }
        
        function calculateHeight() {
            let contentHeight = theme.spacingM * 2 // margins
            
            // Calculate widget heights - media widget is always present
            let widgetHeight = 160  // Media widget always present
            if (weather?.available) {
                widgetHeight += (weather ? 140 : 80) + theme.spacingM
            }
            
            // Calendar height is always 300
            let calendarHeight = 300
            
            // Take the max of widgets and calendar
            contentHeight += Math.max(widgetHeight, calendarHeight)
            
            return Math.min(contentHeight, parent.height * 0.85)
        }
        
        color: theme.surfaceContainer
        radius: theme.cornerRadiusLarge
        border.color: Qt.rgba(theme.outline.r, theme.outline.g, theme.outline.b, 0.12)
        border.width: 1
        
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 4
            shadowBlur: 0.5
            shadowColor: Qt.rgba(0, 0, 0, 0.15)
            shadowOpacity: 0.15
        }
        
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(theme.surfaceTint.r, theme.surfaceTint.g, theme.surfaceTint.b, 0.04)
            radius: parent.radius
            
            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.08
                    duration: theme.extraLongDuration
                    easing.type: theme.standardEasing
                }
                NumberAnimation {
                    to: 0.02
                    duration: theme.extraLongDuration
                    easing.type: theme.standardEasing
                }
            }
        }
        
        opacity: root.calendarVisible ? 1.0 : 0.0
        scale: root.calendarVisible ? 1.0 : 0.92
        
        Behavior on opacity {
            NumberAnimation {
                duration: theme.longDuration
                easing.type: theme.emphasizedEasing
            }
        }
        
        Behavior on scale {
            NumberAnimation {
                duration: theme.longDuration
                easing.type: theme.emphasizedEasing
            }
        }
        
        Behavior on height {
            NumberAnimation {
                duration: theme.mediumDuration
                easing.type: theme.standardEasing
            }
        }
        
        Row {
            anchors.fill: parent
            anchors.margins: theme.spacingM
            spacing: theme.spacingM
            
            // Left section for widgets
            Column {
                id: leftWidgets
                width: hasAnyWidgets ? parent.width * 0.45 : 0
                height: childrenRect.height
                spacing: theme.spacingM
                visible: hasAnyWidgets
                anchors.top: parent.top
                
                property bool hasAnyWidgets: true || weather?.available  // Always show media widget
                
                MediaPlayerWidget {
                    visible: true  // Always visible - shows placeholder when no media
                    width: parent.width
                    height: 160
                    theme: centerCommandCenter.theme
                }
                
                WeatherWidget {
                    visible: weather?.available
                    width: parent.width
                    height: weather ? 140 : 80
                    theme: centerCommandCenter.theme
                    weather: centerCommandCenter.weather
                    useFahrenheit: centerCommandCenter.useFahrenheit
                }
            }
            
            // Right section for calendar
            CalendarWidget {
                width: leftWidgets.hasAnyWidgets ? parent.width * 0.55 - theme.spacingL : parent.width
                height: parent.height
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