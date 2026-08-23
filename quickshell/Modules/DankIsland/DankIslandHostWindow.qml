pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Modals.DankLauncherV2 as DankLauncher
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

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
        const pad = padding !== undefined ? padding : 16;
        const items = [surface.inputMaskItem, surface.mediaDropdownMaskItem, satelliteHost.leftInputItem, satelliteHost.rightInputItem];
        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            if (!item || item.width <= 0 || item.height <= 0)
                continue;
            const topLeft = item.mapToItem(null, 0, 0);
            if (!topLeft)
                continue;
            // mapToItem(null) is window-local; callers pass screen-space cursor coords.
            const top = topLeft.y + root.hostOriginY;
            if (gx >= topLeft.x - pad && gx < topLeft.x + item.width + pad && gy >= top - pad && gy < top + item.height + pad)
                return true;
        }
        return false;
    }

    readonly property int reserveHeight: Math.max(24, Math.min(128, SettingsData.dankIslandReserveHeight))
    readonly property int compactHeight: Math.max(24, Math.min(72, SettingsData.dankIslandCompactHeight))
    readonly property bool floating: SettingsData.dankIslandFloating
    readonly property bool usesOverlayLayer: LayerShell.envUsesOverlay("DMS_DANKISLAND_LAYER", SettingsData.dankIslandUseOverlayLayer)
    readonly property var islandLayer: LayerShell.fromEnv("DMS_DANKISLAND_LAYER", usesOverlayLayer ? WlrLayer.Overlay : WlrLayer.Top)
    readonly property bool bottomEdge: SettingsData.dankIslandEdge === "bottom"
    readonly property int reservedStripHeight: Math.max(reserveHeight, outerGap + compactHeight)
    // Input bands hug the anchored edge, which is the far side of the host when anchored bottom.
    readonly property int stripY: root.bottomEdge ? root.height - root.reservedStripHeight : 0
    // Screen-space Y of this strip's local origin. Zero on top, where the two spaces coincide.
    readonly property int hostOriginY: root.bottomEdge ? Math.max(0, (root.screen?.height ?? 0) - root.height) : 0
    readonly property int outerGap: Math.max(0, Math.min(48, SettingsData.dankIslandOuterGap))
    // The host is larger than the visible island to cover every clamped activity target.
    readonly property int maxActivityHeight: Math.max(560, Math.min(680, (screen?.height ?? 1080) - 200))
    readonly property int hostHeight: outerGap + maxActivityHeight + 8
    readonly property int maxActivityWidth: 736
    readonly property real maximumHorizontalOffset: Math.max(0, (width - maxActivityWidth) / 2 - 8)
    property var colorPickerModal: null
    property var powerMenuModalLoader: null
    property bool keyboardFocusArmed: true

    signal lockRequested

    color: "transparent"
    implicitHeight: hostHeight
    exclusiveZone: floating ? 0 : reservedStripHeight
    readonly property alias islandController: controller
    readonly property int launcherResultCount: launcherController.flatModel?.length ?? 0

    anchors {
        top: !root.bottomEdge
        bottom: root.bottomEdge
        left: true
        right: true
    }

    WlrLayershell.namespace: "dms:dankisland"
    WlrLayershell.layer: islandLayer
    WlrLayershell.keyboardFocus: KeyboardFocus.keyboardFocus(controller.keyboardDismissRequested && root.keyboardFocusArmed && !controller.keyboardYielded, null)

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

    DankFocusGrab {
        windows: [root]
        wanted: KeyboardFocus.wantsGrab(controller.keyboardDismissRequested && !controller.keyboardYielded, null)
    }

    Component.onCompleted: KeyboardFocus.registerBarWindow(root)
    Component.onDestruction: KeyboardFocus.unregisterBarWindow(root)

    Connections {
        target: controller

        function onKeyboardDismissRequestedChanged() {
            root.requestKeyboardFocus();
        }
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

    mask: Region {
        Region {
            item: controller.inputSuspended ? null : surface.inputMaskItem
        }

        Region {
            item: controller.inputSuspended ? null : satelliteHost.leftInputItem
        }

        Region {
            item: controller.inputSuspended ? null : satelliteHost.rightInputItem
        }

        Region {
            item: controller.inputSuspended ? null : surface.mediaDropdownMaskItem
        }

        Region {
            item: controller.inputSuspended || !satelliteHost.scrollEnabled ? null : scrollStrip
        }

        Region {
            item: controller.inputSuspended || !root.satelliteSurfacesOpen ? null : satelliteDismissStrip
        }
    }

    IslandController {
        id: controller

        readonly property string interactionOverride: Quickshell.env("DMS_DANKISLAND_INTERACTION") ?? ""

        interactionMode: {
            const raw = interactionOverride || SettingsData.dankIslandInteractionMode;
            return raw === "click" ? "click" : "hybrid";
        }
        inputSuspended: PopoutManager.screenshotActive
        autoDemo: Quickshell.env("DMS_DANKISLAND_DEMO") === "1"
        horizontalOffset: Math.max(-root.maximumHorizontalOffset, Math.min(root.maximumHorizontalOffset, SettingsData.dankIslandHorizontalOffset))
        outerGap: root.outerGap
        compactHeight: root.compactHeight
        launcherCycleEnabled: SettingsData.launcherStyle === "island"
        controlCenterMaxHeight: root.maxActivityHeight
        notificationCenterMaxHeight: root.maxActivityHeight
        notificationExpandAllowed: SettingsData.dankIslandNotificationExpand
        unreadNotificationCount: NotificationService.notifications.length
        hoverOpenDelay: Math.max(0, Math.min(1000, SettingsData.dankIslandHoverOpenDelay))
        hoverCloseDelay: Math.max(0, Math.min(1000, SettingsData.dankIslandHoverCloseDelay))
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

    TransientSurfaceTracker {
        id: notificationTransientSurfaces
    }

    Connections {
        target: controller

        function onLauncherSessionActiveChanged() {
            if (!controller.launcherSessionActive)
                launcherTransientSurfaces.closeAll();
        }
    }

    DmsMediaActivitySource {
        id: mediaSource

        controller: controller
    }

    DmsSystemActivitySource {
        id: systemSource

        controller: controller
    }

    DmsNotificationActivitySource {
        id: notificationSource

        controller: controller
        targetScreen: root.screen
    }

    // Empty strip dismisses satellite popouts while something is open; click-through otherwise.
    // PopoutManager mutates the map in place, so this tracks popoutChanged instead.
    property int popoutRevision: 0
    readonly property bool satelliteSurfacesOpen: {
        root.popoutRevision;
        const screenName = root.screen?.name;
        if (!screenName)
            return false;
        return !!PopoutManager.currentPopoutsByScreen[screenName] || !!ModalManager.currentModalsByScreen[screenName];
    }

    function dismissSatelliteSurfaces() {
        const screenName = root.screen?.name;
        if (!screenName)
            return;
        if (PopoutManager.currentPopoutsByScreen[screenName])
            PopoutManager.closeAllPopouts();
        if (ModalManager.currentModalsByScreen[screenName])
            ModalManager.closeAllModalsExcept(null);
        TrayMenuManager.closeAllMenus();
    }

    MouseArea {
        id: satelliteDismissStrip

        x: 0
        y: root.stripY
        z: -2
        width: parent.width
        height: root.reservedStripHeight
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: false
        enabled: root.satelliteSurfacesOpen && !controller.inputSuspended
        onClicked: root.dismissSatelliteSurfaces()
    }

    MouseArea {
        id: scrollStrip

        x: 0
        y: root.stripY
        z: -1
        width: parent.width
        height: root.reservedStripHeight
        acceptedButtons: Qt.NoButton
        hoverEnabled: false
        enabled: satelliteHost.scrollEnabled && !controller.inputSuspended

        property real touchpadAccumulatorY: 0
        property real touchpadAccumulatorX: 0
        property real mouseAccumulatorY: 0
        property real mouseAccumulatorX: 0
        property bool actionInProgress: false

        Timer {
            id: cooldownTimer
            interval: 100
            onTriggered: scrollStrip.actionInProgress = false
        }

        function handleScrollAction(behavior, direction) {
            switch (behavior) {
            case "workspace":
                satelliteHost.switchWorkspace(direction);
                return true;
            case "column":
                if (!CompositorService.isNiri)
                    return false;
                if (direction > 0)
                    NiriService.moveColumnRight(root.screen?.name);
                else
                    NiriService.moveColumnLeft(root.screen?.name);
                return true;
            default:
                return false;
            }
        }

        function processWheel(wheel) {
            if (!satelliteHost.scrollEnabled || actionInProgress) {
                wheel.accepted = false;
                return;
            }

            const deltaY = wheel.angleDelta.y;
            const deltaX = wheel.angleDelta.x;
            const isTouchpadY = wheel.pixelDelta && wheel.pixelDelta.y !== 0;
            const isTouchpadX = wheel.pixelDelta && wheel.pixelDelta.x !== 0;
            const xBehavior = satelliteHost.scrollXBehavior || "column";
            const yBehavior = satelliteHost.scrollYBehavior || "workspace";
            const reverse = SettingsData.reverseScrolling ? -1 : 1;

            if (CompositorService.isNiri && xBehavior !== "none" && Math.abs(deltaX) > Math.abs(deltaY)) {
                if (isTouchpadX) {
                    touchpadAccumulatorX += deltaX;
                    if (Math.abs(touchpadAccumulatorX) >= 500) {
                        const direction = touchpadAccumulatorX * reverse < 0 ? 1 : -1;
                        if (handleScrollAction(xBehavior, direction)) {
                            actionInProgress = true;
                            cooldownTimer.restart();
                        }
                        touchpadAccumulatorX = 0;
                    }
                } else {
                    mouseAccumulatorX += deltaX;
                    if (Math.abs(mouseAccumulatorX) >= 120) {
                        const direction = mouseAccumulatorX * reverse < 0 ? 1 : -1;
                        if (handleScrollAction(xBehavior, direction)) {
                            actionInProgress = true;
                            cooldownTimer.restart();
                        }
                        mouseAccumulatorX = 0;
                    }
                }
                wheel.accepted = false;
                return;
            }

            if (yBehavior === "none") {
                wheel.accepted = false;
                return;
            }

            if (isTouchpadY) {
                touchpadAccumulatorY += deltaY;
                if (Math.abs(touchpadAccumulatorY) >= 500) {
                    const direction = touchpadAccumulatorY * reverse < 0 ? 1 : -1;
                    if (handleScrollAction(yBehavior, direction)) {
                        actionInProgress = true;
                        cooldownTimer.restart();
                    }
                    touchpadAccumulatorY = 0;
                }
            } else {
                mouseAccumulatorY += deltaY;
                if (Math.abs(mouseAccumulatorY) >= 120) {
                    const direction = mouseAccumulatorY * reverse < 0 ? 1 : -1;
                    if (handleScrollAction(yBehavior, direction)) {
                        actionInProgress = true;
                        cooldownTimer.restart();
                    }
                    mouseAccumulatorY = 0;
                }
            }

            wheel.accepted = false;
        }

        onWheel: wheel => processWheel(wheel)
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
        notificationTransientSurfaceTracker: notificationTransientSurfaces
        colorPickerModal: root.colorPickerModal
        powerMenuModalLoader: root.powerMenuModalLoader
        effectiveScreen: root.screen
        hostOriginY: root.hostOriginY
        reducedMotion: SettingsData.dankIslandReducedMotion || SettingsData.animationSpeed === SettingsData.AnimationSpeed.None
        springStiffness: Math.max(100, Math.min(1200, SettingsData.dankIslandSpringStiffness))
        springDamping: Math.max(10, Math.min(100, SettingsData.dankIslandSpringDamping))
        springMass: Math.max(0.25, Math.min(3, SettingsData.dankIslandSpringMass))
        palette: SettingsData.dankIslandPalette
        highContrast: SettingsData.dankIslandHighContrast
        onLockRequested: root.lockRequested()
        onScrollWheel: wheel => scrollStrip.processWheel(wheel)
    }

    IslandSatelliteHost {
        id: satelliteHost

        anchors.fill: parent
        hostWindow: root
        targetScreen: root.screen
        controller: controller
        islandSurface: surface
        outerGap: root.outerGap
    }

    FocusScope {
        id: islandFocus

        anchors.fill: parent
        Keys.onEscapePressed: event => {
            controller.requestCollapse();
            event.accepted = true;
        }
    }

    PanelWindow {
        id: dismissWindow

        screen: root.screen
        visible: controller.expanded && !PopoutManager.screenshotActive
        color: "transparent"
        exclusiveZone: -1

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.namespace: "dms:dankisland:dismiss"
        WlrLayershell.layer: root.islandLayer
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region {
            item: dismissMask

            Region {
                item: islandHole
                intersection: Intersection.Subtract
            }

            Region {
                item: leftSatelliteHole
                intersection: Intersection.Subtract
            }

            Region {
                item: rightSatelliteHole
                intersection: Intersection.Subtract
            }

            Region {
                item: mediaDropdownHole
                intersection: Intersection.Subtract
            }
        }

        Rectangle {
            id: dismissMask

            anchors.fill: parent
            visible: false
            color: "transparent"
        }

        Item {
            id: islandHole

            x: surface.inputMaskItem.x
            y: surface.inputMaskItem.y + root.hostOriginY
            width: surface.inputMaskItem.width
            height: surface.inputMaskItem.height
        }

        Item {
            id: leftSatelliteHole

            x: satelliteHost.leftInputItem.x
            y: satelliteHost.leftInputItem.y + root.hostOriginY
            width: satelliteHost.leftInputItem.width
            height: satelliteHost.leftInputItem.height
        }

        Item {
            id: rightSatelliteHole

            x: satelliteHost.rightInputItem.x
            y: satelliteHost.rightInputItem.y + root.hostOriginY
            width: satelliteHost.rightInputItem.width
            height: satelliteHost.rightInputItem.height
        }

        Item {
            id: mediaDropdownHole

            x: surface.mediaDropdownMaskItem ? surface.mediaDropdownMaskItem.x : 0
            y: surface.mediaDropdownMaskItem ? surface.mediaDropdownMaskItem.y + root.hostOriginY : 0
            width: surface.mediaDropdownMaskItem ? surface.mediaDropdownMaskItem.width : 0
            height: surface.mediaDropdownMaskItem ? surface.mediaDropdownMaskItem.height : 0
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            onPressed: mouse => {
                controller.requestCollapse();
                mouse.accepted = true;
            }

            onWheel: wheel => scrollStrip.processWheel(wheel)
        }
    }
}
