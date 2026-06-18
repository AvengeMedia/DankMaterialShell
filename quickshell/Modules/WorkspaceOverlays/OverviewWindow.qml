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
    property real monitorDpr: 1
    property real contentOriginX: 0
    property real contentOriginY: 0
    property real contentScale: 0

    readonly property var windowData: toplevel?.lastIpcObject || null
    readonly property var monitorObj: toplevel?.monitor
    readonly property var monitorData: monitorObj?.lastIpcObject || null
    readonly property real effectiveScale: root.scale / root.monitorDpr
    readonly property real overviewScale: root.contentScale > 0 ? root.contentScale : root.effectiveScale

    readonly property real rawX: ((windowData?.at?.[0] ?? 0) - contentOriginX) * overviewScale
    readonly property real rawY: ((windowData?.at?.[1] ?? 0) - contentOriginY) * overviewScale
    readonly property real rawWidth: (windowData?.size?.[0] ?? 100) * overviewScale
    readonly property real rawHeight: (windowData?.size?.[1] ?? 100) * overviewScale
    readonly property real clipLeft: Math.max(0, rawX)
    readonly property real clipTop: Math.max(0, rawY)
    readonly property real clipRight: Math.min(availableWorkspaceWidth, rawX + rawWidth)
    readonly property real clipBottom: Math.min(availableWorkspaceHeight, rawY + rawHeight)
    readonly property bool intersectsViewport: clipRight > clipLeft && clipBottom > clipTop

    property real initX: clipLeft + xOffset
    property real initY: clipTop + yOffset
    property real xOffset: 0
    property real yOffset: 0
    property int widgetMonitorId: 0

    property var targetWindowWidth: Math.max(clipRight - clipLeft, 0)
    property var targetWindowHeight: Math.max(clipBottom - clipTop, 0)
    property bool hovered: false
    property bool pressed: false

    property var iconToWindowRatio: 0.25
    property var iconToWindowRatioCompact: 0.45
    property var entry: DesktopEntries.heuristicLookup(Paths.moddedAppId(windowData?.class ?? ""))
    property var iconPath: Paths.getAppIcon(windowData?.class ?? "", entry) || Quickshell.iconPath("application-x-executable", "image-missing")
    property bool compactMode: Theme.fontSizeSmall * 4 > targetWindowHeight || Theme.fontSizeSmall * 4 > targetWindowWidth

    x: initX
    y: initY
    width: targetWindowWidth
    height: targetWindowHeight
    visible: intersectsViewport
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
            duration: Theme.variantDuration(Theme.expressiveDurations.expressiveDefaultSpatial, overviewOpen)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.variantModalEnterCurve
        }
    }
    Behavior on y {
        NumberAnimation {
            duration: Theme.variantDuration(Theme.expressiveDurations.expressiveDefaultSpatial, overviewOpen)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.variantModalEnterCurve
        }
    }
    Behavior on width {
        NumberAnimation {
            duration: Theme.variantDuration(Theme.expressiveDurations.expressiveDefaultSpatial, overviewOpen)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.variantModalEnterCurve
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: Theme.variantDuration(Theme.expressiveDurations.expressiveDefaultSpatial, overviewOpen)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.variantModalEnterCurve
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
                        duration: Theme.variantDuration(Theme.expressiveDurations.expressiveDefaultSpatial, overviewOpen)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.variantModalEnterCurve
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: Theme.variantDuration(Theme.expressiveDurations.expressiveDefaultSpatial, overviewOpen)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.variantModalEnterCurve
                    }
                }
            }
        }
    }
}
