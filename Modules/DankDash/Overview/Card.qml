import QtQuick
import QtQuick.Controls
import qs.Common

Rectangle {
    id: card

    property int pad: Theme.spacingM

    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1

    default property alias content: contentItem.data

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: card.pad
    }
}