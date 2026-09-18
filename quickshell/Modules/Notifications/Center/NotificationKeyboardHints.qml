import QtQuick
import qs.Common
import qs.Modules.Notifications
import qs.Widgets

Rectangle {
    id: root

    property bool showHints: false

    height: Theme.listItemTwoLineHeight + Theme.spacingS
    radius: NotificationMetrics.menuRadius
    color: Theme.foregroundColor(Theme.cardSurface, Theme.isFloatingWindow(root))
    border.color: Theme.primary
    border.width: Theme.outlineWidthFocused
    opacity: showHints ? 1 : 0
    z: 100

    Column {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingS
        spacing: Theme.spacingXXS

        StyledText {
            text: I18n.tr("↑/↓: Nav • Space: Expand • Enter: Action/Expand • E: Text")
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
