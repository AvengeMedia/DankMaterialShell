import QtQuick
import Quickshell
import qs.Common
import qs.Services

Item {
    id: barWindow
    readonly property var log: Log.scoped("DankBarBody")

    required property var hostWindow
    required property var rootWindow
    required property var barConfig
    required property var modelData
    readonly property var screen: modelData
    property var hyprlandOverviewLoader: rootWindow ? rootWindow.hyprlandOverviewLoader : null

    property var leftWidgetsModel
    property var centerWidgetsModel
    property var rightWidgetsModel

    readonly property bool barRevealed: inputMask.showing

    property var controlCenterButtonRef: null
    property var clockButtonRef: null
    property var systemUpdateButtonRef: null

    function triggerSystemUpdate() {
        const loader = PopoutService.systemUpdateLoader;
        if (!loader)
            return;
        loader.active = true;
        if (!loader.item)
            return;
        const popout = loader.item;
        const barPosition = axis?.edge === "left" ? 2 : (axis?.edge === "right" ? 3 : (axis?.edge === "top" ? 0 : 1));
        if (systemUpdateButtonRef && popout.setTriggerPosition) {
            const screenPos = systemUpdateButtonRef.mapToItem(null, 0, 0);
            const pos = SettingsData.getPopupTriggerPosition(screenPos, barWindow.screen, barWindow.effectiveBarThickness, systemUpdateButtonRef.width, barConfig?.spacing ?? 4, barPosition, barConfig);
            const section = systemUpdateButtonRef.section || "right";
            popout.setTriggerPosition(pos.x, pos.y, pos.width, section, barWindow.screen, barPosition, barWindow.effectiveBarThickness, barConfig?.spacing ?? 4, barConfig);
        } else {
            popout.screen = barWindow.screen;
        }
        PopoutManager.requestPopout(popout, undefined, "systemUpdate");
    }

    function triggerControlCenter() {
        const loader = PopoutService.controlCenterLoader;
        if (!loader)
            return;
        loader.active = true;
        if (!loader.item) {
            return;
        }

        if (controlCenterButtonRef && loader.item.setTriggerPosition) {
            const screenPos = controlCenterButtonRef.mapToItem(null, 0, 0);
            const barPosition = axis?.edge === "left" ? 2 : (axis?.edge === "right" ? 3 : (axis?.edge === "top" ? 0 : 1));
            const pos = SettingsData.getPopupTriggerPosition(screenPos, barWindow.screen, barWindow.effectiveBarThickness, controlCenterButtonRef.width, barConfig?.spacing ?? 4, barPosition, barConfig);
            const section = controlCenterButtonRef.section || "right";
            loader.item.setTriggerPosition(pos.x, pos.y, pos.width, section, barWindow.screen, barPosition, barWindow.effectiveBarThickness, barConfig?.spacing ?? 4, barConfig);
        } else {
            loader.item.triggerScreen = barWindow.screen;
        }

        loader.item.toggle();
        if (loader.item.shouldBeVisible && NetworkService.wifiEnabled) {
            NetworkService.scanWifi();
        }
    }

    function dashSectionAnchor(section) {
        let item;
        switch (section) {
        case "left":
            item = barWindow.isVertical ? topBarContent.vLeftSection : topBarContent.hLeftSection;
            break;
        case "right":
            item = barWindow.isVertical ? topBarContent.vRightSection : topBarContent.hRightSection;
            break;
        default:
            item = barWindow.isVertical ? topBarContent.vCenterSection : topBarContent.hCenterSection;
        }
        if (!item)
            return null;
        if (barWindow.isVertical)
            return {
                "pos": item.mapToItem(null, 0, item.height / 2),
                "width": item.height
            };
        return {
            "pos": item.mapToItem(null, 0, 0),
            "width": item.width
        };
    }

    function positionDash(popout, position) {
        if (!popout.setTriggerPosition) {
            popout.triggerScreen = barWindow.screen;
            return "center";
        }

        const explicit = position === "left" || position === "center" || position === "right";
        const section = explicit ? position : (clockButtonRef?.section || "center");
        const clockAnchor = clockButtonRef?.visualContent ? {
            "pos": clockButtonRef.visualContent.mapToItem(null, 0, 0),
            "width": clockButtonRef.visualWidth
        } : null;

        let anchor;
        if (!explicit && section !== "center" && clockAnchor)
            anchor = clockAnchor;
        else
            anchor = dashSectionAnchor(section) || clockAnchor;

        if (!anchor) {
            popout.triggerScreen = barWindow.screen;
            return section;
        }

        const barPosition = axis?.edge === "left" ? 2 : (axis?.edge === "right" ? 3 : (axis?.edge === "top" ? 0 : 1));
        const pos = SettingsData.getPopupTriggerPosition(anchor.pos, barWindow.screen, barWindow.effectiveBarThickness, anchor.width, barConfig?.spacing ?? 4, barPosition, barConfig);
        popout.setTriggerPosition(pos.x, pos.y, pos.width, section, barWindow.screen, barPosition, barWindow.effectiveBarThickness, barConfig?.spacing ?? 4, barConfig);
        return section;
    }

    function triggerDashTab(tabId, position) {
        const loader = PopoutService.dankDashPopoutLoader;
        if (!loader)
            return false;
        loader.active = true;
        if (!loader.item) {
            return false;
        }

        const section = positionDash(loader.item, position);
        if (loader.item.requestTab)
            loader.item.requestTab(tabId);
        PopoutManager.requestPopout(loader.item, undefined, (barConfig?.id ?? "default") + "-" + section + "-" + tabId);
        return true;
    }

    function triggerWallpaperBrowser() {
        triggerDashTab("wallpaper");
    }

    property var blurRegion: null
    property var _blurWidgetItems: []

    function registerBlurWidget(item) {
        if (_blurWidgetItems.indexOf(item) >= 0)
            return;
        _blurWidgetItems = _blurWidgetItems.concat([item]);
        _blurRebuildTimer.restart();
    }

    function unregisterBlurWidget(item) {
        const idx = _blurWidgetItems.indexOf(item);
        if (idx < 0)
            return;
        const arr = _blurWidgetItems.slice();
        arr.splice(idx, 1);
        _blurWidgetItems = arr;
        _blurRebuildTimer.restart();
    }

    Timer {
        id: _blurRebuildTimer
        interval: 1
        onTriggered: barBlur.rebuild()
    }

    Connections {
        target: barWindow
        function onUsesConnectedFrameChromeChanged() {
            _blurRebuildTimer.restart();
        }
        function onUsesFrameBarChromeChanged() {
            // Rebuild immediately so the bar region never overlaps FrameWindow's during chrome handoff
            barBlur.rebuild();
        }
        function onBarRevealedChanged() {
            barBlur.rebuild();
        }
    }

    Component {
        id: blurRegionComp
        Region {}
    }

    Component {
        id: blurSubRegionComp
        Region {
            property Item w
            item: w
            radius: Theme.cornerRadius
        }
    }

    Component {
        id: blurWingRegionComp

        // r×r square at a bar end minus a quarter-disc — the swoop BarCanvas paints
        Region {
            id: wingRegion

            property bool atEnd: false

            readonly property real r: barBackground.wing
            readonly property real bx: topBarMouseArea.x + barUnitInset.x + topBarSlide.x
            readonly property real by: topBarMouseArea.y + barUnitInset.y + topBarSlide.y
            readonly property real bw: barUnitInset.width
            readonly property real bh: barUnitInset.height

            x: {
                switch (barPos) {
                case SettingsData.Position.Left:
                    return bx + bw;
                case SettingsData.Position.Right:
                    return bx - r;
                default:
                    return atEnd ? bx + bw - r : bx;
                }
            }
            y: {
                switch (barPos) {
                case SettingsData.Position.Top:
                    return by + bh;
                case SettingsData.Position.Bottom:
                    return by - r;
                default:
                    return atEnd ? by + bh - r : by;
                }
            }
            width: r
            height: r

            Region {
                intersection: Intersection.Subtract
                radius: wingRegion.r
                width: wingRegion.r * 2
                height: wingRegion.r * 2
                x: {
                    switch (barPos) {
                    case SettingsData.Position.Left:
                        return wingRegion.bx + wingRegion.bw;
                    case SettingsData.Position.Right:
                        return wingRegion.bx - wingRegion.r * 2;
                    default:
                        return wingRegion.atEnd ? wingRegion.bx + wingRegion.bw - wingRegion.r * 2 : wingRegion.bx;
                    }
                }
                y: {
                    switch (barPos) {
                    case SettingsData.Position.Top:
                        return wingRegion.by + wingRegion.bh;
                    case SettingsData.Position.Bottom:
                        return wingRegion.by - wingRegion.r * 2;
                    default:
                        return wingRegion.atEnd ? wingRegion.by + wingRegion.bh - wingRegion.r * 2 : wingRegion.by;
                    }
                }
            }
        }
    }

    Component {
        id: blurCornerRegionComp

        // BarCanvas paints square corners at the attached edge and the wing roots (#2975); re-add what the body radius rounds off
        Region {
            id: cornerRegion

            property bool atRight: false
            property bool atBottom: false

            readonly property real r: barBackground.rt
            readonly property bool attachedEdgeCorner: (barBackground.isTop && !atBottom) || (barBackground.isBottom && atBottom) || (barBackground.isLeft && !atRight) || (barBackground.isRight && atRight)
            readonly property bool wingEdgeCorner: (barBackground.isTop && atBottom) || (barBackground.isBottom && !atBottom) || (barBackground.isLeft && atRight) || (barBackground.isRight && !atRight)
            readonly property bool squared: (barBackground.edgeAttached && attachedEdgeCorner) || (barBackground.gothEnabled && wingEdgeCorner)

            x: topBarMouseArea.x + barUnitInset.x + topBarSlide.x + (atRight ? barUnitInset.width - r : 0)
            y: topBarMouseArea.y + barUnitInset.y + topBarSlide.y + (atBottom ? barUnitInset.height - r : 0)
            width: squared ? r : 0
            height: squared ? r : 0
        }
    }

    Item {
        id: barBlur
        visible: false

        readonly property bool barHasTransparency: barWindow._backgroundAlpha > 0 && barWindow._backgroundAlpha < 1

        function rebuild() {
            teardown();
            if (!BlurService.enabled || !BlurService.available)
                return;
            if (!barWindow.barRevealed && CompositorService.isHyprland)
                return;
            // FrameWindow owns the blur region for the whole edge while the bar wears frame chrome
            if (FrameTransitionState.effectiveFrameEnabled && barWindow.usesFrameBarChrome)
                return;

            const widgets = barWindow._blurWidgetItems.filter(w => w && w.visible && w.width > 0 && w.height > 0);
            const hasBar = barHasTransparency;
            if (!hasBar && widgets.length === 0)
                return;

            const region = blurRegionComp.createObject(barWindow);
            if (!region) {
                log.warn("BarBlur: Failed to create blur region");
                return;
            }

            if (hasBar) {
                region.x = Qt.binding(() => topBarMouseArea.x + barUnitInset.x + topBarSlide.x);
                region.y = Qt.binding(() => topBarMouseArea.y + barUnitInset.y + topBarSlide.y);
                region.width = Qt.binding(() => barUnitInset.width);
                region.height = Qt.binding(() => barUnitInset.height);
                region.radius = Qt.binding(() => barBackground.rt);
            }

            const subRegions = [];
            for (let i = 0; i < widgets.length; i++) {
                const sub = blurSubRegionComp.createObject(region, {
                    w: widgets[i]
                });
                if (sub)
                    subRegions.push(sub);
            }

            if (hasBar && barBackground.gothEnabled && barWindow._wingR > 0) {
                for (const atEnd of [false, true]) {
                    const wing = blurWingRegionComp.createObject(region, {
                        atEnd: atEnd
                    });
                    if (wing)
                        subRegions.push(wing);
                }
            }

            if (hasBar) {
                for (const atRight of [false, true]) {
                    for (const atBottom of [false, true]) {
                        const corner = blurCornerRegionComp.createObject(region, {
                            atRight: atRight,
                            atBottom: atBottom
                        });
                        if (corner)
                            subRegions.push(corner);
                    }
                }
            }

            region.regions = subRegions;

            barWindow.blurRegion = region;
        }

        function teardown() {
            const old = barWindow.blurRegion;
            if (!old)
                return;
            barWindow.blurRegion = null;
            old.destroy();
        }

        onBarHasTransparencyChanged: _blurRebuildTimer.restart()

        Connections {
            target: BlurService
            function onEnabledChanged() {
                barBlur.rebuild();
            }
        }

        Connections {
            target: FrameTransitionState
            function onEffectiveFrameEnabledChanged() {
                barBlur.rebuild();
            }
        }

        Connections {
            target: topBarSlide
            function onXChanged() {
                if (barWindow.blurRegion)
                    barWindow.blurRegion.changed();
            }
            function onYChanged() {
                if (barWindow.blurRegion)
                    barWindow.blurRegion.changed();
            }
        }

        Connections {
            target: barBackground
            function onGothEnabledChanged() {
                _blurRebuildTimer.restart();
            }
            function onWingChanged() {
                if (barWindow.blurRegion)
                    barWindow.blurRegion.changed();
            }
        }

        Component.onCompleted: rebuild()
        Component.onDestruction: teardown()
    }

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

    readonly property color _surfaceContainer: Theme.surfaceContainer
    readonly property string _barId: barConfig?.id ?? "default"
    property real _backgroundAlpha: barConfig?.transparency ?? 1.0
    readonly property color _bgColor: (FrameTransitionState.effectiveFrameEnabled && usesFrameBarChrome) ? Theme.withAlpha(SettingsData.effectiveFrameColor, SettingsData.frameOpacity) : Theme.withAlpha(_surfaceContainer, _backgroundAlpha)

    function _updateBackgroundAlpha() {
        const live = SettingsData.barConfigs.find(c => c.id === _barId);
        _backgroundAlpha = (live ?? barConfig)?.transparency ?? 1.0;
    }
    readonly property real _dpr: CompositorService.getScreenScale(barWindow.screen)

    property string screenName: modelData.name

    readonly property bool usesConnectedFrameChrome: CompositorService.usesConnectedFrameChromeForScreen(screenName)
    readonly property bool usesFrameBarChrome: CompositorService.frameWindowVisibleForScreen(screenName)
    readonly property var renderBarConfig: SettingsData.effectiveBarConfigForRender(barConfig, usesFrameBarChrome)

    property bool gothCornersEnabled: renderBarConfig?.gothCornersEnabled ?? false
    property real wingtipsRadius: renderBarConfig?.gothCornerRadiusOverride ? (renderBarConfig?.gothCornerRadiusValue ?? 12) : Theme.cornerRadius
    readonly property real _wingR: Math.max(0, wingtipsRadius)

    // Shadow buffer: extra window space for shadow to render beyond bar bounds
    readonly property bool _shadowActive: Theme.elevationEnabled && (typeof SettingsData !== "undefined" ? (SettingsData.barElevationEnabled ?? true) : false)
    readonly property real _shadowBuffer: {
        if (!_shadowActive)
            return 0;
        const hasOverride = (renderBarConfig?.shadowIntensity ?? 0) > 0;
        if (hasOverride) {
            const blur = (renderBarConfig.shadowIntensity ?? 0) * 0.2;
            const offset = blur * 0.5;
            return Theme.snap(Math.max(16, blur + offset + 8), _dpr);
        }
        return Theme.snap(Theme.elevationRenderPadding(Theme.elevationLevel2, "top", 4, 8, 16), _dpr);
    }

    // Flatten/spacing collapse for maximized windows only applies to frame-integrated layout
    readonly property bool flattenForMaximizedWindow: !FrameTransitionState.effectiveFrameEnabled || usesFrameBarChrome

    property bool hasMaximizedToplevel: false
    property bool shouldHideForWindows: false

    function _updateHasMaximizedToplevel() {
        if (!(barConfig?.maximizeDetection ?? true)) {
            hasMaximizedToplevel = false;
            return;
        }
        if (CompositorService.isMango) {
            const out = MangoService.outputs[screenName];
            const active = new Set((out?.activeTags) || []);
            const wins = MangoService.windows || [];
            for (let i = 0; i < wins.length; i++) {
                const w = wins[i];
                if (!w || w.monitor !== screenName || w.is_minimized)
                    continue;
                if (active.size > 0 && !(w.tags || []).some(t => active.has(t)))
                    continue;
                if (w.is_maximized || w.is_fullscreen) {
                    hasMaximizedToplevel = true;
                    return;
                }
            }
            hasMaximizedToplevel = false;
            return;
        }
        if (!CompositorService.isHyprland && !CompositorService.isNiri) {
            hasMaximizedToplevel = false;
            return;
        }

        const filtered = CompositorService.filterCurrentWorkspace(CompositorService.sortedToplevels, screenName);
        for (let i = 0; i < filtered.length; i++) {
            if (filtered[i]?.maximized) {
                hasMaximizedToplevel = true;
                return;
            }
        }
        hasMaximizedToplevel = false;
    }

    function _updateShouldHideForWindows() {
        if (!(barConfig?.showOnWindowsOpen ?? false)) {
            shouldHideForWindows = false;
            return;
        }
        if (!(barConfig?.autoHide ?? false)) {
            shouldHideForWindows = false;
            return;
        }
        if (!CompositorService.isNiri && !CompositorService.isHyprland && !CompositorService.isMango) {
            shouldHideForWindows = false;
            return;
        }

        if (CompositorService.isNiri) {
            let currentWorkspaceId = null;
            for (let i = 0; i < NiriService.allWorkspaces.length; i++) {
                const ws = NiriService.allWorkspaces[i];
                if (ws.output === screenName && ws.is_active) {
                    currentWorkspaceId = ws.id;
                    break;
                }
            }

            if (currentWorkspaceId === null) {
                shouldHideForWindows = false;
                return;
            }

            let hasTiled = false;
            let hasFloatingTouchingBar = false;
            const pos = barConfig?.position ?? 0;
            const barThickness = barWindow.effectiveBarThickness + (barConfig?.spacing ?? 4);

            for (let i = 0; i < NiriService.windows.length; i++) {
                const win = NiriService.windows[i];
                if (win.workspace_id !== currentWorkspaceId)
                    continue;

                if (!win.is_floating) {
                    hasTiled = true;
                    continue;
                }

                const tilePos = win.layout?.tile_pos_in_workspace_view;
                const winSize = win.layout?.window_size || win.layout?.tile_size;
                if (!tilePos || !winSize)
                    continue;

                switch (pos) {
                case SettingsData.Position.Top:
                    if (tilePos[1] < barThickness)
                        hasFloatingTouchingBar = true;
                    break;
                case SettingsData.Position.Bottom:
                    const screenHeight = barWindow.screen?.height ?? 0;
                    if (tilePos[1] + winSize[1] > screenHeight - barThickness)
                        hasFloatingTouchingBar = true;
                    break;
                case SettingsData.Position.Left:
                    if (tilePos[0] < barThickness)
                        hasFloatingTouchingBar = true;
                    break;
                case SettingsData.Position.Right:
                    const screenWidth = barWindow.screen?.width ?? 0;
                    if (tilePos[0] + winSize[0] > screenWidth - barThickness)
                        hasFloatingTouchingBar = true;
                    break;
                }
            }

            shouldHideForWindows = hasTiled || hasFloatingTouchingBar;
            return;
        }

        const filtered = CompositorService.filterCurrentWorkspace(CompositorService.sortedToplevels, screenName);
        shouldHideForWindows = filtered.length > 0;
    }

    readonly property bool edgeAttached: (barConfig?.attachToScreenEdge ?? false) && !(FrameTransitionState.effectiveFrameEnabled && usesFrameBarChrome)
    property real effectiveSpacing: (FrameTransitionState.effectiveFrameEnabled && usesFrameBarChrome) ? 0 : ((edgeAttached || (flattenForMaximizedWindow && hasMaximizedToplevel)) ? 0 : (barConfig?.spacing ?? 4))

    Behavior on effectiveSpacing {
        enabled: barWindow.hostWindow?.visible ?? false
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Easing.OutCubic
        }
    }

    readonly property int notificationCount: NotificationService.notifications.length
    readonly property real effectiveBarThickness: (FrameTransitionState.effectiveFrameEnabled && usesFrameBarChrome) ? SettingsData.frameBarSize : Theme.barThickness(barConfig?.innerPadding ?? 4, _dpr)
    readonly property real effectiveBarLengthPadding: {
        if ((FrameTransitionState.effectiveFrameEnabled && usesFrameBarChrome) || (flattenForMaximizedWindow && hasMaximizedToplevel))
            return 0;
        const pad = Math.max(0, barConfig?.barLengthPadding ?? 0);
        const length = isVertical ? height : width;
        return length > 0 ? Math.min(pad, Math.max(0, length / 2 - effectiveSpacing)) : pad;
    }
    readonly property bool effectiveOpenOnOverview: (FrameTransitionState.effectiveFrameEnabled && usesFrameBarChrome) ? SettingsData.frameShowOnOverview : (barConfig?.openOnOverview ?? false)
    readonly property real widgetThickness: Theme.barWidgetThickness(barConfig?.innerPadding ?? 4, _dpr)

    readonly property bool hasAdjacentTopBar: {
        if (barConfig?.autoHide ?? false)
            return false;
        if (!isVertical)
            return false;
        return SettingsData.barConfigs.some(bc => {
            if (!bc.enabled || bc.id === barConfig?.id)
                return false;
            if (SettingsData.isIslandBarConfig(bc))
                return false;
            if (bc.autoHide)
                return false;
            if (!(bc.visible ?? true))
                return false;
            if (bc.position !== SettingsData.Position.Top && bc.position !== 0)
                return false;
            return SettingsData.barConfigCoversScreen(bc, barWindow.screen);
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
            if (SettingsData.isIslandBarConfig(bc))
                return false;
            if (bc.autoHide)
                return false;
            if (!(bc.visible ?? true))
                return false;
            if (bc.position !== SettingsData.Position.Bottom && bc.position !== 1)
                return false;
            return SettingsData.barConfigCoversScreen(bc, barWindow.screen);
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
            if (SettingsData.isIslandBarConfig(bc))
                return false;
            if (bc.autoHide)
                return false;
            if (!(bc.visible ?? true))
                return false;
            if (bc.position !== SettingsData.Position.Left && bc.position !== 2)
                return false;
            return SettingsData.barConfigCoversScreen(bc, barWindow.screen);
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
            if (SettingsData.isIslandBarConfig(bc))
                return false;
            if (bc.autoHide)
                return false;
            if (!(bc.visible ?? true))
                return false;
            if (bc.position !== SettingsData.Position.Right && bc.position !== 3)
                return false;
            return SettingsData.barConfigCoversScreen(bc, barWindow.screen);
        });
        return result;
    }

    readonly property real surfaceImplicitHeight: !isVertical ? Theme.px(effectiveBarThickness + effectiveSpacing + ((renderBarConfig?.gothCornersEnabled ?? false) && !hasMaximizedToplevel ? _wingR : 0), _dpr) + _shadowBuffer : 0
    readonly property real surfaceImplicitWidth: isVertical ? Theme.px(effectiveBarThickness + effectiveSpacing + ((renderBarConfig?.gothCornersEnabled ?? false) && !hasMaximizedToplevel ? _wingR : 0), _dpr) + _shadowBuffer : 0

    Component.onCompleted: {
        updateGpuTempConfig();
        _updateBackgroundAlpha();
        _updateHasMaximizedToplevel();
        _updateShouldHideForWindows();
    }

    Connections {
        target: PluginService
        function onPluginLoaded(pluginId) {
            log.info("DankBar: Plugin loaded:", pluginId);
            SettingsData.widgetDataChanged();
        }
        function onPluginUnloaded(pluginId) {
            log.info("DankBar: Plugin unloaded:", pluginId);
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

    Connections {
        function onBarConfigChanged() {
            barWindow.updateGpuTempConfig();
            barWindow._updateBackgroundAlpha();
            barWindow._updateHasMaximizedToplevel();
            barWindow._updateShouldHideForWindows();
        }

        target: rootWindow
    }

    Connections {
        target: SettingsData
        function onBarConfigsChanged() {
            barWindow._updateBackgroundAlpha();
        }
    }

    Connections {
        target: CompositorService
        function onToplevelsChanged() {
            barWindow._updateHasMaximizedToplevel();
            barWindow._updateShouldHideForWindows();
        }
    }

    Connections {
        target: NiriService
        function onAllWorkspacesChanged() {
            barWindow._updateHasMaximizedToplevel();
            barWindow._updateShouldHideForWindows();
        }
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

    readonly property bool reserveExclusiveWhenAutoHidden: FrameTransitionState.effectiveFrameEnabled && usesFrameBarChrome && !!barWindow.screen && SettingsData.isScreenInPreferences(barWindow.screen, SettingsData.frameScreenPreferences)

    readonly property real surfaceExclusiveZone: (!(barConfig?.visible ?? true) || (topBarCore.autoHide && !barWindow.reserveExclusiveWhenAutoHidden)) ? -1 : (barWindow.effectiveBarThickness + effectiveSpacing + (usesFrameBarChrome ? 0 : (barConfig?.bottomGap ?? 0)))

    readonly property alias inputMaskItem: inputMask

    Item {
        id: inputMask

        readonly property int barThickness: Theme.px(barWindow.effectiveBarThickness + barWindow.effectiveSpacing, barWindow._dpr)
        readonly property int lengthPaddingPx: Theme.px(barWindow.effectiveBarLengthPadding, barWindow._dpr)

        readonly property bool inOverviewWithShow: CompositorService.isNiri && NiriService.inOverview && barWindow.effectiveOpenOnOverview
        readonly property bool effectiveVisible: (barConfig?.visible ?? true) || inOverviewWithShow
        readonly property bool showing: effectiveVisible && (topBarCore.reveal || inOverviewWithShow)

        readonly property int maskThickness: showing ? barThickness : 1

        x: {
            if (!axis.isVertical) {
                return lengthPaddingPx;
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
                return lengthPaddingPx;
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
        width: axis.isVertical ? maskThickness : parent.width - lengthPaddingPx * 2
        height: axis.isVertical ? parent.height - lengthPaddingPx * 2 : maskThickness
    }

    readonly property bool clickThroughEnabled: barConfig?.clickThrough ?? false

    readonly property var _leftSection: topBarContent ? (barWindow.isVertical ? topBarContent.vLeftSection : topBarContent.hLeftSection) : null
    readonly property var _centerSection: topBarContent ? (barWindow.isVertical ? topBarContent.vCenterSection : topBarContent.hCenterSection) : null
    readonly property var _rightSection: topBarContent ? (barWindow.isVertical ? topBarContent.vRightSection : topBarContent.hRightSection) : null
    readonly property real _revealProgress: topBarSlide.x + topBarSlide.y

    function containsGlobalPoint(gx, gy, padding) {
        const pad = padding !== undefined ? padding : 16;
        if (!inputMask.showing)
            return false;
        const topLeft = inputMask.mapToItem(null, 0, 0);
        return gx >= topLeft.x - pad && gx < topLeft.x + inputMask.width + pad && gy >= topLeft.y - pad && gy < topLeft.y + inputMask.height + pad;
    }

    function sectionRect(section, isCenter, _dep) {
        if (!section)
            return {
                "x": 0,
                "y": 0,
                "w": 0,
                "h": 0
            };

        const pos = section.mapToItem(barWindow.hostWindow.contentItem, 0, 0);
        const implW = section.implicitWidth || 0;
        const implH = section.implicitHeight || 0;
        const contentSize = isCenter ? (section.contentSize || 0) : 0;

        let offsetX = isCenter && !barWindow.isVertical ? (section.width - implW) / 2 : 0;
        let offsetY = !barWindow.isVertical ? (section.height - implH) / 2 : (isCenter ? (section.height - implH) / 2 : 0);
        let w = implW;
        let h = implH;

        // index centering lays content out asymmetrically; use the real extent
        if (contentSize > 0) {
            if (barWindow.isVertical) {
                offsetY = section.contentStart;
                h = contentSize;
            } else {
                offsetX = section.contentStart;
                w = contentSize;
            }
        }

        const edgePad = 2;
        return {
            "x": pos.x + offsetX - edgePad,
            "y": pos.y + offsetY - edgePad,
            "w": w + edgePad * 2,
            "h": h + edgePad * 2
        };
    }

    Item {
        id: topBarCore
        anchors.fill: parent
        layer.enabled: false

        property bool autoHide: barConfig?.autoHide ?? false
        property bool revealSticky: false
        // In click-through mode the hidden bar's input mask covers the full
        // band while the revealed bar's mask covers only the widget sections,
        // so the pointer position is unknowable while it is over a gap. An
        // enter on the hidden bar therefore only reveals once the pointer
        // reaches a thin strip at the screen edge; anything else (including
        // the spurious enter generated by the mask expanding underneath a
        // resting pointer) keeps the bar hidden.
        property bool gapEnterSuppressed: false
        readonly property bool hoverReveal: topBarMouseArea.containsMouse && !gapEnterSuppressed
        readonly property bool ipcReveal: !!SettingsData.barIpcRevealStates[barConfig?.id ?? ""]

        onRevealChanged: {
            if (reveal && barWindow.clickThroughEnabled)
                revealSettle.restart();
        }

        // The input mask updates lag reveal transitions, generating spurious
        // enter/leave pairs. Hides are deferred until the transition settles;
        // the timer re-evaluates against the post-transition mask.
        Timer {
            id: revealSettle
            interval: 600
            repeat: false
            onTriggered: topBarCore.evaluateReveal()
        }

        function inEdgeStrip(x, y) {
            const band = barWindow.isVertical ? topBarMouseArea.width : topBarMouseArea.height;
            const strip = Math.max(8, band * 0.15);
            switch (barPos) {
            case SettingsData.Position.Bottom:
                return y >= band - strip;
            case SettingsData.Position.Left:
                return x <= strip;
            case SettingsData.Position.Right:
                return x >= band - strip;
            default:
                return y <= strip;
            }
        }

        Timer {
            id: revealHold
            interval: barConfig?.autoHideDelay ?? 250
            repeat: false
            onTriggered: {
                if (!topBarCore.hoverReveal && !topBarCore.popoutPinsReveal)
                    topBarCore.revealSticky = false;
            }
        }

        property bool hasActivePopout: false

        readonly property bool popoutPinsReveal: !!(hasActivePopout && !(barConfig?.autoHideStrict ?? false))

        onHasActivePopoutChanged: evaluateReveal()

        onPopoutPinsRevealChanged: evaluateReveal()

        function updateActivePopoutState() {
            if (!barWindow.screen)
                return;
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

            function onPopoutOpening() {
                topBarCore.evaluateReveal();
            }
        }

        Connections {
            target: TrayMenuManager

            function onActiveTrayMenusChanged() {
                topBarCore.updateActivePopoutState();
            }
        }

        property bool reveal: {
            const inOverviewWithShow = CompositorService.isNiri && NiriService.inOverview && barWindow.effectiveOpenOnOverview;
            if (inOverviewWithShow)
                return true;

            const showOnWindowsSetting = barConfig?.showOnWindowsOpen ?? false;
            if (showOnWindowsSetting && autoHide && (CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango)) {
                if (barWindow.shouldHideForWindows)
                    return hoverReveal || popoutPinsReveal || revealSticky || ipcReveal;
                return true;
            }

            if (CompositorService.isNiri && NiriService.inOverview)
                return hoverReveal || popoutPinsReveal || revealSticky || ipcReveal;

            return (barConfig?.visible ?? true) && (!autoHide || hoverReveal || popoutPinsReveal || revealSticky || ipcReveal);
        }

        Connections {
            function onBarConfigChanged() {
                topBarCore.autoHide = barConfig?.autoHide ?? false;
                topBarCore.evaluateReveal();
            }

            target: rootWindow
        }

        Component.onCompleted: topBarCore.updateActivePopoutState()

        function evaluateReveal() {
            if (!autoHide)
                return;

            if (hoverReveal) {
                SettingsData.setBarIpcReveal(barConfig?.id ?? "", false);
                revealSticky = true;
                revealHold.stop();
                return;
            }

            if (popoutPinsReveal) {
                revealSticky = true;
                revealHold.stop();
                return;
            }

            if (revealSettle.running)
                return;

            revealHold.interval = barConfig?.autoHideDelay ?? 250;
            revealHold.restart();
        }

        Connections {
            target: topBarMouseArea
            function onContainsMouseChanged() {
                if (!topBarMouseArea.containsMouse) {
                    topBarCore.gapEnterSuppressed = false;
                } else if (barWindow.clickThroughEnabled && !topBarCore.reveal) {
                    topBarCore.gapEnterSuppressed = true;
                }
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
            readonly property bool inOverview: CompositorService.isNiri && NiriService.inOverview && barWindow.effectiveOpenOnOverview
            hoverEnabled: (barConfig?.autoHide ?? false) && !inOverview && !topBarCore.popoutPinsReveal
            acceptedButtons: barWindow.clickThroughEnabled ? Qt.NoButton : Qt.RightButton
            enabled: !inOverview && ((barConfig?.autoHide ?? false) || !barWindow.clickThroughEnabled)
            onPositionChanged: mouse => {
                if (!topBarCore.gapEnterSuppressed)
                    return;
                if (!topBarCore.inEdgeStrip(mouse.x, mouse.y))
                    return;
                topBarCore.gapEnterSuppressed = false;
                topBarCore.evaluateReveal();
            }

            Item {
                id: topBarContainer
                anchors.fill: parent

                transform: Translate {
                    id: topBarSlide
                    x: barWindow.isVertical ? Theme.snap(topBarCore.reveal ? 0 : (barPos === SettingsData.Position.Right ? barWindow.surfaceImplicitWidth : -barWindow.surfaceImplicitWidth), barWindow._dpr) : 0
                    y: !barWindow.isVertical ? Theme.snap(topBarCore.reveal ? 0 : (barPos === SettingsData.Position.Bottom ? barWindow.surfaceImplicitHeight : -barWindow.surfaceImplicitHeight), barWindow._dpr) : 0

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
                    property int lengthPaddingPx: Theme.px(barWindow.effectiveBarLengthPadding, barWindow._dpr)
                    anchors.fill: parent
                    anchors.leftMargin: !barWindow.isVertical ? spacingPx + lengthPaddingPx : (axis.edge === "left" ? spacingPx : 0)
                    anchors.rightMargin: !barWindow.isVertical ? spacingPx + lengthPaddingPx : (axis.edge === "right" ? spacingPx : 0)
                    anchors.topMargin: barWindow.isVertical ? (barWindow.hasAdjacentTopBar ? 0 : spacingPx) + lengthPaddingPx : (axis.outerVisualEdge() === "bottom" ? 0 : spacingPx)
                    anchors.bottomMargin: barWindow.isVertical ? (barWindow.hasAdjacentBottomBar ? 0 : spacingPx) + lengthPaddingPx : (axis.outerVisualEdge() === "bottom" ? spacingPx : 0)

                    BarCanvas {
                        id: barBackground
                        barWindow: barWindow
                        axis: axis
                        barConfig: barWindow.renderBarConfig
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: -2
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: PopoutManager.dismissAllForScreen(barWindow.screen?.name)
                    }

                    BarScrollArea {
                        id: scrollArea
                        anchors.fill: parent
                        propagateComposedEvents: true
                        z: -1
                        scrollEnabled: barConfig?.scrollEnabled ?? true
                        xBehavior: barConfig?.scrollXBehavior ?? "column"
                        yBehavior: barConfig?.scrollYBehavior ?? "workspace"
                        screenName: barWindow.screenName
                        onWorkspaceSwitchRequested: direction => topBarContent.switchWorkspace(direction)
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

                    // Passive: tracks cursor without intercepting clicks or scroll
                    HoverHandler {
                        id: hoverPopoutHandler
                        enabled: (barConfig?.hoverPopouts ?? false) && !barWindow.clickThroughEnabled

                        property real lastGlobalX: 0
                        property real lastGlobalY: 0

                        onPointChanged: {
                            const gp = barUnitInset.mapToItem(null, point.position.x, point.position.y);
                            lastGlobalX = gp.x;
                            lastGlobalY = gp.y;
                            topBarContent.queueHoverPopout(gp.x, gp.y);
                        }

                        onHoveredChanged: {
                            topBarContent.updateHoverBarHovered(hovered);
                        }
                    }
                }
            }
        }
    }
}
