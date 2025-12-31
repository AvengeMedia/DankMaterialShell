pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import qs.Common
import qs.Modals.Common
import qs.Services

DankModal {
    id: clipboardHistoryModal

    layerNamespace: "dms:clipboard"

    HyprlandFocusGrab {
        windows: [clipboardHistoryModal.contentWindow]
        active: clipboardHistoryModal.useHyprlandFocusGrab && clipboardHistoryModal.shouldHaveFocus
    }

    property int totalCount: 0
    property var clipboardEntries: []
    property string searchText: ""
    property int selectedIndex: 0
    property bool keyboardNavigationActive: false
    property bool showKeyboardHints: false
    property Component clipboardContent
    property int activeImageLoads: 0
    readonly property int maxConcurrentLoads: 3
    readonly property bool clipboardAvailable: DMSService.isConnected && (DMSService.capabilities.length === 0 || DMSService.capabilities.includes("clipboard"))
    property bool wtypeAvailable: false

    Process {
        id: wtypeCheck
        command: ["which", "wtype"]
        running: true
        onExited: exitCode => {
            clipboardHistoryModal.wtypeAvailable = (exitCode === 0);
        }
    }

    Process {
        id: wtypeProcess
        command: ["wtype", "-M", "ctrl", "-P", "v", "-p", "v", "-m", "ctrl"]
        running: false
    }

    Timer {
        id: pasteTimer
        interval: 200
        repeat: false
        onTriggered: wtypeProcess.running = true
    }

    function pasteSelected() {
        if (!keyboardNavigationActive || clipboardEntries.length === 0 || selectedIndex < 0 || selectedIndex >= clipboardEntries.length) {
            return;
        }
        if (!wtypeAvailable) {
            ToastService.showError(I18n.tr("wtype not available - install wtype for paste support"));
            return;
        }
        const entry = clipboardEntries[selectedIndex];
        DMSService.sendRequest("clipboard.copyEntry", {
            "id": entry.id
        }, function (response) {
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to copy entry"));
                return;
            }
            instantClose();
            pasteTimer.start();
        });
    }

    function updateFilteredModel() {
        const query = searchText.trim();
        if (query.length === 0) {
            clipboardEntries = internalEntries;
        } else {
            const lowerQuery = query.toLowerCase();
            clipboardEntries = internalEntries.filter(entry => entry.preview.toLowerCase().includes(lowerQuery));
        }
        totalCount = clipboardEntries.length;
        if (clipboardEntries.length === 0) {
            keyboardNavigationActive = false;
            selectedIndex = 0;
        } else if (selectedIndex >= clipboardEntries.length) {
            selectedIndex = clipboardEntries.length - 1;
        }
    }

    property var internalEntries: []

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
        searchText = "";
        activeImageLoads = 0;
        shouldHaveFocus = true;
        refreshClipboard();
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
        searchText = "";
        activeImageLoads = 0;
        internalEntries = [];
        clipboardEntries = [];
        keyboardController.reset();
    }

    function refreshClipboard() {
        DMSService.sendRequest("clipboard.getHistory", null, function (response) {
            if (response.error) {
                console.warn("ClipboardHistoryModal: Failed to get history:", response.error);
                return;
            }
            internalEntries = response.result || [];
            updateFilteredModel();
        });
    }

    function copyEntry(entry) {
        DMSService.sendRequest("clipboard.copyEntry", {
            "id": entry.id
        }, function (response) {
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to copy entry"));
                return;
            }
            ToastService.showInfo(entry.isImage ? I18n.tr("Image copied to clipboard") : I18n.tr("Copied to clipboard"));
            hide();
        });
    }

    function deleteEntry(entry) {
        DMSService.sendRequest("clipboard.deleteEntry", {
            "id": entry.id
        }, function (response) {
            if (response.error) {
                console.warn("ClipboardHistoryModal: Failed to delete entry:", response.error);
                return;
            }
            internalEntries = internalEntries.filter(e => e.id !== entry.id);
            updateFilteredModel();
            if (clipboardEntries.length === 0) {
                keyboardNavigationActive = false;
                selectedIndex = 0;
            } else if (selectedIndex >= clipboardEntries.length) {
                selectedIndex = clipboardEntries.length - 1;
            }
        });
    }

    function clearAll() {
        DMSService.sendRequest("clipboard.clearHistory", null, function (response) {
            if (response.error) {
                console.warn("ClipboardHistoryModal: Failed to clear history:", response.error);
                return;
            }
            internalEntries = [];
            clipboardEntries = [];
            totalCount = 0;
        });
    }

    function getEntryPreview(entry) {
        return entry.preview || "";
    }

    function getEntryType(entry) {
        if (entry.isImage) {
            return "image";
        }
        if (entry.size > ClipboardConstants.longTextThreshold) {
            return "long_text";
        }
        return "text";
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
            } else if (clipboardHistoryModal.shouldBeVisible) {
                clipboardHistoryModal.shouldHaveFocus = true;
                clipboardHistoryModal.modalFocusScope.forceActiveFocus();
                if (clipboardHistoryModal.contentLoader.item?.searchField) {
                    clipboardHistoryModal.contentLoader.item.searchField.forceActiveFocus();
                }
            }
        }
    }

    property var confirmDialog: clearConfirmDialog

    clipboardContent: Component {
        ClipboardContent {
            modal: clipboardHistoryModal
            clearConfirmDialog: clipboardHistoryModal.confirmDialog
        }
    }
}
