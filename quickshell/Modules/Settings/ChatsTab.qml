import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

// Settings for the chat system.
//
// Shared storage preferences, then one container per installed chat plugin.
// Notification policy is deliberately not global: it lives inside each
// provider's container, because a work account and a family one rarely want the
// same answer.
//
// A chat plugin is a bridge process supervised by the backend rather than QML
// loaded into the shell, so enabling one here starts a process. See
// docs/CHAT-PLUGINS.md.
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

            StyledText {
                width: parent.width
                visible: ChatService.available
                text: I18n.tr("Providers")
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: I18n.tr("No chat providers installed. Install one from the plugin browser under Plugins.")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                visible: ChatService.available && ChatService.providers.length === 0
            }

            // One container per installed chat plugin. Each holds its own
            // state, warning, sign-in, notification policy and plugin settings,
            // so providers never share a settings surface.
            Repeater {
                model: ChatService.providers

                ChatProviderRow {
                    required property var modelData

                    width: mainColumn.width
                    provider: modelData
                }
            }
        }
    }
}
