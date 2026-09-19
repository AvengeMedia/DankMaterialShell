import QtQuick
import qs.Common

Item {
    property CcTile tile: null
    readonly property bool live: tile?.live ?? false
    readonly property real columns: tile?.columns ?? 4
    readonly property real rows: tile?.rows ?? 1
    readonly property color contentColor: tile?.contentColor ?? Theme.surfaceText
    readonly property color subtitleColor: tile?.subtitleColor ?? Theme.surfaceVariantText
}
