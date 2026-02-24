import QtQuick
import Quickshell
import qs.Common
import qs.Widgets

Item {
    id: root

    property real widgetWidth: 280
    property real widgetHeight: 200

    property string instanceId: ""
    property var instanceData: null
    readonly property var cfg: instanceData?.config ?? null
    readonly property bool isInstance: instanceId !== "" && cfg !== null

    property string clockStyle: isInstance ? (cfg.style ?? "analog") : SettingsData.desktopClockStyle
    property bool forceSquare: clockStyle === "analog"

    property real defaultWidth: {
        switch (clockStyle) {
        case "analog":
            return 200;
        case "stacked":
            return 100;
        default:
            return 160;
        }
    }
    property real defaultHeight: {
        switch (clockStyle) {
        case "analog":
            return 200;
        case "stacked":
            return 160;
        default:
            return 70;
        }
    }
    property real minWidth: {
        switch (clockStyle) {
        case "analog":
            return 120;
        case "stacked":
            return 70;
        default:
            return 100;
        }
    }
    property real minHeight: {
        switch (clockStyle) {
        case "analog":
            return 120;
        case "stacked":
            return 100;
        default:
            return 45;
        }
    }

    property bool enabled: isInstance ? (instanceData?.enabled ?? true) : SettingsData.desktopClockEnabled
    property real transparency: isInstance ? (cfg.transparency ?? 0.8) : SettingsData.desktopClockTransparency
    property string colorMode: isInstance ? (cfg.colorMode ?? "primary") : SettingsData.desktopClockColorMode
    property color customColor: isInstance ? (cfg.customColor ?? "#ffffff") : SettingsData.desktopClockCustomColor
    property bool showDate: isInstance ? (cfg.showDate ?? true) : SettingsData.desktopClockShowDate
    property bool showAnalogNumbers: isInstance ? (cfg.showAnalogNumbers ?? false) : SettingsData.desktopClockShowAnalogNumbers

    readonly property real scaleFactor: Math.min(width, height) / 200

    readonly property color accentColor: {
        if (colorMode === "primary")
            return Theme.primary;
        if (colorMode === "secondary")
            return Theme.secondary;
        if (colorMode === "custom")
            return customColor;
        return Theme.primary;
    }

    readonly property color handColor: accentColor
    readonly property color handColorDim: Theme.withAlpha(accentColor, 0.65)
    readonly property color textColor: Theme.onSurface
    readonly property color subtleTextColor: Theme.onSurfaceVariant
    readonly property color backgroundColor: Theme.withAlpha(Theme.surface, root.transparency)

    readonly property bool showAnalogSeconds: isInstance ? (cfg.showAnalogSeconds ?? true) : SettingsData.desktopClockShowAnalogSeconds
    readonly property bool showDigitalSeconds: isInstance ? (cfg.showDigitalSeconds ?? false) : false
    readonly property bool needsSeconds: clockStyle === "analog" ? showAnalogSeconds : showDigitalSeconds

    SystemClock {
        id: systemClock
        precision: root.needsSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: root.backgroundColor
        visible: root.clockStyle !== "analog"
    }

    OrganicBlobHourBulges {
        anchors.fill: parent
        fillColor: root.backgroundColor
        visible: root.clockStyle === "analog"
        lobes: 12
        rotationDeg: -90
        lobeAmount: 0.075
        hillPower: 0.92
        roundness: 0.22
        paddingFrac: 0.02
        segments: 144
    }

    Loader {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        sourceComponent: {
            if (root.clockStyle === "analog")
                return analogClock;
            if (root.clockStyle === "stacked")
                return stackedClock;
            return digitalClock;
        }
    }

    Component {
        id: analogClock

        Item {
            id: analogRoot

            property real clockSize: Math.min(width, height)
            property real centerX: width / 2
            property real centerY: height / 2
            property real faceRadius: clockSize / 2 - 12

            property int hours: systemClock.date?.getHours() % 12 ?? 0
            property int minutes: systemClock.date?.getMinutes() ?? 0
            property int seconds: systemClock.date?.getSeconds() ?? 0

            Repeater {
                model: root.showAnalogNumbers ? 12 : 0

                StyledText {
                    required property int index
                    property real angle: (index + 1) * 30 * Math.PI / 180
                    property real numRadius: analogRoot.faceRadius + 10

                    x: analogRoot.centerX + numRadius * Math.sin(angle) - width / 2
                    y: analogRoot.centerY - numRadius * Math.cos(angle) - height / 2
                    text: index + 1
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: root.accentColor
                }
            }

            Rectangle {
                id: hourHand
                property real angle: (analogRoot.hours + analogRoot.minutes / 60) * 30
                property real handWidth: Math.max(8, 12 * root.scaleFactor)
                property real mainLength: analogRoot.faceRadius * 0.55
                property real tailLength: handWidth * 0.5

                x: analogRoot.centerX - width / 2
                y: analogRoot.centerY - mainLength
                width: handWidth
                height: mainLength + tailLength
                radius: width / 2
                color: root.handColor
                antialiasing: true

                transform: Rotation {
                    origin.x: hourHand.width / 2
                    origin.y: hourHand.mainLength
                    angle: hourHand.angle
                }
            }

            Rectangle {
                id: minuteHand
                property real angle: (analogRoot.minutes + analogRoot.seconds / 60) * 6
                property real mainLength: analogRoot.faceRadius * 0.75
                property real tailLength: hourHand.handWidth * 0.5

                x: analogRoot.centerX - width / 2
                y: analogRoot.centerY - mainLength
                width: hourHand.handWidth
                height: mainLength + tailLength
                radius: width / 2
                color: root.handColorDim
                antialiasing: true

                transform: Rotation {
                    origin.x: minuteHand.width / 2
                    origin.y: minuteHand.mainLength
                    angle: minuteHand.angle
                }
            }

            Rectangle {
                id: secondDot
                visible: root.showAnalogSeconds

                property real angle: analogRoot.seconds * 6 * Math.PI / 180
                property real orbitRadius: analogRoot.faceRadius * 0.92

                x: analogRoot.centerX + orbitRadius * Math.sin(angle) - width / 2
                y: analogRoot.centerY - orbitRadius * Math.cos(angle) - height / 2
                width: Math.max(10, analogRoot.clockSize * 0.07)
                height: width
                radius: width / 2
                color: root.accentColor

                Behavior on x {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }
            }

            StyledText {
                id: dateText
                visible: root.showDate

                property real hourAngle: (analogRoot.hours + analogRoot.minutes / 60) * 30
                property real minuteAngle: analogRoot.minutes * 6

                property string bestPosition: {
                    const hRad = hourAngle * Math.PI / 180;
                    const mRad = minuteAngle * Math.PI / 180;

                    const topWeight = Math.max(0, Math.cos(hRad)) + Math.max(0, Math.cos(mRad));
                    const bottomWeight = Math.max(0, -Math.cos(hRad)) + Math.max(0, -Math.cos(mRad));
                    const rightWeight = Math.max(0, Math.sin(hRad)) + Math.max(0, Math.sin(mRad));
                    const leftWeight = Math.max(0, -Math.sin(hRad)) + Math.max(0, -Math.sin(mRad));

                    const minWeight = Math.min(topWeight, bottomWeight, leftWeight, rightWeight);

                    if (minWeight === bottomWeight)
                        return "bottom";
                    if (minWeight === topWeight)
                        return "top";
                    if (minWeight === rightWeight)
                        return "right";
                    return "left";
                }

                x: {
                    if (bestPosition === "left")
                        return analogRoot.centerX - analogRoot.faceRadius * 0.5 - width / 2;
                    if (bestPosition === "right")
                        return analogRoot.centerX + analogRoot.faceRadius * 0.5 - width / 2;
                    return analogRoot.centerX - width / 2;
                }
                y: {
                    if (bestPosition === "top")
                        return analogRoot.centerY - analogRoot.faceRadius * 0.5 - height / 2;
                    if (bestPosition === "bottom")
                        return analogRoot.centerY + analogRoot.faceRadius * 0.5 - height / 2;
                    return analogRoot.centerY - height / 2;
                }

                text: {
                    if (SettingsData.clockDateFormat && SettingsData.clockDateFormat.length > 0)
                        return systemClock.date?.toLocaleDateString(I18n.locale(), SettingsData.clockDateFormat) ?? "";
                    return systemClock.date?.toLocaleDateString(I18n.locale(), "ddd, MMM d") ?? "";
                }
                font.pixelSize: Theme.fontSizeSmall
                color: root.accentColor

                Behavior on x {
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: Theme.mediumDuration
                        easing.type: Theme.emphasizedEasing
                    }
                }
            }
        }
    }

    Component {
        id: digitalClock

        Item {
            id: digitalRoot

            property bool hasDate: root.showDate
            property bool hasAmPm: !SettingsData.use24HourClock
            property real verticalScale: hasDate && hasAmPm ? 0.55 : (hasDate || hasAmPm ? 0.65 : 0.8)
            property real baseSize: Math.min(height * verticalScale, width * 0.22)
            property real digitWidth: baseSize * 0.62
            property real smallSize: baseSize * 0.35

            property string hoursStr: {
                const hours = SettingsData.use24HourClock ? systemClock.date?.getHours() ?? 0 : ((systemClock.date?.getHours() ?? 0) % 12 || 12);
                if (SettingsData.use24HourClock || SettingsData.padHours12Hour)
                    return String(hours).padStart(2, '0');
                return String(hours);
            }
            property string minutesStr: String(systemClock.date?.getMinutes() ?? 0).padStart(2, '0')
            property string secondsStr: String(systemClock.date?.getSeconds() ?? 0).padStart(2, '0')

            Column {
                anchors.centerIn: parent
                spacing: 0

                StyledText {
                    visible: root.showDate
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        if (SettingsData.clockDateFormat && SettingsData.clockDateFormat.length > 0)
                            return systemClock.date?.toLocaleDateString(I18n.locale(), SettingsData.clockDateFormat) ?? "";
                        return systemClock.date?.toLocaleDateString(I18n.locale(), "ddd, MMM d") ?? "";
                    }
                    font.pixelSize: digitalRoot.smallSize
                    color: Theme.withAlpha(root.accentColor, 0.7)
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 0

                    StyledText {
                        visible: digitalRoot.hoursStr.length > 1
                        width: digitalRoot.digitWidth
                        text: digitalRoot.hoursStr.charAt(0)
                        font.pixelSize: digitalRoot.baseSize
                        font.weight: Font.Medium
                        color: root.accentColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    StyledText {
                        width: digitalRoot.digitWidth
                        text: digitalRoot.hoursStr.length > 1 ? digitalRoot.hoursStr.charAt(1) : digitalRoot.hoursStr.charAt(0)
                        font.pixelSize: digitalRoot.baseSize
                        font.weight: Font.Medium
                        color: root.accentColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    StyledText {
                        text: ":"
                        font.pixelSize: digitalRoot.baseSize
                        font.weight: Font.Medium
                        color: root.accentColor
                    }
                    StyledText {
                        width: digitalRoot.digitWidth
                        text: digitalRoot.minutesStr.charAt(0)
                        font.pixelSize: digitalRoot.baseSize
                        font.weight: Font.Medium
                        color: root.accentColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    StyledText {
                        width: digitalRoot.digitWidth
                        text: digitalRoot.minutesStr.charAt(1)
                        font.pixelSize: digitalRoot.baseSize
                        font.weight: Font.Medium
                        color: root.accentColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    StyledText {
                        visible: root.showDigitalSeconds
                        text: ":"
                        font.pixelSize: digitalRoot.baseSize
                        font.weight: Font.Medium
                        color: Theme.withAlpha(root.accentColor, 0.7)
                    }
                    StyledText {
                        visible: root.showDigitalSeconds
                        width: digitalRoot.digitWidth
                        text: digitalRoot.secondsStr.charAt(0)
                        font.pixelSize: digitalRoot.baseSize
                        font.weight: Font.Medium
                        color: Theme.withAlpha(root.accentColor, 0.7)
                        horizontalAlignment: Text.AlignHCenter
                    }
                    StyledText {
                        visible: root.showDigitalSeconds
                        width: digitalRoot.digitWidth
                        text: digitalRoot.secondsStr.charAt(1)
                        font.pixelSize: digitalRoot.baseSize
                        font.weight: Font.Medium
                        color: Theme.withAlpha(root.accentColor, 0.7)
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                StyledText {
                    visible: !SettingsData.use24HourClock
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (systemClock.date?.getHours() ?? 0) >= 12 ? "PM" : "AM"
                    font.pixelSize: digitalRoot.smallSize
                    font.weight: Font.Medium
                    color: Theme.withAlpha(root.accentColor, 0.7)
                }
            }
        }
    }

    Component {
        id: stackedClock

        Item {
            id: stackedRoot

            property bool hasSeconds: root.showDigitalSeconds
            property bool hasDate: root.showDate
            property bool hasAmPm: !SettingsData.use24HourClock
            property real extraContent: (hasSeconds ? 0.12 : 0) + (hasDate ? 0.08 : 0) + (hasAmPm ? 0.08 : 0)
            property real baseSize: height * (0.42 - extraContent * 0.5)
            property real digitWidth: baseSize * 0.58
            property real smallSize: baseSize * 0.5
            property real rowSpacing: -baseSize * 0.17

            Column {
                anchors.centerIn: parent
                spacing: 0

                Column {
                    spacing: stackedRoot.rowSpacing
                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        spacing: 0
                        anchors.horizontalCenter: parent.horizontalCenter

                        StyledText {
                            text: {
                                if (SettingsData.use24HourClock)
                                    return String(systemClock.date?.getHours() ?? 0).padStart(2, '0').charAt(0);
                                const hours = systemClock.date?.getHours() ?? 0;
                                const display = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours;
                                return String(display).padStart(2, '0').charAt(0);
                            }
                            font.pixelSize: stackedRoot.baseSize
                            font.weight: Font.Medium
                            color: root.accentColor
                            width: stackedRoot.digitWidth
                            horizontalAlignment: Text.AlignHCenter
                        }

                        StyledText {
                            text: {
                                if (SettingsData.use24HourClock)
                                    return String(systemClock.date?.getHours() ?? 0).padStart(2, '0').charAt(1);
                                const hours = systemClock.date?.getHours() ?? 0;
                                const display = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours;
                                return String(display).padStart(2, '0').charAt(1);
                            }
                            font.pixelSize: stackedRoot.baseSize
                            font.weight: Font.Medium
                            color: root.accentColor
                            width: stackedRoot.digitWidth
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Row {
                        spacing: 0
                        anchors.horizontalCenter: parent.horizontalCenter

                        StyledText {
                            text: String(systemClock.date?.getMinutes() ?? 0).padStart(2, '0').charAt(0)
                            font.pixelSize: stackedRoot.baseSize
                            font.weight: Font.Medium
                            color: root.accentColor
                            width: stackedRoot.digitWidth
                            horizontalAlignment: Text.AlignHCenter
                        }

                        StyledText {
                            text: String(systemClock.date?.getMinutes() ?? 0).padStart(2, '0').charAt(1)
                            font.pixelSize: stackedRoot.baseSize
                            font.weight: Font.Medium
                            color: root.accentColor
                            width: stackedRoot.digitWidth
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Row {
                    visible: stackedRoot.hasSeconds
                    spacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter

                    StyledText {
                        text: String(systemClock.date?.getSeconds() ?? 0).padStart(2, '0').charAt(0)
                        font.pixelSize: stackedRoot.smallSize
                        font.weight: Font.Medium
                        color: Theme.withAlpha(root.accentColor, 0.7)
                        width: stackedRoot.smallSize * 0.58
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        text: String(systemClock.date?.getSeconds() ?? 0).padStart(2, '0').charAt(1)
                        font.pixelSize: stackedRoot.smallSize
                        font.weight: Font.Medium
                        color: Theme.withAlpha(root.accentColor, 0.7)
                        width: stackedRoot.smallSize * 0.58
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Item {
                    width: 1
                    height: stackedRoot.baseSize * 0.1
                    visible: stackedRoot.hasDate
                }

                StyledText {
                    visible: stackedRoot.hasDate
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: systemClock.date?.toLocaleDateString(I18n.locale(), "MMM dd") ?? ""
                    font.pixelSize: stackedRoot.smallSize * 0.7
                    color: Theme.withAlpha(root.accentColor, 0.7)
                }

                StyledText {
                    visible: stackedRoot.hasAmPm
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (systemClock.date?.getHours() ?? 0) >= 12 ? "PM" : "AM"
                    font.pixelSize: stackedRoot.smallSize * 0.7
                    font.weight: Font.Medium
                    color: Theme.withAlpha(root.accentColor, 0.7)
                }
            }
        }
    }
}
