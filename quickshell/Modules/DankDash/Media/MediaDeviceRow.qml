pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

SettingsRow {
    id: root

    required property var node
    property bool selected: false
    property bool playing: false

    signal activated

    title: AudioService.displayName(node)
    subtitle: {
        if (!selected)
            return I18n.tr("Available");
        if (node?.audio?.muted)
            return I18n.tr("Muted");
        return playing ? I18n.tr("Playing", "Audio output currently playing media") : I18n.tr("Active");
    }
    clickable: true
    paddingH: Theme.spacingL
    paddingV: Theme.spacingL
    rowColor: selected ? Theme.selectedContainer : Theme.secondaryContainer
    titleColor: selected ? Theme.onSelectedContainer : Theme.onSecondaryContainer
    subtitleColor: titleColor
    topRadius: Theme.cornerRadiusLIncreased
    bottomRadius: Theme.cornerRadiusLIncreased
    Accessible.selected: selected
    onClicked: activated()

    leading: Rectangle {
        width: Theme.iconButtonSize
        height: width
        radius: Theme.fullRadius(width, height)
        color: root.selected ? Theme.onPrimary : Theme.chipSurface

        DankIcon {
            anchors.centerIn: parent
            name: AudioService.sinkIcon(root.node)
            size: Theme.iconSizeMedium
            color: root.selected ? Theme.onSelectedContainer : Theme.onSurfaceVariant
        }
    }

    body: Loader {
        width: parent.width
        active: root.selected && !!root.node?.audio
        visible: active

        sourceComponent: RowLayout {
            spacing: Theme.spacingS

            DankActionButton {
                buttonSize: Theme.iconButtonSize
                iconName: volumeSlider.volumeIcon
                iconColor: root.titleColor
                Accessible.name: volumeSlider.muteLabel
                onClicked: volumeSlider.muteRequested()
            }

            MediaVolumeSlider {
                id: volumeSlider
                Layout.fillWidth: true
                size: "xs"
                insetIcon: ""
                wheelInsideScrollable: false
                volume: root.node?.audio?.volume ?? 0
                muted: root.node?.audio?.muted ?? false
                maximumVolume: AudioService.getMaxVolumePercent(root.node)
                fillColor: Theme.onSelectedContainer
                fillTextColor: Theme.selectedContainer
                trackColor: Theme.onPrimary
                trackTextColor: Theme.onSelectedContainer
                thumbOutlineColor: Theme.selectedContainer
                Accessible.name: I18n.tr("Volume") + ": " + root.title
                onVolumeChangedByUser: volume => {
                    const audio = root.node?.audio;
                    if (!audio)
                        return;
                    SessionData.suppressOSDTemporarily();
                    audio.volume = volume;
                    if (volume > 0)
                        audio.muted = false;
                }
                onMuteRequested: {
                    const audio = root.node?.audio;
                    if (!audio)
                        return;
                    SessionData.suppressOSDTemporarily();
                    audio.muted = !audio.muted;
                }
            }
        }
    }
}
