import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var eventData: null
    property bool canEdit: false

    signal editRequested
    signal deleteRequested
    signal closeRequested

    readonly property bool _descriptionIsHtml: /<[a-z][^>]*>/i.test((eventData && eventData.description) || "")

    function _styleAnchors(html) {
        return html.replace(/<a\s([^>]*)>/gi, (m, attrs) => {
            const cleaned = attrs.replace(/style="[^"]*"/gi, "");
            return "<a style=\"text-decoration:none; color:" + Theme.primary + ";\" " + cleaned + ">";
        });
    }

    function _inlineMarkdown(line) {
        let out = line.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        out = out.replace(/\\([\\`*_{}[\]()#+\-.!~>])/g, "$1");
        out = out.replace(/(?:https?:\/\/|www\.)[^\s<>)\]]*[^\s<>)\].,;:!?"']/g, (m, offset, s) => {
            const prev = offset > 0 ? s[offset - 1] : "";
            if (prev === "(" || prev === "[" || prev === "\"" || prev === "'")
                return m;
            const href = m.startsWith("www.") ? "https://" + m : m;
            return "<a href=\"" + href + "\">" + m + "</a>";
        });
        out = out.replace(/\[([^\]]+)\]\(([^()\s]+)\)/g, "<a href=\"$2\">$1</a>");
        out = out.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>");
        out = out.replace(/(^|[^*])\*([^*\s][^*]*)\*/g, "$1<i>$2</i>");
        return out;
    }

    // Descriptions arrive as HTML (Google) or markdown/plain text; both render
    // as RichText so links become clickable anchors recolored to the theme.
    function _descriptionRichText() {
        const raw = ((eventData && eventData.description) || "").trim();
        if (raw === "")
            return "";
        if (_descriptionIsHtml)
            return _styleAnchors(raw);

        const parts = [];
        let list = "";
        const closeList = () => {
            if (list === "")
                return;
            parts.push("</" + list + ">");
            list = "";
        };

        const lines = raw.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const ul = lines[i].match(/^\s*[-*+]\s+(.+)$/);
            const ol = lines[i].match(/^\s*\d+[.)]\s+(.+)$/);
            if (ul || ol) {
                const tag = ul ? "ul" : "ol";
                if (list !== tag) {
                    closeList();
                    parts.push("<" + tag + ">");
                    list = tag;
                }
                parts.push("<li>" + _inlineMarkdown((ul || ol)[1]) + "</li>");
                continue;
            }
            closeList();
            parts.push(_inlineMarkdown(lines[i]) + "<br/>");
        }
        closeList();
        return _styleAnchors(parts.join("").replace(/<br\/>$/, ""));
    }

    function _timeText() {
        if (!eventData)
            return "";
        const dateStr = Qt.formatDate(eventData.start, "ddd, MMM d");
        if (eventData.allDay)
            return I18n.tr("All day") + " · " + dateStr;
        const fmt = SettingsData.use24HourClock ? "HH:mm" : "h:mm AP";
        const startStr = Qt.formatTime(eventData.start, fmt);
        if (eventData.start.getTime() === eventData.end.getTime())
            return dateStr + " · " + startStr;
        return dateStr + " · " + startStr + " – " + Qt.formatTime(eventData.end, fmt);
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.spacingL * 2, 380)
        height: Math.min(parent.height - Theme.spacingM * 2, body.implicitHeight + Theme.spacingL * 2)
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        border.color: Theme.outlineMedium
        border.width: 1
        clip: true

        MouseArea {
            anchors.fill: parent
        }

        DankActionButton {
            id: closeButton
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.spacingXS
            circular: false
            iconName: "close"
            iconSize: 16
            z: 1
            onClicked: root.closeRequested()
        }

        DankFlickable {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            anchors.topMargin: Theme.spacingL
            contentWidth: width
            contentHeight: body.implicitHeight
            clip: true

            Column {
                id: body
                width: parent.width
                spacing: Theme.spacingS

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    Rectangle {
                        width: 4
                        height: titleText.implicitHeight
                        radius: 2
                        anchors.top: parent.top
                        color: (root.eventData && root.eventData.color) ? root.eventData.color : Theme.primary
                    }

                    StyledText {
                        id: titleText
                        width: parent.width - 4 - Theme.spacingS - closeButton.width
                        text: root.eventData ? root.eventData.title : ""
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        horizontalAlignment: Text.AlignLeft
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }

                StyledText {
                    width: parent.width
                    text: root._timeText()
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.Wrap
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingXS
                    visible: root.eventData && root.eventData.calendar

                    DankIcon {
                        name: "calendar_month"
                        size: 14
                        color: Theme.surfaceVariantText
                        anchors.top: parent.top
                        anchors.topMargin: 2
                    }

                    StyledText {
                        width: parent.width - 14 - Theme.spacingXS
                        text: {
                            if (!root.eventData)
                                return "";
                            const acc = root.eventData.account || "";
                            return root.eventData.calendar + (acc ? " · " + acc : "");
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingXS
                    visible: root.eventData && root.eventData.location

                    DankIcon {
                        name: "place"
                        size: 14
                        color: Theme.surfaceVariantText
                        anchors.top: parent.top
                        anchors.topMargin: 2
                    }

                    StyledText {
                        width: parent.width - 14 - Theme.spacingXS
                        text: root.eventData ? root.eventData.location : ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingXS
                    visible: root.eventData && root.eventData.url

                    DankIcon {
                        name: "link"
                        size: 14
                        color: Theme.primary
                        anchors.top: parent.top
                        anchors.topMargin: 2
                    }

                    StyledText {
                        width: parent.width - 14 - Theme.spacingXS
                        text: root.eventData ? root.eventData.url : ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primary
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 2
                        elide: Text.ElideRight

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.eventData && root.eventData.url)
                                    Qt.openUrlExternally(root.eventData.url);
                            }
                        }
                    }
                }

                StyledText {
                    id: descriptionText
                    width: parent.width
                    text: root._descriptionRichText()
                    visible: root.eventData && root.eventData.description
                    textFormat: Text.RichText
                    linkColor: Theme.primary
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.Wrap
                    onLinkActivated: link => Qt.openUrlExternally(link)

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        cursorShape: descriptionText.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.canEdit
                    topPadding: Theme.spacingXS

                    DankButton {
                        text: I18n.tr("Edit")
                        iconName: "edit"
                        buttonHeight: 32
                        onClicked: root.editRequested()
                    }

                    DankButton {
                        text: I18n.tr("Delete")
                        iconName: "delete"
                        buttonHeight: 32
                        backgroundColor: Theme.withAlpha(Theme.error, 0.15)
                        textColor: Theme.error
                        onClicked: root.deleteRequested()
                    }
                }
            }
        }
    }
}
