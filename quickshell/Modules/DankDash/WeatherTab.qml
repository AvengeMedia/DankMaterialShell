import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.DankBar.Widgets

Item {
    id: root

    implicitWidth: 700
    implicitHeight: 410
    property bool syncing: false

    function syncFrom(type) {
        if (!dailyLoader.item || !hourlyLoader.item)
            return;
        const hourlyList = hourlyLoader.item;
        const dailyList = dailyLoader.item;
        syncing = true;

        try {
            if (type === "hour") {
                const date = new Date();
                date.setHours(hourlyList.currentIndex);
                dateStepper.currentDate = date;

                dailyList.currentIndex = Math.max(0, Math.min((WeatherService.weather.forecast?.length ?? 1) - 1, WeatherService.calendarDayDifference((new Date()), date)));
            } else if (type === "day") {
                const date = new Date(dateStepper.currentDate);
                date.setMonth((new Date()).getMonth());
                date.setDate((new Date()).getDate() + dailyList.currentIndex);
                dateStepper.currentDate = date;

                const hourIndex = Math.max(0, Math.min((WeatherService.weather.hourlyForecast?.length ?? 1) - 1, WeatherService.calendarHourDifference((new Date()), date) + (new Date).getHours()));
                hourlyList.currentIndex = hourIndex;
            } else if (type === "date") {
                const date = dateStepper.currentDate;
                dailyList.currentIndex = Math.max(0, Math.min((WeatherService.weather.forecast?.length ?? 1) - 1, WeatherService.calendarDayDifference((new Date()), date)));
                hourlyList.currentIndex = Math.max(0, Math.min((WeatherService.weather.hourlyForecast?.length ?? 1) - 1, WeatherService.calendarHourDifference((new Date()), date) + (new Date()).getHours()));
            }
        } catch (e) {
            console.warn("Weather Date Sync Error:", e);
        }

        syncing = false;
    }

    property bool available: WeatherService.weather.available

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingL
        visible: !root.available

        DankIcon {
            name: "cloud_off"
            size: Theme.iconSize * 2
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Row {
            width: refreshButtonTwo.width + refreshText.width
            height: refreshButtonTwo.height
            spacing: Theme.spacingS

            StyledText {
                id: refreshText
                text: I18n.tr("No Weather Data Available")
                font.pixelSize: Theme.fontSizeLarge
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                anchors.verticalCenter: parent.verticalCenter
            }

            DankIcon {
                id: refreshButtonTwo
                name: "refresh"
                size: Theme.iconSize - 4
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.4)
                anchors.top: parent.top
                anchors.verticalCenter: parent.verticalCenter

                property bool isRefreshing: false
                enabled: !isRefreshing

                MouseArea {
                    id: refreshButtonMouseAreaTwo
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    enabled: parent.enabled

                    Timer {
                        id: hoverDelayTwo
                        interval: 1000
                        repeat: false
                        onTriggered: {
                            const p = refreshButtonMouseAreaTwo.mapToItem(null, parent.width / 2, parent.height + Theme.spacingXS);
                            refreshButtonTooltipTwo.show(I18n.tr("Refresh Weather"), p.x, p.y, null);
                        }
                    }

                    onEntered: {
                        hoverDelayTwo.restart();
                    }

                    onExited: {
                        hoverDelayTwo.stop();
                        refreshButtonTooltipTwo.hide();
                    }

                    onClicked: {
                        refreshButtonTwo.isRefreshing = true;
                        WeatherService.forceRefresh();
                        refreshTimerTwo.restart();
                    }
                }

                DankTooltip {
                    id: refreshButtonTooltipTwo
                }

                Timer {
                    id: refreshTimerTwo
                    interval: 2000
                    onTriggered: refreshButtonTwo.isRefreshing = false
                }

                NumberAnimation on rotation {
                    running: refreshButtonTwo.isRefreshing
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                }
            }
        }
    }

    Column {
        anchors.fill: parent
        visible: root.available
        spacing: Theme.spacingXS

        Item {
            id: weatherContainer
            width: parent.width
            height: weatherColumn.height

            Column {
                id: weatherColumn
                height: weatherInfo.height + dateStepper.height
                width: Math.max(weatherInfo.width, dateStepper.width)

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
                                            SettingsData.set("useFahrenheit", !SettingsData.useFahrenheit);
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
                    id: dateStepper
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 60
                    width: dateStepperInner.width

                    property var currentDate: new Date()

                    readonly property var changeDate: (magnitudeIndex, sign) => {
                        switch (magnitudeIndex) {
                        case 0:
                            break;
                        case 1:
                            var newDate = new Date(dateStepper.currentDate);
                            newDate.setMonth(dateStepper.currentDate.getMonth() + sign * 1);
                            dateStepper.currentDate = newDate;
                            break;
                        case 2:
                            dateStepper.currentDate = new Date(dateStepper.currentDate.getTime() + sign * 24 * 3600 * 1000);
                            break;
                        case 3:
                            dateStepper.currentDate = new Date(dateStepper.currentDate.getTime() + sign * 3600 * 1000);
                            break;
                        case 4:
                            dateStepper.currentDate = new Date(dateStepper.currentDate.getTime() + sign * 5 * 60 * 1000);
                            break;
                        }
                    }
                    readonly property var splitDate: Qt.formatDateTime(dateStepper.currentDate, "yyyy.MM.dd.hh.mm.AP").split('.')

                    Item {
                        id: dateStepperInner
                        anchors.fill: parent
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property var space: Theme.spacingXS
                        width: yearStepper.width + monthStepper.width + dayStepper.width + hourStepper.width + minuteStepper.width + suffix.width + 10.5 * space + 2 * dateStepperInnerPadding.width

                        Item {
                            id: dateStepperInnerPadding
                            width: dateResetButton.width
                        }

                        DankNumberStepper {
                            id: yearStepper
                            anchors.left: dateStepperInnerPadding.right
                            anchors.leftMargin: parent.space
                            width: implicitWidth
                            text: dateStepper.splitDate[0]
                            // onIncrement: () => dateStepper.changeDate(0, +1)
                            // onDecrement: () => dateStepper.changeDate(0, -1)
                        }

                        DankNumberStepper {
                            id: monthStepper
                            width: implicitWidth
                            anchors.left: yearStepper.right
                            anchors.leftMargin: parent.space
                            text: dateStepper.splitDate[1]
                            onIncrement: () => dateStepper.changeDate(1, +1)
                            onDecrement: () => dateStepper.changeDate(1, -1)
                        }

                        DankNumberStepper {
                            id: dayStepper
                            width: implicitWidth
                            anchors.left: monthStepper.right
                            anchors.leftMargin: parent.space
                            text: dateStepper.splitDate[2]
                            onIncrement: () => dateStepper.changeDate(2, +1)
                            onDecrement: () => dateStepper.changeDate(2, -1)
                        }

                        DankNumberStepper {
                            id: hourStepper
                            width: implicitWidth
                            anchors.left: dayStepper.right
                            anchors.leftMargin: 1.5 * parent.space
                            text: dateStepper.splitDate[3]
                            onIncrement: () => dateStepper.changeDate(3, +1)
                            onDecrement: () => dateStepper.changeDate(3, -1)
                        }

                        DankNumberStepper {
                            id: minuteStepper
                            width: implicitWidth
                            anchors.left: hourStepper.right
                            anchors.leftMargin: parent.space
                            text: dateStepper.splitDate[4]
                            onIncrement: () => dateStepper.changeDate(4, +1)
                            onDecrement: () => dateStepper.changeDate(4, -1)
                        }

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: yearStepper.right
                            anchors.right: monthStepper.left
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "-"
                            }
                        }
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: monthStepper.right
                            anchors.right: dayStepper.left
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "-"
                            }
                        }
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: hourStepper.right
                            anchors.right: minuteStepper.left
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: ":"
                            }
                        }
                        Rectangle {
                            id: suffix
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: minuteStepper.right
                            anchors.leftMargin: 2 * parent.space
                            StyledText {
                                isMonospace: true
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: dateStepper.splitDate[5]
                                font.pixelSize: Theme.fontSizeSmall
                                x: -Theme.fontSizeSmall / 2
                                y: -Theme.fontSizeSmall / 2
                            }
                        }
                        DankActionButton {
                            id: dateResetButton
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            enabled: Math.abs(dateStepper.currentDate - new Date()) > 1000
                            iconColor: enabled ? Theme.blendAlpha(Theme.surfaceText, 0.5) : "transparent"
                            iconSize: 12
                            buttonSize: 20
                            iconName: "replay"
                            onClicked: {
                                dateStepper.currentDate = new Date();
                            }
                        }
                    }

                    onCurrentDateChanged: if (!syncing)
                        root.syncFrom("date")
                }
            }

            Rectangle {
                id: skyBox
                height: weatherColumn.height
                anchors.left: weatherColumn.right
                anchors.right: parent.right
                anchors.leftMargin: Theme.spacingM
                property var backgroundOpacity: 0.3
                property var sunTime: WeatherService.getCurrentSunTime(dateStepper.currentDate)
                property var periodIndex: sunTime?.periodIndex
                property var periodPercent: sunTime?.periodPercent
                property var blackColor: Theme.blend(Theme.surface, Qt.rgba(0, 0, 0, 255), 0.2)
                property var redColor: Theme.secondary
                property var blueColor: Theme.primary
                function blackBlue(r) {
                    return Theme.blend(blackColor, blueColor, r);
                }
                property var topColor: {
                    const colorMap = [blackColor                             // "night"
                        , Theme.withAlpha(blackBlue(0.0), 0.8)   // "astronomicalTwilight"
                        , Theme.withAlpha(blackBlue(0.2), 0.7)   // "nauticalTwilight"
                        , Theme.withAlpha(blackBlue(0.5), 0.6)   // "civilTwilight"
                        , Theme.withAlpha(blackBlue(0.7), 0.6)   // "sunrise"
                        , Theme.withAlpha(blackBlue(0.9), 0.6)   // "goldenHourMorning"
                        , Theme.withAlpha(blackBlue(1.0), 0.6)   // "daytime"
                        , Theme.withAlpha(blackBlue(0.9), 0.6)   // "afternoon"
                        , Theme.withAlpha(blackBlue(0.7), 0.6)   // "goldenHourEvening"
                        , Theme.withAlpha(blackBlue(0.5), 0.6)   // "sunset"
                        , Theme.withAlpha(blackBlue(0.2), 0.7)   // "civilTwilight"
                        , Theme.withAlpha(blackBlue(0.0), 0.8)   // "nauticalTwilightEvening"
                        , blackColor                             // "astronomicalTwilightEvening"
                        , blackColor                             // "night"
                        ,];
                    const index = periodIndex ?? 0;
                    return Theme.blend(colorMap[index], colorMap[index + 1], periodPercent ?? 0);
                }
                property var sunColor: {
                    const colorMap = [Theme.withAlpha(redColor, 0.05)   // "night"
                        , Theme.withAlpha(redColor, 0.1)    // "astronomicalTwilight"
                        , Theme.withAlpha(redColor, 0.3)    // "nauticalTwilight"
                        , Theme.withAlpha(redColor, 0.4)    // "civilTwilight"
                        , Theme.withAlpha(redColor, 0.5)    // "sunrise"
                        , Theme.withAlpha(blueColor, 0.2)   // "goldenHourMorning"
                        , Theme.withAlpha(blueColor, 0.0)   // "daytime"
                        , Theme.withAlpha(blueColor, 0.2)   // "afternoon"
                        , Theme.withAlpha(redColor, 0.5)    // "goldenHourEvening"
                        , Theme.withAlpha(redColor, 0.4)    // "sunset"
                        , Theme.withAlpha(redColor, 0.3)    // "civilTwilight"
                        , Theme.withAlpha(redColor, 0.1)    // "nauticalTwilightEvening"
                        , Theme.withAlpha(redColor, 0.05)   // "astronomicalTwilightEvening"
                        , Theme.withAlpha(redColor, 0.0)    // "night"
                        ,];
                    const index = periodIndex ?? 0;
                    return Theme.blend(colorMap[index], colorMap[index + 1], periodPercent ?? 0);
                }

                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    opacity: skyBox.backgroundOpacity

                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: Theme.withAlpha(skyBox.blackColor, 0.0)
                        }
                        GradientStop {
                            position: 0.05
                            color: skyBox.topColor
                        }
                        GradientStop {
                            position: 0.3
                            color: skyBox.topColor
                        }
                        GradientStop {
                            position: 0.5
                            color: skyBox.topColor
                        }
                        GradientStop {
                            position: 0.501
                            color: skyBox.blackColor
                        }
                        GradientStop {
                            position: 0.9
                            color: skyBox.blackColor
                        }
                        GradientStop {
                            position: 1.0
                            color: Theme.withAlpha(skyBox.blackColor, 0.0)
                        }
                    }
                }

                property var currentDate: dateStepper.currentDate
                property var hMargin: 0
                property var vMargin: Theme.spacingM
                property var effectiveHeight: skyBox.height - 2 * vMargin
                property var effectiveWidth: skyBox.width - 2 * hMargin

                StyledText {
                    text: parent.sunTime?.period ?? ""
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
                    height: parent.height / 2
                    opacity: skyBox.backgroundOpacity

                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: RadialGradient {
                            centerX: skyBox.hMargin + sun.x + sun.width / 2
                            centerY: skyBox.vMargin + sun.y + 30
                            centerRadius: {
                                const a = Math.abs((skyBox.sunTime?.dayPercent ?? 0) - 0.5);
                                const out = 200 * (0.5 - a * a);
                                return out;
                            }
                            focalX: skyBox.hMargin + sun.x + sun.width / 2
                            focalY: skyBox.vMargin + sun.y
                            GradientStop {
                                position: 0
                                color: skyBox.sunColor
                            }
                            GradientStop {
                                position: 0.3
                                color: Theme.blendAlpha(skyBox.sunColor, 0.5)
                            }
                            GradientStop {
                                position: 1
                                color: "transparent"
                            }
                        }
                        PathLine {
                            x: 0
                            y: 0
                        }
                        PathLine {
                            x: skyShape.width
                            y: 0
                        }
                        PathLine {
                            x: skyShape.width
                            y: skyShape.height
                        }
                        PathLine {
                            x: 0
                            y: skyShape.height
                        }
                    }

                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: RadialGradient {
                            centerX: sun.x
                            centerY: sun.y
                            centerRadius: 500
                            focalX: centerX
                            focalY: centerY + 0.99 * (centerRadius - focalRadius)
                            focalRadius: 10
                            GradientStop {
                                position: 0
                                color: skyBox.sunColor
                            }
                            GradientStop {
                                position: 0.45
                                color: skyBox.sunColor
                            }
                            GradientStop {
                                position: 0.55
                                color: "transparent"
                            }
                            GradientStop {
                                position: 1
                                color: "transparent"
                            }
                        }
                        PathLine {
                            x: 0
                            y: 0
                        }
                        PathLine {
                            x: skyShape.width
                            y: 0
                        }
                        PathLine {
                            x: skyShape.width
                            y: skyShape.height
                        }
                        PathLine {
                            x: 0
                            y: skyShape.height
                        }
                    }
                }

                Canvas {
                    id: ecliptic
                    anchors.fill: parent
                    property var points: WeatherService.getEcliptic(dateStepper.currentDate)

                    function getX(index) {
                        return points[index].h * skyBox.effectiveWidth + skyBox.hMargin;
                    }
                    function getY(index) {
                        return points[index].v * -(skyBox.effectiveHeight / 2) + skyBox.effectiveHeight / 2 + skyBox.vMargin;
                    }

                    onPointsChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        if (!points || points.length === 0)
                            return;
                        ctx.beginPath();
                        ctx.moveTo(getX(0), getY(0));
                        for (var i = 1; i < points.length; i++) {
                            ctx.lineTo(getX(i), getY(i));
                        }
                        ctx.strokeStyle = Theme.withAlpha(Theme.outline, 0.2);
                        ctx.stroke();
                    }
                }

                property real latitude: WeatherService.getLocation()?.latitude ?? 0
                property real sunDeclination: WeatherService.getSunDeclination(dateStepper.currentDate)

                readonly property bool solarNoonIsSouth: latitude > sunDeclination

                StyledText {
                    id: middle
                    text: skyBox.solarNoonIsSouth ? "S" : "N"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primary
                    x: skyBox.width / 2 - middle.width / 2
                    y: skyBox.height / 2 - middle.height / 2
                }

                StyledText {
                    id: left
                    text: skyBox.solarNoonIsSouth ? "E" : "W"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primary
                    x: skyBox.width / 4 - left.width / 2
                    y: skyBox.height / 2 - left.height / 2
                }

                StyledText {
                    id: right
                    text: skyBox.solarNoonIsSouth ? "W" : "E"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.primary
                    x: 3 * skyBox.width / 4 - right.width / 2
                    y: skyBox.height / 2 - right.height / 2
                }

                Rectangle {
                    // Rightmost Line
                    height: 1
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    anchors.left: right.right
                    anchors.right: skyBox.right
                    anchors.verticalCenter: middle.verticalCenter
                    color: Theme.outline
                }

                Rectangle {
                    // Middle Right Line
                    height: 1
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    anchors.left: middle.right
                    anchors.right: right.left
                    anchors.verticalCenter: middle.verticalCenter
                    color: Theme.outline
                }

                Rectangle {
                    // Middle Left Line
                    height: 1
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    anchors.left: left.right
                    anchors.right: middle.left
                    anchors.verticalCenter: middle.verticalCenter
                    color: Theme.outline
                }

                Rectangle {
                    // Leftmost Line
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
                    visible: !!pos

                    property var pos: WeatherService.getSkyArcPosition(skyBox.currentDate, false)
                    x: (pos?.h ?? 0) * skyBox.effectiveWidth - (moonPhase.width / 2) + skyBox.hMargin
                    y: (pos?.v ?? 0) * -(skyBox.effectiveHeight / 2) + skyBox.effectiveHeight / 2 - (moonPhase.height / 2) + skyBox.vMargin

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
                    visible: !!pos

                    property var pos: WeatherService.getSkyArcPosition(skyBox.currentDate, true)
                    x: (pos?.h ?? 0) * skyBox.effectiveWidth - (sun.width / 2) + skyBox.hMargin
                    y: (pos?.v ?? 0) * -(skyBox.effectiveHeight / 2) + skyBox.effectiveHeight / 2 - (sun.height / 2) + skyBox.vMargin

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
                    id: refreshButtonMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    enabled: parent.enabled

                    Timer {
                        id: hoverDelay
                        interval: 1000
                        repeat: false
                        onTriggered: {
                            const p = refreshButtonMouseArea.mapToItem(null, parent.width / 2, parent.height + Theme.spacingXS);
                            refreshButtonTooltip.show(I18n.tr("Refresh Weather"), p.x, p.y, null);
                        }
                    }

                    onEntered: {
                        hoverDelay.restart();
                    }

                    onExited: {
                        hoverDelay.stop();
                        refreshButtonTooltip.hide();
                    }

                    onClicked: {
                        refreshButton.isRefreshing = true;
                        WeatherService.forceRefresh();
                        refreshTimer.restart();
                    }
                }

                DankTooltip {
                    id: refreshButtonTooltip
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

        Row {
            width: parent.width
            height: 32
            spacing: Theme.spacingS

            StyledText {
                id: hourlyHeader
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Hourly Forecast")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - denseButton.width - hourlyHeader.width - 2 * parent.spacing
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
            }

            DankActionButton {
                id: denseButton
                anchors.verticalCenter: parent.verticalCenter
                visible: hourlyLoader.item !== null
                iconName: SessionData.weatherHourlyDetailed ? "tile_large" : "tile_medium"
                onClicked: SessionData.setWeatherHourlyDetailed(!SessionData.weatherHourlyDetailed)
            }
        }

        Item {
            width: parent.width
            height: 100 + Theme.spacingXS

            Loader {
                id: hourlyLoader
                anchors.fill: parent
                sourceComponent: hourlyComponent
                active: root.visible && root.available
                asynchronous: true
                opacity: 0
                onLoaded: {
                    root.syncing = true;
                    item.currentIndex = item.initialIndex;
                    item.positionViewAtIndex(item.initialIndex, ListView.SnapPosition);
                    root.syncing = false;
                    opacity = 1;
                }
            }

            Component {
                id: hourlyComponent
                ListView {
                    id: hourlyList
                    width: parent.width
                    height: cardHeight + Theme.spacingXS
                    orientation: ListView.Horizontal
                    spacing: Theme.spacingS
                    clip: true
                    snapMode: ListView.SnapToItem
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    highlightMoveDuration: 0
                    interactive: true
                    contentHeight: cardHeight
                    contentWidth: cardWidth

                    property var cardHeight: 100
                    property var cardWidth: ((hourlyList.width + hourlyList.spacing) / hourlyList.visibleCount) - hourlyList.spacing
                    property int initialIndex: (new Date()).getHours()
                    property bool dense: !SessionData.weatherHourlyDetailed
                    property int visibleCount: 8

                    model: WeatherService.weather.hourlyForecast?.length ?? 0

                    delegate: WeatherForecastCard {
                        width: hourlyList.cardWidth
                        height: hourlyList.cardHeight
                        dense: hourlyList.dense
                        daily: false

                        date: {
                            const d = new Date();
                            d.setHours(index);
                            return d;
                        }
                        forecastData: WeatherService.weather.hourlyForecast?.[index]
                    }

                    onCurrentIndexChanged: if (!syncing)
                        root.syncFrom("hour")

                    states: [
                        State {
                            name: "denseState"
                            when: hourlyList.dense
                            PropertyChanges {
                                target: hourlyList
                                visibleCount: 10
                            }
                        },
                        State {
                            name: "normalState"
                            when: !hourlyList.dense
                            PropertyChanges {
                                target: hourlyList
                                visibleCount: 5
                            }
                        }
                    ]

                    transitions: [
                        Transition {
                            NumberAnimation {
                                properties: "visibleCount"
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    ]

                    MouseArea {
                        anchors.fill: parent
                        onWheel: wheel => {
                            if (wheel.modifiers & Qt.ShiftModifier) {
                                if (wheel.angleDelta.y % 120 == 0 && wheel.angleDelta.x == 0) {
                                    const newIndex = hourlyList.currentIndex - Math.sign(wheel.angleDelta.y);
                                    if (newIndex < hourlyList.model && newIndex >= 0) {
                                        hourlyList.currentIndex = newIndex;
                                        wheel.accepted = true;
                                        return;
                                    }
                                }
                            }
                            wheel.accepted = false;
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: 32
            spacing: Theme.spacingS

            StyledText {
                id: dailyHeader
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Daily Forecast")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - denseButton.width - dailyHeader.width - 2 * parent.spacing
                height: 1
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
            }
        }

        Item {
            width: parent.width
            height: 100 + Theme.spacingXS

            Loader {
                id: dailyLoader
                anchors.fill: parent
                sourceComponent: dailyComponent
                active: root.visible && root.available
                asynchronous: true
                opacity: 0
                onLoaded: {
                    root.syncing = true;
                    item.currentIndex = item.initialIndex;
                    item.positionViewAtIndex(item.initialIndex, ListView.SnapPosition);
                    root.syncing = false;
                    opacity = 1;
                }
            }

            Component {
                id: dailyComponent
                ListView {
                    id: dailyList
                    width: parent.width
                    height: cardHeight + Theme.spacingXS
                    orientation: ListView.Horizontal
                    spacing: Theme.spacingS
                    clip: true
                    snapMode: ListView.SnapToItem
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    highlightMoveDuration: 0
                    interactive: true
                    contentHeight: cardHeight
                    contentWidth: cardWidth

                    property var cardHeight: 100
                    property var cardWidth: ((dailyList.width + dailyList.spacing) / dailyList.visibleCount) - dailyList.spacing
                    property int initialIndex: 0
                    property bool dense: false
                    property int visibleCount: 7

                    model: WeatherService.weather.forecast?.length ?? 0

                    delegate: WeatherForecastCard {
                        width: dailyList.cardWidth
                        height: dailyList.cardHeight
                        dense: true
                        daily: true

                        date: {
                            const date = new Date();
                            date.setDate(date.getDate() + index);
                            return date;
                        }
                        forecastData: WeatherService.weather.forecast?.[index]
                    }

                    onCurrentIndexChanged: if (!syncing)
                        root.syncFrom("day")

                    MouseArea {
                        anchors.fill: parent
                        onWheel: wheel => {
                            if (wheel.modifiers & Qt.ShiftModifier) {
                                if (wheel.angleDelta.y % 120 == 0 && wheel.angleDelta.x == 0) {
                                    const newIndex = dailyList.currentIndex - Math.sign(wheel.angleDelta.y);
                                    if (newIndex < dailyList.model && newIndex >= 0) {
                                        dailyList.currentIndex = newIndex;
                                        wheel.accepted = true;
                                        return;
                                    }
                                }
                            }
                            wheel.accepted = false;
                        }
                    }
                }
            }
        }
    }
}
