pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

QtObject {
    id: root

    // Hybrid peeks the current compact face on hover. Click pins destinations.
    property string interactionMode: "click"
    property bool hoverExpanded: false
    property bool inputSuspended: false
    property bool expanded: false
    property bool pointerInside: false
    // Slots with their own click target suppress hover expansion so the click wins.
    property int slotHoverCount: 0
    readonly property bool slotHovered: slotHoverCount > 0
    property bool mediaDropdownOpen: false
    property bool autoDemo: false
    property bool keyboardDismissRequested: false
    property string activeActivity: "home"
    property bool mediaAvailable: false
    property bool mediaPreferred: false
    property bool launcherCycleEnabled: false
    property bool launcherVisualsRequested: false
    property bool launcherVisualsReady: false
    property bool launcherRequestPending: false
    property bool launcherSessionActive: false
    property bool launcherInputFocused: false
    onLauncherInputFocusedChanged: {
        if (launcherInputFocused)
            hoverExpanded = false;
    }
    property string launcherPendingQuery: ""
    property string launcherPendingMode: ""
    property int launcherSessionSerial: 0
    property bool _launcherPendingExpand: true
    property bool _launcherPendingKeyboardFocus: true
    property bool controlCenterVisualsRequested: false
    property bool controlCenterVisualsReady: false
    property bool controlCenterRequestPending: false
    property string controlCenterPendingSection: ""
    property int controlCenterSessionSerial: 0
    property bool wallpaperVisualsRequested: false
    property bool wallpaperVisualsReady: false
    property bool wallpaperRequestPending: false
    property int wallpaperSessionSerial: 0
    property bool weatherVisualsRequested: false
    property bool weatherVisualsReady: false
    property bool weatherRequestPending: false
    property bool notificationCenterVisualsRequested: false
    property bool notificationCenterVisualsReady: false
    property bool notificationCenterRequestPending: false
    property int notificationCenterSessionSerial: 0
    // Arriving notifications stay pill-sized unless the user opts into full expansion.
    property bool notificationExpandAllowed: false
    property bool keyboardYielded: false
    property real horizontalOffset: 0
    property real outerGap: 8
    // Expanded silhouette signature: tight corners on the screen edge, open corners facing the desktop.
    readonly property bool bottomEdge: SettingsData.dankIslandEdge === "bottom"
    readonly property real anchoredRadius: bottomEdge ? 34 : 26
    readonly property real freeRadius: bottomEdge ? 26 : 34
    property real compactHeight: 38
    property int transientTimeout: 2200
    // Adopted popup timeout; 0 is sticky until dismiss.
    property int notificationTimeout: 5000
    property string transientReturnActivity: ""
    property string suspendedActivity: ""
    property bool suspendedExpanded: false
    property bool suspendedKeyboardDismissRequested: false
    property int hoverOpenDelay: 150
    property int hoverCloseDelay: 150
    property int mediaReturnDelay: 1800
    property real controlCenterContentHeight: 420
    property real controlCenterMaxHeight: 640
    readonly property real controlCenterHeight: Math.max(320, Math.min(controlCenterMaxHeight, controlCenterContentHeight))
    property real notificationCenterContentHeight: 320
    property real notificationCenterMaxHeight: 640
    readonly property real notificationCenterHeight: Math.max(320, Math.min(notificationCenterMaxHeight, notificationCenterContentHeight))

    // Below the pill threshold every compact face drops to a single text line.
    readonly property bool compactDense: compactHeight < 40
    readonly property real compactFaceHeight: compactHeight + (compactDense ? 2 : 4)
    readonly property real compactIconSize: Math.max(14, Math.min(32, compactHeight - 8))
    readonly property bool homeCompactTight: SettingsData.dankIslandHomeCompactTight
    readonly property real homeCompactFaceHeight: homeCompactTight ? Math.max(16, Math.min(32, compactHeight - 8)) : compactFaceHeight

    property int unreadNotificationCount: 0
    readonly property bool homeNotificationBadge: unreadNotificationCount > 0
    readonly property real homeSlotMargin: homeCompactTight ? 4 : 8
    readonly property real homeSlotSpacing: homeCompactTight ? 2 : 4
    readonly property real homeClusterGap: homeCompactTight ? 6 : 10
    property real homeContentWidth: 200

    // Ignore sub-2px clock jitter so the spring does not restart every tick.
    function setHomeContentWidth(width) {
        const next = Math.ceil(width);
        if (!isFinite(next) || next <= 0 || Math.abs(next - homeContentWidth) < 2)
            return;
        homeContentWidth = next;
    }

    property real mediaContentWidth: 360
    readonly property real mediaCompactMaxWidth: 360

    function setMediaContentWidth(width) {
        const next = Math.ceil(Math.min(root.mediaCompactMaxWidth, width));
        if (!isFinite(next) || next <= 0 || Math.abs(next - mediaContentWidth) < 2)
            return;
        mediaContentWidth = next;
    }

    property real launcherContentWidth: 160
    property real controlCenterContentWidth: 180
    property real wallpaperContentWidth: 150
    property real weatherContentWidth: 130
    property real notificationCenterContentWidth: 170
    readonly property real destinationCompactEndPad: Math.max(root.compactFaceHeight / 2, Theme.spacingM) + Theme.spacingS

    function destinationCompactWidthFromContent(contentWidth) {
        return Math.ceil(Math.max(root.compactFaceHeight, contentWidth + root.destinationCompactEndPad * 2));
    }

    function setDestinationContentWidth(activityId, width) {
        const next = Math.ceil(width);
        if (!isFinite(next) || next <= 0)
            return;
        switch (activityId) {
        case "launcher":
            if (Math.abs(next - launcherContentWidth) < 2)
                return;
            launcherContentWidth = next;
            return;
        case "controlcenter":
            if (Math.abs(next - controlCenterContentWidth) < 2)
                return;
            controlCenterContentWidth = next;
            return;
        case "wallpaper":
            if (Math.abs(next - wallpaperContentWidth) < 2)
                return;
            wallpaperContentWidth = next;
            return;
        case "weather":
            if (Math.abs(next - weatherContentWidth) < 2)
                return;
            weatherContentWidth = next;
            return;
        case "notificationcenter":
            if (Math.abs(next - notificationCenterContentWidth) < 2)
                return;
            notificationCenterContentWidth = next;
            return;
        }
    }

    function setLauncherContentWidth(width) {
        root.setDestinationContentWidth("launcher", width);
    }

    function resolvedHomeSlot(value, fallback) {
        if (value === "left" || value === "right" || value === "hidden")
            return value;
        return fallback;
    }

    readonly property string homeMediaSlot: resolvedHomeSlot(SettingsData.dankIslandHomeMediaSlot, "left")
    readonly property string homeStatusSlot: resolvedHomeSlot(SettingsData.dankIslandHomeStatusSlot, "right")
    readonly property string homeWeatherSlot: SettingsData.weatherEnabled ? resolvedHomeSlot(SettingsData.dankIslandHomeWeatherSlot, "hidden") : "hidden"

    readonly property real homeCompactWidth: Math.ceil(homeSlotMargin * 2 + Math.max(homeContentWidth, 1))

    readonly property var homeCompactTarget: ({
            "width": root.homeCompactWidth,
            "height": root.homeCompactFaceHeight,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.homeCompactFaceHeight / 2,
            "topRightRadius": root.homeCompactFaceHeight / 2,
            "bottomLeftRadius": root.homeCompactFaceHeight / 2,
            "bottomRightRadius": root.homeCompactFaceHeight / 2
        })
    readonly property var homeExpandedTarget: ({
            "width": SettingsData.showWeekNumber ? 736 : 700,
            "height": 452,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.anchoredRadius,
            "topRightRadius": root.anchoredRadius,
            "bottomLeftRadius": root.freeRadius,
            "bottomRightRadius": root.freeRadius
        })
    readonly property real mediaCompactWidth: Math.ceil(Math.max(1, mediaContentWidth))

    readonly property var mediaCompactTarget: ({
            "width": root.mediaCompactWidth,
            "height": root.compactFaceHeight,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.compactFaceHeight / 2,
            "topRightRadius": root.compactFaceHeight / 2,
            "bottomLeftRadius": root.compactFaceHeight / 2,
            "bottomRightRadius": root.compactFaceHeight / 2
        })
    readonly property var mediaExpandedTarget: ({
            "width": 600,
            "height": 352,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.anchoredRadius,
            "topRightRadius": root.anchoredRadius,
            "bottomLeftRadius": root.freeRadius,
            "bottomRightRadius": root.freeRadius
        })
    readonly property real launcherCompactWidth: root.destinationCompactWidthFromContent(launcherContentWidth)
    readonly property real controlCenterCompactWidth: root.destinationCompactWidthFromContent(controlCenterContentWidth)
    readonly property real wallpaperCompactWidth: root.destinationCompactWidthFromContent(wallpaperContentWidth)
    readonly property real weatherCompactWidth: root.destinationCompactWidthFromContent(weatherContentWidth)
    readonly property real notificationCenterCompactWidth: root.destinationCompactWidthFromContent(notificationCenterContentWidth)

    readonly property var launcherCompactTarget: ({
            "width": root.launcherCompactWidth,
            "height": root.compactFaceHeight,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.compactFaceHeight / 2,
            "topRightRadius": root.compactFaceHeight / 2,
            "bottomLeftRadius": root.compactFaceHeight / 2,
            "bottomRightRadius": root.compactFaceHeight / 2
        })
    readonly property var launcherExpandedTarget: ({
            "width": 680,
            "height": 560,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.anchoredRadius,
            "topRightRadius": root.anchoredRadius,
            "bottomLeftRadius": root.freeRadius,
            "bottomRightRadius": root.freeRadius
        })
    readonly property var controlCenterCompactTarget: ({
            "width": root.controlCenterCompactWidth,
            "height": root.compactFaceHeight,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.compactFaceHeight / 2,
            "topRightRadius": root.compactFaceHeight / 2,
            "bottomLeftRadius": root.compactFaceHeight / 2,
            "bottomRightRadius": root.compactFaceHeight / 2
        })
    readonly property var controlCenterExpandedTarget: ({
            "width": 580,
            "height": root.controlCenterHeight,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.anchoredRadius,
            "topRightRadius": root.anchoredRadius,
            "bottomLeftRadius": root.freeRadius,
            "bottomRightRadius": root.freeRadius
        })
    readonly property var wallpaperCompactTarget: ({
            "width": root.wallpaperCompactWidth,
            "height": root.compactFaceHeight,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.compactFaceHeight / 2,
            "topRightRadius": root.compactFaceHeight / 2,
            "bottomLeftRadius": root.compactFaceHeight / 2,
            "bottomRightRadius": root.compactFaceHeight / 2
        })
    readonly property var wallpaperExpandedTarget: ({
            "width": 700,
            "height": 452,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.anchoredRadius,
            "topRightRadius": root.anchoredRadius,
            "bottomLeftRadius": root.freeRadius,
            "bottomRightRadius": root.freeRadius
        })
    readonly property var weatherCompactTarget: ({
            "width": root.weatherCompactWidth,
            "height": root.compactFaceHeight,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.compactFaceHeight / 2,
            "topRightRadius": root.compactFaceHeight / 2,
            "bottomLeftRadius": root.compactFaceHeight / 2,
            "bottomRightRadius": root.compactFaceHeight / 2
        })
    readonly property var weatherExpandedTarget: ({
            "width": SettingsData.showWeekNumber ? 736 : 700,
            "height": 452,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.anchoredRadius,
            "topRightRadius": root.anchoredRadius,
            "bottomLeftRadius": root.freeRadius,
            "bottomRightRadius": root.freeRadius
        })
    readonly property var systemCompactTarget: ({
            "width": SettingsData.osdAlwaysShowValue ? 330 : 282,
            "height": root.compactFaceHeight,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.compactFaceHeight / 2,
            "topRightRadius": root.compactFaceHeight / 2,
            "bottomLeftRadius": root.compactFaceHeight / 2,
            "bottomRightRadius": root.compactFaceHeight / 2
        })
    readonly property var systemExpandedTarget: ({
            "width": 460,
            "height": 176,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.anchoredRadius,
            "topRightRadius": root.anchoredRadius,
            "bottomLeftRadius": root.freeRadius,
            "bottomRightRadius": root.freeRadius
        })
    readonly property var notificationCompactTarget: ({
            "width": root.compactDense ? 320 : 360,
            "height": root.compactFaceHeight,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.compactFaceHeight / 2,
            "topRightRadius": root.compactFaceHeight / 2,
            "bottomLeftRadius": root.compactFaceHeight / 2,
            "bottomRightRadius": root.compactFaceHeight / 2
        })
    readonly property var notificationExpandedTarget: ({
            "width": 520,
            "height": 220,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.anchoredRadius,
            "topRightRadius": root.anchoredRadius,
            "bottomLeftRadius": root.freeRadius,
            "bottomRightRadius": root.freeRadius
        })
    readonly property var notificationCenterCompactTarget: ({
            "width": root.notificationCenterCompactWidth,
            "height": root.compactFaceHeight,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.compactFaceHeight / 2,
            "topRightRadius": root.compactFaceHeight / 2,
            "bottomLeftRadius": root.compactFaceHeight / 2,
            "bottomRightRadius": root.compactFaceHeight / 2
        })
    readonly property var notificationCenterExpandedTarget: ({
            "width": 480,
            "height": root.notificationCenterHeight,
            "offsetX": root.horizontalOffset,
            "offsetY": root.outerGap,
            "topLeftRadius": root.anchoredRadius,
            "topRightRadius": root.anchoredRadius,
            "bottomLeftRadius": root.freeRadius,
            "bottomRightRadius": root.freeRadius
        })
    readonly property bool systemActivityActive: activeActivity === "volume" || activeActivity === "brightness"
    readonly property bool notificationActive: activeActivity === "notification"
    readonly property bool notificationHeldForSystem: root.systemActivityActive && root.transientReturnActivity === "notification"
    readonly property bool transientActive: systemActivityActive || notificationActive
    readonly property bool timeoutSuspended: pointerInside || (expanded && !notificationActive)
    readonly property var fullDestinations: ["launcher", "controlcenter", "wallpaper", "weather", "notificationcenter"]
    readonly property bool activityOwnsBlankClicks: root.fullDestinations.indexOf(root.activeActivity) !== -1
    readonly property bool hoverExpandEnabled: root.interactionMode === "hybrid" && !root.systemActivityActive
    readonly property var compactTarget: {
        if (root.notificationActive)
            return root.notificationCompactTarget;
        switch (root.activeActivity) {
        case "launcher":
            return root.launcherCompactTarget;
        case "controlcenter":
            return root.controlCenterCompactTarget;
        case "wallpaper":
            return root.wallpaperCompactTarget;
        case "weather":
            return root.weatherCompactTarget;
        case "notificationcenter":
            return root.notificationCenterCompactTarget;
        case "media":
            return root.mediaCompactTarget;
        }
        return root.systemActivityActive ? root.systemCompactTarget : root.homeCompactTarget;
    }
    readonly property var expandedTarget: {
        if (root.notificationActive)
            return root.notificationExpandedTarget;
        switch (root.activeActivity) {
        case "launcher":
            return root.launcherExpandedTarget;
        case "controlcenter":
            return root.controlCenterExpandedTarget;
        case "wallpaper":
            return root.wallpaperExpandedTarget;
        case "weather":
            return root.weatherExpandedTarget;
        case "notificationcenter":
            return root.notificationCenterExpandedTarget;
        case "media":
            return root.mediaExpandedTarget;
        }
        return root.systemActivityActive ? root.systemExpandedTarget : root.homeExpandedTarget;
    }
    readonly property var targetDescriptor: expanded ? expandedTarget : compactTarget

    function syncNotificationTimeout(restart) {
        // Hover pauses arrival expiry; opt-in expansion remains a timed glance.
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
            return true;
        }

        mediaAvailable = false;
        mediaPreferred = false;
        if (activeActivity === "media")
            mediaReturnTimer.restart();
        return true;
    }

    onInputSuspendedChanged: {
        // Screenshot selection owns input while the island remains mapped for the session.
        if (!inputSuspended)
            return;
        hoverExpanded = false;
        hoverOpenTimer.stop();
        hoverCloseTimer.stop();
        keyboardDismissRequested = false;
        expanded = false;
        keyboardYielded = false;
        launcherRequestPending = false;
        launcherSessionActive = false;
        controlCenterRequestPending = false;
        wallpaperRequestPending = false;
        weatherRequestPending = false;
        notificationCenterRequestPending = false;
        if (fullDestinations.indexOf(activeActivity) !== -1)
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
        launcherRequestPending = false;
        controlCenterRequestPending = false;
        wallpaperRequestPending = false;
        weatherRequestPending = false;
        notificationCenterRequestPending = false;
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
        launcherRequestPending = false;
        launcherSessionActive = false;
        controlCenterRequestPending = false;
        wallpaperRequestPending = false;
        weatherRequestPending = false;
        notificationCenterRequestPending = false;
        if (notificationActive) {
            resumeAfterNotification(false);
            return true;
        }
        if (systemActivityActive) {
            finishTransient();
            return true;
        }

        if (activityOwnsBlankClicks) {
            activeActivity = mediaAvailable && mediaPreferred ? "media" : "home";
            return true;
        }

        return true;
    }

    function resolvedReturnActivity(activityId) {
        if (activityId === "notification")
            return "notification";
        if (activityId === "media" && !mediaAvailable)
            return "home";
        if (activityId === "home" || activityId === "media" || fullDestinations.indexOf(activityId) !== -1)
            return activityId;
        return mediaAvailable && mediaPreferred ? "media" : "home";
    }

    function requestActivity(activityId, shouldExpand, requestKeyboardFocus) {
        if (activityId !== "home" && activityId !== "media" && fullDestinations.indexOf(activityId) === -1)
            return false;
        if (inputSuspended && shouldExpand === true)
            return false;
        if (activityId === "media" && !mediaAvailable)
            return false;
        if (activityId === "weather" && !SettingsData.weatherEnabled)
            return false;

        if (activityId !== "launcher") {
            launcherRequestPending = false;
            launcherSessionActive = false;
        }
        if (activityId !== "controlcenter")
            controlCenterRequestPending = false;
        if (activityId === "wallpaper")
            wallpaperReleaseTimer.stop();
        else
            wallpaperRequestPending = false;
        if (activityId === "weather")
            weatherReleaseTimer.stop();
        else
            weatherRequestPending = false;
        if (activityId === "notificationcenter")
            notificationCenterReleaseTimer.stop();
        else
            notificationCenterRequestPending = false;

        if (activeActivity === activityId && expanded && shouldExpand === true) {
            if (requestKeyboardFocus === true) {
                keyboardDismissRequested = true;
                hoverExpanded = false;
            }
            return true;
        }

        if (activityId === "launcher" && shouldExpand === true && !launcherVisualsReady) {
            launcherRequestPending = true;
            _launcherPendingExpand = true;
            _launcherPendingKeyboardFocus = requestKeyboardFocus === true;
            launcherVisualsRequested = true;
            return true;
        }

        if (activityId === "controlcenter" && shouldExpand === true && !controlCenterVisualsReady) {
            controlCenterRequestPending = true;
            controlCenterVisualsRequested = true;
            return true;
        }

        if (activityId === "wallpaper" && shouldExpand === true && !wallpaperVisualsReady) {
            wallpaperRequestPending = true;
            wallpaperVisualsRequested = true;
            return true;
        }

        if (activityId === "weather" && shouldExpand === true && !weatherVisualsReady) {
            weatherRequestPending = true;
            weatherVisualsRequested = true;
            return true;
        }

        if (activityId === "notificationcenter" && shouldExpand === true && !notificationCenterVisualsReady) {
            notificationCenterRequestPending = true;
            notificationCenterVisualsRequested = true;
            return true;
        }

        if (requestKeyboardFocus === true)
            hoverExpanded = false;
        hoverOpenTimer.stop();
        hoverCloseTimer.stop();
        transientTimer.stop();
        // IPC and other destinations consume the card so its timeout cannot snap back.
        root.consumeTransientNotification();
        keyboardDismissRequested = shouldExpand === true && requestKeyboardFocus === true;
        expanded = shouldExpand === true;
        activeActivity = activityId;
        if (activityId === "media")
            mediaPreferred = true;
        else if (activityId === "home")
            mediaPreferred = false;
        launcherSessionActive = activityId === "launcher" && expanded;
        if (launcherSessionActive)
            launcherSessionSerial++;
        if (activityId === "controlcenter" && expanded)
            controlCenterSessionSerial++;
        if (activityId === "wallpaper" && expanded)
            wallpaperSessionSerial++;
        if (activityId === "notificationcenter" && expanded)
            notificationCenterSessionSerial++;
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

    function markLauncherVisualsReady() {
        launcherVisualsReady = true;
        if (!launcherRequestPending)
            return;
        launcherRequestPending = false;
        requestActivity("launcher", _launcherPendingExpand, _launcherPendingKeyboardFocus);
    }

    function releaseLauncherVisuals() {
        if (expanded && activeActivity === "launcher") {
            launcherReleaseTimer.stop();
            return;
        }
        if (!launcherVisualsRequested && !launcherVisualsReady)
            return;
        launcherReleaseTimer.restart();
    }

    function _dropLauncherVisuals() {
        launcherReleaseTimer.stop();
        if (expanded && activeActivity === "launcher")
            return;
        launcherRequestPending = false;
        launcherVisualsRequested = false;
        launcherVisualsReady = false;
        launcherSessionActive = false;
        launcherInputFocused = false;
        launcherPendingQuery = "";
        launcherPendingMode = "";
    }

    function markControlCenterVisualsReady() {
        controlCenterVisualsReady = true;
        if (!controlCenterRequestPending)
            return;
        controlCenterRequestPending = false;
        requestActivity("controlcenter", true, true);
    }

    function releaseControlCenterVisuals() {
        if (expanded && activeActivity === "controlcenter") {
            controlCenterReleaseTimer.stop();
            return;
        }
        if (!controlCenterVisualsRequested && !controlCenterVisualsReady)
            return;
        controlCenterReleaseTimer.restart();
    }

    function _dropControlCenterVisuals() {
        controlCenterReleaseTimer.stop();
        if (expanded && activeActivity === "controlcenter")
            return;
        controlCenterRequestPending = false;
        controlCenterVisualsRequested = false;
        controlCenterVisualsReady = false;
        controlCenterPendingSection = "";
        controlCenterContentHeight = 420;
    }

    function requestNotificationCenter(shouldToggle) {
        if (shouldToggle === true && activeActivity === "notificationcenter" && expanded)
            return requestCollapse();
        root.consumeTransientNotification();
        return requestActivity("notificationcenter", true, true);
    }

    function markNotificationCenterVisualsReady() {
        notificationCenterVisualsReady = true;
        if (!notificationCenterRequestPending)
            return;
        notificationCenterRequestPending = false;
        requestActivity("notificationcenter", true, true);
    }

    function setNotificationCenterContentHeight(height) {
        const next = Math.round(height);
        if (!isFinite(next) || Math.abs(next - notificationCenterContentHeight) < 1)
            return;
        notificationCenterContentHeight = next;
    }

    function releaseNotificationCenterVisuals() {
        if (expanded && activeActivity === "notificationcenter") {
            notificationCenterReleaseTimer.stop();
            return;
        }
        if (!notificationCenterVisualsRequested && !notificationCenterVisualsReady)
            return;
        notificationCenterReleaseTimer.restart();
    }

    function _dropNotificationCenterVisuals() {
        notificationCenterReleaseTimer.stop();
        notificationCenterRequestPending = false;
        notificationCenterVisualsRequested = false;
        notificationCenterVisualsReady = false;
        notificationCenterContentHeight = 320;
    }

    function markWallpaperVisualsReady() {
        wallpaperVisualsReady = true;
        if (!wallpaperRequestPending)
            return;
        wallpaperRequestPending = false;
        requestActivity("wallpaper", true, true);
    }

    function releaseWallpaperVisuals() {
        if (expanded && activeActivity === "wallpaper") {
            wallpaperReleaseTimer.stop();
            return;
        }
        if (!wallpaperVisualsRequested && !wallpaperVisualsReady)
            return;
        wallpaperReleaseTimer.restart();
    }

    function _dropWallpaperVisuals() {
        wallpaperReleaseTimer.stop();
        wallpaperRequestPending = false;
        wallpaperVisualsRequested = false;
        wallpaperVisualsReady = false;
        keyboardYielded = false;
    }

    function markWeatherVisualsReady() {
        weatherVisualsReady = true;
        if (!weatherRequestPending)
            return;
        weatherRequestPending = false;
        requestActivity("weather", true, true);
    }

    function releaseWeatherVisuals() {
        if (expanded && activeActivity === "weather") {
            weatherReleaseTimer.stop();
            return;
        }
        if (!weatherVisualsRequested && !weatherVisualsReady)
            return;
        weatherReleaseTimer.restart();
    }

    function _dropWeatherVisuals() {
        weatherReleaseTimer.stop();
        weatherRequestPending = false;
        weatherVisualsRequested = false;
        weatherVisualsReady = false;
    }

    function setControlCenterContentHeight(height) {
        const next = Math.round(height);
        if (!isFinite(next) || Math.abs(next - controlCenterContentHeight) < 1)
            return;
        controlCenterContentHeight = next;
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

        launcherRequestPending = false;
        launcherSessionActive = false;
        controlCenterRequestPending = false;
        wallpaperRequestPending = false;
        weatherRequestPending = false;
        notificationCenterRequestPending = false;

        if (notificationActive) {
            notificationTimer.stop();
            hoverExpanded = false;
            hoverOpenTimer.stop();
            hoverCloseTimer.stop();
            keyboardDismissRequested = false;
            expanded = false;
            if (!systemActivityActive)
                transientReturnActivity = "notification";
            activeActivity = activityId;
            syncTransientTimeout(true);
            return true;
        }

        if (expanded) {
            if (activeActivity === activityId)
                transientTimer.stop();
            return activeActivity === activityId;
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

        if (notificationActive) {
            return refreshNotification();
        }

        launcherRequestPending = false;
        controlCenterRequestPending = false;
        wallpaperRequestPending = false;
        weatherRequestPending = false;
        notificationCenterRequestPending = false;

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
        if (launcherSessionActive)
            launcherSessionSerial++;
        if (nextActivity === "controlcenter" && nextExpanded)
            controlCenterSessionSerial++;
        if (nextActivity === "wallpaper" && nextExpanded)
            wallpaperSessionSerial++;
        if (nextActivity === "notificationcenter" && nextExpanded)
            notificationCenterSessionSerial++;
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
        if (pointerInside) {
            hoverCloseTimer.stop();
            if (hoverExpandEnabled && !expanded && !slotHovered)
                hoverOpenTimer.restart();
        } else {
            hoverOpenTimer.stop();
            if (hoverExpanded && expanded && !mediaDropdownOpen)
                hoverCloseTimer.restart();
        }
        syncNotificationTimeout(!pointerInside);
        syncTransientTimeout(!pointerInside);
        return true;
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

    property Timer autoDemoTimer: Timer {
        interval: 1600
        repeat: true
        running: root.autoDemo
        onTriggered: root.requestToggle(false)
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

    property Timer launcherReleaseTimer: Timer {
        interval: 260
        onTriggered: root._dropLauncherVisuals()
    }

    property Timer controlCenterReleaseTimer: Timer {
        interval: 260
        onTriggered: root._dropControlCenterVisuals()
    }

    property Timer wallpaperReleaseTimer: Timer {
        interval: 260
        onTriggered: root._dropWallpaperVisuals()
    }

    property Timer weatherReleaseTimer: Timer {
        interval: 260
        onTriggered: root._dropWeatherVisuals()
    }

    property Timer notificationCenterReleaseTimer: Timer {
        interval: 260
        onTriggered: root._dropNotificationCenterVisuals()
    }
}
