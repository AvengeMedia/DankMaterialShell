import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    signal dismissed

    readonly property bool currentlyActive: SessionData.doNotDisturb
    readonly property real currentRemainingMs: SessionData.doNotDisturbUntil > 0 ? Math.max(0, SessionData.doNotDisturbUntil - nowMs) : 0
    property real nowMs: Date.now()

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.currentlyActive && SessionData.doNotDisturbUntil > 0
        onTriggered: root.nowMs = Date.now()
    }

    function _pad2(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    function formatRemaining(ms) {
        if (ms <= 0)
            return I18n.tr("Off");
        const totalMinutes = Math.ceil(ms / 60000);
        if (totalMinutes < 60)
            return I18n.tr("%1 min left").arg(totalMinutes);
        const hours = Math.floor(totalMinutes / 60);
        const mins = totalMinutes - hours * 60;
        if (mins === 0)
            return I18n.tr("%1 h left").arg(hours);
        return I18n.tr("%1 h %2 m left").arg(hours).arg(mins);
    }

    function formatUntilTimestamp(ts) {
        if (!ts)
            return "";
        const d = new Date(ts);
        const hours = d.getHours();
        const minutes = d.getMinutes();
        const use24h = (typeof SettingsData !== "undefined") ? SettingsData.use24HourClock : true;
        if (use24h) {
            return _pad2(hours) + ":" + _pad2(minutes);
        }
        const suffix = hours >= 12 ? "PM" : "AM";
        const h12 = ((hours + 11) % 12) + 1;
        return h12 + ":" + _pad2(minutes) + " " + suffix;
    }

    function minutesUntilTomorrowMorning() {
        const now = new Date();
        const target = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 8, 0, 0, 0);
        return Math.max(1, Math.round((target.getTime() - now.getTime()) / 60000));
    }

    readonly property var presetOptions: [
        {
            "label": I18n.tr("For 15 minutes"),
            "minutes": 15
        },
        {
            "label": I18n.tr("For 30 minutes"),
            "minutes": 30
        },
        {
            "label": I18n.tr("For 1 hour"),
            "minutes": 60
        },
        {
            "label": I18n.tr("For 3 hours"),
            "minutes": 180
        },
        {
            "label": I18n.tr("For 8 hours"),
            "minutes": 480
        },
        {
            "label": I18n.tr("Until tomorrow, 8:00 AM"),
            "minutesFn": true
        },
        {
            "label": I18n.tr("Until I turn it off"),
            "minutes": 0
        }
    ]

    function selectPreset(option) {
        let minutes = option.minutes;
        if (option.minutesFn) {
            minutes = minutesUntilTomorrowMorning();
        }
        SessionData.setDoNotDisturb(true, minutes);
        root.dismissed();
    }

    function turnOff() {
        SessionData.setDoNotDisturb(false);
        root.dismissed();
    }

    implicitWidth: Math.max(220, menuColumn.implicitWidth + Theme.spacingM * 2)
    implicitHeight: menuColumn.implicitHeight + Theme.spacingM * 2
    color: Theme.floatingSurface
    radius: Theme.cornerRadius
    border.color: BlurService.enabled ? BlurService.borderColor : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
    border.width: BlurService.enabled ? BlurService.borderWidth : 1

    Column {
        id: menuColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingXS

        Row {
            width: parent.width
            spacing: Theme.spacingS

            DankIcon {
                name: SessionData.doNotDisturb ? "notifications_off" : "notifications_paused"
                size: Theme.iconSize - 2
                color: SessionData.doNotDisturb ? Theme.primary : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - Theme.iconSize - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                StyledText {
                    text: I18n.tr("Do Not Disturb")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    width: parent.width
                }

                StyledText {
                    visible: root.currentlyActive
                    text: {
                        if (SessionData.doNotDisturbUntil > 0) {
                            return root.formatRemaining(root.currentRemainingMs) + " · " + I18n.tr("until %1").arg(root.formatUntilTimestamp(SessionData.doNotDisturbUntil));
                        }
                        return I18n.tr("On indefinitely");
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
        }

        Repeater {
            model: root.presetOptions

            Rectangle {
                id: optionRect
                required property var modelData
                width: menuColumn.width
                height: 32
                radius: Theme.cornerRadius
                color: optionArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : "transparent"

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: optionRect.modelData.label
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: optionArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectPreset(optionRect.modelData)
                }
            }
        }

        Rectangle {
            visible: root.currentlyActive
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
        }

        Rectangle {
            visible: root.currentlyActive
            width: menuColumn.width
            height: 32
            radius: Theme.cornerRadius
            color: offArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.14) : "transparent"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingS
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "notifications_active"
                    size: Theme.iconSizeSmall
                    color: offArea.containsMouse ? Theme.error : Theme.surfaceText
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Turn off now")
                    font.pixelSize: Theme.fontSizeSmall
                    color: offArea.containsMouse ? Theme.error : Theme.surfaceText
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                id: offArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.turnOff()
            }
        }
    }
}
