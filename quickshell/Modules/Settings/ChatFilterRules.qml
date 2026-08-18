import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets
import "../../Modals/Chats/ChatFilters.js" as ChatFilters

// Rules deciding which conversations the chat list shows.
//
// Deliberately generic: a rule matches a tag, a name, a handle or a provider,
// and hides or shows what it matches. Tags come from the providers themselves,
// so a WhatsApp status, a mail label and whatever a future service invents are
// all filtered by the same machinery without the shell learning about any of
// them.
Column {
    id: root

    spacing: Theme.spacingM

    // Every tag any conversation carries, offered as suggestions.
    property var knownTags: []

    Component.onCompleted: root.refreshTags()

    function refreshTags() {
        if (!ChatService.available)
            return;
        DMSService.sendRequest("chat.tags", null, response => {
            if (!response.error)
                root.knownTags = response.result?.tags || [];
        });
    }

    function rules() {
        return SettingsData.chatFilters || [];
    }

    function updateRule(index, changes) {
        const next = JSON.parse(JSON.stringify(root.rules()));
        if (index < 0 || index >= next.length)
            return;
        for (const key in changes)
            next[index][key] = changes[key];
        SettingsData.set("chatFilters", next);
    }

    function addRule() {
        const next = JSON.parse(JSON.stringify(root.rules()));
        next.push(ChatFilters.defaultRule());
        SettingsData.set("chatFilters", next);
    }

    function removeRule(index) {
        const next = JSON.parse(JSON.stringify(root.rules()));
        next.splice(index, 1);
        SettingsData.set("chatFilters", next);
    }

    StyledText {
        width: parent.width
        text: I18n.tr("A rule hides or shows conversations matching a tag, name, handle or provider. Show wins over hide, so a broad rule can be carved out with a narrow one.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        visible: root.knownTags.length > 0
        text: I18n.tr("Tags in use: %1").arg(root.knownTags.join(", "))
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: root.rules()

        StyledRect {
            id: ruleRow

            required property var modelData
            required property int index

            width: root.width
            height: ruleColumn.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius / 2
            color: Theme.withAlpha(Theme.surfaceVariantText, 0.08)

            Column {
                id: ruleColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - removeButton.width - enabledToggle.width - Theme.spacingS * 2
                        text: ChatFilters.describe(ruleRow.modelData)
                        font.pixelSize: Theme.fontSizeMedium
                        color: ruleRow.modelData.enabled === false ? Theme.surfaceVariantText : Theme.surfaceText
                        elide: Text.ElideRight
                    }

                    DankToggle {
                        id: enabledToggle
                        anchors.verticalCenter: parent.verticalCenter
                        checked: ruleRow.modelData.enabled !== false
                        onToggled: checked => root.updateRule(ruleRow.index, {
                                "enabled": checked
                            })
                    }

                    DankActionButton {
                        id: removeButton
                        anchors.verticalCenter: parent.verticalCenter
                        buttonSize: 28
                        iconName: "delete"
                        iconColor: Theme.error
                        onClicked: root.removeRule(ruleRow.index)
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankDropdown {
                        width: (parent.width - Theme.spacingS * 2) * 0.28
                        options: ChatFilters.FIELDS
                        currentValue: ruleRow.modelData.field
                        onValueChanged: value => root.updateRule(ruleRow.index, {
                                "field": value
                            })
                    }

                    DankDropdown {
                        width: (parent.width - Theme.spacingS * 2) * 0.28
                        options: ChatFilters.MODES
                        currentValue: ruleRow.modelData.mode
                        onValueChanged: value => root.updateRule(ruleRow.index, {
                                "mode": value
                            })
                    }

                    DankDropdown {
                        width: (parent.width - Theme.spacingS * 2) * 0.44
                        options: ChatFilters.ACTIONS
                        currentValue: ruleRow.modelData.action
                        onValueChanged: value => root.updateRule(ruleRow.index, {
                                "action": value
                            })
                    }
                }

                DankTextField {
                    width: parent.width
                    text: ruleRow.modelData.value || ""
                    placeholderText: ruleRow.modelData.field === "tag" ? I18n.tr("Tag, for example archived or status") : I18n.tr("Text to match")

                    onEditingFinished: root.updateRule(ruleRow.index, {
                            "value": text
                        })
                }
            }
        }
    }

    StyledText {
        width: parent.width
        visible: root.rules().length === 0
        text: I18n.tr("No filters. Every conversation is shown, including archived ones, statuses and channels.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Row {
        spacing: Theme.spacingS

        DankButton {
            text: I18n.tr("Add filter")
            iconName: "add"
            backgroundColor: "transparent"
            textColor: Theme.surfaceText
            onClicked: root.addRule()
        }

        // The common case, offered as one press rather than three dropdowns.
        DankButton {
            text: I18n.tr("Hide archived, statuses and channels")
            iconName: "filter_alt"
            backgroundColor: "transparent"
            textColor: Theme.surfaceText
            visible: root.rules().length === 0
            onClicked: {
                const next = [];
                for (const tag of ["archived", "status", "channel", "broadcast"]) {
                    next.push({
                        "field": "tag",
                        "mode": "is",
                        "value": tag,
                        "action": "hide",
                        "enabled": true
                    });
                }
                SettingsData.set("chatFilters", next);
            }
        }
    }
}
