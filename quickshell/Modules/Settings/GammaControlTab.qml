import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets
import "../../Common/Format.js" as Format

Item {
    id: root

    SettingsPage {
        id: mainColumn

        StyledRect {
            width: parent.width
            height: gammaSection.implicitHeight + Theme.spacingL * 2
            radius: Theme.cornerRadius
            color: Theme.floatingWindowNestedSurface
            border.color: Theme.outlineMedium
            border.width: Theme.layerOutlineWidth

            Column {
                id: gammaSection

                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    leftPadding: Theme.spacingM
                    rightPadding: Theme.spacingM
                    visible: NightModeService.gammaAdjustAvailable

                    SettingsSliderRow {
                        settingKey: "displayGamma"
                        resetStore: SessionData
                        resetKeys: ["displayGamma"]
                        tags: ["gamma", "display", "panel", "washed out", "brightness"]
                        width: parent.width - parent.leftPadding - parent.rightPadding
                        text: I18n.tr("Gamma")
                        minimum: 50
                        maximum: 200
                        step: 5
                        unit: ""
                        decimals: 2
                        value: Math.round(SessionData.displayGamma * 100)
                        onSliderValueChanged: newValue => NightModeService.setDisplayGamma(newValue / 100)
                    }

                    SettingsSliderRow {
                        settingKey: "displayContrast"
                        resetStore: SessionData
                        resetKeys: ["displayContrast"]
                        tags: ["contrast", "display", "panel", "washed out"]
                        width: parent.width - parent.leftPadding - parent.rightPadding
                        text: I18n.tr("Contrast")
                        minimum: 50
                        maximum: 200
                        step: 5
                        unit: "%"
                        value: Math.round(SessionData.displayContrast * 100)
                        onSliderValueChanged: newValue => NightModeService.setDisplayContrast(newValue / 100)
                    }
                }

                DankToggle {
                    id: nightModeToggle

                    width: parent.width
                    text: I18n.tr("Night mode")
                    description: NightModeService.gammaControlAvailable ? "" : I18n.tr("Gamma control not available. Requires DMS API v6+.")
                    checked: NightModeService.nightModeEnabled
                    enabled: NightModeService.gammaControlAvailable
                    onToggled: checked => {
                        NightModeService.toggleNightMode();
                    }

                    Connections {
                        function onNightModeEnabledChanged() {
                            nightModeToggle.checked = NightModeService.nightModeEnabled;
                        }

                        target: NightModeService
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    leftPadding: Theme.spacingM
                    rightPadding: Theme.spacingM
                    visible: NightModeService.gammaControlAvailable

                    SettingsSliderRow {
                        id: nightTempSlider
                        settingKey: "nightModeTemperature"
                        resetStore: SessionData
                        resetKeys: ["nightModeTemperature"]
                        tags: ["gamma", "night", "temperature", "kelvin", "warm", "color", "blue light"]
                        width: parent.width - parent.leftPadding - parent.rightPadding
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
                        id: dayTempSlider
                        settingKey: "nightModeHighTemperature"
                        resetStore: SessionData
                        resetKeys: ["nightModeHighTemperature"]
                        tags: ["gamma", "day", "temperature", "kelvin", "color"]
                        width: parent.width - parent.leftPadding - parent.rightPadding
                        text: I18n.tr("Day temperature")
                        minimum: SessionData.nightModeTemperature
                        maximum: 10000
                        step: 100
                        unit: "K"
                        value: Math.max(SessionData.nightModeHighTemperature, SessionData.nightModeTemperature)
                        visible: SessionData.nightModeAutoEnabled
                        onSliderValueChanged: newValue => SessionData.setNightModeHighTemperature(newValue)
                    }
                }

                DankToggle {
                    id: automaticToggle
                    width: parent.width
                    text: I18n.tr("Automatic control")
                    checked: SessionData.nightModeAutoEnabled
                    visible: NightModeService.gammaControlAvailable
                    onToggled: checked => {
                        if (checked && !NightModeService.nightModeEnabled) {
                            NightModeService.toggleNightMode();
                        } else if (!checked && NightModeService.nightModeEnabled) {
                            NightModeService.toggleNightMode();
                        }
                        SessionData.setNightModeAutoEnabled(checked);
                    }

                    Connections {
                        target: SessionData
                        function onNightModeAutoEnabledChanged() {
                            automaticToggle.checked = SessionData.nightModeAutoEnabled;
                        }
                    }
                }

                Column {
                    id: automaticSettings
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: SessionData.nightModeAutoEnabled && NightModeService.gammaControlAvailable

                    Connections {
                        target: SessionData
                        function onNightModeAutoEnabledChanged() {
                            automaticSettings.visible = SessionData.nightModeAutoEnabled;
                        }
                    }

                    Item {
                        width: parent.width
                        height: modeTabBarNight.height + Theme.spacingM

                        DankTabBar {
                            id: modeTabBarNight
                            width: 200
                            tabHeight: 45
                            anchors.horizontalCenter: parent.horizontalCenter
                            model: [
                                {
                                    "text": I18n.tr("Time"),
                                    "icon": "access_time"
                                },
                                {
                                    "text": I18n.tr("Location"),
                                    "icon": "place"
                                }
                            ]

                            Component.onCompleted: {
                                currentIndex = SessionData.nightModeAutoMode === "location" ? 1 : 0;
                                Qt.callLater(updateIndicator);
                            }

                            onTabClicked: index => {
                                SessionData.setNightModeAutoMode(index === 1 ? "location" : "time");
                                currentIndex = index;
                            }

                            Connections {
                                target: SessionData
                                function onNightModeAutoModeChanged() {
                                    modeTabBarNight.currentIndex = SessionData.nightModeAutoMode === "location" ? 1 : 0;
                                    Qt.callLater(modeTabBarNight.updateIndicator);
                                }
                            }
                        }
                    }

                    SettingsTimeRow {
                        visible: SessionData.nightModeAutoMode === "time"
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
                        width: parent.width
                        text: I18n.tr("Transition duration")
                        minimum: 0
                        maximum: 180
                        step: 5
                        unit: "min"
                        value: SessionData.nightModeTransitionMinutes
                        visible: (SessionData.nightModeAutoMode === "time") && (DMSService.apiVersion >= 32)
                        onSliderValueChanged: newValue => SessionData.setNightModeTransitionMinutes(newValue)
                    }

                    SettingsLocationSection {
                        width: parent.width
                        visible: SessionData.nightModeAutoMode === "location"
                        description: ""
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                        visible: gammaStatusSection.visible
                    }

                    Column {
                        id: gammaStatusSection
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: NightModeService.nightModeEnabled && NightModeService.gammaCurrentTemp > 0

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            DankIcon {
                                name: NightModeService.gammaIsDay ? "light_mode" : "dark_mode"
                                size: Theme.iconSizeSmall
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: I18n.tr("Current status")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Theme.fontWeightMedium
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            Rectangle {
                                width: (parent.width - Theme.spacingM) / 2
                                height: tempColumn.implicitHeight + Theme.spacingM * 2
                                radius: Theme.cornerRadius
                                color: Theme.floatingWindowNestedSurface
                                border.color: Theme.outlineMedium
                                border.width: Theme.layerOutlineWidth

                                Column {
                                    id: tempColumn
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        name: "device_thermostat"
                                        size: Theme.iconSize
                                        color: Theme.primary
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    StyledText {
                                        text: NightModeService.gammaCurrentTemp + "K"
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: Theme.fontWeightMedium
                                        color: Theme.surfaceText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    StyledText {
                                        text: I18n.tr("Current temperature")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            Rectangle {
                                width: (parent.width - Theme.spacingM) / 2
                                height: periodColumn.implicitHeight + Theme.spacingM * 2
                                radius: Theme.cornerRadius
                                color: Theme.floatingWindowNestedSurface
                                border.color: Theme.outlineMedium
                                border.width: Theme.layerOutlineWidth

                                Column {
                                    id: periodColumn
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        name: NightModeService.gammaIsDay ? "wb_sunny" : "nightlight"
                                        size: Theme.iconSize
                                        color: NightModeService.gammaIsDay ? "#FFA726" : "#7E57C2"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    StyledText {
                                        text: NightModeService.gammaIsDay ? I18n.tr("Daytime", "night mode status label, current period is day") : I18n.tr("Night")
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: Theme.fontWeightMedium
                                        color: Theme.surfaceText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    StyledText {
                                        text: I18n.tr("Current period")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM
                            visible: SessionData.nightModeAutoMode === "location" && (NightModeService.gammaSunriseTime || NightModeService.gammaSunsetTime)

                            Rectangle {
                                width: (parent.width - Theme.spacingM) / 2
                                height: sunriseColumn.implicitHeight + Theme.spacingM * 2
                                radius: Theme.cornerRadius
                                color: Theme.floatingWindowNestedSurface
                                border.color: Theme.outlineMedium
                                border.width: Theme.layerOutlineWidth
                                visible: NightModeService.gammaSunriseTime

                                Column {
                                    id: sunriseColumn
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        name: "wb_twilight"
                                        size: Theme.iconSize
                                        color: "#FF7043"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    StyledText {
                                        text: Format.formatIsoTime(NightModeService.gammaSunriseTime)
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: Theme.fontWeightMedium
                                        color: Theme.surfaceText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    StyledText {
                                        text: I18n.tr("Sunrise")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            Rectangle {
                                width: (parent.width - Theme.spacingM) / 2
                                height: sunsetColumn.implicitHeight + Theme.spacingM * 2
                                radius: Theme.cornerRadius
                                color: Theme.floatingWindowNestedSurface
                                border.color: Theme.outlineMedium
                                border.width: Theme.layerOutlineWidth
                                visible: NightModeService.gammaSunsetTime

                                Column {
                                    id: sunsetColumn
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        name: "wb_twilight"
                                        size: Theme.iconSize
                                        color: "#5C6BC0"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    StyledText {
                                        text: Format.formatIsoTime(NightModeService.gammaSunsetTime)
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: Theme.fontWeightMedium
                                        color: Theme.surfaceText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    StyledText {
                                        text: I18n.tr("Sunset")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: nextChangeRow.implicitHeight + Theme.spacingM * 2
                            radius: Theme.cornerRadius
                            color: Theme.floatingWindowNestedSurface
                            border.color: Theme.outlineMedium
                            border.width: Theme.layerOutlineWidth
                            visible: NightModeService.gammaNextTransition

                            Row {
                                id: nextChangeRow
                                anchors.centerIn: parent
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: "schedule"
                                    size: Theme.iconSize
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    spacing: Theme.spacingXXS
                                    anchors.verticalCenter: parent.verticalCenter

                                    StyledText {
                                        text: I18n.tr("Next Transition")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: Format.formatIsoTime(NightModeService.gammaNextTransition)
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Theme.fontWeightMedium
                                        color: Theme.surfaceText
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
