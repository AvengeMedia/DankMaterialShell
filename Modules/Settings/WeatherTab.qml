import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Item {
    id: weatherTab

    DankFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn

            width: parent.width
            spacing: Theme.spacingXL

            // Enable Weather
            StyledRect {
                width: parent.width
                height: enableWeatherSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: enableWeatherSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "cloud"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                                   - enableToggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Enable Weather")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Show weather information in top bar and control center")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: enableToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.weatherEnabled
                            onToggled: checked => {
                                           return SettingsData.setWeatherEnabled(
                                               checked)
                                       }
                        }
                    }
                }
            }

            // Temperature Unit
            StyledRect {
                width: parent.width
                height: temperatureSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0
                visible: SettingsData.weatherEnabled
                opacity: visible ? 1 : 0

                Column {
                    id: temperatureSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "thermostat"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                                   - temperatureToggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Use Fahrenheit")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Use Fahrenheit instead of Celsius for temperature")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: temperatureToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.useFahrenheit
                            onToggled: checked => {
                                           return SettingsData.setTemperatureUnit(
                                               checked)
                                       }
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
            }

            // Location Settings
            StyledRect {
                width: parent.width
                height: locationSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0
                visible: SettingsData.weatherEnabled
                opacity: visible ? 1 : 0

                Column {
                    id: locationSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "location_on"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                                   - autoLocationToggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Auto Location")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Automatically determine your location using your IP address")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: autoLocationToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.useAutoLocation
                            onToggled: checked => {
                                           return SettingsData.setAutoLocation(
                                               checked)
                                       }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: !SettingsData.useAutoLocation

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outline
                            opacity: 0.2
                        }

                        StyledText {
                            text: I18n.tr("Custom Location")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        Row {
                                width: parent.width
                                spacing: Theme.spacingM

                                Column {
                                    width: (parent.width - Theme.spacingM) / 2
                                    spacing: Theme.spacingXS

                                    StyledText {
                                        text: I18n.tr("Latitude")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    DankTextField {
                                        id: latitudeInput
                                        width: parent.width
                                        height: 48
                                        placeholderText: "40.7128"
                                        backgroundColor: Theme.surfaceVariant
                                        normalBorderColor: Theme.primarySelected
                                        focusedBorderColor: Theme.primary
                                        keyNavigationTab: longitudeInput

                                        Component.onCompleted: {
                                            if (SettingsData.weatherCoordinates) {
                                                const coords = SettingsData.weatherCoordinates.split(',')
                                                if (coords.length > 0) {
                                                    text = coords[0].trim()
                                                }
                                            }
                                        }

                                        Connections {
                                            target: SettingsData
                                            function onWeatherCoordinatesChanged() {
                                                if (SettingsData.weatherCoordinates) {
                                                    const coords = SettingsData.weatherCoordinates.split(',')
                                                    if (coords.length > 0) {
                                                        latitudeInput.text = coords[0].trim()
                                                    }
                                                }
                                            }
                                        }

                                        onTextEdited: {
                                            if (text && longitudeInput.text) {
                                                const coords = text + "," + longitudeInput.text
                                                SettingsData.weatherCoordinates = coords
                                                SettingsData.saveSettings()
                                            }
                                        }
                                    }
                                }

                                Column {
                                    width: (parent.width - Theme.spacingM) / 2
                                    spacing: Theme.spacingXS

                                    StyledText {
                                        text: I18n.tr("Longitude")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    DankTextField {
                                        id: longitudeInput
                                        width: parent.width
                                        height: 48
                                        placeholderText: "-74.0060"
                                        backgroundColor: Theme.surfaceVariant
                                        normalBorderColor: Theme.primarySelected
                                        focusedBorderColor: Theme.primary
                                        keyNavigationTab: locationSearchInput
                                        keyNavigationBacktab: latitudeInput

                                        Component.onCompleted: {
                                            if (SettingsData.weatherCoordinates) {
                                                const coords = SettingsData.weatherCoordinates.split(',')
                                                if (coords.length > 1) {
                                                    text = coords[1].trim()
                                                }
                                            }
                                        }

                                        Connections {
                                            target: SettingsData
                                            function onWeatherCoordinatesChanged() {
                                                if (SettingsData.weatherCoordinates) {
                                                    const coords = SettingsData.weatherCoordinates.split(',')
                                                    if (coords.length > 1) {
                                                        longitudeInput.text = coords[1].trim()
                                                    }
                                                }
                                            }
                                        }

                                        onTextEdited: {
                                            if (text && latitudeInput.text) {
                                                const coords = latitudeInput.text + "," + text
                                                SettingsData.weatherCoordinates = coords
                                                SettingsData.saveSettings()
                                            }
                                        }
                                    }
                                }
                            }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Location Search")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                font.weight: Font.Medium
                            }

                            DankLocationSearch {
                                id: locationSearchInput
                                width: parent.width
                                currentLocation: ""
                                placeholderText: I18n.tr("New York, NY")
                                keyNavigationBacktab: longitudeInput
                                onLocationSelected: (displayName, coordinates) => {
                                                        SettingsData.setWeatherLocation(displayName, coordinates)

                                                        const coords = coordinates.split(',')
                                                        if (coords.length >= 2) {
                                                            latitudeInput.text = coords[0].trim()
                                                            longitudeInput.text = coords[1].trim()
                                                        }
                                                    }
                            }
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
            }
        }
    }
}
