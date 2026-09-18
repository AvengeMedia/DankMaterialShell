import QtQuick
import qs.Common

Item {
    property CcTile tile: null
    readonly property bool live: tile?.live ?? false
    readonly property int columns: tile?.columns ?? 4
    readonly property int rows: tile?.rows ?? 1
    readonly property color contentColor: tile?.contentColor ?? Theme.surfaceText
    readonly property color subtitleColor: tile?.subtitleColor ?? Theme.surfaceVariantText
}
