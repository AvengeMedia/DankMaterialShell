import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

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
                width: parent.width
                iconName: "music_note"
                title: I18n.tr("Media Player Settings")
                settingKey: "mediaPlayer"

                SettingsToggleRow {
                    text: I18n.tr("Wave Progress Bars")
                    description: I18n.tr("Use animated wave progress bars for media playback")
                    checked: SettingsData.waveProgressEnabled
                    onToggled: checked => SettingsData.set("waveProgressEnabled", checked)
                }

                SettingsToggleRow {
                    text: I18n.tr("Scroll song title")
                    description: I18n.tr("Scroll title if it doesn't fit in widget")
                    checked: SettingsData.scrollTitleEnabled
                    onToggled: checked => SettingsData.set("scrollTitleEnabled", checked)
                }

                SettingsToggleRow {
                    text: I18n.tr("Audio Visualizer")
                    description: I18n.tr("Show cava audio visualizer in media widget")
                    checked: SettingsData.audioVisualizerEnabled
                    onToggled: checked => SettingsData.set("audioVisualizerEnabled", checked)
                }

                SettingsDropdownRow {
                    property var scrollOpts: {
                        "Change Volume": "volume",
                        "Change Song": "song",
                        "Nothing": "nothing"
                    }

                    text: I18n.tr("Scroll Wheel")
                    description: I18n.tr("Scroll wheel behavior on media widget")
                    settingKey: "audioScrollMode"
                    tags: ["media", "music", "scroll"]
                    options: Object.keys(scrollOpts).sort()
                    currentValue: {
                        Object.keys(scrollOpts).find(key => scrollOpts[key] === SettingsData.audioScrollMode) ?? "volume"
                    }
                    onValueChanged: value => {
                        SettingsData.set("audioScrollMode", scrollOpts[value])
                    }
                }
            }
        }
    }
}
