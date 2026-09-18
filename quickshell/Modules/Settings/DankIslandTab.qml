pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets
import qs.Services
import qs.Widgets

Item {
    id: root

    property var parentModal: null
    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    BarSelectionState {
        id: bar
    }

    readonly property string selectedIslandId: bar.selectedBarIsIsland ? bar.selectedBarId : ""
    readonly property var config: bar.selectedBarConfig
    readonly property bool islandEnabled: bar.selectedBarIsIsland && (bar.selectedBarConfig?.enabled ?? false)

    readonly property var clockDisplayValues: ["time", "date", "both"]
    readonly property var systemLevelDisplayValues: ["icon", "percentage", "both"]
    readonly property var statusContentValues: ["battery", "connectivity"]
    readonly property var satellitePositionValues: ["island", "edges"]

    function valueIndex(values, value, fallback) {
        const index = values.indexOf(value);
        return index >= 0 ? index : Math.max(0, values.indexOf(fallback));
    }

    SettingsPage {
        id: mainColumn

        SettingsCard {
            width: parent.width
            iconName: "home"
            title: I18n.tr("Home compact", "island settings: home face card title")
            settingKey: "islandActivities"
            visible: root.islandEnabled

            IslandHomeLayoutEditor {
                width: parent.width
                barId: root.selectedIslandId
            }

            SettingsButtonGroupRow {
                settingKey: "islandHomeClockDisplay"
                tags: ["island", "home", "compact", "clock", "time", "date"]
                resetStore: bar
                resetKeys: ["islandHomeClockDisplay"]
                text: I18n.tr("Clock style", "island settings: clock display mode row")
                model: [I18n.tr("Time", "island settings: clock shows time only"), I18n.tr("Date", "island settings: clock shows date only"), I18n.tr("Both", "island settings: clock shows time and date")]
                currentIndex: root.valueIndex(root.clockDisplayValues, bar.islandSetting("islandHomeClockDisplay"), "both")
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        bar.apply("islandHomeClockDisplay", root.clockDisplayValues[index] ?? "both");
                }
            }

            SettingsButtonGroupRow {
                settingKey: "islandHomeVolumeDisplay"
                tags: ["island", "home", "compact", "volume", "icon", "percentage"]
                resetStore: bar
                resetKeys: ["islandHomeVolumeDisplay"]
                text: I18n.tr("Volume style", "island settings: volume display mode row")
                visible: SettingsData.islandHomeGroupEnabled(root.config, "volume")
                model: [I18n.tr("Icon", "island settings: level shown as icon only"), I18n.tr("Percentage", "island settings: level shown as percentage only"), I18n.tr("Both", "island settings: level shown as icon and percentage")]
                currentIndex: root.valueIndex(root.systemLevelDisplayValues, bar.islandSetting("islandHomeVolumeDisplay"), "both")
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        bar.apply("islandHomeVolumeDisplay", root.systemLevelDisplayValues[index] ?? "both");
                }
            }

            SettingsButtonGroupRow {
                settingKey: "islandHomeBrightnessDisplay"
                tags: ["island", "home", "compact", "brightness", "icon", "percentage"]
                resetStore: bar
                resetKeys: ["islandHomeBrightnessDisplay"]
                text: I18n.tr("Brightness style", "island settings: brightness display mode row")
                visible: SettingsData.islandHomeGroupEnabled(root.config, "brightness")
                model: [I18n.tr("Icon", "island settings: level shown as icon only"), I18n.tr("Percentage", "island settings: level shown as percentage only"), I18n.tr("Both", "island settings: level shown as icon and percentage")]
                currentIndex: root.valueIndex(root.systemLevelDisplayValues, bar.islandSetting("islandHomeBrightnessDisplay"), "both")
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        bar.apply("islandHomeBrightnessDisplay", root.systemLevelDisplayValues[index] ?? "both");
                }
            }

            SettingsButtonGroupRow {
                settingKey: "islandHomeStatusContent"
                tags: ["island", "home", "compact", "status", "battery", "wifi", "bluetooth", "connectivity"]
                text: I18n.tr("Control Center", "island settings: status group content row")
                visible: SettingsData.islandHomeGroupEnabled(root.config, "status")
                model: [I18n.tr("Battery", "island settings: status group battery content"), I18n.tr("Wi-Fi & Bluetooth", "island settings: status group connectivity content")]
                currentIndex: root.valueIndex(root.statusContentValues, SettingsData.islandHomeStatusContent(root.config), "battery")
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        bar.apply("islandHomeStatusContent", root.statusContentValues[index] ?? "battery");
                }
            }

            SettingsToggleRow {
                settingKey: "islandHomeCompactTight"
                tags: ["island", "home", "compact", "narrow", "width", "height", "clock"]
                resetStore: bar
                resetKeys: ["islandHomeCompactTight"]
                text: I18n.tr("Compact pill", "island settings: tighter home pill toggle")
                checked: bar.islandSetting("islandHomeCompactTight")
                onToggled: checked => bar.apply("islandHomeCompactTight", checked)
            }

            SettingsRow {
                body: Flow {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankButton {
                        text: I18n.tr("Launcher", "island settings: button to launcher tab")
                        iconName: "grid_view"
                        onClicked: {
                            if (!root.parentModal)
                                return;
                            SettingsSearchService.navigateToSection("launcherStyle");
                            root.parentModal.navigateTo("launcher");
                        }
                    }

                    DankButton {
                        text: I18n.tr("Time & weather", "island settings: button to weather tab")
                        iconName: "cloud"
                        onClicked: {
                            if (!root.parentModal)
                                return;
                            SettingsSearchService.navigateToSection("weatherEnabled");
                            root.parentModal.navigateTo("time_weather");
                        }
                    }
                }
            }
        }

        SettingsCard {
            width: parent.width
            iconName: "notifications"
            title: I18n.tr("Notifications", "island settings: notifications card title")
            settingKey: "islandNotifications"
            visible: root.islandEnabled

            SettingsToggleRow {
                settingKey: "islandNotificationPopups"
                tags: ["island", "notifications", "popup", "standard", "bar", "stack", "arrival"]
                resetStore: bar
                resetKeys: ["islandNotificationPopups"]
                text: I18n.tr("Use standard popups", "island settings: show arriving notifications as stacked popups instead of in the island")
                checked: bar.islandSetting("islandNotificationPopups")
                onToggled: checked => bar.apply("islandNotificationPopups", checked)
            }

            SettingsToggleRow {
                settingKey: "islandNotificationExpand"
                tags: ["island", "notifications", "expand", "arrival", "size"]
                resetStore: bar
                resetKeys: ["islandNotificationExpand"]
                text: I18n.tr("Expand by default", "island settings: expanded notification toggle")
                checked: bar.islandSetting("islandNotificationExpand")
                onToggled: checked => bar.apply("islandNotificationExpand", checked)
            }

            SettingsToggleRow {
                settingKey: "islandNotificationBadgeClearOnOpen"
                tags: ["island", "home", "notifications", "badge", "unread", "clear", "dismiss", "open"]
                resetStore: bar
                resetKeys: ["islandNotificationBadgeClearOnOpen"]
                text: I18n.tr("Clear badge on open", "island settings: clear the notification badge when the center opens")
                checked: bar.islandSetting("islandNotificationBadgeClearOnOpen")
                enabled: SettingsData.islandHomeGroupEnabled(root.config, "notifications")
                onToggled: checked => bar.apply("islandNotificationBadgeClearOnOpen", checked)
            }
        }

        SettingsCard {
            width: parent.width
            iconName: "widgets"
            title: I18n.tr("Satellites", "island settings: satellite widgets card title")
            settingKey: "islandSatellites"
            collapsible: true
            expanded: true
            visible: root.islandEnabled

            SettingsToggleRow {
                settingKey: "islandSatellitesEnabled"
                tags: ["island", "satellite", "widgets", "left", "right"]
                resetStore: bar
                resetKeys: ["islandSatellitesEnabled"]
                text: I18n.tr("Show", "island settings: satellite widgets toggle")
                checked: bar.islandSetting("islandSatellitesEnabled")
                onToggled: checked => bar.apply("islandSatellitesEnabled", checked)
            }

            SettingsButtonGroupRow {
                settingKey: "islandSatellitePosition"
                tags: ["island", "satellite", "widgets", "position", "edges", "center"]
                resetStore: bar
                resetKeys: ["islandSatellitePosition"]
                text: I18n.tr("Position", "island settings: position card title")
                model: [I18n.tr("Near island", "island settings: satellites hug the island"), I18n.tr("Display edges", "island settings: satellites sit at screen edges")]
                currentIndex: root.valueIndex(root.satellitePositionValues, bar.islandSetting("islandSatellitePosition"), "island")
                enabled: bar.islandSetting("islandSatellitesEnabled")
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        bar.apply("islandSatellitePosition", root.satellitePositionValues[index] ?? "island");
                }
            }

            SettingsToggleRow {
                settingKey: "islandSatelliteBackground"
                tags: ["island", "satellite", "widgets", "background", "chrome"]
                resetStore: bar
                resetKeys: ["islandSatelliteBackground"]
                text: I18n.tr("Background", "island settings: satellite background toggle")
                checked: bar.islandSetting("islandSatelliteBackground")
                visible: bar.islandSetting("islandSatellitesEnabled")
                onToggled: checked => bar.apply("islandSatelliteBackground", checked)
            }

            SettingsToggleRow {
                settingKey: "islandSatelliteGothCorners"
                tags: ["island", "satellite", "goth", "corners", "wing", "sweep"]
                resetStore: bar
                resetKeys: ["islandSatelliteGothCorners"]
                text: I18n.tr("Goth corners", "island settings: satellite goth corners toggle")
                checked: bar.islandSetting("islandSatelliteGothCorners")
                visible: bar.islandSetting("islandSatellitesEnabled")
                enabled: bar.islandSetting("islandSatelliteBackground")
                onToggled: checked => bar.apply("islandSatelliteGothCorners", checked)
            }

            SettingsSliderRow {
                settingKey: "islandSatelliteSwoopRadius"
                tags: ["island", "satellite", "goth", "corners", "radius", "sweep", "size"]
                resetStore: bar
                resetKeys: ["islandSatelliteSwoopRadius"]
                text: I18n.tr("Goth corner radius", "island settings: satellite goth corner radius slider")
                unit: "px"
                minimum: 4
                maximum: 64
                step: 1
                value: bar.islandSetting("islandSatelliteSwoopRadius")
                visible: bar.islandSetting("islandSatellitesEnabled")
                enabled: bar.islandSetting("islandSatelliteBackground") && bar.islandSetting("islandSatelliteGothCorners")
                onSliderValueChanged: value => bar.apply("islandSatelliteSwoopRadius", value)
            }

            SettingsSliderRow {
                settingKey: "islandSatelliteTransparency"
                tags: ["island", "satellite", "background", "opacity", "transparency", "blur"]
                resetStore: bar
                resetKeys: ["islandSatelliteTransparency"]
                text: I18n.tr("Opacity", "island settings: satellite background opacity slider")
                minimum: 0
                maximum: 100
                step: 1
                value: Math.round(bar.islandSetting("islandSatelliteTransparency") * 100)
                visible: bar.islandSetting("islandSatellitesEnabled")
                enabled: bar.islandSetting("islandSatelliteBackground")
                onSliderValueChanged: value => bar.apply("islandSatelliteTransparency", value / 100)
            }

            SettingsSliderRow {
                settingKey: "islandSatelliteGap"
                tags: ["island", "satellite", "widgets", "gap", "spacing"]
                resetStore: bar
                resetKeys: ["islandSatelliteGap"]
                text: I18n.tr("Gap", "island settings: satellite to island gap slider")
                unit: "px"
                minimum: 4
                maximum: 48
                step: 1
                value: bar.islandSetting("islandSatelliteGap")
                visible: bar.islandSetting("islandSatellitesEnabled")
                enabled: bar.islandSetting("islandSatellitePosition") !== "edges"
                onSliderValueChanged: value => bar.apply("islandSatelliteGap", value)
            }
        }
    }
}
