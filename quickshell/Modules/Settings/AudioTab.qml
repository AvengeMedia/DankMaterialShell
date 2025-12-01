import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: dockTab

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

            // Max Volume Section
            StyledRect {
                width: parent.width
                height: maxVolumeSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: maxVolumeSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "instant_mix"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Max Volumes")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            id: maxSystemVolumeText
                            text: I18n.tr("Max System Volume")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            height: parent.height
                            width: parent.width - maxSystemVolumeText.width - resetMaxSystemVolumeBtn.width - Theme.spacingM * 2
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        DankActionButton {
                            id: resetMaxSystemVolumeBtn
                            buttonSize: 24
                            iconName: "refresh"
                            iconSize: 16
                            backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                            iconColor: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                SettingsData.set("maxSystemVolume", 100);
                                maxSystemVolumeSlider.value = 100
                            }
                        }
                    }

                    DankSlider {
                        id: maxSystemVolumeSlider
                        width: parent.width
                        height: 24
                        value: SettingsData.maxSystemVolume
                        minimum: 0
                        maximum: 200
                        reference: 100
                        unit: "%"
                        showValue: true
                        wheelEnabled: false
                        thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                        onSliderValueChanged: newValue => {
                            SettingsData.set("maxSystemVolume", newValue);
                        }
                    }

                    Row {
                        id: maxSystemWarning
                        spacing: Theme.spacingS
                        opacity: maxSystemVolumeSlider.value > 100 ? 1 : 0
                        height: maxSystemVolumeSlider.value > 100 ? maxSystemVolumeWarningText.height : 0
                        width: parent.width

                        DankIcon {
                            name: "warning"
                            size: Theme.iconSizeSmall
                            color: Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            id: maxSystemVolumeWarningText
                            text: I18n.tr("Setting volumes above 100% could cause distortion or in rare cases damage. Do so at your own risk.")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(parent.width - Theme.iconSizeSmall - Theme.spacingS, 440)
                            wrapMode: Text.WordWrap
                        }

                        states: State {
                            name: "moved"; when: maxSystemVolumeSlider.value > 100
                            PropertyChanges {
                                target: maxSystemWarning
                                opacity: maxSystemVolumeSlider.value > 100 ? 1 : 0
                                height: maxSystemVolumeSlider.value > 100 ? maxSystemVolumeWarningText.height : 0
                            }
                        }

                        transitions: Transition {
                            NumberAnimation { properties: "height,opacity"; easing.type: Easing.OutQuad }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledText {
                            id: maxMediaVolumeText
                            text: I18n.tr("Max Media Volume")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            height: parent.height
                            width: parent.width - maxMediaVolumeText.width - resetMaxMediaVolumeBtn.width - Theme.spacingM * 2
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        DankActionButton {
                            id: resetMaxMediaVolumeBtn
                            buttonSize: 24
                            iconName: "refresh"
                            iconSize: 16
                            backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                            iconColor: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                SettingsData.set("maxMediaVolume", 100);
                                maxMediaVolumeSlider.value = 100
                            }
                        }
                    }

                    DankSlider {
                        id: maxMediaVolumeSlider
                        width: parent.width
                        height: 24
                        value: SettingsData.maxMediaVolume
                        minimum: 0
                        maximum: 200
                        reference: 100
                        unit: "%"
                        showValue: true
                        wheelEnabled: false
                        thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                        onSliderValueChanged: newValue => {
                            SettingsData.set("maxMediaVolume", newValue);
                        }
                    }

                    Row {
                        spacing: Theme.spacingS
                        opacity: maxMediaVolumeSlider.value > 100 ? 1 : 0
                        height: maxMediaVolumeSlider.value > 100 ? maxMediaVolumeWarningText.height : 0
                        width: parent.width

                        DankIcon {
                            name: "warning"
                            size: Theme.iconSizeSmall
                            color: Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            id: maxMediaVolumeWarningText
                            text: I18n.tr("Setting volumes above 100% could cause distortion or in rare cases damage. Do so at your own risk.")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(parent.width - Theme.iconSizeSmall - Theme.spacingS, 440)
                            wrapMode: Text.WordWrap
                        }

                        states: State {
                            name: "moved"; when: maxSystemVolumeSlider.value > 100
                            PropertyChanges {
                                target: maxSystemWarning
                                opacity: maxSystemVolumeSlider.value > 100 ? 1 : 0
                                height: maxSystemVolumeSlider.value > 100 ? maxSystemVolumeWarningText.height : 0
                            }
                        }

                        transitions: Transition {
                            NumberAnimation { properties: "height,opacity"; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }
        }
    }
}
