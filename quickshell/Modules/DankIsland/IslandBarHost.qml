pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modals.DankLauncherV2 as DankLauncher
import qs.Modules.DankBar
import qs.Services
import qs.Widgets
import "../../Common/LayoutResolver.js" as Resolver

Item {
    id: root

    required property var barConfig
    required property var screen
    required property var hostWindow
    required property string barId
    property real originOffsetX: 0
    property real originOffsetY: 0

    readonly property alias islandController: controller
    readonly property alias surface: surface
    readonly property int launcherResultCount: launcherController.flatModel?.length ?? 0
    readonly property var inputMaskItem: surface.inputMaskItem
    readonly property var fittsStripItem: surface.fittsStripItem
    readonly property bool motionRunning: surface.motionRunning
    readonly property rect motionStartBounds: surface.motionStartBounds
    readonly property real targetAlongPos: surface.targetAlongPos
    readonly property real currentAlongPos: surface.currentAlongPos
    readonly property real currentVisualAlong: surface.currentVisualAlong
    readonly property real targetVisualAlong: surface.targetVisualAlong
    readonly property real currentVisualX: surface.currentVisualX
    readonly property real currentVisualY: surface.currentVisualY
    readonly property real currentVisualWidth: surface.currentVisualWidth
    readonly property real currentVisualHeight: surface.currentVisualHeight
    readonly property real currentSurfaceRadius: surface.currentSurfaceRadius
    readonly property color surfaceColor: surface.surfaceColor
    readonly property real surfaceOpacity: surface.surfaceOpacity
    readonly property bool inputSuspended: controller.inputSuspended
    readonly property bool expanded: controller.expanded

    signal scrollWheel(var wheel)

    function setting(key) {
        return SettingsData.islandSetting(root.barConfig, key);
    }

    readonly property var islandMetrics: Resolver.islandMetrics(root.barConfig, SettingsData.islandDefaults)
    readonly property int compactThickness: root.islandMetrics.compact
    readonly property bool floating: root.setting("islandFloating")
    readonly property bool usesOverlayLayer: CompositorService.framePeerSurfacesUseOverlayForScreen(root.screen) || LayerShell.envUsesOverlay("DMS_DANKISLAND_LAYER", root.setting("islandUseOverlayLayer"))
    readonly property string edge: SettingsData.islandEdge(root.barConfig)
    readonly property bool isVertical: SettingsData.islandVertical(root.barConfig)
    readonly property bool farEdge: root.edge === "bottom" || root.edge === "right"
    readonly property int reservedStripThickness: root.islandMetrics.thickness
    readonly property real windowWidth: root.hostWindow?.width ?? 0
    readonly property real windowHeight: root.hostWindow?.height ?? 0
    readonly property real windowMarginLeft: root.hostWindow?.margins?.left ?? 0
    readonly property real windowMarginRight: root.hostWindow?.margins?.right ?? 0
    readonly property real windowMarginTop: root.hostWindow?.margins?.top ?? 0
    readonly property real windowMarginBottom: root.hostWindow?.margins?.bottom ?? 0
    readonly property int hostOriginX: (root.isVertical && root.farEdge ? Math.max(0, (root.screen?.width ?? 0) - root.windowWidth - root.windowMarginRight) : root.windowMarginLeft) + root.originOffsetX
    readonly property int hostOriginY: (!root.isVertical && root.farEdge ? Math.max(0, (root.screen?.height ?? 0) - root.windowHeight - root.windowMarginBottom) : root.windowMarginTop) + root.originOffsetY
    readonly property int outerGap: root.islandMetrics.gap
    readonly property int destinationMinHeight: 560
    readonly property int destinationMaxHeightLimit: 680
    readonly property int activityMinWidth: 320
    readonly property int activityMaxWidth: 736
    readonly property int screenMargin: 200
    readonly property int referenceScreenWidth: 1920
    readonly property int referenceScreenHeight: 1080
    readonly property int maxHoverDelay: 1000
    readonly property var springStiffnessRange: [100, 1200]
    readonly property var springDampingRange: [10, 100]
    readonly property var springMassRange: [0.25, 3]
    readonly property int destinationMaxHeight: Math.max(destinationMinHeight, Math.min(destinationMaxHeightLimit, (root.screen?.height ?? referenceScreenHeight) - screenMargin))
    readonly property int maxActivityHeight: Math.max(controller.dashboardHeight, controller.controlCenterHeight, destinationMaxHeight)
    readonly property int maxActivityWidth: Math.max(controller.dashboardMaxWidth, controller.controlCenterMaxWidth, Math.min(activityMaxWidth, Math.max(activityMinWidth, (root.screen?.width ?? referenceScreenWidth) - screenMargin)))
    readonly property int hostThickness: outerGap + (root.isVertical ? maxActivityWidth : maxActivityHeight) + Theme.spacingS
    readonly property real maximumAlongOffset: root.isVertical ? Math.max(0, (height - maxActivityHeight) / 2 - Theme.spacingS) : Math.max(0, (width - maxActivityWidth) / 2 - Theme.spacingS)
    readonly property bool scrollEnabled: root.barConfig?.scrollEnabled ?? true
    property bool keyboardFocusArmed: true
    readonly property var keyboardFocusPolicy: KeyboardFocus.keyboardFocus(controller.keyboardDismissRequested && root.keyboardFocusArmed && !controller.keyboardYielded, null)
    readonly property bool wantsFocusGrab: KeyboardFocus.wantsGrab(controller.keyboardDismissRequested && !controller.keyboardYielded, null)
    readonly property string registryKey: IslandHostRegistry.key(root.screen?.name, root.barId)
    property string registeredKey: ""

    property int popoutRevision: 0
    readonly property bool satelliteSurfacesOpen: {
        root.popoutRevision;
        const screenName = root.screen?.name;
        if (!screenName)
            return false;
        return !!PopoutManager.currentPopoutsByScreen[screenName] || !!ModalManager.currentModalsByScreen[screenName];
    }

    function requestKeyboardFocus() {
        if (!controller.keyboardDismissRequested) {
            keyboardActivationTimer.stop();
            keyboardFocusArmed = false;
            keyboardRearmTimer.restart();
            return;
        }
        keyboardRearmTimer.stop();
        keyboardFocusArmed = true;
        keyboardActivationTimer.restart();
    }

    function containsGlobalPoint(gx, gy, padding) {
        const pad = padding !== undefined ? padding : Theme.spacingL;
        const items = [surface.inputMaskItem, surface.fittsStripItem];
        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            if (!item || item.width <= 0 || item.height <= 0)
                continue;
            const topLeft = item.mapToItem(null, 0, 0);
            if (!topLeft)
                continue;
            const left = topLeft.x + root.hostOriginX - root.originOffsetX;
            const top = topLeft.y + root.hostOriginY - root.originOffsetY;
            if (gx >= left - pad && gx < left + item.width + pad && gy >= top - pad && gy < top + item.height + pad)
                return true;
        }
        return false;
    }

    function syncRegistration() {
        if (root.registeredKey === root.registryKey)
            return;
        if (root.registeredKey)
            IslandHostRegistry.unregister(root.registeredKey, root);
        root.registeredKey = root.registryKey;
        IslandHostRegistry.register(root.registeredKey, root);
    }

    onRegistryKeyChanged: syncRegistration()
    Component.onCompleted: syncRegistration()
    Component.onDestruction: IslandHostRegistry.unregister(root.registeredKey, root)

    Timer {
        id: keyboardActivationTimer

        interval: 60
        onTriggered: {
            if (controller.keyboardDismissRequested && !surface.requestActivityFocus())
                islandFocus.forceActiveFocus(Qt.PopupFocusReason);
        }
    }

    Timer {
        id: keyboardRearmTimer

        interval: 80
        onTriggered: root.keyboardFocusArmed = true
    }

    Connections {
        target: PopoutManager

        function onPopoutChanged() {
            root.popoutRevision++;
        }

        function onScreenshotActiveChanged() {
            if (!PopoutManager.screenshotActive && controller.keyboardDismissRequested)
                root.requestKeyboardFocus();
        }
    }

    IslandController {
        id: controller

        onKeyboardDismissRequestedChanged: root.requestKeyboardFocus()
        onLauncherSessionActiveChanged: {
            if (!launcherSessionActive)
                launcherTransientSurfaces.closeAll();
        }

        barConfig: root.barConfig
        edge: root.edge
        interactionMode: root.setting("islandInteractionMode") === "click" ? "click" : "hybrid"
        inputSuspended: PopoutManager.screenshotActive
        alongOffset: Math.max(-root.maximumAlongOffset, Math.min(root.maximumAlongOffset, root.setting("islandAlongOffset")))
        outerGap: root.outerGap
        compactThickness: root.compactThickness
        cornerRadius: Theme.windowRadius
        pillRadius: BarMetrics.pillRadius(root.compactThickness, root.barConfig?.widgetStyle ?? "pills")
        homeCompactTight: root.setting("islandHomeCompactTight")
        homeStatusContent: SettingsData.islandHomeStatusContent(root.barConfig)
        homeClockDisplay: SettingsData.islandClockDisplay(root.barConfig)
        homeVolumeDisplay: SettingsData.islandLevelDisplay(root.barConfig, "islandHomeVolumeDisplay")
        homeBrightnessDisplay: SettingsData.islandLevelDisplay(root.barConfig, "islandHomeBrightnessDisplay")
        batteryStyle: root.setting("islandBatteryStyle")
        mediaClockVisible: root.setting("islandMediaClockVisible")
        launcherCycleEnabled: SettingsData.launcherStyle === "island"
        dashboardAvailableWidth: Math.max(0, (root.screen?.width ?? root.referenceScreenWidth) - root.windowMarginLeft - root.windowMarginRight - (root.isVertical ? root.outerGap : 0) - Theme.spacingL * 2)
        dashboardAvailableHeight: Math.max(0, (root.screen?.height ?? root.referenceScreenHeight) - root.windowMarginTop - root.windowMarginBottom - (root.isVertical ? 0 : root.outerGap) - Theme.spacingL * 2)
        controlCenterMaxHeight: dashboardAvailableHeight
        notificationExpandAllowed: root.setting("islandNotificationExpand")
        unreadNotificationCount: root.setting("islandNotificationBadgeClearOnOpen") ? NotificationService.unreadCount : NotificationService.notifications.length
        hoverOpenDelay: Math.max(0, Math.min(root.maxHoverDelay, root.setting("islandHoverOpenDelay")))
        hoverCloseDelay: Math.max(0, Math.min(root.maxHoverDelay, root.setting("islandHoverCloseDelay")))
    }

    DankLauncher.Controller {
        id: launcherController

        active: controller.launcherSessionActive
        viewModeContext: "spotlight"
        forceLinearNavigation: true
    }

    TransientSurfaceTracker {
        id: launcherTransientSurfaces
    }

    IslandMediaSource {
        id: mediaSource

        controller: controller
    }

    IslandSystemSource {
        id: systemSource

        controller: controller
    }

    IslandNotificationSource {
        id: notificationSource

        controller: controller
        targetScreen: root.screen
        enabled: !root.setting("islandNotificationPopups")
    }

    DankIslandSurface {
        id: surface

        anchors.fill: parent
        controller: controller
        mediaModel: mediaSource
        systemModel: systemSource
        notificationModel: notificationSource
        launcherController: launcherController
        launcherTransientSurfaceTracker: launcherTransientSurfaces
        effectiveScreen: root.screen
        hostOriginX: root.hostOriginX
        hostOriginY: root.hostOriginY
        reducedMotion: root.setting("islandReducedMotion") || SettingsData.reduceMotion || SettingsData.animationDuration <= 0
        springStiffness: Math.max(root.springStiffnessRange[0], Math.min(root.springStiffnessRange[1], root.setting("islandSpringStiffness")))
        springDamping: Math.max(root.springDampingRange[0], Math.min(root.springDampingRange[1], root.setting("islandSpringDamping")))
        springMass: Math.max(root.springMassRange[0], Math.min(root.springMassRange[1], root.setting("islandSpringMass")))
        palette: root.setting("islandPalette")
        highContrast: root.setting("islandHighContrast")
        transparency: SettingsData.barTransparency(root.barConfig)
        onScrollWheel: wheel => root.scrollWheel(wheel)
    }

    FocusScope {
        id: islandFocus

        anchors.fill: parent
        Keys.onEscapePressed: event => {
            controller.requestCollapse();
            event.accepted = true;
        }
    }
}
