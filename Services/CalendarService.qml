pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool khalAvailable: false
    property var eventsByDate: ({})
    property bool isLoading: false
    property string lastError: ""
    property date lastStartDate
    property date lastEndDate
    property string khalDateFormat: "MM/dd/yyyy"

    function checkKhalAvailability() {
        if (!khalCheckProcess.running)
            khalCheckProcess.running = true
    }

    function detectKhalDateFormat() {
        if (!khalFormatProcess.running)
            khalFormatProcess.running = true
    }

    function parseKhalDateFormat(formatExample) {
        let qtFormat = formatExample.replace("12", "MM").replace("21", "dd").replace("2013", "yyyy")
        return { format: qtFormat, parser: null }
    }


    function loadCurrentMonth() {
        if (!root.khalAvailable)
            return

        let today = new Date()
        let firstDay = new Date(today.getFullYear(), today.getMonth(), 1)
        let lastDay = new Date(today.getFullYear(), today.getMonth() + 1, 0)
        // Add padding
        let startDate = new Date(firstDay)
        startDate.setDate(startDate.getDate() - firstDay.getDay() - 7)
        let endDate = new Date(lastDay)
        endDate.setDate(endDate.getDate() + (6 - lastDay.getDay()) + 7)
        loadEvents(startDate, endDate)
    }

    function loadEvents(startDate, endDate) {
        if (!root.khalAvailable) {
            return
        }
        if (eventsProcess.running) {
            return
        }
        // Store last requested date range for refresh timer
        root.lastStartDate = startDate
        root.lastEndDate = endDate
        root.isLoading = true
        // Format dates for khal using detected format
        let startDateStr = Qt.formatDate(startDate, root.khalDateFormat)
        let endDateStr = Qt.formatDate(endDate, root.khalDateFormat)
        eventsProcess.requestStartDate = startDate
        eventsProcess.requestEndDate = endDate
        eventsProcess.command = ["khal", "list", "--json", "title", "--json", "description", "--json", "start-date", "--json", "start-time", "--json", "end-date", "--json", "end-time", "--json", "all-day", "--json", "location", "--json", "url", startDateStr, endDateStr]
        eventsProcess.running = true
    }

    function getEventsForDate(date) {
        let dateKey = Qt.formatDate(date, "yyyy-MM-dd")
        return root.eventsByDate[dateKey] || []
    }

    function hasEventsForDate(date) {
        let events = getEventsForDate(date)
        return events.length > 0
    }

    // Initialize on component completion
    Component.onCompleted: {
        detectKhalDateFormat()
    }

    // Process for detecting khal date format
    Process {
        id: khalFormatProcess

        command: ["khal", "printformats"]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                checkKhalAvailability()
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.split('\n')
                for (let line of lines) {
                    if (line.startsWith('dateformat:')) {
                        let formatExample = line.substring(line.indexOf(':') + 1).trim()
                        let formatInfo = parseKhalDateFormat(formatExample)
                        root.khalDateFormat = formatInfo.format
                        break
                    }
                }
                checkKhalAvailability()
            }
        }
    }

    // Process for checking khal configuration
    Process {
        id: khalCheckProcess

        command: ["khal", "list", "today"]
        running: false
        onExited: exitCode => {
            root.khalAvailable = (exitCode === 0)
            if (exitCode === 0) {
                loadCurrentMonth()
            }
        }
    }

    // Process for loading events
    Process {
        id: eventsProcess

        property date requestStartDate
        property date requestEndDate
        property string rawOutput: ""

        running: false
        onExited: exitCode => {
            root.isLoading = false
            if (exitCode !== 0) {
                root.lastError = "Failed to load events (exit code: " + exitCode + ")"
                return
            }
            try {
                let newEventsByDate = {}
                let lines = eventsProcess.rawOutput.split('\n')
                for (let line of lines) {
                    line = line.trim()
                    if (!line || line === "[]")
                    continue

                    // Parse JSON line
                    let dayEvents = JSON.parse(line)
                    // Process each event in this day's array
                    for (let event of dayEvents) {
                        if (!event.title)
                        continue

                        // Parse start and end dates using detected format
                        let startDate, endDate
                        if (event['start-date']) {
                            startDate = Date.fromLocaleString(Qt.locale(), event['start-date'], root.khalDateFormat)
                        } else {
                            startDate = new Date()
                        }
                        if (event['end-date']) {
                            endDate = Date.fromLocaleString(Qt.locale(), event['end-date'], root.khalDateFormat)
                        } else {
                            endDate = new Date(startDate)
                        }
                        // Create start/end times
                        let startTime = new Date(startDate)
                        let endTime = new Date(endDate)
                        if (event['start-time']
                            && event['all-day'] !== "True") {
                            // Parse time if available and not all-day
                            let timeStr = event['start-time']
                            if (timeStr) {
                                // Match time with optional seconds and AM/PM
                                let timeParts = timeStr.match(/(\d+):(\d+)(?::\d+)?\s*(AM|PM)?/i)
                                if (timeParts) {
                                    let hours = parseInt(timeParts[1])
                                    let minutes = parseInt(timeParts[2])

                                    // Handle AM/PM conversion if present
                                    if (timeParts[3]) {
                                        let period = timeParts[3].toUpperCase()
                                        if (period === 'PM' && hours !== 12) {
                                            hours += 12
                                        } else if (period === 'AM' && hours === 12) {
                                            hours = 0
                                        }
                                    }

                                    startTime.setHours(hours, minutes)
                                    if (event['end-time']) {
                                        let endTimeParts = event['end-time'].match(
                                            /(\d+):(\d+)(?::\d+)?\s*(AM|PM)?/i)
                                        if (endTimeParts) {
                                            let endHours = parseInt(endTimeParts[1])
                                            let endMinutes = parseInt(endTimeParts[2])

                                            // Handle AM/PM conversion if present
                                            if (endTimeParts[3]) {
                                                let endPeriod = endTimeParts[3].toUpperCase()
                                                if (endPeriod === 'PM' && endHours !== 12) {
                                                    endHours += 12
                                                } else if (endPeriod === 'AM' && endHours === 12) {
                                                    endHours = 0
                                                }
                                            }

                                            endTime.setHours(endHours, endMinutes)
                                        }
                                    } else {
                                        // Default to 1 hour duration on same day
                                        endTime = new Date(startTime)
                                        endTime.setHours(
                                            startTime.getHours() + 1)
                                    }
                                }
                            }
                        }
                        // Create unique ID for this event (to track multi-day events)
                        let eventId = event.title + "_" + event['start-date']
                        + "_" + (event['start-time'] || 'allday')
                        // Create event object template
                        let eventTemplate = {
                            "id": eventId,
                            "title": event.title || "Untitled Event",
                            "start": startTime,
                            "end": endTime,
                            "location": event.location || "",
                            "description": event.description || "",
                            "url": event.url || "",
                            "calendar": "",
                            "color": "",
                            "allDay": event['all-day'] === "True",
                            "isMultiDay": startDate.toDateString(
                                              ) !== endDate.toDateString()
                        }
                        // Add event to each day it spans
                        let currentDate = new Date(startDate)
                        while (currentDate <= endDate) {
                            let dateKey = Qt.formatDate(currentDate,
                                                        "yyyy-MM-dd")
                            if (!newEventsByDate[dateKey])
                            newEventsByDate[dateKey] = []

                            // Check if this exact event is already added to this date (prevent duplicates)
                            let existingEvent = newEventsByDate[dateKey].find(
                                e => {
                                    return e.id === eventId
                                })
                            if (existingEvent) {
                                // Move to next day without adding duplicate
                                currentDate.setDate(currentDate.getDate() + 1)
                                continue
                            }
                            // Create a copy of the event for this date
                            let dayEvent = Object.assign({}, eventTemplate)
                            // For multi-day events, adjust the display time for this specific day
                            if (currentDate.getTime() === startDate.getTime()) {
                                // First day - use original start time
                                dayEvent.start = new Date(startTime)
                            } else {
                                // Subsequent days - start at beginning of day for all-day events
                                dayEvent.start = new Date(currentDate)
                                if (!dayEvent.allDay)
                                dayEvent.start.setHours(0, 0, 0, 0)
                            }
                            if (currentDate.getTime() === endDate.getTime()) {
                                // Last day - use original end time
                                dayEvent.end = new Date(endTime)
                            } else {
                                // Earlier days - end at end of day for all-day events
                                dayEvent.end = new Date(currentDate)
                                if (!dayEvent.allDay)
                                dayEvent.end.setHours(23, 59, 59, 999)
                            }
                            newEventsByDate[dateKey].push(dayEvent)
                            // Move to next day
                            currentDate.setDate(currentDate.getDate() + 1)
                        }
                    }
                }
                // Sort events by start time within each date
                for (let dateKey in newEventsByDate) {
                    newEventsByDate[dateKey].sort((a, b) => {
                                                      return a.start.getTime(
                                                          ) - b.start.getTime()
                                                  })
                }
                root.eventsByDate = newEventsByDate
                root.lastError = ""
            } catch (error) {
                root.lastError = "Failed to parse events JSON: " + error.toString()
                root.eventsByDate = {}
            }
            // Reset for next run
            eventsProcess.rawOutput = ""
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                eventsProcess.rawOutput += data + "\n"
            }
        }
    }
}
