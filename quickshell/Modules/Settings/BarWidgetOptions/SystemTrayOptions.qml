import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets

Column {
    id: root

    property var page: null

    readonly property bool inlineExpansion: page.value("trayUseInlineExpansion")
    readonly property bool autoOverflow: page.value("trayAutoOverflow")

    width: parent?.width ?? 0
    spacing: Theme.spacingL

    SettingsCard {
        settingKey: "barWidgetTray"

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["trayUseInlineExpansion"]
            text: I18n.tr("Use inline expansion")
            checked: root.inlineExpansion
            onToggled: checked => root.page.set("trayUseInlineExpansion", checked)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["trayPopupSingleLine"]
            text: I18n.tr("Single-line popup")
            enabled: !root.inlineExpansion
            checked: root.page.value("trayPopupSingleLine")
            onToggled: checked => root.page.set("trayPopupSingleLine", checked)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["trayAutoOverflow"]
            text: I18n.tr("Auto overflow")
            checked: root.autoOverflow
            onToggled: checked => root.page.set("trayAutoOverflow", checked)
        }

        SettingsSliderRow {
            resetStore: root.page
            resetKeys: ["trayMaxVisibleItems"]
            text: I18n.tr("Max visible")
            unit: ""
            minimumLabel: I18n.tr("Auto")
            enabled: root.autoOverflow
            value: root.page.value("trayMaxVisibleItems")
            minimum: 0
            maximum: 20
            onSliderValueChanged: newValue => root.page.set("trayMaxVisibleItems", newValue)
        }

        SettingsSliderRow {
            resetStore: root.page
            resetKeys: ["trayIconSpacing"]
            text: I18n.tr("Icon spacing")
            value: root.page.value("trayIconSpacing")
            minimum: 0
            maximum: 20
            unit: "px"
            onSliderValueChanged: newValue => root.page.set("trayIconSpacing", newValue)
        }
    }
}
