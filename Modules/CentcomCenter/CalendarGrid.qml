import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: calendarGrid

    property date displayDate: new Date()
    property date selectedDate: new Date()

    function loadEventsForMonth() {
        if (!CalendarService || !CalendarService.khalAvailable)
            return

        let firstDay = new Date(displayDate.getFullYear(),
                                displayDate.getMonth(), 1)
        let dayOfWeek = firstDay.getDay()
        let startDate = new Date(firstDay)
        startDate.setDate(startDate.getDate(
                              ) - dayOfWeek - 7) // Extra week padding
        let lastDay = new Date(displayDate.getFullYear(),
                               displayDate.getMonth() + 1, 0)
        let endDate = new Date(lastDay)
        endDate.setDate(endDate.getDate() + (6 - lastDay.getDay(
                                                 )) + 7) // Extra week padding
        CalendarService.loadEvents(startDate, endDate)
    }

    spacing: Theme.spacingM
    onDisplayDateChanged: {
        loadEventsForMonth()
    }
    Component.onCompleted: {
        loadEventsForMonth()
    }

    Connections {
        function onKhalAvailableChanged() {
            if (CalendarService && CalendarService.khalAvailable)
                loadEventsForMonth()
        }

        target: CalendarService
        enabled: CalendarService !== null
    }

    Row {
        width: parent.width
        height: 40

        Rectangle {
            width: 40
            height: 40
            radius: Theme.cornerRadius
            color: prevMonthArea.containsMouse ? Qt.rgba(Theme.primary.r,
                                                         Theme.primary.g,
                                                         Theme.primary.b,
                                                         0.12) : "transparent"

            DankIcon {
                anchors.centerIn: parent
                name: "chevron_left"
                size: Theme.iconSize
                color: Theme.primary
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

        StyledText {
            width: parent.width - 80
            height: 40
            text: displayDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.surfaceText
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Rectangle {
            width: 40
            height: 40
            radius: Theme.cornerRadius
            color: nextMonthArea.containsMouse ? Qt.rgba(Theme.primary.r,
                                                         Theme.primary.g,
                                                         Theme.primary.b,
                                                         0.12) : "transparent"

            DankIcon {
                anchors.centerIn: parent
                name: "chevron_right"
                size: Theme.iconSize
                color: Theme.primary
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

    Row {
        width: parent.width
        height: 32

        Repeater {
            model: {
                var days = []
                var locale = Qt.locale()
                for (var i = 0; i < 7; i++) {
                    var date = new Date(2024, 0, 7 + i)
                    days.push(locale.dayName(i, Locale.ShortFormat))
                }
                return days
            }

            Rectangle {
                width: parent.width / 7
                height: 32
                color: "transparent"

                StyledText {
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: Theme.fontSizeSmall
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g,
                                   Theme.surfaceText.b, 0.6)
                    font.weight: Font.Medium
                }
            }
        }
    }

    Grid {
        property date firstDay: {
            let date = new Date(displayDate.getFullYear(),
                                displayDate.getMonth(), 1)
            let dayOfWeek = date.getDay()
            date.setDate(date.getDate() - dayOfWeek)
            return date
        }

        width: parent.width
        height: 200 // Fixed height for calendar
        columns: 7
        rows: 6

        Repeater {
            model: 42

            Rectangle {
                property date dayDate: {
                    let date = new Date(parent.firstDay)
                    date.setDate(date.getDate() + index)
                    return date
                }
                property bool isCurrentMonth: dayDate.getMonth(
                                                  ) === displayDate.getMonth()
                property bool isToday: dayDate.toDateString(
                                           ) === new Date().toDateString()
                property bool isSelected: dayDate.toDateString(
                                              ) === selectedDate.toDateString()

                width: parent.width / 7
                height: parent.height / 6
                color: "transparent"
                clip: true

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 4
                    height: parent.height - 4
                    color: isSelected ? Theme.primary : isToday ? Qt.rgba(
                                                                      Theme.primary.r,
                                                                      Theme.primary.g,
                                                                      Theme.primary.b,
                                                                      0.12) : dayArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                    radius: Theme.cornerRadius
                    clip: true

                    StyledText {
                        anchors.centerIn: parent
                        text: dayDate.getDate()
                        font.pixelSize: Theme.fontSizeMedium
                        color: isSelected ? Theme.surface : isToday ? Theme.primary : isCurrentMonth ? Theme.surfaceText : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                        font.weight: isToday
                                     || isSelected ? Font.Medium : Font.Normal
                    }

                    Rectangle {
                        id: eventIndicator

                        anchors.fill: parent
                        radius: parent.radius
                        visible: CalendarService
                                 && CalendarService.khalAvailable
                                 && CalendarService.hasEventsForDate(dayDate)
                        opacity: {
                            if (isSelected)
                                return 0.9
                            else if (isToday)
                                return 0.8
                            else
                                return 0.6
                        }

                        gradient: Gradient {
                            GradientStop {
                                position: 0.89
                                color: "transparent"
                            }

                            GradientStop {
                                position: 0.9
                                color: {
                                    if (isSelected)
                                        return Qt.lighter(Theme.primary, 1.3)
                                    else if (isToday)
                                        return Theme.primary
                                    else
                                        return Theme.primary
                                }
                            }

                            GradientStop {
                                position: 1
                                color: {
                                    if (isSelected)
                                        return Qt.lighter(Theme.primary, 1.3)
                                    else if (isToday)
                                        return Theme.primary
                                    else
                                        return Theme.primary
                                }
                            }
                        }

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
                        selectedDate = dayDate
                    }
                }
            }
        }
    }
}
