import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import "../../Common/timezone-utils.js" as TimezoneUtils


Rectangle {
    id: root

    property bool compactMode: false
    property string section: "center"
    property var popupTarget: null
    property var parentScreen: null
    property real barHeight: 48
    property real widgetHeight: 30
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 2 : Theme.spacingS

    signal worldClockClicked

    width: clockRow.implicitWidth + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = clockMouseArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }

    Row {
        id: clockRow

        anchors.centerIn: parent
        spacing: Theme.spacingXS

        Repeater {
            model: SettingsData.worldClockTimezones || []

            StyledText {
                text: {
                    if (!systemClock || !systemClock.date) return "Loading..."

                    let label = (modelData && modelData.label) ? modelData.label : ""
                    if (!label || (modelData && label === modelData.timezone)) {
                        if (modelData && modelData.timezone) {
                            label = modelData.timezone.split('/').pop().replace(/_/g, ' ')
                        }
                    }

                    let timeString = ""
                    try {
                        if (TimezoneUtils.isMomentAvailable() && modelData && modelData.timezone) {
                            timeString = TimezoneUtils.getTimeInTimezone(modelData.timezone, SettingsData.use24HourClock)
                        } else {
                            timeString = "missing moment.js dependency"
                        }
                    } catch (e) {
                        timeString = "missing moment.js dependency"
                    }

                    return label + " - " + timeString
                }
                font.pixelSize: Theme.fontSizeMedium - 1
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        StyledText {
            text: "World Clock"
            font.pixelSize: Theme.fontSizeMedium - 1
            color: Theme.surfaceVariantText
            anchors.verticalCenter: parent.verticalCenter
            visible: !SettingsData.worldClockTimezones || SettingsData.worldClockTimezones.length === 0
        }
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }

    MouseArea {
        id: clockMouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            if (popupTarget && popupTarget.setTriggerPosition) {
                const globalPos = mapToGlobal(0, 0)
                const currentScreen = parentScreen || Screen
                const screenX = currentScreen.x || 0
                const relativeX = globalPos.x - screenX
                popupTarget.setTriggerPosition(relativeX, SettingsData.getPopupYPosition(barHeight), width, section, currentScreen)
            }
            root.worldClockClicked()
        }
    }
}
