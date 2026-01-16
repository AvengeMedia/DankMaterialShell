import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                width: parent.width
                iconName: "lock"
                title: I18n.tr("Lock Screen layout")
                settingKey: "lockLayout"

                SettingsToggleRow {
                    settingKey: "lockScreenShowPowerActions"
                    tags: ["lock", "screen", "power", "actions", "shutdown", "reboot"]
                    text: I18n.tr("Show Power Actions", "Enable power action icon on the lock screen window")
                    checked: SettingsData.lockScreenShowPowerActions
                    onToggled: checked => SettingsData.set("lockScreenShowPowerActions", checked)
                }

                SettingsToggleRow {
                    settingKey: "lockScreenShowSystemIcons"
                    tags: ["lock", "screen", "system", "icons", "status"]
                    text: I18n.tr("Show System Icons", "Enable system status icons on the lock screen window")
                    checked: SettingsData.lockScreenShowSystemIcons
                    onToggled: checked => SettingsData.set("lockScreenShowSystemIcons", checked)
                }

                SettingsToggleRow {
                    settingKey: "lockScreenShowTime"
                    tags: ["lock", "screen", "time", "clock", "display"]
                    text: I18n.tr("Show System Time", "Enable system time display on the lock screen window")
                    checked: SettingsData.lockScreenShowTime
                    onToggled: checked => SettingsData.set("lockScreenShowTime", checked)
                }

                SettingsToggleRow {
                    settingKey: "lockScreenShowDate"
                    tags: ["lock", "screen", "date", "calendar", "display"]
                    text: I18n.tr("Show System Date", "Enable system date display on the lock screen window")
                    checked: SettingsData.lockScreenShowDate
                    onToggled: checked => SettingsData.set("lockScreenShowDate", checked)
                }

                SettingsToggleRow {
                    settingKey: "lockScreenShowProfileImage"
                    tags: ["lock", "screen", "profile", "image", "avatar", "picture"]
                    text: I18n.tr("Show Profile Image", "Enable profile image display on the lock screen window")
                    checked: SettingsData.lockScreenShowProfileImage
                    onToggled: checked => SettingsData.set("lockScreenShowProfileImage", checked)
                }

                SettingsToggleRow {
                    settingKey: "lockScreenShowPasswordField"
                    tags: ["lock", "screen", "password", "field", "input", "visible"]
                    text: I18n.tr("Show Password Field", "Enable password field display on the lock screen window")
                    description: I18n.tr("If the field is hidden, it will appear as soon as a key is pressed.")
                    checked: SettingsData.lockScreenShowPasswordField
                    onToggled: checked => SettingsData.set("lockScreenShowPasswordField", checked)
                }

                SettingsDropdownRow {
                    settingKey: "lockScreenNotificationMode"
                    tags: ["lock", "screen", "notification", "notifications", "privacy"]
                    text: I18n.tr("Notification Display", "lock screen notification privacy setting")
                    description: I18n.tr("Control what notification information is shown on the lock screen", "lock screen notification privacy setting")
                    options: [I18n.tr("Disabled", "lock screen notification mode option"), I18n.tr("Count Only", "lock screen notification mode option"), I18n.tr("App Names", "lock screen notification mode option"), I18n.tr("Full Content", "lock screen notification mode option")]
                    currentValue: options[SettingsData.lockScreenNotificationMode] || options[0]
                    onValueChanged: value => {
                        const idx = options.indexOf(value);
                        if (idx >= 0) {
                            SettingsData.set("lockScreenNotificationMode", idx);
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "lock"
                title: I18n.tr("Lock Screen behaviour")
                settingKey: "lockBehavior"

                StyledText {
                    text: I18n.tr("loginctl not available - lock integration requires DMS socket connection")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.warning
                    visible: !SessionService.loginctlAvailable
                    width: parent.width
                    wrapMode: Text.Wrap
                }

                SettingsToggleRow {
                    settingKey: "loginctlLockIntegration"
                    tags: ["lock", "screen", "loginctl", "dbus", "integration", "external"]
                    text: I18n.tr("Enable loginctl lock integration")
                    description: I18n.tr("Bind lock screen to dbus signals from loginctl. Disable if using an external lock screen")
                    checked: SessionService.loginctlAvailable && SettingsData.loginctlLockIntegration
                    enabled: SessionService.loginctlAvailable
                    onToggled: checked => {
                        if (!SessionService.loginctlAvailable)
                            return;
                        SettingsData.set("loginctlLockIntegration", checked);
                    }
                }

                SettingsToggleRow {
                    settingKey: "lockBeforeSuspend"
                    tags: ["lock", "screen", "suspend", "sleep", "automatic"]
                    text: I18n.tr("Lock before suspend")
                    description: I18n.tr("Automatically lock the screen when the system prepares to suspend")
                    checked: SettingsData.lockBeforeSuspend
                    visible: SessionService.loginctlAvailable && SettingsData.loginctlLockIntegration
                    onToggled: checked => SettingsData.set("lockBeforeSuspend", checked)
                }

                SettingsToggleRow {
                    settingKey: "lockScreenPowerOffMonitorsOnLock"
                    tags: ["lock", "screen", "monitor", "display", "dpms", "power"]
                    text: I18n.tr("Power off monitors on lock")
                    description: I18n.tr("Turn off all displays immediately when the lock screen activates")
                    checked: SettingsData.lockScreenPowerOffMonitorsOnLock
                    onToggled: checked => SettingsData.set("lockScreenPowerOffMonitorsOnLock", checked)
                }

                SettingsToggleRow {
                    settingKey: "enableFprint"
                    tags: ["lock", "screen", "fingerprint", "authentication", "biometric", "fprint"]
                    text: I18n.tr("Enable fingerprint authentication")
                    description: I18n.tr("Use fingerprint reader for lock screen authentication (requires enrolled fingerprints)")
                    checked: SettingsData.enableFprint
                    visible: SettingsData.fprintdAvailable
                    onToggled: checked => SettingsData.set("enableFprint", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "monitor"
                title: I18n.tr("Lock Screen Display")
                settingKey: "lockDisplay"
                visible: Quickshell.screens.length > 1

                StyledText {
                    text: I18n.tr("Choose which monitor shows the lock screen interface. Other monitors will display a solid color for OLED burn-in protection.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                }

                SettingsDropdownRow {
                    id: lockScreenMonitorDropdown
                    settingKey: "lockScreenActiveMonitor"
                    tags: ["lock", "screen", "monitor", "display", "active"]
                    text: I18n.tr("Active Lock Screen Monitor")
                    options: {
                        var opts = [I18n.tr("All Monitors")];
                        var screens = Quickshell.screens;
                        for (var i = 0; i < screens.length; i++) {
                            opts.push(SettingsData.getScreenDisplayName(screens[i]));
                        }
                        return opts;
                    }

                    Component.onCompleted: {
                        if (SettingsData.lockScreenActiveMonitor === "all") {
                            currentValue = I18n.tr("All Monitors");
                            return;
                        }
                        var screens = Quickshell.screens;
                        for (var i = 0; i < screens.length; i++) {
                            if (screens[i].name === SettingsData.lockScreenActiveMonitor) {
                                currentValue = SettingsData.getScreenDisplayName(screens[i]);
                                return;
                            }
                        }
                        currentValue = I18n.tr("All Monitors");
                    }

                    onValueChanged: value => {
                        if (value === I18n.tr("All Monitors")) {
                            SettingsData.set("lockScreenActiveMonitor", "all");
                            return;
                        }
                        var screens = Quickshell.screens;
                        for (var i = 0; i < screens.length; i++) {
                            if (SettingsData.getScreenDisplayName(screens[i]) === value) {
                                SettingsData.set("lockScreenActiveMonitor", screens[i].name);
                                return;
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: SettingsData.lockScreenActiveMonitor !== "all"

                    Column {
                        width: parent.width - inactiveColorPreview.width - Theme.spacingM
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: I18n.tr("Inactive Monitor Color")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: I18n.tr("Color displayed on monitors without the lock screen")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            wrapMode: Text.Wrap
                        }
                    }

                    Rectangle {
                        id: inactiveColorPreview
                        width: 48
                        height: 48
                        radius: Theme.cornerRadius
                        color: SettingsData.lockScreenInactiveColor
                        border.color: Theme.outline
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!PopoutService.colorPickerModal)
                                    return;
                                PopoutService.colorPickerModal.selectedColor = SettingsData.lockScreenInactiveColor;
                                PopoutService.colorPickerModal.pickerTitle = I18n.tr("Inactive Monitor Color");
                                PopoutService.colorPickerModal.onColorSelectedCallback = function (selectedColor) {
                                    SettingsData.set("lockScreenInactiveColor", selectedColor);
                                };
                                PopoutService.colorPickerModal.show();
                            }
                        }
                    }
                }
            }
        }
    }
}
