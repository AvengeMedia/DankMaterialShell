import QtQuick
import Quickshell
import qs.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

// The message input.
//
// Attachments are staged rather than sent on selection: you can add several,
// see what you picked, remove a mistake, and write a caption before anything
// leaves. Sending a file the instant it is chosen gives no chance to check it.
//
// Pasting an image from the clipboard is not wired up: attachments travel as
// file paths, and there is no command yet that turns clipboard contents into
// one. Staging from the file browser covers everything else.
//
// Every affordance is gated on what the open conversation's provider declared,
// so a provider that cannot send attachments simply has no attach button.
Item {
    id: root

    property var replyTarget: null

    signal sent
    signal replyCleared

    readonly property bool canSend: ChatService.activeSupports("send")
    readonly property bool canAttach: ChatService.activeSupports("media")

    // Absolute paths waiting to be sent with the next message.
    property var staged: []

    readonly property bool hasStaged: staged.length > 0

    height: replyBar.height + stagedStrip.height + inputRow.height + Theme.spacingS * 2 + (replyBar.visible ? Theme.spacingXS : 0) + (stagedStrip.visible ? Theme.spacingXS : 0)

    function stage(path) {
        if (!path)
            return;
        const clean = String(path).replace("file://", "");
        // Staging the same file twice is never intended.
        if (root.staged.indexOf(clean) !== -1)
            return;
        root.staged = root.staged.concat([clean]);
    }

    function unstage(index) {
        const next = root.staged.slice();
        next.splice(index, 1);
        root.staged = next;
    }

    function clearStaged() {
        root.staged = [];
    }

    function send() {
        const text = input.text.trim();
        if (!root.canSend)
            return;
        if (text === "" && !root.hasStaged)
            return;

        if (root.hasStaged) {
            // One send carrying every attachment plus the caption, so they
            // arrive as one message rather than a burst.
            ChatService.sendFiles(root.staged, text);
            root.clearStaged();
        } else {
            ChatService.sendText(text, root.replyTarget ? root.replyTarget.id : "");
        }

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

        // ------------------------------------------------------ staged files

        // The review step: what will be sent, and a way to drop any of it.
        Flickable {
            id: stagedStrip
            width: parent.width
            height: root.hasStaged ? 76 : 0
            visible: root.hasStaged
            clip: true
            contentWidth: stagedRow.width
            flickableDirection: Flickable.HorizontalFlick

            Row {
                id: stagedRow
                height: parent.height
                spacing: Theme.spacingS

                Repeater {
                    model: root.staged

                    StyledRect {
                        id: chip

                        required property string modelData
                        required property int index

                        readonly property bool isImage: /\.(png|jpe?g|gif|webp|bmp)$/i.test(modelData)
                        readonly property string fileName: modelData.split("/").pop()

                        width: 72
                        height: 72
                        radius: Theme.cornerRadius / 2
                        color: Theme.withAlpha(Theme.surfaceVariantText, 0.12)

                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            visible: chip.isImage && status === Image.Ready
                            source: chip.isImage ? "file://" + chip.modelData : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 144
                            sourceSize.height: 144
                        }

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - Theme.spacingXS * 2
                            spacing: 2
                            visible: !chip.isImage

                            DankIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: "draft"
                                size: Theme.iconSize
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: chip.fileName
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Theme.surfaceVariantText
                                elide: Text.ElideMiddle
                            }
                        }

                        DankActionButton {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            buttonSize: 20
                            iconSize: Theme.fontSizeSmall - 2
                            iconName: "close"
                            iconColor: Theme.surfaceText
                            backgroundColor: Theme.withAlpha(Theme.surfaceContainer, 0.85)
                            onClicked: root.unstage(chip.index)
                        }
                    }
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
                placeholderText: {
                    if (!root.canSend)
                        return I18n.tr("This provider cannot send messages");
                    return root.hasStaged ? I18n.tr("Add a caption") : I18n.tr("Message");
                }

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
                iconColor: (input.text.trim() !== "" || root.hasStaged) ? Theme.primary : Theme.surfaceVariantText
                enabled: root.canSend && (input.text.trim() !== "" || root.hasStaged)
                tooltipText: I18n.tr("Send")
                onClicked: root.send()
            }
        }
    }

    FileBrowserModal {
        id: fileBrowser
        browserTitle: I18n.tr("Attach a file")
        browserIcon: "attach_file"
        browserType: "generic"

        // Staged rather than sent, so more can be added and the selection
        // reviewed first.
        onFileSelected: path => root.stage(path)
    }
}
