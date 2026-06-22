import QtQuick
import qs.Common

Item {
    id: root

    property color rippleColor: Theme.primary
    property real cornerRadius: 0
    property bool enableRipple: typeof SettingsData !== "undefined" ? (SettingsData.enableRippleEffects ?? true) : true
    property int animationDuration: Theme.expressiveDurations.expressiveDefaultSpatial

    property real _rippleX: 0
    property real _rippleY: 0
    property real _rippleMaxRadius: 0
    readonly property alias animating: rippleAnim.running

    anchors.fill: parent

    function trigger(x, y) {
        if (!enableRipple || Theme.currentAnimationSpeed === SettingsData.AnimationSpeed.None)
            return;

        _rippleX = x;
        _rippleY = y;

        const dist = (ox, oy) => ox * ox + oy * oy;
        _rippleMaxRadius = Math.sqrt(Math.max(dist(x, y), dist(x, height - y), dist(width - x, y), dist(width - x, height - y)));

        rippleAnim.restart();
    }

    SequentialAnimation {
        id: rippleAnim

        PropertyAction {
            target: rippleFx
            property: "rippleCenterX"
            value: root._rippleX
        }
        PropertyAction {
            target: rippleFx
            property: "rippleCenterY"
            value: root._rippleY
        }
        PropertyAction {
            target: rippleFx
            property: "rippleRadius"
            value: 0
        }
        PropertyAction {
            target: rippleFx
            property: "rippleOpacity"
            value: 0.10
        }

        ParallelAnimation {
            DankAnim {
                target: rippleFx
                property: "rippleRadius"
                from: 0
                to: root._rippleMaxRadius
                duration: root.animationDuration
                easing.bezierCurve: Theme.expressiveCurves.standardDecel
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: Math.round(root.animationDuration * 0.6)
                }
                DankAnim {
                    target: rippleFx
                    property: "rippleOpacity"
                    to: 0
                    duration: root.animationDuration
                    easing.bezierCurve: Theme.expressiveCurves.standard
                }
            }
        }
    }

    ShaderEffect {
        id: rippleFx
        visible: rippleAnim.running

        property real rippleCenterX: 0
        property real rippleCenterY: 0
        property real rippleRadius: 0
        property real rippleOpacity: 0

        x: Math.max(0, rippleCenterX - rippleRadius)
        y: Math.max(0, rippleCenterY - rippleRadius)
        width: Math.max(0, Math.min(root.width, rippleCenterX + rippleRadius) - x)
        height: Math.max(0, Math.min(root.height, rippleCenterY + rippleRadius) - y)

        property real widthPx: width
        property real heightPx: height
        property real cornerRadiusPx: root.cornerRadius
        property real offsetX: x
        property real offsetY: y
        property real parentWidth: root.width
        property real parentHeight: root.height
        property vector4d rippleCol: Qt.vector4d(root.rippleColor.r, root.rippleColor.g, root.rippleColor.b, root.rippleColor.a)

        fragmentShader: Qt.resolvedUrl("../Shaders/qsb/ripple.frag.qsb")
    }
}
