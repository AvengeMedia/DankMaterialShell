import QtQuick
import qs.Common
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
    readonly property bool hasPinnedDuplicate: !entry.pinned && modal ? modal.hashedPinnedEntry(entry.hash) : false

    radius: Theme.cornerRadius
    color: {
        if (isSelected) {
            return Theme.primaryPressed;
        }
        return mouseArea.containsMouse ? Theme.primaryHoverLight : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency);
    }

    Row {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        anchors.rightMargin: Theme.spacingS
        spacing: Theme.spacingL

        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: Theme.primarySelected
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                anchors.centerIn: parent
                text: entryIndex.toString()
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                color: Theme.primary
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 110
            spacing: Theme.spacingM

            ClipboardThumbnail {
                width: entryType === "image" ? ClipboardConstants.thumbnailSize : Theme.iconSize
                height: entryType === "image" ? ClipboardConstants.thumbnailSize : Theme.iconSize
                anchors.verticalCenter: parent.verticalCenter
                entry: root.entry
                entryType: root.entryType
                modal: root.modal
                listView: root.listView
                itemIndex: root.itemIndex
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (entryType === "image" ? ClipboardConstants.thumbnailSize : Theme.iconSize) - Theme.spacingM
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
                }
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingM
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

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        anchors.rightMargin: 80
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: copyRequested()
    }
}
