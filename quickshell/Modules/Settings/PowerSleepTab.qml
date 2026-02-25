import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    readonly property var timeoutOptions: [I18n.tr("Never"), I18n.tr("1 minute"), I18n.tr("2 minutes"), I18n.tr("3 minutes"), I18n.tr("5 minutes"), I18n.tr("10 minutes"), I18n.tr("15 minutes"), I18n.tr("20 minutes"), I18n.tr("30 minutes"), I18n.tr("1 hour"), I18n.tr("1 hour 30 minutes"), I18n.tr("2 hours"), I18n.tr("3 hours")]
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
            topPadding: 4
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                width: parent.width
                iconName: "schedule"
                title: I18n.tr("Idle Settings")
                settingKey: "idleSettings"

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
                        model: [I18n.tr("AC Power"), I18n.tr("Battery")]
                        currentIndex: 0
                        selectionMode: "single"
                        checkEnabled: false
                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            currentIndex = index;
                        }
                    }
                }

                SettingsToggleRow {
                    settingKey: "fadeToLockEnabled"
                    tags: ["fade", "lock", "screen", "idle", "grace period"]
                    text: I18n.tr("Fade to lock screen")
                    description: I18n.tr("Gradually fade the screen before locking with a configurable grace period")
                    checked: SettingsData.fadeToLockEnabled
                    onToggled: checked => SettingsData.set("fadeToLockEnabled", checked)
                }

                SettingsToggleRow {
                    settingKey: "fadeToDpmsEnabled"
                    tags: ["fade", "dpms", "monitor", "screen", "idle", "grace period"]
                    text: I18n.tr("Fade to monitor off")
                    description: I18n.tr("Gradually fade the screen before turning off monitors with a configurable grace period")
                    checked: SettingsData.fadeToDpmsEnabled
                    onToggled: checked => SettingsData.set("fadeToDpmsEnabled", checked)
                }

                SettingsToggleRow {
                    settingKey: "lockBeforeSuspend"
                    tags: ["lock", "suspend", "sleep", "security"]
                    text: I18n.tr("Lock before suspend")
                    description: I18n.tr("Automatically lock the screen when the system prepares to suspend")
                    checked: SettingsData.lockBeforeSuspend
                    visible: SessionService.loginctlAvailable && SettingsData.loginctlLockIntegration
                    onToggled: checked => SettingsData.set("lockBeforeSuspend", checked)
                }

                SettingsDropdownRow {
                    id: fadeGracePeriodDropdown
                    settingKey: "fadeToLockGracePeriod"
                    tags: ["fade", "grace", "period", "timeout", "lock"]
                    property var periodOptions: [I18n.tr("1 second"), I18n.tr("2 seconds"), I18n.tr("3 seconds"), I18n.tr("4 seconds"), I18n.tr("5 seconds"), I18n.tr("10 seconds"), I18n.tr("15 seconds"), I18n.tr("20 seconds"), I18n.tr("30 seconds")]
                    property var periodValues: [1, 2, 3, 4, 5, 10, 15, 20, 30]

                    text: I18n.tr("Lock fade grace period")
                    options: periodOptions
                    visible: SettingsData.fadeToLockEnabled
                    enabled: SettingsData.fadeToLockEnabled

                    Component.onCompleted: {
                        const currentPeriod = SettingsData.fadeToLockGracePeriod;
                        const index = periodValues.indexOf(currentPeriod);
                        currentValue = index >= 0 ? periodOptions[index] : I18n.tr("5 seconds");
                    }

                    onValueChanged: value => {
                        const index = periodOptions.indexOf(value);
                        if (index < 0)
                            return;
                        SettingsData.set("fadeToLockGracePeriod", periodValues[index]);
                    }
                }

                SettingsDropdownRow {
                    id: fadeDpmsGracePeriodDropdown
                    settingKey: "fadeToDpmsGracePeriod"
                    tags: ["fade", "grace", "period", "timeout", "dpms", "monitor"]
                    property var periodOptions: [I18n.tr("1 second"), I18n.tr("2 seconds"), I18n.tr("3 seconds"), I18n.tr("4 seconds"), I18n.tr("5 seconds"), I18n.tr("10 seconds"), I18n.tr("15 seconds"), I18n.tr("20 seconds"), I18n.tr("30 seconds")]
                    property var periodValues: [1, 2, 3, 4, 5, 10, 15, 20, 30]

                    text: I18n.tr("Monitor fade grace period")
                    options: periodOptions
                    visible: SettingsData.fadeToDpmsEnabled
                    enabled: SettingsData.fadeToDpmsEnabled

                    Component.onCompleted: {
                        const currentPeriod = SettingsData.fadeToDpmsGracePeriod;
                        const index = periodValues.indexOf(currentPeriod);
                        currentValue = index >= 0 ? periodOptions[index] : I18n.tr("5 seconds");
                    }

                    onValueChanged: value => {
                        const index = periodOptions.indexOf(value);
                        if (index < 0)
                            return;
                        SettingsData.set("fadeToDpmsGracePeriod", periodValues[index]);
                    }
                }
                SettingsDropdownRow {
                    id: powerProfileDropdown
                    settingKey: "powerProfile"
                    tags: ["power", "profile", "performance", "balanced", "saver", "battery"]
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
                            powerProfileDropdown.currentValue = powerProfileDropdown.profileOptions[index];
                        }
                    }

                    Component.onCompleted: {
                        const currentProfile = powerCategory.currentIndex === 0 ? SettingsData.acProfileName : SettingsData.batteryProfileName;
                        const index = profileValues.indexOf(currentProfile);
                        currentValue = profileOptions[index];
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
                    settingKey: "lockTimeout"
                    tags: ["lock", "timeout", "idle", "automatic", "security"]
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
                    settingKey: "monitorTimeout"
                    tags: ["monitor", "display", "screen", "timeout", "off", "idle"]
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
                    settingKey: "suspendTimeout"
                    tags: ["suspend", "sleep", "timeout", "idle", "system"]
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
                        model: [I18n.tr("Suspend"), I18n.tr("Hibernate"), I18n.tr("Suspend then Hibernate")]
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
                            currentIndex = index;
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
                settingKey: "powerMenu"

                StyledText {
                    text: I18n.tr("Customize which actions appear in the power menu")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.Wrap
                }

                SettingsToggleRow {
                    settingKey: "powerMenuGridLayout"
                    tags: ["power", "menu", "grid", "layout", "list"]
                    text: I18n.tr("Use Grid Layout")
                    description: I18n.tr("Display power menu actions in a grid instead of a list")
                    checked: SettingsData.powerMenuGridLayout
                    onToggled: checked => SettingsData.set("powerMenuGridLayout", checked)
                }

                SettingsDropdownRow {
                    id: defaultActionDropdown
                    settingKey: "powerMenuDefaultAction"
                    tags: ["power", "menu", "default", "action", "reboot", "logout", "shutdown"]
                    text: I18n.tr("Default selected action")
                    options: [I18n.tr("Reboot"), I18n.tr("Log Out"), I18n.tr("Power Off"), I18n.tr("Lock"), I18n.tr("Suspend"), I18n.tr("Restart DMS"), I18n.tr("Hibernate")]
                    property var actionValues: ["reboot", "logout", "poweroff", "lock", "suspend", "restart", "hibernate"]

                    Component.onCompleted: {
                        const currentAction = SettingsData.powerMenuDefaultAction || "logout";
                        const index = actionValues.indexOf(currentAction);
                        currentValue = index >= 0 ? options[index] : I18n.tr("Log Out");
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
                            settingKey: "powerMenuAction_" + modelData.key
                            tags: ["power", "menu", "action", "show", modelData.key]
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
                settingKey: "powerConfirmation"

                SettingsToggleRow {
                    settingKey: "powerActionConfirm"
                    tags: ["power", "confirm", "hold", "button", "safety"]
                    text: I18n.tr("Hold to Confirm Power Actions")
                    description: I18n.tr("Require holding button/key to confirm power off, restart, suspend, hibernate and logout")
                    checked: SettingsData.powerActionConfirm
                    onToggled: checked => SettingsData.set("powerActionConfirm", checked)
                }

                SettingsDropdownRow {
                    id: holdDurationDropdown
                    settingKey: "powerActionHoldDuration"
                    tags: ["power", "hold", "duration", "confirm", "time"]
                    property var durationOptions: [I18n.tr("250 ms"), I18n.tr("500 ms"), I18n.tr("750 ms"), I18n.tr("1 second"), I18n.tr("2 seconds"), I18n.tr("3 seconds"), I18n.tr("5 seconds"), I18n.tr("10 seconds")]
                    property var durationValues: [0.25, 0.5, 0.75, 1, 2, 3, 5, 10]

                    text: I18n.tr("Hold Duration")
                    options: durationOptions
                    visible: SettingsData.powerActionConfirm

                    Component.onCompleted: {
                        const currentDuration = SettingsData.powerActionHoldDuration;
                        const index = durationValues.indexOf(currentDuration);
                        currentValue = index >= 0 ? durationOptions[index] : I18n.tr("500 ms");
                    }

                    onValueChanged: value => {
                        const index = durationOptions.indexOf(value);
                        if (index < 0)
                            return;
                        SettingsData.set("powerActionHoldDuration", durationValues[index]);
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "developer_mode"
                title: I18n.tr("Custom Power Actions")
                settingKey: "customPowerActions"

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
                            placeholderText: modelData.placeholder
                            backgroundColor: Theme.surfaceContainerHighest
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

            SettingsCard {
                width: parent.width
                iconName: "tune"
                title: I18n.tr("Advanced")
                settingKey: "powerAdvanced"
                collapsible: true
                expanded: false

                SettingsSliderRow {
                    settingKey: "batteryChargeLimit"
                    tags: ["battery", "charge", "limit", "percentage", "power"]
                    text: I18n.tr("Battery Charge Limit")
                    description: I18n.tr("Note: this only changes the percentage, it does not actually limit charging.")
                    value: SettingsData.batteryChargeLimit
                    minimum: 50
                    maximum: 100
                    defaultValue: 100
                    onSliderValueChanged: newValue => SettingsData.set("batteryChargeLimit", newValue)
                }
            }
        }
    }
}
