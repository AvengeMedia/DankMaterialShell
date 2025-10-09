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
            text: "↑/↓: Nav • Space: Expand • Enter: Action/Expand • E: Text"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        StyledText {
            text: I18n.tr("Del: Clear • Shift+Del: Clear All • 1-9: Actions • F10: Help • Esc: Close")
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
