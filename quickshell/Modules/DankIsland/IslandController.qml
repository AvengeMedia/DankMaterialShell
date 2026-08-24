pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

QtObject {
    id: root

    property string interactionMode: "click"
    property bool hoverExpanded: false
    property bool inputSuspended: false
    property bool expanded: false
    property bool pointerInside: false
    property int slotHoverCount: 0
    readonly property bool slotHovered: slotHoverCount > 0
    property bool mediaDropdownOpen: false
    property bool keyboardDismissRequested: false
    property string activeActivity: "home"
    property bool mediaAvailable: false
    property bool mediaPreferred: false
    property bool launcherCycleEnabled: false
    property bool launcherSessionActive: false
    property bool launcherInputFocused: false
    onLauncherInputFocusedChanged: {
        if (launcherInputFocused)
            hoverExpanded = false;
    }
    property string launcherPendingQuery: ""
    property string launcherPendingMode: ""
    property bool _launcherPendingExpand: true
    property bool _launcherPendingKeyboardFocus: true
    property string controlCenterPendingSection: ""
    property bool notificationExpandAllowed: false
    property bool keyboardYielded: false
    property real horizontalOffset: 0
    property real outerGap: 8
    readonly property bool bottomEdge: SettingsData.dankIslandEdge === "bottom"
    readonly property real anchoredRadius: bottomEdge ? 34 : 26
    readonly property real freeRadius: bottomEdge ? 26 : 34
    property real compactHeight: 38
    property int transientTimeout: 2200
    property int notificationTimeout: 5000
    property string transientReturnActivity: ""
    property string suspendedActivity: ""
    property bool suspendedExpanded: false
    property bool suspendedKeyboardDismissRequested: false
    property int hoverOpenDelay: 150
    property int hoverCloseDelay: 150
    property int mediaReturnDelay: 1800
    property real controlCenterMaxHeight: 640
    property real notificationCenterMaxHeight: 640
    readonly property real controlCenterHeight: Math.max(320, Math.min(controlCenterMaxHeight, destinationContentHeight("controlcenter")))
    readonly property real notificationCenterHeight: Math.max(320, Math.min(notificationCenterMaxHeight, destinationContentHeight("notificationcenter")))

    readonly property bool compactDense: compactHeight < 40
    readonly property real compactFaceHeight: compactHeight + (compactDense ? 2 : 4)
    readonly property real compactIconSize: Math.max(14, Math.min(32, compactHeight - 8))
    readonly property bool homeCompactTight: SettingsData.dankIslandHomeCompactTight
    readonly property real homeCompactFaceHeight: homeCompactTight ? Math.max(16, Math.min(32, compactHeight - 8)) : compactFaceHeight

    property int unreadNotificationCount: 0
    readonly property bool homeNotificationBadge: SettingsData.dankIslandHomeNotificationBadge && unreadNotificationCount > 0
    readonly property real homeSlotMargin: homeCompactTight ? Theme.spacingS : Theme.spacingM
    property real homeContentWidth: 200
    property real mediaContentWidth: 360
    readonly property real mediaCompactMaxWidth: 360
    property real notificationContentWidth: 0
    readonly property real notificationCompactMinWidth: compactDense ? 200 : 240
    readonly property real notificationCompactMaxWidth: mediaCompactMaxWidth

    signal sessionStarted(string activityId)

    function setHomeContentWidth(width) {
        const next = Math.ceil(width);
        if (!isFinite(next) || next <= 0 || Math.abs(next - homeContentWidth) < 2)
            return;
        homeContentWidth = next;
    }

    function setNotificationContentWidth(width) {
        const next = Math.ceil(width);
        if (!isFinite(next) || next <= 0 || Math.abs(next - notificationContentWidth) < 2)
            return;
        notificationContentWidth = next;
    }

    function setMediaContentWidth(width) {
        const next = Math.ceil(Math.min(root.mediaCompactMaxWidth, width));
        if (!isFinite(next) || next <= 0 || Math.abs(next - mediaContentWidth) < 2)
            return;
        mediaContentWidth = next;
    }

    readonly property var destinations: ["launcher", "controlcenter", "wallpaper", "weather", "notificationcenter"]
    readonly property var destinationDefaults: ({
            "launcher": {
                "contentWidth": 160,
                "contentHeight": 0
            },
            "controlcenter": {
                "contentWidth": 180,
                "contentHeight": 420
            },
            "wallpaper": {
                "contentWidth": 150,
                "contentHeight": 0
            },
            "weather": {
                "contentWidth": 130,
                "contentHeight": 0
            },
            "notificationcenter": {
                "contentWidth": 170,
                "contentHeight": 320
            }
        })
    property var destinationState: root.freshDestinationState()
    property int destinationRevision: 0

    function freshDestinationState() {
        const state = {};
        for (const id of destinations) {
            state[id] = {
                "requested": false,
                "ready": false,
                "pending": false,
                "contentWidth": destinationDefaults[id].contentWidth,
                "contentHeight": destinationDefaults[id].contentHeight
            };
        }
        return state;
    }

    function destinationEntry(activityId) {
        destinationRevision;
        return destinationState[activityId] ?? null;
    }

    function isDestination(activityId) {
        return destinations.indexOf(activityId) !== -1;
    }

    function visualsRequested(activityId) {
        return destinationEntry(activityId)?.requested ?? false;
    }

    function visualsReady(activityId) {
        return destinationEntry(activityId)?.ready ?? false;
    }

    function destinationContentWidth(activityId) {
        return destinationEntry(activityId)?.contentWidth ?? 0;
    }

    function destinationContentHeight(activityId) {
        return destinationEntry(activityId)?.contentHeight ?? 0;
    }

    function setDestinationContentWidth(activityId, width) {
        const entry = destinationState[activityId];
        const next = Math.ceil(width);
        if (!entry || !isFinite(next) || next <= 0 || Math.abs(next - entry.contentWidth) < 2)
            return;
        entry.contentWidth = next;
        destinationRevision++;
    }

    function setDestinationContentHeight(activityId, height) {
        const entry = destinationState[activityId];
        const next = Math.round(height);
        if (!entry || !isFinite(next) || Math.abs(next - entry.contentHeight) < 1)
            return;
        entry.contentHeight = next;
        destinationRevision++;
    }

    function setVisualsReady(activityId, ready) {
        const entry = destinationState[activityId];
        if (!entry || entry.ready === ready)
            return;
        entry.ready = ready;
        destinationRevision++;
    }

    function markVisualsReady(activityId) {
        const entry = destinationState[activityId];
        if (!entry)
            return;
        const pending = entry.pending;
        entry.ready = true;
        entry.pending = false;
        destinationRevision++;
        if (!pending)
            return;
        if (activityId === "launcher") {
            requestActivity("launcher", _launcherPendingExpand, _launcherPendingKeyboardFocus);
            return;
        }
        requestActivity(activityId, true, true);
    }

    function clearPendingRequests(exceptId) {
        let changed = false;
        for (const id of destinations) {
            const entry = destinationState[id];
            if (id === exceptId || !entry.pending)
                continue;
            entry.pending = false;
            changed = true;
        }
        if (changed)
            destinationRevision++;
    }

    function releaseIdleVisuals() {
        for (const id of destinations) {
            if (expanded && activeActivity === id)
                continue;
            const entry = destinationState[id];
            if (!entry.requested && !entry.ready)
                continue;
            visualsReleaseTimer.restart();
            return;
        }
        visualsReleaseTimer.stop();
    }

    function dropIdleVisuals() {
        for (const id of destinations) {
            if (expanded && activeActivity === id)
                continue;
            if (destinationState[id].pending)
                continue;
            dropVisuals(id);
        }
    }

    function dropVisuals(activityId) {
        const entry = destinationState[activityId];
        entry.requested = false;
        entry.ready = false;
        entry.pending = false;
        entry.contentHeight = destinationDefaults[activityId].contentHeight;
        destinationRevision++;
        switch (activityId) {
        case "launcher":
            launcherSessionActive = false;
            launcherInputFocused = false;
            launcherPendingQuery = "";
            launcherPendingMode = "";
            return;
        case "controlcenter":
            controlCenterPendingSection = "";
            return;
        case "wallpaper":
            keyboardYielded = false;
            return;
        }
    }

    readonly property real destinationCompactEndPad: Math.max(root.compactFaceHeight / 2, Theme.spacingM) + Theme.spacingS

    function destinationCompactWidth(activityId) {
        return Math.ceil(Math.max(root.compactFaceHeight, destinationContentWidth(activityId) + root.destinationCompactEndPad * 2));
    }

    function resolvedHomeSlot(value, fallback) {
        if (value === "left" || value === "right" || value === "hidden")
            return value;
        return fallback;
    }

    readonly property string homeMediaSlot: resolvedHomeSlot(SettingsData.dankIslandHomeMediaSlot, "left")
    readonly property string homeStatusSlot: resolvedHomeSlot(SettingsData.dankIslandHomeStatusSlot, "hidden")
    readonly property string homeWeatherSlot: SettingsData.weatherEnabled ? resolvedHomeSlot(SettingsData.dankIslandHomeWeatherSlot, "hidden") : "hidden"

    readonly property real homeCompactWidth: Math.ceil(homeSlotMargin * 2 + Math.max(homeContentWidth, 1))
    readonly property real mediaCompactWidth: Math.ceil(Math.max(1, mediaContentWidth))

    function pillTarget(width, height) {
        const radius = height / 2;
        return {
            "width": width,
            "height": height,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": radius,
            "topRightRadius": radius,
            "bottomLeftRadius": radius,
            "bottomRightRadius": radius
        };
    }

    function sheetTarget(width, height) {
        return {
            "width": width,
            "height": height,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.anchoredRadius,
            "topRightRadius": root.anchoredRadius,
            "bottomLeftRadius": root.freeRadius,
            "bottomRightRadius": root.freeRadius
        };
    }

    readonly property var homeCompactTarget: pillTarget(homeCompactWidth, homeCompactFaceHeight)
    readonly property var homeExpandedTarget: sheetTarget(SettingsData.showWeekNumber ? 736 : 700, 452)
    readonly property var mediaCompactTarget: pillTarget(mediaCompactWidth, compactFaceHeight)
    readonly property var mediaExpandedTarget: sheetTarget(600, 352)
    readonly property var launcherExpandedTarget: sheetTarget(680, 560)
    readonly property var controlCenterExpandedTarget: sheetTarget(580, controlCenterHeight)
    readonly property var wallpaperExpandedTarget: sheetTarget(700, 452)
    readonly property var weatherExpandedTarget: sheetTarget(SettingsData.showWeekNumber ? 736 : 700, 452)
    readonly property var systemCompactTarget: pillTarget(SettingsData.osdAlwaysShowValue ? 330 : 282, compactFaceHeight)
    readonly property var systemExpandedTarget: sheetTarget(460, 176)
    readonly property var notificationCompactTarget: pillTarget(Math.ceil(Math.max(notificationCompactMinWidth, Math.min(notificationCompactMaxWidth, notificationContentWidth))), compactFaceHeight)
    readonly property var notificationExpandedTarget: sheetTarget(520, 220)
    readonly property var notificationCenterExpandedTarget: sheetTarget(480, notificationCenterHeight)

    readonly property bool systemActivityActive: activeActivity === "volume" || activeActivity === "brightness"
    readonly property bool notificationActive: activeActivity === "notification"
    readonly property bool notificationHeldForSystem: root.systemActivityActive && root.transientReturnActivity === "notification"
    readonly property bool transientActive: systemActivityActive || notificationActive
    readonly property bool timeoutSuspended: pointerInside || (expanded && !notificationActive)
    readonly property bool activityOwnsBlankClicks: isDestination(activeActivity)
    readonly property bool hoverExpandEnabled: root.interactionMode === "hybrid" && !root.systemActivityActive
    function compactTargetFor(activityId) {
        switch (activityId) {
        case "notification":
            return notificationCompactTarget;
        case "volume":
        case "brightness":
            return systemCompactTarget;
        case "media":
            return mediaCompactTarget;
        case "home":
            return homeCompactTarget;
        }
        return isDestination(activityId) ? pillTarget(destinationCompactWidth(activityId), compactFaceHeight) : homeCompactTarget;
    }

    readonly property var compactTarget: compactTargetFor(activeActivity)
    function expandedTargetFor(activityId) {
        switch (activityId) {
        case "notification":
            return notificationExpandedTarget;
        case "volume":
        case "brightness":
            return systemExpandedTarget;
        case "launcher":
            return launcherExpandedTarget;
        case "controlcenter":
            return controlCenterExpandedTarget;
        case "wallpaper":
            return wallpaperExpandedTarget;
        case "weather":
            return weatherExpandedTarget;
        case "notificationcenter":
            return notificationCenterExpandedTarget;
        case "media":
            return mediaExpandedTarget;
        }
        return homeExpandedTarget;
    }

    readonly property var expandedTarget: expandedTargetFor(activeActivity)
    readonly property var targetDescriptor: expanded ? expandedTarget : compactTarget

    function syncNotificationTimeout(restart) {
        if (!notificationActive || timeoutSuspended || notificationTimeout <= 0) {
            notificationTimer.stop();
            return;
        }
        if (restart === true || !notificationTimer.running)
            notificationTimer.restart();
    }

    onNotificationTimeoutChanged: syncNotificationTimeout(true)

    function syncTransientTimeout(restart) {
        if (!systemActivityActive || timeoutSuspended) {
            transientTimer.stop();
            return;
        }
        if (restart === true || !transientTimer.running)
            transientTimer.restart();
    }

    function updateMediaAvailability(available) {
        if (available) {
            mediaReturnTimer.stop();
            mediaAvailable = true;
            return;
        }

        mediaAvailable = false;
        mediaPreferred = false;
        if (activeActivity === "media")
            mediaReturnTimer.restart();
    }

    onInputSuspendedChanged: {
        if (!inputSuspended)
            return;
        hoverExpanded = false;
        hoverOpenTimer.stop();
        hoverCloseTimer.stop();
        keyboardDismissRequested = false;
        expanded = false;
        keyboardYielded = false;
        launcherSessionActive = false;
        clearPendingRequests("");
        if (activityOwnsBlankClicks)
            activeActivity = mediaAvailable && mediaPreferred ? "media" : "home";
    }

    function requestHoverExpand() {
        if (inputSuspended || !hoverExpandEnabled)
            return false;
        if (notificationActive) {
            hoverExpanded = true;
            keyboardDismissRequested = false;
            expanded = true;
            hoverCloseTimer.stop();
            notificationTimer.stop();
            return true;
        }
        if (!requestExpand(false))
            return false;
        hoverExpanded = true;
        return true;
    }

    function requestHoverCollapse() {
        if (!hoverExpanded)
            return false;
        if (notificationActive) {
            hoverExpanded = false;
            expanded = false;
            keyboardDismissRequested = false;
            syncNotificationTimeout(true);
            return true;
        }
        return requestCollapse();
    }

    function requestExpand(requestKeyboardFocus) {
        if (inputSuspended)
            return false;
        if (systemActivityActive) {
            syncTransientTimeout(true);
            return false;
        }
        if (activityOwnsBlankClicks)
            return requestActivity(activeActivity, true, requestKeyboardFocus);
        if (notificationActive && !notificationExpandAllowed)
            return requestNotificationCenter(false);
        hoverExpanded = false;
        clearPendingRequests("");
        hoverCloseTimer.stop();
        transientTimer.stop();
        notificationTimer.stop();
        keyboardDismissRequested = requestKeyboardFocus === true;
        expanded = true;
        return true;
    }

    function requestCollapse() {
        hoverExpanded = false;
        hoverOpenTimer.stop();
        transientTimer.stop();
        notificationTimer.stop();
        keyboardDismissRequested = false;
        keyboardYielded = false;
        expanded = false;
        launcherSessionActive = false;
        clearPendingRequests("");
        if (notificationActive) {
            resumeAfterNotification(false);
            return true;
        }
        if (systemActivityActive) {
            finishTransient();
            return true;
        }
        if (activityOwnsBlankClicks)
            activeActivity = mediaAvailable && mediaPreferred ? "media" : "home";
        return true;
    }

    function resolvedReturnActivity(activityId) {
        switch (activityId) {
        case "notification":
        case "home":
            return activityId;
        case "media":
            return mediaAvailable ? "media" : "home";
        }
        if (isDestination(activityId))
            return activityId;
        return mediaAvailable && mediaPreferred ? "media" : "home";
    }

    function requestActivity(activityId, shouldExpand, requestKeyboardFocus) {
        const destination = isDestination(activityId);
        if (activityId !== "home" && activityId !== "media" && !destination)
            return false;
        if (inputSuspended && shouldExpand === true)
            return false;
        if (activityId === "media" && !mediaAvailable)
            return false;
        if (activityId === "weather" && !SettingsData.weatherEnabled)
            return false;

        if (activityId !== "launcher")
            launcherSessionActive = false;
        clearPendingRequests(activityId);

        if (activeActivity === activityId && expanded && shouldExpand === true) {
            if (requestKeyboardFocus === true) {
                keyboardDismissRequested = true;
                hoverExpanded = false;
            }
            return true;
        }

        if (destination && shouldExpand === true && !visualsReady(activityId)) {
            const entry = destinationState[activityId];
            entry.pending = true;
            entry.requested = true;
            destinationRevision++;
            if (activityId === "launcher") {
                _launcherPendingExpand = true;
                _launcherPendingKeyboardFocus = requestKeyboardFocus === true;
            }
            return true;
        }

        if (requestKeyboardFocus === true)
            hoverExpanded = false;
        hoverOpenTimer.stop();
        hoverCloseTimer.stop();
        transientTimer.stop();
        consumeTransientNotification();
        keyboardDismissRequested = shouldExpand === true && requestKeyboardFocus === true;
        expanded = shouldExpand === true;
        activeActivity = activityId;
        if (activityId === "media" || activityId === "home")
            mediaPreferred = activityId === "media";
        launcherSessionActive = activityId === "launcher" && expanded;
        if (destination && expanded)
            sessionStarted(activityId);
        return true;
    }

    function requestLauncher(query, mode, shouldToggle) {
        if (shouldToggle === true && activeActivity === "launcher" && expanded)
            return requestCollapse();
        launcherPendingQuery = query || "";
        launcherPendingMode = mode || "";
        return requestActivity("launcher", true, true);
    }

    function requestControlCenter(section, shouldToggle) {
        if (shouldToggle === true && activeActivity === "controlcenter" && expanded)
            return requestCollapse();
        controlCenterPendingSection = section || "";
        return requestActivity("controlcenter", true, true);
    }

    function requestWallpaper(shouldToggle) {
        if (shouldToggle === true && activeActivity === "wallpaper" && expanded)
            return requestCollapse();
        return requestActivity("wallpaper", true, true);
    }

    function requestWeather(shouldToggle) {
        if (shouldToggle === true && activeActivity === "weather" && expanded)
            return requestCollapse();
        return requestActivity("weather", true, true);
    }

    function requestNotificationCenter(shouldToggle) {
        if (shouldToggle === true && activeActivity === "notificationcenter" && expanded)
            return requestCollapse();
        root.consumeTransientNotification();
        return requestActivity("notificationcenter", true, true);
    }

    function cycleActivity(direction, shouldExpand) {
        const activities = ["home"];
        if (mediaAvailable)
            activities.push("media");
        if (launcherCycleEnabled)
            activities.push("launcher");
        activities.push("controlcenter");
        activities.push("notificationcenter");
        const currentIndex = Math.max(0, activities.indexOf(activeActivity));
        const step = direction < 0 ? -1 : 1;
        const nextIndex = (currentIndex + step + activities.length) % activities.length;
        return requestActivity(activities[nextIndex], shouldExpand, shouldExpand);
    }

    function finishTransient() {
        if (!systemActivityActive)
            return;

        transientTimer.stop();
        const returnActivity = resolvedReturnActivity(transientReturnActivity);
        transientReturnActivity = "";
        if (returnActivity === "notification") {
            hoverExpanded = false;
            keyboardDismissRequested = false;
            expanded = notificationExpandAllowed;
            activeActivity = "notification";
            syncNotificationTimeout(true);
            return;
        }
        activeActivity = returnActivity;
    }

    function requestSystemActivity(activityId) {
        if (activityId !== "volume" && activityId !== "brightness")
            return false;

        launcherSessionActive = false;
        clearPendingRequests("");

        if (expanded && !notificationActive) {
            if (activeActivity !== activityId)
                return false;
            transientTimer.stop();
            return true;
        }

        if (notificationActive) {
            notificationTimer.stop();
            hoverExpanded = false;
            hoverOpenTimer.stop();
            hoverCloseTimer.stop();
            keyboardDismissRequested = false;
            expanded = false;
        }

        if (!systemActivityActive)
            transientReturnActivity = activeActivity;
        activeActivity = activityId;
        syncTransientTimeout(true);
        return true;
    }

    function canRequestNotification(critical) {
        return notificationActive || !expanded || critical === true;
    }

    function consumeTransientNotification() {
        if (transientReturnActivity === "notification")
            transientReturnActivity = "";
        if (!notificationActive)
            return;
        notificationTimer.stop();
        suspendedActivity = "";
        suspendedExpanded = false;
        suspendedKeyboardDismissRequested = false;
    }

    function requestNotification(critical) {
        if (!canRequestNotification(critical))
            return false;

        if (notificationActive)
            return refreshNotification();

        clearPendingRequests("");
        transientTimer.stop();
        suspendedActivity = activeActivity;
        suspendedExpanded = expanded;
        suspendedKeyboardDismissRequested = keyboardDismissRequested;
        launcherSessionActive = false;
        keyboardDismissRequested = false;
        expanded = notificationExpandAllowed;
        activeActivity = "notification";
        syncNotificationTimeout(true);
        return true;
    }

    function refreshNotification() {
        if (!notificationActive)
            return false;
        syncNotificationTimeout(true);
        return true;
    }

    function resumeAfterNotification(restoreExpanded) {
        if (!notificationActive)
            return;

        notificationTimer.stop();
        const nextActivity = suspendedActivity === "media" && !mediaAvailable ? "home" : suspendedActivity || (mediaAvailable && mediaPreferred ? "media" : "home");
        const nextExpanded = restoreExpanded === true && suspendedExpanded;
        const nextKeyboardDismissRequested = nextExpanded && suspendedKeyboardDismissRequested;
        suspendedActivity = "";
        suspendedExpanded = false;
        suspendedKeyboardDismissRequested = false;
        expanded = nextExpanded;
        keyboardDismissRequested = nextKeyboardDismissRequested;
        activeActivity = nextActivity;
        launcherSessionActive = nextActivity === "launcher" && nextExpanded;
        if (nextExpanded && isDestination(nextActivity))
            sessionStarted(nextActivity);
        if (systemActivityActive && !expanded)
            transientTimer.restart();
    }

    function completeNotification() {
        if (transientReturnActivity === "notification")
            transientReturnActivity = "";
        if (!notificationActive)
            return false;
        resumeAfterNotification(true);
        return true;
    }

    function requestToggle(requestKeyboardFocus) {
        if (notificationActive && hoverExpanded && expanded)
            return requestNotificationCenter(false);
        if (expanded)
            return requestCollapse();
        return requestExpand(requestKeyboardFocus);
    }

    function slotHoverEntered() {
        slotHoverCount++;
    }

    function slotHoverExited() {
        slotHoverCount = Math.max(0, slotHoverCount - 1);
    }

    onSlotHoveredChanged: {
        if (slotHovered) {
            hoverOpenTimer.stop();
            return;
        }
        if (pointerInside && hoverExpandEnabled && !expanded)
            hoverOpenTimer.restart();
    }

    onMediaDropdownOpenChanged: {
        if (mediaDropdownOpen) {
            hoverOpenTimer.stop();
            hoverCloseTimer.stop();
            return;
        }
        if (!pointerInside && hoverExpanded && expanded)
            hoverCloseTimer.restart();
    }

    function updatePointerInside(inside) {
        pointerInside = inside === true;
        syncNotificationTimeout(!pointerInside);
        syncTransientTimeout(!pointerInside);
        if (!pointerInside) {
            slotHoverCount = 0;
            hoverOpenTimer.stop();
            if (hoverExpanded && expanded && !mediaDropdownOpen)
                hoverCloseTimer.restart();
            return;
        }
        hoverCloseTimer.stop();
        if (hoverExpandEnabled && !expanded && !slotHovered)
            hoverOpenTimer.restart();
    }

    property Timer hoverOpenTimer: Timer {
        interval: root.hoverOpenDelay
        onTriggered: {
            if (!root.pointerInside || !root.hoverExpandEnabled || root.inputSuspended || root.slotHovered)
                return;
            root.requestHoverExpand();
        }
    }

    property Timer hoverCloseTimer: Timer {
        interval: root.hoverCloseDelay
        onTriggered: {
            if (!root.pointerInside && !root.mediaDropdownOpen && root.hoverExpanded)
                root.requestHoverCollapse();
        }
    }

    property Timer mediaReturnTimer: Timer {
        interval: root.mediaReturnDelay
        onTriggered: {
            if (root.mediaAvailable || root.activeActivity !== "media")
                return;
            root.keyboardDismissRequested = false;
            root.expanded = false;
            root.activeActivity = "home";
        }
    }

    property Timer transientTimer: Timer {
        interval: root.transientTimeout
        onTriggered: {
            if (!root.transientActive || root.expanded)
                return;
            root.finishTransient();
        }
    }

    property Timer notificationTimer: Timer {
        interval: root.notificationTimeout
        onTriggered: root.completeNotification()
    }

    property Timer visualsReleaseTimer: Timer {
        interval: 260
        onTriggered: root.dropIdleVisuals()
    }
}
