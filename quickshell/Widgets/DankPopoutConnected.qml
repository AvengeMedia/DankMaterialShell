pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

Item {
    id: root
    readonly property var log: Log.scoped("DankPopoutConnected")

    property var popoutHandle: root
    property string layerNamespace: "dms:popout"
    property alias content: contentLoader.sourceComponent
    property alias contentLoader: contentLoader
    property Component overlayContent: null
    property alias overlayLoader: overlayLoader
    readonly property alias backgroundWindow: contentWindow
    readonly property alias contentWindow: contentWindow
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
    property real _chromeAnimTravelX: 1
    property real _chromeAnimTravelY: 1
    property bool _fullSyncQueued: false

    property real storedBarThickness: Theme.barHeight - 4
    property real storedBarSpacing: 4
    property var storedBarConfig: null
    property bool triggerUsesOverlayLayer: false
    property var adjacentBarInfo: ({
            "topBar": 0,
            "bottomBar": 0,
            "leftBar": 0,
            "rightBar": 0
        })
    property var screen: null
    readonly property bool useBackgroundWindow: false
    readonly property var effectivePopoutLayer: LayerShell.fromEnv("DMS_POPOUT_LAYER", root.triggerUsesOverlayLayer ? WlrLayer.Overlay : WlrLayer.Top, {
        "allow": ["top", "overlay"],
        "invalidLayer": WlrLayer.Top,
        "label": "popouts"
    })

    readonly property real effectiveBarThickness: {
        if (root.usesConnectedSurfaceChrome)
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

    Timer {
        id: _syncTimer
        interval: 0
        onTriggered: root._flushSync()
    }

    ConnectedSurfaceLease {
        id: chromeLease
        claimPrefix: root.layerNamespace
        screenName: root.screen ? root.screen.name : ""
        enabled: root.frameOwnsConnectedChrome
        active: contentWindow.visible || root.shouldBeVisible
        presented: contentWindow.visible || root.shouldBeVisible
        renewTokenOnRecovery: false
        isCurrentOwner: function(name) {
            return PopoutManager.isCurrentPopout(root.popoutHandle, name);
        }
        hasOwner: function(_name, ownerId) {
            return ConnectedModeState.hasPopoutOwner(ownerId);
        }
        statePresent: function(name, ownerId) {
            return ConnectedModeState.hasPopoutOwner(ownerId) && ConnectedModeState.hasSurfaceDescriptor(name, "popout", ownerId);
        }
        claimState: function(_name, state, ownerId) {
            return ConnectedModeState.claimPopout(ownerId, state);
        }
        ensureState: function(_name, state, ownerId) {
            if (!ConnectedModeState.hasPopoutOwner(ownerId))
                return false;
            return ConnectedModeState.updatePopout(ownerId, state);
        }
        releaseState: function(_name, ownerId) {
            return ConnectedModeState.releasePopout(ownerId);
        }
        updateAnimationState: function(_name, ownerId, animX, animY) {
            return ConnectedModeState.setPopoutAnim(ownerId, animX, animY);
        }
        updateBodyState: function(_name, ownerId, bodyX, bodyY, bodyW, bodyH) {
            return ConnectedModeState.setPopoutBody(ownerId, bodyX, bodyY, bodyW, bodyH);
        }
        onRecoveryRequested: root._queueFullSync()
    }

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
        const presented = contentWindow.visible || root.shouldBeVisible;
        const phase = root.isClosing ? "closing" : (!presented ? "hidden" : (!contentWindow.visible && root.shouldBeVisible ? "opening" : "open"));
        const bodyRect = {
            "x": root.alignedX,
            "y": root.renderedAlignedY,
            "width": root.alignedWidth,
            "height": root.renderedAlignedHeight
        };
        const animationOffset = {
            "x": _connectedChromeAnimX(),
            "y": _connectedChromeAnimY()
        };
        return {
            "kind": "popout",
            "screenName": root.screen ? root.screen.name : "",
            "phase": phase,
            "visible": visible,
            "presented": presented,
            "barSide": contentContainer.connectedBarSide,
            "bodyRect": bodyRect,
            "animationOffset": animationOffset,
            "scale": 1,
            "opacity": Theme.connectedSurfaceColor.a,
            "bodyX": root.alignedX,
            "bodyY": root.renderedAlignedY,
            "bodyW": root.alignedWidth,
            "bodyH": root.renderedAlignedHeight,
            "animX": animationOffset.x,
            "animY": animationOffset.y,
            "screen": root.screen ? root.screen.name : "",
            "omitStartConnector": root._closeGapOmitStartConnector(),
            "omitEndConnector": root._closeGapOmitEndConnector()
        };
    }

    function _publishConnectedChromeState(forceClaim, visibleOverride) {
        if (!root.frameOwnsConnectedChrome || !root.screen)
            return false;
        return chromeLease.publish(_connectedChromeState(visibleOverride), !!forceClaim);
    }

    function _releaseConnectedChromeState() {
        chromeLease.release();
    }

    readonly property real contentAnimX: contentContainer.animX
    readonly property real contentAnimY: contentContainer.animY

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
        _publishConnectedChromeState(false);
    }

    function _syncPopoutAnim(axis) {
        if (!root.frameOwnsConnectedChrome || !chromeLease.claimId)
            return;
        if (!contentWindow.visible && !shouldBeVisible)
            return;
        const barSide = contentContainer.connectedBarSide;
        const syncX = axis === "x" && (barSide === "left" || barSide === "right");
        const syncY = axis === "y" && (barSide === "top" || barSide === "bottom");
        if (!syncX && !syncY)
            return;
        chromeLease.updateAnim(syncX ? _connectedChromeAnimX() : undefined, syncY ? _connectedChromeAnimY() : undefined);
    }

    function _syncPopoutBody() {
        if (!root.frameOwnsConnectedChrome || !chromeLease.claimId)
            return;
        if (!contentWindow.visible && !shouldBeVisible)
            return;
        chromeLease.updateBody(root.alignedX, root.renderedAlignedY, root.alignedWidth, root.renderedAlignedHeight);
    }

    property bool _animSyncQueued: false
    property bool _bodySyncQueued: false

    function _queueFullSync() {
        _fullSyncQueued = true;
        if (!_syncTimer.running)
            _syncTimer.restart();
    }
    function _queueAnimSync() {
        _animSyncQueued = true;
        if (!_syncTimer.running)
            _syncTimer.restart();
    }
    function _queueBodySync() {
        _bodySyncQueued = true;
        if (!_syncTimer.running)
            _syncTimer.restart();
    }
    function _flushSync() {
        const fullDirty = _fullSyncQueued;
        const animDirty = _animSyncQueued;
        const bodyDirty = _bodySyncQueued;
        _fullSyncQueued = false;
        _animSyncQueued = false;
        _bodySyncQueued = false;
        if (fullDirty)
            _syncPopoutChromeState();
        if (animDirty) {
            _syncPopoutAnim("x");
            _syncPopoutAnim("y");
        }
        if (bodyDirty)
            _syncPopoutBody();
    }

    onAlignedXChanged: _queueFullSync()
    onAlignedYChanged: _queueFullSync()
    onAlignedWidthChanged: _queueFullSync()
    onContentAnimXChanged: _queueAnimSync()
    onContentAnimYChanged: _queueAnimSync()
    onRenderedAlignedYChanged: _queueBodySync()
    onRenderedAlignedHeightChanged: _queueBodySync()
    onScreenChanged: _queueFullSync()
    onEffectiveBarPositionChanged: _queueFullSync()

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
                if ((contentWindow.visible || root.shouldBeVisible) && root.screen && PopoutManager.isCurrentPopout(root.popoutHandle, root.screen.name))
                    root._publishConnectedChromeState(true);
            } else {
                root._releaseConnectedChromeState();
            }
        }
        function onFrameCloseGapsChanged() {
            root._syncPopoutChromeState();
        }
    }

    Connections {
        target: ConnectedModeState
        function onPopoutOwnerIdChanged() {
            chromeLease.checkOwnershipRecovery();
        }
        function onSurfaceDescriptorsChanged() {
            chromeLease.checkStateRecovery();
        }
    }

    Connections {
        target: PopoutManager
        function onPopoutChanged() {
            chromeLease.requestRecovery();
        }
    }

    readonly property bool frameOwnsConnectedChrome: CompositorService.usesConnectedFrameChromeForScreen(root.screen)
    readonly property bool usesConnectedSurfaceChrome: Theme.isConnectedEffect && !CompositorService.connectedFrameBlockedOnScreen(root.screen)
    readonly property bool usesLocalConnectedSurfaceChrome: usesConnectedSurfaceChrome && !frameOwnsConnectedChrome
    onFrameOwnsConnectedChromeChanged: _syncPopoutChromeState()

    property bool animationsEnabled: true

    function open() {
        if (!screen)
            return;
        closeTimer.stop();
        isClosing = false;
        animationsEnabled = false;
        _primeContent = true;

        const screenChanged = _lastOpenedScreen !== null && _lastOpenedScreen !== screen;
        if (screenChanged) {
            contentWindow.visible = false;
        }
        _lastOpenedScreen = screen;
        PopoutManager.showPopout(popoutHandle);

        if (contentContainer) {
            if (!shouldBeVisible)
                morph.openProgress = 0;
            _captureChromeAnimTravel();
        }

        if (root.frameOwnsConnectedChrome) {
            chromeLease.beginClaim();
            _publishConnectedChromeState(true, true);
        } else {
            chromeLease.release();
        }

        if (screenChanged) {
            // Unmap/remap wl_surface across ticks so blur republishes on the new screen.
            Qt.callLater(() => {
                if (!root.shouldBeVisible)
                    return;
                contentWindow.visible = true;
                popoutBlur.kick();
            });
        } else {
            contentWindow.visible = true;
        }

        animationsEnabled = true;
        shouldBeVisible = true;
        if (shouldBeVisible && screen) {
            opened();
        }
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
            } else {
                root._queueFullSync();
            }
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.variantCloseInterval(animationDuration)
        onTriggered: {
            if (!shouldBeVisible) {
                contentWindow.visible = false;
                isClosing = false;
                PopoutManager.hidePopout(popoutHandle);
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
        if (!root.frameOwnsConnectedChrome)
            return 0;
        const ft = SettingsData.frameThickness;
        const fr = SettingsData.frameRounding;
        const ccr = Theme.connectedCornerRadius;
        return Math.max(ft * 4, ft + ccr * 2, fr);
    }

    function _popupGapValue() {
        const useAutoGaps = storedBarConfig?.popupGapsAuto !== undefined ? storedBarConfig.popupGapsAuto : true;
        const manualGapValue = storedBarConfig?.popupGapsManual !== undefined ? storedBarConfig.popupGapsManual : 4;
        const rawPopupGap = useAutoGaps ? Math.max(4, storedBarSpacing) : manualGapValue;
        return root.usesConnectedSurfaceChrome ? 0 : rawPopupGap;
    }

    function _frameEdgeInset(side) {
        if (!root.frameOwnsConnectedChrome || !root.screen)
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

    // Snap positions within connector radius flush to the frame edge (avoids pinched arcs).
    function _snapNearFrameBound(value, minBound, maxBound, minIsFrame, maxIsFrame) {
        if (!root.usesConnectedSurfaceChrome || !root.closeFrameGapsActive)
            return value;
        const snapDist = Theme.connectedCornerRadius;
        if (maxIsFrame && value < maxBound && maxBound - value < snapDist && maxBound - value <= value - minBound)
            return maxBound;
        if (minIsFrame && value > minBound && value - minBound < snapDist)
            return minBound;
        return value;
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
        if (root.usesConnectedSurfaceChrome)
            return Math.max(storedBarSpacing + Theme.connectedCornerRadius + 4, 40);
        if (Theme.isDirectionalEffect)
            return 16;
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
    readonly property bool _settlingToOpen: fullHeightSurface && shouldBeVisible && morphAnim.running

    Behavior on renderedAlignedY {
        enabled: root.animationsEnabled && contentWindow.visible && root.shouldBeVisible && !root._settlingToOpen
        NumberAnimation {
            duration: Theme.variantDuration(root.animationDuration, root.renderedGeometryGrowing)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.renderedGeometryGrowing ? root.animationEnterCurve : root.animationExitCurve
        }
    }

    Behavior on renderedAlignedHeight {
        enabled: root.animationsEnabled && contentWindow.visible && root.shouldBeVisible && !root._settlingToOpen
        NumberAnimation {
            duration: Theme.variantDuration(root.animationDuration, root.renderedGeometryGrowing)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.renderedGeometryGrowing ? root.animationEnterCurve : root.animationExitCurve
        }
    }
    readonly property real connectedAnchorX: {
        if (!root.usesConnectedSurfaceChrome)
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
        if (!root.usesConnectedSurfaceChrome)
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
        if (!root.usesConnectedSurfaceChrome)
            return exclusion;
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
            const anchorX = root.usesConnectedSurfaceChrome ? connectedAnchorX : triggerX;

            switch (effectiveBarPosition) {
            case SettingsData.Position.Left:
                return Math.max(popupGap, Math.min(screenWidth - popupWidth - edgeGapRight, anchorX));
            case SettingsData.Position.Right:
                return Math.max(edgeGapLeft, Math.min(screenWidth - popupWidth - popupGap, anchorX - popupWidth));
            default:
                const rawX = triggerX + (triggerWidth / 2) - (popupWidth / 2);
                const clearLeft = adjacentBarClearance(adjacentBarInfo.leftBar);
                const clearRight = adjacentBarClearance(adjacentBarInfo.rightBar);
                const minX = Math.max(edgeGapLeft, clearLeft);
                const maxX = screenWidth - popupWidth - Math.max(edgeGapRight, clearRight);
                return _snapNearFrameBound(Math.max(minX, Math.min(maxX, rawX)), minX, maxX, edgeGapLeft >= clearLeft, edgeGapRight >= clearRight);
            }
        })(), dpr)

    readonly property real alignedY: Theme.snap((() => {
            const popupGap = _popupGapValue();
            const edgeGapTop = _edgeGapFor("top", popupGap);
            const edgeGapBottom = _edgeGapFor("bottom", popupGap);
            const anchorY = root.usesConnectedSurfaceChrome ? connectedAnchorY : triggerY;

            switch (effectiveBarPosition) {
            case SettingsData.Position.Bottom:
                return Math.max(edgeGapTop, Math.min(screenHeight - popupHeight - popupGap, anchorY - popupHeight));
            case SettingsData.Position.Top:
                return Math.max(popupGap, Math.min(screenHeight - popupHeight - edgeGapBottom, anchorY));
            default:
                const rawY = triggerY - (popupHeight / 2);
                const clearTop = adjacentBarClearance(adjacentBarInfo.topBar);
                const clearBottom = adjacentBarClearance(adjacentBarInfo.bottomBar);
                const minY = Math.max(edgeGapTop, clearTop);
                const maxY = screenHeight - popupHeight - Math.max(edgeGapBottom, clearBottom);
                return _snapNearFrameBound(Math.max(minY, Math.min(maxY, rawY)), minY, maxY, edgeGapTop >= clearTop, edgeGapBottom >= clearBottom);
            }
        })(), dpr)

    readonly property real maskX: _dismissZone.x
    readonly property real maskY: _dismissZone.y
    readonly property real maskWidth: _dismissZone.width
    readonly property real maskHeight: _dismissZone.height

    DismissZone {
        id: _dismissZone
        barPosition: root.effectiveBarPosition
        barX: root.barX
        barY: root.barY
        barWidth: root.barWidth
        barHeight: root.barHeight
        screenWidth: root.screenWidth
        screenHeight: root.screenHeight
        adjacentBarInfo: root.adjacentBarInfo
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
            readonly property bool trackBlurFromBarEdge: root.usesConnectedSurfaceChrome

            readonly property real _dyClamp: (contentContainer.barTop || contentContainer.barBottom) ? Math.max(-contentContainer.height, Math.min(contentContainer.animY, contentContainer.height)) : 0
            readonly property real _dxClamp: (contentContainer.barLeft || contentContainer.barRight) ? Math.max(-contentContainer.width, Math.min(contentContainer.animX, contentContainer.width)) : 0

            blurX: trackBlurFromBarEdge ? contentContainer.x + (contentContainer.barRight ? _dxClamp : 0) : contentContainer.x + contentContainer.width * (1 - s) * 0.5 + Theme.snap(contentContainer.animX, root.dpr) - contentContainer.horizontalConnectorExtent * s
            blurY: trackBlurFromBarEdge ? contentContainer.y + (contentContainer.barBottom ? _dyClamp : 0) : contentContainer.y + contentContainer.height * (1 - s) * 0.5 + Theme.snap(contentContainer.animY, root.dpr) - contentContainer.verticalConnectorExtent * s
            blurWidth: shouldBeVisible ? (trackBlurFromBarEdge ? Math.max(0, contentContainer.width - Math.abs(_dxClamp)) : (contentContainer.width + contentContainer.horizontalConnectorExtent * 2) * s) : 0
            blurHeight: shouldBeVisible ? (trackBlurFromBarEdge ? Math.max(0, contentContainer.height - Math.abs(_dyClamp)) : (contentContainer.height + contentContainer.verticalConnectorExtent * 2) * s) : 0
            blurRadius: root.usesConnectedSurfaceChrome ? Theme.connectedCornerRadius : Theme.cornerRadius
        }

        WlrLayershell.namespace: root.layerNamespace
        WlrLayershell.layer: root.effectivePopoutLayer
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: KeyboardFocus.keyboardFocus(shouldBeVisible || isClosing, customKeyboardFocus)

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
            item: (shouldBeVisible && backgroundInteractive) ? backgroundDismissalMask : contentMaskRect
        }

        Item {
            id: backgroundDismissalMask
            visible: false
            x: root.maskX
            y: root.maskY
            width: root.maskWidth
            height: root.maskHeight
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
            readonly property real surfaceRadius: root.usesConnectedSurfaceChrome ? Theme.connectedSurfaceRadius : Theme.cornerRadius
            readonly property color surfaceColor: root.usesConnectedSurfaceChrome ? Theme.connectedSurfaceColor : Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
            readonly property color surfaceBorderColor: root.usesConnectedSurfaceChrome ? "transparent" : (BlurService.enabled ? BlurService.borderColor : Theme.outlineMedium)
            readonly property real surfaceBorderWidth: root.usesConnectedSurfaceChrome ? 0 : BlurService.borderWidth
            readonly property real surfaceTopLeftRadius: root.usesConnectedSurfaceChrome && (barTop || barLeft) ? 0 : surfaceRadius
            readonly property real surfaceTopRightRadius: root.usesConnectedSurfaceChrome && (barTop || barRight) ? 0 : surfaceRadius
            readonly property real surfaceBottomLeftRadius: root.usesConnectedSurfaceChrome && (barBottom || barLeft) ? 0 : surfaceRadius
            readonly property real surfaceBottomRightRadius: root.usesConnectedSurfaceChrome && (barBottom || barRight) ? 0 : surfaceRadius
            readonly property bool directionalEffect: Theme.isDirectionalEffect
            readonly property bool depthEffect: Theme.isDepthEffect
            readonly property real directionalTravelX: Math.max(root.animationOffset, root.alignedWidth + Theme.spacingL)
            readonly property real directionalTravelY: Math.max(root.animationOffset, root.alignedHeight + Theme.spacingL)
            readonly property real depthTravel: Math.max(root.animationOffset * 0.7, 28)
            readonly property real sectionTilt: (triggerSection === "left" ? -1 : (triggerSection === "right" ? 1 : 0))
            readonly property real horizontalConnectorExtent: root.usesConnectedSurfaceChrome && (barTop || barBottom) ? Theme.connectedCornerRadius : 0
            readonly property real verticalConnectorExtent: root.usesConnectedSurfaceChrome && (barLeft || barRight) ? Theme.connectedCornerRadius : 0

            readonly property real offsetX: {
                if (directionalEffect) {
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

            readonly property real computedScaleCollapsed: root.animationScaleCollapsed

            QtObject {
                id: morph
                property real openProgress: 0
                Behavior on openProgress {
                    enabled: root.animationsEnabled
                    NumberAnimation {
                        id: morphAnim
                        duration: Theme.variantDuration(root.animationDuration, root.shouldBeVisible)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                    }
                }
            }

            readonly property real animX: contentContainer.offsetX * (1 - morph.openProgress)
            readonly property real animY: contentContainer.offsetY * (1 - morph.openProgress)
            readonly property real scaleValue: contentContainer.computedScaleCollapsed + (1.0 - contentContainer.computedScaleCollapsed) * morph.openProgress

            Component.onCompleted: {
                morph.openProgress = root.shouldBeVisible ? 1 : 0;
                root._captureChromeAnimTravel();
            }

            Connections {
                target: root
                function onShouldBeVisibleChanged() {
                    root._captureChromeAnimTravel();
                    morph.openProgress = root.shouldBeVisible ? 1 : 0;
                }
            }

            Item {
                id: directionalClipMask

                readonly property bool shouldClip: Theme.isDirectionalEffect || root.usesConnectedSurfaceChrome
                readonly property real clipOversize: 1000
                readonly property real connectedClipAllowance: {
                    if (!root.usesConnectedSurfaceChrome)
                        return 0;
                    if (root.frameOwnsConnectedChrome)
                        return 0;
                    return -Theme.connectedCornerRadius;
                }

                clip: shouldClip

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

                Item {
                    id: rollOutAdjuster
                    readonly property real baseWidth: contentContainer.width
                    readonly property real baseHeight: contentContainer.height

                    x: directionalClipMask.x !== 0 ? -directionalClipMask.x : 0
                    y: directionalClipMask.y !== 0 ? -directionalClipMask.y : 0
                    width: baseWidth
                    height: baseHeight

                    clip: false

                    ElevationShadow {
                        id: shadowSource
                        visible: !root.usesConnectedSurfaceChrome
                        width: rollOutAdjuster.baseWidth
                        height: rollOutAdjuster.baseHeight
                        opacity: contentWrapper.publishedOpacity
                        scale: contentWrapper.scale
                        x: contentWrapper.x
                        y: contentWrapper.y
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
                        shadowEnabled: Theme.elevationEnabled && SettingsData.popoutElevationEnabled && Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1" && !(root.suspendShadowWhileResizing && root._resizeActive) && !root.frameOwnsConnectedChrome
                    }

                    Item {
                        id: localChrome
                        visible: root.usesLocalConnectedSurfaceChrome

                        readonly property real extraLeft: (contentContainer.barTop || contentContainer.barBottom) ? Theme.connectedCornerRadius : 0
                        readonly property real extraTop: (contentContainer.barLeft || contentContainer.barRight) ? Theme.connectedCornerRadius : 0

                        readonly property bool shadowsOn: Theme.elevationEnabled && SettingsData.popoutElevationEnabled && Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1" && !(root.suspendShadowWhileResizing && root._resizeActive)
                        readonly property real shadowBlurPx: root.shadowLevel && root.shadowLevel.blurPx !== undefined ? root.shadowLevel.blurPx : 0
                        readonly property real shadowSpreadPx: root.shadowLevel && root.shadowLevel.spreadPx !== undefined ? root.shadowLevel.spreadPx : 0
                        readonly property real shadowOffsetX: Theme.elevationOffsetXFor(root.shadowLevel, root.effectiveShadowDirection, root.shadowFallbackOffset)
                        readonly property real shadowOffsetY: Theme.elevationOffsetYFor(root.shadowLevel, root.effectiveShadowDirection, root.shadowFallbackOffset)
                        readonly property color shadowTint: Theme.elevationShadowColor(root.shadowLevel)
                        readonly property var ambient: Theme.elevationAmbient(root.shadowLevel)
                        readonly property real pad: shadowsOn ? Math.ceil(Math.max(shadowBlurPx + shadowSpreadPx + Math.max(Math.abs(shadowOffsetX), Math.abs(shadowOffsetY)), ambient.blurPx + ambient.spreadPx) + 2) : 0

                        width: rollOutAdjuster.baseWidth + extraLeft * 2
                        height: rollOutAdjuster.baseHeight + extraTop * 2
                        opacity: contentWrapper.publishedOpacity
                        scale: contentWrapper.scale
                        x: contentWrapper.x - extraLeft
                        y: contentWrapper.y - extraTop

                        ShaderEffect {
                            anchors.fill: parent
                            anchors.topMargin: contentContainer.barTop ? 0 : -localChrome.pad
                            anchors.bottomMargin: contentContainer.barBottom ? 0 : -localChrome.pad
                            anchors.leftMargin: contentContainer.barLeft ? 0 : -localChrome.pad
                            anchors.rightMargin: contentContainer.barRight ? 0 : -localChrome.pad
                            fragmentShader: Qt.resolvedUrl("../Shaders/qsb/connected_chrome.frag.qsb")

                            property real widthPx: width
                            property real heightPx: height
                            property vector4d surfaceColor: Qt.vector4d(contentContainer.surfaceColor.r, contentContainer.surfaceColor.g, contentContainer.surfaceColor.b, contentContainer.surfaceColor.a)
                            property vector4d shadowColor: Qt.vector4d(localChrome.shadowTint.r, localChrome.shadowTint.g, localChrome.shadowTint.b, localChrome.shadowsOn ? localChrome.shadowTint.a : 0)
                            property vector4d shadowParam: Qt.vector4d(Math.max(0, localChrome.shadowBlurPx), localChrome.shadowSpreadPx, localChrome.shadowOffsetX, localChrome.shadowOffsetY)
                            property vector4d ambientParam: Qt.vector4d(localChrome.ambient.blurPx, localChrome.ambient.spreadPx, localChrome.shadowsOn ? localChrome.ambient.alpha : 0, 0)
                            property vector4d bodyRect: Qt.vector4d((contentContainer.barLeft ? 0 : localChrome.pad) + localChrome.extraLeft, (contentContainer.barTop ? 0 : localChrome.pad) + localChrome.extraTop, rollOutAdjuster.baseWidth, rollOutAdjuster.baseHeight)
                            property vector4d cornerRadius: Qt.vector4d(contentContainer.surfaceTopLeftRadius, contentContainer.surfaceTopRightRadius, contentContainer.surfaceBottomRightRadius, contentContainer.surfaceBottomLeftRadius)
                            property vector4d edgeParam: Qt.vector4d(contentContainer.barTop ? 0 : (contentContainer.barBottom ? 1 : (contentContainer.barLeft ? 2 : 3)), Theme.connectedCornerRadius, 0, 0)
                        }
                    }

                    Item {
                        id: contentWrapper
                        width: rollOutAdjuster.baseWidth
                        height: rollOutAdjuster.baseHeight

                        property bool _renderActive: Theme.isDirectionalEffect || shouldBeVisible
                        property bool _animating: false
                        property real publishedOpacity: Theme.isDirectionalEffect ? 1 : (shouldBeVisible ? 1 : 0)

                        opacity: Theme.isDirectionalEffect ? 1 : (shouldBeVisible ? 1 : 0)
                        visible: _renderActive

                        scale: contentContainer.scaleValue
                        x: Theme.snap(contentContainer.animX + (rollOutAdjuster.baseWidth - width) * (1 - scale) * 0.5, root.dpr)
                        y: Theme.snap(contentContainer.animY + (rollOutAdjuster.baseHeight - height) * (1 - scale) * 0.5, root.dpr)

                        layer.enabled: _animating || (!Theme.isDirectionalEffect && publishedOpacity < 1)
                        layer.smooth: false
                        layer.textureSize: root.dpr > 1 ? Qt.size(Math.ceil(width * root.dpr), Math.ceil(height * root.dpr)) : Qt.size(0, 0)

                        Behavior on opacity {
                            enabled: !Theme.isDirectionalEffect
                            NumberAnimation {
                                duration: Math.round(Theme.variantDuration(animationDuration, shouldBeVisible) * Theme.variantOpacityDurationScale)
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                                onRunningChanged: {
                                    contentWrapper._animating = running;
                                    if (!running && !root.shouldBeVisible)
                                        contentWrapper._renderActive = false;
                                }
                            }
                        }

                        Behavior on publishedOpacity {
                            enabled: !Theme.isDirectionalEffect
                            NumberAnimation {
                                duration: Math.round(Theme.variantDuration(animationDuration, shouldBeVisible) * Theme.variantOpacityDurationScale)
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                            }
                        }

                        Connections {
                            target: root
                            function onShouldBeVisibleChanged() {
                                if (root.shouldBeVisible)
                                    contentWrapper._renderActive = true;
                            }
                        }

                        Connections {
                            target: contentWindow
                            function onVisibleChanged() {
                                if (!contentWindow.visible && !root.shouldBeVisible)
                                    contentWrapper._renderActive = false;
                            }
                        }

                        Item {
                            anchors.fill: parent
                            clip: false
                            visible: !root.usesConnectedSurfaceChrome

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
