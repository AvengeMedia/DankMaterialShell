import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankOSD {
    id: root

    readonly property bool useVertical: isVerticalLayout

    osdWidth: useVertical ? (40 + Theme.spacingS * 2) : Math.min(260, Screen.width - Theme.spacingM * 2)
    osdHeight: useVertical ? Math.min(260, Screen.height - Theme.spacingM * 2) : (40 + Theme.spacingS * 2)
    autoHideInterval: 3000
    enableMouseInteraction: true

    Connections {
        target: AudioService.sink && AudioService.sink.audio ? AudioService.sink.audio : null

        function onVolumeChanged() {
            if (!AudioService.suppressOSD && SettingsData.osdVolumeEnabled) {
                root.show()
            }
        }

        function onMutedChanged() {
            if (!AudioService.suppressOSD && SettingsData.osdVolumeEnabled) {
                root.show()
            }
        }
    }

    Connections {
        target: AudioService

        function onSinkChanged() {
            if (root.shouldBeVisible && SettingsData.osdVolumeEnabled) {
                root.show()
            }
        }
    }

    content: Loader {
        anchors.fill: parent
        sourceComponent: useVertical ? verticalContent : horizontalContent
    }

    Component {
        id: horizontalContent

        Item {
            property int gap: Theme.spacingS

            anchors.centerIn: parent
            width: parent.width - Theme.spacingS * 2
            height: 40

            Rectangle {
                width: Theme.iconSize
                height: Theme.iconSize
                radius: Theme.iconSize / 2
                color: "transparent"
                x: parent.gap
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    anchors.centerIn: parent
                    name: AudioService.sink && AudioService.sink.audio && AudioService.sink.audio.muted ? "volume_off" : "volume_up"
                    size: Theme.iconSize
                    color: muteButton.containsMouse ? Theme.primary : Theme.surfaceText
                }

                MouseArea {
                    id: muteButton

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        AudioService.toggleMute()
                    }
                    onContainsMouseChanged: {
                        setChildHovered(containsMouse || volumeSlider.containsMouse)
                    }
                }
            }

            DankSlider {
                id: volumeSlider

                readonly property real actualVolumePercent: AudioService.sink && AudioService.sink.audio ? Math.round(AudioService.sink.audio.volume * 100) : 0
                readonly property real displayPercent: actualVolumePercent

                orientation: DankSlider.Horizontal
                width: parent.width - Theme.iconSize - parent.gap * 3
                height: 40
                x: parent.gap * 2 + Theme.iconSize
                anchors.verticalCenter: parent.verticalCenter
                minimum: 0
                maximum: SettingsData.maxSystemVolume
                reference: 100
                enabled: AudioService.sink && AudioService.sink.audio
                showValue: true
                unit: "%"
                thumbOutlineColor: Theme.surfaceContainer
                valueOverride: displayPercent
                alwaysShowValue: SettingsData.osdAlwaysShowValue
                tooltipPlacement: [
                    SettingsData.Position.Top,
                    SettingsData.Position.TopCenter,
                    SettingsData.Position.Left,
                ].includes(SettingsData.osdPosition) ? DankSlider.After : DankSlider.Before

                Component.onCompleted: {
                    if (AudioService.sink && AudioService.sink.audio) {
                        value = Math.min(SettingsData.maxSystemVolume, Math.round(AudioService.sink.audio.volume * 100))
                    }
                }

                onSliderValueChanged: newValue => {
                                          if (AudioService.sink && AudioService.sink.audio) {
                                              AudioService.suppressOSD = true
                                              AudioService.sink.audio.volume = newValue / 100
                                              AudioService.suppressOSD = false
                                              resetHideTimer()
                                          }
                                      }

                onContainsMouseChanged: {
                    setChildHovered(containsMouse || muteButton.containsMouse)
                }

                Connections {
                    target: AudioService.sink && AudioService.sink.audio ? AudioService.sink.audio : null

                    function onVolumeChanged() {
                        if (volumeSlider && !volumeSlider.pressed) {
                            volumeSlider.value = Math.min(SettingsData.maxSystemVolume, Math.round(AudioService.sink.audio.volume * 100))
                        }
                    }
                }
            }
        }
    }

    Component {
        id: verticalContent

        Item {
            anchors.fill: parent
            property int gap: Theme.spacingS

            Rectangle {
                width: Theme.iconSize
                height: Theme.iconSize
                radius: Theme.iconSize / 2
                color: "transparent"
                anchors.horizontalCenter: parent.horizontalCenter
                y: gap

                DankIcon {
                    anchors.centerIn: parent
                    name: AudioService.sink && AudioService.sink.audio && AudioService.sink.audio.muted ? "volume_off" : "volume_up"
                    size: Theme.iconSize
                    color: muteButtonVert.containsMouse ? Theme.primary : Theme.surfaceText
                }

                MouseArea {
                    id: muteButtonVert

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        AudioService.toggleMute()
                    }
                    onContainsMouseChanged: {
                        setChildHovered(containsMouse || vertSliderArea.containsMouse)
                    }
                }
            }

            DankSlider {
                id: volumeSlider

                readonly property real actualVolumePercent: AudioService.sink && AudioService.sink.audio ? Math.round(AudioService.sink.audio.volume * 100) : 0
                readonly property real displayPercent: actualVolumePercent

                orientation: DankSlider.Vertical
                width: 12
                height: parent.height - Theme.iconSize - gap * 3 - 24
                anchors.horizontalCenter: parent.horizontalCenter
                y: gap * 2 + Theme.iconSize
                minimum: 0
                maximum: SettingsData.maxSystemVolume
                reference: 100
                enabled: AudioService.sink && AudioService.sink.audio
                showValue: true
                unit: "%"
                thumbOutlineColor: Theme.surfaceContainer
                valueOverride: displayPercent
                alwaysShowValue: SettingsData.osdAlwaysShowValue
                tooltipPlacement: SettingsData.osdPosition === SettingsData.Position.RightCenter ? DankSlider.Before : DankSlider.After

                Component.onCompleted: {
                    if (AudioService.sink && AudioService.sink.audio) {
                        value = Math.min(SettingsData.maxSystemVolume, Math.round(AudioService.sink.audio.volume * 100))
                    }
                }

                onSliderValueChanged: newValue => {
                                          if (AudioService.sink && AudioService.sink.audio) {
                                              AudioService.suppressOSD = true
                                              AudioService.sink.audio.volume = newValue / 100
                                              AudioService.suppressOSD = false
                                              resetHideTimer()
                                          }
                                      }

                onContainsMouseChanged: {
                    setChildHovered(containsMouse || muteButtonVert.containsMouse)
                }

                Connections {
                    target: AudioService.sink && AudioService.sink.audio ? AudioService.sink.audio : null

                    function onVolumeChanged() {
                        if (volumeSlider && !volumeSlider.pressed) {
                            volumeSlider.value = Math.min(SettingsData.maxSystemVolume, Math.round(AudioService.sink.audio.volume * 100))
                        }
                    }
                }
            }

            StyledText {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: gap
                text: volumeSlider.value + "%"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                visible: SettingsData.osdAlwaysShowValue
            }
        }
    }

    onOsdShown: {
        if (AudioService.sink && AudioService.sink.audio && contentLoader.item && contentLoader.item.item) {
            if (!useVertical) {
                const slider = contentLoader.item.item.children[0].children[1]
                if (slider && slider.value !== undefined) {
                    slider.value = Math.min(SettingsData.maxSystemVolume, Math.round(AudioService.sink.audio.volume * 100))
                }
            }
        }
    }
}
