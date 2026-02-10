import QtQuick
import qs.Services

QtObject {
    id: keyboardController

    required property var modal

    function reset() {
        ClipboardService.selectedIndex = 0;
        ClipboardService.keyboardNavigationActive = false;
        modal.showKeyboardHints = false;
    }

    function selectNext() {
        const entries = modal.activeTab === "saved" ? ClipboardService.pinnedEntries : ClipboardService.unpinnedEntries;
        if (!entries || entries.length === 0) {
            return;
        }
        ClipboardService.keyboardNavigationActive = true;
        ClipboardService.selectedIndex = Math.min(ClipboardService.selectedIndex + 1, entries.length - 1);
    }

    function selectPrevious() {
        const entries = modal.activeTab === "saved" ? ClipboardService.pinnedEntries : ClipboardService.unpinnedEntries;
        if (!entries || entries.length === 0) {
            return;
        }
        ClipboardService.keyboardNavigationActive = true;
        ClipboardService.selectedIndex = Math.max(ClipboardService.selectedIndex - 1, 0);
    }

    function copySelected() {
        const entries = modal.activeTab === "saved" ? ClipboardService.pinnedEntries : ClipboardService.unpinnedEntries;
        if (!entries || entries.length === 0 || ClipboardService.selectedIndex < 0 || ClipboardService.selectedIndex >= entries.length) {
            return;
        }
        const selectedEntry = entries[ClipboardService.selectedIndex];
        modal.copyEntry(selectedEntry);
    }

    function deleteSelected() {
        const entries = modal.activeTab === "saved" ? ClipboardService.pinnedEntries : ClipboardService.unpinnedEntries;
        if (!entries || entries.length === 0 || ClipboardService.selectedIndex < 0 || ClipboardService.selectedIndex >= entries.length) {
            return;
        }
        const selectedEntry = entries[ClipboardService.selectedIndex];
        if (modal.activeTab === "saved") {
            modal.deletePinnedEntry(selectedEntry);
        } else {
            modal.deleteEntry(selectedEntry);
        }
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Escape:
            if (ClipboardService.keyboardNavigationActive) {
                ClipboardService.keyboardNavigationActive = false;
            } else {
                modal.hide();
            }
            event.accepted = true;
            return;
        case Qt.Key_Down:
        case Qt.Key_Tab:
            if (!ClipboardService.keyboardNavigationActive) {
                ClipboardService.keyboardNavigationActive = true;
                ClipboardService.selectedIndex = 0;
            } else {
                selectNext();
            }
            event.accepted = true;
            return;
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            if (!ClipboardService.keyboardNavigationActive) {
                ClipboardService.keyboardNavigationActive = true;
                ClipboardService.selectedIndex = 0;
            } else if (ClipboardService.selectedIndex === 0) {
                ClipboardService.keyboardNavigationActive = false;
            } else {
                selectPrevious();
            }
            event.accepted = true;
            return;
        case Qt.Key_F10:
            modal.showKeyboardHints = !modal.showKeyboardHints;
            event.accepted = true;
            return;
        }

        if (event.modifiers & Qt.ControlModifier) {
            switch (event.key) {
            case Qt.Key_N:
            case Qt.Key_J:
                if (!ClipboardService.keyboardNavigationActive) {
                    ClipboardService.keyboardNavigationActive = true;
                    ClipboardService.selectedIndex = 0;
                } else {
                    selectNext();
                }
                event.accepted = true;
                return;
            case Qt.Key_P:
            case Qt.Key_K:
                if (!ClipboardService.keyboardNavigationActive) {
                    ClipboardService.keyboardNavigationActive = true;
                    ClipboardService.selectedIndex = 0;
                } else if (ClipboardService.selectedIndex === 0) {
                    ClipboardService.keyboardNavigationActive = false;
                } else {
                    selectPrevious();
                }
                event.accepted = true;
                return;
            case Qt.Key_C:
                if (ClipboardService.keyboardNavigationActive) {
                    copySelected();
                    event.accepted = true;
                }
                return;
            }
        }

        if (event.modifiers & Qt.ShiftModifier) {
            switch (event.key) {
            case Qt.Key_Delete:
                modal.clearAll();
                modal.hide();
                event.accepted = true;
                return;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (ClipboardService.keyboardNavigationActive) {
                    modal.pasteSelected();
                    event.accepted = true;
                }
                return;
            }
        }

        if (ClipboardService.keyboardNavigationActive) {
            switch (event.key) {
            case Qt.Key_Return:
            case Qt.Key_Enter:
                copySelected();
                event.accepted = true;
                return;
            case Qt.Key_Delete:
                deleteSelected();
                event.accepted = true;
                return;
            }
        }
    }
}
