import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

// The message input.
//
// Attachments arrive by pasting: Ctrl+V in the text field writes whatever the
// clipboard holds to a file and stages it with a preview. There is no file
// browser button -- opening one from a popout put the dialog behind the window,
// where it could not be reached without closing the chat first.
//
// Staged rather than sent on paste: you can add several, see what you picked,
// remove a mistake, and write a caption before anything leaves.
Item {
    id: root

    property var replyTarget: null

    signal sent
    signal replyCleared

    readonly property bool canSend: ChatService.activeSupports("send")
    readonly property bool canAttach: ChatService.activeSupports("media")

    // Absolute paths waiting to be sent with the next message.
    property var staged: []
    property bool pasting: false

    readonly property bool hasStaged: staged.length > 0

    height: replyBar.height + stagedStrip.height + inputRow.height + Theme.spacingS * 2 + (replyBar.visible ? Theme.spacingXS : 0) + (stagedStrip.visible ? Theme.spacingXS : 0)

    function stage(path) {
        if (!path)
            return;
        const clean = String(path).replace("file://", "").trim();
        if (clean === "")
            return;
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

    // paste handles the clipboard itself, for both media and text.
    //
    // The text field's own Ctrl+V cannot be extended: the inner input consumes
    // the key before anything wrapping it is told, so intercepting the shortcut
    // and doing the whole job here is the only way to stage an image. Text is
    // then inserted by hand, which is why this reads it rather than leaving it.
    function paste() {
        if (root.pasting)
            return;
        root.pasting = true;

        // One pass over the clipboard, in the order that matters:
        //
        //   1. a copied file, which a file manager offers as text/uri-list
        //   2. raw media bytes, as a screenshot tool offers
        //   3. text
        //
        // uri-list comes first because copying a file in a file manager also
        // offers its name as text, and attaching the file is what was meant.
        const script = "types=$(wl-paste --list-types 2>/dev/null)\n" + "if printf '%s\\n' \"$types\" | grep -qx 'text/uri-list'; then\n" + "  wl-paste --type text/uri-list 2>/dev/null | tr -d '\\r' | grep -v '^$' | while IFS= read -r u; do\n" + "    printf 'FILE:%s\\n' \"${u#file://}\"\n" + "  done\n" + "  exit 0\n" + "fi\n" + "media=$(printf '%s\\n' \"$types\" | grep -E '^(image|video|audio|application)/' | head -1)\n" + "if [ -n \"$media\" ]; then\n" + "  ext=${media##*/}\n" + "  case \"$ext\" in jpeg) ext=jpg ;; esac\n" + "  f=$(mktemp \"${XDG_RUNTIME_DIR:-/tmp}/dms-chat-paste-XXXXXX.$ext\")\n" + "  wl-paste --type \"$media\" > \"$f\" 2>/dev/null\n" + "  if [ -s \"$f\" ]; then printf 'FILE:%s\\n' \"$f\"; exit 0; fi\n" + "  rm -f \"$f\"\n" + "fi\n" + "printf 'TEXT:%s' \"$(wl-paste --no-newline 2>/dev/null)\"\n";

        Proc.runCommand("chat.paste", ["sh", "-c", script], (stdout, exitCode) => {
            root.pasting = false;

            const out = stdout || "";

            // Several files can be copied at once, so every FILE line counts.
            if (out.startsWith("FILE:")) {
                if (!root.canAttach) {
                    ToastService.showWarning(I18n.tr("Cannot attach"), I18n.tr("This provider does not accept attachments."));
                    return;
                }

                const lines = out.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].startsWith("FILE:"))
                        root.stage(decodeURIComponent(lines[i].slice(5).trim()));
                }
                return;
            }

            if (out.startsWith("TEXT:")) {
                const pasted = out.slice(5);
                if (pasted === "")
                    return;

                // A pasted path is almost certainly meant as an attachment, not
                // as a line of text about a file.
                if (root.canAttach && root.looksLikePath(pasted)) {
                    root.stageIfFile(pasted);
                    return;
                }
                root.insertText(pasted);
            }
        });
    }

    // insertText puts text at the cursor, since the paste is handled here
    // rather than by the field.
    function insertText(text) {
        const at = input.cursorPosition;
        const before = input.text.slice(0, at);
        const after = input.text.slice(at);
        input.text = before + text + after;
        input.cursorPosition = at + text.length;
    }

    function looksLikePath(text) {
        const trimmed = text.trim();
        if (trimmed === "" || trimmed.indexOf("\n") !== -1)
            return false;
        return trimmed.startsWith("/") || trimmed.startsWith("~/") || trimmed.startsWith("file://");
    }

    // stageIfFile attaches a path only once it is confirmed to exist, so a
    // sentence that happens to start with a slash is still just text.
    function stageIfFile(text, onMissing) {
        const path = text.trim().replace("file://", "");

        Proc.runCommand("chat.checkPath", ["test", "-f", path], (stdout, exitCode) => {
            if (exitCode === 0) {
                root.stage(path);
                if (onMissing)
                    onMissing(true);
                return;
            }
            if (onMissing)
                onMissing(false);
            else
                root.insertText(text);
        });
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

            DankTextField {
                id: input
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 36 - Theme.spacingS
                enabled: root.canSend
                placeholderText: {
                    if (!root.canSend)
                        return I18n.tr("This provider cannot send messages");
                    if (root.hasStaged)
                        return I18n.tr("Add a caption");
                    return root.canAttach ? I18n.tr("Message, or paste an image") : I18n.tr("Message");
                }

                // Enter always sends. Shift+Enter is left unhandled here so it
                // reaches the conversation, where it opens the selected
                // message's attachment or link -- the text field holds focus
                // permanently, so it is the only place those keys can arrive.
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

                // Typing or pasting a path and pressing space attaches it,
                // which is how a file manager's "copy path" ends up here.
                onTextChanged: {
                    if (!root.canAttach || root.pasting)
                        return;
                    if (!input.text.endsWith(" "))
                        return;

                    const candidate = input.text.trim();
                    if (!root.looksLikePath(candidate))
                        return;

                    root.pasting = true;
                    root.stageIfFile(candidate, found => {
                        root.pasting = false;
                        // Only clear the field once the file turned out to be
                        // real; otherwise the text was just text.
                        if (found)
                            input.text = "";
                    });
                }
            }

            DankActionButton {
                anchors.verticalCenter: parent.verticalCenter
                buttonSize: 36
                iconName: root.pasting ? "hourglass_empty" : "send"
                iconColor: (input.text.trim() !== "" || root.hasStaged) ? Theme.primary : Theme.surfaceVariantText
                enabled: root.canSend && (input.text.trim() !== "" || root.hasStaged)
                tooltipText: I18n.tr("Send")
                onClicked: root.send()
            }
        }
    }
}
