pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Item {
    id: root
    readonly property var log: Log.scoped("CalendarDankBackend")

    property bool enabled: false

    property string socketPath: ""
    readonly property bool socketFound: socketPath.length > 0
    property bool connected: false
    property bool binaryExists: false
    property bool binaryChecked: false

    property var calendars: []
    property var events: []
    property var eventsByDate: ({})
    property string lastError: ""
    property date focusDate: new Date()
    property var _loadedFrom: null
    property var _loadedTo: null

    property var pendingRequests: ({})
    property int requestCounter: 0

    readonly property var fallbackPalette: ["#7287fd", "#f38ba8", "#a6e3a1", "#fab387", "#cba6f7", "#94e2d5", "#f9e2af", "#89dceb"]

    signal eventsUpdated

    onEnabledChanged: {
        if (enabled) {
            if (!connected)
                discoverProcess.running = true;
            return;
        }
        requestSocket.connected = false;
        subscribeSocket.connected = false;
        socketPath = "";
        connected = false;
    }

    Component.onCompleted: {
        binaryCheck.running = true;
        discoverProcess.running = true;
    }

    Process {
        id: binaryCheck
        command: ["sh", "-c", "command -v dcal"]
        running: false
        onExited: code => {
            root.binaryExists = (code === 0);
            root.binaryChecked = true;
        }
    }

    Process {
        id: discoverProcess
        running: false
        command: ["sh", "-c", "s=\"${DANKCAL_SOCKET:-}\"; if [ -S \"$s\" ]; then echo \"$s\"; exit 0; fi; for f in \"${XDG_RUNTIME_DIR:-/tmp}\"/dankcal-*.sock /tmp/dankcal-*.sock; do [ -S \"$f\" ] || continue; p=$(basename \"$f\" .sock); p=${p#dankcal-}; if kill -0 \"$p\" 2>/dev/null; then echo \"$f\"; exit 0; fi; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim().split('\n')[0] || "";
                if (path.length > 0) {
                    root._applySocketPath(path);
                    return;
                }
                if (!root.connected) {
                    if (root.socketPath !== "")
                        root.log.info("dankcal socket gone, waiting for daemon");
                    requestSocket.connected = false;
                    subscribeSocket.connected = false;
                    root.socketPath = "";
                }
            }
        }
    }

    Timer {
        id: rediscoverTimer
        interval: 3000
        repeat: true
        running: root.enabled && !root.connected
        onTriggered: {
            if (!discoverProcess.running)
                discoverProcess.running = true;
        }
    }

    function launch() {
        if (!binaryExists)
            return;
        Quickshell.execDetached(["dcal", "run", "-d", "--hidden"]);
        if (enabled && !connected)
            discoverProcess.running = true;
    }

    function _applySocketPath(path) {
        const changed = path !== socketPath;
        if (changed)
            log.info("dankcal socket discovered:", path);
        if (!changed && connected)
            return;
        socketPath = path;
        _reconnect();
    }

    function _reconnect() {
        requestSocket.connected = false;
        subscribeSocket.connected = false;
        Qt.callLater(() => requestSocket.connected = true);
    }

    DankSocket {
        id: requestSocket
        path: root.socketPath
        connected: false

        onConnectionStateChanged: {
            if (linkUp) {
                root.connected = true;
                subscribeSocket.connected = true;
                root.log.info("connected to dankcal:", root.socketPath);
                root.refreshCalendars();
                root.reloadEvents();
                return;
            }
            if (!root.connected && !root.socketFound)
                return;
            root.connected = false;
            root._flushPending();
            requestSocket.connected = false;
            subscribeSocket.connected = false;
            root.log.info("dankcal disconnected, rediscovering");
            if (root.enabled)
                discoverProcess.running = true;
        }

        parser: SplitParser {
            onRead: line => {
                if (!line || line.length === 0)
                    return;
                let response;
                try {
                    response = JSON.parse(line);
                } catch (e) {
                    return;
                }
                root._handleResponse(response);
            }
        }
    }

    DankSocket {
        id: subscribeSocket
        path: root.socketPath
        connected: false

        onConnectionStateChanged: {
            if (linkUp)
                root._sendSubscribe();
        }

        parser: SplitParser {
            onRead: line => {
                if (!line || line.length === 0)
                    return;
                let event;
                try {
                    event = JSON.parse(line);
                } catch (e) {
                    return;
                }
                root._handleEvent(event);
            }
        }
    }

    Timer {
        id: refreshDebounce
        interval: 400
        repeat: false
        onTriggered: {
            root.refreshCalendars();
            root.reloadEvents();
        }
    }

    function _sendSubscribe() {
        subscribeSocket.send({
            "id": _nextId(),
            "method": "subscribe",
            "params": {
                "topics": ["accounts", "calendars", "events", "sync"]
            }
        });
    }

    function _nextId() {
        requestCounter++;
        return Date.now() + requestCounter;
    }

    function _flushPending() {
        const ids = Object.keys(pendingRequests);
        for (const id of ids) {
            const cb = pendingRequests[id];
            delete pendingRequests[id];
            if (cb)
                cb({
                    "error": "disconnected"
                });
        }
    }

    function _handleResponse(response) {
        if (response.event) {
            _handleEvent(response);
            return;
        }
        const id = response.id;
        if (!id)
            return;
        const cb = pendingRequests[id];
        if (cb) {
            delete pendingRequests[id];
            cb(response);
        }
    }

    function _handleEvent(event) {
        switch (event.event) {
        case "accounts":
        case "calendars":
            refreshCalendars();
            refreshDebounce.restart();
            break;
        case "events":
        case "sync":
            refreshDebounce.restart();
            break;
        }
    }

    function sendRequest(method, params, callback) {
        if (!connected) {
            if (callback)
                callback({
                    "error": "not connected to dankcal socket"
                });
            return;
        }
        const id = _nextId();
        const req = {
            "id": id,
            "method": method
        };
        if (params)
            req.params = params;
        if (callback)
            pendingRequests[id] = callback;
        requestSocket.send(req);
    }

    function refreshCalendars() {
        sendRequest("calendars.list", null, response => {
            if (response.error) {
                lastError = response.error;
                return;
            }
            const list = response.result || [];
            for (let i = 0; i < list.length; i++) {
                if (!list[i].color)
                    list[i].color = fallbackPalette[i % fallbackPalette.length];
            }
            calendars = list;
            _rebuildEventsByDate();
        });
    }

    function calendarById(id) {
        for (let i = 0; i < calendars.length; i++) {
            if (calendars[i].id === id)
                return calendars[i];
        }
        return null;
    }

    function writableCalendars() {
        return calendars.filter(c => !c.readOnly);
    }

    function defaultCalendar() {
        const writable = writableCalendars().filter(c => !c.hidden);
        return writable.length > 0 ? writable[0] : null;
    }

    function loadEvents(startDate, endDate) {
        const mid = new Date((startDate.getTime() + endDate.getTime()) / 2);
        focusDate = mid;
        _ensureWindow();
    }

    function _ensureWindow() {
        if (!connected)
            return;
        if (!_loadedFrom || !_loadedTo) {
            reloadEvents();
            return;
        }
        const margin = 14 * 86400000;
        const t = focusDate.getTime();
        if (t < _loadedFrom.getTime() + margin || t > _loadedTo.getTime() - margin)
            reloadEvents();
        else
            _rebuildEventsByDate();
    }

    function reloadEvents() {
        if (!connected)
            return;
        const from = new Date(focusDate.getTime() - 60 * 86400000);
        const to = new Date(focusDate.getTime() + 90 * 86400000);
        sendRequest("events.list", {
            "from": from.toISOString(),
            "to": to.toISOString(),
            "limit": 5000
        }, response => {
            if (response.error) {
                lastError = response.error;
                return;
            }
            _loadedFrom = from;
            _loadedTo = to;
            const raw = (response.result || {}).events || [];
            events = raw.map(e => _normalizeEvent(e));
            _rebuildEventsByDate();
        });
    }

    function _dayBoundary(iso) {
        const d = new Date(iso);
        return new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
    }

    function _normalizeEvent(e) {
        const allDay = !!e.allDay;
        const id = e.id || "";
        if (id.startsWith("task_"))
            log.warn("daemon event id collides with task prefix:", id);
        return {
            "id": id,
            "calendarId": e.calendarId || "",
            "title": e.summary || "(untitled)",
            "description": e.description || "",
            "location": e.location || "",
            "url": e.url || "",
            "start": allDay ? _dayBoundary(e.start) : new Date(e.start),
            "end": allDay ? _dayBoundary(e.end) : new Date(e.end),
            "allDay": allDay,
            "status": e.status || "confirmed",
            "recurringId": e.recurringId || "",
            "attendees": e.attendees || [],
            "organizer": e.organizer || null,
            "reminders": e.reminders || []
        };
    }

    function decorateEvent(ev) {
        const cal = calendarById(ev.calendarId);
        const out = Object.assign({}, ev);
        out.color = cal ? cal.color : fallbackPalette[0];
        out.calendar = cal ? cal.name : "";
        out.account = cal ? (cal.accountName || cal.accountId || "") : "";
        out.readOnly = cal ? !!cal.readOnly : false;
        out.isMultiDay = ev.start.toDateString() !== ev.end.toDateString();
        return out;
    }

    function _hiddenCalendarIds() {
        const hidden = {};
        for (let i = 0; i < calendars.length; i++) {
            if (calendars[i].hidden)
                hidden[calendars[i].id] = true;
        }
        return hidden;
    }

    function _clampForDay(ev, cur, endDay) {
        const out = Object.assign({}, ev);
        const dayStart = new Date(cur.getFullYear(), cur.getMonth(), cur.getDate());
        const startDay = new Date(ev.start.getFullYear(), ev.start.getMonth(), ev.start.getDate());
        if (dayStart.getTime() === startDay.getTime()) {
            out.start = new Date(ev.start);
        } else {
            out.start = new Date(dayStart);
            if (!ev.allDay)
                out.start.setHours(0, 0, 0, 0);
        }
        if (dayStart.getTime() === endDay.getTime()) {
            out.end = new Date(ev.end);
        } else {
            out.end = new Date(dayStart);
            if (!ev.allDay)
                out.end.setHours(23, 59, 59, 999);
        }
        return out;
    }

    function _rebuildEventsByDate() {
        const hidden = _hiddenCalendarIds();
        const map = {};
        for (const raw of events) {
            if (raw.status === "cancelled")
                continue;
            if (hidden[raw.calendarId])
                continue;
            const ev = decorateEvent(raw);
            const lastInstant = ev.allDay ? new Date(ev.end.getTime() - 1) : ev.end;
            let cur = new Date(ev.start.getFullYear(), ev.start.getMonth(), ev.start.getDate());
            let endDay = new Date(lastInstant.getFullYear(), lastInstant.getMonth(), lastInstant.getDate());
            if (endDay < cur)
                endDay = new Date(cur);
            while (cur <= endDay) {
                const key = Qt.formatDate(cur, "yyyy-MM-dd");
                if (!map[key])
                    map[key] = [];
                if (!map[key].some(e => e.id === ev.id))
                    map[key].push(_clampForDay(ev, cur, endDay));
                cur.setDate(cur.getDate() + 1);
            }
        }
        eventsByDate = map;
        eventsUpdated();
    }

    function createEvent(fields, callback) {
        sendRequest("events.create", fields, response => {
            if (response.error)
                lastError = response.error;
            else
                reloadEvents();
            if (callback)
                callback(response);
        });
    }

    function updateEvent(id, fields, callback) {
        const params = Object.assign({
            "id": id
        }, fields);
        sendRequest("events.update", params, response => {
            if (response.error)
                lastError = response.error;
            else
                reloadEvents();
            if (callback)
                callback(response);
        });
    }

    function deleteEvent(id, callback) {
        sendRequest("events.delete", {
            "id": id
        }, response => {
            if (response.error)
                lastError = response.error;
            else
                reloadEvents();
            if (callback)
                callback(response);
        });
    }
}
