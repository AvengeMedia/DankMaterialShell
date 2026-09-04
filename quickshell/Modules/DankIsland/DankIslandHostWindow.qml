pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Modals.DankLauncherV2 as DankLauncher
import qs.Modules.DankBar
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
        const items = [surface.inputMaskItem, surface.fittsStripItem, satelliteHost.leadingInputItem, satelliteHost.trailingInputItem];
        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            if (!item || item.width <= 0 || item.height <= 0)
                continue;
            const topLeft = item.mapToItem(null, 0, 0);
            if (!topLeft)
                continue;
            // mapToItem(null) is window-local; callers pass screen-space cursor coords.
            const left = topLeft.x + root.hostOriginX;
            const top = topLeft.y + root.hostOriginY;
            if (gx >= left - pad && gx < left + item.width + pad && gy >= top - pad && gy < top + item.height + pad)
                return true;
        }
        return false;
    }

    required property string barId
    readonly property var barConfig: {
        SettingsData.barConfigs;
        return SettingsData.getBarConfig(root.barId);
    }

    function setting(key) {
        return SettingsData.islandSetting(root.barConfig, key);
    }

    readonly property int reserveThickness: Math.max(24, Math.min(128, root.setting("islandReserveThickness")))
    readonly property int compactThickness: Math.max(24, Math.min(72, root.setting("islandCompactThickness")))
    readonly property bool floating: root.setting("islandFloating")
    readonly property bool usesOverlayLayer: LayerShell.envUsesOverlay("DMS_DANKISLAND_LAYER", root.setting("islandUseOverlayLayer"))
    readonly property var islandLayer: LayerShell.fromEnv("DMS_DANKISLAND_LAYER", usesOverlayLayer ? WlrLayer.Overlay : WlrLayer.Top)
    readonly property string edge: SettingsData.islandEdge(root.barConfig)
    readonly property bool isVertical: SettingsData.islandVertical(root.barConfig)
    readonly property bool farEdge: root.edge === "bottom" || root.edge === "right"
    readonly property int reservedStripThickness: Math.max(reserveThickness, outerGap + compactThickness)
    readonly property int stripPos: root.farEdge ? (root.isVertical ? root.width : root.height) - root.reservedStripThickness : 0
    readonly property int hostOriginX: root.isVertical && root.farEdge ? Math.max(0, (root.screen?.width ?? 0) - root.width) : 0
    readonly property int hostOriginY: !root.isVertical && root.farEdge ? Math.max(0, (root.screen?.height ?? 0) - root.height) : 0
    readonly property int outerGap: Math.max(0, Math.min(48, root.setting("islandOuterGap")))
    readonly property int maxActivityHeight: Math.max(560, Math.min(680, (screen?.height ?? 1080) - 200))
    readonly property int maxActivityWidth: Math.min(736, Math.max(320, (screen?.width ?? 1920) - 200))
    readonly property int hostThickness: outerGap + (root.isVertical ? maxActivityWidth : maxActivityHeight) + 8
    readonly property real maximumAlongOffset: root.isVertical ? Math.max(0, (height - maxActivityHeight) / 2 - 8) : Math.max(0, (width - maxActivityWidth) / 2 - 8)
    property bool keyboardFocusArmed: true

    color: "transparent"
    implicitHeight: hostThickness
    implicitWidth: hostThickness
    exclusiveZone: floating ? 0 : reservedStripThickness
    readonly property alias islandController: controller
    readonly property int launcherResultCount: launcherController.flatModel?.length ?? 0

    anchors {
        top: root.isVertical || root.edge === "top"
        bottom: root.isVertical || root.edge === "bottom"
        left: !root.isVertical || root.edge === "left"
        right: !root.isVertical || root.edge === "right"
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
            item: controller.inputSuspended ? null : surface.fittsStripItem
        }

        Region {
            item: controller.inputSuspended ? null : satelliteHost.leadingInputItem
        }

        Region {
            item: controller.inputSuspended ? null : satelliteHost.trailingInputItem
        }

        Region {
            item: controller.inputSuspended || !satelliteHost.scrollEnabled || root.floating ? null : scrollStrip
        }

        Region {
            item: controller.inputSuspended || !root.satelliteSurfacesOpen ? null : satelliteDismissStrip
        }
    }

    IslandController {
        id: controller

        barConfig: root.barConfig
        edge: root.edge
        interactionMode: root.setting("islandInteractionMode") === "click" ? "click" : "hybrid"
        inputSuspended: PopoutManager.screenshotActive
        alongOffset: Math.max(-root.maximumAlongOffset, Math.min(root.maximumAlongOffset, root.setting("islandAlongOffset")))
        outerGap: root.outerGap
        compactThickness: root.compactThickness
        cornerRadius: Math.max(0, Math.min(64, root.setting("islandCornerRadius")))
        homeCompactTight: root.setting("islandHomeCompactTight")
        homeClockDisplay: SettingsData.islandClockDisplay(root.barConfig)
        homeVolumeDisplay: SettingsData.islandLevelDisplay(root.barConfig, "islandHomeVolumeDisplay")
        homeBrightnessDisplay: SettingsData.islandLevelDisplay(root.barConfig, "islandHomeBrightnessDisplay")
        batteryStyle: root.setting("islandBatteryStyle")
        mediaClockVisible: root.setting("islandMediaClockVisible")
        launcherCycleEnabled: SettingsData.launcherStyle === "island"
        controlCenterMaxHeight: root.maxActivityHeight
        notificationCenterMaxHeight: root.maxActivityHeight
        notificationExpandAllowed: root.setting("islandNotificationExpand")
        unreadNotificationCount: root.setting("islandNotificationBadgeClearOnOpen") ? NotificationService.unreadCount : NotificationService.notifications.length
        hoverOpenDelay: Math.max(0, Math.min(1000, root.setting("islandHoverOpenDelay")))
        hoverCloseDelay: Math.max(0, Math.min(1000, root.setting("islandHoverCloseDelay")))
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
    }

    // PopoutManager mutates the map in place, so this tracks popoutChanged instead.
    property int popoutRevision: 0
    readonly property bool satelliteSurfacesOpen: {
        root.popoutRevision;
        const screenName = root.screen?.name;
        if (!screenName)
            return false;
        return !!PopoutManager.currentPopoutsByScreen[screenName] || !!ModalManager.currentModalsByScreen[screenName];
    }

    MouseArea {
        id: satelliteDismissStrip

        x: root.isVertical ? root.stripPos : 0
        y: root.isVertical ? 0 : root.stripPos
        z: -2
        width: root.isVertical ? root.reservedStripThickness : parent.width
        height: root.isVertical ? parent.height : root.reservedStripThickness
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: false
        enabled: root.satelliteSurfacesOpen && !controller.inputSuspended
        onClicked: PopoutManager.dismissAllForScreen(root.screen?.name)
    }

    BarScrollArea {
        id: scrollStrip

        x: root.isVertical ? root.stripPos : 0
        y: root.isVertical ? 0 : root.stripPos
        z: -1
        width: root.isVertical ? root.reservedStripThickness : parent.width
        height: root.isVertical ? parent.height : root.reservedStripThickness
        hoverEnabled: false
        enabled: satelliteHost.scrollEnabled && !controller.inputSuspended
        scrollEnabled: satelliteHost.scrollEnabled
        xBehavior: satelliteHost.scrollXBehavior
        yBehavior: satelliteHost.scrollYBehavior
        screenName: root.screen?.name ?? ""
        onWorkspaceSwitchRequested: direction => satelliteHost.switchWorkspace(direction)
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
        effectiveScreen: root.screen
        hostOriginX: root.hostOriginX
        hostOriginY: root.hostOriginY
        reducedMotion: root.setting("islandReducedMotion") || SettingsData.reduceMotion || SettingsData.animationSpeed === SettingsData.AnimationSpeed.None
        springStiffness: Math.max(100, Math.min(1200, root.setting("islandSpringStiffness")))
        springDamping: Math.max(10, Math.min(100, root.setting("islandSpringDamping")))
        springMass: Math.max(0.25, Math.min(3, root.setting("islandSpringMass")))
        palette: root.setting("islandPalette")
        highContrast: root.setting("islandHighContrast")
        transparency: root.setting("islandTransparency")
        onScrollWheel: wheel => scrollStrip.processWheel(wheel)
    }

    IslandSatelliteHost {
        id: satelliteHost

        anchors.fill: parent
        hostWindow: root
        targetScreen: root.screen
        barConfig: root.barConfig
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
                item: fittsStripHole
                intersection: Intersection.Subtract
            }

            Region {
                item: leadingSatelliteHole
                intersection: Intersection.Subtract
            }

            Region {
                item: trailingSatelliteHole
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

            x: surface.inputMaskItem.x + root.hostOriginX
            y: surface.inputMaskItem.y + root.hostOriginY
            width: surface.inputMaskItem.width
            height: surface.inputMaskItem.height
        }

        Item {
            id: fittsStripHole

            x: surface.fittsStripItem.x + root.hostOriginX
            y: surface.fittsStripItem.y + root.hostOriginY
            width: surface.fittsStripItem.visible ? surface.fittsStripItem.width : 0
            height: surface.fittsStripItem.visible ? surface.fittsStripItem.height : 0
        }

        Item {
            id: leadingSatelliteHole

            x: satelliteHost.leadingInputItem.x + root.hostOriginX
            y: satelliteHost.leadingInputItem.y + root.hostOriginY
            width: satelliteHost.leadingInputItem.width
            height: satelliteHost.leadingInputItem.height
        }

        Item {
            id: trailingSatelliteHole

            x: satelliteHost.trailingInputItem.x + root.hostOriginX
            y: satelliteHost.trailingInputItem.y + root.hostOriginY
            width: satelliteHost.trailingInputItem.width
            height: satelliteHost.trailingInputItem.height
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
