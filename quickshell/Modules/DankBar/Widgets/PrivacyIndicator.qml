import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    section: "right"

    property bool showMicIcon: SettingsData.privacyShowMicIcon
    property bool showCameraIcon: SettingsData.privacyShowCameraIcon
    property bool showScreenSharingIcon: SettingsData.privacyShowScreenShareIcon

    readonly property bool hasActivePrivacy: showMicIcon || showCameraIcon || showScreenSharingIcon || PrivacyService.anyPrivacyActive
    readonly property int activeCount: (showMicIcon ? 1 : PrivacyService.microphoneActive) + (showCameraIcon ? 1 : PrivacyService.cameraActive) + (showScreenSharingIcon ? 1 : PrivacyService.screensharingActive)
    readonly property real contentWidth: hasActivePrivacy ? (activeCount * 18 + (activeCount - 1) * Theme.spacingXS) : 0
    readonly property real contentHeight: hasActivePrivacy ? (activeCount * 18 + (activeCount - 1) * Theme.spacingXS) : 0

    opacity: hasActivePrivacy ? 1 : 0

    states: [
        State {
            name: "hidden_horizontal"
            when: !hasActivePrivacy && !isVerticalOrientation
            PropertyChanges {
                target: root
                width: 0
            }
        },
        State {
            name: "hidden_vertical"
            when: !hasActivePrivacy && isVerticalOrientation
            PropertyChanges {
                target: root
                height: 0
            }
        }
    ]

    transitions: [
        Transition {
            NumberAnimation {
                properties: "width,height"
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
    ]

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    content: Component {
        Item {
            implicitWidth: root.hasActivePrivacy ? root.contentWidth : 0
            implicitHeight: root.hasActivePrivacy ? root.contentHeight : 0

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingXS
                visible: root.isVerticalOrientation && root.hasActivePrivacy

                Item {
                    width: 18
                    height: 18
                    visible: root.showMicIcon || PrivacyService.microphoneActive
                    anchors.horizontalCenter: parent.horizontalCenter

                    DankIcon {
                        name: {
                            const sourceAudio = AudioService.source?.audio;
                            const muted = !sourceAudio || sourceAudio.muted || sourceAudio.volume === 0.0;
                            if (muted)
                                return "mic_off";
                            return "mic";
                        }
                        size: Theme.iconSizeSmall
                        color: PrivacyService.microphoneActive ? Theme.error : Theme.surfaceText
                        filled: PrivacyService.microphoneActive
                        anchors.centerIn: parent
                    }
                }

                Item {
                    width: 18
                    height: 18
                    visible: root.showCameraIcon || PrivacyService.cameraActive
                    anchors.horizontalCenter: parent.horizontalCenter

                    DankIcon {
                        name: "camera_video"
                        size: Theme.iconSizeSmall
                        color: PrivacyService.cameraActive ? Theme.error : Theme.surfaceText
                        filled: PrivacyService.cameraActive
                        anchors.centerIn: parent
                    }

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.error
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: -2
                        anchors.topMargin: -1
                        visible: PrivacyService.cameraActive
                    }
                }

                Item {
                    width: 18
                    height: 18
                    visible: root.showScreenSharingIcon || PrivacyService.screensharingActive
                    anchors.horizontalCenter: parent.horizontalCenter

                    DankIcon {
                        name: "screen_share"
                        size: Theme.iconSizeSmall
                        color: PrivacyService.screensharingActive ? Theme.warning : Theme.surfaceText
                        filled: PrivacyService.screensharingActive
                        anchors.centerIn: parent
                    }
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingXS
                visible: !root.isVerticalOrientation && root.hasActivePrivacy

                Item {
                    width: 18
                    height: 18
                    visible: root.showMicIcon || PrivacyService.microphoneActive
                    anchors.verticalCenter: parent.verticalCenter

                    DankIcon {
                        name: {
                            const sourceAudio = AudioService.source?.audio;
                            const muted = !sourceAudio || sourceAudio.muted || sourceAudio.volume === 0.0;
                            if (muted)
                                return "mic_off";
                            return "mic";
                        }
                        size: Theme.iconSizeSmall
                        color: PrivacyService.microphoneActive ? Theme.error : Theme.surfaceText
                        filled: PrivacyService.microphoneActive
                        anchors.centerIn: parent
                    }
                }

                Item {
                    width: 18
                    height: 18
                    visible: root.showCameraIcon || PrivacyService.cameraActive
                    anchors.verticalCenter: parent.verticalCenter

                    DankIcon {
                        name: "camera_video"
                        size: Theme.iconSizeSmall
                        color: PrivacyService.cameraActive ? Theme.error : Theme.surfaceText
                        filled: PrivacyService.cameraActive
                        anchors.centerIn: parent
                    }

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.error
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: -2
                        anchors.topMargin: -1
                        visible: PrivacyService.cameraActive
                    }
                }

                Item {
                    width: 18
                    height: 18
                    visible: root.showScreenSharingIcon || PrivacyService.screensharingActive
                    anchors.verticalCenter: parent.verticalCenter

                    DankIcon {
                        name: "screen_share"
                        size: Theme.iconSizeSmall
                        color: PrivacyService.screensharingActive ? Theme.warning : Theme.surfaceText
                        filled: PrivacyService.screensharingActive
                        anchors.centerIn: parent
                    }
                }
            }
        }
    }

    Rectangle {
        id: tooltip
        width: tooltipText.contentWidth + Theme.spacingM * 2
        height: tooltipText.contentHeight + Theme.spacingS * 2
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
        border.color: Theme.outlineMedium
        border.width: 1
        visible: false
        opacity: root.isMouseHovered && hasActivePrivacy ? 1 : 0
        z: 100
        x: (parent.width - width) / 2
        y: -height - Theme.spacingXS

        StyledText {
            id: tooltipText
            anchors.centerIn: parent
            text: PrivacyService.getPrivacySummary()
            font.pixelSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
            color: Theme.widgetTextColor
        }

        Rectangle {
            width: 8
            height: 8
            color: parent.color
            border.color: parent.border.color
            border.width: parent.border.width
            rotation: 45
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: -4
        }

        Behavior on opacity {
            enabled: hasActivePrivacy && root.visible

            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.standardEasing
            }
        }
    }
}
