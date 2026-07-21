pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.Common

Singleton {
    id: root

    property var currentPopoutsByScreen: ({})
    property var currentPopoutTriggers: ({})

    // Set by the screenshot IPC handshake (dms screenshot region select); cleared by end() or any popout/modal open.
    property bool screenshotActive: false

    signal popoutOpening
    signal popoutChanged

    property real hoverCursorGlobalX: 0
    property real hoverCursorGlobalY: 0

    function updateHoverCursor(gx, gy) {
        hoverCursorGlobalX = gx;
        hoverCursorGlobalY = gy;
    }

    function cursorOverBar(gx, gy, padding, excludedWindow) {
        const pad = padding !== undefined ? padding : 16;
        const bars = KeyboardFocus.barWindows || [];
        for (let i = 0; i < bars.length; i++) {
            const w = bars[i];
            if (!w?.visible || w === excludedWindow)
                continue;
            if (typeof w.containsGlobalPoint === "function") {
                if (w.containsGlobalPoint(gx, gy, pad))
                    return true;
                continue;
            }
            const item = w.contentItem;
            if (!item || typeof item.mapToItem !== "function")
                continue;
            const topLeft = item.mapToItem(null, 0, 0);
            if (!topLeft)
                continue;
            if (gx >= topLeft.x - pad && gx < topLeft.x + item.width + pad && gy >= topLeft.y - pad && gy < topLeft.y + item.height + pad)
                return true;
        }
        return false;
    }

    function _isPopoutPresented(popout) {
        if (!popout)
            return false;
        try {
            if (popout.dashVisible !== undefined)
                return !!popout.dashVisible;
            if (popout.notificationHistoryVisible !== undefined)
                return !!popout.notificationHistoryVisible;
            return !!(popout.shouldBeVisible || popout.isClosing);
        } catch (e) {
            return false;
        }
    }

    function _openPopout(popout) {
        if (popout.dashVisible !== undefined) {
            let flagStayedTrue = popout.dashVisible === true;
            if (popout.dashVisible && !popout.shouldBeVisible && !popout.isClosing) {
                popout.dashVisible = false;
                flagStayedTrue = false;
            }
            popout.dashVisible = true;
            // Flag already true (e.g. retargeting to another monitor) won't re-fire
            // the change handler, so drive the surface open explicitly.
            if (flagStayedTrue)
                _ensureSurfaceOpen(popout);
            return;
        }
        if (popout.notificationHistoryVisible !== undefined) {
            const flagStayedTrue = popout.notificationHistoryVisible === true;
            popout.notificationHistoryVisible = true;
            if (flagStayedTrue)
                _ensureSurfaceOpen(popout);
            return;
        }
        _ensureSurfaceOpen(popout);
    }

    function _ensureSurfaceOpen(popout) {
        if (typeof popout.present === "function") {
            popout.present();
            return;
        }
        if (typeof popout.open === "function")
            popout.open();
    }

    function _closePopout(popout) {
        try {
            if (popout.hoverDismissEnabled !== undefined)
                popout.hoverDismissEnabled = false;
            switch (true) {
            case popout.dashVisible !== undefined:
                popout.dashVisible = false;
                return;
            case popout.notificationHistoryVisible !== undefined:
                popout.notificationHistoryVisible = false;
                return;
            default:
                if (typeof popout.close !== "function")
                    return;
                popout.close();
            }
        } catch (e) {
            return;
        }
    }

    function _dismissPopoutFromHover(popout) {
        try {
            if (!popout || popout.hoverDismissEnabled !== true)
                return;
            if (typeof popout.closeFromHoverDismiss === "function") {
                popout.closeFromHoverDismiss();
                return;
            }
            _closePopout(popout);
        } catch (e) {
            return;
        }
    }

    function _isStale(popout) {
        try {
            if (!popout || !("shouldBeVisible" in popout))
                return true;
            if (!popout.screen)
                return true;
            return false;
        } catch (e) {
            return true;
        }
    }

    function showPopout(popout) {
        if (!popout || !popout.screen)
            return;
        screenshotActive = false;
        popoutOpening();

        const screenName = popout.screen.name;

        for (const otherScreenName in currentPopoutsByScreen) {
            const otherPopout = currentPopoutsByScreen[otherScreenName];
            if (!otherPopout || otherPopout === popout)
                continue;
            if (_isStale(otherPopout)) {
                currentPopoutsByScreen[otherScreenName] = null;
                continue;
            }
            _closePopout(otherPopout);
        }

        currentPopoutsByScreen[screenName] = popout;
        popoutChanged();
        ModalManager.closeAllModalsExcept(null);
    }

    function hidePopout(popout) {
        if (!popout || !popout.screen)
            return;
        const screenName = popout.screen.name;
        if (currentPopoutsByScreen[screenName] === popout) {
            currentPopoutsByScreen[screenName] = null;
            currentPopoutTriggers[screenName] = null;
            popoutChanged();
        }
    }

    function closeAllPopouts() {
        for (const screenName in currentPopoutsByScreen) {
            const popout = currentPopoutsByScreen[screenName];
            if (!popout || _isStale(popout))
                continue;
            _closePopout(popout);
        }
        // Keep map entries until each popout's close animation finishes (hidePopout).
    }

    function closePopoutForScreen(screen) {
        if (!screen)
            return;
        const screenName = screen.name;
        const popout = currentPopoutsByScreen[screenName];
        if (!popout || _isStale(popout)) {
            currentPopoutsByScreen[screenName] = null;
            currentPopoutTriggers[screenName] = null;
            return;
        }
        _closePopout(popout);
    }

    function dismissHoverPopoutForScreen(screen) {
        if (!screen)
            return;
        const screenName = screen.name;
        const popout = currentPopoutsByScreen[screenName];
        if (!popout || _isStale(popout)) {
            currentPopoutsByScreen[screenName] = null;
            currentPopoutTriggers[screenName] = null;
            return;
        }
        _dismissPopoutFromHover(popout);
    }

    function cancelHoverDismiss(screen) {
        const popout = getActivePopout(screen);
        if (popout?.cancelHoverDismiss)
            popout.cancelHoverDismiss();
    }

    function getActivePopout(screen) {
        if (!screen)
            return null;
        return currentPopoutsByScreen[screen.name] || null;
    }

    // Checks if the active popout is pinned for auto-dismissal
    function isActivePopoutPinned(screen) {
        const p = getActivePopout(screen);
        if (!p || !_isPopoutPresented(p))
            return false;
        const dismissSuspended = p.effectiveHoverDismissSuspended ?? p.hoverDismissSuspended;
        return p.hoverDismissEnabled === false || dismissSuspended === true;
    }

    function isCurrentPopout(popout, screenName) {
        const name = screenName || popout?.screen?.name || "";
        return !!name && currentPopoutsByScreen[name] === popout;
    }

    function _requestPopout(popout, tabIndex, triggerSource, hoverRequest) {
        if (!popout || !popout.screen)
            return;

        // Clicking a transient popout pins it instead of toggling it closed.
        const wasTransient = popout.hoverDismissEnabled === true;
        if (!hoverRequest && popout.hoverDismissEnabled !== undefined)
            popout.hoverDismissEnabled = false;

        screenshotActive = false;
        const screenName = popout.screen.name;
        const currentPopout = currentPopoutsByScreen[screenName];
        const triggerId = triggerSource !== undefined ? triggerSource : tabIndex;
        const alreadyPresented = currentPopout === popout && (hoverRequest ? _isPopoutPresented(popout) : popout.shouldBeVisible);

        const willOpen = !(alreadyPresented && triggerId !== undefined && currentPopoutTriggers[screenName] === triggerId);
        if (willOpen)
            popoutOpening();

        let movedFromOtherScreen = false;
        for (const otherScreenName in currentPopoutsByScreen) {
            if (otherScreenName === screenName)
                continue;
            const otherPopout = currentPopoutsByScreen[otherScreenName];
            if (!otherPopout)
                continue;

            if (_isStale(otherPopout)) {
                currentPopoutsByScreen[otherScreenName] = null;
                currentPopoutTriggers[otherScreenName] = null;
                continue;
            }

            if (otherPopout === popout) {
                movedFromOtherScreen = true;
                currentPopoutsByScreen[otherScreenName] = null;
                currentPopoutTriggers[otherScreenName] = null;
                continue;
            }

            _closePopout(otherPopout);
        }

        if (currentPopout && currentPopout !== popout) {
            if (_isStale(currentPopout)) {
                currentPopoutsByScreen[screenName] = null;
                currentPopoutTriggers[screenName] = null;
            } else {
                if (hoverRequest && typeof currentPopout.beginSupersededClose === "function")
                    currentPopout.beginSupersededClose();
                _closePopout(currentPopout);
            }
        }

        if (alreadyPresented && !movedFromOtherScreen) {
            const sameDefinedTrigger = triggerId !== undefined && currentPopoutTriggers[screenName] === triggerId;
            if (hoverRequest && sameDefinedTrigger)
                return;

            if (!hoverRequest && (triggerId === undefined || sameDefinedTrigger)) {
                if (!wasTransient) {
                    _closePopout(popout);
                    return;
                }
                if (popout.updateSurfacePosition)
                    popout.updateSurfacePosition();
                if (triggerId !== undefined)
                    currentPopoutTriggers[screenName] = triggerId;
                return;
            }

            if (tabIndex !== undefined && popout.currentTabIndex !== undefined) {
                popout.currentTabIndex = tabIndex;
            }
            if (popout.updateSurfacePosition)
                popout.updateSurfacePosition();
            currentPopoutTriggers[screenName] = triggerId;
            if (hoverRequest && popout.hoverDismissEnabled !== undefined)
                popout.hoverDismissEnabled = true;
            return;
        }

        currentPopoutTriggers[screenName] = triggerId;
        currentPopoutsByScreen[screenName] = popout;
        popoutChanged();

        if (tabIndex !== undefined && popout.currentTabIndex !== undefined) {
            popout.currentTabIndex = tabIndex;
        }

        if (currentPopout !== popout) {
            ModalManager.closeAllModalsExcept(null);
        }

        if (hoverRequest && popout.hoverDismissEnabled !== undefined)
            popout.hoverDismissEnabled = true;

        _openPopout(popout);
    }

    function requestPopout(popout, tabIndex, triggerSource) {
        _requestPopout(popout, tabIndex, triggerSource, false);
    }

    function requestHoverPopout(popout, tabIndex, triggerSource) {
        _requestPopout(popout, tabIndex, triggerSource, true);
    }
}
