import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

Row {
    id: root

    property var defaultSource: AudioService.source
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
            visible: defaultSource !== null
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (defaultSource) {
                    AudioService.suppressOSD = true
                    defaultSource.audio.muted = !defaultSource.audio.muted
                    AudioService.suppressOSD = false
                }
            }
        }

        DankIcon {
            anchors.centerIn: parent
            name: {
                if (!defaultSource) return "mic_off"

                let volume = defaultSource.audio.volume
                let muted = defaultSource.audio.muted

                if (muted || volume === 0.0) return "mic_off"
                return "mic"
            }
            size: Theme.iconSize
            color: defaultSource && !defaultSource.audio.muted && defaultSource.audio.volume > 0 ? Theme.primary : Theme.surfaceText
        }
    }

    DankSlider {
        readonly property real actualVolumePercent: defaultSource ? Math.round(defaultSource.audio.volume * 100) : 0

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - (Theme.iconSize + Theme.spacingS * 2)
        enabled: defaultSource !== null
        minimum: 0
        maximum: 100
        value: defaultSource ? Math.min(100, Math.round(defaultSource.audio.volume * 100)) : 0
        showValue: true
        unit: "%"
        valueOverride: actualVolumePercent
        thumbOutlineColor: Theme.surfaceContainer
        trackColor: root.sliderTrackColor.a > 0 ? root.sliderTrackColor : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
        onIsDraggingChanged: {
            AudioService.suppressOSD = isDragging
        }
        onSliderValueChanged: function(newValue) {
            if (defaultSource) {
                defaultSource.audio.volume = newValue / 100.0
                if (newValue > 0 && defaultSource.audio.muted) {
                    defaultSource.audio.muted = false
                }
            }
        }
    }
}