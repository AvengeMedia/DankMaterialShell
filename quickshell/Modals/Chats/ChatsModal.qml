pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modals.Chats
import qs.Modals.Common
import qs.Services

// The chat window.
//
// Provider-agnostic by construction: it renders whatever the backend's store
// holds and gates its affordances on what each provider declared it can do, so
// a new chat plugin needs no changes here. See docs/CHAT-PLUGINS.md.
DankModal {
    id: chatsModal

    layerNamespace: "dms:chats"

    modalWidth: 900
    modalHeight: 620
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    cornerRadius: Theme.cornerRadius
    // Kept loaded: reopening should land back in the conversation you left,
    // and rebuilding the message list on every open is visibly slow.
    keepContentLoaded: true
    visible: false

    // While the conversation has an overlay up -- help, a delete confirmation,
    // a forward picker -- Escape belongs to that overlay. Without this the
    // whole window closes on the first press and the overlay never sees it.
    closeOnEscapeKey: !(contentLoader.item?.hasOverlay ?? false)

    function toggle() {
        if (shouldBeVisible) {
            hide();
            return;
        }
        show();
    }

    function show() {
        open();
        shouldHaveFocus = true;

        Qt.callLater(() => {
            ChatService.refresh();
            // Re-assert focus so the backend knows the conversation is on
            // screen again and stops notifying for it.
            if (ChatService.hasActiveChat) {
                ChatService.setFocus(ChatService.activeProvider, ChatService.activeChatId);
                ChatService.markRead();
            }
            contentLoader.item?.takeFocus();
        });
    }

    function hide() {
        // Tell the backend nothing is on screen, so messages notify again.
        ChatService.setFocus("", "");
        Qt.callLater(() => chatsModal.close());
    }

    // showChat opens straight into a conversation, for the launcher and IPC.
    function showChat(provider, chatId) {
        show();
        Qt.callLater(() => ChatService.openChat(provider, chatId));
    }

    onDialogClosed: {
        ChatService.setFocus("", "");
        // Next press of the cycle binding starts from the newest unread chat
        // rather than resuming a rotation the user has visibly finished with.
        ChatCycleService.reset();
    }

    content: Component {
        ChatsContent {
            onCloseRequested: chatsModal.hide()
        }
    }

    // Constructs ChatService with the shell.
    //
    // A QML singleton is not built until something references it, and until it
    // exists nothing restores the providers the user enabled -- so without this
    // chat would only reconnect once the window was opened by hand. It takes no
    // subscription: notifications are raised by the backend, so live updates
    // are only needed while the UI is actually on screen.
    //
    // Deferred behind a Loader flipped by Qt.callLater rather than referenced
    // directly, because a singleton built during shell construction initialises
    // before its own dependencies are ready.
    Loader {
        id: warmup
        active: false
        sourceComponent: Item {
            Component.onCompleted: {
                if (ChatService.available)
                    ChatService.refresh();
            }
        }
    }

    Component.onCompleted: Qt.callLater(() => warmup.active = true)
}
