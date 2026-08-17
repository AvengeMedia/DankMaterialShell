pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modals.Chats
import Quickshell
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

    // The message under keyboard focus, as an index into ChatService.messages.
    // -1 means none, which is the resting state: the composer has focus and
    // typing should go there, not move a selection.
    property int focusedIndex: -1

    // The message awaiting a destination, or null. Forwarding needs a target,
    // and picking one is a choice the user has to make.
    property var forwardSource: null

    property bool showingHelp: false

    readonly property var focusedMessage: focusedIndex >= 0 && focusedIndex < ChatService.messages.length ? ChatService.messages[focusedIndex] : null

    // Alt+k/j walk the conversation. Alt rather than bare k/j because the
    // composer holds focus and bare letters have to keep reaching it.
    function focusPrevious() {
        const count = ChatService.messages.length;
        if (count === 0)
            return;
        // From nothing, start at the newest and walk back.
        root.focusedIndex = root.focusedIndex < 0 ? count - 1 : Math.max(0, root.focusedIndex - 1);
        messageList.positionViewAtIndex(root.focusedIndex, ListView.Contain);
    }

    function focusNext() {
        const count = ChatService.messages.length;
        if (count === 0 || root.focusedIndex < 0)
            return;
        root.focusedIndex = Math.min(count - 1, root.focusedIndex + 1);
        messageList.positionViewAtIndex(root.focusedIndex, ListView.Contain);
    }

    function clearFocus() {
        root.focusedIndex = -1;
    }

    // Opens whatever the focused message carries -- its attachment, or a link
    // in its text.
    function openFocused() {
        const msg = root.focusedMessage;
        if (!msg)
            return;

        if (msg.mediaPath) {
            Quickshell.execDetached(["xdg-open", msg.mediaPath]);
            return;
        }
        if (msg.mediaRef) {
            ChatService.fetchMedia(ChatService.activeProvider, ChatService.activeChatId, msg.id, path => {
                if (path)
                    Quickshell.execDetached(["xdg-open", path]);
            });
            return;
        }

        const link = (msg.text || "").match(/https?:\/\/[^\s]+/);
        if (link)
            Quickshell.execDetached(["xdg-open", link[0]]);
    }

    Connections {
        target: ChatService

        function onActiveChatIdChanged() {
            root.replyTarget = null;
            root.focusedIndex = -1;
        }
    }

    // Alt+k/j and Enter act on the focused message wherever focus sits inside
    // the conversation, including while typing.
    Keys.onPressed: event => {
        if (event.modifiers & Qt.AltModifier) {
            if (event.key === Qt.Key_K) {
                root.focusPrevious();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_J) {
                root.focusNext();
                event.accepted = true;
                return;
            }
        }

        if (event.key === Qt.Key_Question && (event.modifiers & Qt.ShiftModifier)) {
            root.showingHelp = !root.showingHelp;
            event.accepted = true;
            return;
        }

        if (root.showingHelp && event.key === Qt.Key_Escape) {
            root.showingHelp = false;
            event.accepted = true;
            return;
        }

        if (root.focusedIndex >= 0) {
            if (event.key === Qt.Key_Escape) {
                root.clearFocus();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.openFocused();
                event.accepted = true;
            }
        }
    }

    ChatKeybindHelp {
        anchors.fill: parent
        z: 20
        visible: root.showingHelp
        onDismissed: root.showingHelp = false
    }

    // Destination picker for a forward. An overlay rather than a separate
    // window: it is a short-lived choice about the conversation already open.
    ChatForwardPicker {
        anchors.fill: parent
        z: 10
        visible: root.forwardSource !== null
        source: root.forwardSource

        onCancelled: root.forwardSource = null
        onPicked: (provider, chatId) => {
            ChatService.forward(provider, chatId, root.forwardSource?.text ?? "");
            root.forwardSource = null;
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
                    iconName: "help"
                    iconColor: Theme.surfaceVariantText
                    tooltipText: I18n.tr("Keyboard Shortcuts")
                    onClicked: root.showingHelp = true
                }

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
                    keyboardFocused: root.focusedIndex === index
                    // The list is inverted, so the visually preceding message
                    // is the next one in the model.
                    previousMessage: index + 1 < ChatService.messages.length ? ChatService.messages[index + 1] : null

                    onReplyRequested: root.replyTarget = modelData
                    onDeleteRequested: ChatService.revoke(ChatService.activeProvider, ChatService.activeChatId, modelData.id)
                    onCopyRequested: {
                        Quickshell.execDetached([Proc.dmsBin, "cl", "copy", modelData.text || ""]);
                        ToastService.showInfo(I18n.tr("Copied to clipboard"));
                    }
                    onForwardRequested: root.forwardSource = modelData
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
