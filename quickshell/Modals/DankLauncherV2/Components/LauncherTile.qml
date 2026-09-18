pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import qs.Modals.DankLauncherV2

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property bool imageTile: false
    property real iconMargins: 0
    property real iconFallbackLeftMargin: 0
    property real iconFallbackRightMargin: 0
    property real iconFallbackBottomMargin: 0
    property real iconMaterialSizeAdjustment: Theme.spacingM
    property real iconUnicodeScale: Theme.fontSizeXLarge / Theme.iconSizeLarge
    property real minIconSize: Theme.iconSizeLarge
    property real maxIconSize: LauncherMetrics.gridIconSize
    property real iconSizeRatio: Theme.launcherImageRatio
    property bool externalHighlight: false
    readonly property color contentColor: isSelected ? Theme.onSelectedContainer : Theme.onSurface
    property var item: null
    property bool isSelected: false
    property bool isHovered: itemArea.containsMouse
    property var controller: null
    property int flatIndex: -1

    signal clicked
    signal rightClicked(real mouseX, real mouseY)
    signal pointerMoved

    readonly property string iconValue: {
        if (!item)
            return "";
        switch (item.iconType) {
        case "material":
        case "nerd":
            return "material:" + (item.icon || "apps");
        case "unicode":
            return "unicode:" + (item.icon || "");
        case "composite":
            return item.iconFull || "";
        case "image":
        default:
            return item.icon || "";
        }
    }

    readonly property int computedIconSize: Math.min(root.maxIconSize, Math.max(root.minIconSize, width * root.iconSizeRatio))

    radius: Theme.cornerRadiusL
    color: externalHighlight ? "transparent" : isSelected ? Theme.selectedContainer : Theme.foregroundColor(Theme.cardSurface, Theme.isFloatingWindow(root))

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.withAlpha(root.contentColor, itemArea.pressed ? Theme.stateLayerPressed : Theme.stateLayerHover)
        visible: root.isHovered || itemArea.pressed
    }

    DankRipple {
        id: rippleLayer
        rippleColor: root.contentColor
        cornerRadius: root.radius
    }

    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.spacingXS
        spacing: Theme.spacingXS
        z: 1

        SourceBadge {
            badgeVisible: !root.imageTile
            source: root.item?.type === "app" ? (root.item.source || "") : ""
            glyphSize: Theme.iconSizeSmall
        }

        DankIcon {
            name: "push_pin"
            size: Theme.iconSizeSmall
            color: root.contentColor
            visible: root.item?.pinned === true
        }
    }

    DankKeycap {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: Theme.spacingXS
        text: "↵"
        textColor: root.contentColor
        visible: root.isSelected
        z: 1
    }

    Loader {
        anchors.fill: parent
        active: !root.imageTile
        sourceComponent: Item {
            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingS
                width: parent.width - Theme.spacingL * 2

                AppIconRenderer {
                    visible: true
                    fallbackRadius: Theme.fullRadius(width, height)
                    fallbackBackgroundColor: Theme.primaryContainer
                    fallbackTextColor: Theme.onPrimaryContainer
                    width: root.computedIconSize
                    height: root.computedIconSize
                    anchors.horizontalCenter: parent.horizontalCenter
                    iconValue: root.iconValue
                    iconMargins: root.iconMargins
                    fallbackLeftMargin: root.iconFallbackLeftMargin
                    fallbackRightMargin: root.iconFallbackRightMargin
                    fallbackBottomMargin: root.iconFallbackBottomMargin
                    unicodeIconScale: root.iconUnicodeScale
                    iconSize: root.computedIconSize
                    animate: root.visible && root.item?.data?.animated === true
                    fallbackText: root.item?.name?.charAt(0).toUpperCase() || "?"
                    iconColor: root.contentColor
                    materialIconSizeAdjustment: root.iconMaterialSizeAdjustment
                }

                StyledText {
                    width: parent.width
                    text: root.item?._hName ?? root.item?.name ?? ""
                    textFormat: root.item?._hRich ? Text.RichText : Text.PlainText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    font.family: Theme.fontFamily
                    color: root.contentColor
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    MouseArea {
        id: itemArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton)
                rippleLayer.trigger(mouse.x, mouse.y);
        }
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                var scenePos = mapToItem(null, mouse.x, mouse.y);
                root.rightClicked(scenePos.x, scenePos.y);
                return;
            }
            root.clicked();
        }

        onPositionChanged: {
            root.pointerMoved();
            if (root.controller)
                root.controller.keyboardNavigationActive = false;
        }
    }
}
