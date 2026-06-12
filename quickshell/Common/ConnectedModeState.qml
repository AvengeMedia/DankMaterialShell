pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "ConnectedSurfaceDescriptor.js" as SurfaceDescriptor

Singleton {
    id: root

    property var surfaceDescriptors: ({})

    function _surfaceSlot(kind) {
        return SurfaceDescriptor.slotForKind(kind);
    }

    function surfaceDescriptor(screenName, kind) {
        const slot = _surfaceSlot(kind);
        const screenDescriptors = screenName ? surfaceDescriptors[screenName] : null;
        const descriptor = screenDescriptors && screenDescriptors[slot] ? screenDescriptors[slot] : SurfaceDescriptor.empty(kind, screenName);
        let bodyRect = descriptor.bodyRect;
        let animationOffset = descriptor.animationOffset;
        if (slot === "popout" && popoutScreen === screenName) {
            bodyRect = {
                "x": popoutBodyX,
                "y": popoutBodyY,
                "width": popoutBodyW,
                "height": popoutBodyH
            };
            animationOffset = {
                "x": popoutAnimX,
                "y": popoutAnimY
            };
        } else if (slot === "modal" && modalStates[screenName]) {
            const modal = modalStates[screenName];
            bodyRect = {
                "x": modal.bodyX,
                "y": modal.bodyY,
                "width": modal.bodyW,
                "height": modal.bodyH
            };
            animationOffset = {
                "x": modal.animX,
                "y": modal.animY
            };
        } else if (slot === "dock" && dockStates[screenName]) {
            const dock = dockStates[screenName];
            const slide = dockSlides[screenName] || {
                "x": dock.slideX,
                "y": dock.slideY
            };
            bodyRect = {
                "x": dock.bodyX,
                "y": dock.bodyY,
                "width": dock.bodyW,
                "height": dock.bodyH
            };
            animationOffset = {
                "x": slide.x,
                "y": slide.y
            };
        } else if (slot === "notification" && notificationStates[screenName]) {
            const notification = notificationStates[screenName];
            bodyRect = {
                "x": notification.bodyX,
                "y": notification.bodyY,
                "width": notification.bodyW,
                "height": notification.bodyH
            };
        }
        return SurfaceDescriptor.normalize({
            "bodyRect": bodyRect,
            "animationOffset": animationOffset
        }, descriptor);
    }

    function hasSurfaceDescriptor(screenName, kind, ownerId) {
        const descriptor = surfaceDescriptor(screenName, kind);
        return descriptor.phase !== "hidden" && (!ownerId || descriptor.ownerId === ownerId);
    }

    function _setSurfaceDescriptor(screenName, slotKind, state, ownerId) {
        if (!screenName || !state)
            return false;
        const slot = _surfaceSlot(slotKind);
        const currentScreen = surfaceDescriptors[screenName] || {};
        const previous = currentScreen[slot] || SurfaceDescriptor.empty(state.kind || slotKind, screenName);
        let normalized = SurfaceDescriptor.normalize(Object.assign({}, state, {
            "ownerId": ownerId !== undefined ? ownerId : previous.ownerId,
            "screenName": screenName,
            "revision": previous.revision
        }), previous);
        if (SurfaceDescriptor.same(previous, normalized))
            return true;
        normalized = SurfaceDescriptor.withRevision(normalized, previous.revision + 1);
        const nextScreen = _cloneDict(currentScreen);
        nextScreen[slot] = normalized;
        const next = _cloneDict(surfaceDescriptors);
        next[screenName] = nextScreen;
        surfaceDescriptors = next;
        return true;
    }

    function _clearSurfaceDescriptor(screenName, kind, ownerId) {
        if (!screenName)
            return false;
        const slot = _surfaceSlot(kind);
        const currentScreen = surfaceDescriptors[screenName];
        const current = currentScreen ? currentScreen[slot] : null;
        if (!current || (ownerId && current.ownerId !== ownerId))
            return false;
        const nextScreen = _cloneDict(currentScreen);
        delete nextScreen[slot];
        const next = _cloneDict(surfaceDescriptors);
        if (Object.keys(nextScreen).length > 0)
            next[screenName] = nextScreen;
        else
            delete next[screenName];
        surfaceDescriptors = next;
        return true;
    }

    readonly property var emptyDockState: ({
            "reveal": false,
            "barSide": "bottom",
            "bodyX": 0,
            "bodyY": 0,
            "bodyW": 0,
            "bodyH": 0,
            "slideX": 0,
            "slideY": 0
        })

    property string popoutOwnerId: ""
    property bool popoutVisible: false
    property string popoutBarSide: "top"
    property real popoutBodyX: 0
    property real popoutBodyY: 0
    property real popoutBodyW: 0
    property real popoutBodyH: 0
    property real popoutAnimX: 0
    property real popoutAnimY: 0
    property string popoutScreen: ""
    property bool popoutOmitStartConnector: false
    property bool popoutOmitEndConnector: false

    property var dockStates: ({})

    property var dockSlides: ({})

    property var surfaceRevisions: ({})

    function _cloneDict(src) {
        const next = {};
        for (const k in src)
            next[k] = src[k];
        return next;
    }

    function _bumpSurfaceRevision(screenName) {
        if (!screenName)
            return;
        const next = _cloneDict(surfaceRevisions);
        next[screenName] = Number(next[screenName] || 0) + 1;
        surfaceRevisions = next;
    }

    function hasPopoutOwner(claimId) {
        return !!claimId && popoutOwnerId === claimId;
    }

    function claimPopout(claimId, state) {
        if (!claimId || !state)
            return false;

        const previousScreen = popoutScreen;
        popoutOwnerId = claimId;
        const ok = updatePopout(claimId, state);
        if (ok) {
            if (previousScreen && previousScreen !== popoutScreen) {
                _clearSurfaceDescriptor(previousScreen, "popout");
                _bumpSurfaceRevision(previousScreen);
            }
            _bumpSurfaceRevision(popoutScreen);
        }
        return ok;
    }

    function updatePopout(claimId, state) {
        if (!hasPopoutOwner(claimId) || !state)
            return false;

        if (state.visible !== undefined)
            popoutVisible = !!state.visible;
        if (state.barSide !== undefined)
            popoutBarSide = state.barSide || "top";
        if (state.bodyX !== undefined)
            popoutBodyX = Number(state.bodyX);
        if (state.bodyY !== undefined)
            popoutBodyY = Number(state.bodyY);
        if (state.bodyW !== undefined)
            popoutBodyW = Number(state.bodyW);
        if (state.bodyH !== undefined)
            popoutBodyH = Number(state.bodyH);
        if (state.animX !== undefined)
            popoutAnimX = Number(state.animX);
        if (state.animY !== undefined)
            popoutAnimY = Number(state.animY);
        if (state.screen !== undefined)
            popoutScreen = state.screen || "";
        if (state.omitStartConnector !== undefined)
            popoutOmitStartConnector = !!state.omitStartConnector;
        if (state.omitEndConnector !== undefined)
            popoutOmitEndConnector = !!state.omitEndConnector;

        _setSurfaceDescriptor(popoutScreen, "popout", Object.assign({}, state, {
            "kind": "popout",
            "screenName": popoutScreen,
            "visible": popoutVisible,
            "presented": state.presented !== undefined ? !!state.presented : popoutVisible,
            "barSide": popoutBarSide,
            "bodyX": popoutBodyX,
            "bodyY": popoutBodyY,
            "bodyW": popoutBodyW,
            "bodyH": popoutBodyH,
            "animX": popoutAnimX,
            "animY": popoutAnimY,
            "omitStartConnector": popoutOmitStartConnector,
            "omitEndConnector": popoutOmitEndConnector
        }), claimId);
        return true;
    }

    function releasePopout(claimId) {
        if (!hasPopoutOwner(claimId))
            return false;

        const releasedScreen = popoutScreen;
        popoutOwnerId = "";
        popoutVisible = false;
        popoutBarSide = "top";
        popoutBodyX = 0;
        popoutBodyY = 0;
        popoutBodyW = 0;
        popoutBodyH = 0;
        popoutAnimX = 0;
        popoutAnimY = 0;
        popoutScreen = "";
        popoutOmitStartConnector = false;
        popoutOmitEndConnector = false;
        _clearSurfaceDescriptor(releasedScreen, "popout", claimId);
        _bumpSurfaceRevision(releasedScreen);
        return true;
    }

    function setPopoutAnim(claimId, animX, animY) {
        if (!hasPopoutOwner(claimId))
            return false;
        if (animX !== undefined) {
            const nextX = Number(animX);
            if (!isNaN(nextX) && popoutAnimX !== nextX)
                popoutAnimX = nextX;
        }
        if (animY !== undefined) {
            const nextY = Number(animY);
            if (!isNaN(nextY) && popoutAnimY !== nextY)
                popoutAnimY = nextY;
        }
        return true;
    }

    function setPopoutBody(claimId, bodyX, bodyY, bodyW, bodyH) {
        if (!hasPopoutOwner(claimId))
            return false;
        if (bodyX !== undefined) {
            const nextX = Number(bodyX);
            if (!isNaN(nextX) && popoutBodyX !== nextX)
                popoutBodyX = nextX;
        }
        if (bodyY !== undefined) {
            const nextY = Number(bodyY);
            if (!isNaN(nextY) && popoutBodyY !== nextY)
                popoutBodyY = nextY;
        }
        if (bodyW !== undefined) {
            const nextW = Number(bodyW);
            if (!isNaN(nextW) && popoutBodyW !== nextW)
                popoutBodyW = nextW;
        }
        if (bodyH !== undefined) {
            const nextH = Number(bodyH);
            if (!isNaN(nextH) && popoutBodyH !== nextH)
                popoutBodyH = nextH;
        }
        return true;
    }

    function _normalizeDockState(state) {
        return {
            "reveal": !!(state && state.reveal),
            "barSide": state && state.barSide ? state.barSide : "bottom",
            "bodyX": Number(state && state.bodyX !== undefined ? state.bodyX : 0),
            "bodyY": Number(state && state.bodyY !== undefined ? state.bodyY : 0),
            "bodyW": Number(state && state.bodyW !== undefined ? state.bodyW : 0),
            "bodyH": Number(state && state.bodyH !== undefined ? state.bodyH : 0),
            "slideX": Number(state && state.slideX !== undefined ? state.slideX : 0),
            "slideY": Number(state && state.slideY !== undefined ? state.slideY : 0)
        };
    }

    function _sameDockState(a, b) {
        if (!a || !b)
            return false;
        return a.reveal === b.reveal && a.barSide === b.barSide && Math.abs(a.bodyX - b.bodyX) < 0.5 && Math.abs(a.bodyY - b.bodyY) < 0.5 && Math.abs(a.bodyW - b.bodyW) < 0.5 && Math.abs(a.bodyH - b.bodyH) < 0.5 && Math.abs(a.slideX - b.slideX) < 0.5 && Math.abs(a.slideY - b.slideY) < 0.5;
    }

    function setDockState(screenName, state) {
        if (!screenName || !state)
            return false;

        const normalized = _normalizeDockState(state);
        const descriptorState = Object.assign({}, state, normalized, {
            "kind": "dock",
            "screenName": screenName,
            "visible": normalized.reveal,
            "presented": normalized.reveal,
            "phase": normalized.reveal ? (state.phase || "open") : "hidden"
        });
        const previous = dockStates[screenName] || emptyDockState;
        const stateChanged = !_sameDockState(dockStates[screenName], normalized);
        if (stateChanged) {
            const next = _cloneDict(dockStates);
            next[screenName] = normalized;
            dockStates = next;
        }
        _setSurfaceDescriptor(screenName, "dock", descriptorState, "dock:" + screenName);
        if (!!previous.reveal !== !!normalized.reveal)
            _bumpSurfaceRevision(screenName);
        return true;
    }

    function clearDockState(screenName) {
        if (!screenName || !dockStates[screenName])
            return false;

        const next = _cloneDict(dockStates);
        delete next[screenName];
        dockStates = next;
        _clearSurfaceDescriptor(screenName, "dock");

        if (dockSlides[screenName]) {
            const nextSlides = _cloneDict(dockSlides);
            delete nextSlides[screenName];
            dockSlides = nextSlides;
        }
        _bumpSurfaceRevision(screenName);
        return true;
    }

    function setDockSlide(screenName, x, y) {
        if (!screenName)
            return false;
        const numX = Number(x);
        const numY = Number(y);
        const cur = dockSlides[screenName];
        if (cur && Math.abs(cur.x - numX) < 0.5 && Math.abs(cur.y - numY) < 0.5)
            return true;
        const next = _cloneDict(dockSlides);
        next[screenName] = {
            "x": numX,
            "y": numY
        };
        dockSlides = next;
        return true;
    }

    readonly property var emptyNotificationState: ({
            "visible": false,
            "barSide": "top",
            "bodyX": 0,
            "bodyY": 0,
            "bodyW": 0,
            "bodyH": 0,
            "omitStartConnector": false,
            "omitEndConnector": false
        })

    property var notificationStates: ({})

    function _normalizeNotificationState(state) {
        return {
            "visible": !!(state && state.visible),
            "barSide": state && state.barSide ? state.barSide : "top",
            "bodyX": Number(state && state.bodyX !== undefined ? state.bodyX : 0),
            "bodyY": Number(state && state.bodyY !== undefined ? state.bodyY : 0),
            "bodyW": Number(state && state.bodyW !== undefined ? state.bodyW : 0),
            "bodyH": Number(state && state.bodyH !== undefined ? state.bodyH : 0),
            "omitStartConnector": !!(state && state.omitStartConnector),
            "omitEndConnector": !!(state && state.omitEndConnector)
        };
    }

    function _sameNotificationGeometry(a, b) {
        if (!a || !b)
            return false;
        return Math.abs(Number(a.bodyX) - Number(b.bodyX)) < 0.5 && Math.abs(Number(a.bodyY) - Number(b.bodyY)) < 0.5 && Math.abs(Number(a.bodyW) - Number(b.bodyW)) < 0.5 && Math.abs(Number(a.bodyH) - Number(b.bodyH)) < 0.5;
    }

    function _sameNotificationState(a, b) {
        if (!a || !b)
            return false;
        return a.visible === b.visible && a.barSide === b.barSide && a.omitStartConnector === b.omitStartConnector && a.omitEndConnector === b.omitEndConnector && _sameNotificationGeometry(a, b);
    }

    function setNotificationState(screenName, state) {
        if (!screenName || !state)
            return false;

        const normalized = _normalizeNotificationState(state);
        const descriptorState = Object.assign({}, state, normalized, {
            "kind": "notification",
            "screenName": screenName,
            "presented": normalized.visible,
            "phase": normalized.visible ? (state.phase || "open") : "hidden"
        });
        const previous = notificationStates[screenName] || emptyNotificationState;
        const stateChanged = !_sameNotificationState(notificationStates[screenName], normalized);
        if (stateChanged) {
            const next = _cloneDict(notificationStates);
            next[screenName] = normalized;
            notificationStates = next;
        }
        _setSurfaceDescriptor(screenName, "notification", descriptorState, "notification:" + screenName);
        if (!!previous.visible !== !!normalized.visible)
            _bumpSurfaceRevision(screenName);
        return true;
    }

    function clearNotificationState(screenName) {
        if (!screenName || !notificationStates[screenName])
            return false;

        const next = _cloneDict(notificationStates);
        delete next[screenName];
        notificationStates = next;
        _clearSurfaceDescriptor(screenName, "notification");
        _bumpSurfaceRevision(screenName);
        return true;
    }

    readonly property var emptyModalState: ({
            "visible": false,
            "barSide": "bottom",
            "bodyX": 0,
            "bodyY": 0,
            "bodyW": 0,
            "bodyH": 0,
            "animX": 0,
            "animY": 0,
            "omitStartConnector": false,
            "omitEndConnector": false
        })

    property var modalStates: ({})
    property var modalOwners: ({})

    function _normalizeModalState(state) {
        return {
            "visible": !!(state && state.visible),
            "barSide": state && state.barSide ? state.barSide : "bottom",
            "bodyX": Number(state && state.bodyX !== undefined ? state.bodyX : 0),
            "bodyY": Number(state && state.bodyY !== undefined ? state.bodyY : 0),
            "bodyW": Number(state && state.bodyW !== undefined ? state.bodyW : 0),
            "bodyH": Number(state && state.bodyH !== undefined ? state.bodyH : 0),
            "animX": Number(state && state.animX !== undefined ? state.animX : 0),
            "animY": Number(state && state.animY !== undefined ? state.animY : 0),
            "omitStartConnector": !!(state && state.omitStartConnector),
            "omitEndConnector": !!(state && state.omitEndConnector)
        };
    }

    function _sameModalGeometry(a, b) {
        if (!a || !b)
            return false;
        return Math.abs(Number(a.bodyX) - Number(b.bodyX)) < 0.5 && Math.abs(Number(a.bodyY) - Number(b.bodyY)) < 0.5 && Math.abs(Number(a.bodyW) - Number(b.bodyW)) < 0.5 && Math.abs(Number(a.bodyH) - Number(b.bodyH)) < 0.5 && Math.abs(Number(a.animX) - Number(b.animX)) < 0.5 && Math.abs(Number(a.animY) - Number(b.animY)) < 0.5;
    }

    function _sameModalState(a, b) {
        if (!a || !b)
            return false;
        return a.visible === b.visible && a.barSide === b.barSide && a.omitStartConnector === b.omitStartConnector && a.omitEndConnector === b.omitEndConnector && _sameModalGeometry(a, b);
    }

    function claimModalState(screenName, state, ownerId) {
        if (!screenName || !state)
            return false;
        if (ownerId) {
            const nextOwners = _cloneDict(modalOwners);
            nextOwners[screenName] = ownerId;
            modalOwners = nextOwners;
        }
        const normalized = _normalizeModalState(state);
        const next = _cloneDict(modalStates);
        next[screenName] = normalized;
        modalStates = next;
        _setSurfaceDescriptor(screenName, "modal", Object.assign({}, state, normalized, {
            "kind": state.kind || "modal",
            "screenName": screenName
        }), ownerId || "");
        _bumpSurfaceRevision(screenName);
        return true;
    }

    function updateModalState(screenName, state, ownerId) {
        if (!screenName || !state)
            return false;
        if (ownerId && modalOwners[screenName] !== ownerId)
            return false;
        const normalized = _normalizeModalState(state);
        const descriptorState = Object.assign({}, state, normalized, {
            "kind": state.kind || (surfaceDescriptor(screenName, "modal").kind || "modal"),
            "screenName": screenName
        });
        if (!_sameModalState(modalStates[screenName], normalized)) {
            const next = _cloneDict(modalStates);
            next[screenName] = normalized;
            modalStates = next;
        }
        _setSurfaceDescriptor(screenName, "modal", descriptorState, ownerId || modalOwners[screenName] || "");
        return true;
    }

    function hasModalOwner(screenName, ownerId) {
        return !!screenName && !!ownerId && modalOwners[screenName] === ownerId;
    }

    function ensureModalState(screenName, state, ownerId) {
        if (!screenName || !state || !ownerId)
            return false;
        const currentOwner = modalOwners[screenName] || "";
        if (currentOwner && currentOwner !== ownerId)
            return false;
        if (!currentOwner)
            return claimModalState(screenName, state, ownerId);
        return updateModalState(screenName, state, ownerId);
    }

    function clearModalState(screenName, ownerId) {
        if (!screenName)
            return false;
        if (ownerId && modalOwners[screenName] !== ownerId)
            return false;
        if (!modalStates[screenName] && !modalOwners[screenName])
            return false;

        if (modalStates[screenName]) {
            const next = _cloneDict(modalStates);
            delete next[screenName];
            modalStates = next;
        }

        if (modalOwners[screenName]) {
            const nextOwners = _cloneDict(modalOwners);
            delete nextOwners[screenName];
            modalOwners = nextOwners;
        }
        _clearSurfaceDescriptor(screenName, "modal", ownerId);
        _bumpSurfaceRevision(screenName);
        return true;
    }

    function setModalAnim(screenName, animX, animY, ownerId) {
        if (ownerId && modalOwners[screenName] !== ownerId)
            return false;
        const cur = screenName ? modalStates[screenName] : null;
        if (!cur)
            return false;
        const nax = animX !== undefined ? Number(animX) : cur.animX;
        const nay = animY !== undefined ? Number(animY) : cur.animY;
        if (Math.abs(nax - cur.animX) < 0.5 && Math.abs(nay - cur.animY) < 0.5)
            return false;
        const next = _cloneDict(modalStates);
        next[screenName] = Object.assign({}, cur, {
            "animX": nax,
            "animY": nay
        });
        modalStates = next;
        return true;
    }

    function setModalBody(screenName, bodyX, bodyY, bodyW, bodyH, ownerId) {
        if (ownerId && modalOwners[screenName] !== ownerId)
            return false;
        const cur = screenName ? modalStates[screenName] : null;
        if (!cur)
            return false;
        const nx = bodyX !== undefined ? Number(bodyX) : cur.bodyX;
        const ny = bodyY !== undefined ? Number(bodyY) : cur.bodyY;
        const nw = bodyW !== undefined ? Number(bodyW) : cur.bodyW;
        const nh = bodyH !== undefined ? Number(bodyH) : cur.bodyH;
        if (Math.abs(nx - cur.bodyX) < 0.5 && Math.abs(ny - cur.bodyY) < 0.5 && Math.abs(nw - cur.bodyW) < 0.5 && Math.abs(nh - cur.bodyH) < 0.5)
            return false;
        const next = _cloneDict(modalStates);
        next[screenName] = Object.assign({}, cur, {
            "bodyX": nx,
            "bodyY": ny,
            "bodyW": nw,
            "bodyH": nh
        });
        modalStates = next;
        return true;
    }

    property var dockRetractRequests: ({})

    function requestDockRetract(requesterId, screenName, side) {
        if (!requesterId || !screenName || !side)
            return false;
        const existing = dockRetractRequests[requesterId];
        if (existing && existing.screenName === screenName && existing.side === side)
            return true;
        const next = _cloneDict(dockRetractRequests);
        next[requesterId] = {
            "screenName": screenName,
            "side": side
        };
        dockRetractRequests = next;
        return true;
    }

    function releaseDockRetract(requesterId) {
        if (!requesterId || !dockRetractRequests[requesterId])
            return false;
        const next = _cloneDict(dockRetractRequests);
        delete next[requesterId];
        dockRetractRequests = next;
        return true;
    }

    function dockRetractActiveForSide(screenName, side) {
        if (!screenName || !side)
            return false;
        for (const k in dockRetractRequests) {
            const r = dockRetractRequests[k];
            if (r && r.screenName === screenName && r.side === side)
                return true;
        }
        return false;
    }

    function _pruneToLiveScreens() {
        const live = {};
        const screens = Quickshell.screens || [];
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i];
            if (s && s.name)
                live[s.name] = true;
        }

        function pruneKeyed(dict) {
            let changed = false;
            const next = {};
            for (const k in dict) {
                if (live[k])
                    next[k] = dict[k];
                else
                    changed = true;
            }
            return changed ? next : null;
        }

        const nextDock = pruneKeyed(dockStates);
        if (nextDock !== null)
            dockStates = nextDock;
        const nextSlides = pruneKeyed(dockSlides);
        if (nextSlides !== null)
            dockSlides = nextSlides;
        const nextNotif = pruneKeyed(notificationStates);
        if (nextNotif !== null)
            notificationStates = nextNotif;
        const nextModal = pruneKeyed(modalStates);
        if (nextModal !== null)
            modalStates = nextModal;
        const nextModalOwners = pruneKeyed(modalOwners);
        if (nextModalOwners !== null)
            modalOwners = nextModalOwners;
        const nextSurfaceRevisions = pruneKeyed(surfaceRevisions);
        if (nextSurfaceRevisions !== null)
            surfaceRevisions = nextSurfaceRevisions;
        const nextDescriptors = pruneKeyed(surfaceDescriptors);
        if (nextDescriptors !== null)
            surfaceDescriptors = nextDescriptors;

        let retractChanged = false;
        const nextRetract = {};
        for (const k in dockRetractRequests) {
            const r = dockRetractRequests[k];
            if (r && live[r.screenName])
                nextRetract[k] = r;
            else
                retractChanged = true;
        }
        if (retractChanged)
            dockRetractRequests = nextRetract;

        if (popoutOwnerId && popoutScreen && !live[popoutScreen])
            releasePopout(popoutOwnerId);
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            screenPruneAction.schedule();
        }
    }

    DeferredAction {
        id: screenPruneAction
        onTriggered: root._pruneToLiveScreens()
    }
}
