pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland
import qs.Common
import qs.Services
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

    radius: Theme.cornerRadius
    color: isSelected ? Theme.primaryPressed : isHovered ? Theme.primaryPressed : "transparent"
    border.width: isSelected ? 2 : 0
    border.color: Theme.primary

    readonly property string toplevelId: item?.data?.toplevelId ?? ""
    readonly property var waylandToplevel: {
        if (!toplevelId || !item?.pluginId)
            return null;
        const pluginInstance = PluginService.pluginInstances[item.pluginId];
        if (!pluginInstance?.getToplevelById)
            return null;
        return pluginInstance.getToplevelById(toplevelId);
    }
    readonly property bool hasScreencopy: waylandToplevel !== null

    readonly property string iconValue: {
        if (!item)
            return "";
        if (hasScreencopy)
            return "";
        var data = item.data;
        if (data?.imageUrl)
            return "image:" + data.imageUrl;
        if (data?.imagePath)
            return "image:" + data.imagePath;
        if (data?.path && isImageFile(data.path))
            return "image:" + data.path;
        switch (item.iconType) {
        case "material":
        case "nerd":
            return "material:" + (item.icon || "image");
        case "unicode":
            return "unicode:" + (item.icon || "");
        case "composite":
            return item.iconFull || "";
        case "image":
        default:
            return item.icon || "";
        }
    }

    function isImageFile(path) {
        if (!path)
            return false;
        var ext = path.split('.').pop().toLowerCase();
        return ["jpg", "jpeg", "png", "gif", "webp", "svg", "bmp"].indexOf(ext) >= 0;
    }

    DankRipple {
        id: rippleLayer
        rippleColor: Theme.surfaceText
        cornerRadius: root.radius
    }

    Item {
        anchors.fill: parent
        anchors.margins: 4

        Rectangle {
            id: imageContainer
            anchors.fill: parent
            radius: Theme.cornerRadius - 2
            color: Theme.surfaceContainerHigh
            clip: true

            ScreencopyView {
                id: screencopyView
                anchors.fill: parent
                captureSource: root.waylandToplevel
                live: root.hasScreencopy
                visible: root.hasScreencopy

                Rectangle {
                    anchors.fill: parent
                    color: root.isHovered ? Theme.withAlpha(Theme.surfaceVariant, 0.2) : "transparent"
                }
            }

            AppIconRenderer {
                anchors.fill: parent
                iconValue: root.iconValue
                iconSize: Math.min(parent.width, parent.height)
                fallbackText: (root.item?.name?.length > 0) ? root.item.name.charAt(0).toUpperCase() : "?"
                materialIconSizeAdjustment: iconSize * 0.3
                visible: !root.hasScreencopy
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: labelText.implicitHeight + Theme.spacingS * 2
                color: Theme.withAlpha(Theme.surfaceContainer, 0.85)
                visible: root.item?.name?.length > 0

                Text {
                    id: labelText
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXS
                    text: root.item?._hName ?? root.item?.name ?? ""
                    textFormat: root.item?._hRich ? Text.RichText : Text.PlainText
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.spacingXS
                width: 20
                height: 20
                radius: 10
                color: Theme.primary
                visible: root.isSelected

                DankIcon {
                    anchors.centerIn: parent
                    name: "check"
                    size: 14
                    color: Theme.primaryText
                }
            }

            Rectangle {
                id: attributionBadge
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Theme.spacingXS
                width: root.hasScreencopy ? 28 : 40
                height: root.hasScreencopy ? 28 : 16
                radius: root.hasScreencopy ? 14 : 4
                color: root.hasScreencopy ? Theme.surfaceContainer : "transparent"
                visible: attributionImage.status === Image.Ready
                opacity: 0.95

                Image {
                    id: attributionImage
                    anchors.fill: parent
                    anchors.margins: root.hasScreencopy ? 4 : 0
                    fillMode: Image.PreserveAspectFit
                    source: root.item?.data?.attribution || ""
                    mipmap: true
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
            if (root.controller)
                root.controller.keyboardNavigationActive = false;
        }
    }
}
