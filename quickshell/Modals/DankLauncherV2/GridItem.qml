pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property var item: null
    property bool isSelected: false
    property bool isHovered: itemArea.containsMouse
    property var controller: null
    property int flatIndex: -1

    signal clicked
    signal rightClicked(real mouseX, real mouseY)

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

    readonly property int computedIconSize: Math.min(48, Math.max(32, width * 0.45))

    radius: Theme.cornerRadius
    color: isSelected ? Theme.primaryPressed : isHovered ? Theme.primaryHoverLight : "transparent"

    DankRipple {
        id: rippleLayer
        rippleColor: Theme.surfaceText
        cornerRadius: root.radius
    }

    Column {
        anchors.centerIn: parent
        anchors.margins: Theme.spacingS
        spacing: Theme.spacingS
        width: parent.width - Theme.spacingM

        AppIconRenderer {
            width: root.computedIconSize
            height: root.computedIconSize
            anchors.horizontalCenter: parent.horizontalCenter
            iconValue: root.iconValue
            iconSize: root.computedIconSize
            fallbackText: (root.item?.name?.length > 0) ? root.item.name.charAt(0).toUpperCase() : "?"
            iconColor: root.isSelected ? Theme.primary : Theme.surfaceText
            materialIconSizeAdjustment: root.computedIconSize * 0.3
        }

        Text {
            width: parent.width
            text: root.item?._hName ?? root.item?.name ?? ""
            textFormat: root.item?._hRich ? Text.RichText : Text.PlainText
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            font.family: Theme.fontFamily
            color: root.isSelected ? Theme.primary : Theme.surfaceText
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            maximumLineCount: 2
            wrapMode: Text.Wrap
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
            } else {
                root.clicked();
            }
        }

        onPositionChanged: {
            if (root.controller) {
                root.controller.keyboardNavigationActive = false;
            }
        }
    }
}
