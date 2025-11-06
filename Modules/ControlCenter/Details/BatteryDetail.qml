import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.UPower
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    implicitHeight: contentColumn.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 0

    function isActiveProfile(profile) {
        if (typeof PowerProfiles === "undefined") {
            return false
        }
        return PowerProfiles.profile === profile
    }

    function setProfile(profile) {
        if (typeof PowerProfiles === "undefined") {
            ToastService.showError("power-profiles-daemon not available")
            return
        }
        PowerProfiles.profile = profile
        if (PowerProfiles.profile !== profile) {
            ToastService.showError("Failed to set power profile")
        }
    }

    Column {
        id: contentColumn
        width: parent.width - Theme.spacingL * 2
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingL

        Row {
            id: headerRow
            width: parent.width
            height: 48
            spacing: Theme.spacingM

            DankIcon {
                name: BatteryService.getBatteryIcon()
                size: Theme.iconSizeLarge
                color: {
                    if (BatteryService.isLowBattery && !BatteryService.isCharging)
                        return Theme.error
                    if (BatteryService.isCharging || BatteryService.isPluggedIn)
                        return Theme.primary
                    return Theme.surfaceText
                }
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                spacing: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.iconSizeLarge - Theme.spacingM

                Row {
                    spacing: Theme.spacingS

                    StyledText {
                        text: BatteryService.batteryAvailable ? `${BatteryService.batteryLevel}%` : "Power"
                        font.pixelSize: Theme.fontSizeXLarge
                        color: {
                            if (BatteryService.isLowBattery && !BatteryService.isCharging) {
                                return Theme.error
                            }
                            if (BatteryService.isCharging) {
                                return Theme.primary
                            }
                            return Theme.surfaceText
                        }
                        font.weight: Font.Bold
                    }

                    StyledText {
                        text: BatteryService.batteryAvailable ? BatteryService.batteryStatus : "Management"
                        font.pixelSize: Theme.fontSizeLarge
                        color: {
                            if (BatteryService.isLowBattery && !BatteryService.isCharging) {
                                return Theme.error
                            }
                            if (BatteryService.isCharging) {
                                return Theme.primary
                            }
                            return Theme.surfaceText
                        }
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    text: {
                        if (!BatteryService.batteryAvailable) return "Power profile management available"
                        const time = BatteryService.formatTimeRemaining()
                        if (time !== "Unknown") {
                            return BatteryService.isCharging ? `Time until full: ${time}` : `Time remaining: ${time}`
                        }
                        return ""
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceTextMedium
                    visible: text.length > 0
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }

        Row {
            width: parent.width
            spacing: Theme.spacingM
            visible: BatteryService.batteryAvailable

            StyledRect {
                width: (parent.width - Theme.spacingM) / 2
                height: 64
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                border.width: 0

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Health")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primary
                        font.weight: Font.Medium
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: BatteryService.batteryHealth
                        font.pixelSize: Theme.fontSizeLarge
                        color: {
                            if (BatteryService.batteryHealth === "N/A") {
                                return Theme.surfaceText
                            }
                            const healthNum = parseInt(BatteryService.batteryHealth)
                            return healthNum < 80 ? Theme.error : Theme.surfaceText
                        }
                        font.weight: Font.Bold
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            StyledRect {
                width: (parent.width - Theme.spacingM) / 2
                height: 64
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                border.width: 0

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Capacity")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primary
                        font.weight: Font.Medium
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: BatteryService.batteryCapacity > 0 ? `${BatteryService.batteryCapacity.toFixed(1)} Wh` : "Unknown"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Bold
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }

        DankButtonGroup {
            property var profileModel: (typeof PowerProfiles !== "undefined") ? [PowerProfile.PowerSaver, PowerProfile.Balanced].concat(PowerProfiles.hasPerformanceProfile ? [PowerProfile.Performance] : []) : [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
            property int currentProfileIndex: {
                if (typeof PowerProfiles === "undefined") return 1
                return profileModel.findIndex(profile => isActiveProfile(profile))
            }

            model: profileModel.map(profile => Theme.getPowerProfileLabel(profile))
            currentIndex: currentProfileIndex
            selectionMode: "single"
            anchors.horizontalCenter: parent.horizontalCenter
            onSelectionChanged: (index, selected) => {
                if (!selected) return
                setProfile(profileModel[index])
            }
        }

        StyledRect {
            width: parent.width
            height: degradationContent.implicitHeight + Theme.spacingL * 2
            radius: Theme.cornerRadius
            color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
            border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.3)
            border.width: 0
            visible: (typeof PowerProfiles !== "undefined") && PowerProfiles.degradationReason !== PerformanceDegradationReason.None

            Column {
                id: degradationContent
                width: parent.width - Theme.spacingL * 2
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingS

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "warning"
                        size: Theme.iconSize
                        color: Theme.error
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.iconSize - Theme.spacingM

                        StyledText {
                            text: I18n.tr("Power Profile Degradation")
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.error
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: (typeof PowerProfiles !== "undefined") ? PerformanceDegradationReason.toString(PowerProfiles.degradationReason) : ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.8)
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }
                }
            }
        }
    }
}