import QtQuick
import qs.Common
import qs.Widgets

// One possible conversation in the popout's disambiguation list.
StyledRect {
    id: root

    required property var candidate

    signal chosen

    readonly property string displayName: candidate?.name || candidate?.chatId || ""
    readonly property string providerLabel: candidate?.providerName || candidate?.provider || ""
    readonly property bool isGroup: candidate?.isGroup ?? false
    readonly property int unread: candidate?.unread ?? 0

    height: 52
    radius: Theme.cornerRadius
    color: hover.containsMouse ? Theme.surfaceHover : "transparent"

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.chosen()
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingS
        anchors.rightMargin: Theme.spacingS
        spacing: Theme.spacingS

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.isGroup ? "group" : "person"
            size: Theme.iconSize
            color: Theme.surfaceVariantText
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Theme.iconSize - Theme.spacingS * 2 - badge.width
            spacing: 2

            StyledText {
                width: parent.width
                text: root.displayName
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                elide: Text.ElideRight
            }

            // Which service. The same person can appear on more than one, and
            // that is exactly when this list gets shown.
            StyledText {
                width: parent.width
                text: root.providerLabel
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
            }
        }

        Item {
            id: badge
            anchors.verticalCenter: parent.verticalCenter
            width: root.unread > 0 ? unreadPill.width : 0
            height: 18

            StyledRect {
                id: unreadPill
                visible: root.unread > 0
                width: Math.max(18, unreadText.implicitWidth + Theme.spacingS)
                height: 18
                radius: 9
                color: Theme.primary

                StyledText {
                    id: unreadText
                    anchors.centerIn: parent
                    text: root.unread > 99 ? "99+" : root.unread
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onPrimary
                }
            }
        }
    }
}
