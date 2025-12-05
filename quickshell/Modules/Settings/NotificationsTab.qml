import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    readonly property var timeoutOptions: [
        {
            text: I18n.tr("Never"),
            value: 0
        },
        {
            text: I18n.tr("1 second"),
            value: 1000
        },
        {
            text: I18n.tr("3 seconds"),
            value: 3000
        },
        {
            text: I18n.tr("5 seconds"),
            value: 5000
        },
        {
            text: I18n.tr("8 seconds"),
            value: 8000
        },
        {
            text: I18n.tr("10 seconds"),
            value: 10000
        },
        {
            text: I18n.tr("15 seconds"),
            value: 15000
        },
        {
            text: I18n.tr("30 seconds"),
            value: 30000
        },
        {
            text: I18n.tr("1 minute"),
            value: 60000
        },
        {
            text: I18n.tr("2 minutes"),
            value: 120000
        },
        {
            text: I18n.tr("5 minutes"),
            value: 300000
        },
        {
            text: I18n.tr("10 minutes"),
            value: 600000
        }
    ]

    function getTimeoutText(value) {
        if (value === undefined || value === null || isNaN(value))
            return I18n.tr("5 seconds");
        for (let i = 0; i < timeoutOptions.length; i++) {
            if (timeoutOptions[i].value === value)
                return timeoutOptions[i].text;
        }
        if (value === 0)
            return I18n.tr("Never");
        if (value < 1000)
            return value + "ms";
        if (value < 60000)
            return Math.round(value / 1000) + " " + I18n.tr("seconds");
        return Math.round(value / 60000) + " " + I18n.tr("minutes");
    }

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

            SettingsCard {
                width: parent.width
                iconName: "notifications"
                title: I18n.tr("Notification Popups")

                SettingsDropdownRow {
                    text: I18n.tr("Popup Position")
                    description: I18n.tr("Choose where notification popups appear on screen")
                    currentValue: {
                        if (SettingsData.notificationPopupPosition === -1)
                            return "Top Center";
                        switch (SettingsData.notificationPopupPosition) {
                        case SettingsData.Position.Top:
                            return "Top Right";
                        case SettingsData.Position.Bottom:
                            return "Bottom Left";
                        case SettingsData.Position.Left:
                            return "Top Left";
                        case SettingsData.Position.Right:
                            return "Bottom Right";
                        default:
                            return "Top Right";
                        }
                    }
                    options: ["Top Right", "Top Left", "Top Center", "Bottom Right", "Bottom Left"]
                    onValueChanged: value => {
                        switch (value) {
                        case "Top Right":
                            SettingsData.set("notificationPopupPosition", SettingsData.Position.Top);
                            break;
                        case "Top Left":
                            SettingsData.set("notificationPopupPosition", SettingsData.Position.Left);
                            break;
                        case "Top Center":
                            SettingsData.set("notificationPopupPosition", -1);
                            break;
                        case "Bottom Right":
                            SettingsData.set("notificationPopupPosition", SettingsData.Position.Right);
                            break;
                        case "Bottom Left":
                            SettingsData.set("notificationPopupPosition", SettingsData.Position.Bottom);
                            break;
                        }
                        SettingsData.sendTestNotifications();
                    }
                }

                SettingsToggleRow {
                    text: I18n.tr("Notification Overlay")
                    description: I18n.tr("Display all priorities over fullscreen apps")
                    checked: SettingsData.notificationOverlayEnabled
                    onToggled: checked => SettingsData.set("notificationOverlayEnabled", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "notifications_off"
                title: I18n.tr("Do Not Disturb")

                SettingsToggleRow {
                    text: I18n.tr("Enable Do Not Disturb")
                    description: I18n.tr("Suppress notification popups while enabled")
                    checked: SessionData.doNotDisturb
                    onToggled: checked => SessionData.setDoNotDisturb(checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "timer"
                title: I18n.tr("Notification Timeouts")

                SettingsDropdownRow {
                    text: I18n.tr("Low Priority")
                    description: I18n.tr("Timeout for low priority notifications")
                    currentValue: root.getTimeoutText(SettingsData.notificationTimeoutLow)
                    options: root.timeoutOptions.map(opt => opt.text)
                    onValueChanged: value => {
                        for (let i = 0; i < root.timeoutOptions.length; i++) {
                            if (root.timeoutOptions[i].text === value) {
                                SettingsData.set("notificationTimeoutLow", root.timeoutOptions[i].value);
                                break;
                            }
                        }
                    }
                }

                SettingsDropdownRow {
                    text: I18n.tr("Normal Priority")
                    description: I18n.tr("Timeout for normal priority notifications")
                    currentValue: root.getTimeoutText(SettingsData.notificationTimeoutNormal)
                    options: root.timeoutOptions.map(opt => opt.text)
                    onValueChanged: value => {
                        for (let i = 0; i < root.timeoutOptions.length; i++) {
                            if (root.timeoutOptions[i].text === value) {
                                SettingsData.set("notificationTimeoutNormal", root.timeoutOptions[i].value);
                                break;
                            }
                        }
                    }
                }

                SettingsDropdownRow {
                    text: I18n.tr("Critical Priority")
                    description: I18n.tr("Timeout for critical priority notifications")
                    currentValue: root.getTimeoutText(SettingsData.notificationTimeoutCritical)
                    options: root.timeoutOptions.map(opt => opt.text)
                    onValueChanged: value => {
                        for (let i = 0; i < root.timeoutOptions.length; i++) {
                            if (root.timeoutOptions[i].text === value) {
                                SettingsData.set("notificationTimeoutCritical", root.timeoutOptions[i].value);
                                break;
                            }
                        }
                    }
                }
            }
        }
    }
}
