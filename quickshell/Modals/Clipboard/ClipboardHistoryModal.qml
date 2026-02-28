pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import qs.Common
import qs.Modals.Clipboard
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: clipboardHistoryModal

    layerNamespace: "dms:clipboard"

    HyprlandFocusGrab {
        windows: [clipboardHistoryModal.contentWindow]
        active: clipboardHistoryModal.useHyprlandFocusGrab && clipboardHistoryModal.shouldHaveFocus
    }

    property string activeTab: "recents"
    onActiveTabChanged: {
        ClipboardService.selectedIndex = 0;
        ClipboardService.keyboardNavigationActive = false;
    }
    property var editClipboardModal: null
    property bool showKeyboardHints: false
    property Component clipboardContent
    property int activeImageLoads: 0
    readonly property int maxConcurrentLoads: 3

    readonly property bool clipboardAvailable: ClipboardService.clipboardAvailable
    readonly property bool wtypeAvailable: ClipboardService.wtypeAvailable
    readonly property int totalCount: ClipboardService.totalCount
    readonly property var clipboardEntries: ClipboardService.clipboardEntries
    readonly property var pinnedEntries: ClipboardService.pinnedEntries
    readonly property int pinnedCount: ClipboardService.pinnedCount
    readonly property var unpinnedEntries: ClipboardService.unpinnedEntries
    readonly property int selectedIndex: ClipboardService.selectedIndex
    readonly property bool keyboardNavigationActive: ClipboardService.keyboardNavigationActive
    property string searchText: ClipboardService.searchText
    onSearchTextChanged: ClipboardService.searchText = searchText

    Ref {
        service: ClipboardService
    }

    property string mode: "history"

    function updateFilteredModel() {
        ClipboardService.updateFilteredModel();
    }

    function pasteSelected() {
        ClipboardService.pasteSelected(instantClose);
    }

    function toggle() {
        if (shouldBeVisible) {
            hide();
        } else {
            show();
        }
    }

    function show() {
        if (!clipboardAvailable) {
            ToastService.showError(I18n.tr("Clipboard service not available"));
            return;
        }
        open();
        mode = "history";
        activeImageLoads = 0;
        shouldHaveFocus = true;
        ClipboardService.reset();
        ClipboardService.refresh();
        keyboardController.reset();

        Qt.callLater(function () {
            if (contentLoader.item?.searchField) {
                contentLoader.item.searchField.text = "";
                contentLoader.item.searchField.forceActiveFocus();
            }
        });
    }

    function hide() {
        close();
    }

    onDialogClosed: {
        activeImageLoads = 0;
        ClipboardService.reset();
        keyboardController.reset();
    }

    function refreshClipboard() {
        ClipboardService.refresh();
    }

    function copyEntry(entry) {
        ClipboardService.copyEntry(entry, hide);
    }

    function deleteEntry(entry) {
        ClipboardService.deleteEntry(entry);
    }

    function deletePinnedEntry(entry) {
        ClipboardService.deletePinnedEntry(entry, clearConfirmDialog);
    }

    function pinEntry(entry) {
        ClipboardService.pinEntry(entry);
    }

    function unpinEntry(entry) {
        ClipboardService.unpinEntry(entry);
    }

    function clearAll() {
        ClipboardService.clearAll();
    }

    function getEntryPreview(entry) {
        return ClipboardService.getEntryPreview(entry);
    }

    function getEntryType(entry) {
        return ClipboardService.getEntryType(entry);
    }

    function editEntry(entry) {
        if (!entry) {
            return;
        }
        if (entry.isImage) {
            return;
        }
        const editor = contentLoader.item?.editorView;
        if (!editor) {
            return;
        }
        editor.setEntry(entry);
        mode = "editor";
    }

    visible: false
    modalWidth: ClipboardConstants.modalWidth
    modalHeight: ClipboardConstants.modalHeight
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    cornerRadius: Theme.cornerRadius
    borderColor: Theme.outlineMedium
    borderWidth: 1
    enableShadow: true
    onBackgroundClicked: hide()
    modalFocusScope.Keys.onPressed: function (event) {
        keyboardController.handleKey(event);
    }
    content: clipboardContent

    ClipboardKeyboardController {
        id: keyboardController
        modal: clipboardHistoryModal
    }

    ConfirmModal {
        id: clearConfirmDialog
        confirmButtonText: I18n.tr("Clear All")
        confirmButtonColor: Theme.primary
        onVisibleChanged: {
            if (visible) {
                clipboardHistoryModal.shouldHaveFocus = false;
                return;
            }
            Qt.callLater(function () {
                if (!clipboardHistoryModal.shouldBeVisible) {
                    return;
                }
                clipboardHistoryModal.shouldHaveFocus = true;
                clipboardHistoryModal.modalFocusScope.forceActiveFocus();
                if (clipboardHistoryModal.contentLoader.item?.searchField) {
                    clipboardHistoryModal.contentLoader.item.searchField.forceActiveFocus();
                }
            });
        }
    }

    property var confirmDialog: clearConfirmDialog

    clipboardContent: Component {
        Item {
            id: viewContainer

            property alias editorView: editorView
            property alias searchField: historyContent.searchField

            anchors.fill: parent

            Item {
                id: historyView

                anchors.fill: parent
                opacity: 1
                scale: 1
                visible: opacity > 0.01
                enabled: clipboardHistoryModal.mode === "history"

                ClipboardContent {
                    id: historyContent
                    anchors.fill: parent
                    modal: clipboardHistoryModal
                    clearConfirmDialog: clipboardHistoryModal.confirmDialog
                }
            }

            Item {
                id: editorView

                anchors.fill: parent
                opacity: 0
                scale: 0.98
                visible: opacity > 0.01
                enabled: clipboardHistoryModal.mode === "editor"

                property var entry: null
                property string editorText: ""

                function setEntry(newEntry) {
                    entry = newEntry;
                    editorText = newEntry?.text ?? newEntry?.preview ?? "";
                    if (editField) {
                        editField.text = editorText;
                    }
                    Qt.callLater(function () {
                        if (editField) {
                            editField.forceActiveFocus();
                        }
                    });
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM

                    Item {
                        width: parent.width
                        height: ClipboardConstants.headerHeight

                        DankActionButton {
                            iconName: "arrow_back"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: clipboardHistoryModal.mode = "history"
                        }

                        StyledText {
                            text: I18n.tr("Edit Clipboard")
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.centerIn: parent
                        }

                        DankActionButton {
                            iconName: "close"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: clipboardHistoryModal.mode = "history"
                        }
                    }

                    StyledRect {
                        id: editFieldContainer
                        width: parent.width
                        height: Math.max(Theme.fontSizeMedium * 8, Theme.fontSizeMedium * 3)
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                        border.color: editField.activeFocus ? Theme.primary : Theme.outlineMedium
                        border.width: editField.activeFocus ? 2 : 1
                        clip: true

                        DankIcon {
                            id: editIcon
                            name: "edit"
                            size: Theme.iconSize
                            color: editField.activeFocus ? Theme.primary : Theme.surfaceVariantText
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.top: parent.top
                            anchors.topMargin: Theme.spacingM
                        }

                        TextEdit {
                            id: editField
                            anchors.left: editIcon.right
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: Theme.spacingM
                            anchors.topMargin: Theme.spacingS
                            anchors.bottomMargin: Theme.spacingS
                            text: editorView.editorText
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            Keys.forwardTo: [clipboardHistoryModal.modalFocusScope]
                            onTextChanged: editorView.editorText = text
                            Keys.onEscapePressed: function (event) {
                                clipboardHistoryModal.mode = "history";
                                event.accepted = true;
                            }
                        }

                        StyledText {
                            text: I18n.tr("Edit clipboard text")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.outlineButton
                            anchors.left: editField.left
                            anchors.right: editField.right
                            anchors.top: editField.top
                            anchors.bottom: editField.bottom
                            visible: editField.text.length === 0 && !editField.activeFocus
                            wrapMode: Text.WordWrap
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        Item {
                            id: buttonSpacer
                            width: Math.max(0, parent.width - cancelButton.width - saveButton.width - Theme.spacingS)
                            height: 1
                        }

                        DankButton {
                            id: cancelButton
                            text: I18n.tr("Cancel")
                            backgroundColor: Theme.surfaceContainerHigh
                            textColor: Theme.surfaceText
                            onClicked: clipboardHistoryModal.mode = "history"
                        }

                        DankButton {
                            id: saveButton
                            text: I18n.tr("Save")
                            backgroundColor: Theme.primary
                            textColor: Theme.onPrimary
                            onClicked: {
                                DMSService.sendRequest("clipboard.copy", {
                                    "text": editorView.editorText
                                }, function (response) {
                                    if (response.error) {
                                        ToastService.showError(I18n.tr("Failed to update clipboard"));
                                        return;
                                    }
                                    clipboardHistoryModal.mode = "history";
                                    clipboardHistoryModal.refreshClipboard();
                                });
                            }
                        }
                    }
                }
            }

            states: [
                State {
                    name: "history"
                    when: clipboardHistoryModal.mode === "history"
                    PropertyChanges {
                        target: historyView
                        opacity: 1
                        scale: 1
                    }
                    PropertyChanges {
                        target: editorView
                        opacity: 0
                        scale: 0.98
                    }
                },
                State {
                    name: "editor"
                    when: clipboardHistoryModal.mode === "editor"
                    PropertyChanges {
                        target: historyView
                        opacity: 0
                        scale: 0.98
                    }
                    PropertyChanges {
                        target: editorView
                        opacity: 1
                        scale: 1
                    }
                }
            ]

            transitions: [
                Transition {
                    from: "history"
                    to: "editor"
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                        NumberAnimation {
                            property: "scale"
                            duration: Theme.shortDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                },
                Transition {
                    from: "editor"
                    to: "history"
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                        NumberAnimation {
                            property: "scale"
                            duration: Theme.shortDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                }
            ]
        }
    }
}
