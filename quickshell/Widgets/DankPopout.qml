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

    property real storedBarThickness: Theme.barHeight - 4
    property real storedBarSpacing: 4
    property var storedBarConfig: null
    property var adjacentBarInfo: ({ "topBar": 0, "bottomBar": 0, "leftBar": 0, "rightBar": 0 })

    visible: false

    readonly property real effectiveBarThickness: {
        const padding = storedBarConfig ? (storedBarConfig.innerPadding !== undefined ? storedBarConfig.innerPadding : 4) : 4
        return Math.max(26 + padding * 0.6, Theme.barHeight - 4 - (8 - padding)) + storedBarSpacing
    }

    readonly property var barBounds: {
        if (!root.screen) {
            return { "x": 0, "y": 0, "width": 0, "height": 0, "wingSize": 0 }
        }
        return SettingsData.getBarBounds(root.screen, effectiveBarThickness, effectiveBarPosition, storedBarConfig)
    }

    readonly property real barX: barBounds.x
    readonly property real barY: barBounds.y
    readonly property real barWidth: barBounds.width
    readonly property real barHeight: barBounds.height
    readonly property real barWingSize: barBounds.wingSize

    signal opened
    signal popoutClosed
    signal backgroundClicked

    function setBarContext(position, bottomGap) {
        effectiveBarPosition = position !== undefined ? position : 0
        effectiveBarBottomGap = bottomGap !== undefined ? bottomGap : 0
    }

    function setTriggerPosition(x, y, width, section, screen, barPosition, barThickness, barSpacing, barConfig) {
        triggerX = x
        triggerY = y
        triggerWidth = width
        triggerSection = section
        root.screen = screen

        storedBarThickness = barThickness !== undefined ? barThickness : (Theme.barHeight - 4)
        storedBarSpacing = barSpacing !== undefined ? barSpacing : 4
        storedBarConfig = barConfig

        const pos = barPosition !== undefined ? barPosition : 0
        const bottomGap = barConfig ? (barConfig.bottomGap !== undefined ? barConfig.bottomGap : 0) : 0

        // Get adjacent bar info for proper positioning
        adjacentBarInfo = SettingsData.getAdjacentBarInfo(screen, pos, barConfig)

        setBarContext(pos, bottomGap)
    }

    function open() {
        closeTimer.stop()
        shouldBeVisible = true
        visible = true
        PopoutManager.showPopout(root)
        opened()
    }

    function close() {
        shouldBeVisible = false
        PopoutManager.popoutChanged()
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
    property int effectiveBarPosition: 0
    property real effectiveBarBottomGap: 0

    readonly property real alignedX: Theme.snap((() => {
        const useAutoGaps = storedBarConfig?.popupGapsAuto !== undefined ? storedBarConfig.popupGapsAuto : true
        const manualGapValue = storedBarConfig?.popupGapsManual !== undefined ? storedBarConfig.popupGapsManual : 4
        const popupGap = useAutoGaps ? Math.max(4, storedBarSpacing) : manualGapValue

        let rawX = 0
        if (effectiveBarPosition === SettingsData.Position.Left) {
            rawX = triggerX
        } else if (effectiveBarPosition === SettingsData.Position.Right) {
            rawX = triggerX - popupWidth
        } else {
            rawX = triggerX + (triggerWidth / 2) - (popupWidth / 2)
            const minX = adjacentBarInfo.leftBar > 0 ? adjacentBarInfo.leftBar : popupGap
            const maxX = screenWidth - popupWidth - (adjacentBarInfo.rightBar > 0 ? adjacentBarInfo.rightBar : popupGap)
            return Math.max(minX, Math.min(maxX, rawX))
        }
        return Math.max(popupGap, Math.min(screenWidth - popupWidth - popupGap, rawX))
    })(), dpr)

    readonly property real alignedY: Theme.snap((() => {
        const useAutoGaps = storedBarConfig?.popupGapsAuto !== undefined ? storedBarConfig.popupGapsAuto : true
        const manualGapValue = storedBarConfig?.popupGapsManual !== undefined ? storedBarConfig.popupGapsManual : 4
        const popupGap = useAutoGaps ? Math.max(4, storedBarSpacing) : manualGapValue

        let rawY = 0
        if (effectiveBarPosition === SettingsData.Position.Bottom) {
            rawY = triggerY - popupHeight
        } else if (effectiveBarPosition === SettingsData.Position.Top) {
             rawY = triggerY
        } else {
             rawY = triggerY - (popupHeight / 2)
             const minY = adjacentBarInfo.topBar > 0 ? adjacentBarInfo.topBar : popupGap
             const maxY = screenHeight - popupHeight - (adjacentBarInfo.bottomBar > 0 ? adjacentBarInfo.bottomBar : popupGap)
             return Math.max(minY, Math.min(maxY, rawY))
        }
        return Math.max(popupGap, Math.min(screenHeight - popupHeight - popupGap, rawY))
    })(), dpr)

    readonly property real maskX: {
        const triggeringBarX = (effectiveBarPosition === SettingsData.Position.Left && root.barWidth > 0) ? root.barWidth : 0
        const adjacentLeftBar = adjacentBarInfo?.leftBar ?? 0
        return Math.max(triggeringBarX, adjacentLeftBar)
    }

    readonly property real maskY: {
        const triggeringBarY = (effectiveBarPosition === SettingsData.Position.Top && root.barHeight > 0) ? root.barHeight : 0
        const adjacentTopBar = adjacentBarInfo?.topBar ?? 0
        return Math.max(triggeringBarY, adjacentTopBar)
    }

    readonly property real maskWidth: {
        const triggeringBarRight = (effectiveBarPosition === SettingsData.Position.Right && root.barWidth > 0) ? root.barWidth : 0
        const adjacentRightBar = adjacentBarInfo?.rightBar ?? 0
        const rightExclusion = Math.max(triggeringBarRight, adjacentRightBar)
        return Math.max(100, root.width - maskX - rightExclusion)
    }

    readonly property real maskHeight: {
        const triggeringBarBottom = (effectiveBarPosition === SettingsData.Position.Bottom && root.barHeight > 0) ? root.barHeight : 0
        const adjacentBottomBar = adjacentBarInfo?.bottomBar ?? 0
        const bottomExclusion = Math.max(triggeringBarBottom, adjacentBottomBar)
        return Math.max(100, root.height - maskY - bottomExclusion)
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

                readonly property int blurMax: 64

                layer.effect: MultiEffect {
                    id: shadowFx
                    autoPaddingEnabled: true
                    shadowEnabled: true
                    blurEnabled: false
                    maskEnabled: false
                    shadowBlur: Math.max(0, Math.min(1, contentWrapper.shadowBlurPx / bgShadowLayer.blurMax))
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
