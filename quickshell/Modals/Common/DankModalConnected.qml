pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root
    readonly property var log: Log.scoped("DankModalConnected")

    property var modalHandle: root
    property string layerNamespace: "dms:modal"
    property alias content: contentLoader.sourceComponent
    property alias contentLoader: contentLoader
    property Item directContent: null
    property real modalWidth: 400
    property real modalHeight: 300
    property var targetScreen
    readonly property var effectiveScreen: contentWindow.screen ?? targetScreen
    readonly property real screenWidth: effectiveScreen?.width ?? 1920
    readonly property real screenHeight: effectiveScreen?.height ?? 1080
    readonly property real dpr: effectiveScreen ? CompositorService.getScreenScale(effectiveScreen) : 1
    property bool showBackground: true
    property real backgroundOpacity: 0.5
    property string positioning: "center"
    property point customPosition: Qt.point(0, 0)
    property bool closeOnEscapeKey: true
    property bool closeOnBackgroundClick: true
    property string animationType: "scale"

    // Opposite side from the launcher by default; subclasses may override
    property string preferredConnectedBarSide: SettingsData.frameModalEmergeSide

    readonly property bool frameConnectedMode: SettingsData.frameEnabled && Theme.isConnectedEffect && !!effectiveScreen && SettingsData.isScreenInPreferences(effectiveScreen, SettingsData.frameScreenPreferences)

    readonly property string resolvedConnectedBarSide: frameConnectedMode ? preferredConnectedBarSide : ""

    readonly property bool frameOwnsConnectedChrome: frameConnectedMode && resolvedConnectedBarSide !== "" && !allowStacking

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

    readonly property bool connectedMotionParity: Theme.isConnectedEffect
    property int animationDuration: connectedMotionParity ? Theme.popoutAnimationDuration : Theme.modalAnimationDuration
    property real animationScaleCollapsed: Theme.effectScaleCollapsed
    property real animationOffset: Theme.effectAnimOffset
    property list<real> animationEnterCurve: connectedMotionParity ? Theme.variantPopoutEnterCurve : Theme.variantModalEnterCurve
    property list<real> animationExitCurve: connectedMotionParity ? Theme.variantPopoutExitCurve : Theme.variantModalExitCurve
    property color backgroundColor: Theme.surfaceContainer
    property color borderColor: Theme.outlineMedium
    property real borderWidth: 0
    property real cornerRadius: Theme.cornerRadius
    readonly property bool connectedSurfaceOverride: Theme.isConnectedEffect
    readonly property color effectiveBackgroundColor: connectedSurfaceOverride ? Theme.connectedSurfaceColor : backgroundColor
    readonly property color effectiveBorderColor: connectedSurfaceOverride ? "transparent" : borderColor
    readonly property real effectiveBorderWidth: connectedSurfaceOverride ? 0 : borderWidth
    readonly property real effectiveCornerRadius: connectedSurfaceOverride ? Theme.connectedSurfaceRadius : cornerRadius
    readonly property bool effectiveBlurEnabled: Theme.connectedSurfaceBlurEnabled
    property bool enableShadow: true
    property alias modalFocusScope: focusScope
    property bool shouldBeVisible: false
    property bool shouldHaveFocus: shouldBeVisible
    property bool allowFocusOverride: false
    property bool allowStacking: false
    property bool keepContentLoaded: false
    property bool keepPopoutsOpen: false
    property var customKeyboardFocus: null
    property bool useOverlayLayer: false
    property real frozenMotionOffsetX: 0
    property real frozenMotionOffsetY: 0
    readonly property alias contentWindow: contentWindow
    readonly property alias clickCatcher: clickCatcher
    readonly property bool useHyprlandFocusGrab: CompositorService.useHyprlandFocusGrab
    readonly property bool useBackground: false
    readonly property bool useSingleWindow: CompositorService.isHyprland

    signal opened
    signal dialogClosed
    signal backgroundClicked

    // Coalesce per-channel dirty bits; one ConnectedModeState write per tick.
    Timer {
        id: _syncTimer
        interval: 0
        onTriggered: root._flushSync()
    }

    property bool animationsEnabled: true

    property string _chromeClaimId: ""
    property bool _fullSyncPending: false

    function _nextChromeClaimId() {
        return layerNamespace + ":modal:" + (new Date()).getTime() + ":" + Math.floor(Math.random() * 1000);
    }

    function _currentScreenName() {
        return effectiveScreen ? effectiveScreen.name : "";
    }

    function _publishModalChromeState(isClaim) {
        const screenName = _currentScreenName();
        if (!screenName)
            return;
        const state = {
            "visible": shouldBeVisible || contentWindow.visible,
            "barSide": resolvedConnectedBarSide,
            "bodyX": alignedX,
            "bodyY": alignedY,
            "bodyW": alignedWidth,
            "bodyH": alignedHeight,
            "animX": modalContainer ? modalContainer.animX : 0,
            "animY": modalContainer ? modalContainer.animY : 0,
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
        if (_dockBlocksEmergence && (shouldBeVisible || contentWindow.visible))
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
        if (!screenName || !modalContainer)
            return;
        ConnectedModeState.setModalAnim(screenName, modalContainer.animX, modalContainer.animY, _chromeClaimId);
    }

    function _syncModalBody() {
        if (!frameOwnsConnectedChrome || !_chromeClaimId)
            return;
        const screenName = _currentScreenName();
        if (!screenName)
            return;
        ConnectedModeState.setModalBody(screenName, alignedX, alignedY, alignedWidth, alignedHeight, _chromeClaimId);
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
    onResolvedConnectedBarSideChanged: _queueFullSync()
    onShouldBeVisibleChanged: _queueFullSync()
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

    function open() {
        closeTimer.stop();
        animationsEnabled = false;
        frozenMotionOffsetX = modalContainer ? modalContainer.offsetX : 0;
        frozenMotionOffsetY = modalContainer ? modalContainer.offsetY : animationOffset;

        const focusedScreen = CompositorService.getFocusedScreen();
        if (focusedScreen) {
            contentWindow.screen = focusedScreen;
            if (!useSingleWindow)
                clickCatcher.screen = focusedScreen;
        }

        if (Theme.isDirectionalEffect || root.useBackground) {
            if (!useSingleWindow)
                clickCatcher.visible = true;
            contentWindow.visible = true;
        }
        ModalManager.openModal(modalHandle);

        Qt.callLater(() => {
            animationsEnabled = true;
            shouldBeVisible = true;
            if (!useSingleWindow && !clickCatcher.visible)
                clickCatcher.visible = true;
            if (!contentWindow.visible)
                contentWindow.visible = true;
            shouldHaveFocus = false;
            Qt.callLater(() => shouldHaveFocus = Qt.binding(() => shouldBeVisible));
        });
    }

    function close() {
        if (modalContainer) {
            frozenMotionOffsetX = modalContainer.offsetX;
            frozenMotionOffsetY = modalContainer.offsetY;
        }
        shouldBeVisible = false;
        shouldHaveFocus = false;
        ModalManager.closeModal(modalHandle);
        closeTimer.restart();
    }

    function instantClose() {
        animationsEnabled = false;
        shouldBeVisible = false;
        shouldHaveFocus = false;
        ModalManager.closeModal(modalHandle);
        closeTimer.stop();
        contentWindow.visible = false;
        if (!useSingleWindow)
            clickCatcher.visible = false;
        dialogClosed();
        Qt.callLater(() => animationsEnabled = true);
    }

    function toggle() {
        shouldBeVisible ? close() : open();
    }

    Connections {
        target: ModalManager
        function onCloseAllModalsExcept(excludedModal) {
            if (excludedModal !== modalHandle && !allowStacking && shouldBeVisible)
                close();
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (!contentWindow.screen)
                return;
            const currentScreenName = contentWindow.screen.name;
            let screenStillExists = false;
            for (let i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === currentScreenName) {
                    screenStillExists = true;
                    break;
                }
            }
            if (screenStillExists)
                return;
            const newScreen = CompositorService.getFocusedScreen();
            if (newScreen) {
                contentWindow.screen = newScreen;
                if (!useSingleWindow)
                    clickCatcher.screen = newScreen;
            }
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.variantCloseInterval(animationDuration)
        onTriggered: {
            if (shouldBeVisible)
                return;
            contentWindow.visible = false;
            if (!useSingleWindow)
                clickCatcher.visible = false;
            dialogClosed();
        }
    }

    // shadowRenderPadding is zeroed when frame owns the chrome
    // Wayland then clips any content translating past
    readonly property var shadowLevel: Theme.elevationLevel3
    readonly property real shadowFallbackOffset: 6
    readonly property real shadowRenderPadding: (!frameOwnsConnectedChrome && root.enableShadow && Theme.elevationEnabled && SettingsData.modalElevationEnabled) ? Theme.elevationRenderPadding(shadowLevel, Theme.elevationLightDirection, shadowFallbackOffset, 8, 16) : 0
    readonly property real shadowMotionPadding: {
        if (Theme.isConnectedEffect)
            return 0;
        if (animationType === "slide")
            return 30;
        if (Theme.isDirectionalEffect)
            return Math.max(Math.max(0, animationOffset), Math.max(alignedWidth, alignedHeight) * 0.9);
        if (Theme.isDepthEffect)
            return Math.max(Math.max(0, animationOffset), Math.max(alignedWidth, alignedHeight) * 0.35);
        return Math.max(0, animationOffset);
    }
    readonly property real shadowBuffer: Theme.snap(shadowRenderPadding + shadowMotionPadding, dpr)
    readonly property real alignedWidth: Theme.px(modalWidth, dpr)
    readonly property real alignedHeight: Theme.px(modalHeight, dpr)

    function _frameEdgeInset(side) {
        if (!effectiveScreen)
            return 0;
        return SettingsData.frameEdgeInsetForSide(effectiveScreen, side);
    }

    // frameEdgeInsetForSide is the full inset; do not add frameBarSize
    readonly property real _connectedAlignedX: {
        switch (resolvedConnectedBarSide) {
        case "top":
        case "bottom":
            {
                const insetL = _frameEdgeInset("left");
                const insetR = _frameEdgeInset("right");
                const usable = Math.max(0, screenWidth - insetL - insetR);
                return insetL + Math.max(0, (usable - alignedWidth) / 2);
            }
        case "left":
            return _frameEdgeInset("left");
        case "right":
            return screenWidth - alignedWidth - _frameEdgeInset("right");
        }
        return 0;
    }

    readonly property real _connectedAlignedY: {
        switch (resolvedConnectedBarSide) {
        case "top":
            return _frameEdgeInset("top");
        case "bottom":
            return screenHeight - alignedHeight - _frameEdgeInset("bottom");
        case "left":
        case "right":
            {
                const insetT = _frameEdgeInset("top");
                const insetB = _frameEdgeInset("bottom");
                const usable = Math.max(0, screenHeight - insetT - insetB);
                return insetT + Math.max(0, (usable - alignedHeight) / 2);
            }
        }
        return 0;
    }

    readonly property real alignedX: Theme.snap(frameOwnsConnectedChrome ? _connectedAlignedX : (() => {
            switch (positioning) {
            case "center":
                return (screenWidth - alignedWidth) / 2;
            case "top-right":
                return Math.max(Theme.spacingL, screenWidth - alignedWidth - Theme.spacingL);
            case "custom":
                return customPosition.x;
            default:
                return 0;
            }
        })(), dpr)

    readonly property real alignedY: Theme.snap(frameOwnsConnectedChrome ? _connectedAlignedY : (() => {
            switch (positioning) {
            case "center":
                return (screenHeight - alignedHeight) / 2;
            case "top-right":
                return Theme.barHeight + Theme.spacingXS;
            case "custom":
                return customPosition.y;
            default:
                return 0;
            }
        })(), dpr)

    PanelWindow {
        id: clickCatcher
        visible: false
        color: "transparent"

        WlrLayershell.namespace: root.layerNamespace + ":clickcatcher"
        WlrLayershell.layer: WlrLayershell.Top
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        mask: Region {
            item: Rectangle {
                x: root.alignedX
                y: root.alignedY
                width: root.alignedWidth
                height: root.alignedHeight
            }
            intersection: Intersection.Xor
        }

        MouseArea {
            anchors.fill: parent
            enabled: !root.useSingleWindow && root.closeOnBackgroundClick && root.shouldBeVisible
            onClicked: root.backgroundClicked()
        }

        Rectangle {
            anchors.fill: parent
            z: -1
            color: "black"
            opacity: (!root.useSingleWindow && root.useBackground) ? (root.shouldBeVisible ? root.backgroundOpacity : 0) : 0
            visible: opacity > 0

            Behavior on opacity {
                enabled: root.animationsEnabled && (!Theme.isDirectionalEffect || Theme.isConnectedEffect)
                NumberAnimation {
                    duration: Math.round(Theme.variantDuration(root.animationDuration, root.shouldBeVisible) * Theme.variantOpacityDurationScale)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }
        }
    }

    PanelWindow {
        id: contentWindow
        visible: false
        color: "transparent"

        WindowBlur {
            targetWindow: contentWindow
            blurEnabled: root.effectiveBlurEnabled && !root.frameOwnsConnectedChrome
            readonly property real s: Math.min(1, modalContainer.scaleValue)
            blurX: modalContainer.x + modalContainer.width * (1 - s) * 0.5 + Theme.snap(modalContainer.animX, root.dpr)
            blurY: modalContainer.y + modalContainer.height * (1 - s) * 0.5 + Theme.snap(modalContainer.animY, root.dpr)
            blurWidth: (root.shouldBeVisible && !root.frameOwnsConnectedChrome) ? modalContainer.width * s : 0
            blurHeight: (root.shouldBeVisible && !root.frameOwnsConnectedChrome) ? modalContainer.height * s : 0
            blurRadius: root.effectiveCornerRadius
        }

        WlrLayershell.namespace: root.layerNamespace
        WlrLayershell.layer: {
            if (root.useOverlayLayer)
                return WlrLayershell.Overlay;
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
        WlrLayershell.keyboardFocus: {
            if (customKeyboardFocus !== null)
                return customKeyboardFocus;
            if (!shouldHaveFocus)
                return WlrKeyboardFocus.None;
            if (root.useHyprlandFocusGrab)
                return WlrKeyboardFocus.OnDemand;
            return WlrKeyboardFocus.Exclusive;
        }

        anchors {
            left: true
            top: true
            right: root.useSingleWindow
            bottom: root.useSingleWindow
        }

        readonly property real actualMarginLeft: root.useSingleWindow ? 0 : Math.max(0, Theme.snap(root.alignedX - shadowBuffer, dpr))
        readonly property real actualMarginTop: root.useSingleWindow ? 0 : Math.max(0, Theme.snap(root.alignedY - shadowBuffer, dpr))

        WlrLayershell.margins {
            left: actualMarginLeft
            top: actualMarginTop
            right: 0
            bottom: 0
        }

        implicitWidth: root.useSingleWindow ? 0 : root.alignedWidth + (shadowBuffer * 2)
        implicitHeight: root.useSingleWindow ? 0 : root.alignedHeight + (shadowBuffer * 2)

        onVisibleChanged: {
            if (visible) {
                opened();
            } else {
                if (Qt.inputMethod) {
                    Qt.inputMethod.hide();
                    Qt.inputMethod.reset();
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.useSingleWindow && root.closeOnBackgroundClick && root.shouldBeVisible
            z: -2
            onClicked: root.backgroundClicked()
        }

        Rectangle {
            anchors.fill: parent
            z: -1
            color: "black"
            opacity: (root.useSingleWindow && root.useBackground) ? (root.shouldBeVisible ? root.backgroundOpacity : 0) : 0
            visible: opacity > 0

            Behavior on opacity {
                enabled: root.animationsEnabled && (!Theme.isDirectionalEffect || Theme.isConnectedEffect)
                NumberAnimation {
                    duration: Math.round(Theme.variantDuration(root.animationDuration, root.shouldBeVisible) * Theme.variantOpacityDurationScale)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }
        }

        Item {
            id: modalContainer
            x: (root.useSingleWindow ? root.alignedX : (root.alignedX - contentWindow.actualMarginLeft)) + Theme.snap(animX, root.dpr)
            y: (root.useSingleWindow ? root.alignedY : (root.alignedY - contentWindow.actualMarginTop)) + Theme.snap(animY, root.dpr)

            width: root.alignedWidth
            height: root.alignedHeight

            MouseArea {
                anchors.fill: parent
                enabled: root.useSingleWindow && root.shouldBeVisible
                hoverEnabled: false
                acceptedButtons: Qt.AllButtons
                onPressed: mouse.accepted = true
                onClicked: mouse.accepted = true
                z: -1
            }

            readonly property bool slide: root.animationType === "slide"
            readonly property bool directionalEffect: Theme.isDirectionalEffect
            readonly property bool depthEffect: Theme.isDepthEffect
            readonly property real directionalTravel: Math.max(root.animationOffset, Math.max(root.alignedWidth, root.alignedHeight) * 0.8)
            readonly property real depthTravel: Math.max(root.animationOffset * 0.8, 36)
            readonly property real customAnchorX: root.alignedX + root.alignedWidth * 0.5
            readonly property real customAnchorY: root.alignedY + root.alignedHeight * 0.5
            readonly property real customDistLeft: customAnchorX
            readonly property real customDistRight: root.screenWidth - customAnchorX
            readonly property real customDistTop: customAnchorY
            readonly property real customDistBottom: root.screenHeight - customAnchorY
            // Connected emergence: travel from the resolved bar edge, matching DankPopout cadence.
            readonly property real connectedEmergenceTravelX: Math.max(root.animationOffset, root.alignedWidth + Theme.spacingL)
            readonly property real connectedEmergenceTravelY: Math.max(root.animationOffset, root.alignedHeight + Theme.spacingL)
            readonly property real offsetX: {
                if (root.frameOwnsConnectedChrome) {
                    switch (root.resolvedConnectedBarSide) {
                    case "left":
                        return -connectedEmergenceTravelX;
                    case "right":
                        return connectedEmergenceTravelX;
                    }
                    return 0;
                }
                if (slide && !directionalEffect && !depthEffect)
                    return 15;
                if (directionalEffect) {
                    switch (root.positioning) {
                    case "top-right":
                        return 0;
                    case "custom":
                        if (customDistLeft <= customDistRight && customDistLeft <= customDistTop && customDistLeft <= customDistBottom)
                            return -directionalTravel;
                        if (customDistRight <= customDistTop && customDistRight <= customDistBottom)
                            return directionalTravel;
                        return 0;
                    default:
                        return 0;
                    }
                }
                if (depthEffect) {
                    switch (root.positioning) {
                    case "top-right":
                        return 0;
                    case "custom":
                        if (customDistLeft <= customDistRight && customDistLeft <= customDistTop && customDistLeft <= customDistBottom)
                            return -depthTravel;
                        if (customDistRight <= customDistTop && customDistRight <= customDistBottom)
                            return depthTravel;
                        return 0;
                    default:
                        return 0;
                    }
                }
                return 0;
            }
            readonly property real offsetY: {
                if (root.frameOwnsConnectedChrome) {
                    switch (root.resolvedConnectedBarSide) {
                    case "top":
                        return -connectedEmergenceTravelY;
                    case "bottom":
                        return connectedEmergenceTravelY;
                    }
                    return 0;
                }
                if (slide && !directionalEffect && !depthEffect)
                    return -30;
                if (directionalEffect) {
                    switch (root.positioning) {
                    case "top-right":
                        return -Math.max(directionalTravel * 0.65, 96);
                    case "custom":
                        if (customDistTop <= customDistBottom && customDistTop <= customDistLeft && customDistTop <= customDistRight)
                            return -directionalTravel;
                        if (customDistBottom <= customDistLeft && customDistBottom <= customDistRight)
                            return directionalTravel;
                        return 0;
                    default:
                        // Default to sliding down from top when centered
                        return -Math.max(directionalTravel, root.screenHeight * 0.24);
                    }
                }
                if (depthEffect) {
                    switch (root.positioning) {
                    case "top-right":
                        return -depthTravel * 0.75;
                    case "custom":
                        if (customDistTop <= customDistBottom && customDistTop <= customDistLeft && customDistTop <= customDistRight)
                            return -depthTravel;
                        if (customDistBottom <= customDistLeft && customDistBottom <= customDistRight)
                            return depthTravel;
                        return depthTravel * 0.45;
                    default:
                        return -depthTravel;
                    }
                }
                return root.animationOffset;
            }

            readonly property real computedScaleCollapsed: root.animationScaleCollapsed

            // openProgress: 0 = closed (at frozenMotionOffset, scaleCollapsed), 1 = open (at 0, scale 1).
            QtObject {
                id: morph
                property real openProgress: root.shouldBeVisible ? 1 : 0
                Behavior on openProgress {
                    enabled: root.animationsEnabled
                    NumberAnimation {
                        duration: Theme.variantDuration(root.animationDuration, root.shouldBeVisible)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                    }
                }
            }

            readonly property real animX: root.frozenMotionOffsetX * (1 - morph.openProgress)
            readonly property real animY: root.frozenMotionOffsetY * (1 - morph.openProgress)
            readonly property real scaleValue: computedScaleCollapsed + (1.0 - computedScaleCollapsed) * morph.openProgress

            onAnimXChanged: if (root.frameOwnsConnectedChrome)
                root._queueAnimSync()
            onAnimYChanged: if (root.frameOwnsConnectedChrome)
                root._queueAnimSync()

            Item {
                id: contentContainer
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                clip: false

                Item {
                    id: animatedContent
                    anchors.fill: parent
                    clip: false

                    property real publishedOpacity: (Theme.isDirectionalEffect && !Theme.isConnectedEffect) ? 1 : (root.shouldBeVisible ? 1 : 0)

                    opacity: (Theme.isDirectionalEffect && !Theme.isConnectedEffect) ? 1 : (root.shouldBeVisible ? 1 : 0)
                    scale: modalContainer.scaleValue
                    transformOrigin: Item.Center

                    Behavior on opacity {
                        enabled: root.animationsEnabled && (!Theme.isDirectionalEffect || Theme.isConnectedEffect)
                        NumberAnimation {
                            duration: Math.round(Theme.variantDuration(animationDuration, root.shouldBeVisible) * Theme.variantOpacityDurationScale)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                        }
                    }

                    Behavior on publishedOpacity {
                        enabled: root.animationsEnabled && (!Theme.isDirectionalEffect || Theme.isConnectedEffect)
                        NumberAnimation {
                            duration: Math.round(Theme.variantDuration(animationDuration, root.shouldBeVisible) * Theme.variantOpacityDurationScale)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                        }
                    }

                    ElevationShadow {
                        id: modalShadowLayer
                        anchors.fill: parent
                        level: root.shadowLevel
                        fallbackOffset: root.shadowFallbackOffset
                        targetRadius: root.effectiveCornerRadius
                        targetColor: root.frameOwnsConnectedChrome ? "transparent" : root.effectiveBackgroundColor
                        borderColor: root.frameOwnsConnectedChrome ? "transparent" : root.effectiveBorderColor
                        borderWidth: root.frameOwnsConnectedChrome ? 0 : root.effectiveBorderWidth
                        shadowEnabled: !root.frameOwnsConnectedChrome && root.enableShadow && Theme.elevationEnabled && SettingsData.modalElevationEnabled && Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1"
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: root.effectiveCornerRadius
                        color: "transparent"
                        border.color: (root.connectedSurfaceOverride || root.frameOwnsConnectedChrome) ? "transparent" : BlurService.borderColor
                        border.width: (root.connectedSurfaceOverride || root.frameOwnsConnectedChrome) ? 0 : BlurService.borderWidth
                        z: 100
                    }

                    FocusScope {
                        anchors.fill: parent
                        focus: root.shouldBeVisible
                        clip: false

                        Item {
                            id: directContentWrapper
                            anchors.fill: parent
                            visible: root.directContent !== null
                            focus: true
                            clip: false

                            Component.onCompleted: {
                                if (root.directContent) {
                                    root.directContent.parent = directContentWrapper;
                                    root.directContent.anchors.fill = directContentWrapper;
                                    Qt.callLater(() => root.directContent.forceActiveFocus());
                                }
                            }

                            Connections {
                                target: root
                                function onDirectContentChanged() {
                                    if (root.directContent) {
                                        root.directContent.parent = directContentWrapper;
                                        root.directContent.anchors.fill = directContentWrapper;
                                        Qt.callLater(() => root.directContent.forceActiveFocus());
                                    }
                                }
                            }
                        }

                        Loader {
                            id: contentLoader
                            anchors.fill: parent
                            active: root.directContent === null && (root.keepContentLoaded || root.shouldBeVisible || contentWindow.visible)
                            asynchronous: false
                            focus: true
                            clip: false
                            visible: root.directContent === null

                            onLoaded: {
                                if (item) {
                                    Qt.callLater(() => item.forceActiveFocus());
                                }
                            }
                        }
                    }
                }
            }
        }

        FocusScope {
            id: focusScope
            objectName: "modalFocusScope"
            anchors.fill: parent
            visible: root.shouldBeVisible || contentWindow.visible
            focus: root.shouldBeVisible
            Keys.onEscapePressed: event => {
                if (root.closeOnEscapeKey && shouldHaveFocus) {
                    root.close();
                    event.accepted = true;
                }
            }
        }
    }
}
