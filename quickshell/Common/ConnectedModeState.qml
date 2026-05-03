pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

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

    // Popout state (updated by DankPopout when connectedFrameModeActive)
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

    // Dock state (updated by Dock when connectedFrameModeActive), keyed by screen.name
    property var dockStates: ({})

    // Dock slide offsets — hot-path updates separated from full geometry state
    property var dockSlides: ({})

    function _cloneDict(src) {
        const next = {};
        for (const k in src)
            next[k] = src[k];
        return next;
    }

    function hasPopoutOwner(claimId) {
        return !!claimId && popoutOwnerId === claimId;
    }

    function claimPopout(claimId, state) {
        if (!claimId)
            return false;

        popoutOwnerId = claimId;
        return updatePopout(claimId, state);
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

        return true;
    }

    function releasePopout(claimId) {
        if (!hasPopoutOwner(claimId))
            return false;

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
        if (_sameDockState(dockStates[screenName], normalized))
            return true;

        const next = _cloneDict(dockStates);
        next[screenName] = normalized;
        dockStates = next;
        return true;
    }

    function clearDockState(screenName) {
        if (!screenName || !dockStates[screenName])
            return false;

        const next = _cloneDict(dockStates);
        delete next[screenName];
        dockStates = next;

        // Also clear corresponding slide
        if (dockSlides[screenName]) {
            const nextSlides = _cloneDict(dockSlides);
            delete nextSlides[screenName];
            dockSlides = nextSlides;
        }
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
        if (_sameNotificationState(notificationStates[screenName], normalized))
            return true;

        const next = _cloneDict(notificationStates);
        next[screenName] = normalized;
        notificationStates = next;
        return true;
    }

    function clearNotificationState(screenName) {
        if (!screenName || !notificationStates[screenName])
            return false;

        const next = _cloneDict(notificationStates);
        delete next[screenName];
        notificationStates = next;
        return true;
    }

    // DankModal / DankLauncherV2Modal State
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

    function setModalState(screenName, state) {
        if (!screenName || !state)
            return false;

        const normalized = _normalizeModalState(state);
        if (_sameModalState(modalStates[screenName], normalized))
            return true;

        const next = _cloneDict(modalStates);
        next[screenName] = normalized;
        modalStates = next;
        return true;
    }

    function clearModalState(screenName) {
        if (!screenName || !modalStates[screenName])
            return false;

        const next = _cloneDict(modalStates);
        delete next[screenName];
        modalStates = next;
        return true;
    }

    function setModalAnim(screenName, animX, animY) {
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

    function setModalBody(screenName, bodyX, bodyY, bodyW, bodyH) {
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

    // Prune state for screens that are no longer connected. Stale entries
    // accumulate across hotplug cycles otherwise — Frame's per-screen
    // FrameInstance doesn't notice when its peer dicts go orphan.
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
            root._pruneToLiveScreens();
        }
    }
}
