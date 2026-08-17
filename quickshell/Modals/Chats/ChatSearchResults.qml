pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// Message search results.
//
// Matches come from the backend's full-text index over every provider at once,
// so a search spans services the same way the conversation list does.
Item {
    id: root

    required property var hits
    property string query: ""

    signal hitChosen(string provider, string chatId, real ts)

    function formatWhen(timestamp) {
        if (!timestamp)
            return "";
        const date = new Date(timestamp);
        const now = new Date();
        if (date.toDateString() === now.toDateString())
            return SettingsData.use24HourClock ? date.toLocaleTimeString(Qt.locale(), "HH:mm") : date.toLocaleTimeString(Qt.locale(), "h:mm AP");
        return date.toLocaleDateString(Qt.locale(), "d MMM yyyy");
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: Theme.spacingS

        StyledText {
            id: heading
            width: parent.width
            text: I18n.tr("%1 messages found").arg(root.hits.length)
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        DankListView {
            width: parent.width
            height: parent.height - heading.height - parent.spacing
            clip: true
            model: root.hits
            spacing: Theme.spacingXS

            delegate: StyledRect {
                id: hitRow

                required property var modelData

                width: ListView.view.width
                height: hitColumn.implicitHeight + Theme.spacingS * 2
                radius: Theme.cornerRadius
                color: hitArea.containsMouse ? Theme.surfaceHover : "transparent"

                MouseArea {
                    id: hitArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.hitChosen(hitRow.modelData.provider, hitRow.modelData.chatId, hitRow.modelData.ts)
                }

                Column {
                    id: hitColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Theme.spacingS
                    spacing: 2

                    Row {
                        width: parent.width
                        spacing: Theme.spacingXS

                        StyledText {
                            text: hitRow.modelData.chatName || hitRow.modelData.chatId
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.primary
                            elide: Text.ElideRight
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.formatWhen(hitRow.modelData.ts)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: {
                            const who = hitRow.modelData.fromMe ? I18n.tr("You") : (hitRow.modelData.senderName || "");
                            return who !== "" ? who + ": " + (hitRow.modelData.text || "") : (hitRow.modelData.text || "");
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
