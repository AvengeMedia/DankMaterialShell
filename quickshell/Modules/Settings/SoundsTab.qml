import QtQuick
import qs.Common
import qs.Services
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
                tab: "sounds"
                tags: ["sound", "audio", "notification", "volume"]
                title: I18n.tr("System Sounds")
                iconName: SettingsData.soundsEnabled ? "volume_up" : "volume_off"
                visible: AudioService.soundsAvailable

                SettingsToggleRow {
                    tab: "sounds"
                    tags: ["sound", "enable", "system"]
                    settingKey: "soundsEnabled"
                    text: I18n.tr("Enable System Sounds")
                    description: I18n.tr("Play sounds for system events")
                    checked: SettingsData.soundsEnabled
                    onToggled: checked => SettingsData.set("soundsEnabled", checked)
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: SettingsData.soundsEnabled

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                    }

                    SettingsToggleRow {
                        tab: "sounds"
                        tags: ["sound", "theme", "system"]
                        settingKey: "useSystemSoundTheme"
                        visible: AudioService.gsettingsAvailable
                        text: I18n.tr("Use System Theme")
                        description: I18n.tr("Use sound theme from system settings")
                        checked: SettingsData.useSystemSoundTheme
                        onToggled: checked => SettingsData.set("useSystemSoundTheme", checked)
                    }

                    SettingsDropdownRow {
                        tab: "sounds"
                        tags: ["sound", "theme", "select"]
                        settingKey: "soundTheme"
                        visible: SettingsData.useSystemSoundTheme && AudioService.availableSoundThemes.length > 0
                        enabled: SettingsData.useSystemSoundTheme && AudioService.availableSoundThemes.length > 0
                        text: I18n.tr("Sound Theme")
                        description: I18n.tr("Select system sound theme")
                        options: AudioService.availableSoundThemes
                        currentValue: {
                            const theme = AudioService.currentSoundTheme;
                            if (theme && AudioService.availableSoundThemes.includes(theme))
                                return theme;
                            return AudioService.availableSoundThemes.length > 0 ? AudioService.availableSoundThemes[0] : "";
                        }
                        onValueChanged: value => {
                            if (value && value !== AudioService.currentSoundTheme)
                                AudioService.setSoundTheme(value);
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                        visible: AudioService.gsettingsAvailable
                    }

                    SettingsToggleRow {
                        tab: "sounds"
                        tags: ["sound", "notification", "new"]
                        settingKey: "soundNewNotification"
                        text: I18n.tr("New Notification")
                        description: I18n.tr("Play sound when new notification arrives")
                        checked: SettingsData.soundNewNotification
                        onToggled: checked => SettingsData.set("soundNewNotification", checked)
                    }

                    SettingsToggleRow {
                        tab: "sounds"
                        tags: ["sound", "volume", "changed"]
                        settingKey: "soundVolumeChanged"
                        text: I18n.tr("Volume Changed")
                        description: I18n.tr("Play sound when volume is adjusted")
                        checked: SettingsData.soundVolumeChanged
                        onToggled: checked => SettingsData.set("soundVolumeChanged", checked)
                    }

                    SettingsToggleRow {
                        tab: "sounds"
                        tags: ["sound", "power", "plugged"]
                        settingKey: "soundPluggedIn"
                        visible: BatteryService.batteryAvailable
                        text: I18n.tr("Plugged In")
                        description: I18n.tr("Play sound when power cable is connected")
                        checked: SettingsData.soundPluggedIn
                        onToggled: checked => SettingsData.set("soundPluggedIn", checked)
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: notAvailableText.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
                visible: !AudioService.soundsAvailable

                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "info"
                        size: Theme.iconSizeSmall
                        color: Theme.warning
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        id: notAvailableText
                        font.pixelSize: Theme.fontSizeSmall
                        text: I18n.tr("System sounds are not available. Install canberra-gtk-play for sound support.")
                        wrapMode: Text.WordWrap
                        width: parent.width - Theme.iconSizeSmall - Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
