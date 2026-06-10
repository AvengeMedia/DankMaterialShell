pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modals.Clipboard
import qs.Modals.Common
import qs.Services

DankModal {
    id: clipboardHistoryModal

    layerNamespace: "dms:clipboard"

    function toggle() {
        if (shouldBeVisible) {
            hide();
            return;
        }
        show();
    }

    function show() {
        open();
        shouldHaveFocus = true;

        Qt.callLater(function () {
            if (contentLoader.item) {
                contentLoader.item.resetState();
            }
            if (clipboardHistoryModal.clipboardAvailable) {
                if (Theme.isConnectedEffect) {
                    Qt.callLater(() => {
                        if (clipboardHistoryModal.shouldBeVisible) {
                            ClipboardService.refresh();
                        }
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
        if (contentLoader.item) {
            contentLoader.item.resetState();
        }
    }

    readonly property bool clipboardAvailable: ClipboardService.clipboardAvailable

    visible: false
    modalWidth: ClipboardConstants.modalWidth
    modalHeight: ClipboardConstants.modalHeight
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    cornerRadius: Theme.cornerRadius
    borderColor: Theme.outlineMedium
    borderWidth: 1
    enableShadow: true
    closeOnEscapeKey: (contentLoader.item?.mode ?? "history") !== "editor"
    onBackgroundClicked: hide()

    Ref {
        service: ClipboardService
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

    content: Component {
        ClipboardHistoryContent {
            clearConfirmDialog: clearConfirmDialog
            onCloseRequested: clipboardHistoryModal.hide()
            onInstantCloseRequested: clipboardHistoryModal.instantClose()
        }
    }
}
