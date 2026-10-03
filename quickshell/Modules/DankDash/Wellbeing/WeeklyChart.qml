pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.DankDash
import "Wellbeing.js" as Wellbeing

DankCard {
    id: root

    property var week: []
    property real limitSeconds: 0
    property bool showTitle: true
    property int hoverIndex: -1

    readonly property real total: Wellbeing.totalSeconds(week)
    readonly property real peak: Math.max(limitSeconds, ...week.map(day => day.active))
    readonly property var axis: Wellbeing.axis(peak)
    readonly property var hoverDay: hoverIndex >= 0 && hoverIndex < week.length ? week[hoverIndex] : null
    readonly property real columnWidth: week.length > 0 ? plot.width / week.length : 0
    readonly property real barWidth: columnWidth * WellbeingMetrics.barWidthRatio
    readonly property color pastColor: Theme.primaryContainer
    readonly property color todayColor: Theme.primary
    readonly property color overColor: Theme.error

    function barColor(day) {
        if (limitSeconds > 0 && day.active > limitSeconds)
            return overColor;
        return day.today ? todayColor : pastColor;
    }

    function yFor(seconds) {
        return plot.height * (1 - Math.min(1, seconds / axis.top));
    }

    function dayLabel(day) {
        return Qt.locale().dayName(day.weekday, Locale.ShortFormat);
    }

    restRadius: DashMetrics.cardRadius
    pad: Theme.spacingL
    Accessible.role: Accessible.Chart
    Accessible.name: I18n.tr("Weekly screen time")

    Column {
        anchors.fill: parent
        spacing: Theme.spacingS

        StyledText {
            width: parent.width
            visible: root.showTitle
            text: I18n.tr("Weekly screen time")
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Theme.fontWeightMedium
            color: root.contentColor
            elide: Text.ElideRight
        }

        Row {
            spacing: Theme.spacingS

            StyledText {
                anchors.baseline: caption.baseline
                text: WellbeingService.formatDuration(root.hoverDay ? root.hoverDay.active : root.total)
                font.pixelSize: Theme.fontSizeXLarge
                font.weight: Theme.fontWeightBold
                font.features: ({
                        "tnum": 1
                    })
                color: root.accentColor
            }

            StyledText {
                id: caption
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.spacingXXS
                text: root.hoverDay ? root.dayLabel(root.hoverDay) : I18n.tr("Total")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightMedium
                font.capitalization: Font.AllUppercase
                color: root.mutedColor
            }
        }

        Item {
            width: parent.width
            height: parent.height - y
            LayoutMirroring.enabled: false
            LayoutMirroring.childrenInherit: true

            Item {
                id: plot
                anchors.left: parent.left
                anchors.right: axisLabels.left
                anchors.rightMargin: Theme.spacingS
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingS
                anchors.bottom: dayLabels.top
                anchors.bottomMargin: Theme.spacingXS

                Repeater {
                    model: root.axis.ticks

                    Rectangle {
                        required property int modelData
                        width: plot.width
                        height: Theme.dividerWidth
                        y: root.yFor(modelData * Wellbeing.secondsPerHour) - height / 2
                        color: Theme.outlineVariant
                    }
                }

                Repeater {
                    model: root.week

                    Rectangle {
                        id: bar
                        required property var modelData
                        required property int index
                        readonly property real targetHeight: Math.max(0, plot.height - root.yFor(modelData.active))
                        x: index * root.columnWidth + (root.columnWidth - width) / 2
                        y: plot.height - height
                        width: root.barWidth
                        height: targetHeight
                        visible: !modelData.future && modelData.active > 0
                        topLeftRadius: Theme.cornerRadiusS
                        topRightRadius: Theme.cornerRadiusS
                        color: root.barColor(modelData)
                        opacity: root.hoverIndex === -1 || root.hoverIndex === index ? 1 : WellbeingMetrics.dimmedBarOpacity

                        Behavior on height {
                            enabled: DashMetrics.animationsEnabled
                            NumberAnimation {
                                duration: DashMetrics.meterDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.expressiveCurves.standard
                            }
                        }
                    }
                }

                Shape {
                    anchors.fill: parent
                    visible: root.limitSeconds > 0
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: root.overColor
                        strokeWidth: Theme.outlineWidthFocused
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [3, 3]
                        fillColor: "transparent"
                        capStyle: ShapePath.FlatCap
                        startX: 0
                        startY: root.yFor(root.limitSeconds)

                        PathLine {
                            x: plot.width
                            y: root.yFor(root.limitSeconds)
                        }
                    }
                }

                StyledText {
                    anchors.right: parent.right
                    y: root.yFor(root.limitSeconds) - height - Theme.spacingXXS
                    visible: root.limitSeconds > 0
                    text: I18n.tr("Limit", "label on the daily screen time limit line of a chart")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightBold
                    font.capitalization: Font.AllUppercase
                    color: root.overColor
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    hoverEnabled: true
                    onPositionChanged: mouse => root.hoverIndex = root.columnWidth > 0 ? Math.floor(mouse.x / root.columnWidth) : -1
                    onExited: root.hoverIndex = -1
                }
            }

            Item {
                id: axisLabels
                anchors.right: parent.right
                anchors.top: plot.top
                anchors.bottom: plot.bottom
                width: WellbeingMetrics.axisLabelWidth

                Repeater {
                    model: root.axis.ticks

                    StyledText {
                        required property int modelData
                        anchors.right: axisLabels.right
                        y: root.yFor(modelData * Wellbeing.secondsPerHour) - height / 2
                        text: I18n.tr("%1h").arg(modelData)
                        font.pixelSize: Theme.fontSizeSmall
                        font.features: ({
                                "tnum": 1
                            })
                        color: root.mutedColor
                    }
                }
            }

            Row {
                id: dayLabels
                anchors.left: plot.left
                anchors.right: plot.right
                anchors.bottom: parent.bottom
                height: Theme.fontSizeSmall + Theme.spacingXS

                Repeater {
                    model: root.week

                    StyledText {
                        required property var modelData
                        width: root.columnWidth
                        horizontalAlignment: Text.AlignHCenter
                        text: root.dayLabel(modelData)
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: modelData.today ? Theme.fontWeightBold : Theme.fontWeightMedium
                        color: modelData.today ? root.accentColor : root.mutedColor
                    }
                }
            }
        }
    }
}
