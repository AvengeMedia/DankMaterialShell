import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Settings.Widgets
import qs.Services

Item {
    id: root

    property var desktopApps: []
    property var parentModal: null

    Component.onCompleted: {
        desktopApps = AppSearchService.getVisibleApplications() || [];
    }

    Component.onDestruction: {
        desktopApps = [];
    }

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

                SettingsToggleRow {
                    text: I18n.tr("Adaptive Media Width")
                    description: I18n.tr("Shrink the media widget to fit shorter song titles while still respecting the configured maximum size")
                    checked: SettingsData.mediaAdaptiveWidthEnabled
                    onToggled: checked => SettingsData.set("mediaAdaptiveWidthEnabled", checked)
                }

                SettingsToggleRow {
                    text: I18n.tr("Use album art accent")
                    description: I18n.tr("Use colors extracted from album art instead of system theme colors")
                    checked: SettingsData.mediaUseAlbumArtAccent
                    onToggled: checked => SettingsData.set("mediaUseAlbumArtAccent", checked)
                }

                SettingsDropdownRow {
                    property var scrollOptsInternal: ["volume", "song", "nothing"]
                    property var scrollOptsDisplay: [I18n.tr("Change Volume", "media scroll wheel option"), I18n.tr("Change Song", "media scroll wheel option"), I18n.tr("Nothing", "media scroll wheel option")]

                    text: I18n.tr("Scroll Wheel")
                    description: I18n.tr("Scroll wheel behavior on media widget")
                    settingKey: "audioScrollMode"
                    tags: ["media", "music", "scroll"]
                    options: scrollOptsDisplay
                    currentValue: {
                        const idx = scrollOptsInternal.indexOf(SettingsData.audioScrollMode);
                        return idx >= 0 ? scrollOptsDisplay[idx] : scrollOptsDisplay[0];
                    }
                    onValueChanged: value => {
                        const idx = scrollOptsDisplay.indexOf(value);
                        if (idx >= 0)
                            SettingsData.set("audioScrollMode", scrollOptsInternal[idx]);
                    }
                }

                Item {
                    width: parent.width
                    height: audioWheelScrollAmountColumn.height
                    visible: SettingsData.audioScrollMode == "volume"
                    opacity: visible ? 1 : 0

                    Column {
                        id: audioWheelScrollAmountColumn
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingL
                        spacing: Theme.spacingS

                        StyledText {
                            anchors.left: parent.left
                            text: I18n.tr("Adjust volume per scroll indent")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignLeft
                        }

                        DankTextField {
                            anchors.left: parent.left
                            width: 100
                            height: 28
                            placeholderText: "5"
                            text: SettingsData.audioWheelScrollAmount
                            maximumLength: 2
                            font.pixelSize: Theme.fontSizeSmall
                            topPadding: Theme.spacingXS
                            bottomPadding: Theme.spacingXS
                            onEditingFinished: SettingsData.set("audioWheelScrollAmount", parseInt(text, 10))
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.emphasizedEasing
                        }
                    }
                }

                SettingsToggleRow {
                    text: I18n.tr("Device list scroll volume")
                    description: I18n.tr("Allow adjusting device volume by scrolling on the right half of items in the device list")
                    checked: SettingsData.audioDeviceScrollVolumeEnabled
                    onToggled: checked => SettingsData.set("audioDeviceScrollVolumeEnabled", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "do_not_disturb_on"
                title: I18n.tr("Excluded Media Players")
                settingKey: "mediaExcludePlayers"
                tags: ["media", "music", "exclude", "ignore", "player", "mpris"]

                Column {
                    width: parent.width
                    spacing: Theme.spacingM

                    StyledText {
                        text: I18n.tr("Prevent specific applications from displaying in the media controllers (e.g., browser audio streams, background tools). Matches player identity or desktop file name case-insensitively.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        DankTextField {
                            id: newExcludePlayerField
                            width: parent.width - addBtn.width - selectAppBtn.width - Theme.spacingS * 2
                            height: 36
                            placeholderText: I18n.tr("App name or identity (e.g., firefox)")
                            font.pixelSize: Theme.fontSizeSmall
                            onAccepted: {
                                if (text.trim() !== "") {
                                    SettingsData.addMediaExcludePlayer(text.trim());
                                    text = "";
                                }
                            }
                        }

                        DankActionButton {
                            id: addBtn
                            buttonSize: 36
                            iconName: "add"
                            iconSize: 20
                            backgroundColor: Theme.primary
                            iconColor: Theme.onPrimary
                            onClicked: {
                                if (newExcludePlayerField.text.trim() !== "") {
                                    SettingsData.addMediaExcludePlayer(newExcludePlayerField.text.trim());
                                    newExcludePlayerField.text = "";
                                }
                            }
                        }

                        DankActionButton {
                            id: selectAppBtn
                            buttonSize: 36
                            iconName: "apps"
                            iconSize: 20
                            backgroundColor: Theme.surfaceContainer
                            iconColor: Theme.primary
                            onClicked: appBrowserPopup.show()
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        Repeater {
                            model: SettingsData.mediaExcludePlayers

                            delegate: Rectangle {
                                width: parent.width
                                height: 48
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceContainer, 0.5)

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingS
                                    spacing: Theme.spacingM

                                    Row {
                                        width: parent.width - deleteBtn.width - Theme.spacingS
                                        height: parent.height
                                        spacing: Theme.spacingS

                                        DankIcon {
                                            name: "music_off"
                                            size: 20
                                            color: Theme.surfaceVariantText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: modelData
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    DankActionButton {
                                        id: deleteBtn
                                        buttonSize: 32
                                        iconName: "delete"
                                        iconSize: 18
                                        iconColor: Theme.error
                                        backgroundColor: "transparent"
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: SettingsData.removeMediaExcludePlayer(index)
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        visible: !SettingsData.mediaExcludePlayers || SettingsData.mediaExcludePlayers.length === 0
                        text: I18n.tr("No excluded players configured")
                        font.pixelSize: Theme.fontSizeSmall
                        font.italic: true
                        color: Theme.surfaceVariantText
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        topPadding: Theme.spacingS
                    }
                }
            }
        }
    }

    AppBrowserPopup {
        id: appBrowserPopup
        appsModel: root.desktopApps
        parentModal: root.parentModal
        onAppSelected: appId => {
            var name = appId;
            if (name.endsWith(".desktop")) {
                name = name.slice(0, -8);
            }
            SettingsData.addMediaExcludePlayer(name);
        }
    }
}
