pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Modals.Chats
import qs.Services
import qs.Widgets

// The open conversation: header, messages, composer.
FocusScope {
    id: root

    readonly property var chat: ChatService.activeChat
    readonly property string chatName: chat?.name || chat?.subject || ChatService.activeChatId

    // What the user is replying to, or null. Cleared when the conversation
    // changes, since a reply target from another chat is meaningless.
    property var replyTarget: null

    // The message awaiting a destination, or null.
    property var forwardSource: null

    property bool showingHelp: false

    // A pending destructive action, held until confirmed. Deleting a message is
    // not undoable, and a mistyped key should not be enough to do it.
    property var pendingDelete: null
    property bool pendingDeleteForEveryone: false

    // The selected message, as an index into ChatService.messages.
    //
    // Deliberately not real focus: the composer keeps that, so typing always
    // reaches the text field. This is a border drawn around one message and
    // moved with Alt+K/J.
    property int selectedIndex: -1

    readonly property var selectedMessage: selectedIndex >= 0 && selectedIndex < ChatService.messages.length ? ChatService.messages[selectedIndex] : null

    // True while anything is layered over the conversation. Escape belongs to
    // the overlay then, and the modal must not act on it.
    readonly property bool hasOverlay: showingHelp || pendingDelete !== null || forwardSource !== null

    // Whatever closes an overlay puts focus back on the composer, so Escape
    // keeps working and typing keeps landing in the text field.
    onHasOverlayChanged: {
        if (!hasOverlay)
            Qt.callLater(() => composer.takeFocus());
    }

    function takeFocus() {
        composer.takeFocus();
    }

    // ------------------------------------------------------------- selection

    function selectPrevious() {
        const count = ChatService.messages.length;
        if (count === 0)
            return;
        // From nothing, start at the newest and walk back.
        root.selectedIndex = root.selectedIndex < 0 ? count - 1 : Math.max(0, root.selectedIndex - 1);
        messageList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
    }

    function selectNext() {
        const count = ChatService.messages.length;
        if (count === 0 || root.selectedIndex < 0)
            return;
        root.selectedIndex = Math.min(count - 1, root.selectedIndex + 1);
        messageList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
    }

    function clearSelection() {
        root.selectedIndex = -1;
    }

    // --------------------------------------------------------------- actions

    function openSelected() {
        const msg = root.selectedMessage;
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

    // copyMessage puts the message on the clipboard: an attachment goes as a
    // file, so it can be pasted into anything that takes one, and text as text.
    function copyMessage(msg) {
        if (!msg)
            return;

        if (msg.mediaPath) {
            ChatService.copyFileToClipboard(msg.mediaPath);
            return;
        }

        if (msg.mediaRef) {
            ChatService.fetchMedia(ChatService.activeProvider, ChatService.activeChatId, msg.id, path => {
                if (path)
                    ChatService.copyFileToClipboard(path);
            });
            return;
        }

        if ((msg.text || "") === "")
            return;

        // wl-copy rather than the clipboard manager, so text lands the same way
        // an attachment does and is immediately readable by wl-paste.
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", msg.text]);
        ToastService.showInfo(I18n.tr("Copied to clipboard"));
    }

    function requestDelete(msg, forEveryone) {
        if (!msg)
            return;
        if (forEveryone && !ChatService.activeSupports("revoke"))
            return;
        root.pendingDeleteForEveryone = forEveryone;
        root.pendingDelete = msg;
    }

    function confirmDelete() {
        const msg = root.pendingDelete;
        if (!msg)
            return;

        if (root.pendingDeleteForEveryone)
            ChatService.revoke(ChatService.activeProvider, ChatService.activeChatId, msg.id);
        else
            ChatService.deleteLocal(ChatService.activeProvider, ChatService.activeChatId, msg.id);

        root.pendingDelete = null;
        root.clearSelection();
    }

    function replyToSelected() {
        if (root.selectedMessage && ChatService.activeSupports("reply"))
            root.replyTarget = root.selectedMessage;
    }

    function forwardSelected() {
        if (root.selectedMessage && (root.selectedMessage.text || "") !== "")
            root.forwardSource = root.selectedMessage;
    }

    Connections {
        target: ChatService

        function onActiveChatIdChanged() {
            root.replyTarget = null;
            root.selectedIndex = -1;
            root.pendingDelete = null;
            Qt.callLater(() => messageList.positionViewAtEnd());
        }

        function onMessagesChanged() {
            // Stay pinned to the newest message unless the user has scrolled up
            // to read something.
            if (messageList.atYEnd || root.selectedIndex < 0)
                Qt.callLater(() => messageList.positionViewAtEnd());
        }
    }

    // Shortcuts rather than Keys handlers: the composer holds real focus and
    // consumes most key events, so a handler on this scope would never see them.
    Shortcut {
        sequences: ["Alt+K"]
        onActivated: root.selectPrevious()
    }

    Shortcut {
        sequences: ["Alt+J"]
        onActivated: root.selectNext()
    }

    Shortcut {
        sequences: ["Alt+R"]
        onActivated: root.replyToSelected()
    }

    Shortcut {
        sequences: ["Alt+F"]
        onActivated: root.forwardSelected()
    }

    // Paste is intercepted rather than left to the text field, which consumes
    // Ctrl+V before anything wrapping it is told. The composer then handles
    // both cases: an image is staged, text is inserted at the cursor.
    Shortcut {
        sequences: ["Ctrl+V"]
        enabled: !root.hasOverlay
        onActivated: composer.paste()
    }

    // Ctrl+Shift+C rather than Ctrl+C: the composer always holds focus, so
    // plain Ctrl+C has to stay available for the text the user selected there.
    Shortcut {
        sequences: ["Ctrl+Shift+C"]
        enabled: root.selectedIndex >= 0
        onActivated: root.copyMessage(root.selectedMessage)
    }

    Shortcut {
        sequences: ["Shift+Delete"]
        enabled: root.selectedIndex >= 0 && !root.hasOverlay
        onActivated: root.requestDelete(root.selectedMessage, true)
    }

    Shortcut {
        sequences: ["Delete"]
        enabled: root.selectedIndex >= 0 && !root.hasOverlay
        onActivated: root.requestDelete(root.selectedMessage, false)
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            if (root.pendingDelete) {
                root.pendingDelete = null;
                event.accepted = true;
                return;
            }
            if (root.showingHelp) {
                root.showingHelp = false;
                event.accepted = true;
                return;
            }
            if (root.selectedIndex >= 0) {
                root.clearSelection();
                event.accepted = true;
                return;
            }
        }

        // Shift+Enter opens the selected message's attachment or link. Plain
        // Enter always sends, because the composer always holds focus.
        if ((event.modifiers & Qt.ShiftModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            if (root.selectedIndex >= 0) {
                root.openSelected();
                event.accepted = true;
            }
        }
    }

    // ------------------------------------------------------------- overlays

    ChatKeybindHelp {
        anchors.fill: parent
        z: 20
        visible: root.showingHelp
        focus: visible
        onDismissed: root.showingHelp = false
    }

    ChatDeleteConfirm {
        anchors.fill: parent
        z: 25
        visible: root.pendingDelete !== null
        focus: visible
        forEveryone: root.pendingDeleteForEveryone
        message: root.pendingDelete

        onConfirmed: root.confirmDelete()
        onCancelled: root.pendingDelete = null
    }

    // Destination picker for a forward. An overlay rather than a separate
    // window: it is a short-lived choice about the conversation already open.
    ChatForwardPicker {
        anchors.fill: parent
        z: 10
        visible: root.forwardSource !== null
        focus: visible
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
            height: 52

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: headerActions.left
                anchors.rightMargin: Theme.spacingS
                spacing: Theme.spacingS

                DankCircularImage {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    imageSource: root.chat?.avatarPath ? "file://" + root.chat.avatarPath : ""
                    fallbackText: root.chatName.charAt(0).toUpperCase()
                    fallbackIcon: "person"
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 34 - Theme.spacingS
                    spacing: 0

                    StyledText {
                        width: parent.width
                        text: root.chatName
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                    }

                    // Who this is, in the service's own terms: the number or
                    // address they are reachable at, and which service it is.
                    // The same person can appear on more than one.
                    StyledText {
                        width: parent.width
                        text: {
                            const parts = [];
                            const handles = root.chat?.handles ?? [];
                            for (let i = 0; i < handles.length; i++)
                                parts.push(handles[i]);

                            const provider = ChatService.providerById(ChatService.activeProvider);
                            parts.push(provider ? provider.name : ChatService.activeProvider);

                            if (root.chat?.isGroup)
                                parts.push(I18n.tr("Group"));

                            return parts.join("  ·  ");
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
            height: parent.height - 52 - 1 - composer.height

            DankListView {
                id: messageList
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                clip: true
                model: ChatService.messages
                spacing: Theme.spacingXS

                // Chronological, top to bottom, parked at the end. An inverted
                // list renders a chronological model newest-first and makes
                // "scroll to the bottom" mean the wrong end of the history.
                verticalLayoutDirection: ListView.TopToBottom

                delegate: MessageBubble {
                    required property var modelData
                    required property int index

                    width: messageList.width
                    message: modelData
                    selected: root.selectedIndex === index
                    previousMessage: index > 0 ? ChatService.messages[index - 1] : null

                    onReplyRequested: root.replyTarget = modelData
                    onForwardRequested: root.forwardSource = modelData
                    onCopyRequested: root.copyMessage(modelData)
                    onDeleteRequested: root.requestDelete(modelData, ChatService.activeSupports("revoke"))
                }

                // Older messages page in at the top, which is where the
                // conversation continues backwards.
                onAtYBeginningChanged: {
                    if (atYBeginning && ChatService.hasMoreHistory && !ChatService.loadingHistory)
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
                root.clearSelection();
                Qt.callLater(() => messageList.positionViewAtEnd());
            }
        }
    }
}
