import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

// One message.
//
// Renders whatever the store holds without knowing which service it came from:
// the only provider-specific thing here is whether replying is offered, which
// follows the provider's declared capabilities.
Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    required property var message
    property var previousMessage: null

    // Set when this message carries the Alt+K/J selection.
    property bool selected: false

    signal replyRequested
    signal forwardRequested
    signal copyRequested
    signal deleteRequested

    readonly property bool fromMe: message?.fromMe ?? false
    readonly property string kind: message?.kind ?? "text"
    readonly property string text: message?.text ?? ""
    readonly property string status: message?.status ?? ""
    readonly property string mediaPath: message?.mediaPath ?? ""
    readonly property bool hasMedia: mediaPath !== "" || (message?.mediaRef ?? "") !== ""
    readonly property bool isDeleted: kind === "deleted"
    readonly property string senderAvatar: message?.senderAvatarPath ?? ""

    readonly property string linkUrl: message?.linkUrl ?? ""

    // The body with URLs turned into anchors.
    //
    // Escaped first: message text is other people's input, and StyledText would
    // otherwise treat markup in it as markup.
    readonly property string richText: {
        const raw = root.text;
        if (raw === "")
            return "";

        const escaped = raw.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        return escaped.replace(/(https?:\/\/[^\s<]+)/g, "<a href=\"$1\" style=\"color:" + Theme.primary + "\">$1</a>");
    }
    readonly property bool hasLink: linkUrl !== ""

    // Hover is kept alive briefly after the pointer leaves. The action row sits
    // beside the bubble, so reaching for a button crosses a gap that belongs to
    // neither -- without the delay the buttons vanish on the way.
    property bool hovering: false

    Timer {
        id: hoverGrace
        interval: 220
        onTriggered: root.hovering = false
    }

    function setHovered(value) {
        if (value) {
            hoverGrace.stop();
            root.hovering = true;
            return;
        }
        hoverGrace.restart();
    }

    // System rows are the conversation talking about itself, not someone
    // speaking, so they are centred and unstyled rather than given a bubble.
    readonly property bool isSystem: kind === "system" || kind === "unsupported"

    // Only label the sender when it changes, so a run of messages from one
    // person does not repeat their name on every line.
    readonly property bool showSender: {
        if (fromMe || isSystem)
            return false;
        if (!(root.message?.senderName ?? ""))
            return false;
        if (!previousMessage)
            return true;
        return previousMessage.senderName !== root.message.senderName || previousMessage.fromMe;
    }

    readonly property string statusIcon: {
        switch (root.status) {
        case "pending":
            return "schedule";
        case "sent":
            return "check";
        case "delivered":
            return "done_all";
        case "read":
            return "done_all";
        case "failed":
            return "error_outline";
        default:
            return "";
        }
    }

    function formatTime(timestamp) {
        if (!timestamp)
            return "";
        const date = new Date(timestamp);
        return SettingsData.use24HourClock ? date.toLocaleTimeString(Qt.locale(), "HH:mm") : date.toLocaleTimeString(Qt.locale(), "h:mm AP");
    }

    height: isSystem ? systemLabel.implicitHeight + Theme.spacingS : bubble.height + (showSender ? senderLabel.height + 2 : 0)

    // ------------------------------------------------------------ system row

    StyledText {
        id: systemLabel
        anchors.centerIn: parent
        visible: root.isSystem
        width: parent.width * 0.8
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: root.text
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    // ------------------------------------------------------------ message

    Row {
        id: senderLabel
        visible: root.showSender
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingS
        anchors.top: parent.top
        spacing: Theme.spacingXS

        // Only on the first message of a run, so a back-and-forth does not
        // repeat the same face on every line.
        DankCircularImage {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fontSizeMedium
            height: Theme.fontSizeMedium
            imageSource: root.senderAvatar !== "" ? "file://" + root.senderAvatar : ""
            fallbackText: (root.message?.senderName ?? "?").charAt(0).toUpperCase()
            fallbackIcon: "person"
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.message?.senderName ?? ""
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.primary
        }
    }

    StyledRect {
        id: bubble
        visible: !root.isSystem

        anchors.top: root.showSender ? senderLabel.bottom : parent.top
        anchors.topMargin: root.showSender ? 2 : 0
        anchors.left: root.fromMe ? undefined : parent.left
        anchors.right: root.fromMe ? parent.right : undefined
        anchors.leftMargin: Theme.spacingS
        anchors.rightMargin: Theme.spacingS

        width: Math.min(bubbleContent.implicitWidth + Theme.spacingM * 2, root.width * 0.72)
        height: bubbleContent.implicitHeight + Theme.spacingS * 2
        radius: Theme.cornerRadius

        color: {
            if (root.status === "failed")
                return Theme.withAlpha(Theme.error, 0.15);
            return root.fromMe ? Theme.primarySelected : Theme.surfaceContainerHigh;
        }

        // Keyboard focus needs to be visible without moving anything, so it is
        // drawn as a border rather than a size or colour change.
        border.color: root.selected ? Theme.primary : "transparent"
        border.width: root.selected ? 2 : 0

        // Hover is tracked across the bubble and its action row together:
        // the buttons sit outside the bubble, so leaving it to reach one used
        // to hide the very thing being reached for.
        HoverHandler {
            id: bubbleHover
            onHoveredChanged: root.setHovered(hovered)
        }

        MouseArea {
            id: bubbleArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton

            onClicked: {
                if (!root.hasMedia)
                    return;
                if (root.mediaPath !== "") {
                    Quickshell.execDetached(["xdg-open", root.mediaPath]);
                    return;
                }
                // Not cached yet: media is fetched only when actually opened,
                // so the first click is what downloads it.
                ChatService.fetchMedia(ChatService.activeProvider, ChatService.activeChatId, root.message.id, path => {
                    if (path)
                        Quickshell.execDetached(["xdg-open", path]);
                });
            }
        }

        Column {
            id: bubbleContent
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Theme.spacingM
            anchors.topMargin: Theme.spacingS
            spacing: Theme.spacingXS

            // Quoted message being replied to.
            StyledRect {
                visible: (root.message?.replyTo ?? "") !== ""
                width: Math.max(replyLabel.implicitWidth + Theme.spacingS * 2, 80)
                height: replyLabel.implicitHeight + Theme.spacingXS * 2
                radius: Theme.cornerRadius / 2
                color: Theme.withAlpha(Theme.surfaceVariantText, 0.12)

                StyledText {
                    id: replyLabel
                    anchors.centerIn: parent
                    text: I18n.tr("Reply")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }

            // Attachment. Dimensions come from the provider so the bubble is
            // the right size before the image has loaded, avoiding a reflow.
            Item {
                visible: root.hasMedia && !root.isDeleted
                width: Math.min(240, root.width * 0.6)
                height: {
                    const w = root.message?.mediaW ?? 0;
                    const h = root.message?.mediaH ?? 0;
                    if (w > 0 && h > 0)
                        return Math.round(width * (h / w));
                    return 160;
                }

                Image {
                    id: mediaImage
                    anchors.fill: parent
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    source: root.mediaPath !== "" ? "file://" + root.mediaPath : ""
                    visible: status === Image.Ready
                }

                // Placeholder for media not yet fetched, or that failed.
                StyledRect {
                    anchors.fill: parent
                    visible: !mediaImage.visible
                    radius: Theme.cornerRadius / 2
                    color: Theme.withAlpha(Theme.surfaceVariantText, 0.12)

                    DankIcon {
                        anchors.centerIn: parent
                        name: {
                            switch (root.kind) {
                            case "video":
                                return "movie";
                            case "audio":
                                return "mic";
                            case "document":
                                return "description";
                            default:
                                return "image";
                            }
                        }
                        size: Theme.iconSizeLarge
                        color: Theme.surfaceVariantText
                    }
                }
            }

            // What the link is, when the provider resolved it. Nothing is
            // fetched here: doing so would tell whoever hosts the page that the
            // message had been read.
            StyledRect {
                visible: root.hasLink && !root.isDeleted
                width: Math.min(280, root.width * 0.66)
                height: linkColumn.implicitHeight + Theme.spacingS * 2
                radius: Theme.cornerRadius / 2
                color: Theme.withAlpha(Theme.primary, 0.10)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["xdg-open", root.linkUrl])
                }

                Column {
                    id: linkColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Theme.spacingS
                    spacing: 2

                    StyledText {
                        width: parent.width
                        visible: (root.message?.linkTitle ?? "") !== ""
                        text: root.message?.linkTitle ?? ""
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        width: parent.width
                        visible: (root.message?.linkDesc ?? "") !== ""
                        text: root.message?.linkDesc ?? ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingXS

                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "link"
                            size: Theme.fontSizeSmall
                            color: Theme.primary
                        }

                        StyledText {
                            width: parent.width - Theme.fontSizeSmall - Theme.spacingXS
                            text: root.linkUrl
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            StyledText {
                width: Math.min(implicitWidth, root.width * 0.72 - Theme.spacingM * 2)
                visible: root.text !== "" || root.isDeleted
                text: root.isDeleted ? I18n.tr("This message was deleted") : root.richText
                font.pixelSize: Theme.fontSizeMedium
                font.italic: root.isDeleted
                color: root.isDeleted ? Theme.surfaceVariantText : Theme.surfaceText
                wrapMode: Text.Wrap
                // Links in the body are clickable without turning the whole
                // message into rich text.
                textFormat: Text.StyledText
                onLinkActivated: url => Quickshell.execDetached(["xdg-open", url])

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    enabled: parent.hoveredLink !== ""
                }
            }

            // Filename for attachments that are not images.
            StyledText {
                visible: (root.message?.fileName ?? "") !== "" && root.kind === "document"
                text: root.message.fileName
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                elide: Text.ElideMiddle
            }

            Row {
                anchors.right: parent.right
                spacing: Theme.spacingXS

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.formatTime(root.message?.ts ?? 0)
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.surfaceVariantText
                }

                // Delivery status is only meaningful for messages we sent.
                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.fromMe && root.statusIcon !== ""
                    name: root.statusIcon
                    size: Theme.fontSizeSmall
                    color: {
                        if (root.status === "failed")
                            return Theme.error;
                        if (root.status === "read")
                            return Theme.primary;
                        return Theme.surfaceVariantText;
                    }
                }
            }
        }

        // Actions appear on hover or under keyboard focus, and each is gated on
        // what the provider actually supports -- an action that would fail is
        // never offered.
        Row {
            id: actions
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: root.fromMe ? undefined : parent.right
            anchors.right: root.fromMe ? parent.left : undefined
            anchors.leftMargin: Theme.spacingXS
            anchors.rightMargin: Theme.spacingXS
            spacing: 0
            visible: (root.hovering || root.selected) && !root.isDeleted

            HoverHandler {
                id: actionsHover
                onHoveredChanged: root.setHovered(hovered)
            }

            DankActionButton {
                buttonSize: 26
                iconSize: Theme.fontSizeSmall
                iconName: "reply"
                iconColor: Theme.surfaceVariantText
                tooltipText: I18n.tr("Reply")
                visible: ChatService.activeSupports("reply")
                onClicked: root.replyRequested()
            }

            DankActionButton {
                buttonSize: 26
                iconSize: Theme.fontSizeSmall
                iconName: "forward"
                iconColor: Theme.surfaceVariantText
                tooltipText: I18n.tr("Forward")
                visible: root.text !== ""
                onClicked: root.forwardRequested()
            }

            DankActionButton {
                buttonSize: 26
                iconSize: Theme.fontSizeSmall
                iconName: "content_copy"
                iconColor: Theme.surfaceVariantText
                tooltipText: I18n.tr("Copy")
                visible: root.text !== ""
                onClicked: root.copyRequested()
            }

            // Always offered: a message can at least be removed from this
            // device, and the confirmation says which kind of delete it is.
            DankActionButton {
                buttonSize: 26
                iconSize: Theme.fontSizeSmall
                iconName: "delete"
                iconColor: Theme.error
                tooltipText: root.fromMe && ChatService.activeSupports("revoke") ? I18n.tr("Delete for everyone") : I18n.tr("Delete")
                onClicked: root.deleteRequested()
            }
        }
    }
}
