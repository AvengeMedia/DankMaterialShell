import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property real widgetHeight: 30
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 2 : Theme.spacingS
    readonly property bool hasActivePrivacy: PrivacyService.anyPrivacyActive
    readonly property int activeCount: PrivacyService.microphoneActive + PrivacyService.cameraActive + PrivacyService.screensharingActive
    readonly property real contentWidth: hasActivePrivacy ? (activeCount * 18 + (activeCount - 1) * Theme.spacingXS) : 0

    width: hasActivePrivacy ? (contentWidth + horizontalPadding * 2) : 0
    height: hasActivePrivacy ? widgetHeight : 0
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    visible: hasActivePrivacy
    opacity: hasActivePrivacy ? 1 : 0
    enabled: hasActivePrivacy
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        return Qt.rgba(privacyArea.containsMouse ? Theme.errorPressed.r : Theme.errorHover.r, privacyArea.containsMouse ? Theme.errorPressed.g : Theme.errorHover.g, privacyArea.containsMouse ? Theme.errorPressed.b : Theme.errorHover.b, (privacyArea.containsMouse ? Theme.errorPressed.a : Theme.errorHover.a) * Theme.widgetTransparency);
    }

    MouseArea {
        // Privacy indicator click handler

        id: privacyArea

        anchors.fill: parent
        hoverEnabled: hasActivePrivacy
        enabled: hasActivePrivacy
        cursorShape: Qt.PointingHandCursor
        onClicked: {
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingXS
        visible: hasActivePrivacy

        Item {
            width: 18
            height: 18
            visible: PrivacyService.microphoneActive
            anchors.verticalCenter: parent.verticalCenter

            DankIcon {
                name: "mic"
                size: Theme.iconSizeSmall
                color: Theme.error
                filled: true
                anchors.centerIn: parent
            }

        }

        Item {
            width: 18
            height: 18
            visible: PrivacyService.cameraActive
            anchors.verticalCenter: parent.verticalCenter

            DankIcon {
                name: "camera_video"
                size: Theme.iconSizeSmall
                color: Theme.surfaceText
                filled: true
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
            }

        }

        Item {
            width: 18
            height: 18
            visible: PrivacyService.screensharingActive
            anchors.verticalCenter: parent.verticalCenter

            DankIcon {
                name: "screen_share"
                size: Theme.iconSizeSmall
                color: Theme.warning
                filled: true
                anchors.centerIn: parent
            }

        }

    }

    Rectangle {
        id: tooltip

        width: tooltipText.contentWidth + Theme.spacingM * 2
        height: tooltipText.contentHeight + Theme.spacingS * 2
        radius: Theme.cornerRadius
        color: Theme.popupBackground()
        border.color: Theme.outlineMedium
        border.width: 1
        visible: false
        opacity: privacyArea.containsMouse && hasActivePrivacy ? 1 : 0
        z: 100
        x: (parent.width - width) / 2
        y: -height - Theme.spacingXS

        StyledText {
            id: tooltipText

            anchors.centerIn: parent
            text: PrivacyService.getPrivacySummary()
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
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

    Behavior on width {
        enabled: hasActivePrivacy && visible

        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Theme.emphasizedEasing
        }

    }

}
