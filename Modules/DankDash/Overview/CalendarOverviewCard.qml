import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool showEventDetails: false
    property date selectedDate: systemClock.date
    property var selectedDateEvents: []
    property bool hasEvents: selectedDateEvents && selectedDateEvents.length > 0

    function weekStartJs() {
        return Qt.locale().firstDayOfWeek % 7
    }

    function startOfWeek(dateObj) {
        const d = new Date(dateObj)
        const jsDow = d.getDay()
        const diff = (jsDow - weekStartJs() + 7) % 7
        d.setDate(d.getDate() - diff)
        return d
    }

    function endOfWeek(dateObj) {
        const d = new Date(dateObj)
        const jsDow = d.getDay()
        const add = (weekStartJs() + 6 - jsDow + 7) % 7
        d.setDate(d.getDate() + add)
        return d
    }

    function updateSelectedDateEvents() {
        if (CalendarService && CalendarService.khalAvailable) {
            const events = CalendarService.getEventsForDate(selectedDate)
            selectedDateEvents = events
        } else {
            selectedDateEvents = []
        }
    }

    function loadEventsForMonth() {
        if (!CalendarService || !CalendarService.khalAvailable) {
            return
        }

        const firstOfMonth = new Date(calendarGrid.displayDate.getFullYear(),
                                      calendarGrid.displayDate.getMonth(), 1)
        const lastOfMonth  = new Date(calendarGrid.displayDate.getFullYear(),
                                      calendarGrid.displayDate.getMonth() + 1, 0)

        const startDate = startOfWeek(firstOfMonth)
        startDate.setDate(startDate.getDate() - 7)

        const endDate = endOfWeek(lastOfMonth)
        endDate.setDate(endDate.getDate() + 7)

        CalendarService.loadEvents(startDate, endDate)
    }

    onSelectedDateChanged: updateSelectedDateEvents()
    Component.onCompleted: {
        loadEventsForMonth()
        updateSelectedDateEvents()
    }

    Connections {
        function onEventsByDateChanged() {
            updateSelectedDateEvents()
        }

        function onKhalAvailableChanged() {
            if (CalendarService && CalendarService.khalAvailable) {
                loadEventsForMonth()
            }
            updateSelectedDateEvents()
        }

        target: CalendarService
        enabled: CalendarService !== null
    }

    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.05)
    border.width: 1

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS
        
        Item {
            width: parent.width
            height: 40
            visible: showEventDetails
            
            Rectangle {
                width: 32
                height: 32
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingS
                radius: Theme.cornerRadius
                color: backButtonArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                DankIcon {
                    anchors.centerIn: parent
                    name: "arrow_back"
                    size: 14
                    color: Theme.primary
                }

                MouseArea {
                    id: backButtonArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showEventDetails = false
                }
            }
            
            StyledText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 32 + Theme.spacingS * 2
                anchors.rightMargin: Theme.spacingS
                height: 40
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const dateStr = Qt.formatDate(selectedDate, "MMM d")
                    if (selectedDateEvents && selectedDateEvents.length > 0) {
                        const eventCount = selectedDateEvents.length === 1 ? I18n.tr("1 event") : selectedDateEvents.length + " " + I18n.tr("events")
                        return dateStr + " • " + eventCount
                    }
                    return dateStr
                }
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
        Row {
            width: parent.width
            height: 28
            visible: !showEventDetails
            
            Rectangle {
                width: 28
                height: 28
                radius: Theme.cornerRadius
                color: prevMonthArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                DankIcon {
                    anchors.centerIn: parent
                    name: "chevron_left"
                    size: 14
                    color: Theme.primary
                }

                MouseArea {
                    id: prevMonthArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let newDate = new Date(calendarGrid.displayDate)
                        newDate.setMonth(newDate.getMonth() - 1)
                        calendarGrid.displayDate = newDate
                        loadEventsForMonth()
                    }
                }
            }

            StyledText {
                width: parent.width - 56
                height: 28
                text: calendarGrid.displayDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                width: 28
                height: 28
                radius: Theme.cornerRadius
                color: nextMonthArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

                DankIcon {
                    anchors.centerIn: parent
                    name: "chevron_right"
                    size: 14
                    color: Theme.primary
                }

                MouseArea {
                    id: nextMonthArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let newDate = new Date(calendarGrid.displayDate)
                        newDate.setMonth(newDate.getMonth() + 1)
                        calendarGrid.displayDate = newDate
                        loadEventsForMonth()
                    }
                }
            }
        }
        
        Row {
            width: parent.width
            height: 18
            visible: !showEventDetails

            Repeater {
                model: {
                    const days = []
                    const loc = Qt.locale()
                    const qtFirst = loc.firstDayOfWeek
                    for (let i = 0; i < 7; ++i) {
                        const qtDay = ((qtFirst - 1 + i) % 7) + 1
                        days.push(loc.dayName(qtDay, Locale.ShortFormat))
                    }
                    return days
                }

                Rectangle {
                    width: parent.width / 7
                    height: 18
                    color: "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: Theme.fontSizeSmall
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                        font.weight: Font.Medium
                    }
                }
            }
        }
        
        Grid {
            id: calendarGrid
            visible: !showEventDetails
            
            property date displayDate: systemClock.date
            property date selectedDate: systemClock.date
            
            readonly property date firstDay: {
                const firstOfMonth = new Date(displayDate.getFullYear(), displayDate.getMonth(), 1)
                return startOfWeek(firstOfMonth)
            }

            width: parent.width
            height: parent.height - 28 - 18 - Theme.spacingS * 2
            columns: 7
            rows: 6

            Repeater {
                model: 42

                Rectangle {
                    readonly property date dayDate: {
                        const date = new Date(parent.firstDay)
                        date.setDate(date.getDate() + index)
                        return date
                    }
                    readonly property bool isCurrentMonth: dayDate.getMonth() === calendarGrid.displayDate.getMonth()
                    readonly property bool isToday: dayDate.toDateString() === new Date().toDateString()
                    readonly property bool isSelected: dayDate.toDateString() === calendarGrid.selectedDate.toDateString()

                    width: parent.width / 7
                    height: parent.height / 6
                    color: "transparent"

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 4, parent.height - 4, 32)
                        height: width
                        color: isToday ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : dayArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                        radius: width / 2

                        StyledText {
                            anchors.centerIn: parent
                            text: dayDate.getDate()
                            font.pixelSize: Theme.fontSizeSmall
                            color: isToday ? Theme.primary : isCurrentMonth ? Theme.surfaceText : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                            font.weight: isToday ? Font.Medium : Font.Normal
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottomMargin: 4
                            width: 12
                            height: 2
                            radius: 1
                            visible: CalendarService && CalendarService.khalAvailable && CalendarService.hasEventsForDate(dayDate)
                            color: isToday ? Qt.lighter(Theme.primary, 1.3) : Theme.primary
                            opacity: isToday ? 0.9 : 0.7

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: dayArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (CalendarService && CalendarService.khalAvailable && CalendarService.hasEventsForDate(dayDate)) {
                                root.selectedDate = dayDate
                                root.showEventDetails = true
                            }
                        }
                    }
                }
            }
        }
        DankListView {
            width: parent.width - Theme.spacingS * 2
            height: parent.height - (showEventDetails ? 40 : 28 + 18) - Theme.spacingS
            anchors.horizontalCenter: parent.horizontalCenter
            model: selectedDateEvents
            visible: showEventDetails
            clip: true
            spacing: Theme.spacingXS
            
            delegate: Rectangle {
                width: parent ? parent.width : 0
                height: eventContent.implicitHeight + Theme.spacingS
                radius: Theme.cornerRadius
                color: {
                    if (modelData.url && eventMouseArea.containsMouse) {
                        return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                    } else if (eventMouseArea.containsMouse) {
                        return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06)
                    }
                    return Theme.surfaceContainerHigh
                }
                border.color: {
                    if (modelData.url && eventMouseArea.containsMouse) {
                        return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                    } else if (eventMouseArea.containsMouse) {
                        return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    }
                    return "transparent"
                }
                border.width: 1

                Rectangle {
                    width: 3
                    height: parent.height - 6
                    anchors.left: parent.left
                    anchors.leftMargin: 3
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 2
                    color: Theme.primary
                    opacity: 0.8
                }

                Column {
                    id: eventContent
                    
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.spacingS + 6
                    anchors.rightMargin: Theme.spacingXS
                    spacing: 2

                    StyledText {
                        width: parent.width
                        text: modelData.title
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    StyledText {
                        width: parent.width
                        text: {
                            if (!modelData || modelData.allDay) {
                                return I18n.tr("All day")
                            } else if (modelData.start && modelData.end) {
                                const timeFormat = SettingsData.use24HourClock ? "HH:mm" : "h:mm AP"
                                const startTime = Qt.formatTime(modelData.start, timeFormat)
                                if (modelData.start.toDateString() !== modelData.end.toDateString() || modelData.start.getTime() !== modelData.end.getTime()) {
                                    return startTime + " – " + Qt.formatTime(modelData.end, timeFormat)
                                }
                                return startTime
                            }
                            return ""
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                        font.weight: Font.Normal
                        visible: text !== ""
                    }
                }

                MouseArea {
                    id: eventMouseArea
                    
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: modelData.url ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: modelData.url !== ""
                    onClicked: {
                        if (modelData.url && modelData.url !== "") {
                            if (Qt.openUrlExternally(modelData.url) === false) {
                                console.warn("Failed to open URL: " + modelData.url)
                            }
                        }
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }
        }
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Hours
    }
}