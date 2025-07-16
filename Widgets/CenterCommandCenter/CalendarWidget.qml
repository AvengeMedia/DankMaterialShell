import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.Common
import qs.Services

Column {
    id: calendarWidget
    
    property var theme: Theme
    property date displayDate: new Date()
    property date selectedDate: new Date()
    
    spacing: theme.spacingM
    
    // Load events when display date changes
    onDisplayDateChanged: {
        loadEventsForMonth()
    }
    
    // Load events when calendar service becomes available
    Connections {
        target: CalendarService
        enabled: CalendarService !== null
        function onKhalAvailableChanged() {
            if (CalendarService && CalendarService.khalAvailable) {
                loadEventsForMonth()
            }
        }
    }
    
    Component.onCompleted: {
        console.log("CalendarWidget: Component completed, CalendarService available:", !!CalendarService)
        if (CalendarService) {
            console.log("CalendarWidget: khal available:", CalendarService.khalAvailable)
        }
        loadEventsForMonth()
    }
    
    function loadEventsForMonth() {
        if (!CalendarService || !CalendarService.khalAvailable) return
        
        // Calculate date range with padding
        let firstDay = new Date(displayDate.getFullYear(), displayDate.getMonth(), 1)
        let dayOfWeek = firstDay.getDay()
        let startDate = new Date(firstDay)
        startDate.setDate(startDate.getDate() - dayOfWeek - 7) // Extra week padding
        
        let lastDay = new Date(displayDate.getFullYear(), displayDate.getMonth() + 1, 0)
        let endDate = new Date(lastDay)
        endDate.setDate(endDate.getDate() + (6 - lastDay.getDay()) + 7) // Extra week padding
        
        CalendarService.loadEvents(startDate, endDate)
    }
    
    // Month navigation header
    Row {
        width: parent.width
        height: 40
        
        Rectangle {
            width: 40
            height: 40
            radius: theme.cornerRadius
            color: prevMonthArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) : "transparent"
            
            Text {
                anchors.centerIn: parent
                text: "chevron_left"
                font.family: theme.iconFont
                font.pixelSize: theme.iconSize
                color: theme.primary
                font.weight: theme.iconFontWeight
            }
            
            MouseArea {
                id: prevMonthArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                onClicked: {
                    let newDate = new Date(displayDate)
                    newDate.setMonth(newDate.getMonth() - 1)
                    displayDate = newDate
                }
            }
        }
        
        Text {
            width: parent.width - 80
            height: 40
            text: Qt.formatDate(displayDate, "MMMM yyyy")
            font.pixelSize: theme.fontSizeLarge
            color: theme.surfaceText
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        
        Rectangle {
            width: 40
            height: 40
            radius: theme.cornerRadius
            color: nextMonthArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) : "transparent"
            
            Text {
                anchors.centerIn: parent
                text: "chevron_right"
                font.family: theme.iconFont
                font.pixelSize: theme.iconSize
                color: theme.primary
                font.weight: theme.iconFontWeight
            }
            
            MouseArea {
                id: nextMonthArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                onClicked: {
                    let newDate = new Date(displayDate)
                    newDate.setMonth(newDate.getMonth() + 1)
                    displayDate = newDate
                }
            }
        }
    }
    
    // Days of week header
    Row {
        width: parent.width
        height: 32
        
        Repeater {
            model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            
            Rectangle {
                width: parent.width / 7
                height: 32
                color: "transparent"
                
                Text {
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: theme.fontSizeSmall
                    color: Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.6)
                    font.weight: Font.Medium
                }
            }
        }
    }
    
    // Calendar grid
    Grid {
        width: parent.width
        height: 200 // Fixed height for calendar
        columns: 7
        rows: 6
        
        property date firstDay: {
            let date = new Date(displayDate.getFullYear(), displayDate.getMonth(), 1)
            let dayOfWeek = date.getDay()
            date.setDate(date.getDate() - dayOfWeek)
            return date
        }
        
        Repeater {
            model: 42
            
            Rectangle {
                width: parent.width / 7
                height: parent.height / 6
                
                property date dayDate: {
                    let date = new Date(parent.firstDay)
                    date.setDate(date.getDate() + index)
                    return date
                }
                
                property bool isCurrentMonth: dayDate.getMonth() === displayDate.getMonth()
                property bool isToday: dayDate.toDateString() === new Date().toDateString()
                property bool isSelected: dayDate.toDateString() === selectedDate.toDateString()
                
                color: isSelected ? theme.primary :
                       isToday ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.12) :
                       dayArea.containsMouse ? Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.08) : "transparent"
                
                radius: theme.cornerRadiusSmall
                
                Text {
                    anchors.centerIn: parent
                    text: dayDate.getDate()
                    font.pixelSize: theme.fontSizeMedium
                    color: isSelected ? theme.surface :
                           isToday ? theme.primary :
                           isCurrentMonth ? theme.surfaceText : 
                           Qt.rgba(theme.surfaceText.r, theme.surfaceText.g, theme.surfaceText.b, 0.4)
                    font.weight: isToday || isSelected ? Font.Medium : Font.Normal
                }
                
                // Event indicator - full-width elegant bar
                Rectangle {
                    id: eventIndicator
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 2
                    height: 3
                    radius: 1.5
                    visible: CalendarService && CalendarService.khalAvailable && CalendarService.hasEventsForDate(dayDate)
                    
                    // Dynamic color based on state with opacity
                    color: {
                        if (isSelected) {
                            // Use a lighter tint of primary for selected state
                            return Qt.lighter(theme.primary, 1.3)
                        } else if (isToday) {
                            return theme.primary
                        } else {
                            return theme.primary
                        }
                    }
                    
                    opacity: {
                        if (isSelected) {
                            return 0.9
                        } else if (isToday) {
                            return 0.8
                        } else {
                            return 0.6
                        }
                    }
                    
                    // Subtle animation on hover
                    scale: dayArea.containsMouse ? 1.05 : 1.0
                    
                    Behavior on scale {
                        NumberAnimation {
                            duration: theme.shortDuration
                            easing.type: theme.standardEasing
                        }
                    }
                    
                    Behavior on color {
                        ColorAnimation {
                            duration: theme.shortDuration
                            easing.type: theme.standardEasing
                        }
                    }
                    
                    Behavior on opacity {
                        NumberAnimation {
                            duration: theme.shortDuration
                            easing.type: theme.standardEasing
                        }
                    }
                }
                
                MouseArea {
                    id: dayArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        selectedDate = dayDate
                    }
                }
            }
        }
    }
}