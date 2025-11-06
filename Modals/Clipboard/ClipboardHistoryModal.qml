pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets

DankModal {
    id: clipboardHistoryModal

    layerNamespace: "dms:clipboard"

    property int totalCount: 0
    property var clipboardEntries: []
    property string searchText: ""
    property int selectedIndex: 0
    property bool keyboardNavigationActive: false
    property bool showKeyboardHints: false
    property Component clipboardContent
    property int activeImageLoads: 0
    readonly property int maxConcurrentLoads: 3

    function updateFilteredModel() {
        filteredClipboardModel.clear()
        for (var i = 0; i < clipboardModel.count; i++) {
            const entry = clipboardModel.get(i).entry
            if (searchText.trim().length === 0) {
                filteredClipboardModel.append({
                                                  "entry": entry
                                              })
            } else {
                const content = getEntryPreview(entry).toLowerCase()
                if (content.includes(searchText.toLowerCase())) {
                    filteredClipboardModel.append({
                                                      "entry": entry
                                                  })
                }
            }
        }
        clipboardHistoryModal.totalCount = filteredClipboardModel.count
        if (filteredClipboardModel.count === 0) {
            keyboardNavigationActive = false
            selectedIndex = 0
        } else if (selectedIndex >= filteredClipboardModel.count) {
            selectedIndex = filteredClipboardModel.count - 1
        }
    }

    function toggle() {
        if (shouldBeVisible) {
            hide()
        } else {
            show()
        }
    }

    function show() {
        open()
        clipboardHistoryModal.searchText = ""
        clipboardHistoryModal.activeImageLoads = 0
        clipboardHistoryModal.shouldHaveFocus = true
        refreshClipboard()
        keyboardController.reset()

        Qt.callLater(function () {
            if (contentLoader.item && contentLoader.item.searchField) {
                contentLoader.item.searchField.text = ""
                contentLoader.item.searchField.forceActiveFocus()
            }
        })
    }

    function hide() {
        close()
        clipboardHistoryModal.searchText = ""
        clipboardHistoryModal.activeImageLoads = 0
        updateFilteredModel()
        keyboardController.reset()
        cleanupTempFiles()
    }

    function cleanupTempFiles() {
        Quickshell.execDetached(["sh", "-c", "rm -f /tmp/clipboard_*.png"])
    }

    function refreshClipboard() {
        clipboardProcesses.refresh()
    }

    function copyEntry(entry) {
        const entryId = entry.split('\t')[0]
        Quickshell.execDetached(["sh", "-c", `cliphist decode ${entryId} | wl-copy`])
        ToastService.showInfo(I18n.tr("Copied to clipboard"))
        hide()
    }

    function deleteEntry(entry) {
        clipboardProcesses.deleteEntry(entry)
    }

    function clearAll() {
        clipboardProcesses.clearAll()
    }

    function getEntryPreview(entry) {
        let content = entry.replace(/^\s*\d+\s+/, "")
        if (content.includes("image/") || content.includes("binary data") || /\.(png|jpg|jpeg|gif|bmp|webp)/i.test(content)) {
            const dimensionMatch = content.match(/(\d+)x(\d+)/)
            if (dimensionMatch) {
                return `Image ${dimensionMatch[1]}×${dimensionMatch[2]}`
            }
            const typeMatch = content.match(/\b(png|jpg|jpeg|gif|bmp|webp)\b/i)
            if (typeMatch) {
                return `Image (${typeMatch[1].toUpperCase()})`
            }
            return "Image"
        }
        if (content.length > ClipboardConstants.previewLength) {
            return content.substring(0, ClipboardConstants.previewLength) + "..."
        }
        return content
    }

    function getEntryType(entry) {
        if (entry.includes("image/") || entry.includes("binary data") || /\.(png|jpg|jpeg|gif|bmp|webp)/i.test(entry) || /\b(png|jpg|jpeg|gif|bmp|webp)\b/i.test(entry)) {
            return "image"
        }
        if (entry.length > ClipboardConstants.longTextThreshold) {
            return "long_text"
        }
        return "text"
    }

    visible: false
    width: ClipboardConstants.modalWidth
    height: ClipboardConstants.modalHeight
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    cornerRadius: Theme.cornerRadius
    borderColor: Theme.outlineMedium
    borderWidth: 1
    enableShadow: true
    onBackgroundClicked: hide()
    modalFocusScope.Keys.onPressed: function (event) {
        keyboardController.handleKey(event)
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
                clipboardHistoryModal.shouldHaveFocus = false
            } else if (clipboardHistoryModal.shouldBeVisible) {
                clipboardHistoryModal.shouldHaveFocus = true
                clipboardHistoryModal.modalFocusScope.forceActiveFocus()
                if (clipboardHistoryModal.contentLoader.item && clipboardHistoryModal.contentLoader.item.searchField) {
                    clipboardHistoryModal.contentLoader.item.searchField.forceActiveFocus()
                }
            }
        }
    }

    property alias filteredClipboardModel: filteredClipboardModel
    property alias clipboardModel: clipboardModel
    property var confirmDialog: clearConfirmDialog

    ListModel {
        id: clipboardModel
    }

    ListModel {
        id: filteredClipboardModel
    }

    ClipboardProcesses {
        id: clipboardProcesses
        modal: clipboardHistoryModal
        clipboardModel: clipboardModel
        filteredClipboardModel: filteredClipboardModel
    }

    IpcHandler {
        function open(): string {
            clipboardHistoryModal.show()
            return "CLIPBOARD_OPEN_SUCCESS"
        }

        function close(): string {
            clipboardHistoryModal.hide()
            return "CLIPBOARD_CLOSE_SUCCESS"
        }

        function toggle(): string {
            clipboardHistoryModal.toggle()
            return "CLIPBOARD_TOGGLE_SUCCESS"
        }

        target: "clipboard"
    }

    clipboardContent: Component {
        ClipboardContent {
            modal: clipboardHistoryModal
            filteredModel: filteredClipboardModel
            clearConfirmDialog: clipboardHistoryModal.confirmDialog
        }
    }
}
