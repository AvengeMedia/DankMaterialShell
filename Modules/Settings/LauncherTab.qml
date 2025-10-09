import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Modals
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

Item {
    id: recentAppsTab

    FileBrowserModal {
        id: logoFileBrowser
        browserTitle: I18n.tr("Select Launcher Logo")
        browserIcon: "image"
        browserType: "generic"
        filterExtensions: ["*.svg", "*.png", "*.jpg", "*.jpeg", "*.webp"]
        onFileSelected: path => {
            SettingsData.setLauncherLogoCustomPath(path.replace("file://", ""))
        }
    }

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

            StyledRect {
                width: parent.width
                height: launcherLogoSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: launcherLogoSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "apps"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Launcher Button Logo")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Choose the logo displayed on the launcher button in DankBar")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    Item {
                        width: parent.width
                        height: logoModeGroup.height

                        DankButtonGroup {
                            id: logoModeGroup
                            anchors.horizontalCenter: parent.horizontalCenter
                            model: {
                                const modes = [I18n.tr("Apps Icon"), I18n.tr("OS Logo")]
                                if (CompositorService.isNiri || CompositorService.isHyprland) {
                                    const compositorName = CompositorService.isNiri ? "niri" : "Hyprland"
                                    modes.push(compositorName)
                                }
                                modes.push(I18n.tr("Custom"))
                                return modes
                            }
                            currentIndex: {
                                if (SettingsData.launcherLogoMode === "apps") return 0
                                if (SettingsData.launcherLogoMode === "os") return 1
                                if (SettingsData.launcherLogoMode === "compositor") {
                                    return (CompositorService.isNiri || CompositorService.isHyprland) ? 2 : -1
                                }
                                if (SettingsData.launcherLogoMode === "custom") {
                                    return (CompositorService.isNiri || CompositorService.isHyprland) ? 3 : 2
                                }
                                return 0
                            }
                            onSelectionChanged: (index, selected) => {
                                if (!selected) return
                                if (index === 0) {
                                    SettingsData.setLauncherLogoMode("apps")
                                } else if (index === 1) {
                                    SettingsData.setLauncherLogoMode("os")
                                } else if (CompositorService.isNiri || CompositorService.isHyprland) {
                                    if (index === 2) {
                                        SettingsData.setLauncherLogoMode("compositor")
                                    } else if (index === 3) {
                                        SettingsData.setLauncherLogoMode("custom")
                                    }
                                } else if (index === 2) {
                                    SettingsData.setLauncherLogoMode("custom")
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        visible: SettingsData.launcherLogoMode === "custom"
                        opacity: visible ? 1 : 0
                        spacing: Theme.spacingM

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.mediumDuration
                                easing.type: Theme.emphasizedEasing
                            }
                        }

                        StyledRect {
                            width: parent.width - selectButton.width - Theme.spacingM
                            height: 36
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.9)
                            border.color: Theme.outlineStrong
                            border.width: 1

                            StyledText {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                text: SettingsData.launcherLogoCustomPath || I18n.tr("Select an image file...")
                                font.pixelSize: Theme.fontSizeMedium
                                color: SettingsData.launcherLogoCustomPath ? Theme.surfaceText : Theme.outlineButton
                                width: parent.width - Theme.spacingM * 2
                                elide: Text.ElideMiddle
                            }
                        }

                        DankActionButton {
                            id: selectButton
                            iconName: "folder_open"
                            width: 36
                            height: 36
                            onClicked: logoFileBrowser.open()
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingL
                        visible: SettingsData.launcherLogoMode !== "apps"
                        opacity: visible ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.mediumDuration
                                easing.type: Theme.emphasizedEasing
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingM

                            StyledText {
                                text: I18n.tr("Color Override")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Theme.spacingM

                                DankButtonGroup {
                                    id: colorModeGroup
                                    model: [I18n.tr("Default"), I18n.tr("Primary"), I18n.tr("Surface"), I18n.tr("Custom")]
                                    currentIndex: {
                                        const override = SettingsData.launcherLogoColorOverride
                                        if (override === "") return 0
                                        if (override === "primary") return 1
                                        if (override === "surface") return 2
                                        return 3
                                    }
                                    onSelectionChanged: (index, selected) => {
                                        if (!selected) return
                                        if (index === 0) {
                                            SettingsData.setLauncherLogoColorOverride("")
                                        } else if (index === 1) {
                                            SettingsData.setLauncherLogoColorOverride("primary")
                                        } else if (index === 2) {
                                            SettingsData.setLauncherLogoColorOverride("surface")
                                        } else if (index === 3) {
                                            const currentOverride = SettingsData.launcherLogoColorOverride
                                            const isPreset = currentOverride === "" || currentOverride === "primary" || currentOverride === "surface"
                                            if (isPreset) {
                                                SettingsData.setLauncherLogoColorOverride("#ffffff")
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: {
                                        const override = SettingsData.launcherLogoColorOverride
                                        return override !== "" && override !== "primary" && override !== "surface"
                                    }
                                    width: 36
                                    height: 36
                                    radius: 18
                                    color: {
                                        const override = SettingsData.launcherLogoColorOverride
                                        if (override !== "" && override !== "primary" && override !== "surface") {
                                            return override
                                        }
                                        return "#ffffff"
                                    }
                                    border.color: Theme.outline
                                    border.width: 1
                                    anchors.verticalCenter: parent.verticalCenter

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (PopoutService.colorPickerModal) {
                                                PopoutService.colorPickerModal.selectedColor = SettingsData.launcherLogoColorOverride
                                                PopoutService.colorPickerModal.pickerTitle = I18n.tr("Choose Launcher Logo Color")
                                                PopoutService.colorPickerModal.onColorSelectedCallback = function(selectedColor) {
                                                    SettingsData.setLauncherLogoColorOverride(selectedColor)
                                                }
                                                PopoutService.colorPickerModal.show()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS

                            Column {
                                width: 120
                                spacing: Theme.spacingS
                                anchors.horizontalCenter: parent.horizontalCenter

                                StyledText {
                                    text: I18n.tr("Size Offset")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                DankSlider {
                                    width: 100
                                    height: 20
                                    minimum: -12
                                    maximum: 12
                                    value: SettingsData.launcherLogoSizeOffset
                                    unit: ""
                                    showValue: true
                                    wheelEnabled: false
                                    thumbOutlineColor: Theme.surfaceContainerHigh
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    onSliderValueChanged: newValue => {
                                        SettingsData.setLauncherLogoSizeOffset(newValue)
                                    }
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: customControlsFlow.height
                            visible: {
                                const override = SettingsData.launcherLogoColorOverride
                                return override !== "" && override !== "primary" && override !== "surface"
                            }
                            opacity: visible ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.mediumDuration
                                    easing.type: Theme.emphasizedEasing
                                }
                            }

                            Flow {
                                id: customControlsFlow
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Theme.spacingS

                                Column {
                                    width: 120
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: I18n.tr("Brightness")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    DankSlider {
                                        width: 100
                                        height: 20
                                        minimum: 0
                                        maximum: 100
                                        value: Math.round(SettingsData.launcherLogoBrightness * 100)
                                        unit: "%"
                                        showValue: true
                                        wheelEnabled: false
                                        thumbOutlineColor: Theme.surfaceContainerHigh
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        onSliderValueChanged: newValue => {
                                            SettingsData.setLauncherLogoBrightness(newValue / 100)
                                        }
                                    }
                                }

                                Column {
                                    width: 120
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: I18n.tr("Contrast")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    DankSlider {
                                        width: 100
                                        height: 20
                                        minimum: 0
                                        maximum: 200
                                        value: Math.round(SettingsData.launcherLogoContrast * 100)
                                        unit: "%"
                                        showValue: true
                                        wheelEnabled: false
                                        thumbOutlineColor: Theme.surfaceContainerHigh
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        onSliderValueChanged: newValue => {
                                            SettingsData.setLauncherLogoContrast(newValue / 100)
                                        }
                                    }
                                }

                                Column {
                                    width: 120
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: I18n.tr("Invert on mode change")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        font.weight: Font.Medium
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    DankToggle {
                                        width: 32
                                        height: 18
                                        checked: SettingsData.launcherLogoColorInvertOnMode
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        onToggled: checked => {
                                            SettingsData.setLauncherLogoColorInvertOnMode(checked)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: launchPrefixSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: launchPrefixSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "terminal"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Launch Prefix")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Add a custom prefix to all application launches. This can be used for things like 'uwsm-app', 'systemd-run', or other command wrappers.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    DankTextField {
                        width: parent.width
                        text: SessionData.launchPrefix
                        placeholderText: "Enter launch prefix (e.g., 'uwsm-app')"
                        onTextEdited: {
                            SessionData.setLaunchPrefix(text)
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: recentlyUsedSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: recentlyUsedSection

                    property var rankedAppsModel: {
                        var apps = []
                        for (var appId in (AppUsageHistoryData.appUsageRanking
                                           || {})) {
                            var appData = (AppUsageHistoryData.appUsageRanking
                                           || {})[appId]
                            apps.push({
                                          "id": appId,
                                          "name": appData.name,
                                          "exec": appData.exec,
                                          "icon": appData.icon,
                                          "comment": appData.comment,
                                          "usageCount": appData.usageCount,
                                          "lastUsed": appData.lastUsed
                                      })
                        }
                        apps.sort(function (a, b) {
                            if (a.usageCount !== b.usageCount)
                                return b.usageCount - a.usageCount

                            return a.name.localeCompare(b.name)
                        })
                        return apps.slice(0, 20)
                    }

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "history"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Recently Used Apps")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            width: parent.width - parent.children[0].width
                                   - parent.children[1].width
                                   - clearAllButton.width - Theme.spacingM * 3
                            height: 1
                        }

                        DankActionButton {
                            id: clearAllButton

                            iconName: "delete_sweep"
                            iconSize: Theme.iconSize - 2
                            iconColor: Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                AppUsageHistoryData.appUsageRanking = {}
                                SettingsData.saveSettings()
                            }
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("Apps are ordered by usage frequency, then last used, then alphabetically.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    Column {
                        id: rankedAppsList

                        width: parent.width
                        spacing: Theme.spacingS

                        Repeater {
                            model: recentlyUsedSection.rankedAppsModel

                            delegate: Rectangle {
                                width: rankedAppsList.width
                                height: 48
                                radius: Theme.cornerRadius
                                color: Qt.rgba(Theme.surfaceContainer.r,
                                               Theme.surfaceContainer.g,
                                               Theme.surfaceContainer.b, 0.3)
                                border.color: Qt.rgba(Theme.outline.r,
                                                      Theme.outline.g,
                                                      Theme.outline.b, 0.1)
                                border.width: 0

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingM

                                    StyledText {
                                        text: (index + 1).toString()
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                        color: Theme.primary
                                        width: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Image {
                                        width: 24
                                        height: 24
                                        source: modelData.icon ? "image://icon/" + modelData.icon : "image://icon/application-x-executable"
                                        sourceSize.width: 24
                                        sourceSize.height: 24
                                        fillMode: Image.PreserveAspectFit
                                        anchors.verticalCenter: parent.verticalCenter
                                        onStatusChanged: {
                                            if (status === Image.Error)
                                                source = "image://icon/application-x-executable"
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        StyledText {
                                            text: modelData.name
                                                  || "Unknown App"
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                        }

                                        StyledText {
                                            text: {
                                                if (!modelData.lastUsed)
                                                    return "Never used"

                                                var date = new Date(modelData.lastUsed)
                                                var now = new Date()
                                                var diffMs = now - date
                                                var diffMins = Math.floor(
                                                            diffMs / (1000 * 60))
                                                var diffHours = Math.floor(
                                                            diffMs / (1000 * 60 * 60))
                                                var diffDays = Math.floor(
                                                            diffMs / (1000 * 60 * 60 * 24))
                                                if (diffMins < 1)
                                                    return "Last launched just now"

                                                if (diffMins < 60)
                                                    return "Last launched " + diffMins + " minute"
                                                            + (diffMins === 1 ? "" : "s") + " ago"

                                                if (diffHours < 24)
                                                    return "Last launched " + diffHours + " hour"
                                                            + (diffHours === 1 ? "" : "s") + " ago"

                                                if (diffDays < 7)
                                                    return "Last launched " + diffDays + " day"
                                                            + (diffDays === 1 ? "" : "s") + " ago"

                                                return "Last launched " + date.toLocaleDateString()
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                }

                                DankActionButton {
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    circular: true
                                    iconName: "close"
                                    iconSize: 16
                                    iconColor: Theme.error
                                    onClicked: {
                                        var currentRanking = Object.assign(
                                                    {},
                                                    AppUsageHistoryData.appUsageRanking
                                                    || {})
                                        delete currentRanking[modelData.id]
                                        AppUsageHistoryData.appUsageRanking = currentRanking
                                        SettingsData.saveSettings()
                                    }
                                }
                            }
                        }

                        StyledText {
                            width: parent.width
                            text: recentlyUsedSection.rankedAppsModel.length
                                  === 0 ? "No apps have been launched yet." : ""
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            horizontalAlignment: Text.AlignHCenter
                            visible: recentlyUsedSection.rankedAppsModel.length === 0
                        }
                    }
                }
            }
        }
    }
}
