import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

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

            StyledRect {
                width: parent.width
                height: timeSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: timeSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "schedule"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                                   - toggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("24-Hour Format")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Use 24-hour time format instead of 12-hour AM/PM")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: toggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.use24HourClock
                            onToggled: checked => {
                                           return SettingsData.set("use24HourClock",
                                               checked)
                                       }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: timeSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: secondsSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "schedule"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                                   - toggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Show seconds")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Clock show seconds")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: toggleSec

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.showSeconds
                            onToggled: checked => {
                                           return SettingsData.set("showSeconds",
                                               checked)
                                       }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: dateSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: dateSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "calendar_today"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Date Format")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankDropdown {
                        height: 50
                        text: I18n.tr("Top Bar Format")
                        description: "Preview: " + (SettingsData.clockDateFormat ? new Date().toLocaleDateString(Qt.locale(), SettingsData.clockDateFormat) : new Date().toLocaleDateString(Qt.locale(), "ddd d"))
                        currentValue: {
                            if (!SettingsData.clockDateFormat || SettingsData.clockDateFormat.length === 0) {
                                return "System Default"
                            }
                            const presets = [{
                                                 "format": "ddd d",
                                                 "label": "Day Date"
                                             }, {
                                                 "format": "ddd MMM d",
                                                 "label": "Day Month Date"
                                             }, {
                                                 "format": "MMM d",
                                                 "label": "Month Date"
                                             }, {
                                                 "format": "M/d",
                                                 "label": "Numeric (M/D)"
                                             }, {
                                                 "format": "d/M",
                                                 "label": "Numeric (D/M)"
                                             }, {
                                                 "format": "ddd d MMM yyyy",
                                                 "label": "Full with Year"
                                             }, {
                                                 "format": "yyyy-MM-dd",
                                                 "label": "ISO Date"
                                             }, {
                                                 "format": "dddd, MMMM d",
                                                 "label": "Full Day & Month"
                                             }]
                            const match = presets.find(p => {
                                                           return p.format
                                                           === SettingsData.clockDateFormat
                                                       })
                            return match ? match.label: I18n.tr("Custom: ") + SettingsData.clockDateFormat
                        }
                        options: ["System Default", "Day Date", "Day Month Date", "Month Date", "Numeric (M/D)", "Numeric (D/M)", "Full with Year", "ISO Date", "Full Day & Month", "Custom..."]
                        onValueChanged: value => {
                                            const formatMap = {
                                                "System Default": "",
                                                "Day Date": "ddd d",
                                                "Day Month Date": "ddd MMM d",
                                                "Month Date": "MMM d",
                                                "Numeric (M/D)": "M/d",
                                                "Numeric (D/M)": "d/M",
                                                "Full with Year": "ddd d MMM yyyy",
                                                "ISO Date": "yyyy-MM-dd",
                                                "Full Day & Month": "dddd, MMMM d"
                                            }
                                            if (value === "Custom...") {
                                                customFormatInput.visible = true
                                            } else {
                                                customFormatInput.visible = false
                                                SettingsData.set("clockDateFormat", 
                                                    formatMap[value])
                                            }
                                        }
                    }

                    DankDropdown {
                        height: 50
                        text: I18n.tr("Lock Screen Format")
                        description: "Preview: " + (SettingsData.lockDateFormat ? new Date().toLocaleDateString(Qt.locale(), SettingsData.lockDateFormat) : new Date().toLocaleDateString(Qt.locale(), Locale.LongFormat))
                        currentValue: {
                            if (!SettingsData.lockDateFormat || SettingsData.lockDateFormat.length === 0) {
                                return "System Default"
                            }
                            const presets = [{
                                                 "format": "ddd d",
                                                 "label": "Day Date"
                                             }, {
                                                 "format": "ddd MMM d",
                                                 "label": "Day Month Date"
                                             }, {
                                                 "format": "MMM d",
                                                 "label": "Month Date"
                                             }, {
                                                 "format": "M/d",
                                                 "label": "Numeric (M/D)"
                                             }, {
                                                 "format": "d/M",
                                                 "label": "Numeric (D/M)"
                                             }, {
                                                 "format": "ddd d MMM yyyy",
                                                 "label": "Full with Year"
                                             }, {
                                                 "format": "yyyy-MM-dd",
                                                 "label": "ISO Date"
                                             }, {
                                                 "format": "dddd, MMMM d",
                                                 "label": "Full Day & Month"
                                             }]
                            const match = presets.find(p => {
                                                           return p.format
                                                           === SettingsData.lockDateFormat
                                                       })
                            return match ? match.label: I18n.tr("Custom: ") + SettingsData.lockDateFormat
                        }
                        options: ["System Default", "Day Date", "Day Month Date", "Month Date", "Numeric (M/D)", "Numeric (D/M)", "Full with Year", "ISO Date", "Full Day & Month", "Custom..."]
                        onValueChanged: value => {
                                            const formatMap = {
                                                "System Default": "",
                                                "Day Date": "ddd d",
                                                "Day Month Date": "ddd MMM d",
                                                "Month Date": "MMM d",
                                                "Numeric (M/D)": "M/d",
                                                "Numeric (D/M)": "d/M",
                                                "Full with Year": "ddd d MMM yyyy",
                                                "ISO Date": "yyyy-MM-dd",
                                                "Full Day & Month": "dddd, MMMM d"
                                            }
                                            if (value === "Custom...") {
                                                customLockFormatInput.visible = true
                                            } else {
                                                customLockFormatInput.visible = false
                                                SettingsData.set("lockDateFormat", 
                                                    formatMap[value])
                                            }
                                        }
                    }

                    DankTextField {
                        id: customFormatInput

                        width: parent.width
                        visible: false
                        placeholderText: I18n.tr("Enter custom top bar format (e.g., ddd MMM d)")
                        text: SettingsData.clockDateFormat
                        onTextChanged: {
                            if (visible && text)
                                SettingsData.set("clockDateFormat", text)
                        }
                    }

                    DankTextField {
                        id: customLockFormatInput

                        width: parent.width
                        visible: false
                        placeholderText: I18n.tr("Enter custom lock screen format (e.g., dddd, MMMM d)")
                        text: SettingsData.lockDateFormat
                        onTextChanged: {
                            if (visible && text)
                                SettingsData.set("lockDateFormat", text)
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: formatHelp.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                              Theme.outline.b, 0.1)
                        border.width: 0

                        Column {
                            id: formatHelp

                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Format Legend")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.primary
                                font.weight: Font.Medium
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingL

                                Column {
                                    width: (parent.width - Theme.spacingL) / 2
                                    spacing: 2

                                    StyledText {
                                        text: I18n.tr("• d - Day (1-31)")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: I18n.tr("• dd - Day (01-31)")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: I18n.tr("• ddd - Day name (Mon)")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: I18n.tr("• dddd - Day name (Monday)")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: I18n.tr("• M - Month (1-12)")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }
                                }

                                Column {
                                    width: (parent.width - Theme.spacingL) / 2
                                    spacing: 2

                                    StyledText {
                                        text: I18n.tr("• MM - Month (01-12)")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: I18n.tr("• MMM - Month (Jan)")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: I18n.tr("• MMMM - Month (January)")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: I18n.tr("• yy - Year (24)")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: I18n.tr("• yyyy - Year (2024)")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: enableWeatherSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
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
                                           return SettingsData.set("weatherEnabled", 
                                               checked)
                                       }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: temperatureSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
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
                                           return SettingsData.set("temperatureUnit", 
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

            StyledRect {
                width: parent.width
                height: locationSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
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
                                           return SettingsData.set("autoLocation", 
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

            StyledRect {
                width: parent.width
                height: weatherDisplaySection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0
                visible: SettingsData.weatherEnabled
                opacity: visible ? 1 : 0

                Column {
                    id: weatherDisplaySection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "visibility"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Current Weather")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingL
                        visible: !WeatherService.weather.available || WeatherService.weather.temp === 0

                        DankIcon {
                            name: "cloud_off"
                            size: Theme.iconSize * 2
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: I18n.tr("No Weather Data Available")
                            font.pixelSize: Theme.fontSizeLarge
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: WeatherService.weather.available && WeatherService.weather.temp !== 0

                        Item {
                            width: parent.width
                            height: 70

                            DankIcon {
                                id: refreshButton
                                name: "refresh"
                                size: Theme.iconSize - 4
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                                anchors.right: parent.right
                                anchors.top: parent.top

                                property bool isRefreshing: false
                                enabled: !isRefreshing

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                    onClicked: {
                                        refreshButton.isRefreshing = true
                                        WeatherService.forceRefresh()
                                        refreshTimer.restart()
                                    }
                                    enabled: parent.enabled
                                }

                                Timer {
                                    id: refreshTimer
                                    interval: 2000
                                    onTriggered: refreshButton.isRefreshing = false
                                }

                                NumberAnimation on rotation {
                                    running: refreshButton.isRefreshing
                                    from: 0
                                    to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                }
                            }

                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                width: weatherIcon.width + tempColumn.width + sunriseColumn.width + Theme.spacingM * 2
                                height: 70

                                DankIcon {
                                    id: weatherIcon
                                    name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                                    size: Theme.iconSize * 1.5
                                    color: Theme.primary
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter

                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        shadowEnabled: true
                                        shadowHorizontalOffset: 0
                                        shadowVerticalOffset: 4
                                        shadowBlur: 0.8
                                        shadowColor: Qt.rgba(0, 0, 0, 0.2)
                                        shadowOpacity: 0.2
                                    }
                                }

                                Column {
                                    id: tempColumn
                                    spacing: Theme.spacingXS
                                    anchors.left: weatherIcon.right
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter

                                    Item {
                                        width: tempText.width + unitText.width + Theme.spacingXS
                                        height: tempText.height

                                        StyledText {
                                            id: tempText
                                            text: (SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp) + "°"
                                            font.pixelSize: Theme.fontSizeLarge + 4
                                            color: Theme.surfaceText
                                            font.weight: Font.Light
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            id: unitText
                                            text: SettingsData.useFahrenheit ? "F" : "C"
                                            font.pixelSize: Theme.fontSizeMedium
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                            anchors.left: tempText.right
                                            anchors.leftMargin: Theme.spacingXS
                                            anchors.verticalCenter: parent.verticalCenter

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (WeatherService.weather.available) {
                                                        SettingsData.set("temperatureUnit", !SettingsData.useFahrenheit)
                                                    }
                                                }
                                                enabled: WeatherService.weather.available
                                            }
                                        }
                                    }

                                    StyledText {
                                        text: WeatherService.weather.city || ""
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                        visible: text.length > 0
                                    }
                                }

                                Column {
                                    id: sunriseColumn
                                    spacing: Theme.spacingXS
                                    anchors.left: tempColumn.right
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: WeatherService.weather.sunrise && WeatherService.weather.sunset

                                    Item {
                                        width: sunriseIcon.width + sunriseText.width + Theme.spacingXS
                                        height: sunriseIcon.height

                                        DankIcon {
                                            id: sunriseIcon
                                            name: "wb_twilight"
                                            size: Theme.iconSize - 6
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            id: sunriseText
                                            text: WeatherService.weather.sunrise || ""
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                            anchors.left: sunriseIcon.right
                                            anchors.leftMargin: Theme.spacingXS
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Item {
                                        width: sunsetIcon.width + sunsetText.width + Theme.spacingXS
                                        height: sunsetIcon.height

                                        DankIcon {
                                            id: sunsetIcon
                                            name: "bedtime"
                                            size: Theme.iconSize - 6
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            id: sunsetText
                                            text: WeatherService.weather.sunset || ""
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                            anchors.left: sunsetIcon.right
                                            anchors.leftMargin: Theme.spacingXS
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                        }

                        GridLayout {
                            width: parent.width
                            height: 95
                            columns: 6
                            columnSpacing: Theme.spacingS
                            rowSpacing: 0

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "device_thermostat"
                                            size: Theme.iconSize - 4
                                            color: Theme.primary
                                        }
                                    }

                                    Column {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 2

                                        StyledText {
                                            text: I18n.tr("Feels Like")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                        StyledText {
                                            text: (SettingsData.useFahrenheit ? (WeatherService.weather.feelsLikeF || WeatherService.weather.tempF) : (WeatherService.weather.feelsLike || WeatherService.weather.temp)) + "°"
                                            font.pixelSize: Theme.fontSizeSmall + 1
                                            color: Theme.surfaceText
                                            font.weight: Font.Medium
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "humidity_low"
                                            size: Theme.iconSize - 4
                                            color: Theme.primary
                                        }
                                    }

                                    Column {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 2

                                        StyledText {
                                            text: I18n.tr("Humidity")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                        StyledText {
                                            text: WeatherService.weather.humidity ? WeatherService.weather.humidity + "%" : "--"
                                            font.pixelSize: Theme.fontSizeSmall + 1
                                            color: Theme.surfaceText
                                            font.weight: Font.Medium
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "air"
                                            size: Theme.iconSize - 4
                                            color: Theme.primary
                                        }
                                    }

                                    Column {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 2

                                        StyledText {
                                            text: I18n.tr("Wind")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                        StyledText {
                                            text: WeatherService.weather.wind || "--"
                                            font.pixelSize: Theme.fontSizeSmall + 1
                                            color: Theme.surfaceText
                                            font.weight: Font.Medium
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "speed"
                                            size: Theme.iconSize - 4
                                            color: Theme.primary
                                        }
                                    }

                                    Column {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 2

                                        StyledText {
                                            text: I18n.tr("Pressure")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                        StyledText {
                                            text: WeatherService.weather.pressure ? WeatherService.weather.pressure + " hPa" : "--"
                                            font.pixelSize: Theme.fontSizeSmall + 1
                                            color: Theme.surfaceText
                                            font.weight: Font.Medium
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "rainy"
                                            size: Theme.iconSize - 4
                                            color: Theme.primary
                                        }
                                    }

                                    Column {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 2

                                        StyledText {
                                            text: I18n.tr("Rain Chance")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                        StyledText {
                                            text: WeatherService.weather.precipitationProbability ? WeatherService.weather.precipitationProbability + "%" : "0%"
                                            font.pixelSize: Theme.fontSizeSmall + 1
                                            color: Theme.surfaceText
                                            font.weight: Font.Medium
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "wb_sunny"
                                            size: Theme.iconSize - 4
                                            color: Theme.primary
                                        }
                                    }

                                    Column {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 2

                                        StyledText {
                                            text: I18n.tr("Visibility")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                        StyledText {
                                            text: I18n.tr("Good")
                                            font.pixelSize: Theme.fontSizeSmall + 1
                                            color: Theme.surfaceText
                                            font.weight: Font.Medium
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
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
