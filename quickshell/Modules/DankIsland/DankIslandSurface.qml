pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DankDash
import qs.Modules.DankIsland.Activities
import qs.Services

Item {
    id: root

    required property IslandController controller
    required property var mediaModel
    required property var systemModel
    required property var notificationModel
    required property var launcherController
    property var launcherTransientSurfaceTracker: null
    property var notificationTransientSurfaceTracker: null
    property var colorPickerModal: null
    property var powerMenuModalLoader: null
    property var effectiveScreen: null
    property bool reducedMotion: false
    property real springStiffness: 560
    property real springDamping: 37
    property real springMass: 1
    // Screen-space Y of the host strip's local origin; non-zero only on the bottom edge.
    property real hostOriginY: 0
    property string palette: "default"
    property bool highContrast: false

    readonly property color surfaceColor: {
        if (root.highContrast)
            return Theme.surfaceContainerHighest;
        if (root.palette === "bright")
            return Theme.surfaceBright;
        if (root.palette === "dim")
            return Theme.surfaceDim;
        return Theme.surfaceContainerHigh;
    }

    signal lockRequested
    signal scrollWheel(var wheel)

    readonly property alias inputMaskItem: inputEnvelope
    readonly property bool motionRunning: motion.running
    readonly property Item mediaDropdownMaskItem: mediaDropdowns.__activePanel
    property real fadeCompactHeight: 48
    property real fadeExpandedHeight: 352
    property rect motionStartBounds: Qt.rect(0, 0, 0, 0)
    property int mediaDropdownType: 0
    property point mediaDropdownAnchor: Qt.point(0, 0)
    readonly property real currentVisualX: (width - motion.currentWidth) / 2 + motion.currentOffsetX
    readonly property bool bottomEdge: SettingsData.dankIslandEdge === "bottom"
    readonly property real currentVisualY: bottomEdge ? height - motion.currentOffsetY - motion.currentHeight : motion.currentOffsetY
    readonly property real currentVisualWidth: motion.currentWidth
    readonly property real currentVisualHeight: motion.currentHeight
    readonly property real targetVisualX: (width - motion.targetWidth) / 2 + motion.targetOffsetX
    readonly property real targetVisualY: bottomEdge ? height - motion.targetOffsetY - motion.targetHeight : motion.targetOffsetY
    // Activity hosts hand alignedY to full-screen windows, which need screen space, not surface space.
    readonly property real targetScreenY: targetVisualY + root.hostOriginY
    readonly property real targetVisualWidth: motion.targetWidth
    readonly property real targetVisualHeight: motion.targetHeight
    readonly property real morphProgress: {
        const span = fadeExpandedHeight - fadeCompactHeight;
        if (Math.abs(span) < 1)
            return controller.expanded ? 1 : 0;
        return Math.max(0, Math.min(1, (motion.currentHeight - fadeCompactHeight) / span));
    }

    function applyTarget() {
        if (controller.expanded)
            fadeExpandedHeight = controller.expandedTarget.height;
        else
            fadeCompactHeight = controller.compactTarget.height;
        // A retarget leaves the frozen start stale, so widen it to cover where the island is now.
        if (motion.running)
            root.unionMotionStartBounds();
        motion.setTarget(controller.targetDescriptor);
        if (!motion.running)
            root.releaseIdleVisuals();
    }

    function unionMotionStartBounds() {
        const b = root.motionStartBounds;
        const left = Math.min(b.x, root.currentVisualX);
        const top = Math.min(b.y, root.currentVisualY);
        const right = Math.max(b.x + b.width, root.currentVisualX + motion.currentWidth);
        const bottom = Math.max(b.y + b.height, root.currentVisualY + motion.currentHeight);
        root.motionStartBounds = Qt.rect(left, top, right - left, bottom - top);
    }

    function releaseIdleVisuals() {
        root.controller.releaseWallpaperVisuals();
        root.controller.releaseWeatherVisuals();
        root.controller.releaseNotificationCenterVisuals();
        root.controller.releaseLauncherVisuals();
        root.controller.releaseControlCenterVisuals();
    }

    function openMediaDropdown(type, pos) {
        stopMediaDropdownCloseTimer();
        mediaDropdownAnchor = pos;
        mediaDropdownType = type;
        controller.mediaDropdownOpen = true;
    }

    function hideMediaDropdowns() {
        stopMediaDropdownCloseTimer();
        mediaDropdownType = 0;
        controller.mediaDropdownOpen = false;
    }

    function startMediaDropdownCloseTimer() {
        mediaDropdownCloseTimer.restart();
    }

    function stopMediaDropdownCloseTimer() {
        mediaDropdownCloseTimer.stop();
    }

    function requestActivityFocus() {
        return contentHost.requestActivityFocus();
    }

    Component.onCompleted: {
        fadeCompactHeight = controller.compactTarget.height;
        fadeExpandedHeight = controller.expandedTarget.height;
        motion.snapTo(controller.targetDescriptor);
    }

    Connections {
        target: root.controller

        function onTargetDescriptorChanged() {
            root.applyTarget();
        }

        function onExpandedChanged() {
            if (!controller.expanded || controller.activeActivity !== "media")
                root.hideMediaDropdowns();
        }

        function onActiveActivityChanged() {
            if (controller.activeActivity !== "media")
                root.hideMediaDropdowns();
        }
    }

    Connections {
        target: motion

        function onRunningChanged() {
            if (motion.running) {
                root.motionStartBounds = Qt.rect(root.currentVisualX, root.currentVisualY, motion.currentWidth, motion.currentHeight);
                if (root.controller.activeActivity === "media")
                    root.hideMediaDropdowns();
                return;
            }
            root.releaseIdleVisuals();
        }
    }

    VectorSpringMotion {
        id: motion

        reducedMotion: root.reducedMotion
        stiffness: root.springStiffness
        damping: root.springDamping
        mass: root.springMass
    }

    Timer {
        id: mediaDropdownCloseTimer

        interval: 400
        onTriggered: root.hideMediaDropdowns()
    }

    // Frozen start/target union so the Wayland mask is not rewritten every spring frame.
    Item {
        id: inputEnvelope

        // Cover underdamped overshoot for the frozen flight, scaled to travel.
        readonly property real overshootBudget: {
            if (!motion.running)
                return 0;
            const zeta = motion.damping / (2 * Math.sqrt(Math.max(1, motion.stiffness * motion.mass)));
            if (zeta >= 1)
                return 0;
            const spanX = Math.abs(root.targetVisualX - root.motionStartBounds.x);
            const spanY = Math.abs(root.targetVisualY - root.motionStartBounds.y);
            const spanW = Math.abs(motion.targetWidth - root.motionStartBounds.width);
            const spanH = Math.abs(motion.targetHeight - root.motionStartBounds.height);
            const span = Math.max(spanX, spanY, spanW, spanH);
            return Math.ceil(span * Math.exp(-Math.PI * zeta / Math.sqrt(1 - zeta * zeta)));
        }

        x: (motion.running ? Math.min(root.motionStartBounds.x, root.targetVisualX) : root.targetVisualX) - overshootBudget
        y: (motion.running ? Math.min(root.motionStartBounds.y, root.targetVisualY) : root.targetVisualY) - overshootBudget
        width: (motion.running ? Math.max(root.motionStartBounds.x + root.motionStartBounds.width, root.targetVisualX + motion.targetWidth) : root.targetVisualX + motion.targetWidth) + overshootBudget - x
        height: (motion.running ? Math.max(root.motionStartBounds.y + root.motionStartBounds.height, root.targetVisualY + motion.targetHeight) : root.targetVisualY + motion.targetHeight) + overshootBudget - y
    }

    Rectangle {
        id: island

        x: root.currentVisualX
        y: root.currentVisualY
        width: motion.currentWidth
        height: motion.currentHeight
        topLeftRadius: Math.max(0, motion.currentTopLeftRadius)
        topRightRadius: Math.max(0, motion.currentTopRightRadius)
        bottomLeftRadius: Math.max(0, motion.currentBottomLeftRadius)
        bottomRightRadius: Math.max(0, motion.currentBottomRightRadius)
        color: root.surfaceColor
        border.width: root.highContrast ? 2 : 0
        border.color: root.highContrast ? Theme.outlineStrong : "transparent"

        // Full destinations keep blank clicks for their own content instead of collapsing.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            enabled: !root.controller.expanded || !root.controller.activityOwnsBlankClicks
            onClicked: root.controller.requestToggle(true)
            onWheel: wheel => {
                if (root.controller.expanded) {
                    wheel.accepted = false;
                    return;
                }
                root.scrollWheel(wheel);
                wheel.accepted = true;
            }
        }

        IslandContentHost {
            id: contentHost

            anchors.fill: parent
            morphProgress: root.morphProgress
            expanded: root.controller.expanded
            pointerInside: root.controller.pointerInside
            activityId: root.controller.activeActivity
            homeCompactComponent: compactHomeComponent
            homeExpandedComponent: expandedHomeComponent
            mediaCompactComponent: compactMediaComponent
            mediaExpandedComponent: expandedMediaComponent
            launcherCompactComponent: compactLauncherComponent
            launcherExpandedComponent: expandedLauncherComponent
            launcherVisualsRequested: root.controller.launcherVisualsRequested
            controlCenterCompactComponent: compactControlCenterComponent
            controlCenterExpandedComponent: expandedControlCenterComponent
            controlCenterVisualsRequested: root.controller.controlCenterVisualsRequested
            wallpaperCompactComponent: compactWallpaperComponent
            wallpaperExpandedComponent: expandedWallpaperComponent
            wallpaperVisualsRequested: root.controller.wallpaperVisualsRequested
            weatherCompactComponent: compactWeatherComponent
            weatherExpandedComponent: expandedWeatherComponent
            weatherVisualsRequested: root.controller.weatherVisualsRequested
            systemCompactComponent: compactSystemComponent
            systemExpandedComponent: expandedSystemComponent
            notificationCompactComponent: compactNotificationComponent
            notificationExpandedComponent: expandedNotificationComponent
            notificationCenterCompactComponent: compactNotificationCenterComponent
            notificationCenterExpandedComponent: expandedNotificationCenterComponent
            notificationCenterVisualsRequested: root.controller.notificationCenterVisualsRequested
        }

        HoverHandler {
            onHoveredChanged: {
                if (hovered)
                    root.controller.updatePointerInside(true);
                else
                    root.controller.updatePointerInside(false);
            }
        }
    }

    MediaDropdownOverlay {
        id: mediaDropdowns

        dropdownType: root.mediaDropdownType
        anchorPos: root.mediaDropdownAnchor
        isRightEdge: true
        availableBounds: Qt.rect(0, 0, root.width, root.height)
        activePlayer: MprisController.activePlayer
        allPlayers: MprisController.availablePlayers
        targetWindow: root.Window.window
        onCloseRequested: root.hideMediaDropdowns()
        onPanelEntered: root.stopMediaDropdownCloseTimer()
        onPanelExited: root.startMediaDropdownCloseTimer()
        onVolumeChanged: volume => {
            const player = MprisController.activePlayer;
            const identity = (player?.identity ?? "").toLowerCase();
            const chrome = identity.includes("chrome") || identity.includes("chromium");
            if (player && player.volumeSupported && !chrome)
                player.volume = volume;
            else if (AudioService.sink?.audio)
                AudioService.sink.audio.volume = volume;
        }
        onDeviceSelected: device => AudioService.setSink(device)
        onPlayerSelected: player => MprisController.setActivePlayer(player)
    }

    Component {
        id: compactHomeComponent

        HomeCompact {
            controller: root.controller
            mediaModel: root.mediaModel
        }
    }

    Component {
        id: expandedHomeComponent

        HomeExpanded {
            islandController: root.controller
        }
    }

    Component {
        id: compactMediaComponent

        MediaCompact {
            mediaModel: root.mediaModel
            controller: root.controller
        }
    }

    Component {
        id: expandedMediaComponent

        MediaExpanded {
            islandController: root.controller
            geometrySettled: !motion.running
            effectiveScreen: root.effectiveScreen
            alignedX: root.targetVisualX
            // Surface-local on purpose: the media dropdowns it anchors live inside this surface.
            alignedY: root.targetVisualY
            alignedWidth: root.targetVisualWidth
            alignedHeight: root.targetVisualHeight
            onShowVolumeDropdown: pos => root.openMediaDropdown(1, pos)
            onShowAudioDevicesDropdown: pos => root.openMediaDropdown(2, pos)
            onShowPlayersDropdown: pos => root.openMediaDropdown(3, pos)
            onHideDropdowns: root.hideMediaDropdowns()
            onDropdownHoverEnded: root.startMediaDropdownCloseTimer()
        }
    }

    Component {
        id: compactLauncherComponent

        LauncherCompact {
            controller: root.controller
        }
    }

    Component {
        id: expandedLauncherComponent

        LauncherExpanded {
            islandController: root.controller
            launcherController: root.launcherController
            transientSurfaceTracker: root.launcherTransientSurfaceTracker
            effectiveScreen: root.effectiveScreen
            // Settled bounds; animated values rebind the tree every frame.
            alignedX: root.targetVisualX
            alignedY: root.targetScreenY
        }
    }

    Component {
        id: compactControlCenterComponent

        ControlCenterCompact {
            controller: root.controller
        }
    }

    Component {
        id: expandedControlCenterComponent

        ControlCenterExpanded {
            islandController: root.controller
            effectiveScreen: root.effectiveScreen
            colorPickerModal: root.colorPickerModal
            powerMenuModalLoader: root.powerMenuModalLoader
            // Settled bounds; animated values rebind the tree every frame.
            alignedX: root.targetVisualX
            alignedY: root.targetScreenY
            alignedWidth: root.targetVisualWidth
            alignedHeight: root.targetVisualHeight
            onLockRequested: root.lockRequested()
        }
    }

    Component {
        id: compactWallpaperComponent

        WallpaperCompact {
            controller: root.controller
        }
    }

    Component {
        id: expandedWallpaperComponent

        WallpaperExpanded {
            islandController: root.controller
            effectiveScreen: root.effectiveScreen
        }
    }

    Component {
        id: compactWeatherComponent

        WeatherCompact {
            controller: root.controller
        }
    }

    Component {
        id: expandedWeatherComponent

        WeatherExpanded {
            islandController: root.controller
        }
    }

    Component {
        id: compactSystemComponent

        SystemLevelCompact {
            systemModel: root.systemModel
            dense: root.controller.compactDense
            iconSize: root.controller.compactIconSize
        }
    }

    Component {
        id: expandedSystemComponent

        SystemLevelExpanded {
            systemModel: root.systemModel
        }
    }

    Component {
        id: compactNotificationComponent

        NotificationCompact {
            notificationModel: root.notificationModel
            dense: root.controller.compactDense
            iconSize: root.controller.compactIconSize
        }
    }

    Component {
        id: compactNotificationCenterComponent

        NotificationCenterCompact {
            controller: root.controller
        }
    }

    Component {
        id: expandedNotificationCenterComponent

        NotificationCenterExpanded {
            islandController: root.controller
            effectiveScreen: root.effectiveScreen
            transientSurfaceTracker: root.notificationTransientSurfaceTracker
        }
    }

    Component {
        id: expandedNotificationComponent

        NotificationExpanded {
            notificationModel: root.notificationModel
        }
    }
}
