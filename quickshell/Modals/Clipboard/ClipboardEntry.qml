import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    required property var entry
    required property int entryIndex
    required property int itemIndex
    required property bool isSelected
    required property var modal
    required property var listView

    signal copyRequested
    signal deleteRequested
    signal pinRequested
    signal unpinRequested

    readonly property string entryType: modal ? modal.getEntryType(entry) : "text"
    readonly property string entryPreview: modal ? modal.getEntryPreview(entry) : ""
    readonly property bool hasPinnedDuplicate: !entry.pinned && ClipboardService.hashedPinnedEntry(entry.hash)

    radius: Theme.cornerRadius
    color: {
        if (isSelected) {
            return Theme.primaryPressed;
        }
        return mouseArea.containsMouse ? Theme.primaryHoverLight : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency);
    }

    DankRipple {
        id: rippleLayer
        rippleColor: Theme.surfaceText
        cornerRadius: root.radius
    }

    Rectangle {
        id: indexBadge
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        radius: 12
        color: Theme.primarySelected

        StyledText {
            anchors.centerIn: parent
            text: entryIndex.toString()
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
            color: Theme.primary
        }
    }

    Row {
        id: actionButtons
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS

        DankActionButton {
            iconName: "push_pin"
            iconSize: Theme.iconSize - 6
            iconColor: (entry.pinned || hasPinnedDuplicate) ? Theme.primary : Theme.surfaceText
            backgroundColor: (entry.pinned || hasPinnedDuplicate) ? Theme.primarySelected : "transparent"
            onClicked: entry.pinned ? unpinRequested() : pinRequested()
        }

        DankActionButton {
            iconName: "close"
            iconSize: Theme.iconSize - 6
            iconColor: Theme.surfaceText
            onClicked: deleteRequested()
        }
    }

    Item {
        anchors.left: indexBadge.right
        anchors.leftMargin: Theme.spacingM
        anchors.right: actionButtons.left
        anchors.rightMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        // height: contentColumn.implicitHeight
        height: ClipboardConstants.itemHeight
        clip: true

        ClipboardThumbnail {
            id: thumbnail
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: entryType === "image" ? ClipboardConstants.thumbnailSize : Theme.iconSize
            height: entryType === "image" ? ClipboardConstants.itemHeight - 4 : Theme.iconSize // 100 - 4 = 96, 96:72 = 4:3
            entry: root.entry
            entryType: root.entryType
            modal: root.modal
            listView: root.listView
            itemIndex: root.itemIndex
        }

        Column {
            id: contentColumn
            anchors.left: thumbnail.right
            anchors.leftMargin: Theme.spacingM
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS

            StyledText {
                text: {
                    switch (entryType) {
                    case "image":
                        return I18n.tr("Image") + " • " + entryPreview;
                    case "long_text":
                        return I18n.tr("Long Text");
                    default:
                        return I18n.tr("Text");
                    }
                }
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primary
                font.weight: Font.Medium
                width: parent.width
                elide: Text.ElideRight
            }

            StyledText {
                text: entryPreview
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                width: parent.width
                wrapMode: Text.WordWrap
                maximumLineCount: entryType === "long_text" ? 3 : 1
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        anchors.rightMargin: 80
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            const pos = mouseArea.mapToItem(root, mouse.x, mouse.y);
            rippleLayer.trigger(pos.x, pos.y);
        }
        onClicked: copyRequested()
    }
}
