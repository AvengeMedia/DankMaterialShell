pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// Choose where a message is going.
//
// Forwarding sends into a different conversation, so the destination is picked
// explicitly -- there is no sensible default, and guessing means sending to the
// wrong person.
StyledRect {
    id: root

    property var source: null

    signal picked(string provider, string chatId)
    signal cancelled

    color: Theme.withAlpha(Theme.surfaceContainer, 0.97)
    radius: Theme.cornerRadius

    // Swallow clicks so they cannot reach the conversation behind.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    onVisibleChanged: {
        if (visible) {
            filter.text = "";
            filter.forceActiveFocus();
        }
    }

    readonly property var targets: {
        const query = filter.text.trim().toLowerCase();
        const out = [];
        for (let i = 0; i < ChatService.chats.length; i++) {
            const chat = ChatService.chats[i];
            // Forwarding to the conversation it came from is a no-op the user
            // never means.
            if (chat.provider === ChatService.activeProvider && chat.id === ChatService.activeChatId)
                continue;
            if (query !== "") {
                const name = (chat.name || "").toLowerCase();
                if (name.indexOf(query) === -1)
                    continue;
            }
            out.push(chat);
        }
        return out;
    }

    Keys.onEscapePressed: event => {
        root.cancelled();
        event.accepted = true;
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        Row {
            width: parent.width
            spacing: Theme.spacingS

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - closeButton.width - Theme.spacingS
                text: I18n.tr("Forward to")
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            DankActionButton {
                id: closeButton
                anchors.verticalCenter: parent.verticalCenter
                buttonSize: 28
                iconName: "close"
                iconColor: Theme.surfaceVariantText
                onClicked: root.cancelled()
            }
        }

        // What is being forwarded, so the user can see they picked the right
        // message before choosing a destination.
        StyledRect {
            width: parent.width
            height: preview.implicitHeight + Theme.spacingS * 2
            radius: Theme.cornerRadius / 2
            color: Theme.withAlpha(Theme.surfaceVariantText, 0.12)

            StyledText {
                id: preview
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Theme.spacingS
                text: root.source?.text ?? ""
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }

        DankTextField {
            id: filter
            width: parent.width
            placeholderText: I18n.tr("Search conversations")
            leftIconName: "search"
        }

        DankListView {
            width: parent.width
            height: parent.height - parent.spacing * 3 - closeButton.height - preview.height - Theme.spacingS * 2 - filter.height
            clip: true
            model: root.targets
            spacing: Theme.spacingXS

            delegate: ChatCandidateRow {
                required property var modelData

                width: ListView.view.width
                candidate: ({
                        "name": modelData.name,
                        "chatId": modelData.id,
                        "provider": modelData.provider,
                        "providerName": modelData.provider,
                        "isGroup": modelData.isGroup,
                        "unread": 0
                    })

                onChosen: root.picked(modelData.provider, modelData.id)
            }
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: root.targets.length === 0
            text: I18n.tr("No other conversations")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }
}
