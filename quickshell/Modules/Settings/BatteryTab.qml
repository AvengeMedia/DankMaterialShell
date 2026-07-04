import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    Process {
        id: applyLimitProcess
        command: ["pkexec", "sh", "-c", "
for bat in /sys/class/power_supply/BAT*; do
  if [ -f \"$bat/charge_control_limit_max\" ]; then
    echo " + SettingsData.batteryChargeLimit + " > \"$bat/charge_control_limit_max\"
  elif [ -f \"$bat/charge_stop_threshold\" ]; then
    echo " + SettingsData.batteryChargeLimit + " > \"$bat/charge_stop_threshold\"
  elif [ -f \"$bat/charge_control_end_threshold\" ]; then
    echo " + SettingsData.batteryChargeLimit + " > \"$bat/charge_control_end_threshold\"
  fi
done
"]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                ToastService.showError(I18n.tr("Failed to apply charge limit to system"), I18n.tr("Process exited with code %1").arg(exitCode));
            } else {
                ToastService.showInfo(I18n.tr("Charge limit applied successfully"), I18n.tr("Limit set to %1%").arg(SettingsData.batteryChargeLimit));
            }
        }
    }

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

            // 1. Information Card
            SettingsCard {
                width: parent.width
                iconName: "battery_charging_full"
                title: I18n.tr("Battery Status")
                settingKey: "batteryStatusCard"

                Column {
                    width: parent.width - Theme.spacingM * 2
                    x: Theme.spacingM
                    spacing: Theme.spacingM

                    SettingsDivider {}

                    Row {
                        width: parent.width
                        StyledText {
                            text: I18n.tr("Power source")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignLeft
                        }
                        StyledText {
                            text: BatteryService.isPluggedIn ? I18n.tr("AC Adapter (Plugged In)") : I18n.tr("Battery Power")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignLeft
                        }
                    }

                    SettingsDivider {}

                    Row {
                        width: parent.width
                        StyledText {
                            text: I18n.tr("Charge Level")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignLeft
                        }
                        StyledText {
                            text: `${BatteryService.batteryLevel}%`
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignLeft
                        }
                    }

                    SettingsDivider {}

                    Row {
                        width: parent.width
                        StyledText {
                            text: I18n.tr("Status")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignLeft
                        }
                        StyledText {
                            text: BatteryService.batteryStatus
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignLeft
                        }
                    }

                    SettingsDivider {}

                    Row {
                        width: parent.width
                        StyledText {
                            text: I18n.tr("Estimated Time")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignLeft
                        }
                        StyledText {
                            text: BatteryService.formatTimeRemaining()
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignLeft
                        }
                    }

                    SettingsDivider {}

                    Row {
                        width: parent.width
                        StyledText {
                            text: I18n.tr("Battery Health")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignLeft
                        }
                        StyledText {
                            text: BatteryService.batteryHealth
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignLeft
                        }
                    }
                }
            }

            // 2. Threshold & Limits Card
            SettingsCard {
                width: parent.width
                iconName: "tune"
                title: I18n.tr("Battery Protection")
                settingKey: "batteryProtection"

                SettingsSliderRow {
                    settingKey: "batteryChargeLimit"
                    text: I18n.tr("Battery Charge Limit")
                    description: I18n.tr("Limit the maximum battery charge level to extend lifespan.")
                    value: SettingsData.batteryChargeLimit
                    minimum: 50
                    maximum: 100
                    defaultValue: 100
                    onSliderValueChanged: newValue => SettingsData.set("batteryChargeLimit", newValue)
                }

                Row {
                    width: parent.width
                    height: applyButton.height
                    layoutDirection: I18n.isRtl ? Qt.LeftToRight : Qt.RightToLeft

                    Item {
                        width: Theme.spacingM
                        height: 1
                    }

                    DankButton {
                        id: applyButton
                        text: I18n.tr("Apply to Hardware")
                        iconName: "lock"
                        backgroundColor: Theme.primary
                        textColor: Theme.onPrimary
                        onClicked: {
                            applyLimitProcess.running = true;
                        }
                    }
                }

                SettingsToggleRow {
                    settingKey: "batteryNotifyChargeLimit"
                    text: I18n.tr("Notify when limit is reached")
                    description: I18n.tr("Show a notification when battery reaches the charge limit.")
                    checked: SettingsData.batteryNotifyChargeLimit
                    onToggled: checked => SettingsData.set("batteryNotifyChargeLimit", checked)
                }

                SettingsButtonGroupRow {
                    settingKey: "batteryChargeLimitNotificationType"
                    text: I18n.tr("Notification Type")
                    description: I18n.tr("Choose how to be notified when charge limit is reached.")
                    model: [I18n.tr("Toast"), I18n.tr("Notification")]
                    visible: SettingsData.batteryNotifyChargeLimit
                    currentIndex: SettingsData.batteryChargeLimitNotificationType
                    onSelectionChanged: (index, selected) => {
                        if (selected) {
                            SettingsData.set("batteryChargeLimitNotificationType", index);
                        }
                    }
                }
            }

            // 3. Battery Alerts Card
            SettingsCard {
                width: parent.width
                iconName: "notifications"
                title: I18n.tr("Battery Alerts")
                settingKey: "batteryAlerts"

                SettingsSliderRow {
                    settingKey: "batteryLowThreshold"
                    text: I18n.tr("Low Battery Threshold")
                    description: I18n.tr("Set the percentage at which the battery is considered low.")
                    value: SettingsData.batteryLowThreshold
                    minimum: 5
                    maximum: 40
                    defaultValue: 20
                    onSliderValueChanged: newValue => SettingsData.set("batteryLowThreshold", newValue)
                }

                SettingsToggleRow {
                    settingKey: "batteryNotifyLow"
                    text: I18n.tr("Low Battery Notifications")
                    description: I18n.tr("Show a warning popup when battery is running low.")
                    checked: SettingsData.batteryNotifyLow
                    onToggled: checked => SettingsData.set("batteryNotifyLow", checked)
                }

                SettingsButtonGroupRow {
                    settingKey: "batteryLowNotificationType"
                    text: I18n.tr("Notification Type")
                    description: I18n.tr("Choose how to be notified about low battery alerts.")
                    model: [I18n.tr("Toast"), I18n.tr("Notification")]
                    visible: SettingsData.batteryNotifyLow
                    currentIndex: SettingsData.batteryLowNotificationType
                    onSelectionChanged: (index, selected) => {
                        if (selected) {
                            SettingsData.set("batteryLowNotificationType", index);
                        }
                    }
                }

                SettingsDivider {}

                StyledText {
                    text: I18n.tr("Critical Battery Alert")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: Theme.surfaceText
                    x: Theme.spacingM
                    width: parent.width - Theme.spacingM * 2
                    topPadding: Theme.spacingS
                }

                SettingsSliderRow {
                    settingKey: "batteryCriticalThreshold"
                    text: I18n.tr("Critical Threshold")
                    description: I18n.tr("Battery percentage to trigger a critical alert.")
                    value: SettingsData.batteryCriticalThreshold
                    minimum: 1
                    maximum: 30
                    defaultValue: 10
                    onSliderValueChanged: newValue => SettingsData.set("batteryCriticalThreshold", newValue)
                }

                SettingsToggleRow {
                    settingKey: "batteryNotifyCritical"
                    text: I18n.tr("Critical Battery Notifications")
                    description: I18n.tr("Show an urgent alert when battery reaches critical level.")
                    checked: SettingsData.batteryNotifyCritical
                    onToggled: checked => SettingsData.set("batteryNotifyCritical", checked)
                }

                SettingsButtonGroupRow {
                    settingKey: "batteryCriticalNotificationType"
                    text: I18n.tr("Notification Type")
                    description: I18n.tr("Choose how to be notified about critical battery alerts.")
                    model: [I18n.tr("Toast"), I18n.tr("Notification")]
                    visible: SettingsData.batteryNotifyCritical
                    currentIndex: SettingsData.batteryCriticalNotificationType
                    onSelectionChanged: (index, selected) => {
                        if (selected) {
                            SettingsData.set("batteryCriticalNotificationType", index);
                        }
                    }
                }
            }

            // 4. Power Profiles & Saving Card
            SettingsCard {
                width: parent.width
                iconName: "power"
                title: I18n.tr("Power Profiles & Saving")
                settingKey: "powerProfilesSaving"

                SettingsToggleRow {
                    settingKey: "batteryAutoPowerSaver"
                    text: I18n.tr("Auto Power Saver")
                    description: I18n.tr("Automatically turn on Power Saver profile when battery is low.")
                    checked: SettingsData.batteryAutoPowerSaver
                    onToggled: checked => SettingsData.set("batteryAutoPowerSaver", checked)
                }

                SettingsDivider {}

                SettingsDropdownRow {
                    settingKey: "acProfileName"
                    text: I18n.tr("Profile when Plugged In (AC)")
                    description: I18n.tr("Power profile to use when AC power is connected.")
                    options: [I18n.tr("Don't Change"), Theme.getPowerProfileLabel(0), Theme.getPowerProfileLabel(1), Theme.getPowerProfileLabel(2)]
                    currentValue: {
                        const val = SettingsData.acProfileName;
                        const idx = ["", "0", "1", "2"].indexOf(val);
                        return idx >= 0 ? options[idx] : options[0];
                    }
                    onValueChanged: value => {
                        const idx = options.indexOf(value);
                        if (idx >= 0) {
                            SettingsData.set("acProfileName", ["", "0", "1", "2"][idx]);
                        }
                    }
                }

                SettingsDropdownRow {
                    settingKey: "batteryProfileName"
                    text: I18n.tr("Profile when on Battery")
                    description: I18n.tr("Power profile to use when running on battery power.")
                    options: [I18n.tr("Don't Change"), Theme.getPowerProfileLabel(0), Theme.getPowerProfileLabel(1), Theme.getPowerProfileLabel(2)]
                    currentValue: {
                        const val = SettingsData.batteryProfileName;
                        const idx = ["", "0", "1", "2"].indexOf(val);
                        return idx >= 0 ? options[idx] : options[0];
                    }
                    onValueChanged: value => {
                        const idx = options.indexOf(value);
                        if (idx >= 0) {
                            SettingsData.set("batteryProfileName", ["", "0", "1", "2"][idx]);
                        }
                    }
                }
            }
        }
    }
}
