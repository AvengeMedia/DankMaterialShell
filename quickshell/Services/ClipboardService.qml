pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property int longTextThreshold: 200

    readonly property bool clipboardAvailable: DMSService.isConnected && (DMSService.capabilities.length === 0 || DMSService.capabilities.includes("clipboard"))
    readonly property bool wtypeAvailable: SessionService.wtypeAvailable

    property var internalEntries: []
    property var clipboardEntries: []
    property var unpinnedEntries: []
    property var pinnedEntries: []
    property int pinnedCount: 0
    property int totalCount: 0
    property string searchText: ""
    property int selectedIndex: 0
    property bool keyboardNavigationActive: false
    property int refCount: 0

    signal historyCopied
    signal historyCleared

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

    function updateFilteredModel() {
        const query = searchText.trim();
        let filtered = [];

        if (query.length === 0) {
            filtered = internalEntries;
        } else {
            const lowerQuery = query.toLowerCase();
            filtered = internalEntries.filter(entry => entry.preview.toLowerCase().includes(lowerQuery));
        }

        filtered.sort((a, b) => {
            if (a.pinned !== b.pinned)
                return b.pinned ? 1 : -1;
            return b.id - a.id;
        });

        clipboardEntries = filtered;
        unpinnedEntries = filtered.filter(e => !e.pinned);
        totalCount = clipboardEntries.length;

        if (unpinnedEntries.length === 0) {
            keyboardNavigationActive = false;
            selectedIndex = 0;
            return;
        }
        if (selectedIndex >= unpinnedEntries.length) {
            selectedIndex = unpinnedEntries.length - 1;
        }
    }

    function refresh() {
        if (!clipboardAvailable) {
            return;
        }
        DMSService.sendRequest("clipboard.getHistory", null, function (response) {
            if (response.error) {
                console.warn("ClipboardService: Failed to get history:", response.error);
                return;
            }
            internalEntries = response.result || [];
            pinnedEntries = internalEntries.filter(e => e.pinned);
            pinnedCount = pinnedEntries.length;
            updateFilteredModel();
        });
    }

    function reset() {
        searchText = "";
        selectedIndex = 0;
        keyboardNavigationActive = false;
        internalEntries = [];
        clipboardEntries = [];
        unpinnedEntries = [];
    }

    function copyEntry(entry, closeCallback) {
        DMSService.sendRequest("clipboard.copyEntry", {
            "id": entry.id
        }, function (response) {
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to copy entry"));
                return;
            }
            ToastService.showInfo(entry.isImage ? I18n.tr("Image copied to clipboard") : I18n.tr("Copied to clipboard"));
            historyCopied();
            if (closeCallback) {
                closeCallback();
            }
        });
    }

    function pasteEntry(entry, closeCallback) {
        if (!wtypeAvailable) {
            ToastService.showError(I18n.tr("wtype not available - install wtype for paste support"));
            return;
        }
        DMSService.sendRequest("clipboard.copyEntry", {
            "id": entry.id
        }, function (response) {
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to copy entry"));
                return;
            }
            if (closeCallback) {
                closeCallback();
            }
            pasteTimer.start();
        });
    }

    function pasteSelected(closeCallback) {
        if (!keyboardNavigationActive || clipboardEntries.length === 0 || selectedIndex < 0 || selectedIndex >= clipboardEntries.length) {
            return;
        }
        pasteEntry(clipboardEntries[selectedIndex], closeCallback);
    }

    function deleteEntry(entry) {
        DMSService.sendRequest("clipboard.deleteEntry", {
            "id": entry.id
        }, function (response) {
            if (response.error) {
                console.warn("ClipboardService: Failed to delete entry:", response.error);
                return;
            }
            internalEntries = internalEntries.filter(e => e.id !== entry.id);
            updateFilteredModel();
            if (clipboardEntries.length === 0) {
                keyboardNavigationActive = false;
                selectedIndex = 0;
                return;
            }
            if (selectedIndex >= clipboardEntries.length) {
                selectedIndex = clipboardEntries.length - 1;
            }
        });
    }

    function deletePinnedEntry(entry, confirmDialog) {
        if (!confirmDialog) {
            return;
        }
        confirmDialog.show(I18n.tr("Delete Saved Item?"), I18n.tr("This will permanently remove this saved clipboard item. This action cannot be undone."), function () {
            DMSService.sendRequest("clipboard.deleteEntry", {
                "id": entry.id
            }, function (response) {
                if (response.error) {
                    console.warn("ClipboardService: Failed to delete entry:", response.error);
                    return;
                }
                internalEntries = internalEntries.filter(e => e.id !== entry.id);
                updateFilteredModel();
                ToastService.showInfo(I18n.tr("Saved item deleted"));
            });
        }, function () {});
    }

    function pinEntry(entry) {
        DMSService.sendRequest("clipboard.getPinnedCount", null, function (countResponse) {
            if (countResponse.error) {
                ToastService.showError(I18n.tr("Failed to check pin limit"));
                return;
            }

            const maxPinned = 25;
            if (countResponse.result.count >= maxPinned) {
                ToastService.showError(I18n.tr("Maximum pinned entries reached") + " (" + maxPinned + ")");
                return;
            }

            DMSService.sendRequest("clipboard.pinEntry", {
                "id": entry.id
            }, function (response) {
                if (response.error) {
                    ToastService.showError(I18n.tr("Failed to pin entry"));
                    return;
                }
                ToastService.showInfo(I18n.tr("Entry pinned"));
                refresh();
            });
        });
    }

    function unpinEntry(entry) {
        DMSService.sendRequest("clipboard.unpinEntry", {
            "id": entry.id
        }, function (response) {
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to unpin entry"));
                return;
            }
            ToastService.showInfo(I18n.tr("Entry unpinned"));
            refresh();
        });
    }

    function clearAll() {
        const hasPinned = pinnedCount > 0;
        const savedCount = pinnedCount;
        DMSService.sendRequest("clipboard.clearHistory", null, function (response) {
            if (response.error) {
                console.warn("ClipboardService: Failed to clear history:", response.error);
                return;
            }
            refresh();
            historyCleared();
            if (hasPinned) {
                ToastService.showInfo(I18n.tr("History cleared. %1 pinned entries kept.").arg(savedCount));
            }
        });
    }

    function getEntryPreview(entry) {
        return entry.preview || "";
    }

    function getEntryType(entry) {
        if (entry.isImage) {
            return "image";
        }
        if (entry.size > longTextThreshold) {
            return "long_text";
        }
        return "text";
    }

    function hashedPinnedEntry(entryHash) {
        if (!entryHash) {
            return false;
        }
        return pinnedEntries.some(pinnedEntry => pinnedEntry.hash === entryHash);
    }

    Connections {
        target: DMSService
        enabled: root.refCount > 0
        function onClipboardStateUpdate(data) {
            const newHistory = data.history || [];
            internalEntries = newHistory;
            pinnedEntries = newHistory.filter(e => e.pinned);
            pinnedCount = pinnedEntries.length;
            updateFilteredModel();
        }
    }
}
