import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: powerTab

    DankFlickable {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingL
        clip: true
        contentHeight: mainColumn.height
        contentWidth: width

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.spacingXL

            StyledText {
                text: I18n.tr("Battery not detected - only AC power settings available")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                visible: !BatteryService.batteryAvailable
            }

            StyledRect {
                width: parent.width
                height: lockScreenSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: lockScreenSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "lock"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Lock Screen")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        width: parent.width
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

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Enable loginctl lock integration")
                        description: I18n.tr("Bind lock screen to dbus signals from loginctl. Disable if using an external lock screen")
                        checked: SessionService.loginctlAvailable && SettingsData.loginctlLockIntegration
                        enabled: SessionService.loginctlAvailable
                        onToggled: checked => {
                            if (SessionService.loginctlAvailable) {
                                SettingsData.set("loginctlLockIntegration", checked)
                            }
                        }
                    }

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Lock before suspend")
                        description: I18n.tr("Automatically lock the screen when the system prepares to suspend")
                        checked: SettingsData.lockBeforeSuspend
                        visible: SessionService.loginctlAvailable && SettingsData.loginctlLockIntegration
                        onToggled: checked => SettingsData.set("lockBeforeSuspend", checked)
                    }

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Enable fingerprint authentication")
                        description: I18n.tr("Use fingerprint reader for lock screen authentication (requires enrolled fingerprints)")
                        checked: SettingsData.enableFprint
                        visible: SettingsData.fprintdAvailable
                        onToggled: checked => SettingsData.set("enableFprint", checked)
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: timeoutSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: timeoutSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "schedule"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Idle Settings")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            width: Math.max(0, parent.width - parent.children[0].width - parent.children[1].width - powerCategory.width - Theme.spacingM * 3)
                            height: parent.height
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

                    DankDropdown {
                        id: lockDropdown
                        property var timeoutOptions: ["Never", "1 minute", "2 minutes", "3 minutes", "5 minutes", "10 minutes", "15 minutes", "20 minutes", "30 minutes", "1 hour", "1 hour 30 minutes", "2 hours", "3 hours"]
                        property var timeoutValues: [0, 60, 120, 180, 300, 600, 900, 1200, 1800, 3600, 5400, 7200, 10800]

                        text: I18n.tr("Automatically lock after")
                        options: timeoutOptions

                        Connections {
                            target: powerCategory
                            function onCurrentIndexChanged() {
                                const currentTimeout = powerCategory.currentIndex === 0 ? SettingsData.acLockTimeout : SettingsData.batteryLockTimeout
                                const index = lockDropdown.timeoutValues.indexOf(currentTimeout)
                                lockDropdown.currentValue = index >= 0 ? lockDropdown.timeoutOptions[index] : "Never"
                            }
                        }

                        Component.onCompleted: {
                            const currentTimeout = powerCategory.currentIndex === 0 ? SettingsData.acLockTimeout : SettingsData.batteryLockTimeout
                            const index = timeoutValues.indexOf(currentTimeout)
                            currentValue = index >= 0 ? timeoutOptions[index] : "Never"
                        }

                        onValueChanged: value => {
                            const index = timeoutOptions.indexOf(value)
                            if (index >= 0) {
                                const timeout = timeoutValues[index]
                                if (powerCategory.currentIndex === 0) {
                                    SettingsData.set("acLockTimeout", timeout)
                                } else {
                                    SettingsData.set("batteryLockTimeout", timeout)
                                }
                            }
                        }
                    }

                    DankDropdown {
                        id: monitorDropdown
                        property var timeoutOptions: ["Never", "1 minute", "2 minutes", "3 minutes", "5 minutes", "10 minutes", "15 minutes", "20 minutes", "30 minutes", "1 hour", "1 hour 30 minutes", "2 hours", "3 hours"]
                        property var timeoutValues: [0, 60, 120, 180, 300, 600, 900, 1200, 1800, 3600, 5400, 7200, 10800]

                        text: I18n.tr("Turn off monitors after")
                        options: timeoutOptions

                        Connections {
                            target: powerCategory
                            function onCurrentIndexChanged() {
                                const currentTimeout = powerCategory.currentIndex === 0 ? SettingsData.acMonitorTimeout : SettingsData.batteryMonitorTimeout
                                const index = monitorDropdown.timeoutValues.indexOf(currentTimeout)
                                monitorDropdown.currentValue = index >= 0 ? monitorDropdown.timeoutOptions[index] : "Never"
                            }
                        }

                        Component.onCompleted: {
                            const currentTimeout = powerCategory.currentIndex === 0 ? SettingsData.acMonitorTimeout : SettingsData.batteryMonitorTimeout
                            const index = timeoutValues.indexOf(currentTimeout)
                            currentValue = index >= 0 ? timeoutOptions[index] : "Never"
                        }

                        onValueChanged: value => {
                            const index = timeoutOptions.indexOf(value)
                            if (index >= 0) {
                                const timeout = timeoutValues[index]
                                if (powerCategory.currentIndex === 0) {
                                    SettingsData.set("acMonitorTimeout", timeout)
                                } else {
                                    SettingsData.set("batteryMonitorTimeout", timeout)
                                }
                            }
                        }
                    }

                    DankDropdown {
                        id: suspendDropdown
                        property var timeoutOptions: ["Never", "1 minute", "2 minutes", "3 minutes", "5 minutes", "10 minutes", "15 minutes", "20 minutes", "30 minutes", "1 hour", "1 hour 30 minutes", "2 hours", "3 hours"]
                        property var timeoutValues: [0, 60, 120, 180, 300, 600, 900, 1200, 1800, 3600, 5400, 7200, 10800]

                        text: I18n.tr("Suspend system after")
                        options: timeoutOptions

                        Connections {
                            target: powerCategory
                            function onCurrentIndexChanged() {
                                const currentTimeout = powerCategory.currentIndex === 0 ? SettingsData.acSuspendTimeout : SettingsData.batterySuspendTimeout
                                const index = suspendDropdown.timeoutValues.indexOf(currentTimeout)
                                suspendDropdown.currentValue = index >= 0 ? suspendDropdown.timeoutOptions[index] : "Never"
                            }
                        }

                        Component.onCompleted: {
                            const currentTimeout = powerCategory.currentIndex === 0 ? SettingsData.acSuspendTimeout : SettingsData.batterySuspendTimeout
                            const index = timeoutValues.indexOf(currentTimeout)
                            currentValue = index >= 0 ? timeoutOptions[index] : "Never"
                        }

                        onValueChanged: value => {
                            const index = timeoutOptions.indexOf(value)
                            if (index >= 0) {
                                const timeout = timeoutValues[index]
                                if (powerCategory.currentIndex === 0) {
                                    SettingsData.set("acSuspendTimeout", timeout)
                                } else {
                                    SettingsData.set("batterySuspendTimeout", timeout)
                                }
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
                                    const behavior = powerCategory.currentIndex === 0 ? SettingsData.acSuspendBehavior : SettingsData.batterySuspendBehavior
                                    suspendBehaviorSelector.currentIndex = behavior
                                }
                            }

                            Component.onCompleted: {
                                const behavior = powerCategory.currentIndex === 0 ? SettingsData.acSuspendBehavior : SettingsData.batterySuspendBehavior
                                currentIndex = behavior
                            }

                            onSelectionChanged: (index, selected) => {
                                if (selected) {
                                    if (powerCategory.currentIndex === 0) {
                                        SettingsData.set("acSuspendBehavior", index)
                                    } else {
                                        SettingsData.set("batterySuspendBehavior", index)
                                    }
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
            }

            StyledRect {
                width: parent.width
                height: powerCommandConfirmSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: powerCommandConfirmSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "check_circle"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Power Action Confirmation")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Show Confirmation on Power Actions")
                        description: I18n.tr("Request confirmation on power off, restart, suspend, hibernate and logout actions")
                        checked: SettingsData.powerActionConfirm
                        onToggled: checked => SettingsData.set("powerActionConfirm", checked)
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: powerCommandCustomization.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: powerCommandCustomization
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingL

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "developer_mode"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Custom Power Actions")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        anchors.left: parent.left

                        StyledText {
                            text: I18n.tr("Command or script to run instead of the standard lock procedure")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        DankTextField {
                            id: customLockCommand
                            width: parent.width
                            height: 48
                            placeholderText: "/usr/bin/myLock.sh"
                            backgroundColor: Theme.surfaceVariant
                            normalBorderColor: Theme.primarySelected
                            focusedBorderColor: Theme.primary

                            Component.onCompleted: {
                                if (SettingsData.customPowerActionLock) {
                                    text = SettingsData.customPowerActionLock;
                                }
                            }

                            onTextEdited: {
                                SettingsData.set("customPowerActionLock", text.trim());
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        anchors.left: parent.left

                        StyledText {
                            text: I18n.tr("Command or script to run instead of the standard logout procedure")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        DankTextField {
                            id: customLogoutCommand
                            width: parent.width
                            height: 48
                            placeholderText: "/usr/bin/myLogout.sh"
                            backgroundColor: Theme.surfaceVariant
                            normalBorderColor: Theme.primarySelected
                            focusedBorderColor: Theme.primary

                            Component.onCompleted: {
                                if (SettingsData.customPowerActionLogout) {
                                    text = SettingsData.customPowerActionLogout;
                                }
                            }

                            onTextEdited: {
                                SettingsData.set("customPowerActionLogout", text.trim());
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        anchors.left: parent.left

                        StyledText {
                            text: I18n.tr("Command or script to run instead of the standard suspend procedure")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        DankTextField {
                            id: customSuspendCommand
                            width: parent.width
                            height: 48
                            placeholderText: "/usr/bin/mySuspend.sh"
                            backgroundColor: Theme.surfaceVariant
                            normalBorderColor: Theme.primarySelected
                            focusedBorderColor: Theme.primary

                            Component.onCompleted: {
                                if (SettingsData.customPowerActionSuspend) {
                                    text = SettingsData.customPowerActionSuspend;
                                }
                            }

                            onTextEdited: {
                                SettingsData.set("customPowerActionSuspend", text.trim());
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        anchors.left: parent.left

                        StyledText {
                            text: I18n.tr("Command or script to run instead of the standard hibernate procedure")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        DankTextField {
                            id: customHibernateCommand
                            width: parent.width
                            height: 48
                            placeholderText: "/usr/bin/myHibernate.sh"
                            backgroundColor: Theme.surfaceVariant
                            normalBorderColor: Theme.primarySelected
                            focusedBorderColor: Theme.primary

                            Component.onCompleted: {
                                if (SettingsData.customPowerActionHibernate) {
                                    text = SettingsData.customPowerActionHibernate;
                                }
                            }

                            onTextEdited: {
                                SettingsData.set("customPowerActionHibernate", text.trim());
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        anchors.left: parent.left

                        StyledText {
                            text: I18n.tr("Command or script to run instead of the standard reboot procedure")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        DankTextField {
                            id: customRebootCommand
                            width: parent.width
                            height: 48
                            placeholderText: "/usr/bin/myReboot.sh"
                            backgroundColor: Theme.surfaceVariant
                            normalBorderColor: Theme.primarySelected
                            focusedBorderColor: Theme.primary

                            Component.onCompleted: {
                                if (SettingsData.customPowerActionReboot) {
                                    text = SettingsData.customPowerActionReboot;
                                }
                            }

                            onTextEdited: {
                                SettingsData.set("customPowerActionReboot", text.trim());
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        anchors.left: parent.left

                        StyledText {
                            text: I18n.tr("Command or script to run instead of the standard power off procedure")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        DankTextField {
                            id: customPowerOffCommand
                            width: parent.width
                            height: 48
                            placeholderText: "/usr/bin/myPowerOff.sh"
                            backgroundColor: Theme.surfaceVariant
                            normalBorderColor: Theme.primarySelected
                            focusedBorderColor: Theme.primary

                            Component.onCompleted: {
                                if (SettingsData.customPowerActionPowerOff) {
                                    text = SettingsData.customPowerActionPowerOff;
                                }
                            }

                            onTextEdited: {
                                SettingsData.set("customPowerActionPowerOff", text.trim());
                            }
                        }
                    }
                }
            }
        }
    }
}
