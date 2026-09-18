import QtQuick
import qs.Common

QtObject {
    id: root

    property bool hovered: false
    property bool suppressed: false
    property bool barHosted: false
    property int position: SettingsData.Position.Bottom
    property real distance: 40
    property real offset: 0
    readonly property bool enabled: !Theme.springMotionDisabled && !barHosted
    readonly property real direction: position === SettingsData.Position.Top || position === SettingsData.Position.Left ? 1 : -1

    onHoveredChanged: {
        if (!enabled || suppressed)
            return;
        if (!hovered) {
            bounce.stop();
            exit.restart();
            return;
        }
        exit.stop();
        if (!bounce.running)
            bounce.restart();
    }

    readonly property SequentialAnimation bounce: SequentialAnimation {
        NumberAnimation {
            target: root
            property: "offset"
            to: root.direction * root.distance * 0.25
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.emphasizedAccel
        }

        NumberAnimation {
            target: root
            property: "offset"
            to: root.direction * root.distance * 0.2
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.emphasizedDecel
        }
    }

    readonly property NumberAnimation exit: NumberAnimation {
        target: root
        property: "offset"
        to: 0
        duration: Anims.durShort
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Anims.emphasizedDecel
    }
}
