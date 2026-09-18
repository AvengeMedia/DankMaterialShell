import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.DankDash

Card {
    id: root

    property bool live: Window.window?.visible ?? false

    readonly property bool showSeconds: options.seconds === true
    readonly property bool showDate: options.date === true
    readonly property string hourText: {
        const hours = systemClock.date.getHours();
        if (SettingsData.use24HourClock)
            return String(hours).padStart(2, "0");
        const display = hours % 12 === 0 ? 12 : hours % 12;
        return String(display).padStart(2, "0");
    }
    readonly property string minuteText: String(systemClock.date.getMinutes()).padStart(2, "0")
    readonly property string secondText: String(systemClock.date.getSeconds()).padStart(2, "0")

    entryId: "clock"
    tone: options.tone ?? ""
    pad: Theme.spacingL

    Loader {
        anchors.fill: parent
        sourceComponent: root.options.style === "analog" ? analogFace : digitalFace
    }

    Component {
        id: digitalFace

        DankClockFace {
            hours: root.hourText
            minutes: root.minuteText
            seconds: root.showSeconds ? root.secondText : ""
            dateText: root.showDate ? systemClock.date.toLocaleDateString(I18n.locale(), "MMMM d") : ""
            dayText: root.showDate ? systemClock.date.toLocaleDateString(I18n.locale(), "dddd") : ""
            color: root.accentColor
            supportingColor: root.tinted ? root.contentColor : root.mutedColor
        }
    }

    Component {
        id: analogFace

        DankAnalogClock {
            hours: systemClock.date.getHours()
            minutes: systemClock.date.getMinutes()
            seconds: systemClock.date.getSeconds()
            showSeconds: root.showSeconds
            showNumbers: root.options.numbers === true
            numbersOutside: root.tinted
            dateText: root.showDate ? systemClock.date.toLocaleDateString(I18n.locale(), "MMM d") : ""
            color: root.tinted ? root.onAccentColor : root.accentColor
            numberColor: root.accentColor
            backgroundColor: root.tinted ? root.accentColor : root.chipColor
            facePadding: 0
        }
    }

    SystemClock {
        id: systemClock
        enabled: root.live
        precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Connections {
        target: SessionService

        function onSessionResumed() {
            if (!root.live)
                return;
            systemClock.enabled = false;
            systemClock.enabled = true;
        }
    }
}
