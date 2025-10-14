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
                        description: "Show power, restart, and logout buttons on the lock screen"
                        checked: SettingsData.lockScreenShowPowerActions
                        onToggled: checked => SettingsData.setLockScreenShowPowerActions(checked)
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
                        description: "Bind lock screen to dbus signals from loginctl. Disable if using an external lock screen"
                        checked: SessionService.loginctlAvailable && SessionData.loginctlLockIntegration
                        enabled: SessionService.loginctlAvailable
                        onToggled: checked => {
                            if (SessionService.loginctlAvailable) {
                                SessionData.setLoginctlLockIntegration(checked)
                            }
                        }
                    }

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Lock before suspend")
                        description: "Automatically lock the screen when the system prepares to suspend"
                        checked: SessionData.lockBeforeSuspend
                        visible: SessionService.loginctlAvailable && SessionData.loginctlLockIntegration
                        onToggled: checked => SessionData.setLockBeforeSuspend(checked)
                    }

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Enable fingerprint authentication")
                        description: "Use fingerprint reader for lock screen authentication (requires enrolled fingerprints)"
                        checked: SettingsData.enableFprint
                        visible: SettingsData.fprintdAvailable
                        onToggled: checked => SettingsData.setEnableFprint(checked)
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
                                const currentTimeout = powerCategory.currentIndex === 0 ? SessionData.acLockTimeout : SessionData.batteryLockTimeout
                                const index = lockDropdown.timeoutValues.indexOf(currentTimeout)
                                lockDropdown.currentValue = index >= 0 ? lockDropdown.timeoutOptions[index] : "Never"
                            }
                        }

                        Component.onCompleted: {
                            const currentTimeout = powerCategory.currentIndex === 0 ? SessionData.acLockTimeout : SessionData.batteryLockTimeout
                            const index = timeoutValues.indexOf(currentTimeout)
                            currentValue = index >= 0 ? timeoutOptions[index] : "Never"
                        }

                        onValueChanged: value => {
                            const index = timeoutOptions.indexOf(value)
                            if (index >= 0) {
                                const timeout = timeoutValues[index]
                                if (powerCategory.currentIndex === 0) {
                                    SessionData.setAcLockTimeout(timeout)
                                } else {
                                    SessionData.setBatteryLockTimeout(timeout)
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
                                const currentTimeout = powerCategory.currentIndex === 0 ? SessionData.acMonitorTimeout : SessionData.batteryMonitorTimeout
                                const index = monitorDropdown.timeoutValues.indexOf(currentTimeout)
                                monitorDropdown.currentValue = index >= 0 ? monitorDropdown.timeoutOptions[index] : "Never"
                            }
                        }

                        Component.onCompleted: {
                            const currentTimeout = powerCategory.currentIndex === 0 ? SessionData.acMonitorTimeout : SessionData.batteryMonitorTimeout
                            const index = timeoutValues.indexOf(currentTimeout)
                            currentValue = index >= 0 ? timeoutOptions[index] : "Never"
                        }

                        onValueChanged: value => {
                            const index = timeoutOptions.indexOf(value)
                            if (index >= 0) {
                                const timeout = timeoutValues[index]
                                if (powerCategory.currentIndex === 0) {
                                    SessionData.setAcMonitorTimeout(timeout)
                                } else {
                                    SessionData.setBatteryMonitorTimeout(timeout)
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
                                const currentTimeout = powerCategory.currentIndex === 0 ? SessionData.acSuspendTimeout : SessionData.batterySuspendTimeout
                                const index = suspendDropdown.timeoutValues.indexOf(currentTimeout)
                                suspendDropdown.currentValue = index >= 0 ? suspendDropdown.timeoutOptions[index] : "Never"
                            }
                        }

                        Component.onCompleted: {
                            const currentTimeout = powerCategory.currentIndex === 0 ? SessionData.acSuspendTimeout : SessionData.batterySuspendTimeout
                            const index = timeoutValues.indexOf(currentTimeout)
                            currentValue = index >= 0 ? timeoutOptions[index] : "Never"
                        }

                        onValueChanged: value => {
                            const index = timeoutOptions.indexOf(value)
                            if (index >= 0) {
                                const timeout = timeoutValues[index]
                                if (powerCategory.currentIndex === 0) {
                                    SessionData.setAcSuspendTimeout(timeout)
                                } else {
                                    SessionData.setBatterySuspendTimeout(timeout)
                                }
                            }
                        }
                    }

                    DankDropdown {
                        id: hibernateDropdown
                        property var timeoutOptions: ["Never", "1 minute", "2 minutes", "3 minutes", "5 minutes", "10 minutes", "15 minutes", "20 minutes", "30 minutes", "1 hour", "1 hour 30 minutes", "2 hours", "3 hours"]
                        property var timeoutValues: [0, 60, 120, 180, 300, 600, 900, 1200, 1800, 3600, 5400, 7200, 10800]

                        text: I18n.tr("Hibernate system after")
                        options: timeoutOptions
                        visible: SessionService.hibernateSupported

                        Connections {
                            target: powerCategory
                            function onCurrentIndexChanged() {
                                const currentTimeout = powerCategory.currentIndex === 0 ? SessionData.acHibernateTimeout : SessionData.batteryHibernateTimeout
                                const index = hibernateDropdown.timeoutValues.indexOf(currentTimeout)
                                hibernateDropdown.currentValue = index >= 0 ? hibernateDropdown.timeoutOptions[index] : "Never"
                            }
                        }

                        Component.onCompleted: {
                            const currentTimeout = powerCategory.currentIndex === 0 ? SessionData.acHibernateTimeout : SessionData.batteryHibernateTimeout
                            const index = timeoutValues.indexOf(currentTimeout)
                            currentValue = index >= 0 ? timeoutOptions[index] : "Never"
                        }

                        onValueChanged: value => {
                            const index = timeoutOptions.indexOf(value)
                            if (index >= 0) {
                                const timeout = timeoutValues[index]
                                if (powerCategory.currentIndex === 0) {
                                    SessionData.setAcHibernateTimeout(timeout)
                                } else {
                                    SessionData.setBatteryHibernateTimeout(timeout)
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
                        description: "Request confirmation on power off, restart, suspend, hibernate and logout actions"
                        checked: SettingsData.powerActionConfirm
                        onToggled: checked => SettingsData.setPowerActionConfirm(checked)
                    }
                }
            }
        }
    }
}
