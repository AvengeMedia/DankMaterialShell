pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root
    readonly property var log: Log.scoped("DankLauncherV2ModalConnected")

    property var modalHandle: root

    visible: false

    property bool spotlightOpen: false
    property bool keyboardActive: false
    property bool contentVisible: false
    readonly property bool launcherMotionVisible: Theme.isConnectedEffect ? _motionActive : (Theme.isDirectionalEffect ? spotlightOpen : _motionActive)
    property var spotlightContent: launcherContentLoader.item
    property bool openedFromOverview: false
    property bool isClosing: false
    property bool _windowEnabled: true
    property bool _pendingInitialize: false
    property string _pendingQuery: ""
    property string _pendingMode: ""
    readonly property bool unloadContentOnClose: SettingsData.dankLauncherV2UnloadOnClose

    // Animation state — matches DankPopout/DankModal pattern
    property bool animationsEnabled: true
    property bool _motionActive: false
    property real _frozenMotionX: 0
    property real _frozenMotionY: 0

    readonly property bool useHyprlandFocusGrab: CompositorService.useHyprlandFocusGrab
    readonly property var effectiveScreen: contentWindow.screen
    readonly property real screenWidth: effectiveScreen?.width ?? 1920
    readonly property real screenHeight: effectiveScreen?.height ?? 1080
    readonly property real dpr: effectiveScreen ? CompositorService.getScreenScale(effectiveScreen) : 1

    readonly property int baseWidth: {
        switch (SettingsData.dankLauncherV2Size) {
        case "micro":
            return 500;
        case "medium":
            return 720;
        case "large":
            return 860;
        default:
            return 620;
        }
    }
    readonly property int baseHeight: {
        switch (SettingsData.dankLauncherV2Size) {
        case "micro":
            return 480;
        case "medium":
            return 720;
        case "large":
            return 860;
        default:
            return 600;
        }
    }
    readonly property int modalWidth: Math.min(baseWidth, screenWidth - 100)
    readonly property int modalHeight: Math.min(baseHeight, screenHeight - 100)

    readonly property string preferredConnectedBarSide: SettingsData.frameLauncherEmergeSide

    readonly property bool frameConnectedMode: SettingsData.frameEnabled && Theme.isConnectedEffect && !!effectiveScreen && SettingsData.isScreenInPreferences(effectiveScreen, SettingsData.frameScreenPreferences)

    readonly property string resolvedConnectedBarSide: frameConnectedMode ? preferredConnectedBarSide : ""

    readonly property bool frameOwnsConnectedChrome: frameConnectedMode && resolvedConnectedBarSide !== ""
    readonly property bool launcherArcExtenderActive: frameOwnsConnectedChrome && SettingsData.frameLauncherArcExtender && (resolvedConnectedBarSide === "top" || resolvedConnectedBarSide === "bottom")

    function _dockOccupiesSide(side) {
        if (!SettingsData.showDock)
            return false;
        switch (side) {
        case "top":
            return SettingsData.dockPosition === SettingsData.Position.Top;
        case "bottom":
            return SettingsData.dockPosition === SettingsData.Position.Bottom;
        case "left":
            return SettingsData.dockPosition === SettingsData.Position.Left;
        case "right":
            return SettingsData.dockPosition === SettingsData.Position.Right;
        }
        return false;
    }
    readonly property bool _dockBlocksEmergence: frameOwnsConnectedChrome && _dockOccupiesSide(resolvedConnectedBarSide)

    function _frameEdgeInset(side) {
        if (!effectiveScreen)
            return 0;
        return SettingsData.frameEdgeInsetForSide(effectiveScreen, side);
    }

    // frameEdgeInsetForSide is the full inset; do not add frameBarSize.
    // Positions the modal flush to the emerge side, centered on the cross axis.
    readonly property var _connectedModalPos: {
        const fallback = {
            "x": (screenWidth - modalWidth) / 2,
            "y": (screenHeight - modalHeight) / 2
        };
        switch (resolvedConnectedBarSide) {
        case "top":
        case "bottom":
            {
                const insetL = _frameEdgeInset("left");
                const insetR = _frameEdgeInset("right");
                const insetT = _frameEdgeInset("top");
                const insetB = _frameEdgeInset("bottom");
                const usable = Math.max(0, screenWidth - insetL - insetR);
                const usableH = Math.max(0, screenHeight - insetT - insetB);
                return {
                    "x": insetL + Math.max(0, (usable - modalWidth) / 2),
                    "y": launcherArcExtenderActive ? insetT + Math.max(0, (usableH - modalHeight) / 2) : (resolvedConnectedBarSide === "top" ? insetT : screenHeight - modalHeight - insetB)
                };
            }
        case "left":
        case "right":
            {
                const insetT = _frameEdgeInset("top");
                const insetB = _frameEdgeInset("bottom");
                const usable = Math.max(0, screenHeight - insetT - insetB);
                return {
                    "x": resolvedConnectedBarSide === "left" ? _frameEdgeInset("left") : screenWidth - modalWidth - _frameEdgeInset("right"),
                    "y": insetT + Math.max(0, (usable - modalHeight) / 2)
                };
            }
        }
        return fallback;
    }

    readonly property real modalX: frameOwnsConnectedChrome ? _connectedModalPos.x : ((screenWidth - modalWidth) / 2)
    readonly property real modalY: frameOwnsConnectedChrome ? _connectedModalPos.y : ((screenHeight - modalHeight) / 2)

    readonly property bool connectedSurfaceOverride: Theme.isConnectedEffect
    readonly property int launcherAnimationDuration: Theme.isConnectedEffect ? Theme.popoutAnimationDuration : Theme.modalAnimationDuration
    readonly property list<real> launcherEnterCurve: Theme.isConnectedEffect ? Theme.variantPopoutEnterCurve : Theme.variantModalEnterCurve
    readonly property list<real> launcherExitCurve: Theme.isConnectedEffect ? Theme.variantPopoutExitCurve : Theme.variantModalExitCurve
    readonly property color backgroundColor: connectedSurfaceOverride ? Theme.connectedSurfaceColor : Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    readonly property real cornerRadius: connectedSurfaceOverride ? Theme.connectedSurfaceRadius : Theme.cornerRadius
    readonly property color borderColor: {
        if (!SettingsData.dankLauncherV2BorderEnabled)
            return Theme.outlineMedium;
        switch (SettingsData.dankLauncherV2BorderColor) {
        case "primary":
            return Theme.primary;
        case "secondary":
            return Theme.secondary;
        case "outline":
            return Theme.outline;
        case "surfaceText":
            return Theme.surfaceText;
        default:
            return Theme.primary;
        }
    }
    readonly property int borderWidth: SettingsData.dankLauncherV2BorderEnabled ? SettingsData.dankLauncherV2BorderThickness : 0
    readonly property color effectiveBorderColor: connectedSurfaceOverride ? "transparent" : borderColor
    readonly property int effectiveBorderWidth: connectedSurfaceOverride ? 0 : borderWidth
    readonly property bool effectiveBlurEnabled: Theme.connectedSurfaceBlurEnabled

    // Shadow padding for the content window (render padding only, no motion padding).
    // Zeroed when frame owns the chrome and Wayland clips past the bar edge
    readonly property var shadowLevel: Theme.elevationLevel3
    readonly property real shadowFallbackOffset: 6
    readonly property real shadowRenderPadding: (!frameOwnsConnectedChrome && Theme.elevationEnabled && SettingsData.modalElevationEnabled) ? Theme.elevationRenderPadding(shadowLevel, Theme.elevationLightDirection, shadowFallbackOffset, 8, 16) : 0
    readonly property real shadowPad: Theme.snap(shadowRenderPadding, dpr)
    readonly property real alignedWidth: Theme.px(modalWidth, dpr)
    readonly property real alignedHeight: Theme.px(modalHeight, dpr)
    readonly property real alignedX: Theme.snap(modalX, dpr)
    readonly property real alignedY: Theme.snap(modalY, dpr)
    readonly property real _connectedChromeX: alignedX
    readonly property real _connectedChromeY: {
        if (!launcherArcExtenderActive)
            return alignedY;
        return resolvedConnectedBarSide === "top" ? Theme.snap(_frameEdgeInset("top"), dpr) : alignedY;
    }
    readonly property real _connectedChromeWidth: alignedWidth
    readonly property real _connectedChromeHeight: {
        if (!launcherArcExtenderActive)
            return alignedHeight;
        if (resolvedConnectedBarSide === "top")
            return Theme.snap(Math.max(alignedHeight, alignedY + alignedHeight - _frameEdgeInset("top")), dpr);
        if (resolvedConnectedBarSide === "bottom")
            return Theme.snap(Math.max(alignedHeight, screenHeight - _frameEdgeInset("bottom") - alignedY), dpr);
        return alignedHeight;
    }
    readonly property real contentSurfaceHeight: launcherArcExtenderActive ? _connectedChromeHeight : alignedHeight

    // For directional/depth: window extends from screen top (content slides within)
    // For standard: small window tightly around the modal + shadow padding
    readonly property bool _needsExtendedWindow: (Theme.isDirectionalEffect && !Theme.isConnectedEffect) || Theme.isDepthEffect
    // Content window geometry
    readonly property real _cwMarginLeft: Theme.snap(alignedX - shadowPad, dpr)
    readonly property real _cwMarginTop: launcherArcExtenderActive ? _connectedChromeY : (_needsExtendedWindow ? 0 : Theme.snap(alignedY - shadowPad, dpr))
    readonly property real _cwWidth: alignedWidth + shadowPad * 2
    readonly property real _cwHeight: {
        if (launcherArcExtenderActive)
            return _connectedChromeHeight;
        if (Theme.isDirectionalEffect && !Theme.isConnectedEffect)
            return screenHeight + shadowPad;
        if (Theme.isDepthEffect)
            return alignedY + alignedHeight + shadowPad;
        return alignedHeight + shadowPad * 2;
    }
    // Where the content container sits inside the content window
    readonly property real _ccX: shadowPad
    readonly property real _ccY: launcherArcExtenderActive ? 0 : (_needsExtendedWindow ? alignedY : shadowPad)

    signal dialogClosed

    // Coalesce per-channel dirty bits; one ConnectedModeState write per tick.
    Timer {
        id: _syncTimer
        interval: 0
        onTriggered: root._flushSync()
    }

    property string _chromeClaimId: ""
    property bool _fullSyncPending: false

    function _nextChromeClaimId() {
        return "dms:launcher-v2:" + (new Date()).getTime() + ":" + Math.floor(Math.random() * 1000);
    }

    function _currentScreenName() {
        return effectiveScreen ? effectiveScreen.name : "";
    }

    function _publishModalChromeState(isClaim) {
        const screenName = _currentScreenName();
        if (!screenName)
            return;
        const state = {
            "visible": spotlightOpen || contentWindow.visible,
            "barSide": resolvedConnectedBarSide,
            "bodyX": _connectedChromeX,
            "bodyY": _connectedChromeY,
            "bodyW": _connectedChromeWidth,
            "bodyH": _connectedChromeHeight,
            "animX": contentContainer ? contentContainer.animX : 0,
            "animY": contentContainer ? contentContainer.animY : 0,
            "omitStartConnector": false,
            "omitEndConnector": false
        };
        if (isClaim)
            ConnectedModeState.claimModalState(screenName, state, _chromeClaimId);
        else
            ConnectedModeState.updateModalState(screenName, state, _chromeClaimId);
    }

    function _syncModalChromeState() {
        if (!frameOwnsConnectedChrome) {
            _releaseModalChrome();
            return;
        }
        const isClaim = !_chromeClaimId;
        if (!_chromeClaimId)
            _chromeClaimId = _nextChromeClaimId();
        _publishModalChromeState(isClaim);
        if (_dockBlocksEmergence && (spotlightOpen || contentWindow.visible))
            ConnectedModeState.requestDockRetract(_chromeClaimId, _currentScreenName(), resolvedConnectedBarSide);
        else
            ConnectedModeState.releaseDockRetract(_chromeClaimId);
    }

    property bool _animSyncQueued: false
    property bool _bodySyncQueued: false

    function _queueFullSync() {
        _fullSyncPending = true;
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
        const fullDirty = _fullSyncPending;
        const animDirty = _animSyncQueued;
        const bodyDirty = _bodySyncQueued;
        _fullSyncPending = false;
        _animSyncQueued = false;
        _bodySyncQueued = false;
        if (fullDirty)
            _syncModalChromeState();
        if (animDirty)
            _syncModalAnim();
        if (bodyDirty)
            _syncModalBody();
    }

    function _syncModalAnim() {
        if (!frameOwnsConnectedChrome || !_chromeClaimId)
            return;
        const screenName = _currentScreenName();
        if (!screenName || !contentContainer)
            return;
        ConnectedModeState.setModalAnim(screenName, contentContainer.animX, contentContainer.animY, _chromeClaimId);
    }

    function _syncModalBody() {
        if (!frameOwnsConnectedChrome || !_chromeClaimId)
            return;
        const screenName = _currentScreenName();
        if (!screenName)
            return;
        ConnectedModeState.setModalBody(screenName, _connectedChromeX, _connectedChromeY, _connectedChromeWidth, _connectedChromeHeight, _chromeClaimId);
    }

    function _releaseModalChrome() {
        if (!_chromeClaimId)
            return;
        ConnectedModeState.releaseDockRetract(_chromeClaimId);
        const claimId = _chromeClaimId;
        _chromeClaimId = "";
        const screenName = _currentScreenName();
        if (screenName)
            ConnectedModeState.clearModalState(screenName, claimId);
    }

    onFrameOwnsConnectedChromeChanged: _syncModalChromeState()
    onLauncherArcExtenderActiveChanged: _queueFullSync()
    onResolvedConnectedBarSideChanged: _queueFullSync()
    onSpotlightOpenChanged: _queueFullSync()
    onAlignedXChanged: _queueBodySync()
    onAlignedYChanged: _queueBodySync()
    onAlignedWidthChanged: _queueBodySync()
    onAlignedHeightChanged: _queueBodySync()

    Component.onDestruction: _releaseModalChrome()

    Connections {
        target: contentWindow
        function onVisibleChanged() {
            if (contentWindow.visible)
                root._syncModalChromeState();
            else
                root._releaseModalChrome();
        }
    }

    function _ensureContentLoadedAndInitialize(query, mode) {
        _pendingQuery = query || "";
        _pendingMode = mode || "";
        _pendingInitialize = true;
        contentVisible = true;
        launcherContentLoader.active = true;

        if (spotlightContent) {
            _initializeAndShow(_pendingQuery, _pendingMode);
            _pendingInitialize = false;
        }
    }

    function _initializeAndShow(query, mode) {
        if (!spotlightContent)
            return;
        contentVisible = true;
        // NOTE: forceActiveFocus() is deliberately NOT called here.
        // It is deferred to after animation starts to avoid compositor IPC stalls.

        if (spotlightContent.searchField) {
            spotlightContent.searchField.text = query;
        }
        if (spotlightContent.controller) {
            var targetMode = mode || SessionData.launcherLastMode || "all";
            spotlightContent.controller.searchMode = targetMode;
            spotlightContent.controller.activePluginId = "";
            spotlightContent.controller.activePluginName = "";
            spotlightContent.controller.pluginFilter = "";
            spotlightContent.controller.fileSearchType = "all";
            spotlightContent.controller.fileSearchExt = "";
            spotlightContent.controller.fileSearchFolder = "";
            spotlightContent.controller.fileSearchSort = "score";
            spotlightContent.controller.collapsedSections = {};
            spotlightContent.controller.selectedFlatIndex = 0;
            spotlightContent.controller.selectedItem = null;
            if (query) {
                spotlightContent.controller.setSearchQuery(query);
            } else {
                spotlightContent.controller.searchQuery = "";
                spotlightContent.controller.performSearch();
            }
        }
        if (spotlightContent.resetScroll) {
            spotlightContent.resetScroll();
        }
        if (spotlightContent.actionPanel) {
            spotlightContent.actionPanel.hide();
        }
    }

    function _openCommon(query, mode) {
        closeCleanupTimer.stop();
        isClosing = false;
        openedFromOverview = false;

        // Disable animations so the snap is instant
        animationsEnabled = false;

        // Freeze the collapsed offsets (they depend on height which could change)
        _frozenMotionX = contentContainer ? contentContainer.collapsedMotionX : 0;
        _frozenMotionY = contentContainer ? contentContainer.collapsedMotionY : (Theme.isDirectionalEffect ? Math.max(root.screenHeight - root._ccY + root.shadowPad, Theme.effectAnimOffset * 1.1) : -Theme.effectAnimOffset);

        var focusedScreen = CompositorService.getFocusedScreen();
        if (focusedScreen) {
            backgroundWindow.screen = focusedScreen;
            contentWindow.screen = focusedScreen;
        }

        // _motionActive = false ensures motionX/Y snap to frozen collapsed position
        _motionActive = false;

        // Make windows visible but do NOT request keyboard focus yet
        ModalManager.openModal(modalHandle);
        spotlightOpen = true;
        backgroundWindow.visible = true;
        contentWindow.visible = true;
        if (useHyprlandFocusGrab)
            focusGrab.active = true;

        // Load content and initialize (but no forceActiveFocus — that's deferred)
        _ensureContentLoadedAndInitialize(query || "", mode || "");

        // Frame 1: enable animations and trigger enter motion
        Qt.callLater(() => {
            root.animationsEnabled = true;
            root._motionActive = true;

            // Frame 2: request keyboard focus + activate search field
            // Double-deferred to avoid compositor IPC competing with animation frames
            Qt.callLater(() => {
                root.keyboardActive = true;
                if (root.spotlightContent && root.spotlightContent.searchField)
                    root.spotlightContent.searchField.forceActiveFocus();
            });
        });
    }

    function show() {
        _openCommon("", "");
    }

    function showWithQuery(query) {
        _openCommon(query, "");
    }

    function hide() {
        if (!spotlightOpen)
            return;
        openedFromOverview = false;
        isClosing = true;
        // For directional effects, defer contentVisible=false so content stays rendered during exit slide
        if (!Theme.isDirectionalEffect)
            contentVisible = false;

        // Trigger exit animation — Behaviors will animate motionX/Y to frozen collapsed position
        _motionActive = false;

        keyboardActive = false;
        spotlightOpen = false;
        focusGrab.active = false;
        ModalManager.closeModal(modalHandle);
        closeCleanupTimer.start();
    }

    function toggle() {
        spotlightOpen ? hide() : show();
    }

    function showWithMode(mode) {
        _openCommon("", mode);
    }

    function toggleWithMode(mode) {
        if (spotlightOpen) {
            hide();
        } else {
            showWithMode(mode);
        }
    }

    function toggleWithQuery(query) {
        if (spotlightOpen) {
            hide();
        } else {
            showWithQuery(query);
        }
    }

    Timer {
        id: closeCleanupTimer
        interval: Theme.variantCloseInterval(root.launcherAnimationDuration)
        repeat: false
        onTriggered: {
            isClosing = false;
            contentVisible = false;
            contentWindow.visible = false;
            backgroundWindow.visible = false;
            if (root.unloadContentOnClose)
                launcherContentLoader.active = false;
            dialogClosed();
        }
    }

    Connections {
        target: spotlightContent?.controller ?? null
        function onModeChanged(mode) {
            if (spotlightContent.controller.autoSwitchedToFiles)
                return;
            SessionData.setLauncherLastMode(mode);
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [contentWindow]
        active: false

        onCleared: {
            if (spotlightOpen) {
                hide();
            }
        }
    }

    Connections {
        target: ModalManager
        function onCloseAllModalsExcept(excludedModal) {
            if (excludedModal !== modalHandle && spotlightOpen) {
                hide();
            }
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (Quickshell.screens.length === 0)
                return;

            const screen = contentWindow.screen;
            const screenName = screen?.name;

            let needsReset = !screen || !screenName;
            if (!needsReset) {
                needsReset = true;
                for (let i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === screenName) {
                        needsReset = false;
                        break;
                    }
                }
            }

            if (!needsReset)
                return;

            const newScreen = CompositorService.getFocusedScreen() ?? Quickshell.screens[0];
            if (!newScreen)
                return;

            root._windowEnabled = false;
            backgroundWindow.screen = newScreen;
            contentWindow.screen = newScreen;
            Qt.callLater(() => {
                root._windowEnabled = true;
            });
        }
    }

    PanelWindow {
        id: backgroundWindow
        visible: false
        color: "transparent"

        readonly property real _topMargin: contentContainer.dockTop ? contentContainer.dockThickness : (typeof SettingsData !== "undefined" && SettingsData.barPosition === 0 ? Theme.px(42, root.dpr) : 0)
        readonly property real _bottomMargin: contentContainer.dockBottom ? contentContainer.dockThickness : (typeof SettingsData !== "undefined" && SettingsData.barPosition === 1 ? Theme.px(42, root.dpr) : 0)
        readonly property real _leftMargin: contentContainer.dockLeft ? contentContainer.dockThickness : (typeof SettingsData !== "undefined" && SettingsData.barPosition === 2 ? Theme.px(42, root.dpr) : 0)
        readonly property real _rightMargin: contentContainer.dockRight ? contentContainer.dockThickness : (typeof SettingsData !== "undefined" && SettingsData.barPosition === 3 ? Theme.px(42, root.dpr) : 0)

        WlrLayershell.namespace: "dms:spotlight:bg"
        WlrLayershell.layer: WlrLayershell.Top
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        WlrLayershell.margins {
            top: backgroundWindow._topMargin
            bottom: backgroundWindow._bottomMargin
            left: backgroundWindow._leftMargin
            right: backgroundWindow._rightMargin
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        mask: Region {
            item: (spotlightOpen || isClosing) ? bgFullScreenMask : null

            Region {
                item: bgContentHole
                intersection: Intersection.Subtract
            }
        }

        Item {
            id: bgFullScreenMask
            anchors.fill: parent
        }

        Item {
            id: bgContentHole
            visible: false
            x: root._cwMarginLeft + contentContainer.x - backgroundWindow._leftMargin
            y: root._cwMarginTop + contentContainer.y - backgroundWindow._topMargin
            width: root.alignedWidth
            height: root.contentSurfaceHeight
        }

        Rectangle {
            id: backgroundDarken
            anchors.fill: parent
            color: "black"
            opacity: 0
            visible: false
        }

        MouseArea {
            anchors.fill: parent
            enabled: spotlightOpen
            onClicked: root.hide()
        }
    }

    PanelWindow {
        id: contentWindow
        visible: false
        color: "transparent"

        WindowBlur {
            targetWindow: contentWindow
            blurEnabled: root.effectiveBlurEnabled && !root.frameOwnsConnectedChrome
            readonly property real s: Math.min(1, contentContainer.scaleValue)
            blurX: root._ccX + root.alignedWidth * (1 - s) * 0.5 + Theme.snap(contentContainer.animX, root.dpr)
            blurY: root._ccY + root.alignedHeight * (1 - s) * 0.5 + Theme.snap(contentContainer.animY, root.dpr)
            blurWidth: (root.spotlightOpen || root.isClosing) && !root.frameOwnsConnectedChrome ? root.alignedWidth * s : 0
            blurHeight: (root.spotlightOpen || root.isClosing) && !root.frameOwnsConnectedChrome ? root.alignedHeight * s : 0
            blurRadius: root.cornerRadius
        }

        WlrLayershell.namespace: "dms:spotlight"
        WlrLayershell.layer: {
            switch (Quickshell.env("DMS_MODAL_LAYER")) {
            case "bottom":
                log.error("'bottom' layer is not valid for modals. Defaulting to 'top' layer.");
                return WlrLayershell.Top;
            case "background":
                log.error("'background' layer is not valid for modals. Defaulting to 'top' layer.");
                return WlrLayershell.Top;
            case "overlay":
                return WlrLayershell.Overlay;
            default:
                return WlrLayershell.Top;
            }
        }
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: keyboardActive ? (root.useHyprlandFocusGrab ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

        anchors {
            left: true
            top: true
        }

        WlrLayershell.margins {
            left: root._cwMarginLeft
            top: root._cwMarginTop
        }

        implicitWidth: root._cwWidth
        implicitHeight: root._cwHeight

        mask: Region {
            item: contentInputMask
        }

        Item {
            id: contentInputMask
            visible: false
            x: contentContainer.x
            y: contentContainer.y
            width: root.alignedWidth
            height: root.contentSurfaceHeight
        }

        Item {
            id: contentContainer

            // For directional/depth: contentContainer is at alignedY from window top (window starts at screen top)
            // For standard: contentContainer is at shadowPad from window top (window starts near modal)
            x: root._ccX
            y: root._ccY
            width: root.alignedWidth
            height: root.contentSurfaceHeight

            readonly property int dockEdge: typeof SettingsData !== "undefined" ? SettingsData.dockPosition : 1
            readonly property bool dockTop: dockEdge === 0
            readonly property bool dockBottom: dockEdge === 1
            readonly property bool dockLeft: dockEdge === 2
            readonly property bool dockRight: dockEdge === 3

            readonly property real dockThickness: typeof SettingsData !== "undefined" && SettingsData.showDock ? Theme.px(SettingsData.dockIconSize + (SettingsData.dockMargin * 2) + SettingsData.dockSpacing + 8, root.dpr) : Theme.px(60, root.dpr)

            readonly property bool directionalEffect: Theme.isDirectionalEffect
            readonly property bool depthEffect: Theme.isDepthEffect
            readonly property real _connectedTravelX: Math.max(Theme.effectAnimOffset, root.alignedWidth + Theme.spacingL)
            readonly property real _connectedTravelY: root.launcherArcExtenderActive ? root._connectedChromeHeight : Math.max(Theme.effectAnimOffset, root.alignedHeight + Theme.spacingL)
            readonly property real collapsedMotionX: {
                if (root.frameOwnsConnectedChrome) {
                    switch (root.resolvedConnectedBarSide) {
                    case "left":
                        return -_connectedTravelX;
                    case "right":
                        return _connectedTravelX;
                    }
                    return 0;
                }
                if (directionalEffect) {
                    if (dockLeft)
                        return -(root._ccX + root.alignedWidth + Theme.effectAnimOffset);
                    if (dockRight)
                        return root.screenWidth - root._ccX + Theme.effectAnimOffset;
                }
                if (depthEffect)
                    return Theme.effectAnimOffset * 0.25;
                return 0;
            }
            readonly property real collapsedMotionY: {
                if (root.frameOwnsConnectedChrome) {
                    switch (root.resolvedConnectedBarSide) {
                    case "top":
                        return -_connectedTravelY;
                    case "bottom":
                        return _connectedTravelY;
                    }
                    return 0;
                }
                if (directionalEffect) {
                    if (dockTop)
                        return -(root._ccY + root.alignedHeight + Theme.effectAnimOffset);
                    if (dockBottom)
                        return root.screenHeight - root._ccY + root.shadowPad + Theme.effectAnimOffset;
                    return 0;
                }
                if (depthEffect)
                    return -Math.max(Theme.effectAnimOffset * 0.85, 34);
                return -Math.max((root.shadowPad || 0) + Theme.effectAnimOffset, 40);
            }

            // openProgress: 0 = closed (at frozenMotion, scaleCollapsed), 1 = open (at 0, scale 1).
            QtObject {
                id: morph
                property real openProgress: root._motionActive ? 1 : 0
                Behavior on openProgress {
                    enabled: root.animationsEnabled
                    DankAnim {
                        duration: Theme.variantDuration(root.launcherAnimationDuration, root._motionActive)
                        easing.bezierCurve: root._motionActive ? root.launcherEnterCurve : root.launcherExitCurve
                    }
                }
            }

            readonly property real animX: root._frozenMotionX * (1 - morph.openProgress)
            readonly property real animY: root._frozenMotionY * (1 - morph.openProgress)
            readonly property real scaleValue: Theme.effectScaleCollapsed + (1.0 - Theme.effectScaleCollapsed) * morph.openProgress

            onAnimXChanged: if (root.frameOwnsConnectedChrome)
                root._queueAnimSync()
            onAnimYChanged: if (root.frameOwnsConnectedChrome)
                root._queueAnimSync()

            Item {
                id: directionalClipMask
                readonly property bool shouldClip: Theme.isDirectionalEffect
                readonly property real clipOversize: 2000

                clip: shouldClip

                x: shouldClip ? (contentContainer.dockRight ? -clipOversize : (contentContainer.dockLeft ? contentContainer.dockThickness - root._ccX : -clipOversize)) : 0
                y: shouldClip ? (contentContainer.dockBottom ? -clipOversize : (contentContainer.dockTop ? contentContainer.dockThickness - root._ccY : -clipOversize)) : 0

                width: shouldClip ? parent.width + clipOversize + (contentContainer.dockRight ? (root.screenWidth - contentContainer.dockThickness - root._ccX - parent.width) : (contentContainer.dockLeft ? clipOversize : clipOversize)) : parent.width
                height: shouldClip ? parent.height + clipOversize + (contentContainer.dockBottom ? (root.screenHeight - contentContainer.dockThickness - root._ccY - parent.height) : (contentContainer.dockTop ? clipOversize : clipOversize)) : parent.height

                Item {
                    id: aligner
                    x: directionalClipMask.x !== 0 ? -directionalClipMask.x : 0
                    y: directionalClipMask.y !== 0 ? -directionalClipMask.y : 0
                    width: contentContainer.width
                    height: contentContainer.height

                    // Shadow mirrors contentWrapper position/scale/opacity
                    ElevationShadow {
                        id: launcherShadowLayer
                        width: parent.width
                        height: parent.height
                        opacity: contentWrapper.publishedOpacity
                        scale: contentWrapper.scale
                        x: contentWrapper.x
                        y: contentWrapper.y
                        level: root.shadowLevel
                        fallbackOffset: root.shadowFallbackOffset
                        targetColor: root.frameOwnsConnectedChrome ? "transparent" : root.backgroundColor
                        borderColor: root.frameOwnsConnectedChrome ? "transparent" : root.effectiveBorderColor
                        borderWidth: root.frameOwnsConnectedChrome ? 0 : root.effectiveBorderWidth
                        targetRadius: root.cornerRadius
                        shadowEnabled: !root.frameOwnsConnectedChrome && Theme.elevationEnabled && SettingsData.modalElevationEnabled && Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1"
                    }

                    // contentWrapper moves inside static contentContainer — DankPopout pattern
                    Item {
                        id: contentWrapper
                        width: parent.width
                        height: parent.height

                        property bool _renderActive: (Theme.isDirectionalEffect && !Theme.isConnectedEffect) || launcherMotionVisible
                        property real publishedOpacity: (Theme.isDirectionalEffect && !Theme.isConnectedEffect) ? 1 : (launcherMotionVisible ? 1 : 0)

                        opacity: (Theme.isDirectionalEffect && !Theme.isConnectedEffect) ? 1 : (launcherMotionVisible ? 1 : 0)
                        visible: _renderActive
                        scale: contentContainer.scaleValue
                        x: Theme.snap(contentContainer.animX + (parent.width - width) * (1 - contentContainer.scaleValue) * 0.5, root.dpr)
                        y: Theme.snap(contentContainer.animY + (parent.height - height) * (1 - contentContainer.scaleValue) * 0.5, root.dpr)

                        Behavior on opacity {
                            enabled: root.animationsEnabled && (!Theme.isDirectionalEffect || Theme.isConnectedEffect)
                            NumberAnimation {
                                easing.type: Easing.BezierSpline
                                duration: Math.round(Theme.variantDuration(root.launcherAnimationDuration, launcherMotionVisible) * Theme.variantOpacityDurationScale)
                                easing.bezierCurve: launcherMotionVisible ? root.launcherEnterCurve : root.launcherExitCurve
                            }
                        }

                        Behavior on publishedOpacity {
                            enabled: root.animationsEnabled && (!Theme.isDirectionalEffect || Theme.isConnectedEffect)
                            NumberAnimation {
                                easing.type: Easing.BezierSpline
                                duration: Math.round(Theme.variantDuration(root.launcherAnimationDuration, launcherMotionVisible) * Theme.variantOpacityDurationScale)
                                easing.bezierCurve: launcherMotionVisible ? root.launcherEnterCurve : root.launcherExitCurve
                                onRunningChanged: if (!running && contentWrapper.publishedOpacity === 0)
                                    contentWrapper._renderActive = false
                            }
                        }

                        Connections {
                            target: root
                            function onLauncherMotionVisibleChanged() {
                                if (root.launcherMotionVisible)
                                    contentWrapper._renderActive = true;
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: mouse => mouse.accepted = true
                        }

                        FocusScope {
                            anchors.fill: parent
                            focus: keyboardActive

                            Loader {
                                id: launcherContentLoader
                                anchors.fill: parent
                                active: !root.unloadContentOnClose || root.spotlightOpen || root.isClosing || root.contentVisible || root._pendingInitialize
                                asynchronous: false
                                sourceComponent: LauncherContent {
                                    focus: true
                                    parentModal: root
                                }

                                onLoaded: {
                                    if (root._pendingInitialize) {
                                        root._initializeAndShow(root._pendingQuery, root._pendingMode);
                                        root._pendingInitialize = false;
                                    }
                                }
                            }

                            Keys.onEscapePressed: event => {
                                root.hide();
                                event.accepted = true;
                            }
                        }
                    } // contentWrapper
                } // aligner
            } // directionalClipMask
        } // contentContainer
    } // PanelWindow
}
