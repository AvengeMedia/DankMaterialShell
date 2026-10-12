pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Settings.Widgets

DFlickable {
    id: root
    clip: true

    property string title: ""
    property string titleTooltip: ""
    property string subtitle: ""
    property string subtitle2: ""
    property bool showChart: true
    property string chartLabel: ""
    property string chartValue: ""
    property string chartSecondaryLabel: ""
    property string chartSecondaryValue: ""
    property var values: []
    property var secondaryValues: []
    property real maximum: 0
    property string maximumText: ""
    // Each entry: { label, value, tooltip }; entries without a value are left out.
    property var leftStats: []
    property var rightStats: []
    default property alias content: slot.data

    function present(list) {
        return (list ?? []).filter(s => s && s.value !== null && s.value !== undefined && s.value !== "");
    }

    contentWidth: width
    contentHeight: body.implicitHeight

    Column {
        id: body
        width: root.width
        spacing: Theme.spacingL

        Column {
            width: parent.width

            StyledText {
                id: titleText
                width: parent.width
                text: root.title
                font.pixelSize: Theme.fontSizeXXLarge
                color: Theme.surfaceText
                elide: Text.ElideRight
                maximumLineCount: 1

                MouseArea {
                    id: titleHover
                    anchors.fill: parent
                    enabled: root.titleTooltip !== ""
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                DTooltipHost {
                    text: root.titleTooltip
                    target: titleText
                    hoverArea: titleHover
                }
            }

            StyledText {
                visible: text !== ""
                width: parent.width
                text: root.subtitle
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }

            StyledText {
                visible: text !== ""
                width: parent.width
                text: root.subtitle2
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }
        }

        ChartCard {
            visible: root.showChart
            width: parent.width
            chartHeight: Theme.listItemHeight * 4
            label: root.chartLabel
            valueText: root.chartValue
            secondaryLabel: root.chartSecondaryLabel
            secondaryValueText: root.chartSecondaryValue
            values: root.values
            secondaryValues: root.secondaryValues
            maximum: root.maximum
            maximumText: root.maximumText
            historyLength: DgopService.deviceHistorySize
        }

        Column {
            id: slot
            width: parent.width
            spacing: Theme.spacingL
            visible: children.length > 0
        }

        Grid {
            id: statGrid

            readonly property real cellWidth: columns === 2 ? (width - columnSpacing) / 2 : width

            width: parent.width
            columns: width >= Theme.navigationRailWidth * 6 ? 2 : 1
            columnSpacing: Theme.spacingL
            rowSpacing: Theme.spacingL

            StatGroup {
                width: statGrid.cellWidth
                stats: root.present(root.leftStats)
            }

            StatGroup {
                width: statGrid.cellWidth
                stats: root.present(root.rightStats)
            }
        }
    }

    component StatGroup: SettingsGroup {
        id: group

        property var stats: []

        visible: stats.length > 0
        customPaddingV: 0
        customPaddingH: Theme.spacingL

        Repeater {
            model: group.stats.length

            StatRow {
                required property int index
                readonly property var stat: group.stats[index] ?? ({})

                label: stat.label ?? ""
                value: String(stat.value ?? "")
                tooltip: stat.tooltip ?? ""
            }
        }
    }
}
