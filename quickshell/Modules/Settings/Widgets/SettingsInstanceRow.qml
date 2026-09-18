import QtQuick
import qs.Common
import qs.Widgets

SettingsRow {
    id: root

    property bool selected: false
    property string summary: ""
    property bool checked: false
    property bool toggleVisible: true
    property bool toggleEnabled: true
    property bool deletable: true
    property bool confirmingDelete: false

    signal toggled(bool checked)
    signal deleteRequested

    clickable: true
    iconName: selected ? "radio_button_checked" : "radio_button_unchecked"
    iconColor: selected ? Theme.primary : Theme.surfaceVariantText
    subtitle: confirmingDelete ? I18n.tr("Confirm Delete") : summary
    subtitleColor: confirmingDelete ? Theme.error : Theme.surfaceVariantText

    DankToggle {
        visible: root.toggleVisible
        hideText: true
        text: root.title
        activeFocusOnTab: false
        checked: root.checked
        enabled: root.toggleEnabled
        onToggled: value => root.toggled(value)
    }

    DankActionButton {
        visible: root.deletable
        iconName: root.confirmingDelete ? "warning" : "delete"
        iconColor: root.confirmingDelete ? Theme.error : Theme.surfaceVariantText
        Accessible.name: root.confirmingDelete ? I18n.tr("Confirm Delete") : I18n.tr("Remove")
        onClicked: root.deleteRequested()
    }
}
