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
    // Each entry: { label, value, tooltip, advanced }; entries without a value are left out,
    // advanced ones only show while Advanced is expanded.
    property var leftStats: []
    property var rightStats: []
    default property alias content: slot.data
    property alias headerActions: headerActionsRow.data

    // Labels that had a value on this device keep their row (showing "—") so samples without the value don't
    // make the grid jump.
    property var seenLabels: ({})

    function hasValue(s) {
        return s.value !== null && s.value !== undefined && s.value !== "";
    }

    function present(list, advanced) {
        return (list ?? []).filter(s => s && (s.advanced === true) === advanced && (hasValue(s) || seenLabels[s.label])).map(s => hasValue(s) ? s : Object.assign({}, s, {
                    value: "—"
                }));
    }

    function rememberLabels() {
        const seen = Object.assign({}, seenLabels);
        let added = false;
        for (const s of leftStats.concat(rightStats)) {
            if (s && hasValue(s) && !seen[s.label]) {
                seen[s.label] = true;
                added = true;
            }
        }
        if (added)
            seenLabels = seen;
    }

    onTitleChanged: seenLabels = {}
    onLeftStatsChanged: rememberLabels()
    onRightStatsChanged: rememberLabels()

    contentWidth: width
    contentHeight: body.implicitHeight

    Column {
        id: body
        width: root.width
        spacing: Theme.spacingL

        Item {
            width: parent.width
            height: Math.max(titleColumn.implicitHeight, headerActionsRow.implicitHeight)

            Column {
                id: titleColumn
                width: parent.width - (headerActionsRow.implicitWidth > 0 ? headerActionsRow.implicitWidth + Theme.spacingL : 0)

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

            Row {
                id: headerActionsRow
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Theme.spacingS
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

        StatGrid {
            leftGroup: root.present(root.leftStats, false)
            rightGroup: root.present(root.rightStats, false)
        }

        DButton {
            visible: advancedGrid.hasStats
            text: ProcessListMetrics.showAdvanced ? I18n.tr("Hide advanced", "button: hide the less used details") : I18n.tr("Show advanced", "button: show the less used details")
            backgroundColor: "transparent"
            textColor: Theme.primary
            onClicked: ProcessListMetrics.showAdvanced = !ProcessListMetrics.showAdvanced
        }

        StatGrid {
            id: advancedGrid
            leftGroup: root.present(root.leftStats, true)
            rightGroup: root.present(root.rightStats, true)
            visible: hasStats && ProcessListMetrics.showAdvanced
        }
    }

    component StatGrid: Grid {
        id: statGrid

        property var leftGroup: []
        property var rightGroup: []
        readonly property bool hasStats: leftGroup.length + rightGroup.length > 0
        readonly property real cellWidth: columns === 2 ? (width - columnSpacing) / 2 : width

        width: parent.width
        columns: width >= Theme.navigationRailWidth * 6 ? 2 : 1
        columnSpacing: Theme.spacingL
        rowSpacing: Theme.spacingL

        StatGroup {
            width: statGrid.cellWidth
            stats: statGrid.leftGroup
        }

        StatGroup {
            width: statGrid.cellWidth
            stats: statGrid.rightGroup
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
