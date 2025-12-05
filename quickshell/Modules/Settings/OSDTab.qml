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
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                width: parent.width
                iconName: "tune"
                title: I18n.tr("On-screen Displays")

                SettingsDropdownRow {
                    text: I18n.tr("OSD Position")
                    description: I18n.tr("Choose where on-screen displays appear on screen")
                    currentValue: {
                        switch (SettingsData.osdPosition) {
                        case SettingsData.Position.Top:
                            return "Top Right";
                        case SettingsData.Position.Left:
                            return "Top Left";
                        case SettingsData.Position.TopCenter:
                            return "Top Center";
                        case SettingsData.Position.Right:
                            return "Bottom Right";
                        case SettingsData.Position.Bottom:
                            return "Bottom Left";
                        case SettingsData.Position.BottomCenter:
                            return "Bottom Center";
                        case SettingsData.Position.LeftCenter:
                            return "Left Center";
                        case SettingsData.Position.RightCenter:
                            return "Right Center";
                        default:
                            return "Bottom Center";
                        }
                    }
                    options: ["Top Right", "Top Left", "Top Center", "Bottom Right", "Bottom Left", "Bottom Center", "Left Center", "Right Center"]
                    onValueChanged: value => {
                        switch (value) {
                        case "Top Right":
                            SettingsData.set("osdPosition", SettingsData.Position.Top);
                            break;
                        case "Top Left":
                            SettingsData.set("osdPosition", SettingsData.Position.Left);
                            break;
                        case "Top Center":
                            SettingsData.set("osdPosition", SettingsData.Position.TopCenter);
                            break;
                        case "Bottom Right":
                            SettingsData.set("osdPosition", SettingsData.Position.Right);
                            break;
                        case "Bottom Left":
                            SettingsData.set("osdPosition", SettingsData.Position.Bottom);
                            break;
                        case "Bottom Center":
                            SettingsData.set("osdPosition", SettingsData.Position.BottomCenter);
                            break;
                        case "Left Center":
                            SettingsData.set("osdPosition", SettingsData.Position.LeftCenter);
                            break;
                        case "Right Center":
                            SettingsData.set("osdPosition", SettingsData.Position.RightCenter);
                            break;
                        }
                    }
                }

                SettingsToggleRow {
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
                    text: I18n.tr("Volume")
                    description: I18n.tr("Show on-screen display when volume changes")
                    checked: SettingsData.osdVolumeEnabled
                    onToggled: checked => SettingsData.set("osdVolumeEnabled", checked)
                }

                SettingsToggleRow {
                    text: I18n.tr("Media Volume")
                    description: I18n.tr("Show on-screen display when media player volume changes")
                    checked: SettingsData.osdMediaVolumeEnabled
                    onToggled: checked => SettingsData.set("osdMediaVolumeEnabled", checked)
                }

                SettingsToggleRow {
                    text: I18n.tr("Brightness")
                    description: I18n.tr("Show on-screen display when brightness changes")
                    checked: SettingsData.osdBrightnessEnabled
                    onToggled: checked => SettingsData.set("osdBrightnessEnabled", checked)
                }

                SettingsToggleRow {
                    text: I18n.tr("Idle Inhibitor")
                    description: I18n.tr("Show on-screen display when idle inhibitor state changes")
                    checked: SettingsData.osdIdleInhibitorEnabled
                    onToggled: checked => SettingsData.set("osdIdleInhibitorEnabled", checked)
                }

                SettingsToggleRow {
                    text: I18n.tr("Microphone Mute")
                    description: I18n.tr("Show on-screen display when microphone is muted/unmuted")
                    checked: SettingsData.osdMicMuteEnabled
                    onToggled: checked => SettingsData.set("osdMicMuteEnabled", checked)
                }

                SettingsToggleRow {
                    text: I18n.tr("Caps Lock")
                    description: I18n.tr("Show on-screen display when caps lock state changes")
                    checked: SettingsData.osdCapsLockEnabled
                    onToggled: checked => SettingsData.set("osdCapsLockEnabled", checked)
                }

                SettingsToggleRow {
                    text: I18n.tr("Power Profile")
                    description: I18n.tr("Show on-screen display when power profile changes")
                    checked: SettingsData.osdPowerProfileEnabled
                    onToggled: checked => SettingsData.set("osdPowerProfileEnabled", checked)
                }

                SettingsToggleRow {
                    text: I18n.tr("Audio Output Switch")
                    description: I18n.tr("Show on-screen display when cycling audio output devices")
                    checked: SettingsData.osdAudioOutputEnabled
                    onToggled: checked => SettingsData.set("osdAudioOutputEnabled", checked)
                }
            }
        }
    }
}
