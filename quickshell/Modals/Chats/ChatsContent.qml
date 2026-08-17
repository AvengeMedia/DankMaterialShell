pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Modals.Chats
import qs.Services
import qs.Widgets

// Two panes: conversations on the left, the open one on the right.
FocusScope {
    id: root

    signal closeRequested

    // Keeps the chat subscription alive for as long as the window exists.
    Ref {
        service: ChatService
    }

    function takeFocus() {
        searchField.forceActiveFocus();
    }

    readonly property bool hasProviders: ChatService.providers.length > 0

    // Message search results for the current query. The chat list filters
    // locally as you type; searching message bodies means asking the backend,
    // which is debounced so a query is not sent per keystroke.
    property var messageHits: []
    property bool searching: false

    readonly property bool showingResults: searchField.text.trim().length >= 2 && messageHits.length > 0

    function runSearch() {
        const query = searchField.text.trim();
        if (query.length < 2) {
            root.messageHits = [];
            return;
        }

        root.searching = true;
        ChatService.search(query, (messages, chats) => {
            root.searching = false;
            root.messageHits = messages || [];
        });
    }

    // The first enabled provider waiting to be signed in, if any. Sign-in takes
    // over the conversation pane, since nothing else there is actionable until
    // it is dealt with.
    readonly property var authProvider: {
        for (let i = 0; i < ChatService.providers.length; i++) {
            const provider = ChatService.providers[i];
            if (provider.enabled && provider.state === "needsLogin")
                return provider;
        }
        return null;
    }

    // Chats filtered by the search box. Archived conversations are hidden
    // unless the user is searching, since archiving means "keep this away".
    readonly property var visibleChats: {
        const query = searchField.text.trim().toLowerCase();
        const out = [];
        for (let i = 0; i < ChatService.chats.length; i++) {
            const chat = ChatService.chats[i];
            if (chat.archived && query === "")
                continue;
            if (query !== "") {
                const name = (chat.name || "").toLowerCase();
                const preview = (chat.lastText || "").toLowerCase();
                const subject = (chat.subject || "").toLowerCase();
                if (name.indexOf(query) === -1 && preview.indexOf(query) === -1 && subject.indexOf(query) === -1)
                    continue;
            }
            out.push(chat);
        }
        return out;
    }

    Timer {
        id: searchDebounce
        interval: 250
        onTriggered: root.runSearch()
    }

    Keys.onEscapePressed: event => {
        if (searchField.text !== "") {
            searchField.text = "";
            event.accepted = true;
            return;
        }
        root.closeRequested();
        event.accepted = true;
    }

    Row {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM

        // ---------------------------------------------------- conversations

        Item {
            width: 300
            height: parent.height

            Column {
                anchors.fill: parent
                spacing: Theme.spacingS

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankTextField {
                        id: searchField
                        width: parent.width - syncIndicator.width - Theme.spacingS
                        placeholderText: I18n.tr("Search conversations and messages")
                        leftIconName: "search"
                        showClearButton: true

                        onTextChanged: searchDebounce.restart()
                        Keys.onDownPressed: chatList.forceActiveFocus()
                    }

                    DankSpinner {
                        id: syncIndicator
                        anchors.verticalCenter: parent.verticalCenter
                        width: visible ? 20 : 0
                        height: 20
                        visible: ChatService.syncing
                    }
                }

                DankListView {
                    id: chatList
                    width: parent.width
                    height: parent.height - searchField.height - Theme.spacingS
                    clip: true
                    model: root.visibleChats
                    spacing: Theme.spacingXS
                    currentIndex: -1

                    delegate: ChatListItem {
                        required property var modelData

                        width: chatList.width
                        chat: modelData
                        selected: ChatService.activeProvider === modelData.provider && ChatService.activeChatId === modelData.id

                        onActivated: ChatService.openChat(modelData.provider, modelData.id)
                        onArchiveToggled: ChatService.setArchived(modelData.provider, modelData.id, !modelData.archived)
                        onMuteToggled: ChatService.setMuted(modelData.provider, modelData.id, !modelData.muted)
                    }
                }

                // Empty states say which of the three situations this is, since
                // the fix differs: install a plugin, enable one, or wait.
                StyledText {
                    width: parent.width
                    visible: root.visibleChats.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    text: {
                        if (!root.hasProviders)
                            return I18n.tr("No chat providers installed.\nAdd one from Settings → Plugins.");
                        if (!ChatService.hasEnabledProvider)
                            return I18n.tr("No chat providers enabled.\nTurn one on in Settings → Chats.");
                        if (searchField.text !== "")
                            return I18n.tr("No conversations match.");
                        return I18n.tr("No conversations yet.");
                    }
                }
            }
        }

        Rectangle {
            width: 1
            height: parent.height
            color: Theme.outline
            opacity: 0.2
        }

        // ---------------------------------------------------- conversation

        Item {
            width: parent.width - 300 - Theme.spacingM * 2 - 1
            height: parent.height

            AuthPanel {
                anchors.fill: parent
                visible: root.authProvider !== null
                provider: root.authProvider
            }

            // Message results take over the conversation pane while searching:
            // the point of the search is to find a message, not to keep reading
            // the one already open.
            ChatSearchResults {
                anchors.fill: parent
                visible: root.authProvider === null && root.showingResults
                hits: root.messageHits
                query: searchField.text.trim()

                onHitChosen: (provider, chatId, ts) => {
                    searchField.text = "";
                    root.messageHits = [];
                    ChatService.openChatAt(provider, chatId, ts);
                }
            }

            ConversationView {
                anchors.fill: parent
                visible: root.authProvider === null && !root.showingResults && ChatService.hasActiveChat
            }

            StyledText {
                anchors.centerIn: parent
                visible: root.authProvider === null && !root.showingResults && !ChatService.hasActiveChat
                text: I18n.tr("Select a conversation")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
            }
        }
    }
}
