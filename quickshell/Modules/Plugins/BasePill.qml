import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var axis: null
    property string section: "center"
    property var popoutTarget: null
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48
    property real barSpacing: 4
    property var barConfig: null
    property alias content: contentLoader.sourceComponent
    property bool isVerticalOrientation: axis?.isVertical ?? false
    property bool isFirst: false
    property bool isLast: false
    property real sectionSpacing: 0
    property bool enableBackgroundHover: true
    property bool enableCursor: true
    readonly property bool isMouseHovered: mouseArea.containsMouse
    property bool isLeftBarEdge: false
    property bool isRightBarEdge: false
    property bool isTopBarEdge: false
    property bool isBottomBarEdge: false
    readonly property real dpr: parentScreen ? CompositorService.getScreenScale(parentScreen) : 1
    readonly property real horizontalPadding: (barConfig?.removeWidgetPadding ?? false) ? 0 : Theme.snap((barConfig?.widgetPadding ?? 12) * (widgetThickness / 30), dpr)
    readonly property real visualWidth: Theme.snap(isVerticalOrientation ? widgetThickness : (contentLoader.item ? (contentLoader.item.implicitWidth + horizontalPadding * 2) : 0), dpr)
    readonly property real visualHeight: Theme.snap(isVerticalOrientation ? (contentLoader.item ? (contentLoader.item.implicitHeight + horizontalPadding * 2) : 0) : widgetThickness, dpr)
    readonly property alias visualContent: visualContent
    readonly property real barEdgeExtension: 1000
    readonly property real gapExtension: sectionSpacing
    readonly property real leftMargin: !isVerticalOrientation ? (isLeftBarEdge && isFirst ? barEdgeExtension : (isFirst ? gapExtension : gapExtension / 2)) : 0
    readonly property real rightMargin: !isVerticalOrientation ? (isRightBarEdge && isLast ? barEdgeExtension : (isLast ? gapExtension : gapExtension / 2)) : 0
    readonly property real topMargin: isVerticalOrientation ? (isTopBarEdge && isFirst ? barEdgeExtension : (isFirst ? gapExtension : gapExtension / 2)) : 0
    readonly property real bottomMargin: isVerticalOrientation ? (isBottomBarEdge && isLast ? barEdgeExtension : (isLast ? gapExtension : gapExtension / 2)) : 0

    signal clicked
    signal rightClicked(real rootX, real rootY)
    signal wheel(var wheelEvent)

    function triggerRipple(sourceItem, mouseX, mouseY) {
        const pos = sourceItem.mapToItem(visualContent, mouseX, mouseY);
        rippleLayer.trigger(pos.x, pos.y);
    }

    width: isVerticalOrientation ? barThickness : visualWidth
    height: isVerticalOrientation ? visualHeight : barThickness

    Item {
        id: visualContent
        width: root.visualWidth
        height: root.visualHeight
        anchors.centerIn: parent

        Rectangle {
            id: outline
            anchors.centerIn: parent
            width: {
                const borderWidth = (barConfig?.widgetOutlineEnabled ?? false) ? (barConfig?.widgetOutlineThickness ?? 1) : 0;
                return parent.width + borderWidth * 2;
            }
            height: {
                const borderWidth = (barConfig?.widgetOutlineEnabled ?? false) ? (barConfig?.widgetOutlineThickness ?? 1) : 0;
                return parent.height + borderWidth * 2;
            }
            radius: (barConfig?.noBackground ?? false) ? 0 : Theme.cornerRadius
            color: "transparent"
            border.width: {
                if (barConfig?.widgetOutlineEnabled ?? false) {
                    return barConfig?.widgetOutlineThickness ?? 1;
                }
                return 0;
            }
            border.color: {
                if (!(barConfig?.widgetOutlineEnabled ?? false)) {
                    return "transparent";
                }
                const colorOption = barConfig?.widgetOutlineColor || "primary";
                const opacity = barConfig?.widgetOutlineOpacity ?? 1.0;
                switch (colorOption) {
                case "surfaceText":
                    return Theme.withAlpha(Theme.surfaceText, opacity);
                case "secondary":
                    return Theme.withAlpha(Theme.secondary, opacity);
                case "primary":
                    return Theme.withAlpha(Theme.primary, opacity);
                default:
                    return Theme.withAlpha(Theme.primary, opacity);
                }
            }
        }

        Rectangle {
            id: background
            anchors.fill: parent
            radius: (barConfig?.noBackground ?? false) ? 0 : Theme.cornerRadius
            color: {
                if (barConfig?.noBackground ?? false) {
                    return "transparent";
                }

                const rawTransparency = (root.barConfig && root.barConfig.widgetTransparency !== undefined) ? root.barConfig.widgetTransparency : 1.0;
                const isHovered = root.enableBackgroundHover && (mouseArea.containsMouse || (root.isHovered || false));
                const transparency = isHovered ? Math.max(0.3, rawTransparency) : rawTransparency;
                const baseColor = isHovered ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;

                if (Theme.widgetBackgroundHasAlpha) {
                    return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * transparency);
                }
                return Theme.withAlpha(baseColor, transparency);
            }
        }

        DankRipple {
            id: rippleLayer
            rippleColor: Theme.surfaceText
            cornerRadius: background.radius
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
        onPressed: function (mouse) {
            if (mouse.button === Qt.RightButton) {
                const rPos = mouseArea.mapToItem(root, mouse.x, mouse.y);
                root.rightClicked(rPos.x, rPos.y);
                return;
            }
            const ripplePos = mouseArea.mapToItem(visualContent, mouse.x, mouse.y);
            rippleLayer.trigger(ripplePos.x, ripplePos.y);
            if (popoutTarget) {
                // Ensure bar context is set first if supported
                if (popoutTarget.setBarContext) {
                    const pos = root.axis?.edge === "left" ? 2 : (root.axis?.edge === "right" ? 3 : (root.axis?.edge === "top" ? 0 : 1));
                    const bottomGap = root.barConfig ? (root.barConfig.bottomGap !== undefined ? root.barConfig.bottomGap : 0) : 0;
                    popoutTarget.setBarContext(pos, bottomGap);
                }

                if (popoutTarget.setTriggerPosition) {
                    const globalPos = root.visualContent.mapToItem(null, 0, 0);
                    const currentScreen = parentScreen || Screen;
                    const barPosition = root.axis?.edge === "left" ? 2 : (root.axis?.edge === "right" ? 3 : (root.axis?.edge === "top" ? 0 : 1));
                    const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, root.visualWidth, root.barSpacing, barPosition, root.barConfig);
                    popoutTarget.setTriggerPosition(pos.x, pos.y, pos.width, section, currentScreen, barPosition, barThickness, root.barSpacing, root.barConfig);
                }
            }
            root.clicked();
        }
        onWheel: function (wheelEvent) {
            wheelEvent.accepted = false;
            root.wheel(wheelEvent);
        }
    }
}
