import QtQuick
import qs.Common
import qs.Widgets

Column {
    spacing: Theme.spacingM

    DankIcon {
        name: "music_note"
        size: Theme.iconSize * 3
        color: Theme.surfaceTextSecondary
        anchors.horizontalCenter: parent.horizontalCenter
    }

    StyledText {
        text: I18n.tr("No Active Players")
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.surfaceTextMedium
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
