import QtQuick
import qs.Common
import qs.Services

QtObject {
    id: manager

    property var modelData
    property int topMargin: 0
    readonly property bool compactMode: SettingsData.notificationCompactMode
    readonly property real cardPadding: compactMode ? Theme.notificationCardPaddingCompact : Theme.notificationCardPadding
    readonly property real popupIconSize: compactMode ? Theme.notificationIconSizeCompact : Theme.notificationIconSizeNormal
    readonly property real actionButtonHeight: compactMode ? 20 : 24
    readonly property real contentSpacing: compactMode ? Theme.spacingXS : Theme.spacingS
    readonly property real popupSpacing: compactMode ? 0 : Theme.spacingXS
    readonly property real collapsedContentHeight: Math.max(popupIconSize, Theme.fontSizeSmall * 1.2 + Theme.fontSizeMedium * 1.2 + Theme.fontSizeSmall * 1.2 * (compactMode ? 1 : 2))
    readonly property int baseNotificationHeight: cardPadding * 2 + collapsedContentHeight + actionButtonHeight + contentSpacing + popupSpacing
    property var popupWindows: []
    property var destroyingWindows: new Set()
    property var pendingDestroys: []
    property int destroyDelayMs: 100
    property Component popupComponent

    popupComponent: Component {
        NotificationPopup {
            onExitFinished: manager._onPopupExitFinished(this)
            onPopupHeightChanged: manager._onPopupHeightChanged(this)
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
                _repositionAll();
            }
            if (popupWindows.length === 0)
                sweeper.stop();
        }
    }

    function _hasWindowFor(w) {
        return popupWindows.some(p => p && p.notificationData === w && !p._isDestroying && p.status !== Component.Null);
    }

    function _isValidWindow(p) {
        return p && p.status !== Component.Null && !p._isDestroying && p.hasValidData;
    }

    function _sync(newWrappers) {
        for (const p of popupWindows.slice()) {
            if (!_isValidWindow(p) || p.exiting)
                continue;
            if (p.notificationData && newWrappers.indexOf(p.notificationData) === -1) {
                p.notificationData.removedByLimit = true;
                p.notificationData.popup = false;
            }
        }
        for (const w of newWrappers) {
            if (w && !_hasWindowFor(w))
                _insertAtTop(w);
        }
    }

    function _popupHeight(p) {
        return (p.alignedHeight || p.implicitHeight || (baseNotificationHeight - popupSpacing)) + popupSpacing;
    }

    function _insertAtTop(wrapper) {
        if (!wrapper)
            return;
        const notificationId = wrapper?.notification ? wrapper.notification.id : "";
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
        popupWindows.unshift(win);
        _repositionAll();
        if (!sweeper.running)
            sweeper.start();
    }

    function _repositionAll() {
        const active = popupWindows.filter(p => _isValidWindow(p) && p.notificationData?.popup && !p.exiting);

        const pinnedSlots = [];
        for (const p of active) {
            if (!p.hovered)
                continue;
            pinnedSlots.push({
                y: p.screenY,
                end: p.screenY + _popupHeight(p)
            });
        }
        pinnedSlots.sort((a, b) => a.y - b.y);

        let currentY = topMargin;
        for (const win of active) {
            if (win.hovered)
                continue;
            for (const slot of pinnedSlots) {
                if (currentY >= slot.y - 1 && currentY < slot.end)
                    currentY = slot.end;
            }
            win.screenY = currentY;
            currentY += _popupHeight(win);
        }
    }

    function _onPopupHeightChanged(p) {
        if (!p || p.exiting || p._isDestroying)
            return;
        if (popupWindows.indexOf(p) === -1)
            return;
        _repositionAll();
    }

    function _onPopupExitFinished(p) {
        if (!p)
            return;
        const windowId = p.toString();
        if (destroyingWindows.has(windowId))
            return;
        destroyingWindows.add(windowId);
        const i = popupWindows.indexOf(p);
        if (i !== -1) {
            popupWindows.splice(i, 1);
            popupWindows = popupWindows.slice();
        }
        if (NotificationService.releaseWrapper && p.notificationData)
            NotificationService.releaseWrapper(p.notificationData);
        _scheduleDestroy(p);
        Qt.callLater(() => destroyingWindows.delete(windowId));
        _repositionAll();
    }

    function cleanupAllWindows() {
        sweeper.stop();
        destroyTimer.stop();
        pendingDestroys = [];
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
