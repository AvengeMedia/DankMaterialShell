pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

Item {
    id: root

    readonly property var log: Log.scoped("DankPopoutStandalone")

    property var popoutHandle: root
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
    property bool isClosing: false
    property bool animationsEnabled: true
    property var customKeyboardFocus: null
    property bool backgroundInteractive: true
    property bool contentHandlesKeys: false
    property bool fullHeightSurface: false
    property bool _primeContent: false
    property bool _resizeActive: false
    property real _surfaceMarginLeft: 0
    property real _surfaceMarginTop: 0
    property real _surfaceW: 0
    property real _surfaceH: 0
    property real _surfaceBodyX: 0
    property real _surfaceBodyY: 0
    property real _surfaceBodyW: 0
    property real _surfaceBodyH: 0

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
    readonly property bool frameOnlyNoConnected: SettingsData.frameEnabled && !!screen && SettingsData.isScreenInPreferences(screen, SettingsData.frameScreenPreferences)
    readonly property bool fluidStandaloneActive: Theme.isDirectionalEffect
    readonly property bool backgroundDismissWindowRequired: backgroundInteractive
    readonly property bool backgroundWindowRequired: backgroundDismissWindowRequired || root.overlayContent !== null
    readonly property bool _fullHeight: fullHeightSurface

    function _frameEdgeInset(side) {
        if (!screen)
            return 0;
        return SettingsData.frameEdgeInsetForSide(screen, side);
    }

    function _frameGapMargin(side) {
        return _frameEdgeInset(side) + Theme.popupDistance;
    }

    function _edgeClearance(side, popupGap, adjacentInset) {
        if (frameOnlyNoConnected)
            return Math.max(adjacentInset, _frameGapMargin(side));
        return adjacentInset > 0 ? adjacentInset : popupGap;
    }

    readonly property real effectiveBarThickness: {
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

    signal opened
    signal popoutClosed
    signal backgroundClicked

    property var _lastOpenedScreen: null

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

    // Snapshot mask geometry to prevent background damage on bar updates
    property real _frozenMaskX: 0
    property real _frozenMaskY: 0
    property real _frozenMaskWidth: 0
    property real _frozenMaskHeight: 0

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

    // Briefly forces backgroundWindow.updatesEnabled true while the surface
    // body changes, so the contentHoleRect mask carve-out commits to the
    // compositor — otherwise the input region stays stuck at the popup's
    // initial size and clicks in any newly-grown area dismiss the popup.
    // Cleared by the frameSwapped Connections below as soon as the dirty
    // frame ships, so the bg window goes back to skipping buffer updates.
    property bool _bgCommitWindow: false

    function _setSurfaceGeometry(bodyX, bodyY, bodyW, bodyH) {
        const newX = Theme.snap(bodyX, dpr);
        const newY = Theme.snap(bodyY, dpr);
        const newW = Theme.snap(bodyW, dpr);
        const newH = Theme.snap(bodyH, dpr);
        const changed = newX !== _surfaceBodyX || newY !== _surfaceBodyY || newW !== _surfaceBodyW || newH !== _surfaceBodyH;
        _surfaceBodyX = newX;
        _surfaceBodyY = newY;
        _surfaceBodyW = newW;
        _surfaceBodyH = newH;
        _surfaceMarginLeft = _surfaceBodyX - shadowBuffer;
        _surfaceMarginTop = _surfaceBodyY - shadowBuffer;
        _surfaceW = _surfaceBodyW + shadowBuffer * 2;
        _surfaceH = _surfaceBodyH + shadowBuffer * 2;
        if (changed && backgroundWindow.visible) {
            _bgCommitWindow = true;
        }
    }

    Connections {
        target: backgroundWindow
        ignoreUnknownSignals: true
        function onFrameSwapped() {
            if (root._bgCommitWindow)
                root._bgCommitWindow = false;
        }
    }

    // Forces contentWindow to render a frame so Quickshell ships the updated
    // WindowBlur region to the compositor. WindowBlur's property updates
    // don't dirty the QML scene graph by themselves, so when the popup grows,
    // shrinks, or closes without an animation running, the blur state can
    // get stuck at its previous size. Called from the existing
    // onAligned*Changed / onShouldBeVisibleChanged handlers.
    function _kickBlurCommit() {
        if (typeof contentWindow.update === "function")
            contentWindow.update();
    }

    function _setSettledSurfaceGeometry() {
        if (shouldBeVisible) {
            _setSurfaceGeometry(alignedX, alignedY, alignedWidth, alignedHeight);
        }
    }

    function _setAnimatedSurfaceEnvelope() {
        if (!shouldBeVisible)
            return;
        if (_fullHeight) {
            _setSettledSurfaceGeometry();
            return;
        }

        const currentY = renderedAlignedY;
        const currentBottom = renderedAlignedY + renderedAlignedHeight;
        const targetY = alignedY;
        const targetBottom = alignedY + alignedHeight;
        const existingY = _surfaceBodyH > 0 ? _surfaceBodyY : currentY;
        const existingBottom = _surfaceBodyH > 0 ? _surfaceBodyY + _surfaceBodyH : currentBottom;
        const envelopeY = Math.min(currentY, targetY, existingY);
        const envelopeBottom = Math.max(currentBottom, targetBottom, existingBottom);
        _setSurfaceGeometry(alignedX, envelopeY, alignedWidth, Math.max(0, envelopeBottom - envelopeY));
        surfaceSettleTimer.restart();
    }

    function updateSurfacePosition() {
        _setSettledSurfaceGeometry();
    }

    onAlignedXChanged: {
        if (shouldBeVisible)
            _setAnimatedSurfaceEnvelope();
        _kickBlurCommit();
    }

    onAlignedYChanged: {
        if (shouldBeVisible)
            _setAnimatedSurfaceEnvelope();
        _kickBlurCommit();
    }

    onAlignedWidthChanged: {
        if (shouldBeVisible)
            _setAnimatedSurfaceEnvelope();
        _kickBlurCommit();
    }

    function open() {
        if (!screen)
            return;
        closeTimer.stop();
        isClosing = false;
        animationsEnabled = false;
        _primeContent = true;

        _frozenMaskX = maskX;
        _frozenMaskY = maskY;
        _frozenMaskWidth = maskWidth;
        _frozenMaskHeight = maskHeight;

        if (_lastOpenedScreen !== null && _lastOpenedScreen !== screen) {
            contentWindow.visible = false;
            backgroundWindow.visible = false;
        }
        _lastOpenedScreen = screen;

        if (contentContainer) {
            // animationsEnabled is false here, so this snaps to closed without animating.
            morph.openProgress = 0;
        }

        _setSurfaceGeometry(alignedX, alignedY, alignedWidth, alignedHeight);
        if (backgroundWindowRequired)
            backgroundWindow.visible = true;
        contentWindow.visible = true;

        animationsEnabled = true;
        shouldBeVisible = true;
        if (screen) {
            PopoutManager.showPopout(popoutHandle);
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
                backgroundWindow.visible = false;
                PopoutManager.hidePopout(popoutHandle);
                popoutClosed();
            }
        }
    }

    readonly property real screenWidth: screen ? screen.width : 0
    readonly property real screenHeight: screen ? screen.height : 0
    readonly property real dpr: screen ? screen.devicePixelRatio : 1

    readonly property var shadowLevel: Theme.elevationLevel3
    readonly property real shadowFallbackOffset: 6
    readonly property real shadowRenderPadding: (Theme.elevationEnabled && SettingsData.popoutElevationEnabled) ? Theme.elevationRenderPadding(shadowLevel, effectiveShadowDirection, shadowFallbackOffset, 8, 16) : 0
    readonly property real shadowMotionPadding: fluidStandaloneActive ? 0 : Math.max(0, animationOffset)
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

    onAlignedHeightChanged: {
        if (shouldBeVisible)
            _setAnimatedSurfaceEnvelope();
        _kickBlurCommit();
        if (!suspendShadowWhileResizing || !shouldBeVisible)
            return;
        _resizeActive = true;
        resizeSettleTimer.restart();
    }
    onShouldBeVisibleChanged: {
        _kickBlurCommit();
        if (!shouldBeVisible) {
            _resizeActive = false;
            resizeSettleTimer.stop();
        }
    }
    onBackgroundWindowRequiredChanged: {
        if (shouldBeVisible)
            backgroundWindow.visible = backgroundWindowRequired;
    }

    Timer {
        id: resizeSettleTimer
        interval: 80
        repeat: false
        onTriggered: root._resizeActive = false
    }

    Timer {
        id: surfaceSettleTimer
        interval: Math.max(0, Theme.variantDuration(root.animationDuration, root.renderedGeometryGrowing) + 32)
        repeat: false
        onTriggered: root._setSettledSurfaceGeometry()
    }

    readonly property real alignedX: Theme.snap((() => {
            const useAutoGaps = storedBarConfig?.popupGapsAuto !== undefined ? storedBarConfig.popupGapsAuto : true;
            const manualGapValue = storedBarConfig?.popupGapsManual !== undefined ? storedBarConfig.popupGapsManual : 4;
            const popupGap = useAutoGaps ? Math.max(4, storedBarSpacing) : manualGapValue;
            const leftGap = _edgeClearance("left", popupGap, adjacentBarInfo.leftBar > 0 ? adjacentBarInfo.leftBar : 0);
            const rightGap = _edgeClearance("right", popupGap, adjacentBarInfo.rightBar > 0 ? adjacentBarInfo.rightBar : 0);

            switch (effectiveBarPosition) {
            case SettingsData.Position.Left:
                return Math.max(leftGap, Math.min(screenWidth - popupWidth - rightGap, triggerX));
            case SettingsData.Position.Right:
                return Math.max(leftGap, Math.min(screenWidth - popupWidth - rightGap, triggerX - popupWidth));
            default:
                const rawX = triggerX + (triggerWidth / 2) - (popupWidth / 2);
                const minX = leftGap;
                const maxX = screenWidth - popupWidth - rightGap;
                return Math.max(minX, Math.min(maxX, rawX));
            }
        })(), dpr)

    readonly property real alignedY: Theme.snap((() => {
            const useAutoGaps = storedBarConfig?.popupGapsAuto !== undefined ? storedBarConfig.popupGapsAuto : true;
            const manualGapValue = storedBarConfig?.popupGapsManual !== undefined ? storedBarConfig.popupGapsManual : 4;
            const popupGap = useAutoGaps ? Math.max(4, storedBarSpacing) : manualGapValue;
            const topGap = _edgeClearance("top", popupGap, adjacentBarInfo.topBar > 0 ? adjacentBarInfo.topBar : 0);
            const bottomGap = _edgeClearance("bottom", popupGap, adjacentBarInfo.bottomBar > 0 ? adjacentBarInfo.bottomBar : 0);

            switch (effectiveBarPosition) {
            case SettingsData.Position.Bottom:
                return Math.max(topGap, Math.min(screenHeight - popupHeight - bottomGap, triggerY - popupHeight));
            case SettingsData.Position.Top:
                return Math.max(topGap, Math.min(screenHeight - popupHeight - bottomGap, triggerY));
            default:
                const rawY = triggerY - (popupHeight / 2);
                const minY = topGap;
                const maxY = screenHeight - popupHeight - bottomGap;
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
        id: backgroundWindow
        screen: root.screen
        visible: false
        color: "transparent"
        // Skip buffer updates when there's nothing to render. Briefly flipped
        // true via _bgCommitWindow when _surfaceBodyW/H changes so the
        // contentHoleRect mask carve-out actually commits to the compositor.
        updatesEnabled: root.overlayContent !== null || root._bgCommitWindow

        WlrLayershell.namespace: root.layerNamespace + ":background"
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
            item: maskRect
            Region {
                item: contentHoleRect
                intersection: Intersection.Subtract
            }
        }

        Rectangle {
            id: maskRect
            visible: false
            color: "transparent"
            x: root.backgroundDismissWindowRequired ? root._frozenMaskX : 0
            y: root.backgroundDismissWindowRequired ? root._frozenMaskY : 0
            width: (root.backgroundDismissWindowRequired && shouldBeVisible && backgroundInteractive) ? root._frozenMaskWidth : 0
            height: (root.backgroundDismissWindowRequired && shouldBeVisible && backgroundInteractive) ? root._frozenMaskHeight : 0
        }

        Rectangle {
            id: contentHoleRect
            visible: false
            color: "transparent"
            x: root.backgroundDismissWindowRequired ? root._surfaceBodyX : 0
            y: root.backgroundDismissWindowRequired ? root._surfaceBodyY : 0
            width: (root.backgroundDismissWindowRequired && shouldBeVisible) ? root._surfaceBodyW : 0
            height: (root.backgroundDismissWindowRequired && shouldBeVisible) ? root._surfaceBodyH : 0
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            enabled: root.backgroundDismissWindowRequired && shouldBeVisible && backgroundInteractive
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: backgroundClicked()
        }

        Loader {
            id: overlayLoader
            anchors.fill: parent
            active: root.overlayContent !== null && backgroundWindow.visible
            sourceComponent: root.overlayContent
        }
    }

    PanelWindow {
        id: contentWindow
        screen: root.screen
        visible: false
        color: "transparent"
        readonly property bool closeVisualActive: root.shouldBeVisible || root.isClosing

        WindowBlur {
            id: popoutBlur
            targetWindow: contentWindow
            readonly property real s: Math.min(1, contentContainer.scaleValue)
            readonly property bool trackBlurFromBarEdge: root.fluidStandaloneActive
            readonly property real op: Math.max(0, Math.min(1, (morph.openProgress - 0.08) * 1.6))
            readonly property bool blurAlive: trackBlurFromBarEdge ? (contentContainer.revealWidth > 0 && contentContainer.revealHeight > 0) : root.shouldBeVisible

            blurX: trackBlurFromBarEdge ? contentContainer.x + contentContainer.revealX : contentContainer.x + contentContainer.width * (1 - s * op) * 0.5 + Theme.snap(contentContainer.animX, root.dpr)
            blurY: trackBlurFromBarEdge ? contentContainer.y + contentContainer.revealY : contentContainer.y + contentContainer.height * (1 - s * op) * 0.5 + Theme.snap(contentContainer.animY, root.dpr)
            blurWidth: blurAlive ? (trackBlurFromBarEdge ? contentContainer.revealWidth : contentContainer.width * s * op) : 0
            blurHeight: blurAlive ? (trackBlurFromBarEdge ? contentContainer.revealHeight : contentContainer.height * s * op) : 0
            blurRadius: Theme.cornerRadius
        }

        WlrLayershell.namespace: root.layerNamespace
        WlrLayershell.layer: {
            switch (Quickshell.env("DMS_POPOUT_LAYER")) {
            case "bottom":
                root.log.warn("'bottom' layer is not valid for popouts. Defaulting to 'top' layer.");
                return WlrLayershell.Top;
            case "background":
                root.log.warn("'background' layer is not valid for popouts. Defaulting to 'top' layer.");
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

        anchors {
            left: true
            top: true
            bottom: root._fullHeight
        }

        WlrLayershell.margins {
            left: root._surfaceMarginLeft
            top: root._fullHeight ? 0 : root._surfaceMarginTop
        }

        implicitWidth: root._surfaceW
        implicitHeight: root._fullHeight ? 0 : root._surfaceH

        mask: contentInputMask

        Region {
            id: contentInputMask
            item: contentMaskRect
        }

        Item {
            id: contentMaskRect
            visible: false
            x: contentContainer.x
            y: contentContainer.y
            width: contentWindow.closeVisualActive ? root.alignedWidth : 0
            height: contentWindow.closeVisualActive ? root.renderedAlignedHeight : 0
        }

        Item {
            id: contentContainer
            x: shadowBuffer + root.alignedX - root._surfaceBodyX
            y: root._fullHeight ? root.renderedAlignedY : shadowBuffer + root.renderedAlignedY - root._surfaceBodyY
            width: root.alignedWidth
            height: root.renderedAlignedHeight

            readonly property bool barTop: effectiveBarPosition === SettingsData.Position.Top
            readonly property bool barBottom: effectiveBarPosition === SettingsData.Position.Bottom
            readonly property bool barLeft: effectiveBarPosition === SettingsData.Position.Left
            readonly property bool barRight: effectiveBarPosition === SettingsData.Position.Right
            readonly property string connectedBarSide: barTop ? "top" : (barBottom ? "bottom" : (barLeft ? "left" : "right"))
            readonly property bool directionalEffect: Theme.isDirectionalEffect
            readonly property bool depthEffect: Theme.isDepthEffect
            readonly property real directionalTravelX: Math.max(root.animationOffset, root.alignedWidth + Theme.spacingL)
            readonly property real directionalTravelY: Math.max(root.animationOffset, root.alignedHeight + Theme.spacingL)
            readonly property real depthTravel: Math.max(root.animationOffset * 0.7, 28)
            readonly property real sectionTilt: (triggerSection === "left" ? -1 : (triggerSection === "right" ? 1 : 0))
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

            // openProgress: 0 = closed (at offset, scaleCollapsed), 1 = open (at 0, scale 1).
            QtObject {
                id: morph
                property real openProgress: 0
                Behavior on openProgress {
                    enabled: root.animationsEnabled
                    NumberAnimation {
                        duration: Theme.variantDuration(root.animationDuration, root.shouldBeVisible)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                    }
                }
            }

            readonly property real animX: contentContainer.offsetX * (1 - morph.openProgress)
            readonly property real animY: contentContainer.offsetY * (1 - morph.openProgress)
            readonly property real scaleValue: contentContainer.computedScaleCollapsed + (1.0 - contentContainer.computedScaleCollapsed) * morph.openProgress
            readonly property real clampedAnimX: Math.max(-width, Math.min(animX, width))
            readonly property real clampedAnimY: Math.max(-height, Math.min(animY, height))
            readonly property real revealWidth: {
                if (!root.fluidStandaloneActive)
                    return width;
                if (barLeft)
                    return Theme.snap(Math.max(0, width + clampedAnimX), root.dpr);
                if (barRight)
                    return Theme.snap(Math.max(0, width - clampedAnimX), root.dpr);
                return width;
            }
            readonly property real revealHeight: {
                if (!root.fluidStandaloneActive)
                    return height;
                if (barTop)
                    return Theme.snap(Math.max(0, height + clampedAnimY), root.dpr);
                if (barBottom)
                    return Theme.snap(Math.max(0, height - clampedAnimY), root.dpr);
                return height;
            }
            readonly property real revealX: root.fluidStandaloneActive && barRight ? Theme.snap(width - revealWidth, root.dpr) : 0
            readonly property real revealY: root.fluidStandaloneActive && barBottom ? Theme.snap(height - revealHeight, root.dpr) : 0

            Component.onCompleted: morph.openProgress = root.shouldBeVisible ? 1 : 0

            Connections {
                target: root
                function onShouldBeVisibleChanged() {
                    morph.openProgress = root.shouldBeVisible ? 1 : 0;
                }
            }

            Item {
                id: directionalClipMask

                readonly property bool shouldClip: root.fluidStandaloneActive

                clip: shouldClip
                x: shouldClip ? contentContainer.revealX : 0
                y: shouldClip ? contentContainer.revealY : 0
                width: shouldClip ? contentContainer.revealWidth : parent.width
                height: shouldClip ? contentContainer.revealHeight : parent.height

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
                        width: rollOutAdjuster.baseWidth
                        height: rollOutAdjuster.baseHeight
                        opacity: contentWrapper.publishedOpacity
                        scale: root.fluidStandaloneActive ? 1 : contentWrapper.scale
                        x: root.fluidStandaloneActive ? 0 : contentWrapper.x
                        y: root.fluidStandaloneActive ? 0 : contentWrapper.y
                        level: root.shadowLevel
                        direction: root.effectiveShadowDirection
                        fallbackOffset: root.shadowFallbackOffset
                        targetRadius: Theme.cornerRadius
                        targetColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                        shadowEnabled: Theme.elevationEnabled && SettingsData.popoutElevationEnabled && Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1" && !(root.suspendShadowWhileResizing && root._resizeActive)
                    }

                    Item {
                        id: contentWrapper
                        width: rollOutAdjuster.baseWidth
                        height: rollOutAdjuster.baseHeight

                        // publishedOpacity tracks Item.opacity on the GUI thread so consumers (WindowBlur,
                        // ElevationShadow, sibling rect) see interpolated values while the visual runs on
                        // the render thread via OpacityAnimator.
                        property bool _renderActive: Theme.isDirectionalEffect || shouldBeVisible
                        property real publishedOpacity: Theme.isDirectionalEffect ? 1 : (shouldBeVisible ? 1 : 0)

                        opacity: Theme.isDirectionalEffect ? 1 : (shouldBeVisible ? 1 : 0)
                        visible: _renderActive
                        scale: contentContainer.scaleValue
                        transformOrigin: Item.Center
                        x: Theme.snap(contentContainer.animX + (rollOutAdjuster.baseWidth - width) * (1 - contentContainer.scaleValue) * 0.5, root.dpr)
                        y: Theme.snap(contentContainer.animY + (rollOutAdjuster.baseHeight - height) * (1 - contentContainer.scaleValue) * 0.5, root.dpr)

                        layer.enabled: !Theme.isDirectionalEffect && publishedOpacity < 1
                        layer.smooth: false
                        layer.textureSize: root.dpr > 1 ? Qt.size(Math.ceil(width * root.dpr), Math.ceil(height * root.dpr)) : Qt.size(0, 0)

                        Behavior on opacity {
                            enabled: !Theme.isDirectionalEffect
                            NumberAnimation {
                                duration: Math.round(Theme.variantDuration(root.animationDuration, root.shouldBeVisible) * Theme.variantOpacityDurationScale)
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                                onRunningChanged: {
                                    if (!running && !root.shouldBeVisible)
                                        contentWrapper._renderActive = false;
                                }
                            }
                        }

                        Behavior on publishedOpacity {
                            enabled: !Theme.isDirectionalEffect
                            NumberAnimation {
                                duration: Math.round(Theme.variantDuration(root.animationDuration, root.shouldBeVisible) * Theme.variantOpacityDurationScale)
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
                                if (!contentWindow.visible)
                                    contentWrapper._renderActive = false;
                            }
                        }

                        Loader {
                            id: contentLoader
                            anchors.fill: parent
                            active: root._primeContent || shouldBeVisible || contentWindow.visible
                            asynchronous: false
                        }
                    }

                    Rectangle {
                        width: rollOutAdjuster.baseWidth
                        height: rollOutAdjuster.baseHeight
                        x: root.fluidStandaloneActive ? 0 : contentWrapper.x
                        y: root.fluidStandaloneActive ? 0 : contentWrapper.y
                        opacity: contentWrapper.publishedOpacity
                        scale: root.fluidStandaloneActive ? 1 : contentWrapper.scale
                        visible: contentWrapper.visible
                        radius: Theme.cornerRadius
                        color: "transparent"
                        border.color: BlurService.enabled ? BlurService.borderColor : Theme.outlineMedium
                        border.width: BlurService.borderWidth
                        z: 100
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
    }
}
