import QtQuick
import qs.Common
import qs.DCommon.Widgets

DFlickable {
    id: root

    default property alias content: column.data
    property alias spacing: column.spacing
    property alias columnWidth: column.width
    property real contentMaxWidth: SettingsMetrics.contentMaxWidth
    property Item fabBar: null

    anchors.fill: parent
    clip: true
    contentHeight: column.height + Theme.spacingXL
    contentWidth: width

    Column {
        id: column
        topPadding: Theme.spacingXS
        width: Math.min(root.contentMaxWidth, parent.width)
        bottomPadding: SettingsMetrics.pagePaddingV + (root.fabBar?.reservedHeight ?? 0)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spacingL
    }
}
