import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modals.Clipboard

Rectangle {
    id: entry

    required property string entryData
    required property int entryIndex
    required property int itemIndex
    required property bool isSelected
    required property var modal
    required property var listView

    signal copyRequested
    signal deleteRequested

    readonly property string entryType: modal ? modal.getEntryType(entryData) : "text"
    readonly property string entryPreview: modal ? modal.getEntryPreview(entryData) : entryData

    radius: Theme.cornerRadius
    color: {
        if (isSelected) {
            return Theme.primaryPressed
        }
        return mouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceContainerHigh
    }

    Row {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        anchors.rightMargin: Theme.spacingS
        spacing: Theme.spacingL

        // Index indicator
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

        // Content area
        Row {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 68
            spacing: Theme.spacingM

            // Thumbnail/Icon
            ClipboardThumbnail {
                width: entryType === "image" ? ClipboardConstants.thumbnailSize : Theme.iconSize
                height: entryType === "image" ? ClipboardConstants.thumbnailSize : Theme.iconSize
                anchors.verticalCenter: parent.verticalCenter
                entryData: entry.entryData
                entryType: entry.entryType
                modal: entry.modal
                listView: entry.listView
                itemIndex: entry.itemIndex
            }

            // Text content
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (entryType === "image" ? ClipboardConstants.thumbnailSize : Theme.iconSize) - Theme.spacingM
                spacing: Theme.spacingXS

                StyledText {
                    text: {
                        switch (entryType) {
                        case "image":
                            return I18n.tr("Image") + " • " + entryPreview
                        case "long_text":
                            return I18n.tr("Long Text")
                        default:
                            return I18n.tr("Text")
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

    // Delete button
    DankActionButton {
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        iconName: "close"
        iconSize: Theme.iconSize - 6
        iconColor: Theme.surfaceText
        onClicked: deleteRequested()
    }

    // Click area
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        anchors.rightMargin: 40
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: copyRequested()
    }
}
