import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool expanded: false
    readonly property real contentHeight: contentColumn.height + Theme.spacingL * 2

    width: parent.width
    height: expanded ? contentHeight : 0
    visible: expanded
    clip: true
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.3)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
    border.width: 1

    Behavior on height {
        NumberAnimation {
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.emphasized
        }
    }

    opacity: expanded ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: Anims.durShort
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anims.emphasized
        }
    }

    readonly property var timeoutOptions: [{
            "text": "Never",
            "value": 0
        }, {
            "text": "1 second",
            "value": 1000
        }, {
            "text": "3 seconds",
            "value": 3000
        }, {
            "text": "5 seconds",
            "value": 5000
        }, {
            "text": "8 seconds",
            "value": 8000
        }, {
            "text": "10 seconds",
            "value": 10000
        }, {
            "text": "15 seconds",
            "value": 15000
        }, {
            "text": "30 seconds",
            "value": 30000
        }, {
            "text": "1 minute",
            "value": 60000
        }, {
            "text": "2 minutes",
            "value": 120000
        }, {
            "text": "5 minutes",
            "value": 300000
        }, {
            "text": "10 minutes",
            "value": 600000
        }]

    function getTimeoutText(value) {
        if (value === undefined || value === null || isNaN(value)) {
            return "5 seconds"
        }

        for (let i = 0; i < timeoutOptions.length; i++) {
            if (timeoutOptions[i].value === value) {
                return timeoutOptions[i].text
            }
        }
        if (value === 0) {
            return "Never"
        }
        if (value < 1000) {
            return value + "ms"
        }
        if (value < 60000) {
            return Math.round(value / 1000) + " seconds"
        }
        return Math.round(value / 60000) + " minutes"
    }

    Column {
        id: contentColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM

        StyledText {
            text: I18n.tr("Notification Settings")
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        Item {
            width: parent.width
            height: 36

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingM

                DankIcon {
                    name: SessionData.doNotDisturb ? "notifications_off" : "notifications"
                    size: Theme.iconSizeSmall
                    color: SessionData.doNotDisturb ? Theme.error : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: I18n.tr("Do Not Disturb")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            DankToggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: SessionData.doNotDisturb
                onToggled: SessionData.setDoNotDisturb(!SessionData.doNotDisturb)
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
        }

        StyledText {
            text: I18n.tr("Notification Timeouts")
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceVariantText
        }

        DankDropdown {
            text: I18n.tr("Low Priority")
            description: "Timeout for low priority notifications"
            currentValue: getTimeoutText(SettingsData.notificationTimeoutLow)
            options: timeoutOptions.map(opt => opt.text)
            onValueChanged: value => {
                                for (let i = 0; i < timeoutOptions.length; i++) {
                                    if (timeoutOptions[i].text === value) {
                                        SettingsData.set("notificationTimeoutLow", timeoutOptions[i].value)
                                        break
                                    }
                                }
                            }
        }

        DankDropdown {
            text: I18n.tr("Normal Priority")
            description: "Timeout for normal priority notifications"
            currentValue: getTimeoutText(SettingsData.notificationTimeoutNormal)
            options: timeoutOptions.map(opt => opt.text)
            onValueChanged: value => {
                                for (let i = 0; i < timeoutOptions.length; i++) {
                                    if (timeoutOptions[i].text === value) {
                                        SettingsData.set("notificationTimeoutNormal", timeoutOptions[i].value)
                                        break
                                    }
                                }
                            }
        }

        DankDropdown {
            text: I18n.tr("Critical Priority")
            description: "Timeout for critical priority notifications"
            currentValue: getTimeoutText(SettingsData.notificationTimeoutCritical)
            options: timeoutOptions.map(opt => opt.text)
            onValueChanged: value => {
                                for (let i = 0; i < timeoutOptions.length; i++) {
                                    if (timeoutOptions[i].text === value) {
                                        SettingsData.set("notificationTimeoutCritical", timeoutOptions[i].value)
                                        break
                                    }
                                }
                            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
        }

        Item {
            width: parent.width
            height: 36

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingM

                DankIcon {
                    name: "notifications_active"
                    size: Theme.iconSizeSmall
                    color: SettingsData.notificationOverlayEnabled ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        text: I18n.tr("Notification Overlay")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }

                    StyledText {
                        text: I18n.tr("Display all priorities over fullscreen apps")
                        font.pixelSize: Theme.fontSizeSmall - 1
                        color: Theme.surfaceVariantText
                    }
                }
            }

            DankToggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: SettingsData.notificationOverlayEnabled
                onToggled: toggled => SettingsData.set("notificationOverlayEnabled", toggled)
            }
        }
    }
}
