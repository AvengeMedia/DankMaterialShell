pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property var item: null
    property bool isSelected: false
    property bool isHovered: (controller?.mouseHasMoved && itemArea.containsMouse) || allModeToggleArea.containsMouse
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

    width: parent?.width ?? 200
    height: 52
    color: isSelected ? Theme.primaryPressed : isHovered ? Theme.primaryHoverLight : "transparent"
    radius: Theme.cornerRadius

    MouseArea {
        id: itemArea
        anchors.fill: parent
        anchors.rightMargin: root.item?.type === "plugin_browse" ? 40 : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                var scenePos = mapToItem(null, mouse.x, mouse.y);
                root.rightClicked(scenePos.x, scenePos.y);
            } else {
                root.clicked();
            }
        }

        onPositionChanged: mouse => {
            if (root.controller) {
                root.controller.handleMousePositionChanged(mapToItem(null, mouse.x, mouse.y));
            }
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        spacing: Theme.spacingM

        AppIconRenderer {
            width: 36
            height: 36
            anchors.verticalCenter: parent.verticalCenter
            iconValue: root.iconValue
            iconSize: 36
            fallbackText: (root.item?.name?.length > 0) ? root.item.name.charAt(0).toUpperCase() : "?"
            materialIconSizeAdjustment: 12
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 36 - Theme.spacingM * 3 - rightContent.width
            spacing: 2

            StyledText {
                width: parent.width
                text: root.item?.name ?? ""
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
            }

            StyledText {
                width: parent.width
                text: root.item?.subtitle ?? ""
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                visible: text.length > 0
                horizontalAlignment: Text.AlignLeft
            }
        }

        Row {
            id: rightContent
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            Rectangle {
                id: allModeToggle
                visible: root.item?.type === "plugin_browse"
                width: 28
                height: 28
                radius: 14
                anchors.verticalCenter: parent.verticalCenter
                color: allModeToggleArea.containsMouse ? Theme.surfaceHover : "transparent"

                property bool isAllowed: {
                    if (root.item?.type !== "plugin_browse")
                        return false;
                    var pluginId = root.item?.data?.pluginId;
                    if (!pluginId)
                        return false;
                    SettingsData.launcherPluginVisibility;
                    return SettingsData.getPluginAllowWithoutTrigger(pluginId);
                }

                DankIcon {
                    anchors.centerIn: parent
                    name: allModeToggle.isAllowed ? "visibility" : "visibility_off"
                    size: 18
                    color: allModeToggle.isAllowed ? Theme.primary : Theme.surfaceVariantText
                }

                MouseArea {
                    id: allModeToggleArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var pluginId = root.item?.data?.pluginId;
                        if (!pluginId)
                            return;
                        SettingsData.setPluginAllowWithoutTrigger(pluginId, !allModeToggle.isAllowed);
                    }
                }
            }

            Rectangle {
                visible: root.item?.type && root.item.type !== "app" && root.item.type !== "plugin_browse"
                width: typeBadge.implicitWidth + Theme.spacingS * 2
                height: 20
                radius: 10
                color: Theme.surfaceVariantAlpha
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    id: typeBadge
                    anchors.centerIn: parent
                    text: {
                        if (!root.item)
                            return "";
                        switch (root.item.type) {
                        case "calculator":
                            return I18n.tr("Calc");
                        case "plugin":
                            return I18n.tr("Plugin");
                        case "file":
                            return I18n.tr("File");
                        default:
                            return "";
                        }
                    }
                    font.pixelSize: Theme.fontSizeSmall - 2
                    color: Theme.surfaceVariantText
                }
            }
        }
    }
}
