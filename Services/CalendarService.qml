import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    property bool khalAvailable: false
    property var eventsByDate: ({})
    property bool isLoading: false
    property string lastError: ""
    
    // Periodic refresh timer
    Timer {
        id: refreshTimer
        interval: 60000
        running: root.khalAvailable
        repeat: true
        onTriggered: {
            if (lastStartDate && lastEndDate) {
                loadEvents(lastStartDate, lastEndDate)
            }
        }
    }
    
    property date lastStartDate
    property date lastEndDate
    
    // Process for checking khal configuration
    Process {
        id: khalCheckProcess
        command: ["khal", "list", "today"]
        running: false
        
        onExited: (exitCode) => {
            root.khalAvailable = (exitCode === 0)
            if (exitCode !== 0) {
                console.warn("CalendarService: khal not configured (exit code:", exitCode, ")")
            } else {
                console.log("CalendarService: khal configured and available")
                // Load current month events when khal becomes available
                loadCurrentMonth()
            }
        }
        
        onStarted: {
            console.log("CalendarService: Checking khal configuration...")
        }
    }
    
    // Process for loading events
    Process {
        id: eventsProcess
        running: false
        
        property date requestStartDate
        property date requestEndDate
        property string rawOutput: ""
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                eventsProcess.rawOutput += data + "\n"
            }
        }
        
        onExited: (exitCode) => {
            root.isLoading = false
            
            if (exitCode !== 0) {
                root.lastError = "Failed to load events (exit code: " + exitCode + ")"
                console.warn("CalendarService:", root.lastError)
                return
            }
            
            try {
                let newEventsByDate = {}
                let lines = eventsProcess.rawOutput.split('\n')
                
                for (let line of lines) {
                    line = line.trim()
                    if (!line || line === "[]") continue
                    
                    // Parse JSON line
                    let dayEvents = JSON.parse(line)
                    
                    // Process each event in this day's array
                    for (let event of dayEvents) {
                        if (!event.title) continue
                        
                        // Parse start and end dates
                        let startDate, endDate
                        if (event['start-date']) {
                            let startParts = event['start-date'].split('/')
                            startDate = new Date(parseInt(startParts[2]), parseInt(startParts[0]) - 1, parseInt(startParts[1]))
                        } else {
                            startDate = new Date()
                        }
                        
                        if (event['end-date']) {
                            let endParts = event['end-date'].split('/')
                            endDate = new Date(parseInt(endParts[2]), parseInt(endParts[0]) - 1, parseInt(endParts[1]))
                        } else {
                            endDate = new Date(startDate)
                        }
                        
                        // Create start/end times
                        let startTime = new Date(startDate)
                        let endTime = new Date(endDate)
                        
                        if (event['start-time'] && event['all-day'] !== "True") {
                            // Parse time if available and not all-day
                            let timeStr = event['start-time']
                            if (timeStr) {
                                let timeParts = timeStr.match(/(\d+):(\d+)/)
                                if (timeParts) {
                                    startTime.setHours(parseInt(timeParts[1]), parseInt(timeParts[2]))
                                    
                                    if (event['end-time']) {
                                        let endTimeParts = event['end-time'].match(/(\d+):(\d+)/)
                                        if (endTimeParts) {
                                            endTime.setHours(parseInt(endTimeParts[1]), parseInt(endTimeParts[2]))
                                        }
                                    } else {
                                        // Default to 1 hour duration on same day
                                        endTime = new Date(startTime)
                                        endTime.setHours(startTime.getHours() + 1)
                                    }
                                }
                            }
                        }
                        
                        // Create unique ID for this event (to track multi-day events)
                        let eventId = event.title + "_" + event['start-date'] + "_" + (event['start-time'] || 'allday')
                        
                        // Create event object template
                        let eventTemplate = {
                            id: eventId,
                            title: event.title || "Untitled Event",
                            start: startTime,
                            end: endTime,
                            location: event.location || "",
                            description: event.description || "",
                            url: event.url || "",
                            calendar: "",
                            color: "",
                            allDay: event['all-day'] === "True",
                            isMultiDay: startDate.toDateString() !== endDate.toDateString()
                        }
                        
                        // Add event to each day it spans
                        let currentDate = new Date(startDate)
                        while (currentDate <= endDate) {
                            let dateKey = Qt.formatDate(currentDate, "yyyy-MM-dd")
                            
                            if (!newEventsByDate[dateKey]) {
                                newEventsByDate[dateKey] = []
                            }
                            
                            // Check if this exact event is already added to this date (prevent duplicates)
                            let existingEvent = newEventsByDate[dateKey].find(e => e.id === eventId)
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
                                if (!dayEvent.allDay) {
                                    dayEvent.start.setHours(0, 0, 0, 0)
                                }
                            }
                            
                            if (currentDate.getTime() === endDate.getTime()) {
                                // Last day - use original end time
                                dayEvent.end = new Date(endTime)
                            } else {
                                // Earlier days - end at end of day for all-day events
                                dayEvent.end = new Date(currentDate)
                                if (!dayEvent.allDay) {
                                    dayEvent.end.setHours(23, 59, 59, 999)
                                }
                            }
                            
                            newEventsByDate[dateKey].push(dayEvent)
                            
                            // Move to next day
                            currentDate.setDate(currentDate.getDate() + 1)
                        }
                    }
                }
                
                // Sort events by start time within each date
                for (let dateKey in newEventsByDate) {
                    newEventsByDate[dateKey].sort((a, b) => a.start.getTime() - b.start.getTime())
                }
                
                root.eventsByDate = newEventsByDate
                root.lastError = ""
                
                console.log("CalendarService: Loaded events for", Object.keys(newEventsByDate).length, "days")
                
                // Debug: log parsed events
                for (let dateKey in newEventsByDate) {
                    console.log("  " + dateKey + ":", newEventsByDate[dateKey].map(e => e.title).join(", "))
                }
                
            } catch (error) {
                root.lastError = "Failed to parse events JSON: " + error.toString()
                console.error("CalendarService:", root.lastError)
                console.error("CalendarService: Raw output was:", eventsProcess.rawOutput)
                root.eventsByDate = {}
            }
            
            // Reset for next run
            eventsProcess.rawOutput = ""
        }
        
        onStarted: {
            console.log("CalendarService: Loading events from", Qt.formatDate(requestStartDate, "yyyy-MM-dd"), 
                       "to", Qt.formatDate(requestEndDate, "yyyy-MM-dd"))
        }
    }
    
    function checkKhalAvailability() {
        if (!khalCheckProcess.running) {
            khalCheckProcess.running = true
        }
    }
    
    function loadCurrentMonth() {
        if (!root.khalAvailable) return
        
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
            console.warn("CalendarService: khal not available, skipping event loading")
            return
        }
        
        if (eventsProcess.running) {
            console.log("CalendarService: Event loading already in progress, skipping...")
            return
        }
        
        // Store last requested date range for refresh timer
        root.lastStartDate = startDate
        root.lastEndDate = endDate
        
        root.isLoading = true
        
        // Format dates for khal (MM/dd/yyyy based on printformats)
        let startDateStr = Qt.formatDate(startDate, "MM/dd/yyyy")
        let endDateStr = Qt.formatDate(endDate, "MM/dd/yyyy")
        
        eventsProcess.requestStartDate = startDate
        eventsProcess.requestEndDate = endDate
        eventsProcess.command = [
            "khal", "list",
            "--json", "title",
            "--json", "description", 
            "--json", "start-date",
            "--json", "start-time",
            "--json", "end-date",
            "--json", "end-time",
            "--json", "all-day",
            "--json", "location",
            "--json", "url",
            startDateStr, endDateStr
        ]
        
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
        console.log("CalendarService: Component completed, initializing...")
        checkKhalAvailability()
    }
}