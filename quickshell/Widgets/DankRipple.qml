import QtQuick
import QtQuick.Effects
import qs.Common

Item {
    id: root

    property color rippleColor: Theme.primary
    property real cornerRadius: 0
    property bool enableRipple: typeof SettingsData !== "undefined" ? (SettingsData.enableRippleEffects ?? true) : true

    property real _rippleX: 0
    property real _rippleY: 0
    property real _rippleSize: 0
    readonly property alias animating: rippleAnim.running

    anchors.fill: parent

    function trigger(x, y) {
        if (!enableRipple || Theme.currentAnimationSpeed === SettingsData.AnimationSpeed.None)
            return;

        _rippleX = x;
        _rippleY = y;

        const dist = (ox, oy) => ox * ox + oy * oy;
        _rippleSize = Math.sqrt(Math.max(dist(x, y), dist(x, height - y), dist(width - x, y), dist(width - x, height - y))) * 2;

        rippleAnim.restart();
    }

    SequentialAnimation {
        id: rippleAnim

        PropertyAction {
            target: ripple
            property: "x"
            value: root._rippleX
        }
        PropertyAction {
            target: ripple
            property: "y"
            value: root._rippleY
        }
        PropertyAction {
            target: ripple
            property: "implicitWidth"
            value: 0
        }
        PropertyAction {
            target: ripple
            property: "implicitHeight"
            value: 0
        }
        PropertyAction {
            target: ripple
            property: "opacity"
            value: 0.10
        }

        ParallelAnimation {
            DankAnim {
                target: ripple
                property: "implicitWidth"
                from: 0
                to: root._rippleSize
                duration: Theme.expressiveDurations.expressiveDefaultSpatial
                easing.bezierCurve: Theme.expressiveCurves.standardDecel
            }
            DankAnim {
                target: ripple
                property: "implicitHeight"
                from: 0
                to: root._rippleSize
                duration: Theme.expressiveDurations.expressiveDefaultSpatial
                easing.bezierCurve: Theme.expressiveCurves.standardDecel
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: Math.round(Theme.expressiveDurations.expressiveDefaultSpatial * 0.6)
                }
                DankAnim {
                    target: ripple
                    property: "opacity"
                    to: 0
                    duration: Theme.expressiveDurations.expressiveDefaultSpatial
                    easing.bezierCurve: Theme.expressiveCurves.standard
                }
            }
        }
    }

    Item {
        id: rippleContainer
        anchors.fill: parent
        visible: root.cornerRadius <= 0

        Rectangle {
            id: ripple

            radius: Math.min(width, height) / 2
            color: root.rippleColor
            opacity: 0

            transform: Translate {
                x: -ripple.width / 2
                y: -ripple.height / 2
            }
        }
    }

    Item {
        id: rippleMask
        anchors.fill: parent
        layer.enabled: root.cornerRadius > 0
        layer.smooth: true
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            color: "black"
            antialiasing: true
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: rippleContainer
        maskEnabled: true
        maskSource: rippleMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        visible: root.cornerRadius > 0 && rippleAnim.running
    }
}
