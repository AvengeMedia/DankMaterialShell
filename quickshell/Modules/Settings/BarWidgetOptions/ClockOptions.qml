import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets

Column {
    id: root

    property var page: null

    width: parent?.width ?? 0
    spacing: Theme.spacingL

    SettingsCard {
        settingKey: "barWidgetClock"

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["clockCompactMode"]
            text: I18n.tr("Compact mode")
            checked: root.page.value("clockCompactMode")
            onToggled: checked => root.page.set("clockCompactMode", checked)
        }

        SettingsButtonGroupRow {
            resetStore: root.page
            resetKeys: ["clockDateOrder"]
            text: I18n.tr("Order", "noun, clock widget option for time and date order")
            model: [I18n.tr("Time first"), I18n.tr("Date first")]
            currentIndex: root.page.value("clockDateOrder") === "dateFirst" ? 1 : 0
            onSelectionChanged: (index, selected) => {
                if (!selected)
                    return;
                root.page.set("clockDateOrder", index === 1 ? "dateFirst" : "timeFirst");
            }
        }

        SettingsNavRow {
            iconName: "schedule"
            title: I18n.tr("Time & weather")
            hint: I18n.tr("Clock format, calendar, weather location")
            onClicked: root.page.parentModal?.navigateTo("time_weather")
        }
    }
}
