import QtQuick
import qs.Common
import qs.Widgets

SettingsRow {
    id: root

    property string text: ""
    property string description: ""
    property color descriptionColor: Theme.surfaceVariantText
    property bool checked: false
    property bool toggling: false

    signal toggled(bool checked)

    title: text
    subtitle: description
    subtitleColor: descriptionColor
    clickable: true
    resetByKeys: false
    onResetRequested: {
        if (!resetByKeys)
            toggled(!checked);
    }
    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.onToggleAction: root.clicked()
    onClicked: {
        if (!enabled || toggling)
            return;
        toggled(!checked);
    }

    DankToggle {
        hideText: true
        text: root.text
        description: root.description
        activeFocusOnTab: false
        Accessible.ignored: true
        checked: root.checked
        enabled: root.enabled
        toggling: root.toggling
        onToggled: value => root.toggled(value)
    }
}
