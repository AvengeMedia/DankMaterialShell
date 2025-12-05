import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

PanelWindow {
    id: barWindow

    required property var rootWindow
    required property var barConfig
    property var modelData: item
    property var hyprlandOverviewLoader: rootWindow ? rootWindow.hyprlandOverviewLoader : null

    property var leftWidgetsModel
    property var centerWidgetsModel
    property var rightWidgetsModel

    property var controlCenterButtonRef: null
    property var clockButtonRef: null

    function triggerControlCenter() {
        controlCenterLoader.active = true;
        if (!controlCenterLoader.item) {
            return;
        }

        if (controlCenterButtonRef && controlCenterLoader.item.setTriggerPosition) {
            const globalPos = controlCenterButtonRef.mapToGlobal(0, 0);
            // Calculate barPosition from axis.edge
            const barPosition = axis?.edge === "left" ? 2 : (axis?.edge === "right" ? 3 : (axis?.edge === "top" ? 0 : 1));
            const pos = SettingsData.getPopupTriggerPosition(globalPos, barWindow.screen, barWindow.effectiveBarThickness, controlCenterButtonRef.width, barConfig?.spacing ?? 4, barPosition, barConfig);
            const section = controlCenterButtonRef.section || "right";
            controlCenterLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, section, barWindow.screen, barPosition, barWindow.effectiveBarThickness, barConfig?.spacing ?? 4, barConfig);
        } else {
            controlCenterLoader.item.triggerScreen = barWindow.screen;
        }

        controlCenterLoader.item.toggle();
        if (controlCenterLoader.item.shouldBeVisible && NetworkService.wifiEnabled) {
            NetworkService.scanWifi();
        }
    }

    function triggerWallpaperBrowser() {
        dankDashPopoutLoader.active = true;
        if (!dankDashPopoutLoader.item) {
            return;
        }

        if (clockButtonRef && clockButtonRef.visualContent && dankDashPopoutLoader.item.setTriggerPosition) {
            // Calculate barPosition from axis.edge
            const barPosition = axis?.edge === "left" ? 2 : (axis?.edge === "right" ? 3 : (axis?.edge === "top" ? 0 : 1));
            const section = clockButtonRef.section || "center";

            // For center section widgets, use center section bounds for DankDash centering
            let triggerPos, triggerWidth;
            if (section === "center") {
                const centerSection = barWindow.isVertical ? (barWindow.axis?.edge === "left" ? topBarContent.vCenterSection : topBarContent.vCenterSection) : topBarContent.hCenterSection;
                if (centerSection) {
                    // For vertical bars, use center Y of section; for horizontal, use left edge
                    if (barWindow.isVertical) {
                        const centerY = centerSection.height / 2;
                        const centerGlobalPos = centerSection.mapToGlobal(0, centerY);
                        triggerPos = centerGlobalPos;
                        triggerWidth = centerSection.height;
                    } else {
                        // For horizontal bars, use left edge (DankPopout will center it)
                        const centerGlobalPos = centerSection.mapToGlobal(0, 0);
                        triggerPos = centerGlobalPos;
                        triggerWidth = centerSection.width;
                    }
                } else {
                    triggerPos = clockButtonRef.visualContent.mapToGlobal(0, 0);
                    triggerWidth = clockButtonRef.visualWidth;
                }
            } else {
                triggerPos = clockButtonRef.visualContent.mapToGlobal(0, 0);
                triggerWidth = clockButtonRef.visualWidth;
            }

            const pos = SettingsData.getPopupTriggerPosition(triggerPos, barWindow.screen, barWindow.effectiveBarThickness, triggerWidth, barConfig?.spacing ?? 4, barPosition, barConfig);
            dankDashPopoutLoader.item.setTriggerPosition(pos.x, pos.y, pos.width, section, barWindow.screen, barPosition, barWindow.effectiveBarThickness, barConfig?.spacing ?? 4, barConfig);
        } else {
            dankDashPopoutLoader.item.triggerScreen = barWindow.screen;
        }

        PopoutManager.requestPopout(dankDashPopoutLoader.item, 2, (barConfig?.id ?? "default") + "-2");
    }

    readonly property var dBarLayer: {
        switch (Quickshell.env("DMS_DANKBAR_LAYER")) {
        case "bottom":
            return WlrLayer.Bottom;
        case "overlay":
            return WlrLayer.Overlay;
        case "background":
            return WlrLayer.background;
        default:
            return WlrLayer.Top;
        }
    }

    WlrLayershell.layer: {
        if ((barConfig?.autoHide ?? false) && topBarCore.reveal) {
            return WlrLayer.Overlay;
        }
        return dBarLayer;
    }
    WlrLayershell.namespace: "dms:bar"

    signal colorPickerRequested

    onColorPickerRequested: rootWindow.colorPickerRequested()

    property alias axis: axis

    AxisContext {
        id: axis
        edge: {
            switch (barConfig?.position ?? 0) {
            case SettingsData.Position.Top:
                return "top";
            case SettingsData.Position.Bottom:
                return "bottom";
            case SettingsData.Position.Left:
                return "left";
            case SettingsData.Position.Right:
                return "right";
            default:
                return "top";
            }
        }
    }

    readonly property bool isVertical: axis.isVertical

    property bool gothCornersEnabled: barConfig?.gothCornersEnabled ?? false
    property real wingtipsRadius: barConfig?.gothCornerRadiusOverride ? (barConfig?.gothCornerRadiusValue ?? 12) : Theme.cornerRadius
    readonly property real _wingR: Math.max(0, wingtipsRadius)
    readonly property color _surfaceContainer: Theme.surfaceContainer
    readonly property string _barId: barConfig?.id ?? "default"
    readonly property var _liveBarConfig: SettingsData.barConfigs.find(c => c.id === _barId) || barConfig
    readonly property real _backgroundAlpha: _liveBarConfig?.transparency ?? 1.0
    readonly property color _bgColor: Theme.withAlpha(_surfaceContainer, _backgroundAlpha)
    readonly property real _dpr: CompositorService.getScreenScale(barWindow.screen)

    property string screenName: modelData.name

    readonly property bool hasMaximizedToplevel: {
        if (!(barConfig?.maximizeDetection ?? true))
            return false;
        if (!CompositorService.isHyprland && !CompositorService.isNiri)
            return false;

        const filtered = CompositorService.filterCurrentWorkspace(CompositorService.sortedToplevels, screenName);
        for (let i = 0; i < filtered.length; i++) {
            if (filtered[i]?.maximized)
                return true;
        }
        return false;
    }

    property real effectiveSpacing: hasMaximizedToplevel ? 0 : (barConfig?.spacing ?? 4)

    Behavior on effectiveSpacing {
        enabled: barWindow.visible
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Easing.OutCubic
        }
    }

    readonly property int notificationCount: NotificationService.notifications.length
    readonly property real effectiveBarThickness: Math.max(barWindow.widgetThickness + (barConfig?.innerPadding ?? 4) + 4, Theme.barHeight - 4 - (8 - (barConfig?.innerPadding ?? 4)))
    readonly property real widgetThickness: Math.max(20, 26 + (barConfig?.innerPadding ?? 4) * 0.6)

    readonly property bool hasAdjacentTopBar: {
        if (barConfig?.autoHide ?? false)
            return false;
        if (!isVertical)
            return false;
        return SettingsData.barConfigs.some(bc => {
            if (!bc.enabled || bc.id === barConfig?.id)
                return false;
            if (bc.autoHide)
                return false;
            if (!(bc.visible ?? true))
                return false;
            if (bc.position !== SettingsData.Position.Top && bc.position !== 0)
                return false;
            const onThisScreen = bc.screenPreferences.includes(screenName) || bc.screenPreferences.length === 0 || bc.screenPreferences.includes("all");
            if (!onThisScreen)
                return false;
            if (bc.showOnLastDisplay && screenName !== barWindow.screen.name)
                return false;
            return true;
        });
    }

    readonly property bool hasAdjacentBottomBar: {
        if (barConfig?.autoHide ?? false)
            return false;
        if (!isVertical)
            return false;
        const result = SettingsData.barConfigs.some(bc => {
            if (!bc.enabled || bc.id === barConfig?.id)
                return false;
            if (bc.autoHide)
                return false;
            if (!(bc.visible ?? true))
                return false;
            if (bc.position !== SettingsData.Position.Bottom && bc.position !== 1)
                return false;
            const onThisScreen = bc.screenPreferences.includes(screenName) || bc.screenPreferences.length === 0 || bc.screenPreferences.includes("all");
            if (!onThisScreen)
                return false;
            if (bc.showOnLastDisplay && screenName !== barWindow.screen.name)
                return false;
            return true;
        });
        return result;
    }

    readonly property bool hasAdjacentLeftBar: {
        if (barConfig?.autoHide ?? false)
            return false;
        if (isVertical)
            return false;
        const result = SettingsData.barConfigs.some(bc => {
            if (!bc.enabled || bc.id === barConfig?.id)
                return false;
            if (bc.autoHide)
                return false;
            if (!(bc.visible ?? true))
                return false;
            if (bc.position !== SettingsData.Position.Left && bc.position !== 2)
                return false;
            const onThisScreen = bc.screenPreferences.includes(screenName) || bc.screenPreferences.length === 0 || bc.screenPreferences.includes("all");
            if (!onThisScreen)
                return false;
            if (bc.showOnLastDisplay && screenName !== barWindow.screen.name)
                return false;
            return true;
        });
        return result;
    }

    readonly property bool hasAdjacentRightBar: {
        if (barConfig?.autoHide ?? false)
            return false;
        if (isVertical)
            return false;
        const result = SettingsData.barConfigs.some(bc => {
            if (!bc.enabled || bc.id === barConfig?.id)
                return false;
            if (bc.autoHide)
                return false;
            if (!(bc.visible ?? true))
                return false;
            if (bc.position !== SettingsData.Position.Right && bc.position !== 3)
                return false;
            const onThisScreen = bc.screenPreferences.includes(screenName) || bc.screenPreferences.length === 0 || bc.screenPreferences.includes("all");
            if (!onThisScreen)
                return false;
            if (bc.showOnLastDisplay && screenName !== barWindow.screen.name)
                return false;
            return true;
        });
        return result;
    }

    screen: modelData
    implicitHeight: !isVertical ? Theme.px(effectiveBarThickness + effectiveSpacing + ((barConfig?.gothCornersEnabled ?? false) && !hasMaximizedToplevel ? _wingR : 0), _dpr) : 0
    implicitWidth: isVertical ? Theme.px(effectiveBarThickness + effectiveSpacing + ((barConfig?.gothCornersEnabled ?? false) && !hasMaximizedToplevel ? _wingR : 0), _dpr) : 0
    color: "transparent"

    property var nativeInhibitor: null

    Component.onCompleted: {
        if (SettingsData.forceStatusBarLayoutRefresh) {
            SettingsData.forceStatusBarLayoutRefresh.connect(() => {
                Qt.callLater(() => {
                    stackContainer.visible = false;
                    Qt.callLater(() => {
                        stackContainer.visible = true;
                    });
                });
            });
        }

        updateGpuTempConfig();

        inhibitorInitTimer.start();
    }

    Timer {
        id: inhibitorInitTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (SessionService.nativeInhibitorAvailable) {
                createNativeInhibitor();
            }
        }
    }

    Connections {
        target: PluginService
        function onPluginLoaded(pluginId) {
            console.info("DankBar: Plugin loaded:", pluginId);
            SettingsData.widgetDataChanged();
        }
        function onPluginUnloaded(pluginId) {
            console.info("DankBar: Plugin unloaded:", pluginId);
            SettingsData.widgetDataChanged();
        }
    }

    function updateGpuTempConfig() {
        const leftWidgets = barConfig?.leftWidgets || [];
        const centerWidgets = barConfig?.centerWidgets || [];
        const rightWidgets = barConfig?.rightWidgets || [];
        const allWidgets = [...leftWidgets, ...centerWidgets, ...rightWidgets];

        const hasGpuTempWidget = allWidgets.some(widget => {
            const widgetId = typeof widget === "string" ? widget : widget.id;
            const widgetEnabled = typeof widget === "string" ? true : (widget.enabled !== false);
            return widgetId === "gpuTemp" && widgetEnabled;
        });

        DgopService.gpuTempEnabled = hasGpuTempWidget || SessionData.nvidiaGpuTempEnabled || SessionData.nonNvidiaGpuTempEnabled;
        DgopService.nvidiaGpuTempEnabled = hasGpuTempWidget || SessionData.nvidiaGpuTempEnabled;
        DgopService.nonNvidiaGpuTempEnabled = hasGpuTempWidget || SessionData.nonNvidiaGpuTempEnabled;
    }

    function createNativeInhibitor() {
        if (!SessionService.nativeInhibitorAvailable) {
            return;
        }

        try {
            const qmlString = `
            import QtQuick
            import Quickshell.Wayland

            IdleInhibitor {
            enabled: false
            }
            `;

            nativeInhibitor = Qt.createQmlObject(qmlString, barWindow, "DankBar.NativeInhibitor");
            nativeInhibitor.window = barWindow;
            nativeInhibitor.enabled = Qt.binding(() => SessionService.idleInhibited);
            nativeInhibitor.enabledChanged.connect(function () {
                if (SessionService.idleInhibited !== nativeInhibitor.enabled) {
                    SessionService.idleInhibited = nativeInhibitor.enabled;
                    SessionService.inhibitorChanged();
                }
            });
        } catch (e) {
            nativeInhibitor = null;
        }
    }

    Connections {
        function onBarConfigChanged() {
            barWindow.updateGpuTempConfig();
        }

        target: rootWindow
    }

    Connections {
        function onNvidiaGpuTempEnabledChanged() {
            barWindow.updateGpuTempConfig();
        }

        function onNonNvidiaGpuTempEnabledChanged() {
            barWindow.updateGpuTempConfig();
        }

        target: SessionData
    }

    readonly property int barPos: barConfig?.position ?? 0

    anchors.top: !isVertical ? (barPos === SettingsData.Position.Top) : true
    anchors.bottom: !isVertical ? (barPos === SettingsData.Position.Bottom) : true
    anchors.left: !isVertical ? true : (barPos === SettingsData.Position.Left)
    anchors.right: !isVertical ? true : (barPos === SettingsData.Position.Right)

    exclusiveZone: (!(barConfig?.visible ?? true) || topBarCore.autoHide) ? -1 : (barWindow.effectiveBarThickness + effectiveSpacing + (barConfig?.bottomGap ?? 0))

    Item {
        id: inputMask

        readonly property int barThickness: Theme.px(barWindow.effectiveBarThickness + barWindow.effectiveSpacing, barWindow._dpr)

        readonly property bool inOverviewWithShow: CompositorService.isNiri && NiriService.inOverview && (barConfig?.openOnOverview ?? false)
        readonly property bool effectiveVisible: (barConfig?.visible ?? true) || inOverviewWithShow
        readonly property bool showing: effectiveVisible && (topBarCore.reveal || inOverviewWithShow || !topBarCore.autoHide)

        readonly property int maskThickness: showing ? barThickness : 1

        x: {
            if (!axis.isVertical) {
                return 0;
            } else {
                switch (barPos) {
                case SettingsData.Position.Left:
                    return 0;
                case SettingsData.Position.Right:
                    return parent.width - maskThickness;
                default:
                    return 0;
                }
            }
        }
        y: {
            if (axis.isVertical) {
                return 0;
            } else {
                switch (barPos) {
                case SettingsData.Position.Top:
                    return 0;
                case SettingsData.Position.Bottom:
                    return parent.height - maskThickness;
                default:
                    return 0;
                }
            }
        }
        width: axis.isVertical ? maskThickness : parent.width
        height: axis.isVertical ? parent.height : maskThickness
    }

    mask: Region {
        item: inputMask
    }

    Item {
        id: topBarCore
        anchors.fill: parent
        layer.enabled: true

        property bool autoHide: barConfig?.autoHide ?? false
        property bool revealSticky: false

        Timer {
            id: revealHold
            interval: barConfig?.autoHideDelay ?? 250
            repeat: false
            onTriggered: {
                if (!topBarMouseArea.containsMouse && !topBarCore.hasActivePopout) {
                    topBarCore.revealSticky = false;
                }
            }
        }

        property bool reveal: {
            if (CompositorService.isNiri && NiriService.inOverview) {
                return (barConfig?.openOnOverview ?? false) || topBarMouseArea.containsMouse || hasActivePopout || revealSticky;
            }
            return (barConfig?.visible ?? true) && (!autoHide || topBarMouseArea.containsMouse || hasActivePopout || revealSticky);
        }

        property bool hasActivePopout: false

        onHasActivePopoutChanged: evaluateReveal()

        function updateActivePopoutState() {
            const screenName = barWindow.screen.name;
            const activePopout = PopoutManager.currentPopoutsByScreen[screenName];
            const activeTrayMenu = TrayMenuManager.activeTrayMenus[screenName];
            const trayOpen = rootWindow.systemTrayMenuOpen;

            const hasVisiblePopout = activePopout && activePopout.shouldBeVisible;
            topBarCore.hasActivePopout = !!(hasVisiblePopout || activeTrayMenu || trayOpen);
        }

        Connections {
            target: PopoutManager
            function onPopoutChanged() {
                topBarCore.updateActivePopoutState();
            }
        }

        Connections {
            target: TrayMenuManager
            function onActiveTrayMenusChanged() {
                topBarCore.updateActivePopoutState();
            }
        }

        Connections {
            function onBarConfigChanged() {
                topBarCore.autoHide = barConfig?.autoHide ?? false;
                revealHold.interval = barConfig?.autoHideDelay ?? 250;
            }

            target: rootWindow
        }

        function evaluateReveal() {
            if (!autoHide)
                return;

            if (topBarMouseArea.containsMouse || hasActivePopout) {
                revealSticky = true;
                revealHold.stop();
                return;
            }

            revealHold.restart();
        }

        Connections {
            target: topBarMouseArea
            function onContainsMouseChanged() {
                topBarCore.evaluateReveal();
            }
        }

        Connections {
            target: PopoutManager
            function onPopoutOpening() {
                topBarCore.evaluateReveal();
            }
        }

        MouseArea {
            id: topBarMouseArea
            y: !barWindow.isVertical ? (barPos === SettingsData.Position.Bottom ? parent.height - height : 0) : 0
            x: barWindow.isVertical ? (barPos === SettingsData.Position.Right ? parent.width - width : 0) : 0
            height: !barWindow.isVertical ? Theme.px(barWindow.effectiveBarThickness + barWindow.effectiveSpacing, barWindow._dpr) : undefined
            width: barWindow.isVertical ? Theme.px(barWindow.effectiveBarThickness + barWindow.effectiveSpacing, barWindow._dpr) : undefined
            anchors {
                left: !barWindow.isVertical ? parent.left : (barPos === SettingsData.Position.Left ? parent.left : undefined)
                right: !barWindow.isVertical ? parent.right : (barPos === SettingsData.Position.Right ? parent.right : undefined)
                top: barWindow.isVertical ? parent.top : undefined
                bottom: barWindow.isVertical ? parent.bottom : undefined
            }
            readonly property bool inOverview: CompositorService.isNiri && NiriService.inOverview && (barConfig?.openOnOverview ?? false)
            hoverEnabled: (barConfig?.autoHide ?? false) && !inOverview && !topBarCore.hasActivePopout
            acceptedButtons: Qt.NoButton
            enabled: (barConfig?.autoHide ?? false) && !inOverview

            Item {
                id: topBarContainer
                anchors.fill: parent

                transform: Translate {
                    id: topBarSlide
                    x: barWindow.isVertical ? Theme.snap(topBarCore.reveal ? 0 : (barPos === SettingsData.Position.Right ? barWindow.implicitWidth : -barWindow.implicitWidth), barWindow._dpr) : 0
                    y: !barWindow.isVertical ? Theme.snap(topBarCore.reveal ? 0 : (barPos === SettingsData.Position.Bottom ? barWindow.implicitHeight : -barWindow.implicitHeight), barWindow._dpr) : 0

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on y {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Item {
                    id: barUnitInset
                    property int spacingPx: Theme.px(barWindow.effectiveSpacing, barWindow._dpr)
                    anchors.fill: parent
                    anchors.leftMargin: !barWindow.isVertical ? spacingPx : (axis.edge === "left" ? spacingPx : 0)
                    anchors.rightMargin: !barWindow.isVertical ? spacingPx : (axis.edge === "right" ? spacingPx : 0)
                    anchors.topMargin: barWindow.isVertical ? (barWindow.hasAdjacentTopBar ? 0 : spacingPx) : (axis.outerVisualEdge() === "bottom" ? 0 : spacingPx)
                    anchors.bottomMargin: barWindow.isVertical ? (barWindow.hasAdjacentBottomBar ? 0 : spacingPx) : (axis.outerVisualEdge() === "bottom" ? spacingPx : 0)

                    BarCanvas {
                        id: barBackground
                        barWindow: barWindow
                        axis: axis
                        barConfig: barWindow.barConfig
                    }

                    MouseArea {
                        id: scrollArea
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        propagateComposedEvents: true
                        z: -1

                        property real scrollAccumulator: 0
                        property real touchpadThreshold: 500
                        property bool actionInProgress: false

                        Timer {
                            id: cooldownTimer
                            interval: 100
                            onTriggered: parent.actionInProgress = false
                        }

                        onWheel: wheel => {
                            if (actionInProgress) {
                                wheel.accepted = false;
                                return;
                            }

                            const deltaY = wheel.angleDelta.y;
                            const deltaX = wheel.angleDelta.x;

                            if (CompositorService.isNiri && Math.abs(deltaX) > Math.abs(deltaY)) {
                                topBarContent.switchApp(deltaX);
                                wheel.accepted = false;
                                return;
                            }

                            const isMouseWheel = Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0;
                            const direction = deltaY < 0 ? 1 : -1;

                            if (isMouseWheel) {
                                topBarContent.switchWorkspace(direction);
                                actionInProgress = true;
                                cooldownTimer.restart();
                            } else {
                                scrollAccumulator += deltaY;

                                if (Math.abs(scrollAccumulator) >= touchpadThreshold) {
                                    const touchDirection = scrollAccumulator < 0 ? 1 : -1;
                                    topBarContent.switchWorkspace(touchDirection);
                                    scrollAccumulator = 0;
                                    actionInProgress = true;
                                    cooldownTimer.restart();
                                }
                            }

                            wheel.accepted = false;
                        }
                    }

                    DankBarContent {
                        id: topBarContent
                        barWindow: barWindow
                        rootWindow: barWindow.rootWindow
                        barConfig: barWindow.barConfig
                        leftWidgetsModel: barWindow.leftWidgetsModel
                        centerWidgetsModel: barWindow.centerWidgetsModel
                        rightWidgetsModel: barWindow.rightWidgetsModel
                    }
                }
            }
        }
    }
}
