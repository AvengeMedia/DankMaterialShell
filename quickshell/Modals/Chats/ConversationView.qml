pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modals.Chats
import qs.Services
import qs.Widgets

// The open conversation: header, messages, composer.
Item {
    id: root

    readonly property var chat: ChatService.activeChat
    readonly property string chatName: chat?.name || chat?.subject || ChatService.activeChatId

    // What the user is replying to, or null. Cleared when the conversation
    // changes, since a reply target from another chat is meaningless.
    property var replyTarget: null

    Connections {
        target: ChatService

        function onActiveChatIdChanged() {
            root.replyTarget = null;
        }
    }

    Column {
        anchors.fill: parent
        spacing: 0

        // ------------------------------------------------------------ header

        Item {
            width: parent.width
            height: 48

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: headerActions.left
                anchors.rightMargin: Theme.spacingS
                spacing: Theme.spacingS

                DankCircularImage {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    imageSource: root.chat?.avatarPath ? "file://" + root.chat.avatarPath : ""
                    fallbackText: root.chatName.charAt(0).toUpperCase()
                    fallbackIcon: "person"
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 32 - Theme.spacingS
                    spacing: 0

                    StyledText {
                        width: parent.width
                        text: root.chatName
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                    }

                    // Which service this conversation is on. Worth showing:
                    // the list interleaves providers, so the same person may
                    // appear more than once.
                    StyledText {
                        width: parent.width
                        text: {
                            const provider = ChatService.providerById(ChatService.activeProvider);
                            return provider ? provider.name : ChatService.activeProvider;
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                    }
                }
            }

            Row {
                id: headerActions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                DankActionButton {
                    buttonSize: 32
                    iconName: (root.chat?.muted ?? false) ? "notifications" : "notifications_off"
                    iconColor: Theme.surfaceVariantText
                    tooltipText: (root.chat?.muted ?? false) ? I18n.tr("Unmute") : I18n.tr("Mute")
                    onClicked: ChatService.setMuted(ChatService.activeProvider, ChatService.activeChatId, !(root.chat?.muted ?? false))
                }

                DankActionButton {
                    buttonSize: 32
                    iconName: (root.chat?.archived ?? false) ? "unarchive" : "archive"
                    iconColor: Theme.surfaceVariantText
                    tooltipText: (root.chat?.archived ?? false) ? I18n.tr("Unarchive") : I18n.tr("Archive")
                    onClicked: ChatService.setArchived(ChatService.activeProvider, ChatService.activeChatId, !(root.chat?.archived ?? false))
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outline
            opacity: 0.2
        }

        // ---------------------------------------------------------- messages

        Item {
            width: parent.width
            height: parent.height - 48 - 1 - composer.height

            DankListView {
                id: messageList
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                clip: true
                model: ChatService.messages
                spacing: Theme.spacingXS
                // Conversations are read from the bottom.
                verticalLayoutDirection: ListView.BottomToTop

                delegate: MessageBubble {
                    required property var modelData
                    required property int index

                    width: messageList.width
                    message: modelData
                    // The list is inverted, so the visually preceding message
                    // is the next one in the model.
                    previousMessage: index + 1 < ChatService.messages.length ? ChatService.messages[index + 1] : null

                    onReplyRequested: root.replyTarget = modelData
                }

                // Paging backwards happens at the visual top, which in an
                // inverted list is the end of the model.
                onAtYEndChanged: {
                    if (atYEnd && ChatService.hasMoreHistory && !ChatService.loadingHistory)
                        ChatService.loadOlder();
                }
            }

            DankSpinner {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingS
                width: 24
                height: 24
                visible: ChatService.loadingHistory && ChatService.messages.length > 0
            }

            StyledText {
                anchors.centerIn: parent
                visible: ChatService.messages.length === 0 && !ChatService.loadingHistory
                text: I18n.tr("No messages yet")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }

        // ---------------------------------------------------------- composer

        Composer {
            id: composer
            width: parent.width
            replyTarget: root.replyTarget

            onReplyCleared: root.replyTarget = null
            onSent: {
                root.replyTarget = null;
                messageList.positionViewAtBeginning();
            }
        }
    }
}
