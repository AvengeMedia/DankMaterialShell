import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets
import "../../Common/Format.js" as Format

Item {
    id: root

    property var desktopApps: []
    property var parentModal: null

    function addNightModeExcludedApp() {
        const name = excludeEditor.value.trim();
        if (!name)
            return;
        SettingsData.addNightModeExcludedApp(name);
        excludeEditor.value = "";
    }

    Component.onCompleted: desktopApps = AppSearchService.getVisibleApplications() || []

    component StatusTile: Rectangle {
        id: tile

        property string iconName: ""
        property color iconColor: Theme.primary
        property string value: ""
        property string label: ""

        width: (parent.width - Theme.spacingM) / 2
        height: tileColumn.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: SettingsMetrics.controlColor
        border.color: Theme.floatingWindowFieldBorderColor
        border.width: Theme.outlineWidth

        Column {
            id: tileColumn
            anchors.centerIn: parent
            spacing: Theme.spacingXS

            DankIcon {
                name: tile.iconName
                size: Theme.iconSize
                color: tile.iconColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: tile.value
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: tile.label
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    SettingsPage {
        id: mainColumn

        SettingsCard {
            visible: NightModeService.gammaAdjustAvailable

            SettingsSliderRow {
                settingKey: "displayGamma"
                resetStore: SessionData
                resetKeys: ["displayGamma"]
                tags: ["gamma", "display", "panel", "washed out", "brightness"]
                text: I18n.tr("Gamma")
                minimum: 50
                maximum: 200
                step: 5
                unit: ""
                decimals: 2
                value: Math.round(SessionData.displayGamma * 100)
                onSliderValueChanged: newValue => {
                    NightModeService.setDisplayGamma(newValue / 100);
                }
                onResetRequested: {
                    SessionData.resetToDefault(["displayGamma"]);
                    NightModeService.setDisplayGamma(SessionData.displayGamma);
                }
            }

            SettingsSliderRow {
                settingKey: "displayContrast"
                resetStore: SessionData
                resetKeys: ["displayContrast"]
                tags: ["contrast", "display", "panel", "washed out"]
                text: I18n.tr("Contrast")
                minimum: 50
                maximum: 200
                step: 5
                value: Math.round(SessionData.displayContrast * 100)
                onSliderValueChanged: newValue => NightModeService.setDisplayContrast(newValue / 100)
                onResetRequested: {
                    SessionData.resetToDefault(["displayContrast"]);
                    NightModeService.setDisplayContrast(SessionData.displayContrast);
                }
            }
        }

        SettingsCard {
            SettingsToggleRow {
                text: I18n.tr("Night mode")
                description: NightModeService.gammaControlAvailable ? "" : I18n.tr("Gamma control not available. Requires DMS API v6+.")
                checked: NightModeService.nightModeEnabled
                enabled: NightModeService.gammaControlAvailable
                onToggled: NightModeService.toggleNightMode()
            }

            SettingsSliderRow {
                settingKey: "nightModeTemperature"
                resetStore: SessionData
                resetKeys: ["nightModeTemperature"]
                tags: ["gamma", "night", "temperature", "kelvin", "warm", "color", "blue light"]
                visible: NightModeService.gammaControlAvailable
                text: SessionData.nightModeAutoEnabled ? I18n.tr("Night temperature") : I18n.tr("Color Temperature", "Color Temperature")
                minimum: 1000
                maximum: 6000
                step: 100
                unit: "K"
                value: SessionData.nightModeTemperature
                onSliderValueChanged: newValue => {
                    SessionData.setNightModeTemperature(newValue);
                    if (SessionData.nightModeHighTemperature < newValue)
                        SessionData.setNightModeHighTemperature(newValue);
                }
            }

            SettingsSliderRow {
                settingKey: "nightModeHighTemperature"
                resetStore: SessionData
                resetKeys: ["nightModeHighTemperature"]
                tags: ["gamma", "day", "temperature", "kelvin", "color"]
                visible: NightModeService.gammaControlAvailable && SessionData.nightModeAutoEnabled
                text: I18n.tr("Day temperature")
                minimum: SessionData.nightModeTemperature
                maximum: 10000
                step: 100
                unit: "K"
                value: Math.max(SessionData.nightModeHighTemperature, SessionData.nightModeTemperature)
                onSliderValueChanged: newValue => SessionData.setNightModeHighTemperature(newValue)
            }

            SettingsToggleRow {
                text: I18n.tr("Automatic control")
                checked: SessionData.nightModeAutoEnabled
                visible: NightModeService.gammaControlAvailable
                onToggled: checked => {
                    if (checked !== NightModeService.nightModeEnabled)
                        NightModeService.toggleNightMode();
                    SessionData.setNightModeAutoEnabled(checked);
                }
            }
        }

        SettingsCard {
            visible: SessionData.nightModeAutoEnabled && NightModeService.gammaControlAvailable

            SettingsButtonGroupRow {
                id: autoModeGroup
                readonly property bool locationMode: SessionData.nightModeAutoMode === "location"
                text: I18n.tr("Mode", "noun, setting label, e.g. wallpaper cycling mode, wifi mode, display mode")
                model: [I18n.tr("Time"), I18n.tr("Location")]
                currentIndex: locationMode ? 1 : 0
                onLocationModeChanged: currentIndex = locationMode ? 1 : 0
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    SessionData.setNightModeAutoMode(index === 1 ? "location" : "time");
                }
            }

            SettingsTimeRow {
                visible: !autoModeGroup.locationMode
                is24Hour: SettingsData.use24HourClock
                startTitle: I18n.tr("Start")
                startHour: SessionData.nightModeStartHour
                startMinute: SessionData.nightModeStartMinute
                endTitle: I18n.tr("End", "noun, end time label for night mode schedule or calendar event")
                endHour: SessionData.nightModeEndHour
                endMinute: SessionData.nightModeEndMinute
                onStartChanged: (hour, minute) => {
                    SessionData.setNightModeStartHour(hour);
                    SessionData.setNightModeStartMinute(minute);
                }
                onEndChanged: (hour, minute) => {
                    SessionData.setNightModeEndHour(hour);
                    SessionData.setNightModeEndMinute(minute);
                }
            }

            SettingsSliderRow {
                settingKey: "nightModeTransitionMinutes"
                resetStore: SessionData
                resetKeys: ["nightModeTransitionMinutes"]
                tags: ["gamma", "night", "transition", "duration", "fade"]
                text: I18n.tr("Transition duration")
                minimum: 0
                maximum: 180
                step: 5
                unit: "min"
                value: SessionData.nightModeTransitionMinutes
                visible: !autoModeGroup.locationMode && DMSService.apiVersion >= 32
                onSliderValueChanged: newValue => SessionData.setNightModeTransitionMinutes(newValue)
            }

            SettingsLocationSection {
                visible: autoModeGroup.locationMode
                description: ""
            }
        }

        SettingsCard {
            title: I18n.tr("Current status")
            visible: SessionData.nightModeAutoEnabled && NightModeService.gammaControlAvailable && NightModeService.nightModeEnabled && NightModeService.gammaCurrentTemp > 0

            Column {
                spacing: Theme.spacingM

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    StatusTile {
                        iconName: "device_thermostat"
                        value: NightModeService.gammaCurrentTemp + "K"
                        label: I18n.tr("Current temperature")
                    }

                    StatusTile {
                        iconName: NightModeService.gammaIsDay ? "wb_sunny" : "nightlight"
                        iconColor: NightModeService.gammaIsDay ? Theme.warning : Theme.secondary
                        value: NightModeService.gammaIsDay ? I18n.tr("Daytime", "night mode status label, current period is day") : I18n.tr("Night")
                        label: I18n.tr("Current period")
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: autoModeGroup.locationMode && (NightModeService.gammaSunriseTime || NightModeService.gammaSunsetTime)

                    StatusTile {
                        visible: NightModeService.gammaSunriseTime
                        iconName: "wb_twilight"
                        iconColor: Theme.warning
                        value: Format.formatIsoTime(NightModeService.gammaSunriseTime)
                        label: I18n.tr("Sunrise")
                    }

                    StatusTile {
                        visible: NightModeService.gammaSunsetTime
                        iconName: "wb_twilight"
                        iconColor: Theme.secondary
                        value: Format.formatIsoTime(NightModeService.gammaSunsetTime)
                        label: I18n.tr("Sunset")
                    }
                }
            }

            SettingsRow {
                visible: NightModeService.gammaNextTransition
                iconName: "schedule"
                title: I18n.tr("Next Transition")
                subtitle: Format.formatIsoTime(NightModeService.gammaNextTransition)
            }
        }

        SettingsCard {
            id: exceptionsCard
            iconName: "settings_night_sight"
            title: I18n.tr("Night Mode Exceptions")
            settingKey: "nightModeExceptions"
            tags: ["gamma", "night", "mode", "fullscreen", "app", "media", "exceptions", "exclude", "ignore"]
            visible: NightModeService.gammaControlAvailable
            collapsible: true
            expanded: false

            SettingsToggleRow {
                text: I18n.tr("Fullscreen Applications")
                description: I18n.tr("Pause night mode when focusing a specific app or a fullscreen one.")
                checked: SettingsData.nightModeExcludeFullscreen
                onToggled: checked => {
                    SettingsData.set("nightModeExcludeFullscreen", checked);
                }
            }
        }

        SettingsCard {
            visible: exceptionsCard.visible && exceptionsCard.expanded
            settingKey: "nightModeExceptions"

            SettingsTextFieldRow {
                id: excludeEditor
                leftIconName: "apps"
                text: I18n.tr("Excluded Applications")
                description: I18n.tr("Pause night mode when focusing on specific applications (media player, game, ...)")
                placeholderText: I18n.tr("App name or identity (e.g., GIMP)")
                onAccepted: root.addNightModeExcludedApp()

                actions: [
                    DankIconButton {
                        variant: "filled"
                        iconName: "add"
                        Accessible.name: I18n.tr("Add")
                        enabled: excludeEditor.value.trim() !== ""
                        onClicked: root.addNightModeExcludedApp()
                    },
                    DankIconButton {
                        iconName: "apps"
                        tooltipText: I18n.tr("Browse")
                        onClicked: appBrowserPopup.show()
                    }
                ]
            }

            Repeater {
                model: SettingsData.nightModeExcludedApps

                delegate: SettingsRow {
                    required property string modelData
                    required property int index

                    title: modelData
                    iconName: "bedtime_off"

                    DankActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "delete"
                        iconColor: Theme.error
                        Accessible.name: I18n.tr("Remove")
                        onClicked: SettingsData.removeNightModeExcludedApp(index)
                    }
                }
            }

            SettingsRow {
                visible: !SettingsData.nightModeExcludedApps?.length
                title: I18n.tr("No excluded application configured")
                titleColor: Theme.surfaceVariantText
            }
        }
    }

    AppBrowserPopup {
        id: appBrowserPopup
        appsModel: root.desktopApps
        parentModal: root.parentModal
        onAppSelected: appId => {
            var name = appId;
            if (name.endsWith(".desktop")) {
                name = name.slice(0, -8);
            }
            SettingsData.addNightModeExcludedApp(name);
        }
    }
}
