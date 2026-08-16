import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

// Settings for the chat system.
//
// Two halves: global preferences that apply to every provider, and one row per
// installed chat plugin. A chat plugin is a provider bridge supervised by the
// backend rather than QML loaded into the shell, so enabling one here starts a
// process -- see docs/CHAT-PLUGINS.md.
Item {
    id: root

    // Holding a reference keeps the chat subscription alive while this tab is
    // open, so provider state stays live without polling.
    Ref {
        service: ChatService
    }

    Component.onCompleted: ChatService.rescan()

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            // Nothing works without backend support, so say so plainly rather
            // than showing controls that silently do nothing.
            StyledRect {
                width: parent.width
                height: unavailableColumn.height + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainer
                visible: !ChatService.available

                Column {
                    id: unavailableColumn
                    anchors.centerIn: parent
                    width: parent.width - Theme.spacingL * 2
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Chat support unavailable")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("The DMS backend was built without chat support, or is not running.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "notifications"
                title: I18n.tr("Notifications")
                settingKey: "chatNotifications"
                visible: ChatService.available

                SettingsToggleRow {
                    settingKey: "chatNotificationsEnabled"
                    text: I18n.tr("Notify for new messages")
                    description: I18n.tr("Messages in the conversation you are reading never notify")
                    checked: SettingsData.chatNotificationsEnabled
                    onToggled: checked => SettingsData.set("chatNotificationsEnabled", checked)
                }

                SettingsDivider {
                    width: parent.width
                }

                SettingsToggleRow {
                    settingKey: "chatNotificationPreview"
                    text: I18n.tr("Show message preview")
                    description: I18n.tr("Include the message text; off shows only that something arrived")
                    checked: SettingsData.chatNotificationPreview
                    enabled: SettingsData.chatNotificationsEnabled
                    onToggled: checked => SettingsData.set("chatNotificationPreview", checked)
                }

                SettingsToggleRow {
                    settingKey: "chatNotifyGroups"
                    text: I18n.tr("Notify for group conversations")
                    checked: SettingsData.chatNotifyGroups
                    enabled: SettingsData.chatNotificationsEnabled
                    onToggled: checked => SettingsData.set("chatNotifyGroups", checked)
                }

                SettingsToggleRow {
                    settingKey: "chatNotifyArchived"
                    text: I18n.tr("Notify for archived conversations")
                    description: I18n.tr("Archived conversations are normally kept out of the way entirely")
                    checked: SettingsData.chatNotifyArchived
                    enabled: SettingsData.chatNotificationsEnabled
                    onToggled: checked => SettingsData.set("chatNotifyArchived", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "database"
                title: I18n.tr("Storage")
                settingKey: "chatStorage"
                visible: ChatService.available

                SettingsSliderRow {
                    settingKey: "chatHistoryRetentionDays"
                    text: I18n.tr("Keep message history for")
                    description: SettingsData.chatHistoryRetentionDays === 0 ? I18n.tr("Messages are kept forever") : I18n.tr("Messages older than this are deleted")
                    value: SettingsData.chatHistoryRetentionDays
                    minimum: 0
                    maximum: 365
                    step: 30
                    unit: SettingsData.chatHistoryRetentionDays === 0 ? "" : I18n.tr(" days")
                    defaultValue: 0
                    onSliderDragFinished: finalValue => SettingsData.set("chatHistoryRetentionDays", finalValue)
                }

                SettingsDivider {
                    width: parent.width
                }

                SettingsSliderRow {
                    settingKey: "chatMediaCacheMaxMB"
                    text: I18n.tr("Attachment cache limit")
                    description: I18n.tr("Cached images and files are re-downloaded on demand once evicted")
                    value: SettingsData.chatMediaCacheMaxMB
                    minimum: 64
                    maximum: 4096
                    step: 64
                    unit: " MB"
                    defaultValue: 512
                    onSliderDragFinished: finalValue => SettingsData.set("chatMediaCacheMaxMB", finalValue)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "forum"
                title: I18n.tr("Providers")
                settingKey: "chatProviders"
                visible: ChatService.available

                StyledText {
                    width: parent.width
                    text: I18n.tr("No chat providers installed. Install one from the plugin browser under Plugins.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    visible: ChatService.providers.length === 0
                }

                Repeater {
                    model: ChatService.providers

                    ChatProviderRow {
                        required property var modelData

                        width: parent.width
                        provider: modelData
                    }
                }
            }
        }
    }
}
