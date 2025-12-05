import QtQuick
import qs.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    FileBrowserModal {
        id: logoFileBrowser
        browserTitle: I18n.tr("Select Launcher Logo")
        browserIcon: "image"
        browserType: "generic"
        filterExtensions: ["*.svg", "*.png", "*.jpg", "*.jpeg", "*.webp"]
        onFileSelected: path => SettingsData.set("launcherLogoCustomPath", path.replace("file://", ""))
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
                iconName: "apps"
                title: I18n.tr("Launcher Button Logo")

                StyledText {
                    width: parent.width
                    text: I18n.tr("Choose the logo displayed on the launcher button in DankBar")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                Item {
                    width: parent.width
                    height: logoModeGroup.implicitHeight
                    clip: true

                    DankButtonGroup {
                        id: logoModeGroup
                        anchors.horizontalCenter: parent.horizontalCenter
                        buttonPadding: parent.width < 480 ? Theme.spacingS : Theme.spacingL
                        minButtonWidth: parent.width < 480 ? 44 : 64
                        textSize: parent.width < 480 ? Theme.fontSizeSmall : Theme.fontSizeMedium
                        model: {
                            const modes = [I18n.tr("Apps Icon"), I18n.tr("OS Logo"), I18n.tr("Dank")];
                            if (CompositorService.isNiri) {
                                modes.push("niri");
                            } else if (CompositorService.isHyprland) {
                                modes.push("Hyprland");
                            } else if (CompositorService.isDwl) {
                                modes.push("mango");
                            } else if (CompositorService.isSway) {
                                modes.push("Sway");
                            } else {
                                modes.push(I18n.tr("Compositor"));
                            }
                            modes.push(I18n.tr("Custom"));
                            return modes;
                        }
                        currentIndex: {
                            if (SettingsData.launcherLogoMode === "apps")
                                return 0;
                            if (SettingsData.launcherLogoMode === "os")
                                return 1;
                            if (SettingsData.launcherLogoMode === "dank")
                                return 2;
                            if (SettingsData.launcherLogoMode === "compositor")
                                return 3;
                            if (SettingsData.launcherLogoMode === "custom")
                                return 4;
                            return 0;
                        }
                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            switch (index) {
                            case 0:
                                SettingsData.set("launcherLogoMode", "apps");
                                break;
                            case 1:
                                SettingsData.set("launcherLogoMode", "os");
                                break;
                            case 2:
                                SettingsData.set("launcherLogoMode", "dank");
                                break;
                            case 3:
                                SettingsData.set("launcherLogoMode", "compositor");
                                break;
                            case 4:
                                SettingsData.set("launcherLogoMode", "custom");
                                break;
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    visible: SettingsData.launcherLogoMode === "custom"
                    spacing: Theme.spacingM

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

                        Item {
                            width: parent.width
                            height: colorOverrideRow.implicitHeight
                            clip: true

                            Row {
                                id: colorOverrideRow
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: Theme.spacingM

                                DankButtonGroup {
                                    id: colorModeGroup
                                    buttonPadding: parent.parent.width < 480 ? Theme.spacingS : Theme.spacingL
                                    minButtonWidth: parent.parent.width < 480 ? 44 : 64
                                    textSize: parent.parent.width < 480 ? Theme.fontSizeSmall : Theme.fontSizeMedium
                                    model: [I18n.tr("Default"), I18n.tr("Primary"), I18n.tr("Surface"), I18n.tr("Custom")]
                                    currentIndex: {
                                        const override = SettingsData.launcherLogoColorOverride;
                                        if (override === "")
                                            return 0;
                                        if (override === "primary")
                                            return 1;
                                        if (override === "surface")
                                            return 2;
                                        return 3;
                                    }
                                    onSelectionChanged: (index, selected) => {
                                        if (!selected)
                                            return;
                                        switch (index) {
                                        case 0:
                                            SettingsData.set("launcherLogoColorOverride", "");
                                            break;
                                        case 1:
                                            SettingsData.set("launcherLogoColorOverride", "primary");
                                            break;
                                        case 2:
                                            SettingsData.set("launcherLogoColorOverride", "surface");
                                            break;
                                        case 3:
                                            const currentOverride = SettingsData.launcherLogoColorOverride;
                                            const isPreset = currentOverride === "" || currentOverride === "primary" || currentOverride === "surface";
                                            if (isPreset) {
                                                SettingsData.set("launcherLogoColorOverride", "#ffffff");
                                            }
                                            break;
                                        }
                                    }
                                }

                                Rectangle {
                                    id: colorPickerCircle
                                    visible: {
                                        const override = SettingsData.launcherLogoColorOverride;
                                        return override !== "" && override !== "primary" && override !== "surface";
                                    }
                                    width: 36
                                    height: 36
                                    radius: 18
                                    color: {
                                        const override = SettingsData.launcherLogoColorOverride;
                                        if (override !== "" && override !== "primary" && override !== "surface")
                                            return override;
                                        return "#ffffff";
                                    }
                                    border.color: Theme.outline
                                    border.width: 1
                                    anchors.verticalCenter: parent.verticalCenter

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!PopoutService.colorPickerModal)
                                                return;
                                            PopoutService.colorPickerModal.selectedColor = SettingsData.launcherLogoColorOverride;
                                            PopoutService.colorPickerModal.pickerTitle = I18n.tr("Choose Launcher Logo Color");
                                            PopoutService.colorPickerModal.onColorSelectedCallback = function (selectedColor) {
                                                SettingsData.set("launcherLogoColorOverride", selectedColor);
                                            };
                                            PopoutService.colorPickerModal.show();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    SettingsSliderRow {
                        text: I18n.tr("Size Offset")
                        minimum: -12
                        maximum: 12
                        value: SettingsData.launcherLogoSizeOffset
                        defaultValue: 0
                        onSliderValueChanged: newValue => SettingsData.set("launcherLogoSizeOffset", newValue)
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: {
                            const override = SettingsData.launcherLogoColorOverride;
                            return override !== "" && override !== "primary" && override !== "surface";
                        }

                        SettingsSliderRow {
                            text: I18n.tr("Brightness")
                            minimum: 0
                            maximum: 100
                            value: Math.round(SettingsData.launcherLogoBrightness * 100)
                            unit: "%"
                            defaultValue: 100
                            onSliderValueChanged: newValue => SettingsData.set("launcherLogoBrightness", newValue / 100)
                        }

                        SettingsSliderRow {
                            text: I18n.tr("Contrast")
                            minimum: 0
                            maximum: 200
                            value: Math.round(SettingsData.launcherLogoContrast * 100)
                            unit: "%"
                            defaultValue: 100
                            onSliderValueChanged: newValue => SettingsData.set("launcherLogoContrast", newValue / 100)
                        }

                        SettingsToggleRow {
                            text: I18n.tr("Invert on mode change")
                            checked: SettingsData.launcherLogoColorInvertOnMode
                            onToggled: checked => SettingsData.set("launcherLogoColorInvertOnMode", checked)
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "terminal"
                title: I18n.tr("Launch Prefix")

                StyledText {
                    width: parent.width
                    text: I18n.tr("Add a custom prefix to all application launches. This can be used for things like 'uwsm-app', 'systemd-run', or other command wrappers.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                DankTextField {
                    width: parent.width
                    text: SettingsData.launchPrefix
                    placeholderText: I18n.tr("Enter launch prefix (e.g., 'uwsm-app')")
                    onTextEdited: SettingsData.set("launchPrefix", text)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "sort_by_alpha"
                title: I18n.tr("Sorting & Layout")

                SettingsToggleRow {
                    text: I18n.tr("Sort Alphabetically")
                    description: I18n.tr("When enabled, apps are sorted alphabetically. When disabled, apps are sorted by usage frequency.")
                    checked: SettingsData.sortAppsAlphabetically
                    onToggled: checked => SettingsData.set("sortAppsAlphabetically", checked)
                }

                SettingsSliderRow {
                    text: I18n.tr("Grid Columns")
                    description: I18n.tr("Adjust the number of columns in grid view mode.")
                    minimum: 2
                    maximum: 8
                    value: SettingsData.appLauncherGridColumns
                    defaultValue: 5
                    onSliderValueChanged: newValue => SettingsData.set("appLauncherGridColumns", newValue)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "open_in_new"
                title: I18n.tr("Niri Integration")
                visible: CompositorService.isNiri

                SettingsToggleRow {
                    text: I18n.tr("Close Overview on Launch")
                    description: I18n.tr("Auto-close Niri overview when launching apps.")
                    checked: SettingsData.spotlightCloseNiriOverview
                    onToggled: checked => SettingsData.set("spotlightCloseNiriOverview", checked)
                }

                SettingsToggleRow {
                    text: I18n.tr("Enable Overview Overlay")
                    description: I18n.tr("Show launcher overlay when typing in Niri overview. Disable to use another launcher.")
                    checked: SettingsData.niriOverviewOverlayEnabled
                    onToggled: checked => SettingsData.set("niriOverviewOverlayEnabled", checked)
                }
            }

            SettingsCard {
                id: recentAppsCard
                width: parent.width
                iconName: "history"
                title: I18n.tr("Recently Used Apps")

                property var rankedAppsModel: {
                    var ranking = AppUsageHistoryData.appUsageRanking;
                    if (!ranking)
                        return [];
                    var apps = [];
                    for (var appId in ranking) {
                        var appData = ranking[appId];
                        apps.push({
                            "id": appId,
                            "name": appData.name,
                            "exec": appData.exec,
                            "icon": appData.icon,
                            "comment": appData.comment,
                            "usageCount": appData.usageCount,
                            "lastUsed": appData.lastUsed
                        });
                    }
                    apps.sort(function (a, b) {
                        if (a.usageCount !== b.usageCount)
                            return b.usageCount - a.usageCount;
                        return a.name.localeCompare(b.name);
                    });
                    return apps.slice(0, 20);
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    StyledText {
                        width: parent.width - clearAllButton.width - Theme.spacingM
                        text: I18n.tr("Apps are ordered by usage frequency, then last used, then alphabetically.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankActionButton {
                        id: clearAllButton
                        iconName: "delete_sweep"
                        iconSize: Theme.iconSize - 2
                        iconColor: Theme.error
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            AppUsageHistoryData.appUsageRanking = {};
                            AppUsageHistoryData.saveSettings();
                        }
                    }
                }

                Column {
                    id: rankedAppsList
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: recentAppsCard.rankedAppsModel

                        delegate: Rectangle {
                            width: rankedAppsList.width
                            height: 48
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.3)
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
                                            source = "image://icon/application-x-executable";
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    StyledText {
                                        text: modelData.name || "Unknown App"
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: {
                                            if (!modelData.lastUsed)
                                                return "Never used";
                                            var date = new Date(modelData.lastUsed);
                                            var now = new Date();
                                            var diffMs = now - date;
                                            var diffMins = Math.floor(diffMs / (1000 * 60));
                                            var diffHours = Math.floor(diffMs / (1000 * 60 * 60));
                                            var diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
                                            if (diffMins < 1)
                                                return I18n.tr("Last launched just now");
                                            if (diffMins < 60)
                                                return I18n.tr("Last launched %1 minute%2 ago").arg(diffMins).arg(diffMins === 1 ? "" : "s");
                                            if (diffHours < 24)
                                                return I18n.tr("Last launched %1 hour%2 ago").arg(diffHours).arg(diffHours === 1 ? "" : "s");
                                            if (diffDays < 7)
                                                return I18n.tr("Last launched %1 day%2 ago").arg(diffDays).arg(diffDays === 1 ? "" : "s");
                                            return I18n.tr("Last launched %1").arg(date.toLocaleDateString());
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
                                    var currentRanking = Object.assign({}, AppUsageHistoryData.appUsageRanking || {});
                                    delete currentRanking[modelData.id];
                                    AppUsageHistoryData.appUsageRanking = currentRanking;
                                    AppUsageHistoryData.saveSettings();
                                }
                            }
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: "No apps have been launched yet."
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        horizontalAlignment: Text.AlignHCenter
                        visible: recentAppsCard.rankedAppsModel.length === 0
                    }
                }
            }
        }
    }
}
