import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets

Column {
    id: root

    property var page: null

    readonly property var styleValues: ["icon", "solid", "outline", "ring"]

    width: parent?.width ?? 0
    spacing: Theme.spacingL

    SettingsCard {
        settingKey: "barWidgetBattery"

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["showBatteryPercent"]
            text: I18n.tr("Show percentage")
            checked: root.page.value("showBatteryPercent")
            onToggled: checked => root.page.set("showBatteryPercent", checked)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["showBatteryPercentOnlyOnBattery"]
            enabled: root.page.value("showBatteryPercent")
            text: I18n.tr("Only on battery")
            checked: root.page.value("showBatteryPercentOnlyOnBattery")
            onToggled: checked => root.page.set("showBatteryPercentOnlyOnBattery", checked)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["showBatteryTime"]
            text: I18n.tr("Show remaining time")
            checked: root.page.value("showBatteryTime")
            onToggled: checked => root.page.set("showBatteryTime", checked)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["showBatteryTimeOnlyOnBattery"]
            enabled: root.page.value("showBatteryTime")
            text: I18n.tr("Only on battery")
            checked: root.page.value("showBatteryTimeOnlyOnBattery")
            onToggled: checked => root.page.set("showBatteryTimeOnlyOnBattery", checked)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["showBatteryPowerCharging"]
            text: I18n.tr("Show charge rate", "Battery bar widget setting: show how many watts are going into the battery while charging")
            checked: root.page.value("showBatteryPowerCharging")
            onToggled: checked => root.page.set("showBatteryPowerCharging", checked)
        }

        SettingsToggleRow {
            resetStore: root.page
            resetKeys: ["showBatteryPowerDischarging"]
            text: I18n.tr("Show discharge rate", "Battery bar widget setting: show how many watts the system is drawing from the battery")
            checked: root.page.value("showBatteryPowerDischarging")
            onToggled: checked => root.page.set("showBatteryPowerDischarging", checked)
        }

        SettingsButtonGroupRow {
            resetStore: root.page
            resetKeys: ["batteryStyle"]
            text: I18n.tr("Battery style")
            model: [I18n.tr("Icon", "battery widget: system battery glyph"), I18n.tr("Solid", "island settings: filled battery meter style"), I18n.tr("Outline", "island settings: outlined battery meter style"), I18n.tr("Circle", "island settings: circular battery meter style")]
            currentIndex: Math.max(0, root.styleValues.indexOf(root.page.value("batteryStyle")))
            onSelectionChanged: (index, selected) => {
                if (selected)
                    root.page.set("batteryStyle", root.styleValues[index]);
            }
        }
    }
}
