pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modals.Clipboard
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankPopout {
    id: root

    layerNamespace: "dms:clipboard-popout"

    property var parentWidget: null
    property var triggerScreen: null
    property string activeTab: "recents"
    property bool showKeyboardHints: false
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

    readonly property var modalFocusScope: contentLoader.item ?? null

    Ref {
        service: ClipboardService
    }

    function updateFilteredModel() {
        ClipboardService.updateFilteredModel();
    }

    function pasteSelected() {
        ClipboardService.pasteSelected(instantClose);
    }

    function instantClose() {
        close();
    }

    function show() {
        open();
        activeImageLoads = 0;
        ClipboardService.reset();
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

    popupWidth: ClipboardConstants.popoutWidth
    popupHeight: ClipboardConstants.popoutHeight
    triggerWidth: 55
    positioning: ""
    screen: triggerScreen
    shouldBeVisible: false
    contentHandlesKeys: true

    onBackgroundClicked: hide()

    onShouldBeVisibleChanged: {
        if (!shouldBeVisible)
            return;
        if (clipboardAvailable) {
            if (Theme.isConnectedEffect) {
                Qt.callLater(() => {
                    if (root.shouldBeVisible)
                        ClipboardService.refresh();
                });
            } else {
                ClipboardService.refresh();
            }
        }
        keyboardController.reset();
        Qt.callLater(function () {
            if (contentLoader.item?.searchField) {
                contentLoader.item.searchField.text = "";
                contentLoader.item.searchField.forceActiveFocus();
            }
        });
    }

    onPopoutClosed: {
        activeImageLoads = 0;
        ClipboardService.reset();
        keyboardController.reset();
    }

    ClipboardKeyboardController {
        id: keyboardController
        modal: root
    }

    ConfirmModal {
        id: clearConfirmDialog
        confirmButtonText: I18n.tr("Clear All")
        confirmButtonColor: Theme.primary
    }

    property var confirmDialog: clearConfirmDialog

    content: Component {
        FocusScope {
            id: contentFocusScope

            LayoutMirroring.enabled: I18n.isRtl
            LayoutMirroring.childrenInherit: true

            focus: true

            property alias searchField: clipboardContentItem.searchField

            Keys.onPressed: function (event) {
                keyboardController.handleKey(event);
            }

            Component.onCompleted: {
                if (root.shouldBeVisible)
                    forceActiveFocus();
            }

            Connections {
                target: root
                function onShouldBeVisibleChanged() {
                    if (root.shouldBeVisible) {
                        Qt.callLater(() => contentFocusScope.forceActiveFocus());
                    }
                }
                function onOpened() {
                    Qt.callLater(() => {
                        if (clipboardContentItem.searchField) {
                            clipboardContentItem.searchField.forceActiveFocus();
                        }
                    });
                }
            }

            ClipboardContent {
                id: clipboardContentItem
                modal: root
                clearConfirmDialog: root.confirmDialog
            }
        }
    }
}
