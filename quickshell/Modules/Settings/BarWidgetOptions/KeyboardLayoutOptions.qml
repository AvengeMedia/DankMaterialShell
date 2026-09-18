import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets

Column {
    id: root

    property var page: null

    width: parent?.width ?? 0
    spacing: Theme.spacingL

    SettingsCard {
        settingKey: "barWidgetKeyboardLayout"

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["keyboardLayoutNameCompactMode"]
            text: I18n.tr("Compact mode")
            checked: root.page.value("keyboardLayoutNameCompactMode")
            onToggled: checked => root.page.set("keyboardLayoutNameCompactMode", checked)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["keyboardLayoutNameShowIcon"]
            text: I18n.tr("Show icon")
            checked: root.page.value("keyboardLayoutNameShowIcon")
            onToggled: checked => root.page.set("keyboardLayoutNameShowIcon", checked)
        }
    }
}
