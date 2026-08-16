import QtQuick
import qs.Common
import qs.Widgets

// One conversation in the sidebar.
//
// Archive and mute are revealed on hover rather than behind a context menu:
// the shell's context menus are separate PanelWindows, which is far too heavy
// for a list row.
StyledRect {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    required property var chat
    property bool selected: false

    signal activated
    signal archiveToggled
    signal muteToggled

    readonly property int unread: chat?.unread ?? 0
    readonly property bool hasUnread: unread > 0
    readonly property bool muted: chat?.muted ?? false
    readonly property bool archived: chat?.archived ?? false
    readonly property string displayName: chat?.name || chat?.subject || chat?.id || ""

    // Actions crowd the row, so the timestamp and badge yield to them on hover.
    readonly property bool showActions: mouseArea.containsMouse || archiveButton.pressed || muteButton.pressed

    function formatTime(timestamp) {
        if (!timestamp)
            return "";

        const date = new Date(timestamp);
        const now = new Date();
        const timeStr = SettingsData.use24HourClock ? date.toLocaleTimeString(Qt.locale(), "HH:mm") : date.toLocaleTimeString(Qt.locale(), "h:mm AP");

        const sameDay = date.toDateString() === now.toDateString();
        if (sameDay)
            return timeStr;

        const days = Math.floor((now.getTime() - timestamp) / 86400000);
        if (days < 7)
            return date.toLocaleDateString(Qt.locale(), "ddd");
        return date.toLocaleDateString(Qt.locale(), "d MMM");
    }

    height: 56
    radius: Theme.cornerRadius
    color: {
        if (root.selected)
            return Theme.primarySelected;
        return mouseArea.containsMouse ? Theme.surfaceHover : "transparent";
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingS
        anchors.rightMargin: Theme.spacingS
        spacing: Theme.spacingS

        DankCircularImage {
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            imageSource: root.chat?.avatarPath ? "file://" + root.chat.avatarPath : ""
            // Providers frequently have no avatar; an initial reads better than
            // a generic glyph repeated down the whole list.
            fallbackText: root.displayName.charAt(0).toUpperCase()
            fallbackIcon: "person"
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 36 - Theme.spacingS * 2 - trailing.width
            spacing: 2

            Row {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    width: Math.min(implicitWidth, parent.width - (root.muted ? mutedIcon.width + Theme.spacingXS : 0))
                    text: root.displayName
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: root.hasUnread ? Font.DemiBold : Font.Normal
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                }

                DankIcon {
                    id: mutedIcon
                    anchors.verticalCenter: parent.verticalCenter
                    name: "notifications_off"
                    size: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    visible: root.muted
                }
            }

            StyledText {
                width: parent.width
                text: root.chat?.lastText || ""
                font.pixelSize: Theme.fontSizeSmall
                color: root.hasUnread ? Theme.surfaceText : Theme.surfaceVariantText
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Item {
            id: trailing
            anchors.verticalCenter: parent.verticalCenter
            width: root.showActions ? 64 : Math.max(32, timeText.implicitWidth)
            height: 36

            Column {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                visible: !root.showActions

                StyledText {
                    id: timeText
                    anchors.right: parent.right
                    text: root.formatTime(root.chat?.lastTs ?? 0)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledRect {
                    anchors.right: parent.right
                    visible: root.hasUnread
                    width: Math.max(18, unreadText.implicitWidth + Theme.spacingS)
                    height: 18
                    radius: 9
                    color: root.muted ? Theme.surfaceVariantText : Theme.primary

                    StyledText {
                        id: unreadText
                        anchors.centerIn: parent
                        text: root.unread > 99 ? "99+" : root.unread
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.onPrimary
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                visible: root.showActions

                DankActionButton {
                    id: muteButton
                    buttonSize: 28
                    iconSize: Theme.fontSizeMedium
                    iconName: root.muted ? "notifications" : "notifications_off"
                    iconColor: Theme.surfaceVariantText
                    tooltipText: root.muted ? I18n.tr("Unmute") : I18n.tr("Mute")
                    onClicked: root.muteToggled()
                }

                DankActionButton {
                    id: archiveButton
                    buttonSize: 28
                    iconSize: Theme.fontSizeMedium
                    iconName: root.archived ? "unarchive" : "archive"
                    iconColor: Theme.surfaceVariantText
                    tooltipText: root.archived ? I18n.tr("Unarchive") : I18n.tr("Archive")
                    onClicked: root.archiveToggled()
                }
            }
        }
    }
}
