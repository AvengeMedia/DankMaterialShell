import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.DankBar

Item {
    id: root

    property var axis: null
    property bool surfaceLive: true
    property string section: "center"
    property var popoutTarget: null
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48
    property real barSpacing: 4
    property var barConfig: null
    property bool noBackground: barConfig?.noBackground ?? false
    property var blurBarWindow: null
    property alias content: contentLoader.sourceComponent
    property bool isVerticalOrientation: axis?.isVertical ?? false
    property bool isFirst: false
    property bool isLast: false
    property real sectionSpacing: 0
    property bool enableBackgroundHover: true
    property bool enableCursor: true
    property bool isAutoHideBar: false
    readonly property bool isMouseHovered: mouseArea.containsMouse || visualContent.hovered
    property bool isLeftBarEdge: false
    property bool isRightBarEdge: false
    property bool isTopBarEdge: false
    property bool isBottomBarEdge: false
    property real crossEdgeExtension: 0
    property string segmentRole: "solo"
    property real splitOffset: 0
    readonly property color contentColor: Theme.widgetTextColor
    readonly property real dpr: parentScreen ? CompositorService.getScreenScale(parentScreen) : 1
    readonly property real horizontalPadding: Theme.snap((barConfig?.widgetPadding ?? 8) * (widgetThickness / 30), dpr)
    readonly property real contentThickness: widgetThickness - horizontalPadding * 2
    readonly property real visualWidth: Theme.snap(isVerticalOrientation ? widgetThickness : (contentLoader.item ? (contentLoader.item.implicitWidth + horizontalPadding * 2) : 0), dpr)
    readonly property real visualHeight: Theme.snap(isVerticalOrientation ? (contentLoader.item ? (contentLoader.item.implicitHeight + horizontalPadding * 2) : 0) : widgetThickness, dpr)
    readonly property alias visualContent: visualContent
    readonly property real barEdgeExtension: BarMetrics.fittsReach
    readonly property real gapExtension: sectionSpacing
    readonly property real leftMargin: !isVerticalOrientation ? (isLeftBarEdge && isFirst ? barEdgeExtension : (isFirst ? gapExtension : gapExtension / 2)) : 0
    readonly property real rightMargin: !isVerticalOrientation ? (isRightBarEdge && isLast ? barEdgeExtension : (isLast ? gapExtension : gapExtension / 2)) : 0
    readonly property real topMargin: isVerticalOrientation ? (isTopBarEdge && isFirst ? barEdgeExtension : (isFirst ? gapExtension : gapExtension / 2)) : (axis?.edge === "top" ? crossEdgeExtension : 0)
    readonly property real bottomMargin: isVerticalOrientation ? (isBottomBarEdge && isLast ? barEdgeExtension : (isLast ? gapExtension : gapExtension / 2)) : (axis?.edge === "bottom" ? crossEdgeExtension : 0)
    readonly property real minTooltipY: {
        if (!parentScreen || !isVerticalOrientation || isAutoHideBar)
            return 0;
        return parentScreen.y > 0 ? barThickness + barSpacing : 0;
    }
    readonly property bool barUsesOverlayLayer: LayerShell.envUsesOverlay("DMS_DANKBAR_LAYER", (barConfig?.useOverlayLayer ?? false) || CompositorService.framePeerSurfacesUseOverlayForScreen(parentScreen))

    readonly property bool mirrored: !isVerticalOrientation && LayoutMirroring.enabled
    readonly property bool leadingJoined: segmentRole === "middle" || segmentRole === "last"
    readonly property bool trailingJoined: segmentRole === "middle" || segmentRole === "first"
    readonly property bool startJoined: isVerticalOrientation || !mirrored ? leadingJoined : trailingJoined
    readonly property bool endJoined: isVerticalOrientation || !mirrored ? trailingJoined : leadingJoined
    readonly property real outerRadius: noBackground ? 0 : BarMetrics.pillRadius(widgetThickness, BarMetrics.widgetStyle(barConfig))
    readonly property real innerRadius: noBackground ? 0 : BarMetrics.segmentInnerRadius
    property var pressSource: null
    readonly property bool pressed: mouseArea.pressed || (pressSource?.pressed ?? false)
    property real pressProgress: pressed && enableBackgroundHover ? 1 : 0
    readonly property real blurRadius: segmentRole === "solo" ? outerRadius : innerRadius
    readonly property bool radiusMotion: !SettingsData.reduceMotion && !Theme.springMotionDisabled
    readonly property real outlineThickness: (barConfig?.widgetOutlineEnabled ?? false) ? (barConfig?.widgetOutlineThickness ?? Theme.outlineWidth) : 0
    readonly property color outlineColor: {
        if (outlineThickness <= 0)
            return "transparent";
        const opacity = barConfig?.widgetOutlineOpacity ?? 1.0;
        switch (barConfig?.widgetOutlineColor || "primary") {
        case "surfaceText":
            return Theme.withAlpha(Theme.surfaceText, opacity);
        case "secondary":
            return Theme.withAlpha(Theme.secondary, opacity);
        default:
            return Theme.withAlpha(Theme.primary, opacity);
        }
    }
    readonly property color fillColor: {
        if (noBackground)
            return "transparent";
        const transparency = barConfig?.widgetTransparency ?? 1.0;
        const baseColor = Theme.widgetBaseBackgroundColor;
        if (Theme.widgetBackgroundHasAlpha)
            return Theme.blendAlpha(baseColor, transparency);
        return Theme.withAlpha(baseColor, transparency);
    }

    property real topLeftRadius: cornerRadius(startJoined)
    property real topRightRadius: cornerRadius(isVerticalOrientation ? startJoined : endJoined)
    property real bottomLeftRadius: cornerRadius(isVerticalOrientation ? endJoined : startJoined)
    property real bottomRightRadius: cornerRadius(endJoined)

    Behavior on pressProgress {
        enabled: root.radiusMotion
        NumberAnimation {
            duration: Theme.expressiveDurations.expressiveFastSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
        }
    }

    signal clicked
    signal pressedAt(real rootX, real rootY)
    signal rightClicked(real rootX, real rootY)
    signal wheel(var wheelEvent)

    function cornerRadius(joined) {
        if (noBackground)
            return 0;
        return BarMetrics.cornerRadius(widgetThickness, BarMetrics.widgetStyle(barConfig), joined, pressProgress);
    }

    function triggerRipple(sourceItem, mouseX, mouseY) {
        if (sourceItem !== root && "pressed" in sourceItem)
            pressSource = sourceItem;
        const pos = sourceItem.mapToItem(visualContent, mouseX, mouseY);
        rippleLayer.trigger(pos.x, pos.y);
    }

    function handlePress(mouse, source) {
        if (source !== root && "pressed" in source)
            pressSource = source;
        if (mouse.button === Qt.RightButton) {
            const rPos = source.mapToItem(root, mouse.x, mouse.y);
            root.rightClicked(rPos.x, rPos.y);
            return;
        }
        if (enableBackgroundHover)
            triggerRipple(source, mouse.x, mouse.y);
        const rootPos = source.mapToItem(root, mouse.x, mouse.y);
        root.pressedAt(rootPos.x, rootPos.y);
        if (popoutTarget) {
            if (popoutTarget.setBarContext) {
                const pos = root.axis?.edge === "left" ? 2 : (root.axis?.edge === "right" ? 3 : (root.axis?.edge === "top" ? 0 : 1));
                const bottomGap = root.barConfig ? (root.barConfig.bottomGap !== undefined ? root.barConfig.bottomGap : 0) : 0;
                popoutTarget.setBarContext(pos, bottomGap);
            }

            const context = BarWidgetService.registrationForItem(root)?.context?.surface;
            if (context) {
                context.positionPopout(popoutTarget, root, root.section);
            } else if (popoutTarget.setTriggerPosition) {
                const globalPos = root.visualContent.mapToItem(null, 0, 0);
                const currentScreen = parentScreen || Screen;
                const barPosition = root.axis?.edge === "left" ? 2 : (root.axis?.edge === "right" ? 3 : (root.axis?.edge === "top" ? 0 : 1));
                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, root.visualWidth, root.barSpacing, barPosition, root.barConfig);
                popoutTarget.setTriggerPosition(pos.x, pos.y, pos.width, section, currentScreen, barPosition, barThickness, root.barSpacing, root.barConfig, root);
            }
        }
        root.clicked();
    }

    function contextMenuAnchor() {
        const screen = parentScreen || Screen;
        const vertical = axis?.isVertical ?? false;
        const edge = axis?.edge ?? "top";
        const gap = Math.max(Theme.spacingXS, barSpacing ?? Theme.spacingXS);
        const edgeInset = barThickness + barSpacing + gap;
        const globalPos = mapToGlobal(width / 2, height / 2);
        const relativeX = globalPos.x - (screen.x || 0);
        const relativeY = globalPos.y - (screen.y || 0);
        if (vertical)
            return {
                x: edge === "left" ? edgeInset : screen.width - edgeInset,
                y: relativeY + minTooltipY,
                isVertical: true,
                edge: edge,
                screen: screen
            };
        return {
            x: relativeX,
            y: edge === "bottom" ? screen.height - edgeInset : edgeInset,
            isVertical: false,
            edge: edge,
            screen: screen
        };
    }

    width: isVerticalOrientation ? barThickness : visualWidth
    height: isVerticalOrientation ? visualHeight : barThickness
    enabled: width > 0 && height > 0

    Item {
        id: visualContent
        width: root.visualWidth
        height: root.visualHeight
        anchors.centerIn: parent

        readonly property real blurRadius: root.blurRadius
        readonly property bool split: root.splitOffset > 0
        readonly property real splitGap: BarMetrics.segmentGap
        property bool hovered: false

        Repeater {
            model: visualContent.split ? 2 : 1

            Item {
                id: segment
                required property int index
                readonly property bool leading: index === 0
                readonly property bool joinedStart: visualContent.split && !leading
                readonly property bool joinedEnd: visualContent.split && leading
                readonly property real along: visualContent.split ? (leading ? 0 : root.splitOffset + visualContent.splitGap / 2) : 0
                readonly property real length: {
                    const full = root.isVerticalOrientation ? visualContent.height : visualContent.width;
                    if (!visualContent.split)
                        return full;
                    return leading ? root.splitOffset - visualContent.splitGap / 2 : full - root.splitOffset - visualContent.splitGap / 2;
                }
                readonly property real startRadiusA: joinedStart ? root.cornerRadius(true) : root.topLeftRadius
                readonly property real startRadiusB: joinedStart ? root.cornerRadius(true) : (root.isVerticalOrientation ? root.topRightRadius : root.bottomLeftRadius)
                readonly property real endRadiusA: joinedEnd ? root.cornerRadius(true) : (root.isVerticalOrientation ? root.bottomLeftRadius : root.topRightRadius)
                readonly property real endRadiusB: joinedEnd ? root.cornerRadius(true) : root.bottomRightRadius

                x: root.isVerticalOrientation ? 0 : along
                y: root.isVerticalOrientation ? along : 0
                width: root.isVerticalOrientation ? visualContent.width : Math.max(0, length)
                height: root.isVerticalOrientation ? Math.max(0, length) : visualContent.height

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -root.outlineThickness
                    topLeftRadius: segment.startRadiusA + root.outlineThickness
                    topRightRadius: (root.isVerticalOrientation ? segment.startRadiusB : segment.endRadiusA) + root.outlineThickness
                    bottomLeftRadius: (root.isVerticalOrientation ? segment.endRadiusA : segment.startRadiusB) + root.outlineThickness
                    bottomRightRadius: segment.endRadiusB + root.outlineThickness
                    color: "transparent"
                    border.width: root.outlineThickness
                    border.color: root.outlineColor
                    visible: root.outlineThickness > 0 && !root.noBackground
                }

                Rectangle {
                    id: fill
                    anchors.fill: parent
                    topLeftRadius: segment.startRadiusA
                    topRightRadius: root.isVerticalOrientation ? segment.startRadiusB : segment.endRadiusA
                    bottomLeftRadius: root.isVerticalOrientation ? segment.endRadiusA : segment.startRadiusB
                    bottomRightRadius: segment.endRadiusB
                    color: root.fillColor
                }

                StateLayer {
                    id: stateLayer
                    stateColor: Theme.onSurface
                    topLeftRadius: fill.topLeftRadius
                    topRightRadius: fill.topRightRadius
                    bottomLeftRadius: fill.bottomLeftRadius
                    bottomRightRadius: fill.bottomRightRadius
                    enableRipple: false
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    disabled: !root.enableBackgroundHover || root.noBackground
                    cursorShape: root.enableCursor ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onContainsMouseChanged: visualContent.hovered = containsMouse
                    onPressed: mouse => root.handlePress(mouse, stateLayer)
                }
            }
        }

        DankRipple {
            id: rippleLayer
            rippleColor: Theme.surfaceText
            topLeftRadius: root.topLeftRadius
            topRightRadius: root.topRightRadius
            bottomLeftRadius: root.bottomLeftRadius
            bottomRightRadius: root.bottomRightRadius
        }

        FocusRing {
            topLeftRadius: root.topLeftRadius + Theme.focusRingOffset
            topRightRadius: root.topRightRadius + Theme.focusRingOffset
            bottomLeftRadius: root.bottomLeftRadius + Theme.focusRingOffset
            bottomRightRadius: root.bottomRightRadius + Theme.focusRingOffset
            visible: root.activeFocus
        }

        Loader {
            id: contentLoader
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    MouseArea {
        id: mouseArea
        z: -1
        x: -root.leftMargin
        y: -root.topMargin
        width: root.width + root.leftMargin + root.rightMargin
        height: root.height + root.topMargin + root.bottomMargin
        hoverEnabled: true
        cursorShape: root.enableCursor ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => root.handlePress(mouse, mouseArea)
        onWheel: wheelEvent => {
            wheelEvent.accepted = false;
            root.wheel(wheelEvent);
        }
    }

    property var _blurRegisteredWindow: null
    readonly property var _blurTargetWindow: BlurService.enabled && !!blurBarWindow && !!blurBarWindow.registerBlurWidget && !root.noBackground && root.visible && root.width > 0 ? blurBarWindow : null

    on_BlurTargetWindowChanged: _updateBlurRegistration()

    function _updateBlurRegistration() {
        if (_blurRegisteredWindow === _blurTargetWindow)
            return;
        _blurRegisteredWindow?.unregisterBlurWidget?.(visualContent);
        _blurRegisteredWindow = _blurTargetWindow;
        _blurRegisteredWindow?.registerBlurWidget(visualContent);
    }

    Component.onCompleted: _updateBlurRegistration()
    Component.onDestruction: _blurRegisteredWindow?.unregisterBlurWidget?.(visualContent)
}
