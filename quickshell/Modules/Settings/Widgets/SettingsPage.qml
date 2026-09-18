import QtQuick
import qs.Common
import qs.Widgets

DankFlickable {
    id: root

    default property alias content: column.data
    property alias spacing: column.spacing
    property alias columnWidth: column.width
    property int contentMaxWidth: SettingsMetrics.contentMaxWidth

    anchors.fill: parent
    clip: true
    contentHeight: column.height + Theme.spacingXL
    contentWidth: width

    Column {
        id: column
        topPadding: Theme.spacingXS
        width: Math.min(root.contentMaxWidth, parent.width - Theme.spacingL * 2)
        bottomPadding: SettingsMetrics.pagePaddingV
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spacingL
    }
}
