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
    property string controlCenterPendingSection: ""
    property bool notificationExpandAllowed: false
    property bool keyboardYielded: false
    property real alongOffset: 0
    property real outerGap: 8
    property var barConfig: null
    property string edge: "top"
    readonly property bool isVertical: edge === "left" || edge === "right"
    property real cornerRadius: 34
    readonly property real edgeCornerRadius: Math.round(cornerRadius * 0.75)
    property real compactThickness: 38
    property string batteryStyle: "solid"
    property bool mediaClockVisible: true
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

    readonly property bool compactDense: compactThickness < 40
    readonly property real compactFaceThickness: compactThickness + (compactDense ? 2 : 4)
    readonly property real compactIconSize: Math.max(14, Math.min(32, compactThickness - 8))
    property bool homeCompactTight: false
    readonly property real homeCompactFaceThickness: homeCompactTight ? Math.max(16, Math.min(32, compactThickness - 8)) : compactFaceThickness

    property int unreadNotificationCount: 0
    readonly property bool homeNotificationBadge: SettingsData.islandHomeGroupEnabled(root.barConfig, "notifications") && unreadNotificationCount > 0
    readonly property bool homeWeatherEnabled: SettingsData.weatherEnabled && SettingsData.islandHomeGroupEnabled(root.barConfig, "weather")
    readonly property real homeSlotMargin: homeCompactTight ? Theme.spacingS : Theme.spacingM
    property real homeContentLength: 200
    property real mediaContentLength: 360
    property real mediaExpandedHeight: 324
    readonly property real mediaCompactMaxLength: 360
    property real notificationContentLength: 0
    readonly property real notificationCompactMinLength: isVertical ? compactFaceThickness : (compactDense ? 200 : 240)
    readonly property real notificationCompactMaxLength: mediaCompactMaxLength

    signal sessionStarted(string activityId)

    function setHomeContentLength(length) {
        const next = Math.ceil(length);
        if (!isFinite(next) || next <= 0 || Math.abs(next - homeContentLength) < 2)
            return;
        homeContentLength = next;
    }

    function setNotificationContentLength(length) {
        const next = Math.ceil(length);
        if (!isFinite(next) || next <= 0 || Math.abs(next - notificationContentLength) < 2)
            return;
        notificationContentLength = next;
    }

    function setMediaExpandedHeight(height) {
        const next = Math.ceil(height);
        if (!isFinite(next) || next <= 0 || Math.abs(next - mediaExpandedHeight) < 1)
            return;
        mediaExpandedHeight = next;
    }

    function setMediaContentLength(length) {
        const next = Math.ceil(Math.min(root.mediaCompactMaxLength, length));
        if (!isFinite(next) || next <= 0 || Math.abs(next - mediaContentLength) < 2)
            return;
        mediaContentLength = next;
    }

    readonly property var destinations: ["launcher", "controlcenter", "wallpaper", "weather", "notificationcenter"]
    readonly property var blankClickOwners: ["launcher", "controlcenter", "wallpaper", "notificationcenter"]
    readonly property var destinationDefaults: ({
            "launcher": {
                "contentLength": 160,
                "contentHeight": 0
            },
            "controlcenter": {
                "contentLength": 180,
                "contentHeight": 420
            },
            "wallpaper": {
                "contentLength": 150,
                "contentHeight": 0
            },
            "weather": {
                "contentLength": 130,
                "contentHeight": 0
            },
            "notificationcenter": {
                "contentLength": 170,
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
                "pendingKeyboardFocus": false,
                "contentLength": destinationDefaults[id].contentLength,
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

    function destinationContentLength(activityId) {
        return destinationEntry(activityId)?.contentLength ?? 0;
    }

    function destinationContentHeight(activityId) {
        return destinationEntry(activityId)?.contentHeight ?? 0;
    }

    function setDestinationContentLength(activityId, length) {
        const entry = destinationState[activityId];
        const next = Math.ceil(length);
        if (!entry || !isFinite(next) || next <= 0 || Math.abs(next - entry.contentLength) < 2)
            return;
        entry.contentLength = next;
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
        requestActivity(activityId, true, entry.pendingKeyboardFocus);
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

    readonly property real destinationCompactEndPad: root.isVertical ? Theme.spacingS : Math.max(root.compactFaceThickness / 2, Theme.spacingM) + Theme.spacingS

    function destinationCompactLength(activityId) {
        return Math.ceil(Math.max(root.compactFaceThickness, destinationContentLength(activityId) + root.destinationCompactEndPad * 2));
    }

    function homeGroups(side) {
        const layout = SettingsData.getIslandHomeLayout(root.barConfig);
        const clock = layout.findIndex(g => g.id === "clock");
        const groups = side === "left" ? layout.slice(0, clock) : layout.slice(clock + 1);
        return groups.filter(g => g.enabled).map(g => g.id);
    }

    readonly property var homeLeftGroups: homeGroups("left")
    readonly property var homeRightGroups: homeGroups("right")
    property string homeClockDisplay: "both"
    property string homeVolumeDisplay: "both"
    property string homeBrightnessDisplay: "both"

    readonly property real homeCompactLength: Math.ceil(homeSlotMargin * 2 + Math.max(homeContentLength, 1))
    readonly property real mediaCompactLength: Math.ceil(Math.max(1, mediaContentLength))

    // Corners touching the attached screen edge stay tighter than the ones facing the desktop.
    function sheetRadii() {
        const near = root.edgeCornerRadius;
        const far = root.cornerRadius;
        switch (root.edge) {
        case "bottom":
            return [far, far, near, near];
        case "left":
            return [near, far, near, far];
        case "right":
            return [far, near, far, near];
        }
        return [near, near, far, far];
    }

    function pillTarget(alongSize, crossSize) {
        const radius = Math.min(crossSize / 2, root.cornerRadius);
        return {
            "width": root.isVertical ? crossSize : alongSize,
            "height": root.isVertical ? alongSize : crossSize,
            "offsetAlong": root.alongOffset,
            "offsetCross": root.outerGap,
            "topLeftRadius": radius,
            "topRightRadius": radius,
            "bottomLeftRadius": radius,
            "bottomRightRadius": radius
        };
    }

    function sheetTarget(width, height) {
        const radii = root.sheetRadii();
        return {
            "width": width,
            "height": height,
            "offsetAlong": root.alongOffset,
            "offsetCross": root.outerGap,
            "topLeftRadius": radii[0],
            "topRightRadius": radii[1],
            "bottomLeftRadius": radii[2],
            "bottomRightRadius": radii[3]
        };
    }

    readonly property var homeCompactTarget: pillTarget(homeCompactLength, homeCompactFaceThickness)
    readonly property var mediaCompactTarget: pillTarget(mediaCompactLength, compactFaceThickness)
    readonly property var dashSheetTarget: sheetTarget(SettingsData.showWeekNumber ? 736 : 700, 452)
    readonly property var mediaExpandedTarget: sheetTarget(600, mediaExpandedHeight)
    readonly property var launcherExpandedTarget: sheetTarget(680, 560)
    readonly property var controlCenterExpandedTarget: sheetTarget(580, controlCenterHeight)
    readonly property var systemCompactTarget: pillTarget(root.isVertical ? 240 : (SettingsData.osdAlwaysShowValue ? 330 : 282), compactFaceThickness)
    readonly property var systemExpandedTarget: sheetTarget(460, 176)
    readonly property var notificationCompactTarget: pillTarget(Math.ceil(Math.max(notificationCompactMinLength, Math.min(notificationCompactMaxLength, notificationContentLength))), compactFaceThickness)
    readonly property var notificationExpandedTarget: sheetTarget(520, 220)
    readonly property var notificationCenterExpandedTarget: sheetTarget(480, notificationCenterHeight)

    readonly property bool systemActivityActive: activeActivity === "volume" || activeActivity === "brightness"
    readonly property bool notificationActive: activeActivity === "notification"
    readonly property bool notificationHeldForSystem: root.systemActivityActive && root.transientReturnActivity === "notification"
    readonly property bool transientActive: systemActivityActive || notificationActive
    readonly property bool timeoutSuspended: pointerInside || (expanded && !notificationActive)
    readonly property bool activityOwnsBlankClicks: blankClickOwners.indexOf(activeActivity) !== -1
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
        return isDestination(activityId) ? pillTarget(destinationCompactLength(activityId), compactFaceThickness) : homeCompactTarget;
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
        case "notificationcenter":
            return notificationCenterExpandedTarget;
        case "media":
            return mediaExpandedTarget;
        }
        return dashSheetTarget;
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
        if (isDestination(activeActivity))
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
        if (isDestination(activeActivity))
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
        if (isDestination(activeActivity))
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
            entry.pendingKeyboardFocus = requestKeyboardFocus === true;
            entry.requested = true;
            destinationRevision++;
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

    function updatePointerInside(inside) {
        pointerInside = inside === true;
        syncNotificationTimeout(!pointerInside);
        syncTransientTimeout(!pointerInside);
        if (!pointerInside) {
            slotHoverCount = 0;
            hoverOpenTimer.stop();
            if (hoverExpanded && expanded)
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
            if (!root.pointerInside && root.hoverExpanded)
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
