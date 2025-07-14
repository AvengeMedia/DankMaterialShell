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
            
            // Main row with widgets and calendar
            let widgetHeight = 160  // Media widget always present
            widgetHeight += (weather ? 140 : 80) + theme.spacingM  // Weather widget always present
            let calendarHeight = 300
            let mainRowHeight = Math.max(widgetHeight, calendarHeight)
            
            contentHeight += mainRowHeight + theme.spacingM // Add spacing between main row and events
            
            // Add events widget height - dynamically calculated
            if (CalendarService && CalendarService.khalAvailable) {
                let eventsHeight = eventsWidget.height || 120 // Use actual widget height or fallback
                contentHeight += eventsHeight
            }
            
            return Math.min(contentHeight, parent.height * 0.9)
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
        
        // Update height when calendar service events change
        Connections {
            target: CalendarService
            enabled: CalendarService !== null
            function onEventsByDateChanged() {
                mainContainer.height = mainContainer.calculateHeight()
            }
            function onKhalAvailableChanged() {
                mainContainer.height = mainContainer.calculateHeight()
            }
        }
        
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
        
        Column {
            anchors.fill: parent
            anchors.margins: theme.spacingM
            spacing: theme.spacingM
            
            // Main row with widgets and calendar
            Row {
                width: parent.width
                height: {
                    let widgetHeight = 160  // Media widget always present
                    widgetHeight += (weather ? 140 : 80) + theme.spacingM  // Weather widget always present
                    let calendarHeight = 300
                    return Math.max(widgetHeight, calendarHeight)
                }
                spacing: theme.spacingM
                
                // Left section for widgets
                Column {
                    id: leftWidgets
                    width: hasAnyWidgets ? parent.width * 0.45 : 0
                    height: childrenRect.height
                    spacing: theme.spacingM
                    visible: hasAnyWidgets
                    anchors.top: parent.top
                    
                    property bool hasAnyWidgets: true  // Always show media widget and weather widget
                    
                    MediaPlayerWidget {
                        visible: true  // Always visible - shows placeholder when no media
                        width: parent.width
                        height: 160
                        theme: centerCommandCenter.theme
                    }
                    
                    WeatherWidget {
                        visible: true  // Always visible - shows placeholder when no weather
                        width: parent.width
                        height: weather ? 140 : 80
                        theme: centerCommandCenter.theme
                        weather: centerCommandCenter.weather
                    }
                }
                
                // Right section for calendar
                CalendarWidget {
                    id: calendarWidget
                    width: leftWidgets.hasAnyWidgets ? parent.width * 0.55 - theme.spacingL : parent.width
                    height: parent.height
                    theme: centerCommandCenter.theme
                }
            }
            
            // Full-width events widget below
            EventsWidget {
                id: eventsWidget
                width: parent.width
                theme: centerCommandCenter.theme
                selectedDate: calendarWidget.selectedDate
                
                // Update container height when events widget height changes
                onHeightChanged: {
                    mainContainer.height = mainContainer.calculateHeight()
                }
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