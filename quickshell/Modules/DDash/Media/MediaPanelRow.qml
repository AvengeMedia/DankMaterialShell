import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Settings.Widgets
import qs.Modules.DDash

SettingsRow {
    id: root

    property bool selected: false
    property color accent: Theme.primary

    signal activated

    clickable: true
    rowColor: Theme.withAlpha(root.accent, root.selected ? DashMetrics.accentSelectedAlpha : DashMetrics.groupIdleAlpha)
    iconColor: root.selected ? root.accent : Theme.onSurfaceVariant
    topRadius: Theme.cornerRadiusL
    bottomRadius: Theme.cornerRadiusL
    Accessible.selected: selected
    onClicked: activated()

    DIcon {
        name: "check"
        size: Theme.iconSizeMedium
        color: root.accent
        visible: root.selected
    }
}
