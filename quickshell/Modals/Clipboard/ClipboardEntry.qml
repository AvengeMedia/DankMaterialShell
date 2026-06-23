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
    signal pasteRequested
    signal deleteRequested
    signal pinRequested(var targetEntry)
    signal unpinRequested(var targetEntry)
    signal editRequested
    signal contextMenuRequested(real mouseX, real mouseY)

    readonly property string entryType: modal ? modal.getEntryType(entry) : "text"
    readonly property string entryPreview: modal ? modal.getEntryPreview(entry) : ""
    readonly property var pinnedDuplicateEntry: !entry.pinned ? ClipboardService.getPinnedEntryByHash(entry.hash) : null
    readonly property bool hasPinnedDuplicate: pinnedDuplicateEntry !== null
    readonly property bool effectivePinned: entry.pinned || hasPinnedDuplicate
    readonly property var visibleEntryActions: SettingsData.clipboardVisibleEntryActions || ["pin", "edit", "delete"]
    readonly property bool showCopyAction: visibleEntryActions.includes("copy")
    readonly property bool showPasteAction: visibleEntryActions.includes("paste")
    readonly property bool showPinAction: visibleEntryActions.includes("pin")
    readonly property bool showEditAction: visibleEntryActions.includes("edit")
    readonly property bool showDeleteAction: visibleEntryActions.includes("delete")
    readonly property bool showPinnedIndicator: hasPinnedDuplicate && !showPinAction
    readonly property bool showAnyAction: showCopyAction || showPasteAction || showPinAction || showEditAction || showDeleteAction || showPinnedIndicator

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
        visible: root.showAnyAction

        Item {
            width: 40
            height: 40
            visible: root.showPinnedIndicator

            // Status indicator only; the Pin action remains hidden.
            DankIcon {
                anchors.centerIn: parent
                name: "push_pin"
                size: Theme.iconSize - 6
                color: Theme.primary
            }
        }

        DankActionButton {
            iconName: "content_copy"
            iconSize: Theme.iconSize - 6
            iconColor: Theme.surfaceText
            visible: root.showCopyAction
            onClicked: copyRequested()
        }

        DankActionButton {
            iconName: "content_paste"
            iconSize: Theme.iconSize - 6
            iconColor: Theme.surfaceText
            visible: root.showPasteAction
            onClicked: pasteRequested()
        }

        DankActionButton {
            iconName: "push_pin"
            iconSize: Theme.iconSize - 6
            iconColor: (entry.pinned || hasPinnedDuplicate) ? Theme.primary : Theme.surfaceText
            backgroundColor: (entry.pinned || hasPinnedDuplicate) ? Theme.primarySelected : "transparent"
            visible: root.showPinAction
            onClicked: {
                if (entry.pinned) {
                    unpinRequested(entry);
                    return;
                }
                if (pinnedDuplicateEntry) {
                    unpinRequested(pinnedDuplicateEntry);
                    return;
                }
                pinRequested(entry);
            }
        }

        DankActionButton {
            iconName: "edit"
            iconSize: Theme.iconSize - 6
            iconColor: Theme.surfaceText
            visible: root.showEditAction

            onClicked: {
                if (entryType === "image") {
                    return;
                }
                editRequested();
            }
        }

        DankActionButton {
            iconName: "close"
            iconSize: Theme.iconSize - 6
            iconColor: Theme.surfaceText
            visible: root.showDeleteAction
            onClicked: deleteRequested()
        }
    }

    Item {
        anchors.left: indexBadge.right
        anchors.leftMargin: Theme.spacingM
        anchors.right: root.showAnyAction ? actionButtons.left : parent.right
        anchors.rightMargin: root.showAnyAction ? Theme.spacingM : Theme.spacingS
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
        anchors.left: parent.left
        anchors.right: root.showAnyAction ? actionButtons.left : parent.right
        anchors.rightMargin: root.showAnyAction ? Theme.spacingS : 0
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton) {
                const pos = mouseArea.mapToItem(root, mouse.x, mouse.y);
                rippleLayer.trigger(pos.x, pos.y);
            }
        }
        onClicked: {
            if (SettingsData.clipboardClickToPaste) {
                pasteRequested()
            } else {
                copyRequested()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: mouse => {
            const scenePos = mapToItem(null, mouse.x, mouse.y);
            contextMenuRequested(scenePos.x, scenePos.y);
        }
    }
}
