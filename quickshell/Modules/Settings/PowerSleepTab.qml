import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    readonly property var timeoutOptions: ["Never", "1 minute", "2 minutes", "3 minutes", "5 minutes", "10 minutes", "15 minutes", "20 minutes", "30 minutes", "1 hour", "1 hour 30 minutes", "2 hours", "3 hours"]
    readonly property var timeoutValues: [0, 60, 120, 180, 300, 600, 900, 1200, 1800, 3600, 5400, 7200, 10800]

    function getTimeoutIndex(timeout) {
        var idx = timeoutValues.indexOf(timeout);
        return idx >= 0 ? idx : 0;
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
                iconName: "schedule"
                title: I18n.tr("Idle Settings")

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    StyledText {
                        text: I18n.tr("Power source")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                        visible: BatteryService.batteryAvailable
                    }

                    Item {
                        width: Theme.spacingS
                        height: 1
                        visible: BatteryService.batteryAvailable
                    }

                    DankButtonGroup {
                        id: powerCategory
                        anchors.verticalCenter: parent.verticalCenter
                        visible: BatteryService.batteryAvailable
                        model: ["AC Power", "Battery"]
                        currentIndex: 0
                        selectionMode: "single"
                        checkEnabled: false
                    }
                }

                SettingsToggleRow {
                    text: I18n.tr("Prevent idle for media")
                    description: I18n.tr("Inhibit idle timeout when audio or video is playing")
                    checked: SettingsData.preventIdleForMedia
                    visible: IdleService.idleMonitorAvailable
                    onToggled: checked => SettingsData.set("preventIdleForMedia", checked)
                }

                SettingsToggleRow {
                    text: I18n.tr("Fade to lock screen")
                    description: I18n.tr("Gradually fade the screen before locking with a configurable grace period")
                    checked: SettingsData.fadeToLockEnabled
                    onToggled: checked => SettingsData.set("fadeToLockEnabled", checked)
                }

                SettingsDropdownRow {
                    id: fadeGracePeriodDropdown
                    property var periodOptions: ["1 second", "2 seconds", "3 seconds", "4 seconds", "5 seconds", "10 seconds", "15 seconds", "20 seconds", "30 seconds"]
                    property var periodValues: [1, 2, 3, 4, 5, 10, 15, 20, 30]

                    text: I18n.tr("Fade grace period")
                    options: periodOptions
                    visible: SettingsData.fadeToLockEnabled
                    enabled: SettingsData.fadeToLockEnabled

                    Component.onCompleted: {
                        const currentPeriod = SettingsData.fadeToLockGracePeriod;
                        const index = periodValues.indexOf(currentPeriod);
                        currentValue = index >= 0 ? periodOptions[index] : "5 seconds";
                    }

                    onValueChanged: value => {
                        const index = periodOptions.indexOf(value);
                        if (index < 0)
                            return;
                        SettingsData.set("fadeToLockGracePeriod", periodValues[index]);
                    }
                }
                SettingsDropdownRow {
                    id: powerProfileDropdown
                    property var profileOptions: [I18n.tr("Don't Change"), Theme.getPowerProfileLabel(0), Theme.getPowerProfileLabel(1), Theme.getPowerProfileLabel(2)]
                    property var profileValues: ["", "0", "1", "2"]

                    width: parent.width
                    addHorizontalPadding: true
                    text: I18n.tr("Switch to power profile")
                    options: profileOptions

                    Connections {
                        target: powerCategory
                        function onCurrentIndexChanged() {
                            const currentProfile = powerCategory.currentIndex === 0 ? SettingsData.acProfileName : SettingsData.batteryProfileName;
                            const index = powerProfileDropdown.profileValues.indexOf(currentProfile);
                            powerProfileDropdown.currentValue = powerProfileDropdown.profileOptions[index]
                        }
                    }

                    Component.onCompleted: {
                        const currentProfile = powerCategory.currentIndex === 0 ? SettingsData.acProfileName : SettingsData.batteryProfileName;
                        const index = profileValues.indexOf(currentProfile);
                        currentValue = profileOptions[index]
                    }

                    onValueChanged: value => {
                        const index = profileOptions.indexOf(value);
                        if (index >= 0) {
                            const profileValue = profileValues[index];
                            if (powerCategory.currentIndex === 0) {
                                SettingsData.set("acProfileName", profileValue);
                            } else {
                                SettingsData.set("batteryProfileName", profileValue);
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.15
                }

                SettingsDropdownRow {
                    id: lockDropdown
                    text: I18n.tr("Automatically lock after")
                    options: root.timeoutOptions

                    Connections {
                        target: powerCategory
                        function onCurrentIndexChanged() {
                            const currentTimeout = powerCategory.currentIndex === 0 ? SettingsData.acLockTimeout : SettingsData.batteryLockTimeout;
                            lockDropdown.currentValue = root.timeoutOptions[root.getTimeoutIndex(currentTimeout)];
                        }
                    }

                    Component.onCompleted: {
                        const currentTimeout = powerCategory.currentIndex === 0 ? SettingsData.acLockTimeout : SettingsData.batteryLockTimeout;
                        currentValue = root.timeoutOptions[root.getTimeoutIndex(currentTimeout)];
                    }

                    onValueChanged: value => {
                        const index = root.timeoutOptions.indexOf(value);
                        if (index < 0)
                            return;
                        const timeout = root.timeoutValues[index];
                        if (powerCategory.currentIndex === 0) {
                            SettingsData.set("acLockTimeout", timeout);
                        } else {
                            SettingsData.set("batteryLockTimeout", timeout);
                        }
                    }
                }

                SettingsDropdownRow {
                    id: monitorDropdown
                    text: I18n.tr("Turn off monitors after")
                    options: root.timeoutOptions

                    Connections {
                        target: powerCategory
                        function onCurrentIndexChanged() {
                            const currentTimeout = powerCategory.currentIndex === 0 ? SettingsData.acMonitorTimeout : SettingsData.batteryMonitorTimeout;
                            monitorDropdown.currentValue = root.timeoutOptions[root.getTimeoutIndex(currentTimeout)];
                        }
                    }

                    Component.onCompleted: {
                        const currentTimeout = powerCategory.currentIndex === 0 ? SettingsData.acMonitorTimeout : SettingsData.batteryMonitorTimeout;
                        currentValue = root.timeoutOptions[root.getTimeoutIndex(currentTimeout)];
                    }

                    onValueChanged: value => {
                        const index = root.timeoutOptions.indexOf(value);
                        if (index < 0)
                            return;
                        const timeout = root.timeoutValues[index];
                        if (powerCategory.currentIndex === 0) {
                            SettingsData.set("acMonitorTimeout", timeout);
                        } else {
                            SettingsData.set("batteryMonitorTimeout", timeout);
                        }
                    }
                }

                SettingsDropdownRow {
                    id: suspendDropdown
                    text: I18n.tr("Suspend system after")
                    options: root.timeoutOptions

                    Connections {
                        target: powerCategory
                        function onCurrentIndexChanged() {
                            const currentTimeout = powerCategory.currentIndex === 0 ? SettingsData.acSuspendTimeout : SettingsData.batterySuspendTimeout;
                            suspendDropdown.currentValue = root.timeoutOptions[root.getTimeoutIndex(currentTimeout)];
                        }
                    }

                    Component.onCompleted: {
                        const currentTimeout = powerCategory.currentIndex === 0 ? SettingsData.acSuspendTimeout : SettingsData.batterySuspendTimeout;
                        currentValue = root.timeoutOptions[root.getTimeoutIndex(currentTimeout)];
                    }

                    onValueChanged: value => {
                        const index = root.timeoutOptions.indexOf(value);
                        if (index < 0)
                            return;
                        const timeout = root.timeoutValues[index];
                        if (powerCategory.currentIndex === 0) {
                            SettingsData.set("acSuspendTimeout", timeout);
                        } else {
                            SettingsData.set("batterySuspendTimeout", timeout);
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: SessionService.hibernateSupported

                    StyledText {
                        text: I18n.tr("Suspend behavior")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        leftPadding: Theme.spacingM
                    }

                    DankButtonGroup {
                        id: suspendBehaviorSelector
                        anchors.horizontalCenter: parent.horizontalCenter
                        model: ["Suspend", "Hibernate", "Suspend then Hibernate"]
                        selectionMode: "single"
                        checkEnabled: false

                        Connections {
                            target: powerCategory
                            function onCurrentIndexChanged() {
                                const behavior = powerCategory.currentIndex === 0 ? SettingsData.acSuspendBehavior : SettingsData.batterySuspendBehavior;
                                suspendBehaviorSelector.currentIndex = behavior;
                            }
                        }

                        Component.onCompleted: {
                            const behavior = powerCategory.currentIndex === 0 ? SettingsData.acSuspendBehavior : SettingsData.batterySuspendBehavior;
                            currentIndex = behavior;
                        }

                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            if (powerCategory.currentIndex === 0) {
                                SettingsData.set("acSuspendBehavior", index);
                            } else {
                                SettingsData.set("batterySuspendBehavior", index);
                            }
                        }
                    }
                }

                StyledText {
                    text: I18n.tr("Idle monitoring not supported - requires newer Quickshell version")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.error
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !IdleService.idleMonitorAvailable
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "tune"
                title: I18n.tr("Power Menu Customization")

                StyledText {
                    text: I18n.tr("Customize which actions appear in the power menu")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                }

                SettingsToggleRow {
                    text: I18n.tr("Use Grid Layout")
                    description: I18n.tr("Display power menu actions in a grid instead of a list")
                    checked: SettingsData.powerMenuGridLayout
                    onToggled: checked => SettingsData.set("powerMenuGridLayout", checked)
                }

                SettingsDropdownRow {
                    id: defaultActionDropdown
                    text: I18n.tr("Default selected action")
                    options: ["Reboot", "Log Out", "Power Off", "Lock", "Suspend", "Restart DMS", "Hibernate"]
                    property var actionValues: ["reboot", "logout", "poweroff", "lock", "suspend", "restart", "hibernate"]

                    Component.onCompleted: {
                        const currentAction = SettingsData.powerMenuDefaultAction || "logout";
                        const index = actionValues.indexOf(currentAction);
                        currentValue = index >= 0 ? options[index] : "Log Out";
                    }

                    onValueChanged: value => {
                        const index = options.indexOf(value);
                        if (index < 0)
                            return;
                        SettingsData.set("powerMenuDefaultAction", actionValues[index]);
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.15
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: [
                            {
                                key: "reboot",
                                label: I18n.tr("Show Reboot")
                            },
                            {
                                key: "logout",
                                label: I18n.tr("Show Log Out")
                            },
                            {
                                key: "poweroff",
                                label: I18n.tr("Show Power Off")
                            },
                            {
                                key: "lock",
                                label: I18n.tr("Show Lock")
                            },
                            {
                                key: "suspend",
                                label: I18n.tr("Show Suspend")
                            },
                            {
                                key: "restart",
                                label: I18n.tr("Show Restart DMS"),
                                desc: I18n.tr("Restart the DankMaterialShell")
                            },
                            {
                                key: "hibernate",
                                label: I18n.tr("Show Hibernate"),
                                desc: I18n.tr("Only visible if hibernate is supported by your system"),
                                hibernate: true
                            }
                        ]

                        SettingsToggleRow {
                            required property var modelData
                            text: modelData.label
                            description: modelData.desc || ""
                            visible: !modelData.hibernate || SessionService.hibernateSupported
                            checked: SettingsData.powerMenuActions.includes(modelData.key)
                            onToggled: checked => {
                                let actions = [...SettingsData.powerMenuActions];
                                if (checked && !actions.includes(modelData.key)) {
                                    actions.push(modelData.key);
                                } else if (!checked) {
                                    actions = actions.filter(a => a !== modelData.key);
                                }
                                SettingsData.set("powerMenuActions", actions);
                            }
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "check_circle"
                title: I18n.tr("Power Action Confirmation")

                SettingsToggleRow {
                    text: I18n.tr("Hold to Confirm Power Actions")
                    description: I18n.tr("Require holding button/key to confirm power off, restart, suspend, hibernate and logout")
                    checked: SettingsData.powerActionConfirm
                    onToggled: checked => SettingsData.set("powerActionConfirm", checked)
                }

                SettingsSliderRow {
                    text: I18n.tr("Hold Duration")
                    description: I18n.tr("How long to hold the button to confirm the action")
                    minimum: 1
                    maximum: 10
                    unit: "s"
                    visible: SettingsData.powerActionConfirm
                    value: SettingsData.powerActionHoldDuration
                    onSliderValueChanged: newValue => SettingsData.set("powerActionHoldDuration", newValue)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "developer_mode"
                title: I18n.tr("Custom Power Actions")

                Repeater {
                    model: [
                        {
                            key: "customPowerActionLock",
                            label: I18n.tr("Custom Lock Command"),
                            placeholder: "/usr/bin/myLock.sh"
                        },
                        {
                            key: "customPowerActionLogout",
                            label: I18n.tr("Custom Logout Command"),
                            placeholder: "/usr/bin/myLogout.sh"
                        },
                        {
                            key: "customPowerActionSuspend",
                            label: I18n.tr("Custom Suspend Command"),
                            placeholder: "/usr/bin/mySuspend.sh"
                        },
                        {
                            key: "customPowerActionHibernate",
                            label: I18n.tr("Custom Hibernate Command"),
                            placeholder: "/usr/bin/myHibernate.sh"
                        },
                        {
                            key: "customPowerActionReboot",
                            label: I18n.tr("Custom Reboot Command"),
                            placeholder: "/usr/bin/myReboot.sh"
                        },
                        {
                            key: "customPowerActionPowerOff",
                            label: I18n.tr("Custom Power Off Command"),
                            placeholder: "/usr/bin/myPowerOff.sh"
                        }
                    ]

                    Column {
                        required property var modelData
                        width: parent.width
                        spacing: Theme.spacingXS

                        StyledText {
                            text: modelData.label
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        DankTextField {
                            width: parent.width
                            height: 48
                            placeholderText: modelData.placeholder
                            backgroundColor: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                            normalBorderColor: Theme.outlineMedium
                            focusedBorderColor: Theme.primary

                            Component.onCompleted: {
                                var val = SettingsData[modelData.key];
                                if (val)
                                    text = val;
                            }

                            onTextEdited: {
                                SettingsData.set(modelData.key, text.trim());
                            }
                        }
                    }
                }
            }
        }
    }
}
