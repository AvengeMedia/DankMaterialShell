import QtQuick
import qs.Common
import qs.Services

QtObject {
    id: manager

    property var modelData
    property int topMargin: 0
    readonly property bool compactMode: SettingsData.notificationCompactMode
    readonly property real cardPadding: compactMode ? Theme.spacingS : Theme.spacingM
    readonly property real popupIconSize: compactMode ? 48 : 63
    readonly property real actionButtonHeight: compactMode ? 20 : 24
    readonly property real popupSpacing: 4
    readonly property int baseNotificationHeight: cardPadding * 2 + popupIconSize + actionButtonHeight + Theme.spacingS + popupSpacing
    property int maxTargetNotifications: 4
    property var popupWindows: [] // strong refs to windows (live until exitFinished)
    property var destroyingWindows: new Set()
    property var pendingDestroys: []
    property int destroyDelayMs: 100
    property var pendingCreates: []
    property int createDelayMs: 50
    property bool createBusy: false
    property Component popupComponent

    popupComponent: Component {
        NotificationPopup {
            onEntered: manager._onPopupEntered(this)
            onExitStarted: manager._onPopupExitStarted(this)
            onExitFinished: manager._onPopupExitFinished(this)
        }
    }

    property Connections notificationConnections

    notificationConnections: Connections {
        function onVisibleNotificationsChanged() {
            manager._sync(NotificationService.visibleNotifications);
        }

        target: NotificationService
    }

    property Timer sweeper

    property Timer destroyTimer: Timer {
        interval: destroyDelayMs
        running: false
        repeat: false
        onTriggered: manager._processDestroyQueue()
    }

    function _processDestroyQueue() {
        if (pendingDestroys.length === 0)
            return;
        const p = pendingDestroys.shift();
        if (p && p.destroy) {
            try {
                p.destroy();
            } catch (e) {}
        }
        if (pendingDestroys.length > 0)
            destroyTimer.restart();
    }

    function _scheduleDestroy(p) {
        if (!p)
            return;
        pendingDestroys.push(p);
        if (!destroyTimer.running)
            destroyTimer.restart();
    }

    property Timer createTimer: Timer {
        interval: createDelayMs
        running: false
        repeat: false
        onTriggered: manager._processCreateQueue()
    }

    function _processCreateQueue() {
        createBusy = false;
        if (pendingCreates.length === 0)
            return;
        const wrapper = pendingCreates.shift();
        if (wrapper)
            _doInsertNewestAtTop(wrapper);
        if (pendingCreates.length > 0) {
            createBusy = true;
            createTimer.restart();
        }
    }

    function _scheduleCreate(wrapper) {
        if (!wrapper)
            return;
        pendingCreates.push(wrapper);
        if (!createBusy) {
            createBusy = true;
            createTimer.restart();
        }
    }

    sweeper: Timer {
        interval: 500
        running: false
        repeat: true
        onTriggered: {
            const toRemove = [];
            for (const p of popupWindows) {
                if (!p) {
                    toRemove.push(p);
                    continue;
                }
                const isZombie = p.status === Component.Null || (!p.visible && !p.exiting) || (!p.notificationData && !p._isDestroying) || (!p.hasValidData && !p._isDestroying);
                if (isZombie) {
                    toRemove.push(p);
                    if (p.forceExit) {
                        p.forceExit();
                    } else if (p.destroy) {
                        try {
                            p.destroy();
                        } catch (e) {}
                    }
                }
            }
            if (toRemove.length) {
                popupWindows = popupWindows.filter(p => toRemove.indexOf(p) === -1);
                const survivors = _active().sort((a, b) => a.screenY - b.screenY);
                for (let k = 0; k < survivors.length; ++k) {
                    survivors[k].screenY = topMargin + k * baseNotificationHeight;
                }
            }
            if (popupWindows.length === 0) {
                sweeper.stop();
            }
        }
    }

    function _hasWindowFor(w) {
        return popupWindows.some(p => p && p.notificationData === w && !p._isDestroying && p.status !== Component.Null);
    }

    function _isValidWindow(p) {
        return p && p.status !== Component.Null && !p._isDestroying && p.hasValidData;
    }

    function _canMakeRoomFor(wrapper) {
        const activeWindows = _active();
        if (activeWindows.length < maxTargetNotifications) {
            return true;
        }
        if (!wrapper || !wrapper.notification) {
            return false;
        }
        const incomingUrgency = wrapper.urgency || 0;
        for (const p of activeWindows) {
            if (!p.notificationData || !p.notificationData.notification) {
                continue;
            }
            const existingUrgency = p.notificationData.urgency || 0;
            if (existingUrgency < incomingUrgency) {
                return true;
            }
            if (existingUrgency === incomingUrgency) {
                const timer = p.notificationData.timer;
                if (timer && !timer.running) {
                    return true;
                }
            }
        }
        return false;
    }

    function _makeRoomForNew(wrapper) {
        const activeWindows = _active();
        if (activeWindows.length < maxTargetNotifications) {
            return;
        }
        const toRemove = _selectPopupToRemove(activeWindows, wrapper);
        if (toRemove && !toRemove.exiting) {
            toRemove.notificationData.removedByLimit = true;
            toRemove.notificationData.popup = false;
            if (toRemove.notificationData.timer) {
                toRemove.notificationData.timer.stop();
            }
        }
    }

    function _selectPopupToRemove(activeWindows, incomingWrapper) {
        const sortedWindows = activeWindows.slice().sort((a, b) => {
            const aUrgency = (a.notificationData) ? a.notificationData.urgency || 0 : 0;
            const bUrgency = (b.notificationData) ? b.notificationData.urgency || 0 : 0;
            if (aUrgency !== bUrgency) {
                return aUrgency - bUrgency;
            }
            const aTimer = a.notificationData && a.notificationData.timer;
            const bTimer = b.notificationData && b.notificationData.timer;
            const aRunning = aTimer && aTimer.running;
            const bRunning = bTimer && bTimer.running;
            if (aRunning !== bRunning) {
                return aRunning ? 1 : -1;
            }
            return b.screenY - a.screenY;
        });
        return sortedWindows[0];
    }

    function _sync(newWrappers) {
        for (const w of newWrappers) {
            if (w && !_hasWindowFor(w)) {
                insertNewestAtTop(w);
            }
        }
        for (const p of popupWindows.slice()) {
            if (!_isValidWindow(p)) {
                continue;
            }
            if (p.notificationData && newWrappers.indexOf(p.notificationData) === -1 && !p.exiting) {
                p.notificationData.removedByLimit = true;
                p.notificationData.popup = false;
            }
        }
    }

    function insertNewestAtTop(wrapper) {
        if (!wrapper)
            return;
        if (createBusy || pendingCreates.length > 0) {
            _scheduleCreate(wrapper);
            return;
        }
        _doInsertNewestAtTop(wrapper);
    }

    function _doInsertNewestAtTop(wrapper) {
        if (!wrapper)
            return;
        for (const p of popupWindows) {
            if (!_isValidWindow(p))
                continue;
            if (p.exiting)
                continue;
            p.screenY = p.screenY + baseNotificationHeight;
        }
        const notificationId = wrapper && wrapper.notification ? wrapper.notification.id : "";
        const win = popupComponent.createObject(null, {
            "notificationData": wrapper,
            "notificationId": notificationId,
            "screenY": topMargin,
            "screen": manager.modelData
        });
        if (!win)
            return;
        if (!win.hasValidData) {
            win.destroy();
            return;
        }
        popupWindows.push(win);
        createBusy = true;
        createTimer.restart();
        if (!sweeper.running)
            sweeper.start();
    }

    function _active() {
        return popupWindows.filter(p => _isValidWindow(p) && p.notificationData && p.notificationData.popup && !p.exiting);
    }

    function _bottom() {
        let b = null;
        let maxY = -1;
        for (const p of _active()) {
            if (p.screenY > maxY) {
                maxY = p.screenY;
                b = p;
            }
        }
        return b;
    }

    function _onPopupEntered(p) {
    }

    function _onPopupExitStarted(p) {
        if (!p)
            return;
        const survivors = _active().sort((a, b) => a.screenY - b.screenY);
        for (let k = 0; k < survivors.length; ++k)
            survivors[k].screenY = topMargin + k * baseNotificationHeight;
    }

    function _onPopupExitFinished(p) {
        if (!p) {
            return;
        }
        const windowId = p.toString();
        if (destroyingWindows.has(windowId)) {
            return;
        }
        destroyingWindows.add(windowId);
        const i = popupWindows.indexOf(p);
        if (i !== -1) {
            popupWindows.splice(i, 1);
            popupWindows = popupWindows.slice();
        }
        if (NotificationService.releaseWrapper && p.notificationData) {
            NotificationService.releaseWrapper(p.notificationData);
        }
        _scheduleDestroy(p);
        Qt.callLater(() => destroyingWindows.delete(windowId));
        const survivors = _active().sort((a, b) => a.screenY - b.screenY);
        for (let k = 0; k < survivors.length; ++k) {
            survivors[k].screenY = topMargin + k * baseNotificationHeight;
        }
    }

    function cleanupAllWindows() {
        sweeper.stop();
        destroyTimer.stop();
        createTimer.stop();
        pendingDestroys = [];
        pendingCreates = [];
        createBusy = false;
        for (const p of popupWindows.slice()) {
            if (p) {
                try {
                    if (p.forceExit) {
                        p.forceExit();
                    } else if (p.destroy) {
                        p.destroy();
                    }
                } catch (e) {}
            }
        }
        popupWindows = [];
        destroyingWindows.clear();
    }

    onPopupWindowsChanged: {
        if (popupWindows.length > 0 && !sweeper.running) {
            sweeper.start();
        } else if (popupWindows.length === 0 && sweeper.running) {
            sweeper.stop();
        }
    }
}
