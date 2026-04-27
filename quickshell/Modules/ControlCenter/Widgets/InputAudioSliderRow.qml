import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Row {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var defaultSource: AudioService.source
    property color sliderTrackColor: "transparent"
    property real sliderTrackOpacity: Theme.ccSliderTrackOpacity

    height: 40
    spacing: 0

    Rectangle {
        width: Theme.iconSize + Theme.spacingS * 2
        height: Theme.iconSize + Theme.spacingS * 2
        anchors.verticalCenter: parent.verticalCenter
        radius: (Theme.iconSize + Theme.spacingS * 2) / 2
        color: iconArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Theme.withAlpha(Theme.primary, 0)

        DankRipple {
            id: iconRipple
            cornerRadius: parent.radius
        }

        MouseArea {
            id: iconArea
            anchors.fill: parent
            visible: defaultSource !== null
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => iconRipple.trigger(mouse.x, mouse.y)
            onClicked: {
                if (defaultSource?.audio) {
                    SessionData.suppressOSDTemporarily();
                    defaultSource.audio.muted = !defaultSource.audio.muted;
                }
            }
        }

        DankIcon {
            anchors.centerIn: parent
            name: {
                if (!defaultSource?.audio)
                    return "mic_off";

                let volume = defaultSource.audio.volume;
                let muted = defaultSource.audio.muted;

                if (muted || volume === 0.0)
                    return "mic_off";
                return "mic";
            }
            size: Theme.iconSize
            color: defaultSource?.audio && !defaultSource.audio.muted && defaultSource.audio.volume > 0 ? Theme.primary : Theme.surfaceText
        }
    }

    DankSlider {
        readonly property real actualVolumePercent: defaultSource?.audio ? Math.round(defaultSource.audio.volume * 100) : 0

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - (Theme.iconSize + Theme.spacingS * 2)
        enabled: defaultSource?.audio != null
        minimum: 0
        maximum: 100
        value: defaultSource?.audio ? Math.min(100, Math.round(defaultSource.audio.volume * 100)) : 0
        showValue: true
        unit: "%"
        valueOverride: actualVolumePercent
        thumbOutlineColor: Theme.surfaceContainer
        trackColor: root.sliderTrackColor.a > 0 ? root.sliderTrackColor : Theme.ccSliderTrackColor
        trackOpacity: root.sliderTrackOpacity
        onSliderValueChanged: function (newValue) {
            if (defaultSource?.audio) {
                SessionData.suppressOSDTemporarily();
                defaultSource.audio.volume = newValue / 100.0;
                if (newValue > 0 && defaultSource.audio.muted) {
                    defaultSource.audio.muted = false;
                }
            }
        }
    }
}
