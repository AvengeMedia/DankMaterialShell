import QtQuick
import qs.Common

Rectangle {
    color: "transparent"
    radius: Appearance.rounding.normal

    readonly property var standardAnimation: {
        "duration": Appearance.anim.durations.normal,
        "easing.type": Easing.BezierSpline,
        "easing.bezierCurve": Appearance.anim.curves.standard
    }

    Behavior on radius {
        NumberAnimation {
            duration: standardAnimation.duration
            easing.type: standardAnimation["easing.type"]
            easing.bezierCurve: standardAnimation["easing.bezierCurve"]
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: standardAnimation.duration
            easing.type: standardAnimation["easing.type"]
            easing.bezierCurve: standardAnimation["easing.bezierCurve"]
        }
    }
}
