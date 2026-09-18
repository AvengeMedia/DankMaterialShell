pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets
import "BatteryHistory.js" as History

DankCard {
    id: root

    property var samples: []
    property real rangeStart: 0
    property real rangeEnd: 1
    property string deviceName: ""
    readonly property real visibleDuration: 14400
    readonly property var segments: History.segments(samples, SettingsData.batteryLowThreshold)
    readonly property bool scrollable: timeline.contentWidth > timeline.width + Theme.spacingXS
    readonly property real viewStart: rangeStart + timeline.contentX / Math.max(1, timeline.width) * visibleDuration
    readonly property real viewEnd: Math.min(rangeEnd, viewStart + visibleDuration)
    property bool followLatest: true

    implicitHeight: Theme.iconButtonSize * 4 + pad * 2 + navigation.height + Theme.spacingS + (deviceName ? deviceLabel.implicitHeight + Theme.spacingS : 0)
    restRadius: Theme.cornerRadiusL
    pad: Theme.spacingM
    Accessible.name: I18n.tr("History")

    onRangeEndChanged: {
        if (followLatest)
            latestTimer.restart();
    }

    function scrollTo(offset) {
        timeline.cancelFlick();
        const next = Math.max(0, Math.min(timeline.contentWidth - timeline.width, offset));
        if (next === timeline.contentX)
            return false;
        timeline.contentX = next;
        followLatest = timeline.atXEnd;
        return true;
    }

    function showLatest() {
        scrollTo(timeline.contentWidth - timeline.width);
        followLatest = true;
    }

    Timer {
        id: latestTimer
        interval: 0
        onTriggered: root.showLatest()
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spacingS

        StyledText {
            id: deviceLabel
            width: parent.width
            text: root.deviceName
            visible: text !== ""
            color: Theme.onSurfaceVariant
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideMiddle
        }

        Item {
            id: navigation
            width: parent.width
            height: Theme.buttonHeightXS
            LayoutMirroring.enabled: false
            LayoutMirroring.childrenInherit: true

            StyledText {
                anchors.left: parent.left
                anchors.right: actions.left
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const start = new Date(root.viewStart * 1000).toLocaleDateString(I18n.locale(), "MMM d");
                    const end = new Date(root.viewEnd * 1000).toLocaleDateString(I18n.locale(), "MMM d");
                    return start === end ? start : `${start} - ${end}`;
                }
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.onSurfaceVariant
            }

            Row {
                id: actions
                anchors.right: parent.right
                spacing: Theme.spacingXXS
                LayoutMirroring.enabled: false
                LayoutMirroring.childrenInherit: true

                DankActionButton {
                    buttonSize: Theme.buttonHeightXS
                    iconName: "chevron_left"
                    Accessible.name: I18n.tr("Previous")
                    enabled: !timeline.atXBeginning
                    onClicked: root.scrollTo(timeline.contentX - timeline.width)
                }

                DankActionButton {
                    buttonSize: Theme.buttonHeightXS
                    iconName: "today"
                    Accessible.name: I18n.tr("Today")
                    enabled: !timeline.atXEnd
                    onClicked: root.showLatest()
                }

                DankActionButton {
                    buttonSize: Theme.buttonHeightXS
                    iconName: "chevron_right"
                    Accessible.name: I18n.tr("Next")
                    enabled: !timeline.atXEnd
                    onClicked: root.scrollTo(timeline.contentX + timeline.width)
                }
            }
        }

        Item {
            id: chart
            width: parent.width
            height: parent.height - navigation.height - timeLabels.height - parent.spacing * 2 - (deviceLabel.visible ? deviceLabel.height + parent.spacing : 0)
            LayoutMirroring.enabled: false
            LayoutMirroring.childrenInherit: true

            Repeater {
                model: 3

                Rectangle {
                    required property int index
                    width: timeline.width
                    height: Theme.dividerWidth
                    y: Theme.spacingXS + index * (chart.height - Theme.spacingXS * 2) / 2
                    color: Theme.outlineVariant
                }
            }

            DankFlickable {
                id: timeline
                width: parent.width - percentLabel.implicitWidth - Theme.spacingS
                height: parent.height
                contentWidth: width * Math.max(1, (root.rangeEnd - root.rangeStart) / root.visibleDuration)
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                wheelEnabled: false
                interactive: root.scrollable
                clip: true
                activeFocusOnTab: root.scrollable
                Accessible.role: Accessible.Chart
                Accessible.name: I18n.tr("History")

                onContentWidthChanged: {
                    if (root.followLatest)
                        latestTimer.restart();
                }
                onMovementStarted: root.followLatest = false
                onMovementEnded: root.followLatest = atXEnd

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Left:
                        root.scrollTo(contentX - width / 2);
                        break;
                    case Qt.Key_Right:
                        root.scrollTo(contentX + width / 2);
                        break;
                    case Qt.Key_Home:
                        root.scrollTo(0);
                        break;
                    case Qt.Key_End:
                        root.showLatest();
                        break;
                    default:
                        return;
                    }
                    event.accepted = true;
                }

                Item {
                    width: timeline.contentWidth
                    height: timeline.height

                    Repeater {
                        model: root.segments

                        DankSparkline {
                            required property var modelData
                            anchors.fill: parent
                            values: modelData.samples.map(sample => sample[1])
                            xValues: modelData.samples.map(sample => sample[0])
                            minimumX: root.rangeStart
                            maximumX: root.rangeEnd
                            maximum: 100
                            curved: false
                            lineColor: modelData.kind === "charging" ? Theme.primary : modelData.kind === "low" ? Theme.error : Theme.success
                            lineWidth: Theme.outlineWidthFocused
                            insetTop: Theme.spacingXS
                            insetBottom: Theme.spacingXS
                            showDots: values.length === 1
                            dotRadius: Theme.spacingXXS
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: timeline
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    if (wheel.angleDelta.x === 0 && wheel.pixelDelta.x === 0 && !(wheel.modifiers & Qt.ShiftModifier)) {
                        wheel.accepted = false;
                        return;
                    }
                    const pixels = wheel.pixelDelta.x || wheel.pixelDelta.y;
                    const steps = (wheel.angleDelta.x || wheel.angleDelta.y) / 120;
                    wheel.accepted = root.scrollTo(timeline.contentX - (pixels || steps * timeline.mouseWheelSpeed));
                }
            }

            FocusRing {
                anchors.fill: timeline
                radius: Theme.cornerRadiusXS
                visible: timeline.activeFocus
            }

            StyledText {
                id: percentLabel
                anchors.right: parent.right
                y: Theme.spacingXS - height / 2
                text: "100%"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.onSurfaceVariant
            }

            Repeater {
                model: [50, 0]

                StyledText {
                    required property int modelData
                    anchors.right: parent.right
                    y: Theme.spacingXS + (1 - modelData / 100) * (chart.height - Theme.spacingXS * 2) - height / 2
                    text: modelData + "%"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                }
            }
        }

        Item {
            id: timeLabels
            width: timeline.width
            height: timeLabelMetrics.height
            LayoutMirroring.enabled: false

            StyledText {
                id: timeLabelMetrics
                text: "00:00"
                font.pixelSize: Theme.fontSizeSmall
                visible: false
            }

            Repeater {
                model: 3

                StyledText {
                    required property int index
                    text: {
                        if (root.rangeEnd <= 1)
                            return "";
                        if (index === 2 && timeline.atXEnd)
                            return I18n.tr("now");
                        return new Date((root.viewStart + root.visibleDuration * index / 2) * 1000).toLocaleTimeString(I18n.locale(), SettingsData.use24HourClock ? "HH:mm" : "h:mm ap");
                    }
                    x: index * (timeLabels.width - width) / 2
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                }
            }
        }
    }
}
