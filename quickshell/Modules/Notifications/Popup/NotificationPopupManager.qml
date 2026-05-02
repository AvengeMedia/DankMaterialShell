pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

QtObject {
    id: manager

    property var modelData
    property int topMargin: 0
    readonly property bool compactMode: SettingsData.notificationCompactMode
    readonly property bool notificationConnectedMode: SettingsData.frameEnabled && Theme.isConnectedEffect && SettingsData.isScreenInPreferences(manager.modelData, SettingsData.frameScreenPreferences)
    readonly property bool closeGapNotifications: notificationConnectedMode && SettingsData.frameCloseGaps
    readonly property string notifBarSide: {
        const pos = SettingsData.notificationPopupPosition;
        if (pos === -1)
            return "top";
        switch (pos) {
        case SettingsData.Position.Top:
            return "right";
        case SettingsData.Position.Left:
            return "left";
        case SettingsData.Position.BottomCenter:
            return "bottom";
        case SettingsData.Position.Right:
            return "right";
        case SettingsData.Position.Bottom:
            return "left";
        default:
            return "top";
        }
    }
    readonly property real cardPadding: compactMode ? Theme.notificationCardPaddingCompact : Theme.notificationCardPadding
    readonly property real popupIconSize: compactMode ? Theme.notificationIconSizeCompact : Theme.notificationIconSizeNormal
    readonly property real actionButtonHeight: compactMode ? 20 : 24
    readonly property real contentSpacing: compactMode ? Theme.spacingXS : Theme.spacingS
    readonly property real popupSpacing: notificationConnectedMode ? 0 : (compactMode ? 0 : Theme.spacingXS)
    readonly property real collapsedContentHeight: Math.max(popupIconSize, Theme.fontSizeSmall * 1.2 + Theme.fontSizeMedium * 1.2 + Theme.fontSizeSmall * 1.2 * (compactMode ? 1 : 2))
    readonly property int baseNotificationHeight: cardPadding * 2 + collapsedContentHeight + actionButtonHeight + contentSpacing + popupSpacing
    property var popupWindows: []
    property var destroyingWindows: new Set()
    property var pendingDestroys: []
    property int destroyDelayMs: 100
    property bool _chromeSyncPending: false
    property bool _syncingVisibleNotifications: false
    readonly property real chromeOpenProgressThreshold: 0.10
    readonly property real chromeReleaseTailStart: 0.90
    readonly property real chromeReleaseDropProgress: 0.995
    property Component popupComponent

    popupComponent: Component {
        NotificationPopup {
            onExitFinished: manager._onPopupExitFinished(this)
            onExitStarted: manager._onPopupExitStarted(this)
            onPopupHeightChanged: manager._onPopupHeightChanged(this)
            onPopupChromeGeometryChanged: manager._onPopupChromeGeometryChanged(this)
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

    function _layoutWindows() {
        return popupWindows.filter(p => _isValidWindow(p) && p.notificationData?.popup && !p.exiting && (!p.popupLayoutReservesSlot || p.popupLayoutReservesSlot()));
    }

    function _chromeWindows() {
        return popupWindows.filter(p => {
            if (!p || p.status === Component.Null || !p.visible || p._finalized || !p.hasValidData)
                return false;
            if (!p.notificationData?.popup && !p.exiting)
                return false;
            if (p.exiting && p.notificationData?.removedByLimit && _layoutWindows().length > 0)
                return true;
            if (!p.exiting && p.popupChromeOpenProgress && p.popupChromeOpenProgress() < chromeOpenProgressThreshold)
                return false;
            // Keep the connected shell until the card is almost fully closed.
            if (p.exiting && !p.swipeActive && p.popupChromeReleaseProgress) {
                if (p.popupChromeReleaseProgress() > chromeReleaseDropProgress)
                    return false;
            }
            return true;
        });
    }

    function _isFocusedScreen() {
        if (!SettingsData.notificationFocusedMonitor)
            return true;
        const focused = CompositorService.getFocusedScreen();
        return focused && manager.modelData && focused.name === manager.modelData.name;
    }

    function _sync(newWrappers) {
        let needsReposition = false;
        _syncingVisibleNotifications = true;
        for (const p of popupWindows.slice()) {
            if (!_isValidWindow(p) || p.exiting)
                continue;
            if (p.notificationData && newWrappers.indexOf(p.notificationData) === -1) {
                p.notificationData.removedByLimit = true;
                p.notificationData.popup = false;
                needsReposition = true;
            }
        }
        for (const w of newWrappers) {
            if (w && !_hasWindowFor(w) && _isFocusedScreen()) {
                needsReposition = _insertAtTop(w, true) || needsReposition;
            }
        }
        _syncingVisibleNotifications = false;
        if (needsReposition)
            _repositionAll();
    }

    function _popupHeight(p) {
        return (p.alignedHeight || p.implicitHeight || (baseNotificationHeight - popupSpacing)) + popupSpacing;
    }

    function _insertAtTop(wrapper, deferReposition) {
        if (!wrapper)
            return false;
        const notificationId = wrapper?.notification ? wrapper.notification.id : "";
        const win = popupComponent.createObject(null, {
            "notificationData": wrapper,
            "notificationId": notificationId,
            "screenY": topMargin,
            "screen": manager.modelData
        });
        if (!win)
            return false;
        if (!win.hasValidData) {
            win.destroy();
            return false;
        }
        popupWindows.unshift(win);
        if (!deferReposition)
            _repositionAll();
        if (!sweeper.running)
            sweeper.start();
        return true;
    }

    function _repositionAll() {
        const active = _layoutWindows();

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
        _scheduleNotificationChromeSync();
    }

    function _scheduleNotificationChromeSync() {
        if (_chromeSyncPending)
            return;
        _chromeSyncPending = true;
        Qt.callLater(() => {
            _chromeSyncPending = false;
            _syncNotificationChromeState();
        });
    }

    function _clamp01(value) {
        return Math.max(0, Math.min(1, value));
    }

    function _clipRectFromBarSide(rect, visibleFraction) {
        const fraction = _clamp01(visibleFraction);
        const w = Math.max(0, rect.right - rect.x);
        const h = Math.max(0, rect.bottom - rect.y);

        if (notifBarSide === "right") {
            rect.x = rect.right - w * fraction;
        } else if (notifBarSide === "left") {
            rect.right = rect.x + w * fraction;
        } else if (notifBarSide === "bottom") {
            rect.y = rect.bottom - h * fraction;
        } else {
            rect.bottom = rect.y + h * fraction;
        }
        return rect;
    }

    function _popupChromeVisibleFraction(p) {
        if (p.popupChromeReleaseProgress) {
            const rel = p.popupChromeReleaseProgress();
            if (p.exiting)
                return Math.max(0, 1 - rel);
            if (rel > 0)
                return p.swipeDismissTowardEdge ? Math.max(0, 1 - rel) : 1 - _chromeReleaseTailProgress(rel);
        }
        if (p.popupChromeOpenProgress)
            return _clamp01(p.popupChromeOpenProgress());
        return 1;
    }

    function _popupChromeRect(p, useMotionOffset) {
        if (!p || !p.screen)
            return null;
        const x = p.getContentX ? p.getContentX() : 0;
        const y = p.getContentY ? p.getContentY() : 0;
        const w = p.alignedWidth || 0;
        const h = Math.max(p.alignedHeight || 0, baseNotificationHeight);
        if (w <= 0 || h <= 0)
            return null;
        const rect = {
            x: x,
            y: y,
            right: x + w,
            bottom: y + h
        };

        if (!useMotionOffset)
            return rect;

        if (p.popupChromeFollowsCardMotion && p.popupChromeFollowsCardMotion()) {
            const motionX = p.popupChromeMotionX ? p.popupChromeMotionX() : 0;
            const motionY = p.popupChromeMotionY ? p.popupChromeMotionY() : 0;
            rect.x += motionX;
            rect.y += motionY;
            rect.right += motionX;
            rect.bottom += motionY;
            return rect;
        }

        return _clipRectFromBarSide(rect, _popupChromeVisibleFraction(p));
    }

    function _chromeReleaseTailProgress(rawProgress) {
        const progress = Math.max(0, Math.min(1, rawProgress));
        if (progress <= chromeReleaseTailStart)
            return 0;
        return Math.max(0, Math.min(1, (progress - chromeReleaseTailStart) / Math.max(0.001, 1 - chromeReleaseTailStart)));
    }

    function _popupChromeBoundsRect(p, trailing, useMotionOffset) {
        const rect = _popupChromeRect(p, useMotionOffset);
        if (!rect || p !== trailing || !p.popupChromeReleaseProgress)
            return rect;

        // Keep maxed-stack chrome anchored while a replacement tail exits.
        if (p.exiting && p.notificationData?.removedByLimit && _layoutWindows().length > 0)
            return rect;

        const progress = _chromeReleaseTailProgress(p.popupChromeReleaseProgress());
        if (progress <= 0)
            return rect;

        const anchorsTop = _stackAnchorsTop();
        const h = Math.max(0, rect.bottom - rect.y);
        const shrink = h * progress;
        if (anchorsTop)
            rect.bottom = Math.max(rect.y, rect.bottom - shrink);
        else
            rect.y = Math.min(rect.bottom, rect.y + shrink);
        return rect;
    }

    function _stackAnchorsTop() {
        const pos = SettingsData.notificationPopupPosition;
        return pos === -1 || pos === SettingsData.Position.Top || pos === SettingsData.Position.Left;
    }

    function _frameEdgeInset(side) {
        if (!manager.modelData)
            return 0;
        const edges = SettingsData.getActiveBarEdgesForScreen(manager.modelData);
        const raw = edges.includes(side) ? SettingsData.frameBarSize : SettingsData.frameThickness;
        const dpr = CompositorService.getScreenScale(manager.modelData);
        return Math.max(0, Math.round(Theme.px(raw, dpr)));
    }

    function _closeGapChromeAnchorEdge(anchorsTop) {
        if (!closeGapNotifications || !manager.modelData)
            return null;
        if (anchorsTop)
            return _frameEdgeInset("top") + topMargin;
        return manager.modelData.height - _frameEdgeInset("bottom") - topMargin;
    }

    function _trailingChromeWindow(candidates) {
        const anchorsTop = _stackAnchorsTop();
        let trailing = null;
        let edge = anchorsTop ? -Infinity : Infinity;
        for (const p of candidates) {
            const rect = _popupChromeRect(p, false);
            if (!rect)
                continue;
            const candidateEdge = anchorsTop ? rect.bottom : rect.y;
            if ((anchorsTop && candidateEdge > edge) || (!anchorsTop && candidateEdge < edge)) {
                edge = candidateEdge;
                trailing = p;
            }
        }
        return trailing;
    }

    function _chromeWindowReservesSlot(p, trailing) {
        if (p === trailing)
            return true;
        return !p.popupChromeReservesSlot || p.popupChromeReservesSlot();
    }

    function _stackAnchoredChromeEdge(candidates) {
        const anchorsTop = _stackAnchorsTop();
        let edge = anchorsTop ? Infinity : -Infinity;
        for (const p of candidates) {
            const rect = _popupChromeRect(p, false);
            if (!rect)
                continue;
            if (anchorsTop && rect.y < edge)
                edge = rect.y;
            if (!anchorsTop && rect.bottom > edge)
                edge = rect.bottom;
        }
        if (edge === Infinity || edge === -Infinity)
            return null;
        return {
            anchorsTop: anchorsTop,
            edge: edge
        };
    }

    function _filledMaxStackChromeEdge(candidates, stackEdge) {
        const layoutWindows = _layoutWindows();
        if (layoutWindows.length < NotificationService.maxVisibleNotifications)
            return null;
        const anchorsTop = _stackAnchorsTop();
        const layoutAnchorEdge = _stackAnchoredChromeEdge(layoutWindows);
        const anchorEdge = layoutAnchorEdge !== null ? layoutAnchorEdge : (stackEdge !== null ? stackEdge : _stackAnchoredChromeEdge(candidates));
        if (anchorEdge === null)
            return null;
        let span = 0;
        for (const p of layoutWindows) {
            const rect = _popupChromeRect(p, false);
            if (!rect)
                continue;
            span += Math.max(0, rect.bottom - rect.y);
        }
        if (span <= 0)
            return null;
        if (layoutWindows.length > 1)
            span += popupSpacing * (layoutWindows.length - 1);
        return {
            anchorsTop: anchorsTop,
            startEdge: anchorEdge.edge,
            edge: anchorsTop ? anchorEdge.edge + span : anchorEdge.edge - span
        };
    }

    function _syncNotificationChromeState() {
        const screenName = manager.modelData?.name || "";
        if (!screenName)
            return;
        if (!notificationConnectedMode) {
            ConnectedModeState.clearNotificationState(screenName);
            return;
        }
        const chromeCandidates = _chromeWindows();
        if (chromeCandidates.length === 0) {
            ConnectedModeState.clearNotificationState(screenName);
            return;
        }

        const trailing = chromeCandidates.length > 1 ? _trailingChromeWindow(chromeCandidates) : null;
        let active = chromeCandidates;
        if (chromeCandidates.length > 1) {
            const reserving = chromeCandidates.filter(p => _chromeWindowReservesSlot(p, trailing));
            if (reserving.length > 0)
                active = reserving;
        }

        let minX = Infinity;
        let minY = Infinity;
        let maxXEnd = -Infinity;
        let maxYEnd = -Infinity;
        const useMotionOffset = active.length === 1 && active[0].popupChromeMotionActive && active[0].popupChromeMotionActive();
        for (const p of active) {
            const rect = _popupChromeBoundsRect(p, trailing, useMotionOffset);
            if (!rect)
                continue;
            if (rect.x < minX)
                minX = rect.x;
            if (rect.y < minY)
                minY = rect.y;
            if (rect.right > maxXEnd)
                maxXEnd = rect.right;
            if (rect.bottom > maxYEnd)
                maxYEnd = rect.bottom;
        }
        const stackEdge = _stackAnchoredChromeEdge(chromeCandidates);
        if (stackEdge !== null) {
            if (stackEdge.anchorsTop && stackEdge.edge < minY)
                minY = stackEdge.edge;
            if (!stackEdge.anchorsTop && stackEdge.edge > maxYEnd)
                maxYEnd = stackEdge.edge;
        }
        const filledMaxStackEdge = _filledMaxStackChromeEdge(chromeCandidates, stackEdge);
        if (filledMaxStackEdge !== null) {
            if (filledMaxStackEdge.anchorsTop) {
                minY = filledMaxStackEdge.startEdge;
                maxYEnd = filledMaxStackEdge.edge;
            } else {
                minY = filledMaxStackEdge.edge;
                maxYEnd = filledMaxStackEdge.startEdge;
            }
        }
        const anchorsTop = stackEdge !== null ? stackEdge.anchorsTop : _stackAnchorsTop();
        const closeGapAnchorEdge = _closeGapChromeAnchorEdge(anchorsTop);
        if (closeGapAnchorEdge !== null) {
            if (anchorsTop)
                minY = closeGapAnchorEdge;
            else
                maxYEnd = closeGapAnchorEdge;
        }
        if (minX === Infinity || minY === Infinity || maxXEnd <= minX || maxYEnd <= minY) {
            ConnectedModeState.clearNotificationState(screenName);
            return;
        }
        ConnectedModeState.setNotificationState(screenName, {
            visible: true,
            barSide: notifBarSide,
            bodyX: minX,
            bodyY: minY,
            bodyW: maxXEnd - minX,
            bodyH: maxYEnd - minY,
            omitStartConnector: _notificationOmitStartConnector(),
            omitEndConnector: _notificationOmitEndConnector()
        });
    }

    function _notificationOmitStartConnector() {
        return closeGapNotifications && (SettingsData.notificationPopupPosition === SettingsData.Position.Top || SettingsData.notificationPopupPosition === SettingsData.Position.Left);
    }

    function _notificationOmitEndConnector() {
        return closeGapNotifications && (SettingsData.notificationPopupPosition === SettingsData.Position.Right || SettingsData.notificationPopupPosition === SettingsData.Position.Bottom);
    }

    function _onPopupChromeGeometryChanged(p) {
        if (!p || popupWindows.indexOf(p) === -1)
            return;
        _scheduleNotificationChromeSync();
    }

    // Coalesce resize repositioning; exit-path moves remain immediate.
    property bool _repositionPending: false

    function _queueReposition() {
        if (_repositionPending)
            return;
        _repositionPending = true;
        Qt.callLater(_flushReposition);
    }

    function _flushReposition() {
        _repositionPending = false;
        _repositionAll();
    }

    function _onPopupHeightChanged(p) {
        if (!p || p.exiting || p._isDestroying)
            return;
        if (popupWindows.indexOf(p) === -1)
            return;
        _queueReposition();
    }

    function _onPopupExitStarted(p) {
        if (!p || popupWindows.indexOf(p) === -1)
            return;
        if (_syncingVisibleNotifications)
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
        _chromeSyncPending = false;
        _syncNotificationChromeState();
    }

    onNotificationConnectedModeChanged: _scheduleNotificationChromeSync()
    onCloseGapNotificationsChanged: _scheduleNotificationChromeSync()
    onNotifBarSideChanged: _scheduleNotificationChromeSync()
    onModelDataChanged: _scheduleNotificationChromeSync()
    onTopMarginChanged: _repositionAll()

    onPopupWindowsChanged: {
        if (popupWindows.length > 0 && !sweeper.running) {
            sweeper.start();
        } else if (popupWindows.length === 0 && sweeper.running) {
            sweeper.stop();
        }
    }
}
