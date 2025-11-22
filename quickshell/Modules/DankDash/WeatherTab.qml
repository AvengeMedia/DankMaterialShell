import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    implicitWidth: 700
    implicitHeight: 410

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingL
        visible: !WeatherService.weather.available

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
        anchors.fill: parent
        spacing: Theme.spacingM
        visible: WeatherService.weather.available

        Item {
            id: weatherContainer
            width: parent.width
            height: weatherColumn.height

            Column {
                id: weatherColumn
                height: weatherInfo.height + dateSlider.height
                width: Math.max(weatherInfo.width, dateSliderColumn.width)

                Item {
                    id: weatherInfo
                    anchors.horizontalCenter: parent.horizontalCenter
                    // anchors.verticalCenter: parent.verticalCenter
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
                                            SettingsData.useFahrenheit = !SettingsData.useFahrenheit
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

                Item {
                    id: dateSlider
                    height: dateSliderColumn.implicitHeight
                    width: dateSliderColumn.width
                    // anchors.top: weatherContainer.bottom
                    // anchors.horizontalCenter: parent.horizontalCenter


                    property var currentDate: new Date()   // the datetime being adjusted

                    signal dateChanged(var newDate)

                    Column {
                        id: dateSliderColumn
                        anchors.fill: parent
                        width: 9 * 20 + 8 * 4
                        spacing: 10

                        Row {
                            spacing: 4
                            anchors.horizontalCenter: parent.horizontalCenter

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: monthBack.containsMouse ? Theme.primaryHover : "transparent"

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "first_page"
                                    size: 12
                                    color: Theme.surfaceText
                                }

                                MouseArea {
                                    id: monthBack
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var newDate = new Date(dateSlider.currentDate)
                                        newDate.setMonth(dateSlider.currentDate.getMonth() - 1)
                                        dateSlider.currentDate = newDate
                                        dateSlider.dateChanged(dateSlider.currentDate)
                                    }
                                }
                            }

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: dayBack.containsMouse ? Theme.primaryHover : "transparent"

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "keyboard_double_arrow_left"
                                    size: 12
                                    color: Theme.surfaceText
                                }

                                MouseArea {
                                    id: dayBack
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        dateSlider.currentDate = new Date(dateSlider.currentDate.getTime() - 24*3600*1000)
                                        dateSlider.dateChanged(dateSlider.currentDate)
                                    }
                                }
                            }

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: hourBack.containsMouse ? Theme.primaryHover : "transparent"

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "keyboard_arrow_left"
                                    size: 12
                                    color: Theme.surfaceText
                                }

                                MouseArea {
                                    id: hourBack
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        dateSlider.currentDate = new Date(dateSlider.currentDate.getTime() - 3600*1000)
                                        dateSlider.dateChanged(dateSlider.currentDate)
                                    }
                                }
                            }

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: minuteBack.containsMouse ? Theme.primaryHover : "transparent"

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "arrow_left"
                                    size: 12
                                    color: Theme.surfaceText
                                }

                                MouseArea {
                                    id: minuteBack
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        dateSlider.currentDate = new Date(dateSlider.currentDate.getTime() - 5*60*1000)
                                        dateSlider.dateChanged(dateSlider.currentDate)
                                    }
                                }
                            }


                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: returnToPresent.containsMouse ? Theme.primaryHover : "transparent"

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: Math.abs((new Date()).getTime() - dateSlider.currentDate.getTime()) < 60 * 60 * 1000 ? "" : (new Date() < dateSlider.currentDate ? "subdirectory_arrow_left" : "subdirectory_arrow_right")
                                    size: 12
                                    color: Theme.surfaceText
                                }

                                MouseArea {
                                    id: returnToPresent
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        dateSlider.currentDate = new Date()
                                        dateSlider.dateChanged(dateSlider.currentDate)
                                    }
                                }
                            }

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: minuteForward.containsMouse ? Theme.primaryHover : "transparent"

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "arrow_right"
                                    size: 12
                                    color: Theme.surfaceText
                                }

                                MouseArea {
                                    id: minuteForward
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        dateSlider.currentDate = new Date(dateSlider.currentDate.getTime() + 5*60*1000)
                                        dateSlider.dateChanged(dateSlider.currentDate)
                                    }
                                }
                            }

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: hourForward.containsMouse ? Theme.primaryHover : "transparent"

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "keyboard_arrow_right"
                                    size: 12
                                    color: Theme.surfaceText
                                }

                                MouseArea {
                                    id: hourForward
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        dateSlider.currentDate = new Date(dateSlider.currentDate.getTime() + 3600*1000)
                                        dateSlider.dateChanged(dateSlider.currentDate)
                                    }
                                }
                            }

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: dayForward.containsMouse ? Theme.primaryHover : "transparent"

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "keyboard_double_arrow_right"
                                    size: 12
                                    color: Theme.surfaceText
                                }

                                MouseArea {
                                    id: dayForward
                                    anchors.fill: parent
                                    // enabled: root.playerAvailable
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        dateSlider.currentDate = new Date(dateSlider.currentDate.getTime() + 24*3600*1000)
                                        dateSlider.dateChanged(dateSlider.currentDate)
                                    }
                                }
                            }

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: monthForward.containsMouse ? Theme.primaryHover : "transparent"

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "last_page"
                                    size: 12
                                    color: Theme.surfaceText
                                }

                                MouseArea {
                                    id: monthForward
                                    anchors.fill: parent
                                    // enabled: root.playerAvailable
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var newDate = new Date(dateSlider.currentDate)
                                        newDate.setMonth(dateSlider.currentDate.getMonth() + 1)
                                        dateSlider.currentDate = newDate
                                        dateSlider.dateChanged(dateSlider.currentDate)
                                    }
                                }
                            }

                        }

                        StyledText {
                            id: dateLabel
                            text: Qt.formatDateTime(dateSlider.currentDate, "yyyy-MM-dd hh:mm")
                            font.pointSize: Theme.barTextSize(4)
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Theme.surfaceText
                        }
                    }

                    onCurrentDateChanged: ()=>{
                        dateLabel.text = Qt.formatDateTime(dateSlider.currentDate, "yyyy-MM-dd hh:mm")
                    }
                }
            }

            Rectangle {
                id: skyBox
                // width: 300
                height: weatherColumn.height
                anchors.left: weatherColumn.right
                anchors.right: parent.right
                anchors.leftMargin: Theme.spacingM
                // anchors.verticalCenter: parent.verticalCenter
                // anchors.top: weatherContainer.bottom
                // anchors.horizontalCenter: parent.horizontalCenter
                property var backgroundOpacity: 0.5
                property var sunTime: WeatherService.getCurrentSunTime(dateSlider.currentDate)
                property var periodIndex: sunTime.periodIndex
                property var periodPercent: sunTime.periodPercent
                property var blackColor: Qt.rgba(0,0,0,1.0)
                property var redColor: Theme.secondary
                property var yellowColor: Theme.primary
                property var blueColor: "transparent"
                property var topColor: {
                    const colorMap = [
                        blackColor,                         // "night"
                        Theme.withAlpha(blackColor, 0.9),   // "astronomicalTwilight"
                        Theme.withAlpha(blackColor, 0.8),   // "nauticalTwilight"
                        Theme.withAlpha(blackColor, 0.6),   // "civilTwilight"
                        Theme.withAlpha(blackColor, 0.2),   // "sunrise"
                        Theme.withAlpha(redColor, 0.1),     // "goldenHourMorning"
                        Theme.withAlpha(yellowColor, 0.0),  // "daytime"
                        Theme.withAlpha(redColor, 0.1),     // "afternoon"
                        Theme.withAlpha(blackColor, 0.2),   // "goldenHourEvening"
                        Theme.withAlpha(blackColor, 0.6),   // "sunset"
                        Theme.withAlpha(blackColor, 0.8),   // "dusk"
                        Theme.withAlpha(blackColor, 0.9),   // "nauticalTwilightEvening"
                        blackColor,                         // "astronomicalTwilightEvening"
                        blackColor,                         // "night"
                    ]
                    return Theme.blend(colorMap[periodIndex], colorMap[periodIndex + 1], periodPercent)
                }
                property var middleColor: {
                    const colorMap = [
                        blackColor,                         // "night"
                        Theme.withAlpha(blackColor, 0.8),   // "astronomicalTwilight"
                        Theme.withAlpha(blackColor, 0.6),   // "nauticalTwilight"
                        Theme.withAlpha(redColor, 0.5),     // "civilTwilight"
                        Theme.withAlpha(yellowColor, 0.5),  // "sunrise"
                        Theme.withAlpha(yellowColor, 0.2),  // "goldenHourMorning"
                        Theme.withAlpha(yellowColor, 0.0),  // "daytime"
                        Theme.withAlpha(yellowColor, 0.2),  // "afternoon"
                        Theme.withAlpha(yellowColor, 0.5),  // "goldenHourEvening"
                        Theme.withAlpha(redColor, 0.5),     // "sunset"
                        Theme.withAlpha(blackColor, 0.6),   // "dusk"
                        Theme.withAlpha(blackColor, 0.8),   // "nauticalTwilightEvening"
                        blackColor,                         // "astronomicalTwilightEvening"
                        blackColor,                         // "night"
                    ]
                    return Theme.blend(colorMap[periodIndex], colorMap[periodIndex + 1], periodPercent)
                }
                property var sunColor: {
                    const colorMap = [
                        Theme.withAlpha(redColor, 0.05),   // "night"
                        Theme.withAlpha(redColor, 0.1),    // "astronomicalTwilight"
                        Theme.withAlpha(redColor, 0.3),    // "nauticalTwilight"
                        Theme.withAlpha(redColor, 0.4),    // "civilTwilight"
                        Theme.withAlpha(redColor, 0.5),    // "sunrise"
                        Theme.withAlpha(yellowColor, 0.2), // "goldenHourMorning"
                        Theme.withAlpha(yellowColor, 0.0), // "daytime"
                        Theme.withAlpha(yellowColor, 0.2), // "afternoon"
                        Theme.withAlpha(redColor, 0.5),    // "goldenHourEvening"
                        Theme.withAlpha(redColor, 0.4),    // "sunset"
                        Theme.withAlpha(redColor, 0.3),    // "dusk"
                        Theme.withAlpha(redColor, 0.1),    // "nauticalTwilightEvening"
                        Theme.withAlpha(redColor, 0.05),   // "astronomicalTwilightEvening"
                        Theme.withAlpha(redColor, 0.0),    // "night"
                    ]
                    return Theme.blend(colorMap[periodIndex], colorMap[periodIndex + 1], periodPercent)
                }

                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    opacity: skyBox.backgroundOpacity

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#00000000" }
                        GradientStop { position: 0.1; color: skyBox.topColor }
                        GradientStop { position: 0.3; color: skyBox.topColor }
                        GradientStop { position: 0.5; color: skyBox.middleColor }
                        GradientStop { position: 0.501; color: "#ff000000" }
                        GradientStop { position: 0.9; color: "#ff000000" }
                        GradientStop { position: 1.0; color: "#00000000" }
                    }
                }

                property var currentDate: dateSlider.currentDate
                property var hMargin: 0
                property var vMargin: Theme.spacingM
                property var effectiveHeight: skyBox.height - 2*vMargin
                property var effectiveWidth: skyBox.width - 2*hMargin

                StyledText {
                    text: parent.sunTime.period
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.withAlpha(Theme.surfaceText, 0.7)
                    x: 0
                    y: 0
                }

                Shape {
                    id: skyShape
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.right: parent.right
                    height: parent.height/2
                    opacity: skyBox.backgroundOpacity

                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: RadialGradient {
                            centerX: skyBox.hMargin + sun.x + sun.width/2
                            centerY: skyBox.vMargin + sun.y + 30
                            centerRadius: {
                                const a = Math.abs(skyBox.sunTime.dayPercent - 0.5)
                                const out = 200 * (0.5 - a*a)
                                // console.warn(out)
                                return out
                            }
                            focalX: skyBox.hMargin + sun.x + sun.width/2
                            focalY: skyBox.vMargin + sun.y
                            GradientStop { position: 0; color: skyBox.sunColor }
                            GradientStop { position: 1; color: "transparent" }
                        }
                        PathLine { x: 0; y: 0 }
                        PathLine { x: skyShape.width; y: 0 }
                        PathLine { x: skyShape.width; y: skyShape.height }
                        PathLine { x: 0; y: skyShape.height }
                    }

                }

                StyledText {
                    id: middle
                    text: WeatherService.getLocation()?.latitude ?? 0 > 0 ? "S" : "N"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primary
                    x: skyBox.width/2 - middle.width/2
                    y: skyBox.height/2 - middle.height/2
                }

                StyledText {
                    id: left
                    text: WeatherService.getLocation()?.latitude ?? 0 > 0 ? "E" : "W"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primary
                    x: skyBox.width/4 - left.width/2
                    y: skyBox.height/2 - left.height/2
                }

                StyledText {
                    id: right
                    text: WeatherService.getLocation()?.latitude ?? 0 > 0 ? "W" : "E"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primary
                    x: 3*skyBox.width/4 - right.width/2
                    y: skyBox.height/2 - right.height/2
                }

                Rectangle { // Rightmost Line
                    height: 1
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    anchors.left: right.right
                    anchors.right: skyBox.right
                    anchors.verticalCenter: middle.verticalCenter
                    color: Theme.outline
                }

                Rectangle { // Middle Right Line
                    height: 1
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    anchors.left: middle.right
                    anchors.right: right.left
                    anchors.verticalCenter: middle.verticalCenter
                    color: Theme.outline
                }

                Rectangle { // Middle Left Line
                    height: 1
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    anchors.left: left.right
                    anchors.right: middle.left
                    anchors.verticalCenter: middle.verticalCenter
                    color: Theme.outline
                }

                Rectangle { // Leftmost Line
                    height: 1
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    anchors.left: skyBox.left
                    anchors.right: left.left
                    anchors.verticalCenter: middle.verticalCenter
                    color: Theme.outline
                }

                StyledText {
                    id: moonPhase
                    text: WeatherService.getMoonPhase(skyBox.currentDate) || ""
                    font.pixelSize: Theme.fontSizeXLarge * 1
                    color: Theme.withAlpha(Theme.surfaceText, 0.7)
                    rotation: (WeatherService.getMoonAngle(skyBox.currentDate) || 0) / Math.PI * 180
                    x: WeatherService.getSkyArcPosition(skyBox.currentDate, false).h * skyBox.effectiveWidth - (moonPhase.width/2) + skyBox.hMargin
                    y: WeatherService.getSkyArcPosition(skyBox.currentDate, false).v * -(skyBox.effectiveHeight/2) + skyBox.effectiveHeight/2 - (moonPhase.height/2) + skyBox.vMargin

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

                StyledText {
                    id: sun
                    text: ""
                    font.pixelSize: Theme.fontSizeXLarge * 1
                    color: Theme.primary
                        x: WeatherService.getSkyArcPosition(skyBox.currentDate, true).h * skyBox.effectiveWidth - (sun.width/2) + skyBox.hMargin
                        y: WeatherService.getSkyArcPosition(skyBox.currentDate, true).v * -(skyBox.effectiveHeight/2) + skyBox.effectiveHeight/2 - (sun.height/2) + skyBox.vMargin

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
            }
            // StyledText {
            //     id: moonPhase
            //     text: WeatherService.getMoonPhase() || ""
            //     font.pixelSize: Theme.fontSizeXLarge * 2
            //     color: Theme.primary
            //     rotation: (WeatherService.getMoonAngle() || 0) * 360
            //     anchors.left: sunriseColumn.right
            //     anchors.leftMargin: Theme.spacingM
            //     anchors.verticalCenter: parent.verticalCenter
            //
            //     layer.enabled: true
            //     layer.effect: MultiEffect {
            //         shadowEnabled: true
            //         shadowHorizontalOffset: 0
            //         shadowVerticalOffset: 4
            //         shadowBlur: 0.8
            //         shadowColor: Qt.rgba(0, 0, 0, 0.2)
            //         shadowOpacity: 0.2
            //     }
            // }

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
                            text: {
                                if (!WeatherService.weather.wind) return "--"
                                const windKmh = parseFloat(WeatherService.weather.wind)
                                if (isNaN(windKmh)) return WeatherService.weather.wind
                                if (SettingsData.useFahrenheit) {
                                    const windMph = Math.round(windKmh * 0.621371)
                                    return windMph + " mph"
                                }
                                return WeatherService.weather.wind
                            }
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
                            text: {
                                if (!WeatherService.weather.pressure) return "--"
                                const pressureHpa = WeatherService.weather.pressure
                                if (SettingsData.useFahrenheit) {
                                    const pressureInHg = (pressureHpa * 0.02953).toFixed(2)
                                    return pressureInHg + " inHg"
                                }
                                return pressureHpa + " hPa"
                            }
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

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
        }

        Column {
            width: parent.width
            height: parent.height - weatherContainer.height - 95 - Theme.spacingM * 3 - 2
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("7-Day Forecast")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
            }

            Row {
                width: parent.width
                height: parent.height - Theme.fontSizeMedium - Theme.spacingS - Theme.spacingL
                spacing: Theme.spacingXS

                Repeater {
                    model: 7

                    Rectangle {
                        width: (parent.width - Theme.spacingXS * 6) / 7
                        height: parent.height
                        radius: Theme.cornerRadius

                        property var dayDate: {
                            const date = new Date(dateSlider.currentDate)
                            date.setDate(date.getDate() + index)
                            return date
                        }
                        property int dayDifference: {
                            const date1 = new Date()
                            const date2 = dayDate
                            const d1 = Date.UTC(date1.getFullYear(), date1.getMonth(), date1.getDate());
                            const d2 = Date.UTC(date2.getFullYear(), date2.getMonth(), date2.getDate());
                            return Math.floor((d2 - d1) / (1000 * 60 * 60 * 24));
                        }
                        property bool isToday: dayDifference == 0
                        property var forecastData: {
                            if (WeatherService.weather.forecast && WeatherService.weather.forecast.length > index) {
                                if (dayDifference >= 0 && dayDifference < 7) {
                                    return WeatherService.weather.forecast[dayDifference]
                                }
                            }
                            return null
                        }

                        color: isToday ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                        border.color: isToday ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : "transparent"
                        border.width: isToday ? 1 : 0

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS

                            StyledText {
                                text: Qt.locale().dayName(dayDate.getDay(), Locale.ShortFormat)
                                font.pixelSize: Theme.fontSizeSmall
                                color: isToday ? Theme.primary : Theme.surfaceText
                                font.weight: isToday ? Font.Medium : Font.Normal
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            DankIcon {
                                name: forecastData ? WeatherService.getWeatherIcon(forecastData.wCode || 0) : "cloud"
                                size: Theme.iconSize
                                color: isToday ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.8)
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Column {
                                spacing: 2
                                anchors.horizontalCenter: parent.horizontalCenter

                                StyledText {
                                    text: forecastData ? (SettingsData.useFahrenheit ? (forecastData.tempMaxF || forecastData.tempMax) : (forecastData.tempMax || 0)) + "°/" + (SettingsData.useFahrenheit ? (forecastData.tempMinF || forecastData.tempMin) : (forecastData.tempMin || 0)) + "°" : "--/--"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: isToday ? Theme.primary : Theme.surfaceText
                                    font.weight: Font.Medium
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Column {
                                    spacing: 1
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: forecastData && forecastData.sunrise && forecastData.sunset

                                    Row {
                                        spacing: 2
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        DankIcon {
                                            name: "wb_twilight"
                                            size: 8
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: forecastData ? forecastData.sunrise : ""
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Row {
                                        spacing: 2
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        DankIcon {
                                            name: "bedtime"
                                            size: 8
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: forecastData ? forecastData.sunset : ""
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                                            anchors.verticalCenter: parent.verticalCenter
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
}
