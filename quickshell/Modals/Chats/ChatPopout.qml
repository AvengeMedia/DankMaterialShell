pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modals.Chats
import qs.Modals.Common
import qs.Services
import qs.Widgets

// A single conversation, on its own.
//
// Distinct from the full chat window: no conversation list, no navigation --
// just one thread, opened by name, number or id. It exists for the quick reply,
// where opening the whole window and hunting for a person is more work than the
// reply itself.
//
// When a query matches more than one conversation it asks rather than guessing,
// because opening the wrong chat means sending a message to the wrong person.
DankModal {
    id: chatPopout

    layerNamespace: "dms:chat-popout"

    modalWidth: 920
    modalHeight: 840
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
    cornerRadius: Theme.cornerRadius
    visible: false

    // While the conversation has an overlay up -- help, a delete confirmation,
    // a forward picker -- Escape belongs to that overlay. Without this the
    // whole window closes on the first press and the overlay never sees it.
    closeOnEscapeKey: !(contentLoader.item?.hasOverlay ?? false)

    // Candidates when a query was ambiguous. Empty once one is chosen.
    property var candidates: []
    property string pendingQuery: ""
    property bool resolving: false
    property string resolveError: ""

    // open resolves whatever identifier the caller has and shows the result.
    //
    // Accepts "provider:chatId", a raw chat id, a phone number in any
    // formatting, or a name. Which of those a provider actually supports is the
    // backend's problem, not the caller's.
    function openQuery(query) {
        chatPopout.candidates = [];
        chatPopout.resolveError = "";
        chatPopout.pendingQuery = query || "";

        if (!query) {
            showPopout();
            return;
        }

        chatPopout.resolving = true;
        DMSService.sendRequest("chat.resolve", {
            "query": query,
            "limit": 10
        }, response => {
            chatPopout.resolving = false;

            if (response.error) {
                chatPopout.resolveError = response.error;
                chatPopout.showPopout();
                return;
            }

            const found = response.result?.candidates || [];
            if (found.length === 0) {
                chatPopout.resolveError = I18n.tr("No conversation matches %1").arg(query);
                chatPopout.showPopout();
                return;
            }

            if (found.length === 1) {
                chatPopout.openResolved(found[0].provider, found[0].chatId);
                return;
            }

            // More than one match: let the user say which.
            chatPopout.candidates = found;
            chatPopout.showPopout();
        });
    }

    function openResolved(provider, chatId) {
        chatPopout.candidates = [];
        chatPopout.resolveError = "";
        showPopout();
        Qt.callLater(() => ChatService.openChat(provider, chatId));
    }

    function showPopout() {
        chatPopout.open();
        chatPopout.shouldHaveFocus = true;
        Qt.callLater(() => chatPopout.contentLoader.item?.takeFocus());
    }

    function hidePopout() {
        ChatService.setFocus("", "");
        Qt.callLater(() => chatPopout.close());
    }

    onDialogClosed: {
        ChatService.setFocus("", "");
        chatPopout.candidates = [];
    }

    content: Component {
        ChatPopoutContent {
            onCloseRequested: chatPopout.hidePopout()
        }
    }
}
