import QtQuick
import Quickshell
import qs.Common
import qs.Widgets

Item {
    id: clipboardContent

    required property var modal
    required property var clearConfirmDialog

    property alias searchField: searchField
    property alias clipboardListView: clipboardListView

    anchors.fill: parent

    Column {
        id: headerColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM
        focus: false

        ClipboardHeader {
            id: header
            width: parent.width
            totalCount: modal.totalCount
            showKeyboardHints: modal.showKeyboardHints
            activeTab: modal.activeTab
            pinnedCount: modal.pinnedCount
            onKeyboardHintsToggled: modal.showKeyboardHints = !modal.showKeyboardHints
            onTabChanged: tabName => modal.activeTab = tabName
            onClearAllClicked: {
                const hasPinned = modal.pinnedCount > 0;
                const message = hasPinned ? I18n.tr("This will delete all unpinned entries. %1 pinned entries will be kept.").arg(modal.pinnedCount) : I18n.tr("This will permanently delete all clipboard history.");
                clearConfirmDialog.show(I18n.tr("Clear History?"), message, function () {
                    modal.clearAll();
                    modal.hide();
                }, function () {});
            }
            onCloseClicked: modal.hide()
        }

        DankTextField {
            id: searchField
            width: parent.width
            placeholderText: ""
            leftIconName: "search"
            showClearButton: true
            focus: true
            ignoreTabKeys: true
            keyForwardTargets: [modal.modalFocusScope]
            onTextChanged: {
                modal.searchText = text;
                modal.updateFilteredModel();
            }
            Keys.onEscapePressed: function (event) {
                modal.hide();
                event.accepted = true;
            }
            Component.onCompleted: {
                Qt.callLater(function () {
                    forceActiveFocus();
                });
            }

            Connections {
                target: modal
                function onOpened() {
                    Qt.callLater(function () {
                        searchField.forceActiveFocus();
                    });
                }
            }
        }
    }

    Item {
        id: listContainer
        anchors.top: headerColumn.bottom
        anchors.topMargin: Theme.spacingM
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.bottomMargin: modal.showKeyboardHints ? (ClipboardConstants.keyboardHintsHeight + Theme.spacingM * 2) : 0
        clip: true

        DankListView {
            id: clipboardListView
            anchors.fill: parent
            model: ScriptModel {
                values: clipboardContent.modal.unpinnedEntries
                objectProp: "id"
            }
            visible: modal.activeTab === "recents"

            currentIndex: clipboardContent.modal ? clipboardContent.modal.selectedIndex : 0
            spacing: Theme.spacingXS
            interactive: true
            flickDeceleration: 1500
            maximumFlickVelocity: 2000
            boundsBehavior: Flickable.DragAndOvershootBounds
            boundsMovement: Flickable.FollowBoundsBehavior
            pressDelay: 0
            flickableDirection: Flickable.VerticalFlick

            function ensureVisible(index) {
                if (index < 0 || index >= count) {
                    return;
                }
                const itemHeight = ClipboardConstants.itemHeight + spacing;
                const itemY = index * itemHeight;
                const itemBottom = itemY + itemHeight;
                if (itemY < contentY) {
                    contentY = itemY;
                } else if (itemBottom > contentY + height) {
                    contentY = itemBottom - height;
                }
            }

            onCurrentIndexChanged: {
                if (clipboardContent.modal?.keyboardNavigationActive && currentIndex >= 0) {
                    ensureVisible(currentIndex);
                }
            }

            StyledText {
                text: I18n.tr("No recent clipboard entries found")
                anchors.centerIn: parent
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                visible: clipboardContent.modal.unpinnedEntries.length === 0
            }

            delegate: ClipboardEntry {
                required property int index
                required property var modelData

                width: clipboardListView.width
                height: ClipboardConstants.itemHeight
                entry: modelData
                entryIndex: index + 1
                itemIndex: index
                isSelected: clipboardContent.modal?.keyboardNavigationActive && index === clipboardContent.modal.selectedIndex
                modal: clipboardContent.modal
                listView: clipboardListView
                onCopyRequested: clipboardContent.modal.copyEntry(modelData)
                onDeleteRequested: clipboardContent.modal.deleteEntry(modelData)
                onPinRequested: clipboardContent.modal.pinEntry(modelData)
                onUnpinRequested: clipboardContent.modal.unpinEntry(modelData)
            }
        }

        DankListView {
            id: savedListView
            anchors.fill: parent
            model: ScriptModel {
                values: clipboardContent.modal.pinnedEntries
                objectProp: "id"
            }
            visible: modal.activeTab === "saved"

            currentIndex: clipboardContent.modal ? clipboardContent.modal.selectedIndex : 0
            spacing: Theme.spacingXS
            interactive: true
            flickDeceleration: 1500
            maximumFlickVelocity: 2000
            boundsBehavior: Flickable.DragAndOvershootBounds
            boundsMovement: Flickable.FollowBoundsBehavior
            pressDelay: 0
            flickableDirection: Flickable.VerticalFlick

            function ensureVisible(index) {
                if (index < 0 || index >= count) {
                    return;
                }
                const itemHeight = ClipboardConstants.itemHeight + spacing;
                const itemY = index * itemHeight;
                const itemBottom = itemY + itemHeight;
                if (itemY < contentY) {
                    contentY = itemY;
                } else if (itemBottom > contentY + height) {
                    contentY = itemBottom - height;
                }
            }

            onCurrentIndexChanged: {
                if (clipboardContent.modal?.keyboardNavigationActive && currentIndex >= 0) {
                    ensureVisible(currentIndex);
                }
            }

            StyledText {
                text: I18n.tr("No saved clipboard entries")
                anchors.centerIn: parent
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                visible: clipboardContent.modal.pinnedEntries.length === 0
            }

            delegate: ClipboardEntry {
                required property int index
                required property var modelData

                width: savedListView.width
                height: ClipboardConstants.itemHeight
                entry: modelData
                entryIndex: index + 1
                itemIndex: index
                isSelected: clipboardContent.modal?.keyboardNavigationActive && index === clipboardContent.modal.selectedIndex
                modal: clipboardContent.modal
                listView: savedListView
                onCopyRequested: clipboardContent.modal.copyEntry(modelData)
                onDeleteRequested: clipboardContent.modal.deletePinnedEntry(modelData)
                onPinRequested: clipboardContent.modal.pinEntry(modelData)
                onUnpinRequested: clipboardContent.modal.unpinEntry(modelData)
            }
        }

        Rectangle {
            id: bottomFade
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 24
            z: 100
            visible: {
                const listView = modal.activeTab === "recents" ? clipboardListView : savedListView;
                if (listView.contentHeight <= listView.height)
                    return false;
                const atBottom = listView.contentY >= listView.contentHeight - listView.height - 5;
                return !atBottom;
            }
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: "transparent"
                }
                GradientStop {
                    position: 1.0
                    color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                }
            }
        }
    }

    Loader {
        id: keyboardHintsLoader
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.bottomMargin: active ? Theme.spacingM : 0
        active: modal.showKeyboardHints
        height: active ? ClipboardConstants.keyboardHintsHeight : 0

        Behavior on height {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }

        sourceComponent: ClipboardKeyboardHints {
            wtypeAvailable: modal.wtypeAvailable
        }
    }
}
