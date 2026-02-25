import QtQuick
import QtQuick.Effects
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
    property real animationScaleCollapsed: 0.96
    property real animationOffset: Theme.spacingL
    property list<real> animationEnterCurve: Theme.expressiveCurves.expressiveDefaultSpatial
    property list<real> animationExitCurve: Theme.expressiveCurves.emphasized
    property bool suspendShadowWhileResizing: false
    property bool shouldBeVisible: false
    property var customKeyboardFocus: null
    property bool backgroundInteractive: true
    property bool contentHandlesKeys: false
    property bool fullHeightSurface: false
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

    // Snapshot mask geometry to prevent background damage on bar updates
    property real _frozenMaskX: 0
    property real _frozenMaskY: 0
    property real _frozenMaskWidth: 0
    property real _frozenMaskHeight: 0

    function setBarContext(position, bottomGap) {
        effectiveBarPosition = position !== undefined ? position : 0;
        effectiveBarBottomGap = bottomGap !== undefined ? bottomGap : 0;
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

    function open() {
        if (!screen)
            return;
        closeTimer.stop();

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

        shouldBeVisible = true;
        if (useBackgroundWindow) {
            _surfaceMarginLeft = alignedX - shadowBuffer;
            _surfaceW = alignedWidth + shadowBuffer * 2;
        }
        Qt.callLater(() => {
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
        shouldBeVisible = false;
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
        interval: animationDuration
        onTriggered: {
            if (!shouldBeVisible) {
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

    readonly property real shadowBuffer: 5
    readonly property real alignedWidth: Theme.px(popupWidth, dpr)
    readonly property real alignedHeight: Theme.px(popupHeight, dpr)

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
            const popupGap = useAutoGaps ? Math.max(4, storedBarSpacing) : manualGapValue;

            switch (effectiveBarPosition) {
            case SettingsData.Position.Left:
                return Math.max(popupGap, Math.min(screenWidth - popupWidth - popupGap, triggerX));
            case SettingsData.Position.Right:
                return Math.max(popupGap, Math.min(screenWidth - popupWidth - popupGap, triggerX - popupWidth));
            default:
                const rawX = triggerX + (triggerWidth / 2) - (popupWidth / 2);
                const minX = adjacentBarInfo.leftBar > 0 ? adjacentBarInfo.leftBar : popupGap;
                const maxX = screenWidth - popupWidth - (adjacentBarInfo.rightBar > 0 ? adjacentBarInfo.rightBar : popupGap);
                return Math.max(minX, Math.min(maxX, rawX));
            }
        })(), dpr)

    readonly property real alignedY: Theme.snap((() => {
            const useAutoGaps = storedBarConfig?.popupGapsAuto !== undefined ? storedBarConfig.popupGapsAuto : true;
            const manualGapValue = storedBarConfig?.popupGapsManual !== undefined ? storedBarConfig.popupGapsManual : 4;
            const popupGap = useAutoGaps ? Math.max(4, storedBarSpacing) : manualGapValue;

            switch (effectiveBarPosition) {
            case SettingsData.Position.Bottom:
                return Math.max(popupGap, Math.min(screenHeight - popupHeight - popupGap, triggerY - popupHeight));
            case SettingsData.Position.Top:
                return Math.max(popupGap, Math.min(screenHeight - popupHeight - popupGap, triggerY));
            default:
                const rawY = triggerY - (popupHeight / 2);
                const minY = adjacentBarInfo.topBar > 0 ? adjacentBarInfo.topBar : popupGap;
                const maxY = screenHeight - popupHeight - (adjacentBarInfo.bottomBar > 0 ? adjacentBarInfo.bottomBar : popupGap);
                return Math.max(minY, Math.min(maxY, rawY));
            }
        })(), dpr)

    readonly property real maskX: {
        const triggeringBarX = (effectiveBarPosition === SettingsData.Position.Left && barWidth > 0) ? barWidth : 0;
        const adjacentLeftBar = adjacentBarInfo?.leftBar ?? 0;
        return Math.max(triggeringBarX, adjacentLeftBar);
    }

    readonly property real maskY: {
        const triggeringBarY = (effectiveBarPosition === SettingsData.Position.Top && barHeight > 0) ? barHeight : 0;
        const adjacentTopBar = adjacentBarInfo?.topBar ?? 0;
        return Math.max(triggeringBarY, adjacentTopBar);
    }

    readonly property real maskWidth: {
        const triggeringBarRight = (effectiveBarPosition === SettingsData.Position.Right && barWidth > 0) ? barWidth : 0;
        const adjacentRightBar = adjacentBarInfo?.rightBar ?? 0;
        const rightExclusion = Math.max(triggeringBarRight, adjacentRightBar);
        return Math.max(100, screenWidth - maskX - rightExclusion);
    }

    readonly property real maskHeight: {
        const triggeringBarBottom = (effectiveBarPosition === SettingsData.Position.Bottom && barHeight > 0) ? barHeight : 0;
        const adjacentBottomBar = adjacentBarInfo?.bottomBar ?? 0;
        const bottomExclusion = Math.max(triggeringBarBottom, adjacentBottomBar);
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
        }

        Rectangle {
            id: maskRect
            visible: false
            color: "transparent"
            x: root._frozenMaskX
            y: root._frozenMaskY
            width: (shouldBeVisible && backgroundInteractive) ? root._frozenMaskWidth : 0
            height: (shouldBeVisible && backgroundInteractive) ? root._frozenMaskHeight : 0
        }

        MouseArea {
            x: root._frozenMaskX
            y: root._frozenMaskY
            width: root._frozenMaskWidth
            height: root._frozenMaskHeight
            hoverEnabled: false
            enabled: shouldBeVisible && backgroundInteractive
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: mouse => {
                const clickX = mouse.x + root._frozenMaskX;
                const clickY = mouse.y + root._frozenMaskY;
                const outsideContent = clickX < root.alignedX || clickX > root.alignedX + root.alignedWidth || clickY < root.alignedY || clickY > root.alignedY + root.alignedHeight;

                if (!outsideContent)
                    return;
                backgroundClicked();
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

        mask: (useBackgroundWindow && _fullHeight) ? contentInputMask : null

        Region {
            id: contentInputMask
            item: contentMaskRect
        }

        Item {
            id: contentMaskRect
            visible: false
            x: contentContainer.x - root.shadowBuffer
            y: contentContainer.y - root.shadowBuffer
            width: root.alignedWidth + root.shadowBuffer * 2
            height: root.alignedHeight + root.shadowBuffer * 2
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
            readonly property real offsetX: barLeft ? root.animationOffset : (barRight ? -root.animationOffset : 0)
            readonly property real offsetY: barBottom ? -root.animationOffset : (barTop ? root.animationOffset : 0)

            property real animX: 0
            property real animY: 0
            property real scaleValue: root.animationScaleCollapsed

            onOffsetXChanged: animX = Theme.snap(root.shouldBeVisible ? 0 : offsetX, root.dpr)
            onOffsetYChanged: animY = Theme.snap(root.shouldBeVisible ? 0 : offsetY, root.dpr)

            Connections {
                target: root
                function onShouldBeVisibleChanged() {
                    contentContainer.animX = Theme.snap(root.shouldBeVisible ? 0 : contentContainer.offsetX, root.dpr);
                    contentContainer.animY = Theme.snap(root.shouldBeVisible ? 0 : contentContainer.offsetY, root.dpr);
                    contentContainer.scaleValue = root.shouldBeVisible ? 1.0 : root.animationScaleCollapsed;
                }
            }

            Behavior on animX {
                NumberAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }

            Behavior on animY {
                NumberAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }

            Behavior on scaleValue {
                NumberAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }

            Rectangle {
                id: shadowSource
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                radius: Theme.cornerRadius
                color: "black"
                visible: false
                opacity: contentWrapper.opacity
                scale: contentWrapper.scale
                x: contentWrapper.x
                y: contentWrapper.y

                property real shadowBlurPx: 10
                property real shadowSpreadPx: 0
                property real shadowBaseAlpha: 0.60
                readonly property real popupSurfaceAlpha: SettingsData.popupTransparency
                readonly property real effectiveShadowAlpha: Math.max(0, Math.min(1, shadowBaseAlpha * popupSurfaceAlpha))
                readonly property int blurMax: 64

                layer.enabled: Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1" && !(root.suspendShadowWhileResizing && root._resizeActive)
                layer.smooth: false

                layer.effect: MultiEffect {
                    id: shadowFx
                    autoPaddingEnabled: true
                    shadowEnabled: true
                    blurEnabled: false
                    maskEnabled: false
                    shadowBlur: Math.max(0, Math.min(1, shadowSource.shadowBlurPx / shadowSource.blurMax))
                    shadowScale: 1 + (2 * shadowSource.shadowSpreadPx) / Math.max(1, Math.min(shadowSource.width, shadowSource.height))
                    shadowColor: {
                        const baseColor = Theme.isLightMode ? Qt.rgba(0, 0, 0, 1) : Theme.surfaceContainerHighest;
                        return Theme.withAlpha(baseColor, shadowSource.effectiveShadowAlpha);
                    }
                }
            }

            Item {
                id: contentWrapper
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                opacity: shouldBeVisible ? 1 : 0
                visible: opacity > 0
                scale: contentContainer.scaleValue
                x: Theme.snap(contentContainer.animX + (parent.width - width) * (1 - contentContainer.scaleValue) * 0.5, root.dpr)
                y: Theme.snap(contentContainer.animY + (parent.height - height) * (1 - contentContainer.scaleValue) * 0.5, root.dpr)

                layer.enabled: contentWrapper.opacity < 1
                layer.smooth: false
                layer.textureSize: root.dpr > 1 ? Qt.size(Math.ceil(width * root.dpr), Math.ceil(height * root.dpr)) : Qt.size(0, 0)

                Behavior on opacity {
                    NumberAnimation {
                        duration: animationDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                    border.color: Theme.outlineMedium
                    border.width: 1
                }

                Loader {
                    id: contentLoader
                    anchors.fill: parent
                    active: shouldBeVisible || contentWindow.visible
                    asynchronous: false
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
