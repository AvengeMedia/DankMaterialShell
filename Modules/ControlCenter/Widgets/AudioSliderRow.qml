import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

Row {
    id: root

    property var defaultSink: AudioService.sink
    property color sliderTrackColor: "transparent"

    height: 40
    spacing: 0

    Rectangle {
        width: Theme.iconSize + Theme.spacingS * 2
        height: Theme.iconSize + Theme.spacingS * 2
        anchors.verticalCenter: parent.verticalCenter
        radius: (Theme.iconSize + Theme.spacingS * 2) / 2
        color: iconArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Theme.withAlpha(Theme.primary, 0)

        MouseArea {
            id: iconArea
            anchors.fill: parent
            visible: defaultSink !== null
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (defaultSink) {
                    AudioService.suppressOSD = true
                    defaultSink.audio.muted = !defaultSink.audio.muted
                    AudioService.suppressOSD = false
                }
            }
        }

        DankIcon {
            anchors.centerIn: parent
            name: {
                if (!defaultSink) return "volume_off"

                let volume = defaultSink.audio.volume
                let muted = defaultSink.audio.muted

                if (muted || volume === 0.0) return "volume_off"
                if (volume <= 0.33) return "volume_down"
                if (volume <= 0.66) return "volume_up"
                return "volume_up"
            }
            size: Theme.iconSize
            color: defaultSink && !defaultSink.audio.muted && defaultSink.audio.volume > 0 ? Theme.primary : Theme.surfaceText
        }
    }

    DankSlider {
        readonly property real actualVolumePercent: defaultSink ? Math.round(defaultSink.audio.volume * 100) : 0

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - (Theme.iconSize + Theme.spacingS * 2)
        enabled: defaultSink !== null
        minimum: 0
        maximum: 100
        value: defaultSink ? Math.min(100, Math.round(defaultSink.audio.volume * 100)) : 0
        showValue: true
        unit: "%"
        valueOverride: actualVolumePercent
        thumbOutlineColor: Theme.surfaceContainer
        trackColor: root.sliderTrackColor.a > 0 ? root.sliderTrackColor : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
        onSliderValueChanged: function(newValue) {
            if (defaultSink) {
                defaultSink.audio.volume = newValue / 100.0
                if (newValue > 0 && defaultSink.audio.muted) {
                    defaultSink.audio.muted = false
                }
            }
        }
    }
}