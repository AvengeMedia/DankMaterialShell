import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets

Column {
    id: root

    property var page: null

    width: parent?.width ?? 0
    spacing: Theme.spacingL

    SettingsCard {
        settingKey: "barWidgetSystemUpdate"

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["hideWhenIdle"]
            text: I18n.tr("Hide when no updates")
            checked: root.page.value("hideWhenIdle")
            onToggled: checked => root.page.set("hideWhenIdle", checked)
        }
    }
}
