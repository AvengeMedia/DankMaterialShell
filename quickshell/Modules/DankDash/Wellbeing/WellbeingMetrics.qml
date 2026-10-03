pragma Singleton

import QtQuick
import Quickshell
import qs.Common
import qs.Modules.DankDash

Singleton {
    readonly property real chartHeight: DashMetrics.gridRowUnit * 2.5
    readonly property real barWidthRatio: 0.72
    readonly property real dimmedBarOpacity: 0.55
    readonly property real axisLabelWidth: 28
    readonly property real appNameWidth: 120
    readonly property real appRowHeight: Theme.listItemHeight
    readonly property int listedApps: 12
    readonly property int cardApps: 3
    readonly property int defaultLimitMinutes: 60
    readonly property int retentionDays: 92
}
