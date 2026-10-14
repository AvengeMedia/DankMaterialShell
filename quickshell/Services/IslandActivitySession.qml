pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Notifications
import qs.Common
import "../Common/IslandActivities.js" as Activities

QtObject {
    id: root

    required property string screenName
    required property string barId
    property bool enabled: true
    property bool notificationsEnabled: true
    property bool blocked: false
    property bool held: false
    property var excludedSources: []
    property var sourceOverrides: ({})
    property int slotLimit: 3
    property int defaultDuration: 5000
    readonly property string hostKey: JSON.stringify([screenName, barId])
    readonly property var stableEntries: enabled ? Activities.stableEntries(IslandActivityService.entries, screenName, barId, excludedSources, sourceOverrides, slotLimit) : []
    property var queue: []
    property var current: null
    property int remaining: 0
    property double deadline: 0
    property bool registered: false
    signal openRequested(var entry)

    function accepts(entry) {
        return enabled && Activities.matches(entry, screenName, barId, excludedSources);
    }

    function contains(entry) {
        const key = Activities.identity(entry);
        return Activities.identity(current) === key || queue.some(item => Activities.identity(item) === key);
    }

    function canEnqueue(entry) {
        return contains(entry) || queue.length < 64;
    }

    function enqueue(entry) {
        if (!accepts(entry))
            return;
        if (!entry.durationSpecified)
            entry = Object.assign({}, entry, {duration: defaultDuration});
        if (Activities.identity(current) === Activities.identity(entry)) {
            current = entry.restartPreview ? entry : Object.assign({}, entry, {duration: current.duration});
            if (entry.announce && entry.restartPreview) {
                remaining = entry.duration;
                deadline = 0;
                syncTimer();
            }
            return;
        }
        queue = Activities.enqueue(queue, entry);
        if (shouldPreempt(entry))
            suspendCurrent();
        advance();
    }

    function enqueueSystem(activityId, duration) {
        if (!enabled || !Activities.validId(activityId))
            return false;
        const entry = Activities.normalize("system", activityId, {
            title: activityId,
            category: "system",
            priorityClass: "high",
            preemption: "higher",
            duration: duration
        }, Date.now());
        if (!entry)
            return false;
        entry.kind = "system";
        entry.systemActivity = activityId;
        entry.durationSpecified = true;
        if (Activities.identity(current) === Activities.identity(entry)) {
            current = entry;
            remaining = entry.duration;
            deadline = 0;
            syncTimer();
            return true;
        }
        if (!contains(entry) && queue.length >= 64)
            return false;
        queue = Activities.enqueue(queue, entry);
        if (shouldPreempt(entry))
            suspendCurrent();
        advance();
        return true;
    }

    function shouldPreempt(entry) {
        return !!current && entry.preemption === "higher" && entry.priority > current.priority;
    }

    function suspendCurrent() {
        if (!current)
            return;
        const suspended = Object.assign({}, current, {
            duration: Math.max(1, deadline ? deadline - Date.now() : remaining),
            durationSpecified: true,
            resumed: true
        });
        timeout.stop();
        deadline = 0;
        remaining = 0;
        current = null;
        queue = Activities.enqueue(queue, suspended);
    }

    function enqueueNotification(wrapper) {
        if (!notificationsEnabled || !wrapper || contains({source: "notifications", id: String(wrapper.seq)}))
            return;
        const duration = wrapper.timer?.interval ?? 5000;
        const critical = wrapper.urgency === NotificationUrgency.Critical;
        const entry = {source: "notifications", id: String(wrapper.seq), kind: "notification", wrapper: wrapper, title: wrapper.summary, duration: duration, priorityClass: critical ? "critical" : "normal", priority: critical ? 100 : 0, preemption: critical ? "higher" : "never", announce: true};
        if (queue.length >= 64)
            return;
        wrapper.timer?.stop();
        queue = Activities.enqueue(queue, entry);
        if (shouldPreempt(entry))
            suspendCurrent();
        advance();
        // NotificationService starts the wrapper timer after emitting its visible-list update.
        Qt.callLater(() => {
            if (root.contains(entry))
                wrapper.timer?.stop();
        });
    }

    function advance() {
        if (current)
            return;
        const next = Activities.nextEvent(queue);
        if (!next || (blocked && next.priorityClass !== "critical"))
            return;
        queue = queue.filter(entry => entry !== next);
        remaining = next.duration;
        deadline = 0;
        current = next;
        syncTimer();
    }

    function cancelMissingNotifications(visible) {
        queue = queue.filter(entry => entry.kind !== "notification" || visible.indexOf(entry.wrapper) >= 0);
        if (current?.kind === "notification" && visible.indexOf(current.wrapper) < 0)
            finishCurrent(current);
    }

    function refreshNotification(wrapper) {
        const duration = wrapper?.timer?.interval ?? 5000;
        queue = queue.map(entry => entry.kind === "notification" && entry.wrapper === wrapper ? Object.assign({}, entry, {duration: duration}) : entry);
        if (current?.kind !== "notification" || current.wrapper !== wrapper)
            return;
        current = Object.assign({}, current, {duration: duration});
        remaining = duration;
        deadline = 0;
        syncTimer();
    }

    function syncTimer() {
        const now = Date.now();
        if (deadline)
            remaining = Math.max(0, deadline - now);
        deadline = 0;
        timeout.stop();
        if (!current || held || current.duration <= 0)
            return;
        if (remaining <= 0) {
            finishCurrent(current);
            return;
        }
        deadline = now + remaining;
        timeout.interval = remaining;
        timeout.start();
    }

    function finishCurrent(expected) {
        if (!current || (expected && Activities.identity(expected) !== Activities.identity(current)))
            return false;
        const finished = current;
        timeout.stop();
        deadline = 0;
        current = null;
        remaining = 0;
        if (finished.kind === "notification") {
            if (finished.wrapper)
                finished.wrapper.popup = false;
        } else {
            IslandActivityService.acknowledge(finished, hostKey);
        }
        Qt.callLater(advance);
        return true;
    }

    function remove(source, id) {
        queue = queue.filter(entry => entry.source !== source || (id && entry.id !== id));
        if (current?.source === source && (!id || current.id === id))
            finishCurrent(current);
    }

    function reconfigure() {
        if (!registered)
            return;
        for (const entry of queue.slice()) {
            if (entry.kind === "notification" && !notificationsEnabled) {
                queue = queue.filter(item => item !== entry);
                if (entry.wrapper?.popup && entry.wrapper.timer?.interval > 0)
                    entry.wrapper.timer.restart();
                continue;
            }
            if (entry.kind !== "notification" && !accepts(entry)) {
                queue = queue.filter(item => item !== entry);
                IslandActivityService.acknowledge(entry, hostKey);
            }
        }
        if (current && ((current.kind === "notification" && !notificationsEnabled) || (current.kind !== "notification" && !accepts(current))))
            finishCurrent(current);
        IslandActivityService.seedSession(root);
        advance();
    }

    onBlockedChanged: {
        syncTimer();
        advance();
    }
    onHeldChanged: syncTimer()
    onEnabledChanged: reconfigure()
    onExcludedSourcesChanged: reconfigure()
    onNotificationsEnabledChanged: reconfigure()

    property Timer timeout: Timer {
        onTriggered: root.finishCurrent(root.current)
    }

    Component.onCompleted: {
        registered = true;
        IslandActivityService.registerSession(root);
    }
    Component.onDestruction: {
        registered = false;
        for (const entry of queue.concat(current ? [current] : [])) {
            if (entry.kind === "notification" && entry.wrapper?.popup && entry.wrapper.timer?.interval > 0)
                entry.wrapper.timer.restart();
        }
        IslandActivityService.unregisterSession(root);
    }
}
