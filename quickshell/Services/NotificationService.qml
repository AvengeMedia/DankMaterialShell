pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.Common
import "../Common/markdown2html.js" as Markdown2Html

Singleton {
    id: root

    readonly property list<NotifWrapper> notifications: []
    readonly property list<NotifWrapper> allWrappers: []
    readonly property list<NotifWrapper> popups: allWrappers.filter(n => n && n.popup)

    property var historyList: []
    readonly property string historyFile: Paths.strip(Paths.cache) + "/notification_history.json"
    readonly property string imageCacheDir: Paths.strip(Paths.cache) + "/notification_images"
    property bool historyLoaded: false

    property list<NotifWrapper> notificationQueue: []
    property list<NotifWrapper> visibleNotifications: []
    property int maxVisibleNotifications: 4
    property bool addGateBusy: false
    property int enterAnimMs: 400
    property int seqCounter: 0
    property bool bulkDismissing: false

    property int maxQueueSize: 32
    property int maxIngressPerSecond: 20
    property double _lastIngressSec: 0
    property int _ingressCountThisSec: 0

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
        _recomputeGroups();
        Quickshell.execDetached(["mkdir", "-p", Paths.strip(Paths.cache)]);
        Quickshell.execDetached(["mkdir", "-p", imageCacheDir]);
    }

    FileView {
        id: historyFileView
        path: root.historyFile
        printErrors: false
        onLoaded: root.loadHistory()
        onLoadFailed: error => {
            if (error === 2) {
                root.historyLoaded = true;
                historyFileView.writeAdapter();
            }
        }

        JsonAdapter {
            id: historyAdapter
            property var notifications: []
        }
    }

    Timer {
        id: historySaveTimer
        interval: 200
        onTriggered: root.performSaveHistory()
    }

    function getImageCachePath(wrapper) {
        const ts = wrapper.time ? wrapper.time.getTime() : Date.now();
        const id = wrapper.notification?.id?.toString() || "0";
        return imageCacheDir + "/notif_" + ts + "_" + id + ".png";
    }

    function updateHistoryImage(wrapperId, imagePath) {
        const idx = historyList.findIndex(n => n.id === wrapperId);
        if (idx < 0)
            return;
        const item = historyList[idx];
        const updated = {
            id: item.id,
            summary: item.summary,
            body: item.body,
            htmlBody: item.htmlBody,
            appName: item.appName,
            appIcon: item.appIcon,
            image: "file://" + imagePath,
            urgency: item.urgency,
            timestamp: item.timestamp,
            desktopEntry: item.desktopEntry
        };
        const newList = historyList.slice();
        newList[idx] = updated;
        historyList = newList;
        saveHistory();
    }

    function addToHistory(wrapper) {
        if (!wrapper)
            return;
        const urg = typeof wrapper.urgency === "number" ? wrapper.urgency : 1;
        const imageUrl = wrapper.image || "";
        let persistableImage = "";
        if (wrapper.persistedImagePath) {
            persistableImage = "file://" + wrapper.persistedImagePath;
        } else if (imageUrl && !imageUrl.startsWith("image://qsimage/")) {
            persistableImage = imageUrl;
        }
        const data = {
            id: wrapper.notification?.id?.toString() || Date.now().toString(),
            summary: wrapper.summary || "",
            body: wrapper.body || "",
            htmlBody: wrapper.htmlBody || wrapper.body || "",
            appName: wrapper.appName || "",
            appIcon: wrapper.appIcon || "",
            image: persistableImage,
            urgency: urg,
            timestamp: wrapper.time.getTime(),
            desktopEntry: wrapper.desktopEntry || ""
        };
        let newList = [data, ...historyList];
        if (newList.length > SettingsData.notificationHistoryMaxCount) {
            newList = newList.slice(0, SettingsData.notificationHistoryMaxCount);
        }
        historyList = newList;
        saveHistory();
    }

    function saveHistory() {
        historySaveTimer.restart();
    }

    function performSaveHistory() {
        try {
            historyAdapter.notifications = historyList;
            historyFileView.writeAdapter();
        } catch (e) {
            console.warn("NotificationService: save history failed:", e);
        }
    }

    function loadHistory() {
        try {
            const maxAgeDays = SettingsData.notificationHistoryMaxAgeDays;
            const now = Date.now();
            const maxAgeMs = maxAgeDays > 0 ? maxAgeDays * 24 * 60 * 60 * 1000 : 0;
            const loaded = [];

            for (const item of historyAdapter.notifications || []) {
                if (maxAgeMs > 0 && (now - item.timestamp) > maxAgeMs)
                    continue;
                const urg = typeof item.urgency === "number" ? item.urgency : 1;
                const body = item.body || "";
                let htmlBody = item.htmlBody || _resolveHtmlBody(body);
                if (htmlBody) {
                    htmlBody = htmlBody.replace(/<img\b[^>]*>/gi, "");
                }
                loaded.push({
                    id: item.id || "",
                    summary: item.summary || "",
                    body: body,
                    htmlBody: htmlBody,
                    appName: item.appName || "",
                    appIcon: item.appIcon || "",
                    image: item.image || "",
                    urgency: urg,
                    timestamp: item.timestamp || 0,
                    desktopEntry: item.desktopEntry || ""
                });
            }
            historyList = loaded;
            historyLoaded = true;
            if (maxAgeMs > 0 && loaded.length !== (historyAdapter.notifications || []).length)
                saveHistory();
        } catch (e) {
            console.warn("NotificationService: load history failed:", e);
            historyLoaded = true;
        }
    }

    function _deleteCachedImage(imagePath) {
        if (!imagePath || !imagePath.startsWith("file://"))
            return;
        const filePath = imagePath.replace("file://", "");
        if (filePath.startsWith(imageCacheDir)) {
            Quickshell.execDetached(["rm", "-f", filePath]);
        }
    }

    function removeFromHistory(notificationId) {
        const idx = historyList.findIndex(n => n.id === notificationId);
        if (idx >= 0) {
            _deleteCachedImage(historyList[idx].image);
            historyList = historyList.filter((_, i) => i !== idx);
            saveHistory();
            return true;
        }
        return false;
    }

    function clearHistory() {
        for (const item of historyList) {
            _deleteCachedImage(item.image);
        }
        historyList = [];
        saveHistory();
    }

    function getHistoryTimeRange(timestamp) {
        const now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const itemDate = new Date(timestamp);
        const itemDay = new Date(itemDate.getFullYear(), itemDate.getMonth(), itemDate.getDate());
        const diffDays = Math.floor((today - itemDay) / (1000 * 60 * 60 * 24));
        if (diffDays === 0)
            return 0;
        if (diffDays === 1)
            return 1;
        return 2;
    }

    function getHistoryCountForRange(range) {
        if (range === -1)
            return historyList.length;
        return historyList.filter(n => getHistoryTimeRange(n.timestamp) === range).length;
    }

    function formatHistoryTime(timestamp) {
        root.timeUpdateTick;
        root.clockFormatChanged;
        const now = new Date();
        const date = new Date(timestamp);
        const diff = now.getTime() - timestamp;
        const minutes = Math.floor(diff / 60000);
        const hours = Math.floor(minutes / 60);
        if (hours < 1) {
            if (minutes < 1)
                return I18n.tr("now");
            return I18n.tr("%1m ago").arg(minutes);
        }
        const nowDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const itemDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        const daysDiff = Math.floor((nowDate - itemDate) / (1000 * 60 * 60 * 24));
        const timeStr = SettingsData.use24HourClock ? date.toLocaleTimeString(Qt.locale(), "HH:mm") : date.toLocaleTimeString(Qt.locale(), "h:mm AP");
        if (daysDiff === 0)
            return timeStr;
        try {
            const localeName = (typeof Qt !== "undefined" && Qt.locale) ? Qt.locale().name : "en-US";
            const weekday = date.toLocaleDateString(localeName, {
                weekday: "long"
            });
            return weekday + ", " + timeStr;
        } catch (e) {
            return timeStr;
        }
    }

    function _nowSec() {
        return Date.now() / 1000.0;
    }

    function _ingressAllowed(urgency) {
        const t = _nowSec();
        if (t - _lastIngressSec >= 1.0) {
            _lastIngressSec = t;
            _ingressCountThisSec = 0;
        }
        _ingressCountThisSec += 1;
        if (urgency === NotificationUrgency.Critical) {
            return true;
        }
        return _ingressCountThisSec <= maxIngressPerSecond;
    }

    function _enqueuePopup(wrapper) {
        if (notificationQueue.length >= maxQueueSize) {
            const gk = getGroupKey(wrapper);
            let idx = notificationQueue.findIndex(w => w && getGroupKey(w) === gk && w.urgency !== NotificationUrgency.Critical);
            if (idx === -1) {
                idx = notificationQueue.findIndex(w => w && w.urgency !== NotificationUrgency.Critical);
            }
            if (idx === -1) {
                idx = 0;
            }
            const victim = notificationQueue[idx];
            if (victim) {
                victim.popup = false;
            }
            notificationQueue.splice(idx, 1);
        }
        notificationQueue = [...notificationQueue, wrapper];
    }

    function _initWrapperPersistence(wrapper) {
        const timeoutMs = wrapper.timer ? wrapper.timer.interval : 5000;
        const isCritical = wrapper && wrapper.urgency === NotificationUrgency.Critical;
        wrapper.isPersistent = isCritical || (timeoutMs === 0);
    }

    function _shouldSaveToHistory(urgency, forceDisable) {
        if (forceDisable === true)
            return false;
        if (!SettingsData.notificationHistoryEnabled)
            return false;
        switch (urgency) {
        case NotificationUrgency.Low:
            return SettingsData.notificationHistorySaveLow;
        case NotificationUrgency.Critical:
            return SettingsData.notificationHistorySaveCritical;
        default:
            return SettingsData.notificationHistorySaveNormal;
        }
    }

    function _resolveAppNameForRule(notif) {
        if (!notif)
            return "";
        if (notif.appName && notif.appName !== "")
            return notif.appName;
        const entry = DesktopEntries.heuristicLookup(notif.desktopEntry);
        if (entry && entry.name)
            return entry.name;
        return "";
    }

    function _ruleFieldValue(field, info) {
        switch ((field || "").toString()) {
        case "desktopEntry":
            return info.desktopEntry;
        case "summary":
            return info.summary;
        case "body":
            return info.body;
        case "appName":
        default:
            return info.appName;
        }
    }

    function _coerceRuleUrgency(value, fallbackUrgency) {
        if (typeof value === "number" && value >= NotificationUrgency.Low && value <= NotificationUrgency.Critical)
            return value;

        const mapped = (value || "default").toString().toLowerCase();
        switch (mapped) {
        case "low":
            return NotificationUrgency.Low;
        case "normal":
            return NotificationUrgency.Normal;
        case "critical":
            return NotificationUrgency.Critical;
        default:
            return fallbackUrgency;
        }
    }

    function _matchesNotificationRule(rule, info) {
        if (!rule)
            return false;
        if (rule.enabled === false)
            return false;

        const pattern = (rule.pattern || "").toString();
        if (!pattern.trim())
            return false;

        const value = (_ruleFieldValue(rule.field, info) || "").toString();
        const matchType = (rule.matchType || "contains").toString().toLowerCase();

        if (matchType === "exact")
            return value.toLowerCase() === pattern.toLowerCase();
        if (matchType === "regex") {
            try {
                return new RegExp(pattern, "i").test(value);
            } catch (e) {
                console.warn("NotificationService: invalid notification rule regex:", pattern);
                return false;
            }
        }

        return value.toLowerCase().includes(pattern.toLowerCase());
    }

    function _evaluateNotificationPolicy(notif) {
        const baseUrgency = typeof notif.urgency === "number" ? notif.urgency : NotificationUrgency.Normal;
        const policy = {
            "drop": false,
            "disablePopup": false,
            "hideFromCenter": false,
            "disableHistory": false,
            "urgency": baseUrgency
        };

        const rules = SettingsData.notificationRules || [];
        if (!rules.length)
            return policy;

        const info = {
            "appName": _resolveAppNameForRule(notif),
            "desktopEntry": notif.desktopEntry || "",
            "summary": notif.summary || "",
            "body": notif.body || ""
        };

        for (const rule of rules) {
            if (!_matchesNotificationRule(rule, info))
                continue;

            const action = (rule.action || "default").toString().toLowerCase();
            switch (action) {
            case "ignore":
                policy.drop = true;
                break;
            case "mute":
                policy.disablePopup = true;
                break;
            case "popup_only":
                policy.hideFromCenter = true;
                policy.disableHistory = true;
                break;
            case "no_history":
                policy.disableHistory = true;
                break;
            default:
                break;
            }

            policy.urgency = _coerceRuleUrgency(rule.urgency, policy.urgency);
            return policy;
        }

        return policy;
    }

    function pruneHistory() {
        const maxAgeDays = SettingsData.notificationHistoryMaxAgeDays;
        if (maxAgeDays <= 0)
            return;

        const now = Date.now();
        const maxAgeMs = maxAgeDays * 24 * 60 * 60 * 1000;
        const toRemove = historyList.filter(item => (now - item.timestamp) > maxAgeMs);
        const pruned = historyList.filter(item => (now - item.timestamp) <= maxAgeMs);

        if (pruned.length !== historyList.length) {
            for (const item of toRemove) {
                _deleteCachedImage(item.image);
            }
            historyList = pruned;
            saveHistory();
        }
    }

    function deleteHistory() {
        for (const item of historyList) {
            _deleteCachedImage(item.image);
        }
        historyList = [];
        historyAdapter.notifications = [];
        historyFileView.writeAdapter();
    }

    function onOverlayOpen() {
        popupsDisabled = true;
        addGate.stop();
        addGateBusy = false;

        notificationQueue = [];
        for (const w of visibleNotifications) {
            if (w) {
                w.popup = false;
            }
        }
        visibleNotifications = [];
        _recomputeGroupsLater();
        pruneHistory();
    }

    function onOverlayClose() {
        popupsDisabled = false;
        processQueue();
    }

    Timer {
        id: addGate
        interval: 80
        running: false
        repeat: false
        onTriggered: {
            addGateBusy = false;
            processQueue();
        }
    }

    Timer {
        id: timeUpdateTimer
        interval: 30000
        repeat: true
        running: root.allWrappers.length > 0 || visibleNotifications.length > 0
        triggeredOnStart: false
        onTriggered: {
            root.timeUpdateTick = !root.timeUpdateTick;
        }
    }

    Timer {
        id: dismissPump
        interval: _dismissTickMs
        repeat: true
        running: false
        onTriggered: {
            let n = Math.min(_dismissBatchSize, _dismissQueue.length);
            for (var i = 0; i < n; ++i) {
                const w = _dismissQueue.pop();
                try {
                    if (w && w.notification) {
                        w.notification.dismiss();
                    }
                } catch (e) {}
            }
            if (_dismissQueue.length === 0) {
                dismissPump.stop();
                _suspendGrouping = false;
                bulkDismissing = false;
                popupsDisabled = false;
                _recomputeGroupsLater();
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
            notif.tracked = true;

            const policy = _evaluateNotificationPolicy(notif);
            if (policy.drop) {
                try {
                    notif.dismiss();
                } catch (e) {}
                return;
            }

            if (!_ingressAllowed(policy.urgency)) {
                if (policy.urgency !== NotificationUrgency.Critical) {
                    try {
                        notif.dismiss();
                    } catch (e) {}
                    return;
                }
            }

            if (SettingsData.soundsEnabled && SettingsData.soundNewNotification) {
                if (policy.urgency === NotificationUrgency.Critical) {
                    AudioService.playCriticalNotificationSound();
                } else {
                    AudioService.playNormalNotificationSound();
                }
            }

            const shouldShowPopup = !root.popupsDisabled && !SessionData.doNotDisturb && !policy.disablePopup;
            const isTransient = notif.transient;
            const shouldKeepInCenter = !isTransient && !policy.hideFromCenter;

            if (!shouldShowPopup && !shouldKeepInCenter) {
                try {
                    notif.dismiss();
                } catch (e) {}
                return;
            }

            const wrapper = notifComponent.createObject(root, {
                "popup": shouldShowPopup,
                "notification": notif,
                "urgencyOverride": policy.urgency
            });

            if (wrapper) {
                root.allWrappers.push(wrapper);
                if (shouldKeepInCenter) {
                    root.notifications.push(wrapper);
                    if (_shouldSaveToHistory(wrapper.urgency, policy.disableHistory)) {
                        root.addToHistory(wrapper);
                    }
                }
                Qt.callLater(() => {
                    _initWrapperPersistence(wrapper);
                });

                if (shouldShowPopup) {
                    _enqueuePopup(wrapper);
                    processQueue();
                }
            }

            _recomputeGroupsLater();
        }
    }

    component NotifWrapper: QtObject {
        id: wrapper

        property bool popup: false
        property bool removedByLimit: false
        property bool isPersistent: true
        property int seq: 0
        property string persistedImagePath: ""

        onPopupChanged: {
            if (!popup) {
                removeFromVisibleNotifications(wrapper);
            }
        }

        readonly property Timer timer: Timer {
            interval: {
                if (!wrapper.notification)
                    return 5000;
                switch (wrapper.urgency) {
                case NotificationUrgency.Low:
                    return SettingsData.notificationTimeoutLow;
                case NotificationUrgency.Critical:
                    return SettingsData.notificationTimeoutCritical;
                default:
                    return SettingsData.notificationTimeoutNormal;
                }
            }
            repeat: false
            running: false
            onTriggered: {
                if (interval > 0) {
                    wrapper.popup = false;
                }
            }
        }

        readonly property date time: new Date()
        readonly property string timeStr: {
            root.timeUpdateTick;
            root.clockFormatChanged;

            const now = new Date();
            const diff = now.getTime() - time.getTime();
            const minutes = Math.floor(diff / 60000);
            const hours = Math.floor(minutes / 60);

            if (hours < 1) {
                if (minutes < 1) {
                    return "now";
                }
                return `${minutes}m ago`;
            }

            const nowDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
            const timeDate = new Date(time.getFullYear(), time.getMonth(), time.getDate());
            const daysDiff = Math.floor((nowDate - timeDate) / (1000 * 60 * 60 * 24));

            if (daysDiff === 0) {
                return formatTime(time);
            }

            try {
                const localeName = (typeof Qt !== "undefined" && Qt.locale) ? Qt.locale().name : "en-US";
                const weekday = time.toLocaleDateString(localeName, {
                    weekday: "long"
                });
                return `${weekday}, ${formatTime(time)}`;
            } catch (e) {
                return formatTime(time);
            }
        }

        function formatTime(date) {
            let use24Hour = true;
            try {
                if (typeof SettingsData !== "undefined" && SettingsData.use24HourClock !== undefined) {
                    use24Hour = SettingsData.use24HourClock;
                }
            } catch (e) {
                use24Hour = true;
            }

            if (use24Hour) {
                return date.toLocaleTimeString(Qt.locale(), "HH:mm");
            } else {
                return date.toLocaleTimeString(Qt.locale(), "h:mm AP");
            }
        }

        required property Notification notification
        readonly property string summary: (notification?.summary ?? "").replace(/<img\b[^>]*>/gi, "")
        readonly property string body: (notification?.body ?? "").replace(/<img\b[^>]*>/gi, "")
        readonly property string htmlBody: root._resolveHtmlBody(body)
        readonly property string appIcon: notification?.appIcon ?? ""
        readonly property string appName: {
            if (!notification)
                return "app";
            if (notification.appName == "") {
                const entry = DesktopEntries.heuristicLookup(notification.desktopEntry);
                if (entry && entry.name)
                    return entry.name.toLowerCase();
            }
            return notification.appName || "app";
        }
        readonly property string desktopEntry: notification?.desktopEntry ?? ""
        readonly property string image: notification?.image ?? ""
        readonly property string cleanImage: {
            if (!image)
                return "";
            return Paths.strip(image);
        }
        property int urgencyOverride: notification?.urgency ?? NotificationUrgency.Normal
        readonly property int urgency: urgencyOverride
        readonly property list<NotificationAction> actions: notification?.actions ?? []

        readonly property Connections conn: Connections {
            target: wrapper.notification?.Retainable ?? null

            function onDropped(): void {
                root.allWrappers = root.allWrappers.filter(w => w !== wrapper);
                root.notifications = root.notifications.filter(w => w !== wrapper);

                if (root.bulkDismissing) {
                    return;
                }

                const groupKey = getGroupKey(wrapper);
                const remainingInGroup = root.notifications.filter(n => getGroupKey(n) === groupKey);

                if (remainingInGroup.length <= 1) {
                    clearGroupExpansionState(groupKey);
                }

                cleanupExpansionStates();
                root._recomputeGroupsLater();
            }

            function onAboutToDestroy(): void {
                wrapper.destroy();
            }
        }
    }

    Component {
        id: notifComponent
        NotifWrapper {}
    }

    function dismissAllPopups() {
        for (const w of visibleNotifications) {
            if (w) {
                w.popup = false;
            }
        }
        visibleNotifications = [];
        notificationQueue = [];
    }

    function clearAllNotifications() {
        if (!notifications.length) {
            return;
        }
        bulkDismissing = true;
        popupsDisabled = true;
        addGate.stop();
        addGateBusy = false;
        notificationQueue = [];

        for (const w of allWrappers) {
            if (w) {
                w.popup = false;
            }
        }
        visibleNotifications = [];

        _dismissQueue = notifications.slice();
        if (notifications.length) {
            notifications = [];
        }
        expandedGroups = {};
        expandedMessages = {};

        _suspendGrouping = true;

        if (!dismissPump.running && _dismissQueue.length) {
            dismissPump.start();
        }
    }

    function dismissNotification(wrapper) {
        if (!wrapper || !wrapper.notification) {
            return;
        }
        wrapper.popup = false;
        wrapper.notification.dismiss();
    }

    function disablePopups(disable) {
        popupsDisabled = disable;
        if (disable) {
            notificationQueue = [];
            for (const notif of visibleNotifications) {
                notif.popup = false;
            }
            visibleNotifications = [];
        }
    }

    property bool _processingQueue: false

    function processQueue() {
        if (addGateBusy || _processingQueue)
            return;
        if (popupsDisabled)
            return;
        if (SessionData.doNotDisturb)
            return;
        if (notificationQueue.length === 0)
            return;

        _processingQueue = true;

        const next = notificationQueue.shift();
        if (!next) {
            _processingQueue = false;
            return;
        }

        next.seq = ++seqCounter;

        const activePopups = visibleNotifications.filter(n => n && n.popup);
        let evicted = null;
        if (activePopups.length >= maxVisibleNotifications) {
            const unhovered = activePopups.filter(n => n.timer?.running);
            const pool = unhovered.length > 0 ? unhovered : activePopups;
            evicted = pool.reduce((min, n) => (n.seq < min.seq) ? n : min, pool[0]);
            if (evicted)
                evicted.removedByLimit = true;
        }

        if (evicted) {
            visibleNotifications = [...visibleNotifications.filter(n => n !== evicted), next];
        } else {
            visibleNotifications = [...visibleNotifications, next];
        }

        if (evicted)
            evicted.popup = false;
        next.popup = true;

        if (next.timer.interval > 0)
            next.timer.start();

        addGateBusy = true;
        addGate.restart();
        _processingQueue = false;
    }

    function removeFromVisibleNotifications(wrapper) {
        visibleNotifications = visibleNotifications.filter(n => n !== wrapper);
        processQueue();
    }

    function releaseWrapper(w) {
        visibleNotifications = visibleNotifications.filter(n => n !== w);
        notificationQueue = notificationQueue.filter(n => n !== w);

        if (w && w.destroy && !w.isPersistent && notifications.indexOf(w) === -1) {
            Qt.callLater(() => {
                try {
                    w.destroy();
                } catch (e) {}
            });
        }
    }

    function _decodeEntities(s) {
        s = s.replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(parseInt(n, 10)));
        s = s.replace(/&#x([0-9a-fA-F]+);/g, (_, n) => String.fromCodePoint(parseInt(n, 16)));
        return s.replace(/&([a-zA-Z][a-zA-Z0-9]*);/g, (match, name) => {
            switch (name) {
            case "amp":
                return "&";
            case "lt":
                return "<";
            case "gt":
                return ">";
            case "quot":
                return "\"";
            case "apos":
                return "'";
            case "nbsp":
                return "\u00A0";
            case "ndash":
                return "\u2013";
            case "mdash":
                return "\u2014";
            case "lsquo":
                return "\u2018";
            case "rsquo":
                return "\u2019";
            case "ldquo":
                return "\u201C";
            case "rdquo":
                return "\u201D";
            case "bull":
                return "\u2022";
            case "hellip":
                return "\u2026";
            case "trade":
                return "\u2122";
            case "copy":
                return "\u00A9";
            case "reg":
                return "\u00AE";
            case "deg":
                return "\u00B0";
            case "plusmn":
                return "\u00B1";
            case "times":
                return "\u00D7";
            case "divide":
                return "\u00F7";
            case "micro":
                return "\u00B5";
            case "middot":
                return "\u00B7";
            case "laquo":
                return "\u00AB";
            case "raquo":
                return "\u00BB";
            case "larr":
                return "\u2190";
            case "rarr":
                return "\u2192";
            case "uarr":
                return "\u2191";
            case "darr":
                return "\u2193";
            default:
                return match;
            }
        });
    }

    function _resolveHtmlBody(body) {
        if (!body)
            return "";

        let result = body;

        if (/<\/?[a-z][\s\S]*>/i.test(body)) {
            result = body;
        } else {
            // Decode percent-encoded URLs (e.g. https%3A%2F%2F → https://)
            let processed = body.replace(/\bhttps?%3A%2F%2F[^\s]+/gi, match => {
                try {
                    return decodeURIComponent(match);
                } catch (e) {
                    return match;
                }
            });

            if (/&(#\d+|#x[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]+);/.test(processed)) {
                const decoded = _decodeEntities(processed);
                if (/<\/?[a-z][\s\S]*>/i.test(decoded))
                    result = decoded;
                else
                    result = Markdown2Html.markdownToHtml(decoded);
            } else {
                result = Markdown2Html.markdownToHtml(processed);
            }
        }

        // Strip out image tags to prevent IP tracking
        return result.replace(/<img\b[^>]*>/gi, "");
    }

    function getGroupKey(wrapper) {
        if (wrapper.desktopEntry && wrapper.desktopEntry !== "") {
            return wrapper.desktopEntry.toLowerCase();
        }

        return wrapper.appName.toLowerCase();
    }

    function _recomputeGroups() {
        if (_suspendGrouping) {
            _groupsDirty = true;
            return;
        }
        _groupCache = {
            "notifications": _calcGroupedNotifications(),
            "popups": _calcGroupedPopups()
        };
        _groupsDirty = false;
    }

    function _recomputeGroupsLater() {
        _groupsDirty = true;
        if (!groupsDebounce.running) {
            groupsDebounce.start();
        }
    }

    function _calcGroupedNotifications() {
        const groups = {};

        for (const notif of notifications) {
            if (!notif || !notif.notification)
                continue;
            const groupKey = getGroupKey(notif);
            if (!groups[groupKey]) {
                groups[groupKey] = {
                    "key": groupKey,
                    "appName": notif.appName,
                    "notifications": [],
                    "latestNotification": null,
                    "count": 0,
                    "hasInlineReply": false
                };
            }

            groups[groupKey].notifications.unshift(notif);
            groups[groupKey].latestNotification = groups[groupKey].notifications[0];
            groups[groupKey].count = groups[groupKey].notifications.length;

            if (notif.notification?.hasInlineReply)
                groups[groupKey].hasInlineReply = true;
        }

        return Object.values(groups).sort((a, b) => {
            if (!a.latestNotification || !b.latestNotification)
                return 0;
            const aUrgency = a.latestNotification.urgency ?? NotificationUrgency.Low;
            const bUrgency = b.latestNotification.urgency ?? NotificationUrgency.Low;
            if (aUrgency !== bUrgency) {
                return bUrgency - aUrgency;
            }
            return b.latestNotification.time.getTime() - a.latestNotification.time.getTime();
        });
    }

    function _calcGroupedPopups() {
        const groups = {};

        for (const notif of popups) {
            if (!notif || !notif.notification)
                continue;
            const groupKey = getGroupKey(notif);
            if (!groups[groupKey]) {
                groups[groupKey] = {
                    "key": groupKey,
                    "appName": notif.appName,
                    "notifications": [],
                    "latestNotification": null,
                    "count": 0,
                    "hasInlineReply": false
                };
            }

            groups[groupKey].notifications.unshift(notif);
            groups[groupKey].latestNotification = groups[groupKey].notifications[0];
            groups[groupKey].count = groups[groupKey].notifications.length;

            if (notif.notification?.hasInlineReply)
                groups[groupKey].hasInlineReply = true;
        }

        return Object.values(groups).sort((a, b) => {
            if (!a.latestNotification || !b.latestNotification)
                return 0;
            return b.latestNotification.time.getTime() - a.latestNotification.time.getTime();
        });
    }

    function toggleGroupExpansion(groupKey) {
        let newExpandedGroups = {};
        for (const key in expandedGroups) {
            newExpandedGroups[key] = expandedGroups[key];
        }
        newExpandedGroups[groupKey] = !newExpandedGroups[groupKey];
        expandedGroups = newExpandedGroups;
    }

    function dismissGroup(groupKey) {
        const group = groupedNotifications.find(g => g.key === groupKey);
        if (group) {
            for (const notif of group.notifications) {
                if (notif && notif.notification) {
                    notif.notification.dismiss();
                }
            }
        } else {
            for (const notif of allWrappers) {
                if (notif && notif.notification && getGroupKey(notif) === groupKey) {
                    notif.notification.dismiss();
                }
            }
        }
    }

    function clearGroupExpansionState(groupKey) {
        let newExpandedGroups = {};
        for (const key in expandedGroups) {
            if (key !== groupKey && expandedGroups[key]) {
                newExpandedGroups[key] = true;
            }
        }
        expandedGroups = newExpandedGroups;
    }

    function cleanupExpansionStates() {
        const currentGroupKeys = new Set(groupedNotifications.map(g => g.key));
        const currentMessageIds = new Set();
        for (const group of groupedNotifications) {
            for (const notif of group.notifications) {
                if (notif && notif.notification) {
                    currentMessageIds.add(notif.notification.id);
                }
            }
        }
        let newExpandedGroups = {};
        for (const key in expandedGroups) {
            if (currentGroupKeys.has(key) && expandedGroups[key]) {
                newExpandedGroups[key] = true;
            }
        }
        expandedGroups = newExpandedGroups;
        let newExpandedMessages = {};
        for (const messageId in expandedMessages) {
            if (currentMessageIds.has(messageId) && expandedMessages[messageId]) {
                newExpandedMessages[messageId] = true;
            }
        }
        expandedMessages = newExpandedMessages;
    }

    function toggleMessageExpansion(messageId) {
        let newExpandedMessages = {};
        for (const key in expandedMessages) {
            newExpandedMessages[key] = expandedMessages[key];
        }
        newExpandedMessages[messageId] = !newExpandedMessages[messageId];
        expandedMessages = newExpandedMessages;
    }

    Connections {
        target: SessionData
        function onDoNotDisturbChanged() {
            if (SessionData.doNotDisturb) {
                // Hide all current popups when DND is enabled
                for (const notif of visibleNotifications) {
                    notif.popup = false;
                }
                visibleNotifications = [];
                notificationQueue = [];
            } else {
                // Re-enable popup processing when DND is disabled
                processQueue();
            }
        }
    }

    Connections {
        target: typeof SettingsData !== "undefined" ? SettingsData : null
        function onUse24HourClockChanged() {
            root.clockFormatChanged = !root.clockFormatChanged;
        }
        function onNotificationHistoryMaxAgeDaysChanged() {
            root.pruneHistory();
        }
        function onNotificationHistoryEnabledChanged() {
            if (!SettingsData.notificationHistoryEnabled) {
                root.deleteHistory();
            }
        }
    }
}
