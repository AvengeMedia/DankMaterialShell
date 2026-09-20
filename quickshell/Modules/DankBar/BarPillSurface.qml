import QtQuick
import qs.Common

Rectangle {
    id: root

    property real thickness: Math.min(width, height)
    property string style: "pills"
    property bool vertical: false
    property bool joinedStart: false
    property bool joinedEnd: false
    property bool pressed: false
    property real pressProgress: pressed ? 1 : 0
    property real radiusOverride: -1
    readonly property bool mirrored: !vertical && LayoutMirroring.enabled
    readonly property real startRadius: radiusOverride >= 0 ? radiusOverride : BarMetrics.cornerRadius(thickness, style, mirrored ? joinedEnd : joinedStart, pressProgress)
    readonly property real endRadius: radiusOverride >= 0 ? radiusOverride : BarMetrics.cornerRadius(thickness, style, mirrored ? joinedStart : joinedEnd, pressProgress)

    radius: radiusOverride >= 0 ? radiusOverride : BarMetrics.cornerRadius(thickness, style, false, pressProgress)
    topLeftRadius: startRadius
    topRightRadius: vertical ? startRadius : endRadius
    bottomLeftRadius: vertical ? endRadius : startRadius
    bottomRightRadius: endRadius

    Behavior on pressProgress {
        enabled: !Theme.reduceMotion && !Theme.springMotionDisabled
        NumberAnimation {
            duration: Theme.expressiveDurations.expressiveFastSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
        }
    }
}
