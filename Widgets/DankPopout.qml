import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Common
import qs.Services

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
    property int keyboardFocusMode: WlrKeyboardFocus.OnDemand

    signal opened
    signal popoutClosed
    signal backgroundClicked

    function open() {
        closeTimer.stop()
        shouldBeVisible = true
        visible = true
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
                popoutClosed()
            }
        }
    }

    color: "transparent"
    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: shouldBeVisible ? keyboardFocusMode : WlrKeyboardFocus.None 

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

    MouseArea {
        anchors.fill: parent
        enabled: shouldBeVisible && contentLoader.opacity > 0.1
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.x < alignedX || mouse.x > alignedX + alignedWidth ||
                mouse.y < alignedY || mouse.y > alignedY + alignedHeight) {
                backgroundClicked()
                close()
            }
        }
    }

    Loader {
        id: contentLoader
        x: alignedX
        y: alignedY
        width: alignedWidth
        height: alignedHeight
        active: root.visible
        asynchronous: false
        transformOrigin: Item.Center
        layer.enabled: Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1"
        layer.smooth: true
        layer.textureSize: Qt.size(width * Math.max(2, root.screen?.devicePixelRatio || 1), height * Math.max(2, root.screen?.devicePixelRatio || 1))
        layer.samples: 4
        opacity: shouldBeVisible ? 1 : 0
        visible: opacity > 0
        transform: [scaleTransform, motionTransform]

        Scale {
            id: scaleTransform

            origin.x: contentLoader.width / 2
            origin.y: contentLoader.height / 2
            xScale: root.shouldBeVisible ? 1 : root.animationScaleCollapsed
            yScale: root.shouldBeVisible ? 1 : root.animationScaleCollapsed

            Behavior on xScale {
                NumberAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }

            Behavior on yScale {
                NumberAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }
        }

        Translate {
            id: motionTransform

            readonly property bool barTop: SettingsData.dankBarPosition === SettingsData.Position.Top
            readonly property bool barBottom: SettingsData.dankBarPosition === SettingsData.Position.Bottom
            readonly property bool barLeft: SettingsData.dankBarPosition === SettingsData.Position.Left
            readonly property bool barRight: SettingsData.dankBarPosition === SettingsData.Position.Right
            readonly property real hiddenX: barLeft ? root.animationOffset : (barRight ? -root.animationOffset : 0)
            readonly property real hiddenY: barBottom ? -root.animationOffset : (barTop ? root.animationOffset : 0)

            x: Theme.snap(root.shouldBeVisible ? 0 : hiddenX, root.dpr)
            y: Theme.snap(root.shouldBeVisible ? 0 : hiddenY, root.dpr)

            Behavior on x {
                NumberAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration: root.animationDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: animationDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.shouldBeVisible ? root.animationEnterCurve : root.animationExitCurve
            }
        }
    }

    Item {
        x: alignedX
        y: alignedY
        width: alignedWidth
        height: alignedHeight
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                close()
                event.accepted = true
            }
        }
        Component.onCompleted: forceActiveFocus()
        onVisibleChanged: if (visible) forceActiveFocus()
    }
}
