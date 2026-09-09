import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "../../../Common/Format.js" as Format

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

    function _syncNow() {
        nowMs = Date.now();
    }

    onVisibleChanged: {
        if (visible)
            _syncNow();
    }

    Connections {
        target: SessionData
        function onIdleInhibitedUntilChanged() {
            if (root.visible)
                root._syncNow();
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && SessionService.idleInhibited && SessionData.idleInhibitedUntil > 0
        triggeredOnStart: true
        onTriggered: root._syncNow()
    }

    function formatRemaining(ms) {
        return Format.formatRemaining(ms, "", I18n.tr("%1 min left"), I18n.tr("%1 h left"), I18n.tr("%1 h %2 m left"));
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
            "label": I18n.tr("2 hours"),
            "minutes": 120
        },
        {
            "label": I18n.tr("4 hours"),
            "minutes": 240
        },
        {
            "label": I18n.tr("8 hours"),
            "minutes": 480
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
                name: SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
                size: Theme.iconSizeLarge
                color: SessionService.idleInhibited ? Theme.primary : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.iconSizeLarge - Theme.spacingM
                spacing: Theme.spacingXXS

                StyledText {
                    text: I18n.tr("Prevent screen timeout")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    width: parent.width
                    elide: Text.ElideRight
                }

                StyledText {
                    text: {
                        if (!SessionService.idleInhibited)
                            return I18n.tr("Pick how long to stay awake", "idle inhibitor detail subtitle shown while keep awake is off");
                        if (SessionData.idleInhibitedUntil <= 0)
                            return I18n.tr("On indefinitely");
                        const remaining = Math.max(0, SessionData.idleInhibitedUntil - root.nowMs);
                        return root.formatRemaining(remaining) + " · " + I18n.tr("until %1").arg(Format.formatUntil(SessionData.idleInhibitedUntil, SettingsData.use24HourClock));
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
                    color: presetArea.containsMouse ? Theme.primaryPressed : Theme.floatingSurface
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
                        onClicked: SessionService.enableIdleInhibit(modelData.minutes)
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
                color: foreverArea.containsMouse ? Theme.primaryPressed : Theme.floatingSurface
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
                    onClicked: SessionService.enableIdleInhibit(0)
                }
            }

            Rectangle {
                width: (contentColumn.width - Theme.spacingS) / 2
                height: 36
                radius: Theme.cornerRadius
                visible: SessionService.idleInhibited
                color: offArea.containsMouse ? Theme.errorPressed : Theme.floatingSurface
                border.color: Theme.outlineStrong
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "motion_sensor_idle"
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
                    onClicked: SessionService.disableIdleInhibit()
                }
            }
        }
    }
}
