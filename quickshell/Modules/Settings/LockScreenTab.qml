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
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                width: parent.width
                iconName: "lock"
                title: I18n.tr("Lock Screen")

                SettingsToggleRow {
                    text: I18n.tr("Show Power Actions")
                    description: I18n.tr("Show power, restart, and logout buttons on the lock screen")
                    checked: SettingsData.lockScreenShowPowerActions
                    onToggled: checked => SettingsData.set("lockScreenShowPowerActions", checked)
                }

                StyledText {
                    text: I18n.tr("loginctl not available - lock integration requires DMS socket connection")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.warning
                    visible: !SessionService.loginctlAvailable
                    width: parent.width
                    wrapMode: Text.Wrap
                }

                SettingsToggleRow {
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
                    text: I18n.tr("Lock before suspend")
                    description: I18n.tr("Automatically lock the screen when the system prepares to suspend")
                    checked: SettingsData.lockBeforeSuspend
                    visible: SessionService.loginctlAvailable && SettingsData.loginctlLockIntegration
                    onToggled: checked => SettingsData.set("lockBeforeSuspend", checked)
                }

                SettingsToggleRow {
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
