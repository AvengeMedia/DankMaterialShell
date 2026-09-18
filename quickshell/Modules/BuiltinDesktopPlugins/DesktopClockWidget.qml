import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property real widgetWidth: 280
    property real widgetHeight: 200

    property string instanceId: ""
    property var instanceData: null
    readonly property var cfg: instanceData?.config ?? ({})

    property string clockStyle: cfg.style ?? "analog"
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

    enabled: instanceData?.enabled ?? true
    property real transparency: cfg.transparency ?? 0.8
    property string colorMode: cfg.colorMode ?? "primary"
    property color customColor: cfg.customColor ?? "#ffffff"
    property bool showDate: cfg.showDate ?? true
    property bool showAnalogNumbers: cfg.showAnalogNumbers ?? false

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

    readonly property bool showAnalogSeconds: cfg.showAnalogSeconds ?? true
    readonly property bool showDigitalSeconds: cfg.showDigitalSeconds ?? false
    readonly property bool needsSeconds: clockStyle === "analog" ? showAnalogSeconds : showDigitalSeconds
    readonly property string formattedDate: {
        if (SettingsData.clockDateFormat && SettingsData.clockDateFormat.length > 0)
            return systemClock.date?.toLocaleDateString(I18n.locale(), SettingsData.clockDateFormat) ?? "";
        return systemClock.date?.toLocaleDateString(I18n.locale(), "ddd, MMM d") ?? "";
    }

    SystemClock {
        id: systemClock
        precision: root.needsSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Connections {
        target: SessionService

        function onSessionResumed() {
            systemClock.enabled = false;
            systemClock.enabled = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: root.backgroundColor
        visible: root.clockStyle !== "analog"
    }

    Loader {
        anchors.fill: parent
        anchors.margins: root.clockStyle === "analog" ? 0 : Theme.spacingM
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

        DankAnalogClock {
            hours: systemClock.date?.getHours() ?? 0
            minutes: systemClock.date?.getMinutes() ?? 0
            seconds: systemClock.date?.getSeconds() ?? 0
            showSeconds: root.showAnalogSeconds
            showNumbers: root.showAnalogNumbers
            dateText: root.showDate ? root.formattedDate : ""
            color: root.accentColor
            backgroundColor: root.backgroundColor
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
                    text: root.formattedDate
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
                        font.weight: Theme.fontWeightMedium
                        color: root.accentColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    StyledText {
                        width: digitalRoot.digitWidth
                        text: digitalRoot.hoursStr.length > 1 ? digitalRoot.hoursStr.charAt(1) : digitalRoot.hoursStr.charAt(0)
                        font.pixelSize: digitalRoot.baseSize
                        font.weight: Theme.fontWeightMedium
                        color: root.accentColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    StyledText {
                        text: ":"
                        font.pixelSize: digitalRoot.baseSize
                        font.weight: Theme.fontWeightMedium
                        color: root.accentColor
                    }
                    StyledText {
                        width: digitalRoot.digitWidth
                        text: digitalRoot.minutesStr.charAt(0)
                        font.pixelSize: digitalRoot.baseSize
                        font.weight: Theme.fontWeightMedium
                        color: root.accentColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    StyledText {
                        width: digitalRoot.digitWidth
                        text: digitalRoot.minutesStr.charAt(1)
                        font.pixelSize: digitalRoot.baseSize
                        font.weight: Theme.fontWeightMedium
                        color: root.accentColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                    StyledText {
                        visible: root.showDigitalSeconds
                        text: ":"
                        font.pixelSize: digitalRoot.baseSize
                        font.weight: Theme.fontWeightMedium
                        color: Theme.withAlpha(root.accentColor, 0.7)
                    }
                    StyledText {
                        visible: root.showDigitalSeconds
                        width: digitalRoot.digitWidth
                        text: digitalRoot.secondsStr.charAt(0)
                        font.pixelSize: digitalRoot.baseSize
                        font.weight: Theme.fontWeightMedium
                        color: Theme.withAlpha(root.accentColor, 0.7)
                        horizontalAlignment: Text.AlignHCenter
                    }
                    StyledText {
                        visible: root.showDigitalSeconds
                        width: digitalRoot.digitWidth
                        text: digitalRoot.secondsStr.charAt(1)
                        font.pixelSize: digitalRoot.baseSize
                        font.weight: Theme.fontWeightMedium
                        color: Theme.withAlpha(root.accentColor, 0.7)
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                StyledText {
                    visible: !SettingsData.use24HourClock
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (systemClock.date?.getHours() ?? 0) >= 12 ? "PM" : "AM"
                    font.pixelSize: digitalRoot.smallSize
                    font.weight: Theme.fontWeightMedium
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
                            font.weight: Theme.fontWeightMedium
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
                            font.weight: Theme.fontWeightMedium
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
                            font.weight: Theme.fontWeightMedium
                            color: root.accentColor
                            width: stackedRoot.digitWidth
                            horizontalAlignment: Text.AlignHCenter
                        }

                        StyledText {
                            text: String(systemClock.date?.getMinutes() ?? 0).padStart(2, '0').charAt(1)
                            font.pixelSize: stackedRoot.baseSize
                            font.weight: Theme.fontWeightMedium
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
                        font.weight: Theme.fontWeightMedium
                        color: Theme.withAlpha(root.accentColor, 0.7)
                        width: stackedRoot.smallSize * 0.58
                        horizontalAlignment: Text.AlignHCenter
                    }

                    StyledText {
                        text: String(systemClock.date?.getSeconds() ?? 0).padStart(2, '0').charAt(1)
                        font.pixelSize: stackedRoot.smallSize
                        font.weight: Theme.fontWeightMedium
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
                    font.weight: Theme.fontWeightMedium
                    color: Theme.withAlpha(root.accentColor, 0.7)
                }
            }
        }
    }
}
