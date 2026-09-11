import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "../../../Common/Format.js" as Format

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    signal dismissed

    readonly property bool currentlyActive: SessionService.idleInhibited
    readonly property real currentRemainingMs: SessionData.idleInhibitedUntil > 0 ? Math.max(0, SessionData.idleInhibitedUntil - nowMs) : 0
    property real nowMs: Date.now()

    function _syncNow() {
        nowMs = Date.now();
    }

    onVisibleChanged: {
        if (visible)
            _syncNow();
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.currentlyActive && SessionData.idleInhibitedUntil > 0
        triggeredOnStart: true
        onTriggered: root._syncNow()
    }

    function formatRemaining(ms) {
        return Format.formatRemaining(ms, I18n.tr("Off"), I18n.tr("%1 min left"), I18n.tr("%1 h left"), I18n.tr("%1 h %2 m left"));
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
            "label": I18n.tr("For 2 hours", "idle inhibit duration menu option"),
            "minutes": 120
        },
        {
            "label": I18n.tr("For 4 hours", "idle inhibit duration menu option"),
            "minutes": 240
        },
        {
            "label": I18n.tr("For 8 hours"),
            "minutes": 480
        },
        {
            "label": I18n.tr("Until I turn it off"),
            "minutes": 0
        }
    ]

    function selectPreset(option) {
        SessionService.enableIdleInhibit(option.minutes);
        root.dismissed();
    }

    function turnOff() {
        SessionService.disableIdleInhibit();
        root.dismissed();
    }

    implicitWidth: Math.max(220, menuColumn.implicitWidth + Theme.spacingM * 2)
    implicitHeight: menuColumn.implicitHeight + Theme.spacingM * 2
    color: Theme.floatingSurface
    radius: Theme.cornerRadius
    border.color: BlurService.borderColor
    border.width: BlurService.borderWidth

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
                name: SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
                size: Theme.iconSize - 2
                color: SessionService.idleInhibited ? Theme.primary : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - Theme.iconSize - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                StyledText {
                    text: I18n.tr("Keep Awake")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    width: parent.width
                }

                StyledText {
                    visible: root.currentlyActive
                    text: {
                        if (SessionData.idleInhibitedUntil > 0) {
                            return root.formatRemaining(root.currentRemainingMs) + " · " + I18n.tr("until %1").arg(Format.formatUntil(SessionData.idleInhibitedUntil, SettingsData.use24HourClock));
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
            color: Theme.outlineStrong
        }

        Repeater {
            model: root.presetOptions

            Rectangle {
                id: optionRect
                required property var modelData
                width: menuColumn.width
                height: 32
                radius: Theme.cornerRadius
                color: optionArea.containsMouse ? BlurService.hoverColor(Theme.widgetBaseHoverColor) : Theme.withAlpha(BlurService.hoverColor(Theme.widgetBaseHoverColor), 0)

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
            color: Theme.outlineStrong
        }

        Rectangle {
            visible: root.currentlyActive
            width: menuColumn.width
            height: 32
            radius: Theme.cornerRadius
            color: offArea.containsMouse ? Theme.errorPressed : Theme.withAlpha(Theme.errorPressed, 0)

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingS
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "motion_sensor_idle"
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
