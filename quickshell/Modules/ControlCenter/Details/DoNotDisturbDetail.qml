import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    implicitHeight: contentColumn.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadius
    color: Theme.nestedSurface
    border.color: Theme.outlineMedium
    border.width: Theme.layerOutlineWidth

    property real nowMs: Date.now()

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && SessionData.doNotDisturb && SessionData.doNotDisturbUntil > 0
        onTriggered: root.nowMs = Date.now()
    }

    function _pad2(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    function formatUntil(ts) {
        if (!ts)
            return "";
        const d = new Date(ts);
        const use24h = (typeof SettingsData !== "undefined") ? SettingsData.use24HourClock : true;
        if (use24h)
            return _pad2(d.getHours()) + ":" + _pad2(d.getMinutes());
        const suffix = d.getHours() >= 12 ? "PM" : "AM";
        const h12 = ((d.getHours() + 11) % 12) + 1;
        return h12 + ":" + _pad2(d.getMinutes()) + " " + suffix;
    }

    function formatRemaining(ms) {
        if (ms <= 0)
            return "";
        const totalMinutes = Math.ceil(ms / 60000);
        if (totalMinutes < 60)
            return I18n.tr("%1 min left").arg(totalMinutes);
        const hours = Math.floor(totalMinutes / 60);
        const mins = totalMinutes - hours * 60;
        if (mins === 0)
            return I18n.tr("%1 h left").arg(hours);
        return I18n.tr("%1 h %2 m left").arg(hours).arg(mins);
    }

    function minutesUntilTomorrowMorning() {
        const now = new Date();
        const target = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 8, 0, 0, 0);
        return Math.max(1, Math.round((target.getTime() - now.getTime()) / 60000));
    }

    readonly property var presets: [
        {
            "label": I18n.tr("15 min"),
            "minutes": 15
        },
        {
            "label": I18n.tr("30 min"),
            "minutes": 30
        },
        {
            "label": I18n.tr("1 hour"),
            "minutes": 60
        },
        {
            "label": I18n.tr("3 hours"),
            "minutes": 180
        },
        {
            "label": I18n.tr("8 hours"),
            "minutes": 480
        },
        {
            "label": I18n.tr("Until 8 AM"),
            "minutesFn": true
        }
    ]

    Column {
        id: contentColumn
        width: parent.width - Theme.spacingL * 2
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM

        Row {
            width: parent.width
            spacing: Theme.spacingM

            DankIcon {
                name: SessionData.doNotDisturb ? "do_not_disturb_on" : "notifications_paused"
                size: Theme.iconSizeLarge
                color: SessionData.doNotDisturb ? Theme.primary : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.iconSizeLarge - Theme.spacingM
                spacing: 2

                StyledText {
                    text: I18n.tr("Silence notifications")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    width: parent.width
                    elide: Text.ElideRight
                }

                StyledText {
                    text: {
                        if (!SessionData.doNotDisturb)
                            return I18n.tr("Pick how long to pause notifications");
                        if (SessionData.doNotDisturbUntil <= 0)
                            return I18n.tr("On indefinitely");
                        const remaining = Math.max(0, SessionData.doNotDisturbUntil - root.nowMs);
                        return root.formatRemaining(remaining) + " · " + I18n.tr("until %1").arg(root.formatUntil(SessionData.doNotDisturbUntil));
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    elide: Text.ElideRight
                }
            }
        }

        Grid {
            width: parent.width
            columns: 3
            columnSpacing: Theme.spacingS
            rowSpacing: Theme.spacingS

            Repeater {
                model: root.presets

                Rectangle {
                    required property var modelData
                    width: (contentColumn.width - Theme.spacingS * 2) / 3
                    height: 36
                    radius: Theme.cornerRadius
                    color: presetArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : Theme.floatingSurface
                    border.color: Theme.outlineStrong
                    border.width: 1

                    StyledText {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: presetArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const minutes = modelData.minutesFn ? root.minutesUntilTomorrowMorning() : modelData.minutes;
                            SessionData.setDoNotDisturb(true, minutes);
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: Theme.spacingS

            Rectangle {
                width: (contentColumn.width - Theme.spacingS) / 2
                height: 36
                radius: Theme.cornerRadius
                color: foreverArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : Theme.floatingSurface
                border.color: Theme.outlineStrong
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "block"
                        size: Theme.iconSizeSmall
                        color: Theme.surfaceText
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Until I turn it off")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                }

                MouseArea {
                    id: foreverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SessionData.setDoNotDisturb(true, 0)
                }
            }

            Rectangle {
                width: (contentColumn.width - Theme.spacingS) / 2
                height: 36
                radius: Theme.cornerRadius
                visible: SessionData.doNotDisturb
                color: offArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18) : Theme.floatingSurface
                border.color: Theme.outlineStrong
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "notifications_active"
                        size: Theme.iconSizeSmall
                        color: offArea.containsMouse ? Theme.error : Theme.surfaceText
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Turn off")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: offArea.containsMouse ? Theme.error : Theme.surfaceText
                    }
                }

                MouseArea {
                    id: offArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SessionData.setDoNotDisturb(false)
                }
            }
        }
    }
}
