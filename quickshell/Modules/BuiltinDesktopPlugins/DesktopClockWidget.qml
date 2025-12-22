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
            return 160;
        default:
            return 280;
        }
    }
    property real defaultHeight: {
        switch (clockStyle) {
        case "analog":
            return 200;
        case "stacked":
            return 220;
        default:
            return 160;
        }
    }
    property real minWidth: {
        switch (clockStyle) {
        case "analog":
            return 120;
        case "stacked":
            return 100;
        default:
            return 140;
        }
    }
    property real minHeight: {
        switch (clockStyle) {
        case "analog":
            return 120;
        case "stacked":
            return 140;
        default:
            return 100;
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
    readonly property bool needsSeconds: clockStyle === "analog" ? showAnalogSeconds : SettingsData.showSeconds

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
                        return systemClock.date?.toLocaleDateString(Qt.locale(), SettingsData.clockDateFormat) ?? "";
                    return systemClock.date?.toLocaleDateString(Qt.locale(), "ddd, MMM d") ?? "";
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

            property real baseSize: Math.max(28, height * 0.38)
            property real smallSize: Math.max(12, baseSize * 0.32)

            Column {
                anchors.centerIn: parent
                spacing: 4

                StyledText {
                    visible: root.showDate
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        if (SettingsData.clockDateFormat && SettingsData.clockDateFormat.length > 0)
                            return systemClock.date?.toLocaleDateString(Qt.locale(), SettingsData.clockDateFormat) ?? "";
                        return systemClock.date?.toLocaleDateString(Qt.locale(), "ddd, MMM d") ?? "";
                    }
                    font.pixelSize: digitalRoot.smallSize
                    color: root.accentColor
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        const hours = SettingsData.use24HourClock ? systemClock.date?.getHours() ?? 0 : ((systemClock.date?.getHours() ?? 0) % 12 || 12);
                        const minutes = String(systemClock.date?.getMinutes() ?? 0).padStart(2, '0');
                        return hours + ":" + minutes;
                    }
                    font.pixelSize: digitalRoot.baseSize
                    font.weight: Font.Normal
                    color: root.accentColor
                }

                Row {
                    visible: !SettingsData.use24HourClock || SettingsData.showSeconds
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingS

                    Row {
                        visible: SettingsData.showSeconds
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: "timer"
                            size: Math.max(10, digitalRoot.baseSize * 0.25)
                            color: root.subtleTextColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: String(systemClock.date?.getSeconds() ?? 0).padStart(2, '0')
                            font.pixelSize: digitalRoot.smallSize
                            color: root.subtleTextColor
                        }
                    }

                    StyledText {
                        visible: !SettingsData.use24HourClock
                        text: (systemClock.date?.getHours() ?? 0) >= 12 ? "PM" : "AM"
                        font.pixelSize: digitalRoot.smallSize
                        font.weight: Font.Medium
                        color: root.accentColor
                    }
                }
            }
        }
    }

    Component {
        id: stackedClock

        Item {
            id: stackedRoot

            property real baseSize: Math.max(32, height * 0.32)
            property real smallSize: Math.max(12, baseSize * 0.28)

            Column {
                anchors.centerIn: parent
                spacing: -baseSize * 0.1

                StyledText {
                    visible: root.showDate
                    anchors.horizontalCenter: parent.horizontalCenter
                    bottomPadding: Theme.spacingS
                    text: {
                        if (SettingsData.clockDateFormat && SettingsData.clockDateFormat.length > 0)
                            return systemClock.date?.toLocaleDateString(Qt.locale(), SettingsData.clockDateFormat) ?? "";
                        return systemClock.date?.toLocaleDateString(Qt.locale(), "ddd, MMM d") ?? "";
                    }
                    font.pixelSize: stackedRoot.smallSize
                    color: root.accentColor
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        const hours = SettingsData.use24HourClock ? systemClock.date?.getHours() ?? 0 : ((systemClock.date?.getHours() ?? 0) % 12 || 12);
                        return String(hours).padStart(2, '0');
                    }
                    font.pixelSize: stackedRoot.baseSize
                    font.weight: Font.Normal
                    color: root.accentColor
                    lineHeight: 0.85
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String(systemClock.date?.getMinutes() ?? 0).padStart(2, '0')
                    font.pixelSize: stackedRoot.baseSize
                    font.weight: Font.Normal
                    color: root.accentColor
                    lineHeight: 0.85
                }

                Row {
                    visible: SettingsData.showSeconds || !SettingsData.use24HourClock
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: Theme.spacingXS
                    spacing: Theme.spacingS

                    Row {
                        visible: SettingsData.showSeconds
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: "timer"
                            size: Math.max(10, stackedRoot.baseSize * 0.28)
                            color: root.subtleTextColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: String(systemClock.date?.getSeconds() ?? 0).padStart(2, '0')
                            font.pixelSize: stackedRoot.smallSize
                            color: root.subtleTextColor
                        }
                    }

                    StyledText {
                        visible: !SettingsData.use24HourClock
                        text: (systemClock.date?.getHours() ?? 0) >= 12 ? "PM" : "AM"
                        font.pixelSize: stackedRoot.smallSize
                        font.weight: Font.Medium
                        color: root.accentColor
                    }
                }
            }
        }
    }
}
