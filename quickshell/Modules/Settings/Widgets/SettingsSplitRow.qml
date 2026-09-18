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

    DankIcon {
        name: "chevron_right"
        size: Theme.iconSize
        color: Theme.surfaceVariantText
        rotation: I18n.isRtl ? 180 : 0
        anchors.verticalCenter: parent.verticalCenter
    }

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
