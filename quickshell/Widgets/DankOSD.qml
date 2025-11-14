import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    property string blurNamespace: "dms:osd"
    WlrLayershell.namespace: blurNamespace

    property alias content: contentLoader.sourceComponent
    property alias contentLoader: contentLoader
    property var modelData
    property bool shouldBeVisible: false
    property int autoHideInterval: 2000
    property bool enableMouseInteraction: false
    property real osdWidth: Theme.iconSize + Theme.spacingS * 2
    property real osdHeight: Theme.iconSize + Theme.spacingS * 2
    property int animationDuration: Theme.mediumDuration
    property var animationEasing: Theme.emphasizedEasing

    signal osdShown
    signal osdHidden

    function show() {
        OSDManager.showOSD(root)
        closeTimer.stop()
        shouldBeVisible = true
        visible = true
        hideTimer.restart()
        osdShown()
    }

    function hide() {
        shouldBeVisible = false
        closeTimer.restart()
    }

    function resetHideTimer() {
        if (shouldBeVisible) {
            hideTimer.restart()
        }
    }

    function updateHoverState() {
        let isHovered = (enableMouseInteraction && mouseArea.containsMouse) || osdContainer.childHovered
        if (enableMouseInteraction) {
            if (isHovered) {
                hideTimer.stop()
            } else if (shouldBeVisible) {
                hideTimer.restart()
            }
        }
    }

    function setChildHovered(hovered) {
        osdContainer.childHovered = hovered
        updateHoverState()
    }

    screen: modelData
    visible: false
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    readonly property real dpr: CompositorService.getScreenScale(screen)
    readonly property real screenWidth: screen.width
    readonly property real screenHeight: screen.height
    readonly property real alignedWidth: Theme.px(osdWidth, dpr)
    readonly property real alignedHeight: Theme.px(osdHeight, dpr)
    readonly property real alignedX: Theme.snap((screenWidth - alignedWidth) / 2, dpr)
    readonly property real alignedY: Theme.snap(screenHeight - alignedHeight - Theme.spacingM, dpr)

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    Timer {
        id: hideTimer

        interval: autoHideInterval
        repeat: false
        onTriggered: {
            if (!enableMouseInteraction || !mouseArea.containsMouse) {
                hide()
            } else {
                hideTimer.restart()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: animationDuration + 50
        onTriggered: {
            if (!shouldBeVisible) {
                visible = false
                osdHidden()
            }
        }
    }

    Item {
        id: osdContainer
        x: alignedX
        y: alignedY
        width: alignedWidth
        height: alignedHeight
        opacity: shouldBeVisible ? 1 : 0
        scale: shouldBeVisible ? 1 : 0.9

        property bool childHovered: false
        property real shadowBlurPx: 10
        property real shadowSpreadPx: 0
        property real shadowBaseAlpha: 0.60
        readonly property real popupSurfaceAlpha: SettingsData.popupTransparency
        readonly property real effectiveShadowAlpha: Math.max(0, Math.min(1, shadowBaseAlpha * popupSurfaceAlpha * osdContainer.opacity))

        Item {
            id: bgShadowLayer
            anchors.fill: parent
            visible: osdContainer.popupSurfaceAlpha >= 0.95
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
                shadowBlur: Math.max(0, Math.min(1, osdContainer.shadowBlurPx / blurMax))
                shadowScale: 1 + (2 * osdContainer.shadowSpreadPx) / Math.max(1, Math.min(bgShadowLayer.width, bgShadowLayer.height))
                shadowColor: {
                    const baseColor = Theme.isLightMode ? Qt.rgba(0, 0, 0, 1) : Theme.surfaceContainerHighest
                    return Theme.withAlpha(baseColor, osdContainer.effectiveShadowAlpha)
                }
            }

            DankRectangle {
                anchors.fill: parent
                radius: Theme.cornerRadius
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: enableMouseInteraction
            acceptedButtons: Qt.NoButton
            propagateComposedEvents: true
            z: -1
            onContainsMouseChanged: updateHoverState()
        }

        onChildHoveredChanged: updateHoverState()

        Loader {
            id: contentLoader
            anchors.fill: parent
            active: root.visible
            asynchronous: false
        }

        Behavior on opacity {
            NumberAnimation {
                duration: animationDuration
                easing.type: animationEasing
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: animationDuration
                easing.type: animationEasing
            }
        }
    }

    mask: Region {
        item: bgShadowLayer
    }
}
