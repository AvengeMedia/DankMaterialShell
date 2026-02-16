import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    readonly property var muxTypeOptions: [
        "tmux",
        "zellij"
    ]

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

            SettingsCard {
                tab: "mux"
                tags: ["mux", "multiplexer", "tmux", "zellij", "type"]
                title: I18n.tr("Multiplexer")
                iconName: "terminal"

                SettingsDropdownRow {
                    tab: "mux"
                    tags: ["mux", "multiplexer", "tmux", "zellij", "type", "backend"]
                    settingKey: "muxType"
                    text: I18n.tr("Multiplexer Type")
                    description: I18n.tr("Terminal multiplexer backend to use")
                    options: root.muxTypeOptions
                    currentValue: SettingsData.muxType
                    onValueChanged: value => SettingsData.set("muxType", value)
                }
            }

            SettingsCard {
                tab: "mux"
                tags: ["mux", "terminal", "custom", "command", "script"]
                title: I18n.tr("Terminal")
                iconName: "desktop_windows"

                SettingsToggleRow {
                    tab: "mux"
                    tags: ["mux", "custom", "command", "override"]
                    settingKey: "muxUseCustomCommand"
                    text: I18n.tr("Use Custom Command")
                    description: I18n.tr("Override terminal with a custom command or script")
                    checked: SettingsData.muxUseCustomCommand
                    onToggled: checked => SettingsData.set("muxUseCustomCommand", checked)
                }

                Column {
                    width: parent?.width ?? 0
                    spacing: Theme.spacingS
                    visible: SettingsData.muxUseCustomCommand

                    StyledText {
                        width: parent.width
                        text: I18n.tr("The custom command used when attaching to sessions (receives the session name as the first argument)")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    DankTextField {
                        width: parent.width
                        text: SettingsData.muxCustomCommand
                        placeholderText: I18n.tr("Enter command or script path")
                        onTextEdited: SettingsData.set("muxCustomCommand", text)
                    }
                }

            }

            SettingsCard {
                tab: "mux"
                tags: ["mux", "session", "filter", "exclude", "hide"]
                title: I18n.tr("Session Filter")
                iconName: "filter_list"

                Column {
                    width: parent?.width ?? 0
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Comma-separated list of session names to hide. Wrap in slashes for regex (e.g., /^_.*/).")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    DankTextField {
                        width: parent.width
                        text: SettingsData.muxSessionFilter
                        placeholderText: I18n.tr("e.g., scratch, /^tmp_.*/, build")
                        onTextEdited: SettingsData.set("muxSessionFilter", text)
                    }
                }
            }
        }
    }
}
