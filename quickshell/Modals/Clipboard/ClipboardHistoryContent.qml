pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

FocusScope {
    id: root

    property var clearConfirmDialog: null

    property string activeTab: "recents"
    property bool showKeyboardHints: false
    property int activeImageLoads: 0
    readonly property int maxConcurrentLoads: 3

    property string mode: "history"
    property string searchText: ClipboardService.searchText

    readonly property bool clipboardAvailable: ClipboardService.clipboardAvailable
    readonly property bool wtypeAvailable: ClipboardService.wtypeAvailable
    readonly property int totalCount: ClipboardService.totalCount
    readonly property var clipboardEntries: ClipboardService.clipboardEntries
    readonly property var pinnedEntries: ClipboardService.pinnedEntries
    readonly property int pinnedCount: ClipboardService.pinnedCount
    readonly property var unpinnedEntries: ClipboardService.unpinnedEntries
    readonly property int selectedIndex: ClipboardService.selectedIndex
    readonly property bool keyboardNavigationActive: ClipboardService.keyboardNavigationActive

    readonly property var modalFocusScope: root
    property alias searchField: historyContent.searchField
    property alias editorView: editorView
    property alias keyboardController: keyboardController

    signal closeRequested
    signal instantCloseRequested

    onActiveTabChanged: {
        if (activeTab === "saved" && pinnedCount === 0) {
            activeTab = "recents";
            return;
        }
        ClipboardService.selectedIndex = 0;
        ClipboardService.keyboardNavigationActive = false;
    }
    onPinnedCountChanged: {
        if (activeTab === "saved" && pinnedCount === 0) {
            activeTab = "recents";
        }
    }
    onSearchTextChanged: ClipboardService.searchText = searchText

    function hide() {
        closeRequested();
    }

    function pasteSelected() {
        ClipboardService.pasteSelected(() => root.instantCloseRequested());
    }

    function copyEntry(entry) {
        ClipboardService.copyEntry(entry, () => root.closeRequested());
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

    function updateFilteredModel() {
        ClipboardService.updateFilteredModel();
    }

    function refreshClipboard() {
        ClipboardService.refresh();
    }

    function editEntry(entry) {
        if (!entry || entry.isImage) {
            return;
        }
        editorView.setEntry(entry);
        mode = "editor";
    }

    function resetState() {
        activeImageLoads = 0;
        mode = "history";
        ClipboardService.reset();
        keyboardController.reset();
    }

    focus: true
    Keys.onPressed: function (event) {
        keyboardController.handleKey(event);
    }

    ClipboardKeyboardController {
        id: keyboardController
        modal: root
    }

    Item {
        id: historyView
        anchors.fill: parent
        opacity: 1
        scale: 1
        visible: opacity > 0.01
        enabled: root.mode === "history"

        ClipboardContent {
            id: historyContent
            anchors.fill: parent
            modal: root
            clearConfirmDialog: root.clearConfirmDialog
        }
    }

    ClipboardEditor {
        id: editorView
        anchors.fill: parent
        opacity: 0
        scale: 0.98
        visible: opacity > 0.01
        enabled: root.mode === "editor"
        focus: root.mode === "editor"
        modal: root
        keyController: keyboardController
    }

    states: [
        State {
            name: "history"
            when: root.mode === "history"
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
            when: root.mode === "editor"
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
