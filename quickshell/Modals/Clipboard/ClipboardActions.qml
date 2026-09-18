import QtQuick
import qs.Common
import qs.Widgets

Row {
    id: actions

    required property var modal

    spacing: Theme.spacingS

    DankActionButton {
        Keys.forwardTo: [actions.modal.modalFocusScope]
        iconName: "push_pin"
        buttonSize: Theme.buttonHeightXXS
        iconSize: Theme.iconSizeSmall
        iconColor: actions.modal.activeTab === "saved" ? Theme.onPrimary : Theme.onSurfaceVariant
        backgroundColor: actions.modal.activeTab === "saved" ? Theme.primary : "transparent"
        visible: actions.modal.pinnedCount > 0 || actions.modal.activeTab === "saved"
        tooltipText: actions.modal.activeTab === "saved" ? I18n.tr("Recent", "clipboard button tooltip, switches to recent entries") : I18n.tr("Saved", "clipboard button tooltip, switches to saved entries")
        onClicked: actions.modal.activeTab = actions.modal.activeTab === "saved" ? "recents" : "saved"
    }

    DankActionButton {
        Keys.forwardTo: [actions.modal.modalFocusScope]
        iconName: "info"
        buttonSize: Theme.buttonHeightXXS
        iconSize: Theme.iconSizeSmall
        iconColor: actions.modal.showKeyboardHints ? Theme.onSecondaryContainer : Theme.onSurfaceVariant
        backgroundColor: actions.modal.showKeyboardHints ? Theme.secondaryContainer : "transparent"
        tooltipText: I18n.tr("Keyboard shortcuts")
        onClicked: actions.modal.showKeyboardHints = !actions.modal.showKeyboardHints
    }

    DankActionButton {
        Keys.forwardTo: [actions.modal.modalFocusScope]
        iconName: "delete_sweep"
        buttonSize: Theme.buttonHeightXXS
        iconSize: Theme.iconSizeSmall
        tooltipText: actions.modal.clearsFilteredOnly ? I18n.tr("Clear Filtered", "clipboard modal: clear button tooltip while a search filter is active") : I18n.tr("Clear All")
        onClicked: actions.modal.confirmClearAll()
    }
}
