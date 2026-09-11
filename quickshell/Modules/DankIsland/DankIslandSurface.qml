pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DankDash
import qs.Modules.DankIsland.Activities
import qs.Services
import qs.Widgets

Item {
    id: root

    required property IslandController controller
    required property var mediaModel
    required property var systemModel
    required property var notificationModel
    required property var launcherController
    property var launcherTransientSurfaceTracker: null
    property var notificationTransientSurfaceTracker: null
    property var effectiveScreen: null
    property bool reducedMotion: false
    property real springStiffness: 560
    property real springDamping: 37
    property real springMass: 1
    property real hostOriginX: 0
    property real hostOriginY: 0
    property string palette: "default"
    property bool highContrast: false
    property real transparency: 1

    readonly property color surfaceColor: {
        if (root.highContrast)
            return Theme.surfaceContainerHighest;
        switch (root.palette) {
        case "bright":
            return Theme.surfaceBright;
        case "dim":
            return Theme.surfaceDim;
        }
        return Theme.surfaceContainerHigh;
    }
    readonly property bool popupStyled: root.controller.expanded
    readonly property real islandOpacity: Math.max(0, Math.min(1, root.transparency))
    readonly property color effectiveSurfaceColor: root.highContrast ? Theme.surfaceContainerHighest : Theme.withAlpha(root.surfaceColor, root.islandOpacity)
    readonly property real surfaceOpacity: root.effectiveSurfaceColor.a
    readonly property real currentSurfaceRadius: Math.max(0, motion.currentTopLeftRadius, motion.currentBottomLeftRadius)
    readonly property color notificationAccentColor: {
        if (!root.controller.notificationActive)
            return "transparent";
        if (root.notificationModel.critical)
            return Theme.error;
        if (root.notificationModel.important)
            return Theme.warning;
        return "transparent";
    }

    signal scrollWheel(var wheel)

    readonly property alias inputMaskItem: inputEnvelope
    readonly property alias fittsStripItem: fittsStrip
    readonly property bool motionRunning: motion.running
    readonly property real springTimeConstantMs: motion.timeConstantMs
    property real trackedCrossExtent: 0
    property real fadeCompactCross: 48
    property real fadeExpandedCross: 352
    property rect motionStartBounds: Qt.rect(0, 0, 0, 0)
    readonly property bool isVertical: root.controller.isVertical
    readonly property bool farEdge: root.controller.edge === "bottom" || root.controller.edge === "right"
    readonly property real alongExtent: root.isVertical ? root.height : root.width
    readonly property real crossExtent: root.isVertical ? root.width : root.height
    readonly property real currentVisualWidth: motion.currentWidth
    readonly property real currentVisualHeight: motion.currentHeight
    readonly property real currentVisualCross: isVertical ? motion.currentWidth : motion.currentHeight
    readonly property real currentAlongPos: (alongExtent - (isVertical ? currentVisualHeight : currentVisualWidth)) / 2 + motion.currentOffsetAlong
    readonly property real currentCrossPos: farEdge ? crossExtent - motion.currentOffsetCross - currentVisualCross : motion.currentOffsetCross
    readonly property real currentVisualX: isVertical ? currentCrossPos : currentAlongPos
    readonly property real currentVisualY: isVertical ? currentAlongPos : currentCrossPos
    readonly property real targetAlongPos: Math.round((alongExtent - (isVertical ? motion.targetHeight : motion.targetWidth)) / 2 + motion.targetOffsetAlong)
    readonly property real targetCrossPos: farEdge ? crossExtent - Math.round(motion.targetOffsetCross) - (isVertical ? motion.targetWidth : motion.targetHeight) : Math.round(motion.targetOffsetCross)
    readonly property real targetVisualX: isVertical ? targetCrossPos : targetAlongPos
    readonly property real targetVisualY: isVertical ? targetAlongPos : targetCrossPos
    readonly property real targetScreenX: targetVisualX + root.hostOriginX
    readonly property real targetScreenY: targetVisualY + root.hostOriginY
    readonly property real targetVisualWidth: motion.targetWidth
    readonly property real targetVisualHeight: motion.targetHeight
    readonly property real currentVisualAlong: isVertical ? motion.currentHeight : motion.currentWidth
    readonly property real targetVisualAlong: isVertical ? motion.targetHeight : motion.targetWidth
    readonly property real morphProgress: {
        const span = fadeExpandedCross - fadeCompactCross;
        if (Math.abs(span) < 1)
            return controller.expanded ? 1 : 0;
        return Math.max(0, Math.min(1, (currentVisualCross - fadeCompactCross) / span));
    }

    function descriptorCross(target) {
        return root.isVertical ? target.width : target.height;
    }

    function descriptorAlong(target) {
        return root.isVertical ? target.height : target.width;
    }

    function applyTarget() {
        if (controller.expanded)
            fadeExpandedCross = root.descriptorCross(controller.expandedTarget);
        else
            fadeCompactCross = root.descriptorCross(controller.compactTarget);
        if (motion.running)
            root.unionMotionStartBounds();
        motion.setTarget(controller.targetDescriptor);
        if (!motion.running)
            root.controller.releaseIdleVisuals();
    }

    function unionMotionStartBounds() {
        const b = root.motionStartBounds;
        const left = Math.min(b.x, root.currentVisualX);
        const top = Math.min(b.y, root.currentVisualY);
        const right = Math.max(b.x + b.width, root.currentVisualX + root.currentVisualWidth);
        const bottom = Math.max(b.y + b.height, root.currentVisualY + root.currentVisualHeight);
        root.motionStartBounds = Qt.rect(left, top, right - left, bottom - top);
    }

    function requestActivityFocus() {
        return contentHost.requestActivityFocus();
    }

    Component.onCompleted: {
        trackedCrossExtent = crossExtent;
        fadeCompactCross = root.descriptorCross(controller.compactTarget);
        fadeExpandedCross = root.descriptorCross(controller.expandedTarget);
        motion.snapTo(controller.targetDescriptor);
    }

    // On a far edge the cross coordinate is measured from the far side, so a host resize
    // shifts everything already in flight by the same delta.
    onCrossExtentChanged: {
        const delta = crossExtent - trackedCrossExtent;
        trackedCrossExtent = crossExtent;
        if (!farEdge || !motion.running || delta === 0)
            return;
        const b = motionStartBounds;
        motionStartBounds = isVertical ? Qt.rect(b.x + delta, b.y, b.width, b.height) : Qt.rect(b.x, b.y + delta, b.width, b.height);
    }

    Connections {
        target: root.controller

        function onTargetDescriptorChanged() {
            root.applyTarget();
        }
    }

    Connections {
        target: motion

        function onRunningChanged() {
            if (motion.running) {
                root.motionStartBounds = Qt.rect(root.currentVisualX, root.currentVisualY, root.currentVisualWidth, root.currentVisualHeight);
                return;
            }
            root.controller.releaseIdleVisuals();
        }
    }

    VectorSpringMotion {
        id: motion

        reducedMotion: root.reducedMotion
        stiffness: root.springStiffness
        damping: root.springDamping
        mass: root.springMass
    }

    // Frozen start/target union so the Wayland mask is not rewritten every spring frame.
    Item {
        id: inputEnvelope

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
        width: root.currentVisualWidth
        height: root.currentVisualHeight
        topLeftRadius: Math.max(0, motion.currentTopLeftRadius)
        topRightRadius: Math.max(0, motion.currentTopRightRadius)
        bottomLeftRadius: Math.max(0, motion.currentBottomLeftRadius)
        bottomRightRadius: Math.max(0, motion.currentBottomRightRadius)
        color: root.effectiveSurfaceColor
        border.width: root.notificationAccentColor !== "transparent" ? 1.5 : (root.highContrast ? 2 : (root.popupStyled ? BlurService.borderWidth : 0))
        border.color: root.notificationAccentColor !== "transparent" ? root.notificationAccentColor : (root.highContrast ? Theme.outlineStrong : (root.popupStyled ? BlurService.borderColor : "transparent"))

        Behavior on color {
            ColorAnimation {
                duration: root.reducedMotion ? 0 : Theme.shortDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: root.reducedMotion ? 0 : Theme.shortDuration
                easing.type: Easing.OutCubic
            }
        }

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

            controller: root.controller
            islandX: root.currentVisualX
            islandY: root.currentVisualY
            hostWidth: root.width
            hostHeight: root.height
            springTimeConstantMs: root.springTimeConstantMs
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
            controlCenterCompactComponent: compactControlCenterComponent
            controlCenterExpandedComponent: expandedControlCenterComponent
            wallpaperCompactComponent: compactWallpaperComponent
            wallpaperExpandedComponent: expandedWallpaperComponent
            weatherCompactComponent: compactWeatherComponent
            weatherExpandedComponent: expandedWeatherComponent
            systemCompactComponent: compactSystemComponent
            systemExpandedComponent: expandedSystemComponent
            notificationCompactComponent: compactNotificationComponent
            notificationExpandedComponent: expandedNotificationComponent
            notificationCenterCompactComponent: compactNotificationCenterComponent
            notificationCenterExpandedComponent: expandedNotificationCenterComponent
        }

        HoverHandler {
            id: islandHover

            onHoveredChanged: root.updateFittsPointerInside()
        }
    }

    function updateFittsPointerInside() {
        root.controller.updatePointerInside(islandHover.hovered || stripHover.hovered);
    }

    // Fitts zone from the island edge to the screen edge — hover/click count as island.
    // Bounds follow the spring target, never the per-frame value, so the Wayland mask is not
    // rewritten every frame and the strip never shrinks out from under the cursor mid-open.
    Item {
        id: fittsStrip

        readonly property real targetCross: root.isVertical ? motion.targetWidth : motion.targetHeight
        readonly property real span: Math.max(root.descriptorAlong(root.controller.compactTarget), root.isVertical ? motion.targetHeight : motion.targetWidth)
        readonly property real edgeGap: root.farEdge ? Math.max(0, root.crossExtent - (root.targetCrossPos + targetCross)) : Math.max(0, root.targetCrossPos)
        readonly property real alongPos: Math.round((root.alongExtent - span) / 2 + motion.targetOffsetAlong)
        readonly property real crossPos: root.farEdge ? root.targetCrossPos + targetCross : 0

        x: root.isVertical ? crossPos : alongPos
        y: root.isVertical ? alongPos : crossPos
        width: root.isVertical ? edgeGap : span
        height: root.isVertical ? span : edgeGap
        visible: edgeGap > 0 && span > 0

        HoverHandler {
            id: stripHover

            onHoveredChanged: root.updateFittsPointerInside()
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: root.controller.requestToggle(true)
            onWheel: wheel => {
                root.scrollWheel(wheel);
                wheel.accepted = true;
            }
        }
    }

    Component {
        id: compactHomeComponent

        HomeCompact {
            controller: root.controller
            systemModel: root.systemModel
        }
    }

    Component {
        id: expandedHomeComponent

        HomeExpanded {
            controller: root.controller
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
            controller: root.controller
        }
    }

    Component {
        id: compactLauncherComponent

        DestinationCompact {
            id: launcherFace

            readonly property real logoSize: Math.max(12, Theme.iconSizeSmall + SettingsData.launcherLogoSizeOffset)
            readonly property color logoColor: Theme.effectiveLogoColor !== "" ? Theme.effectiveLogoColor : Theme.surfaceText

            controller: root.controller
            activityId: "launcher"
            label: I18n.tr("Launcher", "island compact face: launcher label")
            leading: LauncherLogo {
                mode: SettingsData.launcherLogoMode
                size: launcherFace.logoSize
                appsIconColor: launcherFace.logoColor
                colorOverride: String(launcherFace.logoColor)
                brightness: SettingsData.launcherLogoBrightness
                contrast: SettingsData.launcherLogoContrast
                customPath: SettingsData.launcherLogoCustomPath
                fallbackToApps: true
            }
        }
    }

    Component {
        id: expandedLauncherComponent

        LauncherExpanded {
            controller: root.controller
            launcherController: root.launcherController
            transientSurfaceTracker: root.launcherTransientSurfaceTracker
            effectiveScreen: root.effectiveScreen
            alignedX: root.targetScreenX
            alignedY: root.targetScreenY
        }
    }

    Component {
        id: compactControlCenterComponent

        DestinationCompact {
            controller: root.controller
            activityId: "controlcenter"
            iconName: "tune"
            label: I18n.tr("Control Center", "island compact face: control center label")
        }
    }

    Component {
        id: expandedControlCenterComponent

        ControlCenterExpanded {
            controller: root.controller
            effectiveScreen: root.effectiveScreen
            alignedX: root.targetScreenX
            alignedY: root.targetScreenY
            alignedWidth: root.targetVisualWidth
            alignedHeight: root.targetVisualHeight
        }
    }

    Component {
        id: compactWallpaperComponent

        DestinationCompact {
            controller: root.controller
            activityId: "wallpaper"
            iconName: "wallpaper"
            label: I18n.tr("Wallpaper", "island compact face: wallpaper picker label")
        }
    }

    Component {
        id: expandedWallpaperComponent

        WallpaperExpanded {
            controller: root.controller
            effectiveScreen: root.effectiveScreen
        }
    }

    Component {
        id: compactWeatherComponent

        DestinationCompact {
            controller: root.controller
            activityId: "weather"
            iconName: "partly_cloudy_day"
            label: I18n.tr("Weather", "island compact face: weather label")
        }
    }

    Component {
        id: expandedWeatherComponent

        WeatherExpanded {
            controller: root.controller
        }
    }

    Component {
        id: compactSystemComponent

        SystemLevelCompact {
            systemModel: root.systemModel
            isVertical: root.isVertical
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
            controller: root.controller
            dense: root.controller.compactDense
            iconSize: root.controller.compactIconSize
        }
    }

    Component {
        id: compactNotificationCenterComponent

        DestinationCompact {
            id: notificationCenterFace

            readonly property int unreadCount: NotificationService.notifications.length

            controller: root.controller
            activityId: "notificationcenter"
            iconName: notificationCenterFace.unreadCount > 0 ? "notifications_active" : "notifications"
            label: notificationCenterFace.unreadCount > 0 ? I18n.tr("%1 notifications", "island compact face: unread notification count").arg(notificationCenterFace.unreadCount) : I18n.tr("Notifications", "island compact face: notification center label")
        }
    }

    Component {
        id: expandedNotificationCenterComponent

        NotificationCenterExpanded {
            controller: root.controller
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
