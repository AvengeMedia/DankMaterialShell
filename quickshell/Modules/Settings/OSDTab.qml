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
                iconName: "tune"
                title: I18n.tr("On-screen Displays")
                settingKey: "osd"

                SettingsDropdownRow {
                    settingKey: "osdPosition"
                    text: I18n.tr("OSD Position")
                    description: I18n.tr("Choose where on-screen displays appear on screen")
                    currentValue: {
                        switch (SettingsData.osdPosition) {
                        case SettingsData.Position.Top:
                            return I18n.tr("Top Right", "screen position option");
                        case SettingsData.Position.Left:
                            return I18n.tr("Top Left", "screen position option");
                        case SettingsData.Position.TopCenter:
                            return I18n.tr("Top Center", "screen position option");
                        case SettingsData.Position.Right:
                            return I18n.tr("Bottom Right", "screen position option");
                        case SettingsData.Position.Bottom:
                            return I18n.tr("Bottom Left", "screen position option");
                        case SettingsData.Position.BottomCenter:
                            return I18n.tr("Bottom Center", "screen position option");
                        case SettingsData.Position.LeftCenter:
                            return I18n.tr("Left Center", "screen position option");
                        case SettingsData.Position.RightCenter:
                            return I18n.tr("Right Center", "screen position option");
                        default:
                            return I18n.tr("Bottom Center", "screen position option");
                        }
                    }
                    options: [I18n.tr("Top Right", "screen position option"), I18n.tr("Top Left", "screen position option"), I18n.tr("Top Center", "screen position option"), I18n.tr("Bottom Right", "screen position option"), I18n.tr("Bottom Left", "screen position option"), I18n.tr("Bottom Center", "screen position option"), I18n.tr("Left Center", "screen position option"), I18n.tr("Right Center", "screen position option")]
                    onValueChanged: value => {
                        if (value === I18n.tr("Top Right", "screen position option")) {
                            SettingsData.set("osdPosition", SettingsData.Position.Top);
                        } else if (value === I18n.tr("Top Left", "screen position option")) {
                            SettingsData.set("osdPosition", SettingsData.Position.Left);
                        } else if (value === I18n.tr("Top Center", "screen position option")) {
                            SettingsData.set("osdPosition", SettingsData.Position.TopCenter);
                        } else if (value === I18n.tr("Bottom Right", "screen position option")) {
                            SettingsData.set("osdPosition", SettingsData.Position.Right);
                        } else if (value === I18n.tr("Bottom Left", "screen position option")) {
                            SettingsData.set("osdPosition", SettingsData.Position.Bottom);
                        } else if (value === I18n.tr("Bottom Center", "screen position option")) {
                            SettingsData.set("osdPosition", SettingsData.Position.BottomCenter);
                        } else if (value === I18n.tr("Left Center", "screen position option")) {
                            SettingsData.set("osdPosition", SettingsData.Position.LeftCenter);
                        } else if (value === I18n.tr("Right Center", "screen position option")) {
                            SettingsData.set("osdPosition", SettingsData.Position.RightCenter);
                        }
                    }
                }

                SettingsToggleRow {
                    settingKey: "osdAlwaysShowValue"
                    text: I18n.tr("Always Show Percentage")
                    description: I18n.tr("Display volume and brightness percentage values in OSD popups")
                    checked: SettingsData.osdAlwaysShowValue
                    onToggled: checked => SettingsData.set("osdAlwaysShowValue", checked)
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.15
                }

                SettingsToggleRow {
                    settingKey: "osdVolumeEnabled"
                    text: I18n.tr("Volume")
                    description: I18n.tr("Show on-screen display when volume changes")
                    checked: SettingsData.osdVolumeEnabled
                    onToggled: checked => SettingsData.set("osdVolumeEnabled", checked)
                }

                SettingsToggleRow {
                    settingKey: "osdMediaVolumeEnabled"
                    text: I18n.tr("Media Volume")
                    description: I18n.tr("Show on-screen display when media player volume changes")
                    checked: SettingsData.osdMediaVolumeEnabled
                    onToggled: checked => SettingsData.set("osdMediaVolumeEnabled", checked)
                }

                SettingsToggleRow {
                    settingKey: "osdMediaPlaybackEnabled"
                    text: I18n.tr("Media Playback")
                    description: I18n.tr("Show on-screen display when media player status changes")
                    checked: SettingsData.osdMediaPlaybackEnabled
                    onToggled: checked => SettingsData.set("osdMediaPlaybackEnabled", checked)
                }

                SettingsToggleRow {
                    settingKey: "osdBrightnessEnabled"
                    text: I18n.tr("Brightness")
                    description: I18n.tr("Show on-screen display when brightness changes")
                    checked: SettingsData.osdBrightnessEnabled
                    onToggled: checked => SettingsData.set("osdBrightnessEnabled", checked)
                }

                SettingsToggleRow {
                    settingKey: "osdIdleInhibitorEnabled"
                    text: I18n.tr("Idle Inhibitor")
                    description: I18n.tr("Show on-screen display when idle inhibitor state changes")
                    checked: SettingsData.osdIdleInhibitorEnabled
                    onToggled: checked => SettingsData.set("osdIdleInhibitorEnabled", checked)
                }

                SettingsToggleRow {
                    settingKey: "osdMicMuteEnabled"
                    text: I18n.tr("Microphone Mute")
                    description: I18n.tr("Show on-screen display when microphone is muted/unmuted")
                    checked: SettingsData.osdMicMuteEnabled
                    onToggled: checked => SettingsData.set("osdMicMuteEnabled", checked)
                }

                SettingsToggleRow {
                    settingKey: "osdCapsLockEnabled"
                    text: I18n.tr("Caps Lock")
                    description: I18n.tr("Show on-screen display when caps lock state changes")
                    checked: SettingsData.osdCapsLockEnabled
                    onToggled: checked => SettingsData.set("osdCapsLockEnabled", checked)
                }

                SettingsToggleRow {
                    settingKey: "osdPowerProfileEnabled"
                    text: I18n.tr("Power Profile")
                    description: I18n.tr("Show on-screen display when power profile changes")
                    checked: SettingsData.osdPowerProfileEnabled
                    onToggled: checked => SettingsData.set("osdPowerProfileEnabled", checked)
                }

                SettingsToggleRow {
                    settingKey: "osdAudioOutputEnabled"
                    text: I18n.tr("Audio Output Switch")
                    description: I18n.tr("Show on-screen display when cycling audio output devices")
                    checked: SettingsData.osdAudioOutputEnabled
                    onToggled: checked => SettingsData.set("osdAudioOutputEnabled", checked)
                }
            }
        }
    }
}
