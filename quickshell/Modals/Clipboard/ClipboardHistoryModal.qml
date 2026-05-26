pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import qs.Common
import qs.Modals.Clipboard
import qs.Modals.Common
import qs.Services

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
    onModeChanged: {
        if (mode !== "history") {
            return;
        }
        Qt.callLater(function () {
            if (contentLoader.item?.searchField) {
                contentLoader.item.searchField.forceActiveFocus();
            }
        });
    }

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
        open();
        mode = "history";
        activeImageLoads = 0;
        shouldHaveFocus = true;
        ClipboardService.reset();
        keyboardController.reset();

        Qt.callLater(function () {
            if (clipboardAvailable) {
                if (Theme.isConnectedEffect) {
                    Qt.callLater(() => {
                        if (clipboardHistoryModal.shouldBeVisible)
                            ClipboardService.refresh();
                    });
                } else {
                    ClipboardService.refresh();
                }
            }
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
    closeOnEscapeKey: mode !== "editor"
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

            ClipboardEditor {
                id: editorView

                anchors.fill: parent
                opacity: 0
                scale: 0.98
                visible: opacity > 0.01
                enabled: clipboardHistoryModal.mode === "editor"
                focus: clipboardHistoryModal.mode === "editor"
                modal: clipboardHistoryModal
                keyController: keyboardController
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
