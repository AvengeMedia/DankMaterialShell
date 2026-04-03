import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    visible: false

    property bool spotlightOpen: false
    property bool keyboardActive: false
    property bool contentVisible: false
    readonly property bool launcherMotionVisible: Theme.isDirectionalEffect ? spotlightOpen : _motionActive
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
    readonly property real modalX: (screenWidth - modalWidth) / 2
    readonly property real modalY: (screenHeight - modalHeight) / 2

    readonly property bool connectedSurfaceOverride: Theme.isConnectedEffect
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

    // Shadow padding for the content window (render padding only, no motion padding)
    readonly property var shadowLevel: Theme.elevationLevel3
    readonly property real shadowFallbackOffset: 6
    readonly property real shadowRenderPadding: (Theme.elevationEnabled && SettingsData.modalElevationEnabled) ? Theme.elevationRenderPadding(shadowLevel, Theme.elevationLightDirection, shadowFallbackOffset, 8, 16) : 0
    readonly property real shadowPad: Theme.snap(shadowRenderPadding, dpr)
    readonly property real alignedWidth: Theme.px(modalWidth, dpr)
    readonly property real alignedHeight: Theme.px(modalHeight, dpr)
    readonly property real alignedX: Theme.snap(modalX, dpr)
    readonly property real alignedY: Theme.snap(modalY, dpr)

    // For directional/depth: window extends from screen top (content slides within)
    // For standard: small window tightly around the modal + shadow padding
    readonly property bool _needsExtendedWindow: (Theme.isDirectionalEffect && !Theme.isConnectedEffect) || Theme.isDepthEffect
    // Content window geometry
    readonly property real _cwMarginLeft: Theme.snap(alignedX - shadowPad, dpr)
    readonly property real _cwMarginTop: _needsExtendedWindow ? 0 : Theme.snap(alignedY - shadowPad, dpr)
    readonly property real _cwWidth: alignedWidth + shadowPad * 2
    readonly property real _cwHeight: {
        if (Theme.isDirectionalEffect && !Theme.isConnectedEffect)
            return screenHeight + shadowPad;
        if (Theme.isDepthEffect)
            return alignedY + alignedHeight + shadowPad;
        return alignedHeight + shadowPad * 2;
    }
    // Where the content container sits inside the content window
    readonly property real _ccX: shadowPad
    readonly property real _ccY: _needsExtendedWindow ? alignedY : shadowPad

    signal dialogClosed

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
        ModalManager.openModal(root);
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
        ModalManager.closeModal(root);
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
        interval: Theme.variantCloseInterval(Theme.modalAnimationDuration)
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
            if (excludedModal !== root && spotlightOpen) {
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

    // ── Background window: fullscreen, handles darkening + click-to-dismiss ──
    PanelWindow {
        id: backgroundWindow
        visible: false
        color: "transparent"

        WlrLayershell.namespace: "dms:spotlight:bg"
        WlrLayershell.layer: WlrLayershell.Top
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        WlrLayershell.margins {
            top: contentContainer.dockTop ? contentContainer.dockThickness : (typeof SettingsData !== "undefined" && SettingsData.barPosition === 0 ? Theme.px(42, root.dpr) : 0)
            bottom: contentContainer.dockBottom ? contentContainer.dockThickness : (typeof SettingsData !== "undefined" && SettingsData.barPosition === 1 ? Theme.px(42, root.dpr) : 0)
            left: contentContainer.dockLeft ? contentContainer.dockThickness : (typeof SettingsData !== "undefined" && SettingsData.barPosition === 2 ? Theme.px(42, root.dpr) : 0)
            right: contentContainer.dockRight ? contentContainer.dockThickness : (typeof SettingsData !== "undefined" && SettingsData.barPosition === 3 ? Theme.px(42, root.dpr) : 0)
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        mask: Region {
            item: (spotlightOpen || isClosing) ? bgFullScreenMask : null
        }

        Item {
            id: bgFullScreenMask
            anchors.fill: parent
        }

        Rectangle {
            id: backgroundDarken
            anchors.fill: parent
            color: "black"
            opacity: launcherMotionVisible && SettingsData.modalDarkenBackground ? 0.5 : 0
            visible: launcherMotionVisible || opacity > 0

            Behavior on opacity {
                enabled: root.animationsEnabled && (!Theme.isDirectionalEffect || Theme.isConnectedEffect)
                DankAnim {
                    duration: Math.round(Theme.variantDuration(Theme.modalAnimationDuration, launcherMotionVisible) * Theme.variantOpacityDurationScale)
                    easing.bezierCurve: launcherMotionVisible ? Theme.variantModalEnterCurve : Theme.variantModalExitCurve
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: spotlightOpen
            onClicked: root.hide()
        }
    }

    // ── Content window: SMALL, positioned with margins — only renders the modal area ──
    PanelWindow {
        id: contentWindow
        visible: false
        color: "transparent"

        WindowBlur {
            targetWindow: contentWindow
            blurEnabled: root.effectiveBlurEnabled
            readonly property real s: Math.min(1, contentContainer.scaleValue)
            blurX: root._ccX + root.alignedWidth * (1 - s) * 0.5 + Theme.snap(contentContainer.animX, root.dpr)
            blurY: root._ccY + root.alignedHeight * (1 - s) * 0.5 + Theme.snap(contentContainer.animY, root.dpr)
            blurWidth: (root.spotlightOpen || root.isClosing) && contentWrapper.opacity > 0 ? root.alignedWidth * s : 0
            blurHeight: (root.spotlightOpen || root.isClosing) && contentWrapper.opacity > 0 ? root.alignedHeight * s : 0
            blurRadius: root.cornerRadius
        }

        WlrLayershell.namespace: "dms:spotlight"
        WlrLayershell.layer: {
            switch (Quickshell.env("DMS_MODAL_LAYER")) {
            case "bottom":
                console.error("DankLauncherV2Modal: 'bottom' layer is not valid for modals. Defaulting to 'top' layer.");
                return WlrLayershell.Top;
            case "background":
                console.error("DankLauncherV2Modal: 'background' layer is not valid for modals. Defaulting to 'top' layer.");
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
            x: contentContainer.x + contentWrapper.x
            y: contentContainer.y + contentWrapper.y
            width: root.alignedWidth
            height: root.alignedHeight
        }

        Item {
            id: contentContainer

            // For directional/depth: contentContainer is at alignedY from window top (window starts at screen top)
            // For standard: contentContainer is at shadowPad from window top (window starts near modal)
            x: root._ccX
            y: root._ccY
            width: root.alignedWidth
            height: root.alignedHeight

            readonly property int dockEdge: typeof SettingsData !== "undefined" ? SettingsData.dockPosition : 1
            readonly property bool dockTop: dockEdge === 0
            readonly property bool dockBottom: dockEdge === 1
            readonly property bool dockLeft: dockEdge === 2
            readonly property bool dockRight: dockEdge === 3

            readonly property real dockThickness: typeof SettingsData !== "undefined" && SettingsData.showDock ? Theme.px(SettingsData.dockIconSize + (SettingsData.dockMargin * 2) + SettingsData.dockSpacing + 8, root.dpr) : Theme.px(60, root.dpr)

            readonly property bool directionalEffect: Theme.isDirectionalEffect
            readonly property bool depthEffect: Theme.isDepthEffect
            readonly property real collapsedMotionX: {
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

            // animX/animY are Behavior-animated — DankPopout pattern
            property real animX: 0
            property real animY: 0
            property real scaleValue: Theme.isDirectionalEffect && typeof SettingsData !== "undefined" && SettingsData.directionalAnimationMode === 2 ? Theme.effectScaleCollapsed : (Theme.isDirectionalEffect ? 1 : Theme.effectScaleCollapsed)

            Component.onCompleted: {
                animX = Theme.snap(root._motionActive ? 0 : collapsedMotionX, root.dpr);
                animY = Theme.snap(root._motionActive ? 0 : collapsedMotionY, root.dpr);
                scaleValue = root._motionActive ? 1.0 : (Theme.isDirectionalEffect && typeof SettingsData !== "undefined" && SettingsData.directionalAnimationMode === 2 ? Theme.effectScaleCollapsed : (Theme.isDirectionalEffect ? 1 : Theme.effectScaleCollapsed));
            }

            Connections {
                target: root
                function on_MotionActiveChanged() {
                    contentContainer.animX = Theme.snap(root._motionActive ? 0 : root._frozenMotionX, root.dpr);
                    contentContainer.animY = Theme.snap(root._motionActive ? 0 : root._frozenMotionY, root.dpr);
                    contentContainer.scaleValue = root._motionActive ? 1.0 : (Theme.isDirectionalEffect && typeof SettingsData !== "undefined" && SettingsData.directionalAnimationMode === 2 ? Theme.effectScaleCollapsed : (Theme.isDirectionalEffect ? 1 : Theme.effectScaleCollapsed));
                }
            }

            Behavior on animX {
                enabled: root.animationsEnabled
                DankAnim {
                    duration: Theme.variantDuration(Theme.modalAnimationDuration, root._motionActive)
                    easing.bezierCurve: root._motionActive ? Theme.variantModalEnterCurve : Theme.variantModalExitCurve
                }
            }

            Behavior on animY {
                enabled: root.animationsEnabled
                DankAnim {
                    duration: Theme.variantDuration(Theme.modalAnimationDuration, root._motionActive)
                    easing.bezierCurve: root._motionActive ? Theme.variantModalEnterCurve : Theme.variantModalExitCurve
                }
            }

            Behavior on scaleValue {
                enabled: root.animationsEnabled && (!Theme.isDirectionalEffect || (typeof SettingsData !== "undefined" && SettingsData.directionalAnimationMode === 2))
                DankAnim {
                    duration: Theme.variantDuration(Theme.modalAnimationDuration, root._motionActive)
                    easing.bezierCurve: root._motionActive ? Theme.variantModalEnterCurve : Theme.variantModalExitCurve
                }
            }

            Item {
                id: directionalClipMask
                readonly property bool shouldClip: Theme.isDirectionalEffect && typeof SettingsData !== "undefined" && SettingsData.directionalAnimationMode > 0
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
                        opacity: contentWrapper.opacity
                        scale: contentWrapper.scale
                        x: contentWrapper.x
                        y: contentWrapper.y
                        level: root.shadowLevel
                        fallbackOffset: root.shadowFallbackOffset
                        targetColor: root.backgroundColor
                        borderColor: root.effectiveBorderColor
                        borderWidth: root.effectiveBorderWidth
                        targetRadius: root.cornerRadius
                        shadowEnabled: Theme.elevationEnabled && SettingsData.modalElevationEnabled && Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1"
                    }

                    // contentWrapper moves inside static contentContainer — DankPopout pattern
                    Item {
                        id: contentWrapper
                        width: parent.width
                        height: parent.height
                        opacity: (Theme.isDirectionalEffect && !Theme.isConnectedEffect) ? 1 : (launcherMotionVisible ? 1 : 0)
                        visible: opacity > 0
                        scale: contentContainer.scaleValue
                        x: Theme.snap(contentContainer.animX + (parent.width - width) * (1 - contentContainer.scaleValue) * 0.5, root.dpr)
                        y: Theme.snap(contentContainer.animY + (parent.height - height) * (1 - contentContainer.scaleValue) * 0.5, root.dpr)

                        Behavior on opacity {
                            enabled: root.animationsEnabled && (!Theme.isDirectionalEffect || Theme.isConnectedEffect)
                            DankAnim {
                                duration: Math.round(Theme.variantDuration(Theme.modalAnimationDuration, launcherMotionVisible) * Theme.variantOpacityDurationScale)
                                easing.bezierCurve: launcherMotionVisible ? Theme.variantModalEnterCurve : Theme.variantModalExitCurve
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
