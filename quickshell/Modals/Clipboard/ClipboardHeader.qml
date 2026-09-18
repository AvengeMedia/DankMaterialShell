import QtQuick
import qs.Common
import qs.Widgets

DankWindowHeader {
    id: header

    required property var modal

    controls: null
    horizontalPadding: 0
    verticalPadding: 0
    showDivider: false
    title: (modal.activeTab === "saved" ? I18n.tr("Clipboard Saved") : I18n.tr("Clipboard History")) + ` (${modal.activeTab === "saved" ? modal.pinnedEntries.length : modal.unpinnedEntries.length})`
    onCloseRequested: modal.hide()

    ClipboardActions {
        modal: header.modal
    }
}
