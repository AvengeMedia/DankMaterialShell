import QtQuick
import Quickshell
import qs.Common
import qs.Widgets

Item {
    id: clipboardContent

    required property var modal

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
            recentsCount: modal.unpinnedEntries.length
            savedCount: modal.pinnedEntries.length
            showKeyboardHints: modal.showKeyboardHints
            activeTab: modal.activeTab
            pinnedCount: modal.pinnedCount
            activeFilter: modal.activeFilter
            onFilterChanged: filter => modal.activeFilter = filter
            onKeyboardHintsToggled: modal.showKeyboardHints = !modal.showKeyboardHints
            onTabChanged: tabName => modal.activeTab = tabName
            onClearAllClicked: modal.confirmClearAll()
            onCloseClicked: modal.hide()
        }

         Row {
            width: parent.width
            spacing: Theme.spacingS

            DankDropdown {
                id: filterDropdown
                width: 120

                text: ""
                currentValue: {
                    switch (modal.activeFilter) {
                        case "text":
                            return I18n.tr("Text");
                        case "long_text":
                            return I18n.tr("Long Text");
                        case "image":
                            return I18n.tr("Image");
                        default:
                            return I18n.tr("All");
                    }
                }

                options: [I18n.tr("All"), I18n.tr("Text"), I18n.tr("Long Text"), I18n.tr("Image")]

                onValueChanged: value => {
                    switch (value) {
                        case I18n.tr("Text"):
                            modal.activeFilter = "text";
                            break;
                        case I18n.tr("Long Text"):
                            modal.activeFilter = "long_text";
                            break;
                        case I18n.tr("Image"):
                            modal.activeFilter = "image";
                            break;
                        default:
                            modal.activeFilter = "all";
                    }
                }
            }

            DankTextField {
                id: searchField

                width: parent.width - 120 - parent.spacing

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
        anchors.bottomMargin: (modal.showKeyboardHints ? (ClipboardConstants.keyboardHintsHeight + Theme.spacingM * 2) : 0) + Theme.spacingXS
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

            states: [
                State {
                    name: "snap"
                    when: Theme.snapListModelChanges
                    PropertyChanges {
                        target: clipboardListView
                        add: null
                        remove: null
                        displaced: null
                        move: null
                    }
                }
            ]

            function ensureVisible(index) {
                if (index < 0 || index >= count) {
                    return;
                }
                positionViewAtIndex(index, ListView.Contain);
            }

            onCurrentIndexChanged: {
                if (clipboardContent.modal?.keyboardNavigationActive && currentIndex >= 0) {
                    ensureVisible(currentIndex);
                }
            }

            StyledText {
                text: clipboardContent.modal.clipboardAvailable ? I18n.tr("No recent clipboard entries found") : I18n.tr("Connecting to clipboard service...")
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
                onPinRequested: targetEntry => clipboardContent.modal.pinEntry(targetEntry)
                onUnpinRequested: targetEntry => clipboardContent.modal.unpinEntry(targetEntry)
                onEditRequested: clipboardContent.modal.editEntry(modelData)
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

            states: [
                State {
                    name: "snap"
                    when: Theme.snapListModelChanges
                    PropertyChanges {
                        target: savedListView
                        add: null
                        remove: null
                        displaced: null
                        move: null
                    }
                }
            ]

            function ensureVisible(index) {
                if (index < 0 || index >= count) {
                    return;
                }
                positionViewAtIndex(index, ListView.Contain);
            }

            onCurrentIndexChanged: {
                if (clipboardContent.modal?.keyboardNavigationActive && currentIndex >= 0) {
                    ensureVisible(currentIndex);
                }
            }

            StyledText {
                text: clipboardContent.modal.clipboardAvailable ? I18n.tr("No saved clipboard entries") : I18n.tr("Connecting to clipboard service...")
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
                onPinRequested: targetEntry => clipboardContent.modal.pinEntry(targetEntry)
                onUnpinRequested: targetEntry => clipboardContent.modal.unpinEntry(targetEntry)
                onEditRequested: clipboardContent.modal.editEntry(modelData)
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
            enterToPaste: SettingsData.clipboardEnterToPaste
        }
    }
}
