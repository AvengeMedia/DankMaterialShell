import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common

Item {
    id: root
    property var toplevel
    property var scale
    required property bool overviewOpen
    property var availableWorkspaceWidth
    property var availableWorkspaceHeight
    property bool restrictToWorkspace: true

    readonly property var windowData: toplevel?.lastIpcObject || null
    readonly property var monitorObj: toplevel?.monitor
    readonly property var monitorData: monitorObj?.lastIpcObject || null

    property real initX: Math.max(((windowData?.at?.[0] ?? 0) - (monitorData?.x ?? 0) - (monitorData?.reserved?.[0] ?? 0)) * root.scale, 0) + xOffset
    property real initY: Math.max(((windowData?.at?.[1] ?? 0) - (monitorData?.y ?? 0) - (monitorData?.reserved?.[1] ?? 0)) * root.scale, 0) + yOffset
    property real xOffset: 0
    property real yOffset: 0
    property int widgetMonitorId: 0

    property var targetWindowWidth: (windowData?.size?.[0] ?? 100) * scale
    property var targetWindowHeight: (windowData?.size?.[1] ?? 100) * scale
    property bool hovered: false
    property bool pressed: false

    property var iconToWindowRatio: 0.25
    property var iconToWindowRatioCompact: 0.45
    property var entry: DesktopEntries.heuristicLookup(windowData?.class)
    property var iconPath: Quickshell.iconPath(entry?.icon ?? windowData?.class ?? "application-x-executable", "image-missing")
    property bool compactMode: Theme.fontSizeSmall * 4 > targetWindowHeight || Theme.fontSizeSmall * 4 > targetWindowWidth

    x: initX
    y: initY
    width: Math.min((windowData?.size?.[0] ?? 100) * root.scale, availableWorkspaceWidth)
    height: Math.min((windowData?.size?.[1] ?? 100) * root.scale, availableWorkspaceHeight)
    opacity: (monitorObj?.id ?? -1) == widgetMonitorId ? 1 : 0.4

    Rectangle {
        id: maskRect
        width: root.width
        height: root.height
        radius: Theme.cornerRadius
        visible: false
        layer.enabled: true
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: maskRect
        maskSpreadAtMin: 1
        maskThresholdMin: 0.5
    }

    Behavior on x {
        NumberAnimation {
            duration: Theme.expressiveDurations.expressiveDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
        }
    }
    Behavior on y {
        NumberAnimation {
            duration: Theme.expressiveDurations.expressiveDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
        }
    }
    Behavior on width {
        NumberAnimation {
            duration: Theme.expressiveDurations.expressiveDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: Theme.expressiveDurations.expressiveDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
        }
    }

    ScreencopyView {
        id: windowPreview
        anchors.fill: parent
        captureSource: root.overviewOpen ? root.toplevel?.wayland : null
        live: true

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: pressed ? Theme.withAlpha(Theme.surfaceContainerHigh, 0.5) :
                hovered ? Theme.withAlpha(Theme.surfaceVariant, 0.3) :
                Theme.withAlpha(Theme.surfaceContainer, 0.1)
            border.color: Theme.withAlpha(Theme.outline, 0.3)
            border.width: 1
        }

        ColumnLayout {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Theme.fontSizeSmall * 0.5

            Image {
                id: windowIcon
                property var iconSize: {
                    return Math.min(targetWindowWidth, targetWindowHeight) * (root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio) / (root.monitorData?.scale ?? 1)
                }
                Layout.alignment: Qt.AlignHCenter
                source: root.iconPath
                width: iconSize
                height: iconSize
                sourceSize: Qt.size(iconSize, iconSize)

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.expressiveDurations.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: Theme.expressiveDurations.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                    }
                }
            }
        }
    }
}
