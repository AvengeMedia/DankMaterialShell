import QtQuick
import QtQuick.Shapes
import qs.Common

Item {
    id: root

    property real size: 48
    property real strokeWidth: Math.max(2, size / 12)
    property color color: Theme.primary
    property bool running: visible

    implicitWidth: size
    implicitHeight: size

    onRunningChanged: {
        if (running)
            return;
        arc.rotation = 0;
        arc.startAngle = 0;
        arc.sweepAngle = 16;
    }

    Item {
        id: rotator

        anchors.fill: parent

        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 1568
            loops: Animation.Infinite
            running: root.running
        }

        Shape {
            id: arc

            property real startAngle: 0
            property real sweepAngle: 16

            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: arc.width / 2
                    centerY: arc.height / 2
                    radiusX: Math.max(1, (Math.min(arc.width, arc.height) - root.strokeWidth) / 2)
                    radiusY: radiusX
                    startAngle: arc.startAngle
                    sweepAngle: arc.sweepAngle
                }
            }
        }

        SequentialAnimation {
            running: root.running
            loops: Animation.Infinite

            NumberAnimation {
                target: arc
                property: "sweepAngle"
                from: 16
                to: 270
                duration: 666
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Anims.standard
            }

            ParallelAnimation {
                NumberAnimation {
                    target: arc
                    property: "startAngle"
                    from: 0
                    to: 254
                    duration: 666
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Anims.standard
                }

                NumberAnimation {
                    target: arc
                    property: "sweepAngle"
                    from: 270
                    to: 16
                    duration: 666
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Anims.standard
                }
            }

            ScriptAction {
                script: {
                    arc.rotation = (arc.rotation + 254) % 360;
                    arc.startAngle = 0;
                }
            }
        }
    }
}
