import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

Item {
    id: root
    readonly property var log: Log.scoped("DankPopout")

    property string layerNamespace: "dms:popout"
    property alias content: contentLoader.sourceComponent
    property alias contentLoader: contentLoader
    property Component overlayContent: null
    property alias overlayLoader: overlayLoader
    readonly property alias backgroundWindow: backgroundWindow
    property real popupWidth: 400
    property real popupHeight: 300
    property real triggerX: 0
    property real triggerY: 0
    property real triggerWidth: 40
    property string triggerSection: ""
    property string positioning: "center"
    property int animationDuration: Theme.popoutAnimationDuration
    property real animationScaleCollapsed: Theme.effectScaleCollapsed
    property real animationOffset: Theme.effectAnimOffset
    property list<real> animationEnterCurve: Theme.variantPopoutEnterCurve
    property list<real> animationExitCurve: Theme.variantPopoutExitCurve
    property bool suspendShadowWhileResizing: false
    property bool shouldBeVisible: false
    property var customKeyboardFocus: null
    property bool backgroundInteractive: true
    property bool contentHandlesKeys: false
    property bool fullHeightSurface: false
    property bool _primeContent: false
    property bool _resizeActive: false
    property string _chromeClaimId: ""
    property int _connectedChromeSerial: 0
    property real _chromeAnimTravelX: 1
    property real _chromeAnimTravelY: 1

    property real storedBarThickness: Theme.barHeight - 4
    property real storedBarSpacing: 4
    property var storedBarConfig: null
    property var adjacentBarInfo: ({
            "topBar": 0,
            "bottomBar": 0,
            "leftBar": 0,
            "rightBar": 0
        })
    property var screen: null
    // Connected resize uses one full-screen surface; body-sized regions are masks.
    readonly property bool useBackgroundWindow: false

    readonly property real effectiveBarThickness: {
        if (Theme.isConnectedEffect)
            return Math.max(0, storedBarThickness);
        const padding = storedBarConfig ? (storedBarConfig.innerPadding !== undefined ? storedBarConfig.innerPadding : 4) : 4;
        return Math.max(26 + padding * 0.6, Theme.barHeight - 4 - (8 - padding)) + storedBarSpacing;
    }

    readonly property var barBounds: {
        if (!screen)
            return {
                "x": 0,
                "y": 0,
                "width": 0,
                "height": 0,
                "wingSize": 0
            };
        return SettingsData.getBarBounds(screen, effectiveBarThickness, effectiveBarPosition, storedBarConfig);
    }

    readonly property real barX: barBounds.x
    readonly property real barY: barBounds.y
    readonly property real barWidth: barBounds.width
    readonly property real barHeight: barBounds.height
    readonly property real barWingSize: barBounds.wingSize
    readonly property bool effectiveSurfaceBlurEnabled: Theme.connectedSurfaceBlurEnabled

    signal opened
    signal popoutClosed
    signal backgroundClicked

    property var _lastOpenedScreen: null
    property bool isClosing: false

    property int effectiveBarPosition: 0
    property real effectiveBarBottomGap: 0
    readonly property string autoBarShadowDirection: {
        const section = triggerSection || "center";
        switch (effectiveBarPosition) {
        case SettingsData.Position.Top:
            if (section === "left")
                return "topLeft";
            if (section === "right")
                return "topRight";
            return "top";
        case SettingsData.Position.Bottom:
            if (section === "left")
                return "bottomLeft";
            if (section === "right")
                return "bottomRight";
            return "bottom";
        case SettingsData.Position.Left:
            if (section === "left")
                return "topLeft";
            if (section === "right")
                return "bottomLeft";
            return "left";
        case SettingsData.Position.Right:
            if (section === "left")
                return "topRight";
            if (section === "right")
                return "bottomRight";
            return "right";
        default:
            return "top";
        }
    }
    readonly property string effectiveShadowDirection: Theme.elevationLightDirection === "autoBar" ? autoBarShadowDirection : Theme.elevationLightDirection

    function setBarContext(position, bottomGap) {
        effectiveBarPosition = position !== undefined ? position : 0;
        effectiveBarBottomGap = bottomGap !== undefined ? bottomGap : 0;
    }

    function primeContent() {
        _primeContent = true;
    }

    function clearPrimedContent() {
        _primeContent = false;
    }

    function setTriggerPosition(x, y, width, section, targetScreen, barPosition, barThickness, barSpacing, barConfig) {
        triggerX = x;
        triggerY = y;
        triggerWidth = width;
        triggerSection = section;
        screen = targetScreen;

        storedBarThickness = barThickness !== undefined ? barThickness : (Theme.barHeight - 4);
        storedBarSpacing = barSpacing !== undefined ? barSpacing : 4;
        storedBarConfig = barConfig;

        const pos = barPosition !== undefined ? barPosition : 0;
        const bottomGap = barConfig ? (barConfig.bottomGap !== undefined ? barConfig.bottomGap : 0) : 0;

        adjacentBarInfo = SettingsData.getAdjacentBarInfo(targetScreen, pos, barConfig);
        setBarContext(pos, bottomGap);
    }

    function _nextChromeClaimId() {
        _connectedChromeSerial += 1;
        return layerNamespace + ":" + _connectedChromeSerial + ":" + (new Date()).getTime();
    }

    function _captureChromeAnimTravel() {
        _chromeAnimTravelX = Math.max(1, Math.abs(contentContainer.offsetX));
        _chromeAnimTravelY = Math.max(1, Math.abs(contentContainer.offsetY));
    }

    function _connectedChromeAnimX() {
        const barSide = contentContainer.connectedBarSide;
        if (barSide !== "left" && barSide !== "right")
            return contentContainer.animX;

        const extent = Math.max(0, root.alignedWidth);
        const progress = Math.min(1, Math.abs(contentContainer.animX) / Math.max(1, _chromeAnimTravelX));
        const offset = Theme.snap(extent * progress, root.dpr);
        return contentContainer.animX < 0 ? -offset : offset;
    }

    function _connectedChromeAnimY() {
        const barSide = contentContainer.connectedBarSide;
        if (barSide !== "top" && barSide !== "bottom")
            return contentContainer.animY;

        const extent = Math.max(0, root.renderedAlignedHeight);
        const progress = Math.min(1, Math.abs(contentContainer.animY) / Math.max(1, _chromeAnimTravelY));
        const offset = Theme.snap(extent * progress, root.dpr);
        return contentContainer.animY < 0 ? -offset : offset;
    }

    function _connectedChromeState(visibleOverride) {
        const visible = visibleOverride !== undefined ? !!visibleOverride : contentWindow.visible;
        return {
            "visible": visible,
            "barSide": contentContainer.connectedBarSide,
            "bodyX": root.alignedX,
            "bodyY": root.renderedAlignedY,
            "bodyW": root.alignedWidth,
            "bodyH": root.renderedAlignedHeight,
            "animX": _connectedChromeAnimX(),
            "animY": _connectedChromeAnimY(),
            "screen": root.screen ? root.screen.name : "",
            "omitStartConnector": root._closeGapOmitStartConnector(),
            "omitEndConnector": root._closeGapOmitEndConnector()
        };
    }

    function _publishConnectedChromeState(forceClaim, visibleOverride) {
        if (!root.frameOwnsConnectedChrome || !root.screen || !_chromeClaimId)
            return;

        const state = _connectedChromeState(visibleOverride);
        if (forceClaim || !ConnectedModeState.hasPopoutOwner(_chromeClaimId)) {
            ConnectedModeState.claimPopout(_chromeClaimId, state);
        } else {
            ConnectedModeState.updatePopout(_chromeClaimId, state);
        }
    }

    function _releaseConnectedChromeState() {
        if (_chromeClaimId)
            ConnectedModeState.releasePopout(_chromeClaimId);
        _chromeClaimId = "";
    }

    // ─── Exposed animation state for ConnectedModeState ────────────────────
    readonly property real contentAnimX: contentContainer.animX
    readonly property real contentAnimY: contentContainer.animY

    property bool _fullSyncPending: false

    // ─── ConnectedModeState sync ────────────────────────────────────────────
    function _syncPopoutChromeState() {
        if (!root.frameOwnsConnectedChrome) {
            _releaseConnectedChromeState();
            return;
        }
        if (!root.screen) {
            _releaseConnectedChromeState();
            return;
        }
        if (!contentWindow.visible && !shouldBeVisible)
            return;
        if (!_chromeClaimId)
            _chromeClaimId = _nextChromeClaimId();
        _publishConnectedChromeState(contentWindow.visible && !ConnectedModeState.hasPopoutOwner(_chromeClaimId));
    }

    function _syncPopoutAnim(axis) {
        if (!root.frameOwnsConnectedChrome || !_chromeClaimId)
            return;
        if (!contentWindow.visible && !shouldBeVisible)
            return;
        const barSide = contentContainer.connectedBarSide;
        const syncX = axis === "x" && (barSide === "left" || barSide === "right");
        const syncY = axis === "y" && (barSide === "top" || barSide === "bottom");
        if (!syncX && !syncY)
            return;
        ConnectedModeState.setPopoutAnim(_chromeClaimId, syncX ? _connectedChromeAnimX() : undefined, syncY ? _connectedChromeAnimY() : undefined);
    }

    function _syncPopoutBody() {
        if (!root.frameOwnsConnectedChrome || !_chromeClaimId)
            return;
        if (!contentWindow.visible && !shouldBeVisible)
            return;
        ConnectedModeState.setPopoutBody(_chromeClaimId, root.alignedX, root.renderedAlignedY, root.alignedWidth, root.renderedAlignedHeight);
    }

    function _flushFullSync() {
        _fullSyncPending = false;
        if (root && typeof root._syncPopoutChromeState === "function")
            root._syncPopoutChromeState();
    }

    function _queueFullSync() {
        if (_fullSyncPending)
            return;
        _fullSyncPending = true;
        Qt.callLater(() => {
            if (root && typeof root._flushFullSync === "function")
                root._flushFullSync();
        });
    }

    onAlignedXChanged: _queueFullSync()
    onAlignedYChanged: _queueFullSync()
    onAlignedWidthChanged: _queueFullSync()
    onContentAnimXChanged: _syncPopoutAnim("x")
    onContentAnimYChanged: _syncPopoutAnim("y")
    onRenderedAlignedYChanged: _syncPopoutBody()
    onRenderedAlignedHeightChanged: _syncPopoutBody()
    onScreenChanged: _syncPopoutChromeState()
    onEffectiveBarPositionChanged: _syncPopoutChromeState()

    Connections {
        target: contentWindow
        function onVisibleChanged() {
            if (contentWindow.visible)
                root._publishConnectedChromeState(true);
            else
                root._releaseConnectedChromeState();
        }
    }

    Connections {
        target: SettingsData
        function onConnectedFrameModeActiveChanged() {
            if (root.frameOwnsConnectedChrome) {
                if (contentWindow.visible || root.shouldBeVisible) {
                    if (!root._chromeClaimId)
                        root._chromeClaimId = root._nextChromeClaimId();
                    root._publishConnectedChromeState(true);
                }
            } else {
                root._releaseConnectedChromeState();
            }
        }
        function onFrameCloseGapsChanged() {
            root._syncPopoutChromeState();
        }
    }

    readonly property bool frameOwnsConnectedChrome: SettingsData.connectedFrameModeActive
        && !!root.screen
        && SettingsData.isScreenInPreferences(root.screen, SettingsData.frameScreenPreferences)

    property bool animationsEnabled: true

    function open() {
        if (!screen)
            return;
        closeTimer.stop();
        isClosing = false;
        animationsEnabled = false;
        _primeContent = true;

        if (_lastOpenedScreen !== null && _lastOpenedScreen !== screen) {
            contentWindow.visible = false;
        }
        _lastOpenedScreen = screen;

        if (contentContainer) {
            contentContainer.animX = Theme.snap(contentContainer.offsetX, root.dpr);
            contentContainer.animY = Theme.snap(contentContainer.offsetY, root.dpr);
            contentContainer.scaleValue = root.animationScaleCollapsed;
            _captureChromeAnimTravel();
        }

        if (root.frameOwnsConnectedChrome) {
            _chromeClaimId = _nextChromeClaimId();
            _publishConnectedChromeState(true, true);
        } else {
            _chromeClaimId = "";
        }

        contentWindow.visible = true;

        Qt.callLater(() => {
            animationsEnabled = true;
            shouldBeVisible = true;
            if (shouldBeVisible && screen) {
                contentWindow.visible = true;
                PopoutManager.showPopout(root);
                opened();
            }
        });
    }

    function close() {
        isClosing = true;
        shouldBeVisible = false;
        _primeContent = false;
        PopoutManager.popoutChanged();
        closeTimer.restart();
    }

    function toggle() {
        shouldBeVisible ? close() : open();
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (!shouldBeVisible || !screen)
                return;
            const currentScreenName = screen.name;
            let screenStillExists = false;
            for (let i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === currentScreenName) {
                    screenStillExists = true;
                    break;
                }
            }
            if (!screenStillExists) {
                close();
            }
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.variantCloseInterval(animationDuration)
        onTriggered: {
            if (!shouldBeVisible) {
                isClosing = false;
                contentWindow.visible = false;
                PopoutManager.hidePopout(root);
                popoutClosed();
            }
        }
    }

    Component.onDestruction: _releaseConnectedChromeState()

    readonly property real screenWidth: screen ? screen.width : 0
    readonly property real screenHeight: screen ? screen.height : 0
    readonly property real dpr: screen ? screen.devicePixelRatio : 1
    readonly property bool closeFrameGapsActive: SettingsData.frameCloseGaps && frameOwnsConnectedChrome
    readonly property real frameInset: {
        if (!SettingsData.frameEnabled)
            return 0;
        const ft = SettingsData.frameThickness;
        const fr = SettingsData.frameRounding;
        const ccr = Theme.connectedCornerRadius;
        if (Theme.isConnectedEffect)
            return Math.max(ft * 4, ft + ccr * 2);
        const useAutoGaps = storedBarConfig?.popupGapsAuto !== undefined ? storedBarConfig.popupGapsAuto : true;
        const manualGapValue = storedBarConfig?.popupGapsManual !== undefined ? storedBarConfig.popupGapsManual : 6;
        const gap = useAutoGaps ? Math.max(6, storedBarSpacing) : manualGapValue;
        return Math.max(ft + gap, fr);
    }

    function _popupGapValue() {
        const useAutoGaps = storedBarConfig?.popupGapsAuto !== undefined ? storedBarConfig.popupGapsAuto : true;
        const manualGapValue = storedBarConfig?.popupGapsManual !== undefined ? storedBarConfig.popupGapsManual : 4;
        const rawPopupGap = useAutoGaps ? Math.max(4, storedBarSpacing) : manualGapValue;
        return Theme.isConnectedEffect ? 0 : rawPopupGap;
    }

    function _frameEdgeInset(side) {
        if (!SettingsData.frameEnabled || !root.screen)
            return 0;
        const edges = SettingsData.getActiveBarEdgesForScreen(root.screen);
        const raw = edges.includes(side) ? SettingsData.frameBarSize : SettingsData.frameThickness;
        return Math.max(0, raw);
    }

    function _edgeGapFor(side, popupGap) {
        if (root.closeFrameGapsActive)
            return Math.max(popupGap, _frameEdgeInset(side));
        return Math.max(popupGap, frameInset);
    }

    function _sideAdjacentClearance(side) {
        switch (side) {
        case "left":
            return adjacentBarClearance(adjacentBarInfo.leftBar);
        case "right":
            return adjacentBarClearance(adjacentBarInfo.rightBar);
        case "top":
            return adjacentBarClearance(adjacentBarInfo.topBar);
        case "bottom":
            return adjacentBarClearance(adjacentBarInfo.bottomBar);
        default:
            return 0;
        }
    }

    function _nearFrameBound(value, bound) {
        return Math.abs(value - bound) <= Math.max(1, Theme.hairline(root.dpr) * 2);
    }

    function _closeGapClampedToFrameSide(side) {
        if (!root.closeFrameGapsActive)
            return false;
        const popupGap = _popupGapValue();
        const edgeGap = _edgeGapFor(side, popupGap);
        const adjacentGap = _sideAdjacentClearance(side);
        if (edgeGap < adjacentGap - Math.max(1, Theme.hairline(root.dpr) * 2))
            return false;

        switch (side) {
        case "left":
            return _nearFrameBound(root.alignedX, edgeGap);
        case "right":
            return _nearFrameBound(root.alignedX, screenWidth - popupWidth - edgeGap);
        case "top":
            return _nearFrameBound(root.alignedY, edgeGap);
        case "bottom":
            return _nearFrameBound(root.alignedY, screenHeight - popupHeight - edgeGap);
        default:
            return false;
        }
    }

    function _closeGapOmitStartConnector() {
        const side = contentContainer.connectedBarSide;
        if (side === "top" || side === "bottom")
            return _closeGapClampedToFrameSide("left");
        return _closeGapClampedToFrameSide("top");
    }

    function _closeGapOmitEndConnector() {
        const side = contentContainer.connectedBarSide;
        if (side === "top" || side === "bottom")
            return _closeGapClampedToFrameSide("right");
        return _closeGapClampedToFrameSide("bottom");
    }

    readonly property var shadowLevel: Theme.elevationLevel3
    readonly property real shadowFallbackOffset: 6
    readonly property real shadowRenderPadding: (Theme.elevationEnabled && SettingsData.popoutElevationEnabled) ? Theme.elevationRenderPadding(shadowLevel, effectiveShadowDirection, shadowFallbackOffset, 8, 16) : 0
    readonly property real shadowMotionPadding: {
        if (Theme.isConnectedEffect)
            return Math.max(storedBarSpacing + Theme.connectedCornerRadius + 4, 40);
        if (Theme.isDirectionalEffect) {
            if (typeof SettingsData !== "undefined" && SettingsData.directionalAnimationMode !== 0)
                return 16; // Slide Behind and Roll Out do not add animationOffset, enabling strict Wayland clipping.
            return Math.max(0, animationOffset) + 16;
        }
        if (Theme.isDepthEffect)
            return Math.max(0, animationOffset) + 8;
        return Math.max(0, animationOffset);
    }
    readonly property real shadowBuffer: Theme.snap(shadowRenderPadding + shadowMotionPadding, dpr)
    readonly property real alignedWidth: Theme.px(popupWidth, dpr)
    readonly property real alignedHeight: Theme.px(popupHeight, dpr)
    property real renderedAlignedY: alignedY
    property real renderedAlignedHeight: alignedHeight
    readonly property bool renderedGeometryGrowing: alignedHeight >= renderedAlignedHeight

    Behavior on renderedAlignedY {
        enabled: root.animationsEnabled && contentWindow.visible && root.shouldBeVisible
        NumberAnimation {
            duration: Theme.variantDuration(root.animationDuration, root.renderedGeometryGrowing)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.renderedGeometryGrowing ? root.animationEnterCurve : root.animationExitCurve
        }
    }

    Behavior on renderedAlignedHeight {
        enabled: root.animationsEnabled && contentWindow.visible && root.shouldBeVisible
        NumberAnimation {
            duration: Theme.variantDuration(root.animationDuration, root.renderedGeometryGrowing)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.renderedGeometryGrowing ? root.animationEnterCurve : root.animationExitCurve
        }
    }
    readonly property real connectedAnchorX: {
        if (!Theme.isConnectedEffect)
            return triggerX;
        switch (effectiveBarPosition) {
        case SettingsData.Position.Left:
            return barX + barWidth;
        case SettingsData.Position.Right:
            return barX;
        default:
            return triggerX;
        }
    }
    readonly property real connectedAnchorY: {
        if (!Theme.isConnectedEffect)
            return triggerY;
        switch (effectiveBarPosition) {
        case SettingsData.Position.Top:
            return barY + barHeight;
        case SettingsData.Position.Bottom:
            return barY;
        default:
            return triggerY;
        }
    }

    function adjacentBarClearance(exclusion) {
        if (exclusion <= 0)
            return 0;
        if (!Theme.isConnectedEffect)
            return exclusion;
        // In a shared frame corner, the adjacent connected bar already occupies
        // one rounded-corner radius before the popout's own connector begins.
        return exclusion + Theme.connectedCornerRadius * 2;
    }

    onAlignedHeightChanged: {
        _queueFullSync();
        if (!suspendShadowWhileResizing || !shouldBeVisible)
            return;
        _resizeActive = true;
        resizeSettleTimer.restart();
    }
    onShouldBeVisibleChanged: {
        if (!shouldBeVisible) {
            _resizeActive = false;
            resizeSettleTimer.stop();
        }
    }

    Timer {
        id: resizeSettleTimer
        interval: 80
        repeat: false
        onTriggered: root._resizeActive = false
    }

    readonly property real alignedX: Theme.snap((() => {
            const popupGap = _popupGapValue();
            const edgeGapLeft = _edgeGapFor("left", popupGap);
            const edgeGapRight = _edgeGapFor("right", popupGap);
            const anchorX = Theme.isConnectedEffect ? connectedAnchorX : triggerX;

            switch (effectiveBarPosition) {
            case SettingsData.Position.Left:
                // bar on left: left side is bar-adjacent (popupGap), right side is frame-perpendicular (edgeGap)
                return Math.max(popupGap, Math.min(screenWidth - popupWidth - edgeGapRight, anchorX));
            case SettingsData.Position.Right:
                // bar on right: right side is bar-adjacent (popupGap), left side is frame-perpendicular (edgeGap)
                return Math.max(edgeGapLeft, Math.min(screenWidth - popupWidth - popupGap, anchorX - popupWidth));
            default:
                const rawX = triggerX + (triggerWidth / 2) - (popupWidth / 2);
                const minX = Math.max(edgeGapLeft, adjacentBarClearance(adjacentBarInfo.leftBar));
                const maxX = screenWidth - popupWidth - Math.max(edgeGapRight, adjacentBarClearance(adjacentBarInfo.rightBar));
                return Math.max(minX, Math.min(maxX, rawX));
            }
        })(), dpr)

    readonly property real alignedY: Theme.snap((() => {
            const popupGap = _popupGapValue();
            const edgeGapTop = _edgeGapFor("top", popupGap);
            const edgeGapBottom = _edgeGapFor("bottom", popupGap);
            const anchorY = Theme.isConnectedEffect ? connectedAnchorY : triggerY;

            switch (effectiveBarPosition) {
            case SettingsData.Position.Bottom:
                // bar on bottom: bottom side is bar-adjacent (popupGap), top side is frame-perpendicular (edgeGap)
                return Math.max(edgeGapTop, Math.min(screenHeight - popupHeight - popupGap, anchorY - popupHeight));
            case SettingsData.Position.Top:
                // bar on top: top side is bar-adjacent (popupGap), bottom side is frame-perpendicular (edgeGap)
                return Math.max(popupGap, Math.min(screenHeight - popupHeight - edgeGapBottom, anchorY));
            default:
                const rawY = triggerY - (popupHeight / 2);
                const minY = Math.max(edgeGapTop, adjacentBarClearance(adjacentBarInfo.topBar));
                const maxY = screenHeight - popupHeight - Math.max(edgeGapBottom, adjacentBarClearance(adjacentBarInfo.bottomBar));
                return Math.max(minY, Math.min(maxY, rawY));
            }
        })(), dpr)

    readonly property real triggeringBarLeftExclusion: (effectiveBarPosition === SettingsData.Position.Left && barWidth > 0) ? Math.max(0, barX + barWidth) : 0
    readonly property real triggeringBarTopExclusion: (effectiveBarPosition === SettingsData.Position.Top && barHeight > 0) ? Math.max(0, barY + barHeight) : 0
    readonly property real triggeringBarRightExclusion: (effectiveBarPosition === SettingsData.Position.Right && barWidth > 0) ? Math.max(0, screenWidth - barX) : 0
    readonly property real triggeringBarBottomExclusion: (effectiveBarPosition === SettingsData.Position.Bottom && barHeight > 0) ? Math.max(0, screenHeight - barY) : 0

    readonly property real maskX: {
        const adjacentLeftBar = adjacentBarInfo?.leftBar ?? 0;
        return Math.max(triggeringBarLeftExclusion, adjacentLeftBar);
    }

    readonly property real maskY: {
        const adjacentTopBar = adjacentBarInfo?.topBar ?? 0;
        return Math.max(triggeringBarTopExclusion, adjacentTopBar);
    }

    readonly property real maskWidth: {
        const adjacentRightBar = adjacentBarInfo?.rightBar ?? 0;
        const rightExclusion = Math.max(triggeringBarRightExclusion, adjacentRightBar);
        return Math.max(100, screenWidth - maskX - rightExclusion);
    }

    readonly property real maskHeight: {
        const adjacentBottomBar = adjacentBarInfo?.bottomBar ?? 0;
        const bottomExclusion = Math.max(triggeringBarBottomExclusion, adjacentBottomBar);
        return Math.max(100, screenHeight - maskY - bottomExclusion);
    }

    PanelWindow {
        id: contentWindow
        screen: root.screen
        visible: false
        color: "transparent"

        WindowBlur {
            id: popoutBlur
            targetWindow: contentWindow
            blurEnabled: root.effectiveSurfaceBlurEnabled && !root.frameOwnsConnectedChrome

            readonly property real s: Math.min(1, contentContainer.scaleValue)
            readonly property bool trackBlurFromBarEdge: Theme.isConnectedEffect || (typeof SettingsData !== "undefined" && Theme.isDirectionalEffect && SettingsData.directionalAnimationMode !== 2)

            // Directional popouts clip to the bar edge, so the blur needs to grow from
            // that same edge instead of translating through the bar before settling.
            readonly property real _dyClamp: (contentContainer.barTop || contentContainer.barBottom) ? Math.max(-contentContainer.height, Math.min(contentContainer.animY, contentContainer.height)) : 0
            readonly property real _dxClamp: (contentContainer.barLeft || contentContainer.barRight) ? Math.max(-contentContainer.width, Math.min(contentContainer.animX, contentContainer.width)) : 0

            blurX: trackBlurFromBarEdge ? contentContainer.x + (contentContainer.barRight ? _dxClamp : 0) : contentContainer.x + contentContainer.width * (1 - s) * 0.5 + Theme.snap(contentContainer.animX, root.dpr) - contentContainer.horizontalConnectorExtent * s
            blurY: trackBlurFromBarEdge ? contentContainer.y + (contentContainer.barBottom ? _dyClamp : 0) : contentContainer.y + contentContainer.height * (1 - s) * 0.5 + Theme.snap(contentContainer.animY, root.dpr) - contentContainer.verticalConnectorExtent * s
            blurWidth: (shouldBeVisible && contentWrapper.opacity > 0) ? (trackBlurFromBarEdge ? Math.max(0, contentContainer.width - Math.abs(_dxClamp)) : (contentContainer.width + contentContainer.horizontalConnectorExtent * 2) * s) : 0
            blurHeight: (shouldBeVisible && contentWrapper.opacity > 0) ? (trackBlurFromBarEdge ? Math.max(0, contentContainer.height - Math.abs(_dyClamp)) : (contentContainer.height + contentContainer.verticalConnectorExtent * 2) * s) : 0
            blurRadius: Theme.isConnectedEffect ? Theme.connectedCornerRadius : Theme.connectedSurfaceRadius
        }

        WlrLayershell.namespace: root.layerNamespace
        WlrLayershell.layer: {
            switch (Quickshell.env("DMS_POPOUT_LAYER")) {
            case "bottom":
                log.warn("'bottom' layer is not valid for popouts. Defaulting to 'top' layer.");
                return WlrLayershell.Top;
            case "background":
                log.warn("'background' layer is not valid for popouts. Defaulting to 'top' layer.");
                return WlrLayershell.Top;
            case "overlay":
                return WlrLayershell.Overlay;
            default:
                return WlrLayershell.Top;
            }
        }
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: {
            if (customKeyboardFocus !== null)
                return customKeyboardFocus;
            if (!shouldBeVisible)
                return WlrKeyboardFocus.None;
            if (CompositorService.useHyprlandFocusGrab)
                return WlrKeyboardFocus.OnDemand;
            return WlrKeyboardFocus.Exclusive;
        }

        readonly property bool _fullHeight: root.fullHeightSurface
        anchors {
            left: true
            top: true
            right: true
            bottom: true
        }

        WlrLayershell.margins {
            left: 0
            top: 0
        }

        implicitWidth: 0
        implicitHeight: 0

        mask: contentInputMask

        Region {
            id: contentInputMask
            // Outside-click dismissal needs full-screen input only while interactive.
            item: (shouldBeVisible && backgroundInteractive) ? fullScreenMaskItem : contentMaskRect
        }

        Item {
            id: fullScreenMaskItem
            visible: false
            x: 0
            y: 0
            width: 32767
            height: 32767
        }

        Item {
            id: contentMaskRect
            visible: false
            x: contentContainer.x - contentContainer.horizontalConnectorExtent
            y: contentContainer.y - contentContainer.verticalConnectorExtent
            width: root.alignedWidth + contentContainer.horizontalConnectorExtent * 2
            height: root.renderedAlignedHeight + contentContainer.verticalConnectorExtent * 2
        }

        MouseArea {
            anchors.fill: parent
            enabled: shouldBeVisible && backgroundInteractive
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            z: -1
            onClicked: mouse => {
                const clickX = mouse.x;
                const clickY = mouse.y;
                const outsideContent = clickX < root.alignedX || clickX > root.alignedX + root.alignedWidth || clickY < root.renderedAlignedY || clickY > root.renderedAlignedY + root.renderedAlignedHeight;
                if (!outsideContent)
                    return;
                backgroundClicked();
            }
        }

        Item {
            id: contentContainer
            x: root.alignedX
            y: root.renderedAlignedY
            width: root.alignedWidth
            height: root.renderedAlignedHeight

            readonly property bool barTop: effectiveBarPosition === SettingsData.Position.Top
            readonly property bool barBottom: effectiveBarPosition === SettingsData.Position.Bottom
            readonly property bool barLeft: effectiveBarPosition === SettingsData.Position.Left
            readonly property bool barRight: effectiveBarPosition === SettingsData.Position.Right
            readonly property string connectedBarSide: barTop ? "top" : (barBottom ? "bottom" : (barLeft ? "left" : "right"))
            readonly property real surfaceRadius: Theme.connectedSurfaceRadius
            readonly property color surfaceColor: Theme.popupLayerColor(Theme.surfaceContainer)
            readonly property color surfaceBorderColor: Theme.isConnectedEffect ? "transparent" : (BlurService.enabled ? BlurService.borderColor : Theme.outlineMedium)
            readonly property real surfaceBorderWidth: Theme.isConnectedEffect ? 0 : BlurService.borderWidth
            readonly property real surfaceTopLeftRadius: Theme.isConnectedEffect && (barTop || barLeft) ? 0 : surfaceRadius
            readonly property real surfaceTopRightRadius: Theme.isConnectedEffect && (barTop || barRight) ? 0 : surfaceRadius
            readonly property real surfaceBottomLeftRadius: Theme.isConnectedEffect && (barBottom || barLeft) ? 0 : surfaceRadius
            readonly property real surfaceBottomRightRadius: Theme.isConnectedEffect && (barBottom || barRight) ? 0 : surfaceRadius
            readonly property bool directionalEffect: Theme.isDirectionalEffect
            readonly property bool depthEffect: Theme.isDepthEffect
            readonly property real directionalTravelX: Math.max(root.animationOffset, root.alignedWidth + Theme.spacingL)
            readonly property real directionalTravelY: Math.max(root.animationOffset, root.alignedHeight + Theme.spacingL)
            readonly property real depthTravel: Math.max(root.animationOffset * 0.7, 28)
            readonly property real sectionTilt: (triggerSection === "left" ? -1 : (triggerSection === "right" ? 1 : 0))
            readonly property real horizontalConnectorExtent: Theme.isConnectedEffect && (barTop || barBottom) ? Theme.connectedCornerRadius : 0
            readonly property real verticalConnectorExtent: Theme.isConnectedEffect && (barLeft || barRight) ? Theme.connectedCornerRadius : 0

            function connectorWidth(spacing) {
                return (barTop || barBottom) ? Theme.connectedCornerRadius : (spacing + Theme.connectedCornerRadius);
            }

            function connectorHeight(spacing) {
                return (barTop || barBottom) ? (spacing + Theme.connectedCornerRadius) : Theme.connectedCornerRadius;
            }

            function connectorSeamX(baseX, bodyWidth, placement) {
                if (barTop || barBottom)
                    return placement === "left" ? baseX : baseX + bodyWidth;
                return barLeft ? baseX : baseX + bodyWidth;
            }

            function connectorSeamY(baseY, bodyHeight, placement) {
                if (barTop)
                    return baseY;
                if (barBottom)
                    return baseY + bodyHeight;
                return placement === "left" ? baseY : baseY + bodyHeight;
            }

            function connectorX(baseX, bodyWidth, placement, spacing) {
                const seamX = connectorSeamX(baseX, bodyWidth, placement);
                const width = connectorWidth(spacing);
                if (barTop || barBottom)
                    return placement === "left" ? seamX - width : seamX;
                return barLeft ? seamX : seamX - width;
            }

            function connectorY(baseY, bodyHeight, placement, spacing) {
                const seamY = connectorSeamY(baseY, bodyHeight, placement);
                const height = connectorHeight(spacing);
                if (barTop)
                    return seamY;
                if (barBottom)
                    return seamY - height;
                return placement === "left" ? seamY - height : seamY;
            }

            readonly property real offsetX: {
                if (directionalEffect) {
                    if (typeof SettingsData !== "undefined" && SettingsData.directionalAnimationMode === 2)
                        return 0;
                    if (barLeft)
                        return -directionalTravelX;
                    if (barRight)
                        return directionalTravelX;
                    if (barTop || barBottom)
                        return 0;
                    return sectionTilt * directionalTravelX * 0.2;
                }
                if (depthEffect) {
                    if (barLeft)
                        return -depthTravel;
                    if (barRight)
                        return depthTravel;
                    if (barTop || barBottom)
                        return 0;
                    return sectionTilt * depthTravel * 0.2;
                }
                return barLeft ? root.animationOffset : (barRight ? -root.animationOffset : 0);
            }
            readonly property real offsetY: {
                if (directionalEffect) {
                    if (typeof SettingsData !== "undefined" && SettingsData.directionalAnimationMode === 2)
                        return 0;
                    if (barBottom)
                        return directionalTravelY;
                    if (barTop)
                        return -directionalTravelY;
                    if (barLeft || barRight)
                        return 0;
                    return directionalTravelY;
                }
                if (depthEffect) {
                    if (barBottom)
                        return depthTravel;
                    if (barTop)
                        return -depthTravel;
                    if (barLeft || barRight)
                        return 0;
                    return depthTravel;
                }
                return barBottom ? -root.animationOffset : (barTop ? root.animationOffset : 0);
            }

            property real animX: 0
            property real animY: 0

            readonly property real computedScaleCollapsed: (typeof SettingsData !== "undefined" && SettingsData.directionalAnimationMode === 2 && Theme.isDirectionalEffect) ? 0.0 : root.animationScaleCollapsed
            property real scaleValue: computedScaleCollapsed

            Component.onCompleted: {
                animX = Theme.snap(root.shouldBeVisible ? 0 : offsetX, root.dpr);
                animY = Theme.snap(root.shouldBeVisible ? 0 : offsetY, root.dpr);
                scaleValue = root.shouldBeVisible ? 1.0 : computedScaleCollapsed;
                root._captureChromeAnimTravel();
            }

            onOffsetXChanged: {
                if (!root.shouldBeVisible)
                    animX = Theme.snap(offsetX, root.dpr);
            }
            onOffsetYChanged: {
                if (!root.shouldBeVisible)
                    animY = Theme.snap(offsetY, root.dpr);
            }

            Connections {
                target: root
                function onShouldBeVisibleChanged() {
                    root._captureChromeAnimTravel();
                    contentContainer.animX = Theme.snap(root.shouldBeVisible ? 0 : contentContainer.offsetX, root.dpr);
                    contentContainer.animY = Theme.snap(root.shouldBeVisible ? 0 : contentContainer.offsetY, root.dpr);
                    contentContainer.scaleValue = root.shouldBeVisible ? 1.0 : contentContainer.computedScaleCollapsed;
                }
            }

            Behavior on animX {
                enabled: root.animationsEnabled
                NumberAnimation {
                    duration: Theme.variantDuration(root.animationDuration, root.shouldBeVisible)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }

            Behavior on animY {
                enabled: root.animationsEnabled
                NumberAnimation {
                    duration: Theme.variantDuration(root.animationDuration, root.shouldBeVisible)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }

            Behavior on scaleValue {
                enabled: root.animationsEnabled
                NumberAnimation {
                    duration: Theme.variantDuration(root.animationDuration, root.shouldBeVisible)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }

            Item {
                id: directionalClipMask

                readonly property bool shouldClip: (Theme.isDirectionalEffect && typeof SettingsData !== "undefined" && SettingsData.directionalAnimationMode > 0) || Theme.isConnectedEffect
                readonly property real clipOversize: 1000
                readonly property real connectedClipAllowance: {
                    if (!Theme.isConnectedEffect) return 0;
                    if (root.frameOwnsConnectedChrome) return 0;
                    return -Theme.connectedCornerRadius;
                }

                clip: shouldClip

                // Bound the clipping strictly to the bar side, allowing massive overflow on the other 3 sides for shadows
                x: shouldClip ? (contentContainer.barLeft ? -connectedClipAllowance : -clipOversize) : 0
                y: shouldClip ? (contentContainer.barTop ? -connectedClipAllowance : -clipOversize) : 0

                width: {
                    if (!shouldClip)
                        return parent.width;
                    if (contentContainer.barLeft)
                        return parent.width + connectedClipAllowance + clipOversize;
                    if (contentContainer.barRight)
                        return parent.width + clipOversize + connectedClipAllowance;
                    return parent.width + clipOversize * 2;
                }
                height: {
                    if (!shouldClip)
                        return parent.height;
                    if (contentContainer.barTop)
                        return parent.height + connectedClipAllowance + clipOversize;
                    if (contentContainer.barBottom)
                        return parent.height + clipOversize + connectedClipAllowance;
                    return parent.height + clipOversize * 2;
                }

                // Roll-out clips a wrapper while content and shadow keep full-size geometry.
                Item {
                    id: rollOutAdjuster
                    readonly property real baseWidth: contentContainer.width
                    readonly property real baseHeight: contentContainer.height
                    readonly property bool isRollOut: typeof SettingsData !== "undefined" && SettingsData.directionalAnimationMode === 2 && Theme.isDirectionalEffect

                    x: directionalClipMask.x !== 0 ? -directionalClipMask.x : 0
                    y: directionalClipMask.y !== 0 ? -directionalClipMask.y : 0
                    width: isRollOut && (contentContainer.barLeft || contentContainer.barRight) ? Math.max(0, baseWidth * contentContainer.scaleValue) : baseWidth
                    height: isRollOut && (contentContainer.barTop || contentContainer.barBottom) ? Math.max(0, baseHeight * contentContainer.scaleValue) : baseHeight

                    clip: isRollOut

                    ElevationShadow {
                        id: shadowSource
                        readonly property real connectorExtent: Theme.isConnectedEffect ? Theme.connectedCornerRadius : 0
                        readonly property real extraLeft: Theme.isConnectedEffect && (contentContainer.barTop || contentContainer.barBottom) ? connectorExtent : 0
                        readonly property real extraRight: Theme.isConnectedEffect && (contentContainer.barTop || contentContainer.barBottom) ? connectorExtent : 0
                        readonly property real extraTop: Theme.isConnectedEffect && (contentContainer.barLeft || contentContainer.barRight) ? connectorExtent : 0
                        readonly property real extraBottom: Theme.isConnectedEffect && (contentContainer.barLeft || contentContainer.barRight) ? connectorExtent : 0
                        readonly property real bodyX: extraLeft
                        readonly property real bodyY: extraTop
                        readonly property real bodyWidth: rollOutAdjuster.baseWidth
                        readonly property real bodyHeight: rollOutAdjuster.baseHeight

                        width: rollOutAdjuster.baseWidth + extraLeft + extraRight
                        height: rollOutAdjuster.baseHeight + extraTop + extraBottom
                        opacity: contentWrapper.opacity
                        scale: contentWrapper.scale
                        x: contentWrapper.x - extraLeft
                        y: contentWrapper.y - extraTop
                        level: root.shadowLevel
                        direction: root.effectiveShadowDirection
                        fallbackOffset: root.shadowFallbackOffset
                        targetRadius: contentContainer.surfaceRadius
                        topLeftRadius: contentContainer.surfaceTopLeftRadius
                        topRightRadius: contentContainer.surfaceTopRightRadius
                        bottomLeftRadius: contentContainer.surfaceBottomLeftRadius
                        bottomRightRadius: contentContainer.surfaceBottomRightRadius
                        targetColor: contentContainer.surfaceColor
                        borderColor: contentContainer.surfaceBorderColor
                        borderWidth: contentContainer.surfaceBorderWidth
                        useCustomSource: Theme.isConnectedEffect
                        shadowEnabled: Theme.elevationEnabled && SettingsData.popoutElevationEnabled && Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1" && !(root.suspendShadowWhileResizing && root._resizeActive) && !root.frameOwnsConnectedChrome

                        Item {
                            anchors.fill: parent
                            visible: Theme.isConnectedEffect && !root.frameOwnsConnectedChrome
                            clip: false

                            Rectangle {
                                x: shadowSource.bodyX
                                y: shadowSource.bodyY
                                width: shadowSource.bodyWidth
                                height: shadowSource.bodyHeight
                                topLeftRadius: contentContainer.surfaceTopLeftRadius
                                topRightRadius: contentContainer.surfaceTopRightRadius
                                bottomLeftRadius: contentContainer.surfaceBottomLeftRadius
                                bottomRightRadius: contentContainer.surfaceBottomRightRadius
                                color: contentContainer.surfaceColor
                            }

                            ConnectedCorner {
                                visible: Theme.isConnectedEffect
                                barSide: contentContainer.connectedBarSide
                                placement: "left"
                                spacing: 0
                                connectorRadius: Theme.connectedCornerRadius
                                color: contentContainer.surfaceColor
                                dpr: root.dpr
                                x: Theme.snap(contentContainer.connectorX(shadowSource.bodyX, shadowSource.bodyWidth, placement, spacing), root.dpr)
                                y: Theme.snap(contentContainer.connectorY(shadowSource.bodyY, shadowSource.bodyHeight, placement, spacing), root.dpr)
                            }

                            ConnectedCorner {
                                visible: Theme.isConnectedEffect
                                barSide: contentContainer.connectedBarSide
                                placement: "right"
                                spacing: 0
                                connectorRadius: Theme.connectedCornerRadius
                                color: contentContainer.surfaceColor
                                dpr: root.dpr
                                x: Theme.snap(contentContainer.connectorX(shadowSource.bodyX, shadowSource.bodyWidth, placement, spacing), root.dpr)
                                y: Theme.snap(contentContainer.connectorY(shadowSource.bodyY, shadowSource.bodyHeight, placement, spacing), root.dpr)
                            }
                        }
                    }

                    Item {
                        id: contentWrapper
                        width: rollOutAdjuster.baseWidth
                        height: rollOutAdjuster.baseHeight
                        opacity: Theme.isDirectionalEffect ? 1 : (shouldBeVisible ? 1 : 0)
                        visible: opacity > 0

                        scale: rollOutAdjuster.isRollOut ? 1.0 : contentContainer.scaleValue
                        x: Theme.snap(contentContainer.animX + (rollOutAdjuster.baseWidth - width) * (1 - scale) * 0.5, root.dpr)
                        y: Theme.snap(contentContainer.animY + (rollOutAdjuster.baseHeight - height) * (1 - scale) * 0.5, root.dpr)

                        layer.enabled: contentWrapper.opacity < 1
                        layer.smooth: false
                        layer.textureSize: root.dpr > 1 ? Qt.size(Math.ceil(width * root.dpr), Math.ceil(height * root.dpr)) : Qt.size(0, 0)

                        Behavior on opacity {
                            enabled: !Theme.isDirectionalEffect
                            NumberAnimation {
                                duration: Math.round(Theme.variantDuration(animationDuration, shouldBeVisible) * Theme.variantOpacityDurationScale)
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                            }
                        }

                        Item {
                            anchors.fill: parent
                            clip: false
                            visible: !Theme.isConnectedEffect

                            Rectangle {
                                anchors.fill: parent
                                antialiasing: true
                                topLeftRadius: contentContainer.surfaceTopLeftRadius
                                topRightRadius: contentContainer.surfaceTopRightRadius
                                bottomLeftRadius: contentContainer.surfaceBottomLeftRadius
                                bottomRightRadius: contentContainer.surfaceBottomRightRadius
                                color: contentContainer.surfaceColor
                                border.color: contentContainer.surfaceBorderColor
                                border.width: contentContainer.surfaceBorderWidth
                            }
                        }

                        Loader {
                            id: contentLoader
                            anchors.fill: parent
                            active: root._primeContent || shouldBeVisible || contentWindow.visible
                            asynchronous: false
                        }
                    }
                }
            }
        }

        Item {
            id: focusHelper
            parent: contentContainer
            anchors.fill: parent
            visible: !root.contentHandlesKeys
            enabled: !root.contentHandlesKeys
            focus: !root.contentHandlesKeys
            Keys.onPressed: event => {
                if (root.contentHandlesKeys)
                    return;
                if (event.key === Qt.Key_Escape) {
                    close();
                    event.accepted = true;
                }
            }
        }

        Loader {
            id: overlayLoader
            anchors.fill: parent
            active: root.overlayContent !== null && contentWindow.visible
            sourceComponent: root.overlayContent
        }
    }
}
