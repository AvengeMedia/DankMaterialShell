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

    function _cloneDockStates() {
        const next = {};
        for (const screenName in dockStates)
            next[screenName] = dockStates[screenName];
        return next;
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

    function setDockState(screenName, state) {
        if (!screenName || !state)
            return false;

        const next = _cloneDockStates();
        next[screenName] = _normalizeDockState(state);
        dockStates = next;
        return true;
    }

    function clearDockState(screenName) {
        if (!screenName || !dockStates[screenName])
            return false;

        const next = _cloneDockStates();
        delete next[screenName];
        dockStates = next;

        // Also clear corresponding slide
        if (dockSlides[screenName]) {
            const nextSlides = {};
            for (const k in dockSlides)
                nextSlides[k] = dockSlides[k];
            delete nextSlides[screenName];
            dockSlides = nextSlides;
        }
        return true;
    }

    function setDockSlide(screenName, x, y) {
        if (!screenName)
            return false;
        const next = {};
        for (const k in dockSlides)
            next[k] = dockSlides[k];
        next[screenName] = { "x": Number(x), "y": Number(y) };
        dockSlides = next;
        return true;
    }

    // ─── Notification state (per screen, updated by NotificationSurface) ──────

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

    function _cloneNotificationStates() {
        const next = {};
        for (const screenName in notificationStates)
            next[screenName] = notificationStates[screenName];
        return next;
    }

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

    function setNotificationState(screenName, state) {
        if (!screenName || !state)
            return false;

        const next = _cloneNotificationStates();
        next[screenName] = _normalizeNotificationState(state);
        notificationStates = next;
        return true;
    }

    function clearNotificationState(screenName) {
        if (!screenName || !notificationStates[screenName])
            return false;

        const next = _cloneNotificationStates();
        delete next[screenName];
        notificationStates = next;
        return true;
    }
}
