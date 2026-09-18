import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    property var parentModal: null
    readonly property var coordinates: SettingsData.weatherCoordinates.split(",")
    readonly property bool validCoordinates: latitude.text.trim() !== "" && longitude.text.trim() !== "" && Number.isFinite(Number(latitude.text)) && Number.isFinite(Number(longitude.text)) && Math.abs(Number(latitude.text)) <= 90 && Math.abs(Number(longitude.text)) <= 180

    function saveCoordinates() {
        if (!validCoordinates)
            return;
        SettingsData.setWeatherLocation("", Number(latitude.text) + "," + Number(longitude.text));
    }

    SettingsPage {
        SettingsCard {
            title: I18n.tr("Weather")
            tab: "weather"
            settingKey: "weather"

            SettingsToggleRow {
                tab: "weather"
                settingKey: "weatherEnabled"
                tags: ["weather", "enable", "forecast"]
                text: I18n.tr("Weather")
                checked: SettingsData.weatherEnabled
                onToggled: checked => SettingsData.set("weatherEnabled", checked)
            }

            SettingsToggleRow {
                tab: "weather"
                settingKey: "useFahrenheit"
                tags: ["weather", "imperial", "fahrenheit", "celsius", "units", "mph"]
                text: I18n.tr("Imperial units")
                checked: SettingsData.useFahrenheit
                onToggled: checked => SettingsData.set("useFahrenheit", checked)
            }

            SettingsToggleRow {
                enabled: !SettingsData.useFahrenheit
                tab: "weather"
                settingKey: "windSpeedUnit"
                tags: ["weather", "wind", "speed", "units", "metric"]
                text: I18n.tr("Wind speed in m/s")
                checked: SettingsData.windSpeedUnit === "ms"
                onToggled: checked => SettingsData.set("windSpeedUnit", checked ? "ms" : "kmh")
            }
        }

        SettingsCard {
            title: I18n.tr("Location")
            tab: "weather"
            settingKey: "weatherLocation"
            tags: ["weather", "location", "city", "coordinates"]

            SettingsToggleRow {
                tab: "weather"
                settingKey: "useAutoLocation"
                tags: ["weather", "location", "auto", "gps", "ip"]
                text: I18n.tr("Auto location")
                checked: SettingsData.useAutoLocation
                onToggled: checked => SettingsData.set("useAutoLocation", checked)
            }

            SettingsRow {
                enabled: !SettingsData.useAutoLocation
                title: I18n.tr("Location search")
                body: DankLocationSearch {
                    width: parent.width
                    currentLocation: SettingsData.weatherLocation
                    placeholderText: I18n.tr("New York, NY")
                    onLocationSelected: (displayName, coordinates) => SettingsData.setWeatherLocation(displayName, coordinates)
                }
            }

            SettingsRow {
                enabled: !SettingsData.useAutoLocation
                title: I18n.tr("Custom location")
                body: Column {
                    width: parent.width
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankTextField {
                            id: latitude
                            outlined: true
                            leftIconName: "location_on"
                            width: (parent.width - parent.spacing) / 2
                            labelText: I18n.tr("Latitude", "weather location coordinate text field label")
                            text: root.coordinates[0]?.trim() ?? ""
                            keyNavigationTab: longitude
                            onAccepted: root.saveCoordinates()
                        }

                        DankTextField {
                            id: longitude
                            outlined: true
                            leftIconName: "location_on"
                            width: (parent.width - parent.spacing) / 2
                            labelText: I18n.tr("Longitude", "weather location coordinate text field label")
                            text: root.coordinates[1]?.trim() ?? ""
                            keyNavigationBacktab: latitude
                            onAccepted: root.saveCoordinates()
                        }
                    }

                    DankButton {
                        text: I18n.tr("Apply", "verb, button that saves custom weather coordinates")
                        enabled: root.validCoordinates
                        onClicked: root.saveCoordinates()
                    }
                }
            }
        }

        SettingsCard {
            title: I18n.tr("Display")
            tab: "weather"
            settingKey: "weatherDisplay"

            SettingsToggleRow {
                tab: "weather"
                settingKey: "lockScreenShowWeather"
                tags: ["weather", "lock", "screen"]
                text: I18n.tr("Lock screen")
                checked: SettingsData.lockScreenShowWeather
                onToggled: checked => SettingsData.set("lockScreenShowWeather", checked)
            }

            SettingsNavRow {
                title: I18n.tr("Dashboard")
                iconName: "space_dashboard"
                onClicked: root.parentModal?.navigateTo("dank_dash")
            }

            SettingsNavRow {
                title: I18n.tr("Bar widgets")
                iconName: "widgets"
                onClicked: root.parentModal?.navigateTo("dankbar_widgets")
            }
        }
    }
}
