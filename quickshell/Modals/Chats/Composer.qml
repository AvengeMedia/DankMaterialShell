import QtQuick
import qs.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

// The message input.
//
// Every affordance here is gated on what the open conversation's provider said
// it can do, so a provider that cannot send attachments simply has no attach
// button rather than a button that fails.
Item {
    id: root

    property var replyTarget: null

    signal sent
    signal replyCleared

    readonly property bool canSend: ChatService.activeSupports("send")
    readonly property bool canAttach: ChatService.activeSupports("media")

    height: replyBar.height + inputRow.height + Theme.spacingS * 2

    function send() {
        const text = input.text.trim();
        if (text === "" || !root.canSend)
            return;

        ChatService.sendText(text, root.replyTarget ? root.replyTarget.id : "");
        input.text = "";
        root.sent();
    }

    function takeFocus() {
        input.forceActiveFocus();
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: Theme.spacingXS

        // What is being replied to, with a way out of it.
        StyledRect {
            id: replyBar
            width: parent.width
            height: root.replyTarget ? replyRow.implicitHeight + Theme.spacingS : 0
            visible: root.replyTarget !== null
            radius: Theme.cornerRadius / 2
            color: Theme.withAlpha(Theme.primary, 0.1)

            Row {
                id: replyRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.spacingS
                spacing: Theme.spacingS

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "reply"
                    size: Theme.fontSizeMedium
                    color: Theme.primary
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.fontSizeMedium - 32 - Theme.spacingS * 2
                    text: root.replyTarget ? (root.replyTarget.text || I18n.tr("Attachment")) : ""
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    elide: Text.ElideRight
                }

                DankActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    buttonSize: 24
                    iconSize: Theme.fontSizeSmall
                    iconName: "close"
                    iconColor: Theme.surfaceVariantText
                    onClicked: root.replyCleared()
                }
            }
        }

        Row {
            id: inputRow
            width: parent.width
            spacing: Theme.spacingS

            DankActionButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.canAttach
                buttonSize: 36
                iconName: "attach_file"
                iconColor: Theme.surfaceVariantText
                tooltipText: I18n.tr("Attach a file")
                onClicked: fileBrowser.open()
            }

            DankTextField {
                id: input
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (root.canAttach ? 36 + Theme.spacingS : 0) - 36 - Theme.spacingS
                enabled: root.canSend
                placeholderText: root.canSend ? I18n.tr("Message") : I18n.tr("This provider cannot send messages")

                // Enter sends; Shift+Enter is a newline, as everywhere else.
                Keys.onReturnPressed: event => {
                    if (event.modifiers & Qt.ShiftModifier) {
                        event.accepted = false;
                        return;
                    }
                    root.send();
                    event.accepted = true;
                }

                Keys.onEnterPressed: event => {
                    if (event.modifiers & Qt.ShiftModifier) {
                        event.accepted = false;
                        return;
                    }
                    root.send();
                    event.accepted = true;
                }
            }

            DankActionButton {
                anchors.verticalCenter: parent.verticalCenter
                buttonSize: 36
                iconName: "send"
                iconColor: input.text.trim() !== "" ? Theme.primary : Theme.surfaceVariantText
                enabled: root.canSend && input.text.trim() !== ""
                tooltipText: I18n.tr("Send")
                onClicked: root.send()
            }
        }
    }

    FileBrowserModal {
        id: fileBrowser
        browserTitle: I18n.tr("Send a file")
        browserIcon: "attach_file"
        browserType: "generic"

        // The browser hands back a file:// URL; the bridge is given a plain
        // path, matching how attachments are described in the contract.
        onFileSelected: path => {
            ChatService.sendFiles([path.replace("file://", "")], "");
            root.sent();
        }
    }
}
