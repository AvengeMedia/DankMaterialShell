import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    property string layerNamespace: "dms:popout"
    WlrLayershell.namespace: layerNamespace

    property alias content: contentLoader.sourceComponent
    property alias contentLoader: contentLoader
    property real popupWidth: 400
    property real popupHeight: 300
    property real triggerX: 0
    property real triggerY: 0
    property real triggerWidth: 40
    property string triggerSection: ""
    property string positioning: "center"
    property int animationDuration: Theme.expressiveDurations.expressiveDefaultSpatial
    property real animationScaleCollapsed: 0.96
    property real animationOffset: Theme.spacingL
    property list<real> animationEnterCurve: Theme.expressiveCurves.expressiveDefaultSpatial
    property list<real> animationExitCurve: Theme.expressiveCurves.emphasized
    property bool shouldBeVisible: false

    visible: false

    readonly property real effectiveBarThickness: Math.max(26 + SettingsData.dankBarInnerPadding * 0.6, Theme.barHeight - 4 - (8 - SettingsData.dankBarInnerPadding)) + SettingsData.dankBarSpacing

    readonly property var barBounds: {
        if (!root.screen) {
            return { "x": 0, "y": 0, "width": 0, "height": 0, "wingSize": 0 }
        }
        return SettingsData.getBarBounds(root.screen, effectiveBarThickness)
    }

    readonly property real barX: barBounds.x
    readonly property real barY: barBounds.y
    readonly property real barWidth: barBounds.width
    readonly property real barHeight: barBounds.height
    readonly property real barWingSize: barBounds.wingSize

    signal opened
    signal popoutClosed
    signal backgroundClicked

    function open() {
        closeTimer.stop()
        shouldBeVisible = true
        visible = true
        PopoutManager.showPopout(root)
        opened()
    }

    function close() {
        shouldBeVisible = false
        closeTimer.restart()
    }

    function toggle() {
        if (shouldBeVisible)
            close()
        else
            open()
    }

    Timer {
        id: closeTimer
        interval: animationDuration
        onTriggered: {
            if (!shouldBeVisible) {
                visible = false
                PopoutManager.hidePopout(root)
                popoutClosed()
            }
        }
    }

    color: "transparent"
    WlrLayershell.layer: {
        switch (Quickshell.env("DMS_POPOUT_LAYER")) {
        case "bottom":
            return WlrLayershell.Bottom
        case "overlay":
            return WlrLayershell.Overlay
        case "background":
            return WlrLayershell.Background
        default:
            return WlrLayershell.Top
        }
    }
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: {
        if (!shouldBeVisible) return WlrKeyboardFocus.None
        if (CompositorService.isHyprland) return WlrKeyboardFocus.OnDemand
        return WlrKeyboardFocus.Exclusive
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    readonly property real screenWidth: root.screen.width
    readonly property real screenHeight: root.screen.height
    readonly property real dpr: CompositorService.getScreenScale(root.screen)

    readonly property real alignedWidth: Theme.px(popupWidth, dpr)
    readonly property real alignedHeight: Theme.px(popupHeight, dpr)
    readonly property real alignedX: Theme.snap((() => {
        if (SettingsData.dankBarPosition === SettingsData.Position.Left) {
            return triggerY + SettingsData.dankBarBottomGap
        } else if (SettingsData.dankBarPosition === SettingsData.Position.Right) {
            return screenWidth - triggerY - SettingsData.dankBarBottomGap - popupWidth
        } else {
            const centerX = triggerX + (triggerWidth / 2) - (popupWidth / 2)
            return Math.max(Theme.popupDistance, Math.min(screenWidth - popupWidth - Theme.popupDistance, centerX))
        }
    })(), dpr)
    readonly property real alignedY: Theme.snap((() => {
        if (SettingsData.dankBarPosition === SettingsData.Position.Left || SettingsData.dankBarPosition === SettingsData.Position.Right) {
            const centerY = triggerX + (triggerWidth / 2) - (popupHeight / 2)
            return Math.max(Theme.popupDistance, Math.min(screenHeight - popupHeight - Theme.popupDistance, centerY))
        } else if (SettingsData.dankBarPosition === SettingsData.Position.Bottom) {
            return Math.max(Theme.popupDistance, screenHeight - triggerY - popupHeight)
        } else {
            return Math.min(screenHeight - popupHeight - Theme.popupDistance, triggerY)
        }
    })(), dpr)

    readonly property real maskX: {
        switch (SettingsData.dankBarPosition) {
        case SettingsData.Position.Left:
            return root.barWidth > 0 ? root.barWidth : 0
        case SettingsData.Position.Right:
        case SettingsData.Position.Top:
        case SettingsData.Position.Bottom:
        default:
            return 0
        }
    }

    readonly property real maskY: {
        switch (SettingsData.dankBarPosition) {
        case SettingsData.Position.Top:
            return root.barHeight > 0 ? root.barHeight : 0
        case SettingsData.Position.Bottom:
        case SettingsData.Position.Left:
        case SettingsData.Position.Right:
        default:
            return 0
        }
    }

    readonly property real maskWidth: {
        switch (SettingsData.dankBarPosition) {
        case SettingsData.Position.Left:
            return root.barWidth > 0 ? root.width - root.barWidth : root.width
        case SettingsData.Position.Right:
            return root.barWidth > 0 ? root.width - root.barWidth : root.width
        case SettingsData.Position.Top:
        case SettingsData.Position.Bottom:
        default:
            return root.width
        }
    }

    readonly property real maskHeight: {
        switch (SettingsData.dankBarPosition) {
        case SettingsData.Position.Top:
            return root.barHeight > 0 ? root.height - root.barHeight : root.height
        case SettingsData.Position.Bottom:
            return root.barHeight > 0 ? root.height - root.barHeight : root.height
        case SettingsData.Position.Left:
        case SettingsData.Position.Right:
        default:
            return root.height
        }
    }

    mask: Region {
        item: Rectangle {
            x: root.maskX
            y: root.maskY
            width: root.maskWidth
            height: root.maskHeight
        }
    }

    MouseArea {
        x: maskX
        y: maskY
        width: maskWidth
        height: maskHeight
        z: -1
        enabled: shouldBeVisible
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            const clickX = mouse.x + maskX
            const clickY = mouse.y + maskY
            const outsideContent = clickX < alignedX || clickX > alignedX + alignedWidth ||
                                   clickY < alignedY || clickY > alignedY + alignedHeight

            if (!outsideContent) return

            backgroundClicked()
        }
    }

    Item {
        id: contentContainer
        x: alignedX
        y: alignedY
        width: alignedWidth
        height: alignedHeight

        readonly property bool barTop: SettingsData.dankBarPosition === SettingsData.Position.Top
        readonly property bool barBottom: SettingsData.dankBarPosition === SettingsData.Position.Bottom
        readonly property bool barLeft: SettingsData.dankBarPosition === SettingsData.Position.Left
        readonly property bool barRight: SettingsData.dankBarPosition === SettingsData.Position.Right
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
                contentContainer.animX = Theme.snap(root.shouldBeVisible ? 0 : contentContainer.offsetX, root.dpr)
                contentContainer.animY = Theme.snap(root.shouldBeVisible ? 0 : contentContainer.offsetY, root.dpr)
                contentContainer.scaleValue = root.shouldBeVisible ? 1.0 : root.animationScaleCollapsed
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

            property real shadowBlurPx: 10
            property real shadowSpreadPx: 0
            property real shadowBaseAlpha: 0.60
            readonly property real popupSurfaceAlpha: SettingsData.popupTransparency
            readonly property real effectiveShadowAlpha: Math.max(0, Math.min(1, shadowBaseAlpha * popupSurfaceAlpha * contentWrapper.opacity))

            Behavior on opacity {
                NumberAnimation {
                    duration: animationDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }

            Item {
                id: bgShadowLayer
                anchors.fill: parent
                visible: contentWrapper.popupSurfaceAlpha >= 0.95
                layer.enabled: Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1"
                layer.smooth: false
                layer.textureSize: Qt.size(Math.round(width * root.dpr), Math.round(height * root.dpr))
                layer.textureMirroring: ShaderEffectSource.MirrorVertically

                layer.effect: MultiEffect {
                    id: shadowFx
                    autoPaddingEnabled: true
                    shadowEnabled: true
                    blurEnabled: false
                    maskEnabled: false
                    property int blurMax: 64
                    shadowBlur: Math.max(0, Math.min(1, contentWrapper.shadowBlurPx / blurMax))
                    shadowScale: 1 + (2 * contentWrapper.shadowSpreadPx) / Math.max(1, Math.min(bgShadowLayer.width, bgShadowLayer.height))
                    shadowColor: {
                        const baseColor = Theme.isLightMode ? Qt.rgba(0, 0, 0, 1) : Theme.surfaceContainerHighest
                        return Theme.withAlpha(baseColor, contentWrapper.effectiveShadowAlpha)
                    }
                }

                DankRectangle {
                    anchors.fill: parent
                    radius: Theme.cornerRadius
                }
            }

            Item {
                id: contentLoaderWrapper
                anchors.fill: parent
                x: Theme.snap(x, root.dpr)
                y: Theme.snap(y, root.dpr)

                Loader {
                    id: contentLoader
                    anchors.fill: parent
                    active: root.visible
                    asynchronous: false
                }
            }
        }
    }

    Item {
        id: focusHelper
        parent: contentContainer
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                close()
                event.accepted = true
            }
        }
    }
}
