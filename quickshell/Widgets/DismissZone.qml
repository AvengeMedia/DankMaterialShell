import QtQuick
import qs.Common

// Defines the screen area (excluding bars) that dismisses popouts
QtObject {
    id: root

    property int barPosition: 0
    property real barX: 0
    property real barY: 0
    property real barWidth: 0
    property real barHeight: 0
    property real screenWidth: 0
    property real screenHeight: 0
    property var adjacentBarInfo: null

    readonly property real _leftExclusion: (barPosition === SettingsData.Position.Left && barWidth > 0) ? Math.max(0, barX + barWidth) : 0
    readonly property real _topExclusion: (barPosition === SettingsData.Position.Top && barHeight > 0) ? Math.max(0, barY + barHeight) : 0
    readonly property real _rightExclusion: (barPosition === SettingsData.Position.Right && barWidth > 0) ? Math.max(0, screenWidth - barX) : 0
    readonly property real _bottomExclusion: (barPosition === SettingsData.Position.Bottom && barHeight > 0) ? Math.max(0, screenHeight - barY) : 0

    readonly property real x: Math.max(_leftExclusion, adjacentBarInfo?.leftBar ?? 0)
    readonly property real y: Math.max(_topExclusion, adjacentBarInfo?.topBar ?? 0)
    readonly property real width: Math.max(100, screenWidth - x - Math.max(_rightExclusion, adjacentBarInfo?.rightBar ?? 0))
    readonly property real height: Math.max(100, screenHeight - y - Math.max(_bottomExclusion, adjacentBarInfo?.bottomBar ?? 0))
}
