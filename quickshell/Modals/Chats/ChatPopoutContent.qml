pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modals.Chats
import qs.Services
import qs.Widgets

// The popout's body: either a disambiguation list, a no-match message, or one
// conversation.
FocusScope {
    id: root

    signal closeRequested

    // Reached through PopoutService rather than by walking up the parent chain,
    // which breaks whenever the modal's internal structure changes.
    readonly property var popout: PopoutService.chatPopout
    readonly property var candidates: popout?.candidates ?? []
    readonly property string resolveError: popout?.resolveError ?? ""
    readonly property bool resolving: popout?.resolving ?? false

    readonly property bool hasOverlay: conversation.hasOverlay

    readonly property bool showingConversation: !resolving && candidates.length === 0 && resolveError === ""

    Ref {
        service: ChatService
    }

    function takeFocus() {
        // Straight to the composer: a chat opens ready to be written in, and
        // every shortcut is designed around the text field holding focus.
        if (root.showingConversation && ChatService.hasActiveChat)
            conversation.takeFocus();
        else
            root.forceActiveFocus();
    }

    Keys.onEscapePressed: event => {
        root.closeRequested();
        event.accepted = true;
    }

    DankSpinner {
        anchors.centerIn: parent
        width: 32
        height: 32
        visible: root.resolving
    }

    // ------------------------------------------------------------- no match

    Column {
        anchors.centerIn: parent
        width: parent.width - Theme.spacingXL * 2
        spacing: Theme.spacingM
        visible: !root.resolving && root.resolveError !== "" && root.candidates.length === 0

        DankIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "search_off"
            size: Theme.iconSizeLarge
            color: Theme.surfaceVariantText
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.resolveError
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: I18n.tr("Try a name, a phone number, or provider:chatId.")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }

    // -------------------------------------------------------- disambiguation

    // Shown when a query matched more than one conversation. Deliberately a
    // choice rather than a guess: opening the wrong chat means sending a
    // message to the wrong person.
    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS
        visible: !root.resolving && root.candidates.length > 0

        StyledText {
            width: parent.width
            text: I18n.tr("Which conversation?")
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            id: matchCount
            width: parent.width
            text: I18n.tr("%1 conversations match.").arg(root.candidates.length)
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        DankListView {
            width: parent.width
            height: parent.height - parent.spacing * 3 - matchCount.height - Theme.fontSizeLarge * 1.4
            clip: true
            model: root.candidates
            spacing: Theme.spacingXS

            delegate: ChatCandidateRow {
                required property var modelData

                width: ListView.view.width
                candidate: modelData

                onChosen: root.popout?.openResolved(modelData.provider, modelData.chatId)
            }
        }
    }

    // ------------------------------------------------------- the conversation

    ConversationView {
        id: conversation
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        visible: root.showingConversation && ChatService.hasActiveChat
    }

    StyledText {
        anchors.centerIn: parent
        visible: root.showingConversation && !ChatService.hasActiveChat
        text: I18n.tr("No conversation open")
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceVariantText
    }
}
