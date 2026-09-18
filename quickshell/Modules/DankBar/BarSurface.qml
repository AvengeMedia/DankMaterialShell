import QtQuick
import qs.Common
import qs.Services
import qs.Modules.SurfaceWidgets

Item {
    id: root

    required property var barWindow
    required property var axis
    required property var barConfig

    readonly property bool frameShapesBar: FrameTransitionState.effectiveFrameEnabled && barWindow.usesFrameBarChrome
    readonly property bool gothEnabled: (barConfig?.gothCornersEnabled ?? false) && !(barWindow.flattenForMaximizedWindow && barWindow.hasMaximizedToplevel)
    readonly property int barPos: barConfig?.position ?? 0
    readonly property bool isTop: barPos === SettingsData.Position.Top
    readonly property bool isBottom: barPos === SettingsData.Position.Bottom
    readonly property bool isLeft: barPos === SettingsData.Position.Left
    readonly property bool isRight: barPos === SettingsData.Position.Right
    readonly property bool farEdge: isBottom || isRight
    readonly property bool edgeAttached: (barConfig?.attachToScreenEdge ?? false) && !frameShapesBar
    readonly property real wing: gothEnabled ? barWindow._wingR : 0
    readonly property real rt: {
        if (frameShapesBar)
            return SettingsData.frameRounding;
        if (barConfig?.squareCorners ?? false)
            return 0;
        if (barWindow.flattenForMaximizedWindow && barWindow.hasMaximizedToplevel)
            return 0;
        return Theme.windowRadius;
    }
    readonly property bool motionRunning: motion.running
    readonly property alias leadingWing: leadingWing
    readonly property alias trailingWing: trailingWing

    readonly property bool hasPerBarOverride: (barConfig?.shadowIntensity ?? 0) > 0
    readonly property var elevLevel: BarMetrics.elevationLevel
    readonly property bool shadowEnabled: Theme.elevationEnabled && (SettingsData.barElevationEnabled ?? true)
    readonly property string autoBarShadowDirection: isTop ? "top" : (isBottom ? "bottom" : (isLeft ? "left" : "right"))
    readonly property string globalShadowDirection: Theme.elevationLightDirection === "autoBar" ? autoBarShadowDirection : Theme.elevationLightDirection
    readonly property string perBarShadowDirectionMode: barConfig?.shadowDirectionMode ?? "inherit"
    readonly property string perBarManualShadowDirection: {
        switch (barConfig?.shadowDirection) {
        case "top":
        case "topLeft":
        case "topRight":
        case "bottom":
            return barConfig.shadowDirection;
        default:
            return "top";
        }
    }
    readonly property string effectiveShadowDirection: {
        if (!hasPerBarOverride)
            return globalShadowDirection;
        switch (perBarShadowDirectionMode) {
        case "autoBar":
            return autoBarShadowDirection;
        case "manual":
            return perBarManualShadowDirection === "autoBar" ? autoBarShadowDirection : perBarManualShadowDirection;
        default:
            return globalShadowDirection;
        }
    }
    readonly property real overrideBlurRatio: 0.2
    readonly property real overrideOffsetRatio: 0.5
    readonly property real overrideDefaultOpacityPercent: 60
    readonly property real overrideBlurPx: (barConfig?.shadowIntensity ?? 0) * overrideBlurRatio
    readonly property real overrideOpacity: (barConfig?.shadowOpacity ?? overrideDefaultOpacityPercent) / 100
    readonly property color overrideBaseColor: {
        switch (barConfig?.shadowColorMode ?? "default") {
        case "surface":
            return Theme.surface;
        case "primary":
            return Theme.primary;
        case "secondary":
            return Theme.secondary;
        case "custom":
            return barConfig?.shadowCustomColor ?? Theme.scrimColor;
        default:
            return Theme.scrimColor;
        }
    }
    readonly property real shadowBlurPx: hasPerBarOverride ? overrideBlurPx : (elevLevel.blurPx ?? 0)
    readonly property color shadowColor: hasPerBarOverride ? Theme.withAlpha(overrideBaseColor, overrideOpacity) : Theme.elevationShadowColor(elevLevel)
    readonly property real shadowOffsetMagnitude: hasPerBarOverride ? (overrideBlurPx * overrideOffsetRatio) : Theme.elevationOffsetMagnitude(elevLevel, Theme.spacingXS, effectiveShadowDirection)
    readonly property real shadowOffsetX: Theme.elevationOffsetXFor(hasPerBarOverride ? null : elevLevel, effectiveShadowDirection, shadowOffsetMagnitude)
    readonly property real shadowOffsetY: Theme.elevationOffsetYFor(hasPerBarOverride ? null : elevLevel, effectiveShadowDirection, shadowOffsetMagnitude)

    readonly property real attachedRadius: edgeAttached || frameShapesBar ? 0 : rt
    readonly property real wingRootRadius: gothEnabled ? 0 : rt
    readonly property var shapeTarget: ({
            width: Math.max(0, axis.isVertical ? width - wing : width),
            height: Math.max(0, axis.isVertical ? height : height - wing),
            offsetAlong: wing,
            offsetCross: farEdge ? wing : 0,
            topLeftRadius: isTop || isLeft ? attachedRadius : wingRootRadius,
            topRightRadius: isTop || isRight ? attachedRadius : wingRootRadius,
            bottomLeftRadius: isBottom || isLeft ? attachedRadius : wingRootRadius,
            bottomRightRadius: isBottom || isRight ? attachedRadius : wingRootRadius
        })

    visible: !frameShapesBar
    anchors.fill: parent
    anchors.leftMargin: -(gothEnabled && isRight ? barWindow._wingR : 0)
    anchors.rightMargin: -(gothEnabled && isLeft ? barWindow._wingR : 0)
    anchors.topMargin: -(gothEnabled && isBottom ? barWindow._wingR : 0)
    anchors.bottomMargin: -(gothEnabled && isTop ? barWindow._wingR : 0)

    function applyTarget() {
        if (width <= 0 || height <= 0 || !visible) {
            motion.snapTo(shapeTarget);
            return;
        }
        motion.setTarget(shapeTarget);
    }

    onShapeTargetChanged: applyTarget()
    Component.onCompleted: motion.snapTo(shapeTarget)

    VectorSpringMotion {
        id: motion

        readonly property var preset: Theme.springPreset("default", Theme.shortDuration)
        reducedMotion: Theme.springMotionDisabled || SettingsData.reduceMotion
        stiffness: preset.stiffness
        damping: preset.damping
        mass: preset.mass
        onRunningChanged: {
            if (!running)
                snapTo(root.shapeTarget);
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        z: -999
        onClicked: {
            const activePopout = PopoutManager.getActivePopout(root.barWindow.screen);
            if (activePopout) {
                if (activePopout.dashVisible !== undefined) {
                    activePopout.dashVisible = false;
                } else if (activePopout.notificationHistoryVisible !== undefined) {
                    activePopout.notificationHistoryVisible = false;
                } else {
                    activePopout.close();
                }
            }
            TrayMenuManager.closeAllMenus();
        }
    }

    ElevationShadow {
        visible: root.shadowEnabled && root.width > 0 && root.height > 0
        x: body.x
        y: body.y
        width: body.width
        height: body.height
        shadowEnabled: root.shadowEnabled
        level: root.hasPerBarOverride ? null : root.elevLevel
        direction: root.effectiveShadowDirection
        fallbackOffset: Theme.spacingXS
        topLeftRadius: body.topLeftRadius
        topRightRadius: body.topRightRadius
        bottomLeftRadius: body.bottomLeftRadius
        bottomRightRadius: body.bottomRightRadius
        targetColor: "transparent"
        shadowBlurPx: root.shadowBlurPx
        shadowOffsetX: root.shadowOffsetX
        shadowOffsetY: root.shadowOffsetY
        shadowColor: root.shadowColor
    }

    MorphSurface {
        id: body
        motion: motion
        x: root.axis.isVertical ? Math.max(0, motion.currentOffsetCross) : 0
        y: root.axis.isVertical ? 0 : Math.max(0, motion.currentOffsetCross)
        color: root.barWindow._bgColor
    }

    GothCorner {
        id: leadingWing
        radius: Math.max(0, motion.currentOffsetAlong)
        color: root.barWindow._bgColor
        visible: root.gothEnabled && radius > 0
        x: root.isLeft ? body.width : 0
        y: root.isTop ? body.height : 0
        corner: root.isTop ? "bottomRight" : root.isBottom ? "topRight" : root.isLeft ? "bottomRight" : "bottomLeft"
    }

    GothCorner {
        id: trailingWing
        radius: Math.max(0, motion.currentOffsetAlong)
        color: root.barWindow._bgColor
        visible: root.gothEnabled && radius > 0
        x: root.axis.isVertical ? (root.isLeft ? body.width : 0) : root.width - radius
        y: root.axis.isVertical ? root.height - radius : (root.isTop ? body.height : 0)
        corner: root.isTop ? "bottomLeft" : root.isBottom ? "topLeft" : root.isLeft ? "topRight" : "topLeft"
    }

    Rectangle {
        id: border
        readonly property real thickness: Theme.snap(Math.max(Theme.outlineWidth, barConfig?.borderThickness ?? Theme.outlineWidth), CompositorService.getScreenScale(root.barWindow.screen))
        readonly property string colorKey: barConfig?.borderColor || "surfaceText"
        readonly property color baseColor: colorKey === "surfaceText" ? Theme.surfaceText : colorKey === "primary" ? Theme.primary : Theme.secondary
        readonly property bool showFullBorder: (barConfig?.spacing ?? 4) > 0
        z: 100
        visible: barConfig?.borderEnabled ?? false
        x: body.x - (!showFullBorder && root.isRight ? thickness : 0)
        y: body.y - (!showFullBorder && root.isBottom ? thickness : 0)
        width: body.width + (!showFullBorder && (root.isLeft || root.isRight) ? thickness : 0)
        height: body.height + (!showFullBorder && (root.isTop || root.isBottom) ? thickness : 0)
        topLeftRadius: body.topLeftRadius
        topRightRadius: body.topRightRadius
        bottomLeftRadius: body.bottomLeftRadius
        bottomRightRadius: body.bottomRightRadius
        color: "transparent"
        border.width: thickness
        border.color: Theme.withAlpha(baseColor, barConfig?.borderOpacity ?? 1.0)
    }
}
