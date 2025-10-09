import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    property bool hasVolumeSliderInCC: {
        const widgets = SettingsData.controlCenterWidgets || []
        return widgets.some(widget => widget.id === "volumeSlider")
    }

    implicitHeight: headerRow.height + (!hasVolumeSliderInCC ? volumeSlider.height : 0) + audioContent.height + Theme.spacingM
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 0
    
    Row {
        id: headerRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.topMargin: Theme.spacingS
        height: 40
        
        StyledText {
            id: headerText
            text: I18n.tr("Audio Devices")
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.surfaceText
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        id: volumeSlider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerRow.bottom
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.topMargin: Theme.spacingXS
        height: 35
        spacing: 0
        visible: !hasVolumeSliderInCC

        Rectangle {
            width: Theme.iconSize + Theme.spacingS * 2
            height: Theme.iconSize + Theme.spacingS * 2
            anchors.verticalCenter: parent.verticalCenter
            radius: (Theme.iconSize + Theme.spacingS * 2) / 2
            color: iconArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"

            MouseArea {
                id: iconArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (AudioService.sink && AudioService.sink.audio) {
                        AudioService.sink.audio.muted = !AudioService.sink.audio.muted
                    }
                }
            }

            DankIcon {
                anchors.centerIn: parent
                name: {
                    if (!AudioService.sink || !AudioService.sink.audio) return "volume_off"
                    let muted = AudioService.sink.audio.muted
                    let volume = AudioService.sink.audio.volume
                    if (muted || volume === 0.0) return "volume_off"
                    if (volume <= 0.33) return "volume_down"
                    if (volume <= 0.66) return "volume_up"
                    return "volume_up"
                }
                size: Theme.iconSize
                color: AudioService.sink && AudioService.sink.audio && !AudioService.sink.audio.muted && AudioService.sink.audio.volume > 0 ? Theme.primary : Theme.surfaceText
            }
        }

        DankSlider {
            readonly property real actualVolumePercent: AudioService.sink && AudioService.sink.audio ? Math.round(AudioService.sink.audio.volume * 100) : 0

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (Theme.iconSize + Theme.spacingS * 2)
            enabled: AudioService.sink && AudioService.sink.audio
            minimum: 0
            maximum: 100
            value: AudioService.sink && AudioService.sink.audio ? Math.min(100, Math.round(AudioService.sink.audio.volume * 100)) : 0
            showValue: true
            unit: "%"
            valueOverride: actualVolumePercent
            thumbOutlineColor: Theme.surfaceVariant

            onSliderValueChanged: function(newValue) {
                if (AudioService.sink && AudioService.sink.audio) {
                    AudioService.sink.audio.volume = newValue / 100
                    if (newValue > 0 && AudioService.sink.audio.muted) {
                        AudioService.sink.audio.muted = false
                    }
                    AudioService.volumeChanged()
                }
            }
        }
    }

    DankFlickable {
        id: audioContent
        anchors.top: volumeSlider.visible ? volumeSlider.bottom : headerRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingM
        anchors.topMargin: volumeSlider.visible ? Theme.spacingS : Theme.spacingM
        contentHeight: audioColumn.height
        clip: true
        
        Column {
            id: audioColumn
            width: parent.width
            spacing: Theme.spacingS
            
            Repeater {
                model: Pipewire.nodes.values.filter(node => {
                    return node.audio && node.isSink && !node.isStream
                })
                
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    
                    width: parent.width
                    height: 50
                    radius: Theme.cornerRadius
                    color: deviceMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Theme.surfaceContainerHighest
                    border.color: modelData === AudioService.sink ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                    border.width: 0
                    
                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        spacing: Theme.spacingS
                        
                        DankIcon {
                            name: {
                                if (modelData.name.includes("bluez"))
                                    return "headset"
                                else if (modelData.name.includes("hdmi"))
                                    return "tv"
                                else if (modelData.name.includes("usb"))
                                    return "headset"
                                else
                                    return "speaker"
                            }
                            size: Theme.iconSize - 4
                            color: modelData === AudioService.sink ? Theme.primary : Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.parent.width - parent.parent.anchors.leftMargin - parent.spacing - Theme.iconSize - Theme.spacingM
                            
                            StyledText {
                                text: AudioService.displayName(modelData)
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: modelData === AudioService.sink ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                                width: parent.width
                                wrapMode: Text.NoWrap
                            }
                            
                            StyledText {
                                text: modelData === AudioService.sink ? "Active" : "Available"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideRight
                                width: parent.width
                                wrapMode: Text.NoWrap
                            }
                        }
                    }
                    
                    MouseArea {
                        id: deviceMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData) {
                                Pipewire.preferredDefaultAudioSink = modelData
                            }
                        }
                    }
                }
            }
        }
    }
}