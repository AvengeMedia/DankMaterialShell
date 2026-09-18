import QtQuick
import qs.Common
import qs.Widgets

SettingsRow {
    id: root

    property bool checked: false

    signal navigated
    signal toggled(bool checked)

    clickable: true
    onClicked: navigated()

    Rectangle {
        width: Theme.dividerWidth
        height: SettingsMetrics.splitDividerHeight
        color: Theme.outlineVariant
        anchors.verticalCenter: parent.verticalCenter
    }

    Item {
        width: Theme.spacingS
        height: parent.height
    }

    DankToggle {
        hideText: true
        checked: root.checked
        enabled: root.enabled
        onToggled: value => root.toggled(value)
    }
}
