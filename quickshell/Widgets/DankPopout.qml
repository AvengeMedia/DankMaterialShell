import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

Item {
    id: root

    property string layerNamespace: "dms:popout"
    property alias content: contentLoader.sourceComponent
    property alias contentLoader: contentLoader
    property Component overlayContent: null
    property alias overlayLoader: overlayLoader
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
    property real _surfaceMarginLeft: 0
    property real _surfaceW: 0

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

    readonly property bool useBackgroundWindow: !CompositorService.isHyprland || CompositorService.useHyprlandFocusGrab

    function updateSurfacePosition() {
        if (useBackgroundWindow && shouldBeVisible) {
            _surfaceMarginLeft = alignedX - shadowBuffer;
            _surfaceW = alignedWidth + shadowBuffer * 2;
        }
    }

    property bool animationsEnabled: true

    function open() {
        if (!screen)
            return;
        closeTimer.stop();
        isClosing = false;
        animationsEnabled = false;

        // Snapshot mask geometry
        _frozenMaskX = maskX;
        _frozenMaskY = maskY;
        _frozenMaskWidth = maskWidth;
        _frozenMaskHeight = maskHeight;

        if (_lastOpenedScreen !== null && _lastOpenedScreen !== screen) {
            contentWindow.visible = false;
            if (useBackgroundWindow)
                backgroundWindow.visible = false;
        }
        _lastOpenedScreen = screen;

        if (contentContainer) {
            contentContainer.animX = Theme.snap(contentContainer.offsetX, root.dpr);
            contentContainer.animY = Theme.snap(contentContainer.offsetY, root.dpr);
            contentContainer.scaleValue = root.animationScaleCollapsed;
        }

        if (useBackgroundWindow) {
            _surfaceMarginLeft = alignedX - shadowBuffer;
            _surfaceW = alignedWidth + shadowBuffer * 2;
            backgroundWindow.visible = true;
        }
        contentWindow.visible = true;

        Qt.callLater(() => {
            animationsEnabled = true;
            shouldBeVisible = true;
            if (shouldBeVisible && screen) {
                if (useBackgroundWindow)
                    backgroundWindow.visible = true;
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
                if (useBackgroundWindow)
                    backgroundWindow.visible = false;
                PopoutManager.hidePopout(root);
                popoutClosed();
            }
        }
    }

    readonly property real screenWidth: screen ? screen.width : 0
    readonly property real screenHeight: screen ? screen.height : 0
    readonly property real dpr: screen ? screen.devicePixelRatio : 1
    readonly property real frameInset: {
        if (!SettingsData.frameEnabled) return 0;
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
            const useAutoGaps = storedBarConfig?.popupGapsAuto !== undefined ? storedBarConfig.popupGapsAuto : true;
            const manualGapValue = storedBarConfig?.popupGapsManual !== undefined ? storedBarConfig.popupGapsManual : 4;
            const rawPopupGap = useAutoGaps ? Math.max(4, storedBarSpacing) : manualGapValue;
            const popupGap = Theme.isConnectedEffect ? 0 : rawPopupGap;
            const edgeGap = Math.max(popupGap, frameInset);
            const anchorX = Theme.isConnectedEffect ? connectedAnchorX : triggerX;

            switch (effectiveBarPosition) {
            case SettingsData.Position.Left:
                // bar on left: left side is bar-adjacent (popupGap), right side is frame-perpendicular (edgeGap)
                return Math.max(popupGap, Math.min(screenWidth - popupWidth - edgeGap, anchorX));
            case SettingsData.Position.Right:
                // bar on right: right side is bar-adjacent (popupGap), left side is frame-perpendicular (edgeGap)
                return Math.max(edgeGap, Math.min(screenWidth - popupWidth - popupGap, anchorX - popupWidth));
            default:
                const rawX = triggerX + (triggerWidth / 2) - (popupWidth / 2);
                const minX = Math.max(edgeGap, adjacentBarClearance(adjacentBarInfo.leftBar));
                const maxX = screenWidth - popupWidth - Math.max(edgeGap, adjacentBarClearance(adjacentBarInfo.rightBar));
                return Math.max(minX, Math.min(maxX, rawX));
            }
        })(), dpr)

    readonly property real alignedY: Theme.snap((() => {
            const useAutoGaps = storedBarConfig?.popupGapsAuto !== undefined ? storedBarConfig.popupGapsAuto : true;
            const manualGapValue = storedBarConfig?.popupGapsManual !== undefined ? storedBarConfig.popupGapsManual : 4;
            const rawPopupGap = useAutoGaps ? Math.max(4, storedBarSpacing) : manualGapValue;
            const popupGap = Theme.isConnectedEffect ? 0 : rawPopupGap;
            const edgeGap = Math.max(popupGap, frameInset);
            const anchorY = Theme.isConnectedEffect ? connectedAnchorY : triggerY;

            switch (effectiveBarPosition) {
            case SettingsData.Position.Bottom:
                // bar on bottom: bottom side is bar-adjacent (popupGap), top side is frame-perpendicular (edgeGap)
                return Math.max(edgeGap, Math.min(screenHeight - popupHeight - popupGap, anchorY - popupHeight));
            case SettingsData.Position.Top:
                // bar on top: top side is bar-adjacent (popupGap), bottom side is frame-perpendicular (edgeGap)
                return Math.max(popupGap, Math.min(screenHeight - popupHeight - edgeGap, anchorY));
            default:
                const rawY = triggerY - (popupHeight / 2);
                const minY = Math.max(edgeGap, adjacentBarClearance(adjacentBarInfo.topBar));
                const maxY = screenHeight - popupHeight - Math.max(edgeGap, adjacentBarClearance(adjacentBarInfo.bottomBar));
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
        Component.onCompleted: {
            if (typeof updatesEnabled !== "undefined" && !root.overlayContent)
                updatesEnabled = false;
        }

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
                item: contentExclusionRect
                intersection: Intersection.Subtract
            }
        }

        Rectangle {
            id: maskRect
            visible: false
            color: "transparent"
            x: root._frozenMaskX
            y: root._frozenMaskY
            width: (backgroundWindow.visible && backgroundInteractive) ? root._frozenMaskWidth : 0
            height: (backgroundWindow.visible && backgroundInteractive) ? root._frozenMaskHeight : 0
        }

        Item {
            id: contentExclusionRect
            visible: false
            x: root.alignedX
            y: root.alignedY
            width: root.alignedWidth
            height: root.alignedHeight
        }

        Item {
            id: outsideClickCatcher
            x: root._frozenMaskX
            y: root._frozenMaskY
            width: root._frozenMaskWidth
            height: root._frozenMaskHeight
            enabled: root.shouldBeVisible && root.backgroundInteractive

            readonly property real contentLeft: Math.max(0, root.alignedX - x)
            readonly property real contentTop: Math.max(0, root.alignedY - y)
            readonly property real contentRight: Math.min(width, contentLeft + root.alignedWidth)
            readonly property real contentBottom: Math.min(height, contentTop + root.alignedHeight)

            MouseArea {
                x: 0
                y: 0
                width: outsideClickCatcher.width
                height: Math.max(0, outsideClickCatcher.contentTop)
                enabled: parent.enabled
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: root.backgroundClicked()
            }

            MouseArea {
                x: 0
                y: outsideClickCatcher.contentBottom
                width: outsideClickCatcher.width
                height: Math.max(0, outsideClickCatcher.height - outsideClickCatcher.contentBottom)
                enabled: parent.enabled
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: root.backgroundClicked()
            }

            MouseArea {
                x: 0
                y: outsideClickCatcher.contentTop
                width: Math.max(0, outsideClickCatcher.contentLeft)
                height: Math.max(0, outsideClickCatcher.contentBottom - outsideClickCatcher.contentTop)
                enabled: parent.enabled
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: root.backgroundClicked()
            }

            MouseArea {
                x: outsideClickCatcher.contentRight
                y: outsideClickCatcher.contentTop
                width: Math.max(0, outsideClickCatcher.width - outsideClickCatcher.contentRight)
                height: Math.max(0, outsideClickCatcher.contentBottom - outsideClickCatcher.contentTop)
                enabled: parent.enabled
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: root.backgroundClicked()
            }
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

        WindowBlur {
            id: popoutBlur
            targetWindow: contentWindow
            blurEnabled: root.effectiveSurfaceBlurEnabled

            readonly property real s: Math.min(1, contentContainer.scaleValue)
            readonly property bool trackBlurFromBarEdge: Theme.isConnectedEffect
                || (typeof SettingsData !== "undefined"
                    && Theme.isDirectionalEffect
                    && SettingsData.directionalAnimationMode !== 2)

            // Directional popouts clip to the bar edge, so the blur needs to grow from
            // that same edge instead of translating through the bar before settling.
            readonly property real _dyClamp: (contentContainer.barTop || contentContainer.barBottom)
                ? Math.max(-contentContainer.height, Math.min(contentContainer.animY, contentContainer.height))
                : 0
            readonly property real _dxClamp: (contentContainer.barLeft || contentContainer.barRight)
                ? Math.max(-contentContainer.width, Math.min(contentContainer.animX, contentContainer.width))
                : 0

            blurX: trackBlurFromBarEdge
                ? contentContainer.x + (contentContainer.barRight ? _dxClamp : 0)
                : contentContainer.x + contentContainer.width * (1 - s) * 0.5
                  + Theme.snap(contentContainer.animX, root.dpr)
                  - contentContainer.horizontalConnectorExtent * s
            blurY: trackBlurFromBarEdge
                ? contentContainer.y + (contentContainer.barBottom ? _dyClamp : 0)
                : contentContainer.y + contentContainer.height * (1 - s) * 0.5
                  + Theme.snap(contentContainer.animY, root.dpr)
                  - contentContainer.verticalConnectorExtent * s
            blurWidth: (shouldBeVisible && contentWrapper.opacity > 0)
                ? (trackBlurFromBarEdge
                    ? Math.max(0, contentContainer.width - Math.abs(_dxClamp))
                    : (contentContainer.width + contentContainer.horizontalConnectorExtent * 2) * s)
                : 0
            blurHeight: (shouldBeVisible && contentWrapper.opacity > 0)
                ? (trackBlurFromBarEdge
                    ? Math.max(0, contentContainer.height - Math.abs(_dyClamp))
                    : (contentContainer.height + contentContainer.verticalConnectorExtent * 2) * s)
                : 0
            blurRadius: Theme.isConnectedEffect ? Theme.connectedCornerRadius : Theme.connectedSurfaceRadius
        }

        WlrLayershell.namespace: root.layerNamespace
        WlrLayershell.layer: {
            switch (Quickshell.env("DMS_POPOUT_LAYER")) {
            case "bottom":
                console.warn("DankPopout: 'bottom' layer is not valid for popouts. Defaulting to 'top' layer.");
                return WlrLayershell.Top;
            case "background":
                console.warn("DankPopout: 'background' layer is not valid for popouts. Defaulting to 'top' layer.");
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

        readonly property bool _fullHeight: useBackgroundWindow && root.fullHeightSurface
        anchors {
            left: true
            top: true
            right: !useBackgroundWindow
            bottom: _fullHeight || !useBackgroundWindow
        }

        WlrLayershell.margins {
            left: useBackgroundWindow ? root._surfaceMarginLeft : 0
            top: (useBackgroundWindow && !_fullHeight) ? (root.alignedY - shadowBuffer) : 0
        }

        implicitWidth: useBackgroundWindow ? root._surfaceW : 0
        implicitHeight: (useBackgroundWindow && !_fullHeight) ? (root.alignedHeight + shadowBuffer * 2) : 0

        mask: useBackgroundWindow ? contentInputMask : null

        Region {
            id: contentInputMask
            item: contentMaskRect
        }

        Item {
            id: contentMaskRect
            visible: false
            x: contentContainer.x - contentContainer.horizontalConnectorExtent
            y: contentContainer.y - contentContainer.verticalConnectorExtent
            width: root.alignedWidth + contentContainer.horizontalConnectorExtent * 2
            height: root.alignedHeight + contentContainer.verticalConnectorExtent * 2
        }

        MouseArea {
            anchors.fill: parent
            enabled: !useBackgroundWindow && shouldBeVisible && backgroundInteractive
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            z: -1
            onClicked: mouse => {
                const clickX = mouse.x;
                const clickY = mouse.y;
                const outsideContent = clickX < root.alignedX || clickX > root.alignedX + root.alignedWidth || clickY < root.alignedY || clickY > root.alignedY + root.alignedHeight;
                if (!outsideContent)
                    return;
                backgroundClicked();
            }
        }

        Item {
            id: contentContainer
            x: useBackgroundWindow ? shadowBuffer : root.alignedX
            y: (useBackgroundWindow && !contentWindow._fullHeight) ? shadowBuffer : root.alignedY
            width: root.alignedWidth
            height: root.alignedHeight

            readonly property bool barTop: effectiveBarPosition === SettingsData.Position.Top
            readonly property bool barBottom: effectiveBarPosition === SettingsData.Position.Bottom
            readonly property bool barLeft: effectiveBarPosition === SettingsData.Position.Left
            readonly property bool barRight: effectiveBarPosition === SettingsData.Position.Right
            readonly property string connectedBarSide: barTop ? "top" : (barBottom ? "bottom" : (barLeft ? "left" : "right"))
            readonly property real surfaceRadius: Theme.connectedSurfaceRadius
            readonly property color surfaceColor: Theme.popupLayerColor(Theme.surfaceContainer)
            readonly property color surfaceBorderColor: Theme.isConnectedEffect
                ? "transparent"
                : (BlurService.enabled ? BlurService.borderColor : Theme.outlineMedium)
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
            }

            onOffsetXChanged: animX = Theme.snap(root.shouldBeVisible ? 0 : offsetX, root.dpr)
            onOffsetYChanged: animY = Theme.snap(root.shouldBeVisible ? 0 : offsetY, root.dpr)

            Connections {
                target: root
                function onShouldBeVisibleChanged() {
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

                readonly property bool shouldClip: Theme.isDirectionalEffect
                    && typeof SettingsData !== "undefined"
                    && SettingsData.directionalAnimationMode > 0
                readonly property real clipOversize: 1000
                readonly property real connectedClipAllowance: Theme.isConnectedEffect
                    ? Math.ceil(root.shadowRenderPadding + BlurService.borderWidth + 2)
                    : 0

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

                Item {
                    id: aligner
                    readonly property real baseWidth: contentContainer.width
                    readonly property real baseHeight: contentContainer.height
                    readonly property bool isRollOut: typeof SettingsData !== "undefined" && SettingsData.directionalAnimationMode === 2 && Theme.isDirectionalEffect

                    x: (directionalClipMask.x !== 0 ? -directionalClipMask.x : 0) + (isRollOut && contentContainer.barRight ? baseWidth * (1 - contentContainer.scaleValue) : 0)
                    y: (directionalClipMask.y !== 0 ? -directionalClipMask.y : 0) + (isRollOut && contentContainer.barBottom ? baseHeight * (1 - contentContainer.scaleValue) : 0)
                    width: isRollOut && (contentContainer.barLeft || contentContainer.barRight) ? Math.max(0, baseWidth * contentContainer.scaleValue) : baseWidth
                    height: isRollOut && (contentContainer.barTop || contentContainer.barBottom) ? Math.max(0, baseHeight * contentContainer.scaleValue) : baseHeight

                    clip: isRollOut

                    Item {
                        id: unrollCounteract
                        x: aligner.isRollOut && contentContainer.barRight ? -(aligner.baseWidth * (1 - contentContainer.scaleValue)) : 0
                        y: aligner.isRollOut && contentContainer.barBottom ? -(aligner.baseHeight * (1 - contentContainer.scaleValue)) : 0
                        width: aligner.baseWidth
                        height: aligner.baseHeight

                        ElevationShadow {
                            id: shadowSource
                            readonly property real connectorExtent: Theme.isConnectedEffect ? Theme.connectedCornerRadius : 0
                            readonly property real extraLeft: Theme.isConnectedEffect && (contentContainer.barTop || contentContainer.barBottom) ? connectorExtent : 0
                            readonly property real extraRight: Theme.isConnectedEffect && (contentContainer.barTop || contentContainer.barBottom) ? connectorExtent : 0
                            readonly property real extraTop: Theme.isConnectedEffect && (contentContainer.barLeft || contentContainer.barRight) ? connectorExtent : 0
                            readonly property real extraBottom: Theme.isConnectedEffect && (contentContainer.barLeft || contentContainer.barRight) ? connectorExtent : 0
                            readonly property real bodyX: extraLeft
                            readonly property real bodyY: extraTop
                            readonly property real bodyWidth: parent.width
                            readonly property real bodyHeight: parent.height

                            width: parent.width + extraLeft + extraRight
                            height: parent.height + extraTop + extraBottom
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
                            shadowEnabled: Theme.elevationEnabled && SettingsData.popoutElevationEnabled && Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1" && !(root.suspendShadowWhileResizing && root._resizeActive)

                            Item {
                                anchors.fill: parent
                                visible: Theme.isConnectedEffect
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
                                    x: Theme.snap(contentContainer.connectorX(shadowSource.bodyX, shadowSource.bodyWidth, placement, spacing), root.dpr)
                                    y: Theme.snap(contentContainer.connectorY(shadowSource.bodyY, shadowSource.bodyHeight, placement, spacing), root.dpr)
                                }
                            }
                        }

                        Item {
                            id: contentWrapper
                            width: parent.width
                            height: parent.height
                            opacity: Theme.isDirectionalEffect ? 1 : (shouldBeVisible ? 1 : 0)
                            visible: opacity > 0

                            scale: aligner.isRollOut ? 1.0 : contentContainer.scaleValue
                            x: Theme.snap(contentContainer.animX + (parent.width - width) * (1 - scale) * 0.5, root.dpr)
                            y: Theme.snap(contentContainer.animY + (parent.height - height) * (1 - scale) * 0.5, root.dpr)

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
                                    topLeftRadius: contentContainer.surfaceTopLeftRadius
                                    topRightRadius: contentContainer.surfaceTopRightRadius
                                    bottomLeftRadius: contentContainer.surfaceBottomLeftRadius
                                    bottomRightRadius: contentContainer.surfaceBottomRightRadius
                                    color: contentContainer.surfaceColor
                                    border.color: contentContainer.surfaceBorderColor
                                    border.width: contentContainer.surfaceBorderWidth
                                }

                                ConnectedCorner {
                                    visible: Theme.isConnectedEffect
                                    barSide: contentContainer.connectedBarSide
                                    placement: "left"
                                    spacing: 0
                                    connectorRadius: Theme.connectedCornerRadius
                                    color: contentContainer.surfaceColor
                                    x: Theme.snap(contentContainer.connectorX(0, contentWrapper.width, placement, spacing), root.dpr)
                                    y: Theme.snap(contentContainer.connectorY(0, contentWrapper.height, placement, spacing), root.dpr)
                                }

                                ConnectedCorner {
                                    visible: Theme.isConnectedEffect
                                    barSide: contentContainer.connectedBarSide
                                    placement: "right"
                                    spacing: 0
                                    connectorRadius: Theme.connectedCornerRadius
                                    color: contentContainer.surfaceColor
                                    x: Theme.snap(contentContainer.connectorX(0, contentWrapper.width, placement, spacing), root.dpr)
                                    y: Theme.snap(contentContainer.connectorY(0, contentWrapper.height, placement, spacing), root.dpr)
                                }
                            }

                            Loader {
                                id: contentLoader
                                anchors.fill: parent
                                active: root._primeContent || shouldBeVisible || contentWindow.visible
                                asynchronous: false
                            }
                        } // closes contentWrapper
                    } // closes unrollCounteract
                } // closes aligner
            } // closes directionalClipMask
        } // closes contentContainer

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
