import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    implicitWidth: SettingsData.showWeekNumber ? 736 : 700

    property bool showEventDetails: false
    property date selectedDate: systemClock.date
    property var selectedDateEvents: []
    property bool hasEvents: selectedDateEvents && selectedDateEvents.length > 0

    signal closeDash

    function weekStartQt() {
        if (SettingsData.firstDayOfWeek >= 7 || SettingsData.firstDayOfWeek < 0) {
            return Qt.locale().firstDayOfWeek;
        }
        return SettingsData.firstDayOfWeek;
    }

    function weekStartJs() {
        return weekStartQt() % 7;
    }

    function startOfWeek(dateObj) {
        const d = new Date(dateObj);
        const jsDow = d.getDay();
        const diff = (jsDow - weekStartJs() + 7) % 7;
        d.setDate(d.getDate() - diff);
        return d;
    }

    function endOfWeek(dateObj) {
        const d = new Date(dateObj);
        const jsDow = d.getDay();
        const add = (weekStartJs() + 6 - jsDow + 7) % 7;
        d.setDate(d.getDate() + add);
        return d;
    }

    function getWeekNumber(dateObj) {
        // Set time to noon to avoid potential Daylight Saving Time related bugs
        const weekStartDay = startOfWeek(dateObj);
        weekStartDay.setHours(12, 0, 0, 0);

        let week1Start;

        if (weekStartJs() === 1) {
            // ISO 8601 Standard, week start on Monday
            // A week belongs to the year its Thursday falls in
            // So we have to get the yearTarget from weekStartDay instead of dateObj
            let yearTarget = weekStartDay;
            yearTarget.setDate(yearTarget.getDate() + 3); // Monday + 3 = Thursday

            // Week 1 is the week containing Jan 4th
            const jan4 = new Date(yearTarget.getFullYear(), 0, 4);
            week1Start = startOfWeek(jan4);
        } else {
            // Traditional / US Standard, week start on Sunday
            // A week belongs to the year its Sunday falls in
            let yearTarget = weekStartDay;
            yearTarget.setDate(yearTarget.getDate() + 6); // Monday + 6 = Sunday

            // Week 1 is the week containing Jan 1st
            const jan1 = new Date(yearTarget.getFullYear(), 0, 1);
            week1Start = startOfWeek(jan1);
        }

        week1Start.setHours(12, 0, 0, 0);

        const diffDays = Math.round((weekStartDay.getTime() - week1Start.getTime()) / 86400000); // Number of miliseconds in a day
        return Math.floor(diffDays / 7) + 1;
    }

    function updateSelectedDateEvents() {
        if (CalendarService && CalendarService.khalAvailable) {
            const events = CalendarService.getEventsForDate(selectedDate);
            selectedDateEvents = events;
        } else {
            selectedDateEvents = [];
        }
    }

    function loadEventsForMonth() {
        if (!CalendarService || !CalendarService.khalAvailable) {
            return;
        }

        const firstOfMonth = new Date(calendarGrid.displayDate.getFullYear(), calendarGrid.displayDate.getMonth(), 1);
        const lastOfMonth = new Date(calendarGrid.displayDate.getFullYear(), calendarGrid.displayDate.getMonth() + 1, 0);

        const startDate = startOfWeek(firstOfMonth);
        startDate.setDate(startDate.getDate() - 7);

        const endDate = endOfWeek(lastOfMonth);
        endDate.setDate(endDate.getDate() + 7);

        CalendarService.loadEvents(startDate, endDate);
    }

    onSelectedDateChanged: updateSelectedDateEvents()
    Component.onCompleted: {
        loadEventsForMonth();
        updateSelectedDateEvents();
    }

    Connections {
        function onEventsByDateChanged() {
            updateSelectedDateEvents();
        }

        function onKhalAvailableChanged() {
            if (CalendarService && CalendarService.khalAvailable) {
                loadEventsForMonth();
            }
            updateSelectedDateEvents();
        }

        target: CalendarService
        enabled: CalendarService !== null
    }

    radius: Theme.cornerRadius
    color: Theme.nestedSurface
    border.color: Theme.outlineMedium
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
                    const dateStr = Qt.formatDate(selectedDate, "MMM d");
                    if (selectedDateEvents && selectedDateEvents.length > 0) {
                        const eventCount = selectedDateEvents.length === 1 ? I18n.tr("1 event") : selectedDateEvents.length + " " + I18n.tr("events");
                        return dateStr + " • " + eventCount;
                    }
                    return dateStr;
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
                        let newDate = new Date(calendarGrid.displayDate);
                        newDate.setMonth(newDate.getMonth() - 1);
                        calendarGrid.displayDate = newDate;
                        loadEventsForMonth();
                    }
                }
            }

            StyledText {
                width: parent.width - 56
                height: 28
                text: calendarGrid.displayDate.toLocaleDateString(I18n.locale(), "MMMM yyyy")
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
                        let newDate = new Date(calendarGrid.displayDate);
                        newDate.setMonth(newDate.getMonth() + 1);
                        calendarGrid.displayDate = newDate;
                        loadEventsForMonth();
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: parent.height - 28 - Theme.spacingS
            visible: !showEventDetails
            spacing: SettingsData.showWeekNumber ? Theme.spacingS : 0

            Column {
                id: weekNumberColumn
                visible: SettingsData.showWeekNumber
                width: SettingsData.showWeekNumber ? 28 : 0
                height: parent.height
                spacing: Theme.spacingS

                Item {
                    width: parent.width
                    height: 18
                }

                Grid {
                    width: parent.width
                    height: parent.height - 18 - Theme.spacingS
                    columns: 1
                    rows: 6

                    Repeater {
                        model: 6
                        Rectangle {
                            width: parent.width
                            height: parent.height / 6
                            color: "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: {
                                    const rowDate = new Date(calendarGrid.firstDay);
                                    rowDate.setDate(rowDate.getDate() + index * 7);
                                    return root.getWeekNumber(rowDate);
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }

            Column {
                width: SettingsData.showWeekNumber ? (parent.width - weekNumberColumn.width - parent.spacing) : parent.width
                height: parent.height
                spacing: Theme.spacingS

                Row {
                    width: parent.width
                    height: 18

                    Repeater {
                        model: {
                            const days = [];
                            const qtFirst = weekStartQt();
                            for (let i = 0; i < 7; ++i) {
                                const qtDay = ((qtFirst - 1 + i) % 7) + 1;
                                days.push(I18n.locale().dayName(qtDay, Locale.ShortFormat));
                            }
                            return days;
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
                    width: parent.width
                    height: parent.height - 18 - Theme.spacingS
                    columns: 7
                    rows: 6

                    property date displayDate: systemClock.date
                    property date selectedDate: systemClock.date

                    readonly property date firstDay: {
                        const firstOfMonth = new Date(displayDate.getFullYear(), displayDate.getMonth(), 1);
                        return startOfWeek(firstOfMonth);
                    }

                    Repeater {
                        model: 42

                        Rectangle {
                            readonly property date dayDate: {
                                const date = new Date(parent.firstDay);
                                date.setDate(date.getDate() + index);
                                return date;
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
                                radius: Theme.cornerRadius

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
                                    radius: Theme.cornerRadius
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
                                        root.selectedDate = dayDate;
                                        root.showEventDetails = true;
                                    }
                                }
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
                        return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12);
                    } else if (eventMouseArea.containsMouse) {
                        return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06);
                    }
                    return Theme.nestedSurface;
                }
                border.color: {
                    if (modelData.url && eventMouseArea.containsMouse) {
                        return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3);
                    } else if (eventMouseArea.containsMouse) {
                        return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15);
                    }
                    return Theme.outlineMedium;
                }
                border.width: eventMouseArea.containsMouse ? 1 : Theme.layerOutlineWidth

                Rectangle {
                    width: 3
                    height: parent.height - 6
                    anchors.left: parent.left
                    anchors.leftMargin: 3
                    anchors.verticalCenter: parent.verticalCenter
                    radius: Theme.cornerRadius
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
                                return I18n.tr("All day");
                            } else if (modelData.start && modelData.end) {
                                const timeFormat = SettingsData.use24HourClock ? "HH:mm" : "h:mm AP";
                                const startTime = Qt.formatTime(modelData.start, timeFormat);
                                if (modelData.start.toDateString() !== modelData.end.toDateString() || modelData.start.getTime() !== modelData.end.getTime()) {
                                    return startTime + " – " + Qt.formatTime(modelData.end, timeFormat);
                                }
                                return startTime;
                            }
                            return "";
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
                                console.warn("Failed to open URL: " + modelData.url);
                            } else {
                                root.closeDash();
                            }
                        }
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
