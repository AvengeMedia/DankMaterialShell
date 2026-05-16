pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "../../Common/htmlElide.js" as HtmlElide

Rectangle {
    id: root

    property var item: null
    property string sectionTitle: ""
    property string sectionIcon: ""
    property bool isSelected: false
    property var controller: null
    property int flatIndex: -1
    property bool isHovered: itemArea.containsMouse || quickToggleArea.containsMouse

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

    readonly property string previewSource: {
        const data = item?.data;
        const raw = data?.imageUrl || data?.imagePath || (data?.path && isImageFile(data.path) ? data.path : "");
        if (!raw)
            return "";
        if (raw.startsWith("http://") || raw.startsWith("https://") || raw.startsWith("file://"))
            return raw;
        if (raw.startsWith("/"))
            return "file://" + raw;
        return raw;
    }
    readonly property bool hasMediaPreview: previewSource.length > 0
    readonly property bool previewAnimated: previewSource.toLowerCase().indexOf(".gif") >= 0

    readonly property string typeLabel: {
        if (!item)
            return "";
        switch (item.type) {
        case "plugin_browse":
            return I18n.tr("Browse");
        case "plugin":
            return I18n.tr("Plugin");
        case "file":
            return item.data?.is_dir ? I18n.tr("Folder") : I18n.tr("File");
        default:
            return "";
        }
    }

    width: parent?.width ?? 200
    height: 64
    radius: Theme.cornerRadius
    color: root.isSelected ? Theme.primaryPressed : root.isHovered ? Theme.primaryHoverLight : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: 90
            easing.type: Theme.standardEasing
        }
    }

    DankRipple {
        id: rippleLayer
        rippleColor: Theme.surfaceText
        cornerRadius: root.radius
    }

    MouseArea {
        id: itemArea
        z: 2
        anchors.fill: parent
        anchors.rightMargin: root.item?.type === "plugin_browse" ? 38 : 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPositionChanged: {
            if (root.controller)
                root.controller.keyboardNavigationActive = false;
        }

        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton)
                rippleLayer.trigger(mouse.x, mouse.y);
        }

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                const scenePos = mapToItem(null, mouse.x, mouse.y);
                root.rightClicked(scenePos.x, scenePos.y);
            } else {
                root.clicked();
            }
        }
    }

    Rectangle {
        id: iconWell
        width: 40
        height: 40
        radius: Theme.cornerRadius
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        color: root.isSelected ? Theme.primaryContainer : Theme.surfaceContainerHigh
        border.color: Theme.withAlpha(root.isSelected ? Theme.primary : Theme.outline, root.isSelected ? 0.28 : 0.12)
        border.width: 1

        AppIconRenderer {
            anchors.centerIn: parent
            width: 30
            height: 30
            iconValue: root.iconValue
            iconSize: 30
            fallbackText: (root.item?.name?.length > 0) ? root.item.name.charAt(0).toUpperCase() : "?"
            materialIconSizeAdjustment: 10
        }
    }

    Column {
        id: textColumn
        anchors.left: iconWell.right
        anchors.leftMargin: Theme.spacingM
        anchors.right: previewFrame.visible ? previewFrame.left : metaRow.left
        anchors.rightMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        StyledText {
            id: nameText
            width: parent.width
            text: root.item?._hName ?? root.item?.name ?? ""
            textFormat: root.item?._hRich ? Text.RichText : Text.PlainText
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
            maximumLineCount: 1
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignLeft
        }

        TextMetrics {
            id: subProbe
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            elide: Qt.ElideRight
            elideWidth: textColumn.width
            text: root.item?._hRich ? HtmlElide.stripHtmlTags(root.item?._hSub ?? "") : ""
        }

        readonly property int _richBudget: {
            if (!subProbe.text)
                return 0;
            const elided = subProbe.elidedText;
            return elided.endsWith("\u2026") ? elided.length - 1 : elided.length;
        }

        StyledText {
            width: parent.width
            text: root.item?._hRich ? HtmlElide.elideRichText(root.item._hSub ?? "", textColumn._richBudget) : (root.item?.subtitle ?? root.sectionTitle)
            textFormat: root.item?._hRich ? Text.RichText : Text.PlainText
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            maximumLineCount: 1
            elide: Text.ElideRight
            visible: text.length > 0
            horizontalAlignment: Text.AlignLeft
        }
    }

    Row {
        id: metaRow
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS
        visible: childrenRect.width > 0

        Rectangle {
            visible: root.typeLabel.length > 0
            width: typeText.implicitWidth + Theme.spacingS * 2
            height: 22
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.surfaceVariantAlpha

            StyledText {
                id: typeText
                anchors.centerIn: parent
                text: root.typeLabel
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Theme.surfaceVariantText
            }
        }

        Rectangle {
            visible: root.item?.type === "plugin_browse"
            width: 28
            height: 28
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            color: quickToggleArea.containsMouse ? Theme.surfaceHover : "transparent"

            readonly property bool isAllowed: {
                if (root.item?.type !== "plugin_browse")
                    return false;
                const pluginId = root.item?.data?.pluginId;
                if (!pluginId)
                    return false;
                SettingsData.launcherPluginVisibility;
                return SettingsData.getPluginAllowWithoutTrigger(pluginId);
            }

            DankIcon {
                anchors.centerIn: parent
                name: parent.isAllowed ? "visibility" : "visibility_off"
                size: 17
                color: parent.isAllowed ? Theme.primary : Theme.surfaceVariantText
            }

            MouseArea {
                id: quickToggleArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const pluginId = root.item?.data?.pluginId;
                    if (!pluginId)
                        return;
                    SettingsData.setPluginAllowWithoutTrigger(pluginId, !parent.isAllowed);
                }
            }
        }

        SourceBadge {
            visible: root.item?.type === "app"
            anchors.verticalCenter: parent.verticalCenter
            source: root.item?.type === "app" ? (root.item.source || "") : ""
            glyphSize: 14
        }
    }

    Rectangle {
        id: previewFrame
        visible: root.hasMediaPreview
        width: 64
        height: 44
        radius: Theme.cornerRadius
        anchors.right: metaRow.left
        anchors.rightMargin: metaRow.visible ? Theme.spacingS : 0
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: Theme.surfaceContainerHigh
        border.color: Theme.withAlpha(Theme.outline, 0.16)
        border.width: 1

        Image {
            anchors.fill: parent
            source: root.previewSource
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            visible: !root.previewAnimated
        }

        AnimatedImage {
            anchors.fill: parent
            source: root.previewSource
            fillMode: Image.PreserveAspectCrop
            playing: visible
            visible: root.previewAnimated
        }
    }

    function isImageFile(path) {
        if (!path)
            return false;
        const ext = path.split(".").pop().toLowerCase();
        return ["jpg", "jpeg", "png", "gif", "webp", "svg", "bmp", "jxl", "avif", "heif", "exr"].indexOf(ext) >= 0;
    }
}
