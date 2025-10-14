pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.Common
import "../Common/markdown2html.js" as Markdown2Html

Singleton {
    id: root

    readonly property list<NotifWrapper> notifications: []
    readonly property list<NotifWrapper> allWrappers: []
    readonly property list<NotifWrapper> popups: allWrappers.filter(n => n && n.popup)

    property list<NotifWrapper> notificationQueue: []
    property list<NotifWrapper> visibleNotifications: []
    property int maxVisibleNotifications: 3
    property bool addGateBusy: false
    property int enterAnimMs: 400
    property int seqCounter: 0
    property bool bulkDismissing: false

    property int maxQueueSize: 32
    property int maxIngressPerSecond: 20
    property double _lastIngressSec: 0
    property int _ingressCountThisSec: 0
    property int maxStoredNotifications: 300

    property var _dismissQueue: []
    property int _dismissBatchSize: 8
    property int _dismissTickMs: 8
    property bool _suspendGrouping: false
    property var _groupCache: ({
                                   "notifications": [],
                                   "popups": []
                               })
    property bool _groupsDirty: false

    Component.onCompleted: {
        _recomputeGroups()
    }

    function _nowSec() {
        return Date.now() / 1000.0
    }

    function _ingressAllowed(notif) {
        const t = _nowSec()
        if (t - _lastIngressSec >= 1.0) {
            _lastIngressSec = t
            _ingressCountThisSec = 0
        }
        _ingressCountThisSec += 1
        if (notif.urgency === NotificationUrgency.Critical) {
            return true
        }
        return _ingressCountThisSec <= maxIngressPerSecond
    }

    function _enqueuePopup(wrapper) {
        if (notificationQueue.length >= maxQueueSize) {
            const gk = getGroupKey(wrapper)
            let idx = notificationQueue.findIndex(w => w && getGroupKey(w) === gk && w.urgency !== NotificationUrgency.Critical)
            if (idx === -1) {
                idx = notificationQueue.findIndex(w => w && w.urgency !== NotificationUrgency.Critical)
            }
            if (idx === -1) {
                idx = 0
            }
            const victim = notificationQueue[idx]
            if (victim) {
                victim.popup = false
            }
            notificationQueue.splice(idx, 1)
        }
        notificationQueue = [...notificationQueue, wrapper]
    }

    function _initWrapperPersistence(wrapper) {
        const timeoutMs = wrapper.timer ? wrapper.timer.interval : 5000
        const isCritical = wrapper.notification && wrapper.notification.urgency === NotificationUrgency.Critical
        wrapper.isPersistent = isCritical || (timeoutMs === 0)
    }

    function _trimStored() {
        if (notifications.length > maxStoredNotifications) {
            const overflow = notifications.length - maxStoredNotifications
            const toDrop = []
            for (var i = notifications.length - 1; i >= 0 && toDrop.length < overflow; --i) {
                const w = notifications[i]
                if (w && w.notification && w.urgency !== NotificationUrgency.Critical) {
                    toDrop.push(w)
                }
            }
            for (var i = notifications.length - 1; i >= 0 && toDrop.length < overflow; --i) {
                const w = notifications[i]
                if (w && w.notification && toDrop.indexOf(w) === -1) {
                    toDrop.push(w)
                }
            }
            for (const w of toDrop) {
                try {
                    w.notification.dismiss()
                } catch (e) {

                }
            }
        }
    }

    function onOverlayOpen() {
        popupsDisabled = true
        addGate.stop()
        addGateBusy = false

        notificationQueue = []
        for (const w of visibleNotifications) {
            if (w) {
                w.popup = false
            }
        }
        visibleNotifications = []
        _recomputeGroupsLater()
    }

    function onOverlayClose() {
        popupsDisabled = false
        processQueue()
    }

    Timer {
        id: addGate
        interval: enterAnimMs + 50
        running: false
        repeat: false
        onTriggered: {
            addGateBusy = false
            processQueue()
        }
    }

    Timer {
        id: timeUpdateTimer
        interval: 30000
        repeat: true
        running: root.allWrappers.length > 0 || visibleNotifications.length > 0
        triggeredOnStart: false
        onTriggered: {
            root.timeUpdateTick = !root.timeUpdateTick
        }
    }

    Timer {
        id: dismissPump
        interval: _dismissTickMs
        repeat: true
        running: false
        onTriggered: {
            let n = Math.min(_dismissBatchSize, _dismissQueue.length)
            for (var i = 0; i < n; ++i) {
                const w = _dismissQueue.pop()
                try {
                    if (w && w.notification) {
                        w.notification.dismiss()
                    }
                } catch (e) {

                }
            }
            if (_dismissQueue.length === 0) {
                dismissPump.stop()
                _suspendGrouping = false
                bulkDismissing = false
                popupsDisabled = false
                _recomputeGroupsLater()
            }
        }
    }

    Timer {
        id: groupsDebounce
        interval: 16
        repeat: false
        onTriggered: _recomputeGroups()
    }

    property bool timeUpdateTick: false
    property bool clockFormatChanged: false

    readonly property var groupedNotifications: _groupCache.notifications
    readonly property var groupedPopups: _groupCache.popups

    property var expandedGroups: ({})
    property var expandedMessages: ({})
    property bool popupsDisabled: false

    MediaPlayer {
        id: normalNotificationSound
        source: Qt.resolvedUrl("../assets/sounds/freedesktop/message.oga")
        audioOutput: AudioOutput {
            volume: 1.0
        }
    }

    MediaPlayer {
        id: criticalNotificationSound
        source: Qt.resolvedUrl("../assets/sounds/freedesktop/message-new-instant.oga")
        audioOutput: AudioOutput {
            volume: 1.0
        }
    }

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        actionIconsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        inlineReplySupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true

            if (!_ingressAllowed(notif)) {
                if (notif.urgency !== NotificationUrgency.Critical) {
                    try {
                        notif.dismiss()
                    } catch (e) {

                    }
                    return
                }
            }

            if (SettingsData.soundsEnabled && SettingsData.soundNewNotification) {
                if (notif.urgency === NotificationUrgency.Critical) {
                    criticalNotificationSound.play()
                } else {
                    normalNotificationSound.play()
                }
            }

            const shouldShowPopup = !root.popupsDisabled && !SessionData.doNotDisturb
            const isTransient = notif.transient
            const wrapper = notifComponent.createObject(root, {
                                                            "popup": shouldShowPopup,
                                                            "notification": notif
                                                        })

            if (wrapper) {
                root.allWrappers.push(wrapper)
                if (!isTransient) {
                    root.notifications.push(wrapper)
                    _trimStored()
                }

                Qt.callLater(() => {
                                 _initWrapperPersistence(wrapper)
                             })

                if (shouldShowPopup) {
                    _enqueuePopup(wrapper)
                    processQueue()
                }
            }

            _recomputeGroupsLater()
        }
    }

    component NotifWrapper: QtObject {
        id: wrapper

        property bool popup: false
        property bool removedByLimit: false
        property bool isPersistent: true
        property int seq: 0

        onPopupChanged: {
            if (!popup) {
                removeFromVisibleNotifications(wrapper)
            }
        }

        readonly property Timer timer: Timer {
            interval: {
                if (!wrapper.notification) {
                    return 5000
                }

                switch (wrapper.notification.urgency) {
                    case NotificationUrgency.Low:
                    return SettingsData.notificationTimeoutLow
                    case NotificationUrgency.Critical:
                    return SettingsData.notificationTimeoutCritical
                    default:
                    return SettingsData.notificationTimeoutNormal
                }
            }
            repeat: false
            running: false
            onTriggered: {
                if (interval > 0) {
                    wrapper.popup = false
                }
            }
        }

        readonly property date time: new Date()
        readonly property string timeStr: {
            root.timeUpdateTick
            root.clockFormatChanged

            const now = new Date()
            const diff = now.getTime() - time.getTime()
            const minutes = Math.floor(diff / 60000)
            const hours = Math.floor(minutes / 60)

            if (hours < 1) {
                if (minutes < 1) {
                    return "now"
                }
                return `${minutes}m ago`
            }

            const nowDate = new Date(now.getFullYear(), now.getMonth(), now.getDate())
            const timeDate = new Date(time.getFullYear(), time.getMonth(), time.getDate())
            const daysDiff = Math.floor((nowDate - timeDate) / (1000 * 60 * 60 * 24))

            if (daysDiff === 0) {
                return formatTime(time)
            }

            if (daysDiff === 1) {
                return `yesterday, ${formatTime(time)}`
            }

            return `${daysDiff} days ago`
        }

        function formatTime(date) {
            let use24Hour = true
            try {
                if (typeof SettingsData !== "undefined" && SettingsData.use24HourClock !== undefined) {
                    use24Hour = SettingsData.use24HourClock
                }
            } catch (e) {
                use24Hour = true
            }

            if (use24Hour) {
                return date.toLocaleTimeString(Qt.locale(), "HH:mm")
            } else {
                return date.toLocaleTimeString(Qt.locale(), "h:mm AP")
            }
        }

        required property Notification notification
        readonly property string summary: notification.summary
        readonly property string body: notification.body
        readonly property string htmlBody: {
            if (body && (body.includes('<') && body.includes('>'))) {
                return body
            }
            return Markdown2Html.markdownToHtml(body)
        }
        readonly property string appIcon: notification.appIcon
        readonly property string appName: {
            if (notification.appName == "") {
                const entry = DesktopEntries.heuristicLookup(notification.desktopEntry)
                if (entry && entry.name) {
                    return entry.name.toLowerCase()
                }
            }
            return notification.appName || "app"
        }
        readonly property string desktopEntry: notification.desktopEntry
        readonly property string image: notification.image
        readonly property string cleanImage: {
            if (!image) {
                return ""
            }
            return Paths.strip(image)
        }
        readonly property int urgency: notification.urgency
        readonly property list<NotificationAction> actions: notification.actions

        readonly property Connections conn: Connections {
            target: wrapper.notification.Retainable

            function onDropped(): void {
                root.allWrappers = root.allWrappers.filter(w => w !== wrapper)
                root.notifications = root.notifications.filter(w => w !== wrapper)

                if (root.bulkDismissing) {
                    return
                }

                const groupKey = getGroupKey(wrapper)
                const remainingInGroup = root.notifications.filter(n => getGroupKey(n) === groupKey)

                if (remainingInGroup.length <= 1) {
                    clearGroupExpansionState(groupKey)
                }

                cleanupExpansionStates()
                root._recomputeGroupsLater()
            }

            function onAboutToDestroy(): void {
                wrapper.destroy()
            }
        }
    }

    Component {
        id: notifComponent
        NotifWrapper {}
    }

    function clearAllNotifications() {
        bulkDismissing = true
        popupsDisabled = true
        addGate.stop()
        addGateBusy = false
        notificationQueue = []

        for (const w of allWrappers) {
            if (w) {
                w.popup = false
            }
        }
        visibleNotifications = []

        _dismissQueue = notifications.slice()
        if (notifications.length) {
            notifications = []
        }
        expandedGroups = {}
        expandedMessages = {}

        _suspendGrouping = true

        if (!dismissPump.running && _dismissQueue.length) {
            dismissPump.start()
        }
    }

    function dismissNotification(wrapper) {
        if (!wrapper || !wrapper.notification) {
            return
        }
        wrapper.popup = false
        wrapper.notification.dismiss()
    }

    function disablePopups(disable) {
        popupsDisabled = disable
        if (disable) {
            notificationQueue = []
            for (const notif of visibleNotifications) {
                notif.popup = false
            }
            visibleNotifications = []
        }
    }

    function processQueue() {
        if (addGateBusy) {
            return
        }
        if (popupsDisabled) {
            return
        }
        if (SessionData.doNotDisturb) {
            return
        }
        if (notificationQueue.length === 0) {
            return
        }

        const activePopupCount = visibleNotifications.filter(n => n && n.popup).length
        if (activePopupCount >= 4) {
            return
        }

        const next = notificationQueue.shift()

        next.seq = ++seqCounter
        visibleNotifications = [...visibleNotifications, next]
        next.popup = true

        if (next.timer.interval > 0) {
            next.timer.start()
        }

        addGateBusy = true
        addGate.restart()
    }

    function removeFromVisibleNotifications(wrapper) {
        visibleNotifications = visibleNotifications.filter(n => n !== wrapper)
        processQueue()
    }

    function releaseWrapper(w) {
        visibleNotifications = visibleNotifications.filter(n => n !== w)
        notificationQueue = notificationQueue.filter(n => n !== w)

        if (w && w.destroy && !w.isPersistent && notifications.indexOf(w) === -1) {
            Qt.callLater(() => {
                             try {
                                 w.destroy()
                             } catch (e) {

                             }
                         })
        }
    }

    function getGroupKey(wrapper) {
        if (wrapper.desktopEntry && wrapper.desktopEntry !== "") {
            return wrapper.desktopEntry.toLowerCase()
        }

        return wrapper.appName.toLowerCase()
    }

    function _recomputeGroups() {
        if (_suspendGrouping) {
            _groupsDirty = true
            return
        }
        _groupCache = {
            "notifications": _calcGroupedNotifications(),
            "popups": _calcGroupedPopups()
        }
        _groupsDirty = false
    }

    function _recomputeGroupsLater() {
        _groupsDirty = true
        if (!groupsDebounce.running) {
            groupsDebounce.start()
        }
    }

    function _calcGroupedNotifications() {
        const groups = {}

        for (const notif of notifications) {
            if (!notif) continue
            const groupKey = getGroupKey(notif)
            if (!groups[groupKey]) {
                groups[groupKey] = {
                    "key": groupKey,
                    "appName": notif.appName,
                    "notifications": [],
                    "latestNotification": null,
                    "count": 0,
                    "hasInlineReply": false
                }
            }

            groups[groupKey].notifications.unshift(notif)
            groups[groupKey].latestNotification = groups[groupKey].notifications[0]
            groups[groupKey].count = groups[groupKey].notifications.length

            if (notif.notification.hasInlineReply) {
                groups[groupKey].hasInlineReply = true
            }
        }

        return Object.values(groups).sort((a, b) => {
                                              const aUrgency = a.latestNotification.urgency || NotificationUrgency.Low
                                              const bUrgency = b.latestNotification.urgency || NotificationUrgency.Low
                                              if (aUrgency !== bUrgency) {
                                                  return bUrgency - aUrgency
                                              }
                                              return b.latestNotification.time.getTime() - a.latestNotification.time.getTime()
                                          })
    }

    function _calcGroupedPopups() {
        const groups = {}

        for (const notif of popups) {
            if (!notif) continue
            const groupKey = getGroupKey(notif)
            if (!groups[groupKey]) {
                groups[groupKey] = {
                    "key": groupKey,
                    "appName": notif.appName,
                    "notifications": [],
                    "latestNotification": null,
                    "count": 0,
                    "hasInlineReply": false
                }
            }

            groups[groupKey].notifications.unshift(notif)
            groups[groupKey].latestNotification = groups[groupKey].notifications[0]
            groups[groupKey].count = groups[groupKey].notifications.length

            if (notif.notification.hasInlineReply) {
                groups[groupKey].hasInlineReply = true
            }
        }

        return Object.values(groups).sort((a, b) => {
                                              return b.latestNotification.time.getTime() - a.latestNotification.time.getTime()
                                          })
    }

    function toggleGroupExpansion(groupKey) {
        let newExpandedGroups = {}
        for (const key in expandedGroups) {
            newExpandedGroups[key] = expandedGroups[key]
        }
        newExpandedGroups[groupKey] = !newExpandedGroups[groupKey]
        expandedGroups = newExpandedGroups
    }

    function dismissGroup(groupKey) {
        const group = groupedNotifications.find(g => g.key === groupKey)
        if (group) {
            for (const notif of group.notifications) {
                if (notif && notif.notification) {
                    notif.notification.dismiss()
                }
            }
        } else {
            for (const notif of allWrappers) {
                if (notif && notif.notification && getGroupKey(notif) === groupKey) {
                    notif.notification.dismiss()
                }
            }
        }
    }

    function clearGroupExpansionState(groupKey) {
        let newExpandedGroups = {}
        for (const key in expandedGroups) {
            if (key !== groupKey && expandedGroups[key]) {
                newExpandedGroups[key] = true
            }
        }
        expandedGroups = newExpandedGroups
    }

    function cleanupExpansionStates() {
        const currentGroupKeys = new Set(groupedNotifications.map(g => g.key))
        const currentMessageIds = new Set()
        for (const group of groupedNotifications) {
            for (const notif of group.notifications) {
                if (notif && notif.notification) {
                    currentMessageIds.add(notif.notification.id)
                }
            }
        }
        let newExpandedGroups = {}
        for (const key in expandedGroups) {
            if (currentGroupKeys.has(key) && expandedGroups[key]) {
                newExpandedGroups[key] = true
            }
        }
        expandedGroups = newExpandedGroups
        let newExpandedMessages = {}
        for (const messageId in expandedMessages) {
            if (currentMessageIds.has(messageId) && expandedMessages[messageId]) {
                newExpandedMessages[messageId] = true
            }
        }
        expandedMessages = newExpandedMessages
    }

    function toggleMessageExpansion(messageId) {
        let newExpandedMessages = {}
        for (const key in expandedMessages) {
            newExpandedMessages[key] = expandedMessages[key]
        }
        newExpandedMessages[messageId] = !newExpandedMessages[messageId]
        expandedMessages = newExpandedMessages
    }

    Connections {
        target: SessionData
        function onDoNotDisturbChanged() {
            if (SessionData.doNotDisturb) {
                // Hide all current popups when DND is enabled
                for (const notif of visibleNotifications) {
                    notif.popup = false
                }
                visibleNotifications = []
                notificationQueue = []
            } else {
                // Re-enable popup processing when DND is disabled
                processQueue()
            }
        }
    }

    Connections {
        target: typeof SettingsData !== "undefined" ? SettingsData : null
        function onUse24HourClockChanged() {
            root.clockFormatChanged = !root.clockFormatChanged
        }
    }
}
