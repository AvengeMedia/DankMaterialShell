import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property bool showHints: false

    height: 80
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.95)
    border.color: Theme.primary
    border.width: 2
    opacity: showHints ? 1 : 0
    z: 100

    Column {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingS
        spacing: 2

        StyledText {
            text: I18n.tr("Tab/Shift+Tab: Nav • ←→↑↓: Grid Nav • Enter/Space: Select")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        StyledText {
            text: I18n.tr("Alt+←/Backspace: Back • F1/I: File Info • F10: Help • Esc: Close")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }
}
