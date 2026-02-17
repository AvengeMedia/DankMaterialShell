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
            topPadding: 4
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                width: parent.width
                iconName: "apps"
                title: I18n.tr("Launcher Button Logo")
                settingKey: "launcherLogo"

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
                            } else if (CompositorService.isScroll) {
                                modes.push("Scroll");
                            } else if (CompositorService.isMiracle) {
                                modes.push("Miracle");
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
                        settingKey: "launcherLogoSizeOffset"
                        tags: ["launcher", "logo", "size", "offset", "scale"]
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
                            settingKey: "launcherLogoBrightness"
                            tags: ["launcher", "logo", "brightness", "color"]
                            text: I18n.tr("Brightness")
                            minimum: 0
                            maximum: 100
                            value: Math.round(SettingsData.launcherLogoBrightness * 100)
                            unit: "%"
                            defaultValue: 100
                            onSliderValueChanged: newValue => SettingsData.set("launcherLogoBrightness", newValue / 100)
                        }

                        SettingsSliderRow {
                            settingKey: "launcherLogoContrast"
                            tags: ["launcher", "logo", "contrast", "color"]
                            text: I18n.tr("Contrast")
                            minimum: 0
                            maximum: 200
                            value: Math.round(SettingsData.launcherLogoContrast * 100)
                            unit: "%"
                            defaultValue: 100
                            onSliderValueChanged: newValue => SettingsData.set("launcherLogoContrast", newValue / 100)
                        }

                        SettingsToggleRow {
                            settingKey: "launcherLogoColorInvertOnMode"
                            tags: ["launcher", "logo", "invert", "mode", "color"]
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
                settingKey: "launchPrefix"

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
                settingKey: "launcherSorting"

                SettingsToggleRow {
                    settingKey: "sortAppsAlphabetically"
                    tags: ["launcher", "sort", "alphabetically", "apps", "order"]
                    text: I18n.tr("Sort Alphabetically")
                    description: I18n.tr("When enabled, apps are sorted alphabetically. When disabled, apps are sorted by usage frequency.")
                    checked: SettingsData.sortAppsAlphabetically
                    onToggled: checked => SettingsData.set("sortAppsAlphabetically", checked)
                }

                SettingsSliderRow {
                    settingKey: "appLauncherGridColumns"
                    tags: ["launcher", "grid", "columns", "layout"]
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
                iconName: "tune"
                title: I18n.tr("Appearance", "launcher appearance settings")
                settingKey: "dankLauncherV2Appearance"

                Column {
                    width: parent.width
                    spacing: Theme.spacingM

                    StyledText {
                        text: I18n.tr("Size", "launcher size option")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Item {
                        width: parent.width
                        height: sizeGroup.implicitHeight
                        clip: true

                        DankButtonGroup {
                            id: sizeGroup
                            anchors.horizontalCenter: parent.horizontalCenter
                            buttonPadding: parent.width < 400 ? Theme.spacingS : Theme.spacingL
                            minButtonWidth: parent.width < 400 ? 60 : 80
                            textSize: parent.width < 400 ? Theme.fontSizeSmall : Theme.fontSizeMedium
                            model: ["1", "2", "3", "4"]
                            currentIndex: {
                                switch (SettingsData.dankLauncherV2Size) {
                                case "micro":
                                    return 0;
                                case "compact":
                                    return 1;
                                case "large":
                                    return 3;
                                default:
                                    return 2;
                                }
                            }
                            onSelectionChanged: (index, selected) => {
                                if (!selected)
                                    return;
                                var sizes = ["micro", "compact", "medium", "large"];
                                SettingsData.set("dankLauncherV2Size", sizes[index]);
                            }
                        }
                    }
                }

                SettingsToggleRow {
                    settingKey: "dankLauncherV2ShowFooter"
                    tags: ["launcher", "footer", "hints", "shortcuts"]
                    text: I18n.tr("Show Footer", "launcher footer visibility")
                    description: I18n.tr("Show mode tabs and keyboard hints at the bottom.", "launcher footer description")
                    checked: SettingsData.dankLauncherV2ShowFooter
                    enabled: SettingsData.dankLauncherV2Size !== "micro"
                    onToggled: checked => SettingsData.set("dankLauncherV2ShowFooter", checked)
                }

                SettingsToggleRow {
                    settingKey: "dankLauncherV2UnloadOnClose"
                    tags: ["launcher", "unload", "close", "memory", "vram"]
                    text: I18n.tr("Unload on Close")
                    description: I18n.tr("Free VRAM/memory when the launcher is closed. May cause a slight delay when reopening.")
                    checked: SettingsData.dankLauncherV2UnloadOnClose
                    onToggled: checked => SettingsData.set("dankLauncherV2UnloadOnClose", checked)
                }

                SettingsToggleRow {
                    settingKey: "dankLauncherV2BorderEnabled"
                    tags: ["launcher", "border", "outline"]
                    text: I18n.tr("Border", "launcher border option")
                    checked: SettingsData.dankLauncherV2BorderEnabled
                    onToggled: checked => SettingsData.set("dankLauncherV2BorderEnabled", checked)
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: SettingsData.dankLauncherV2BorderEnabled

                    SettingsSliderRow {
                        settingKey: "dankLauncherV2BorderThickness"
                        tags: ["launcher", "border", "thickness"]
                        text: I18n.tr("Thickness", "border thickness")
                        minimum: 1
                        maximum: 6
                        value: SettingsData.dankLauncherV2BorderThickness
                        defaultValue: 2
                        unit: "px"
                        onSliderValueChanged: newValue => SettingsData.set("dankLauncherV2BorderThickness", newValue)
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Color", "border color")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Item {
                            width: parent.width
                            height: borderColorGroup.implicitHeight
                            clip: true

                            DankButtonGroup {
                                id: borderColorGroup
                                anchors.horizontalCenter: parent.horizontalCenter
                                buttonPadding: parent.width < 400 ? Theme.spacingS : Theme.spacingL
                                minButtonWidth: parent.width < 400 ? 50 : 70
                                textSize: parent.width < 400 ? Theme.fontSizeSmall : Theme.fontSizeMedium
                                model: [I18n.tr("Primary", "primary color"), I18n.tr("Secondary", "secondary color"), I18n.tr("Outline", "outline color"), I18n.tr("Text", "text color")]
                                currentIndex: SettingsData.dankLauncherV2BorderColor === "secondary" ? 1 : SettingsData.dankLauncherV2BorderColor === "outline" ? 2 : SettingsData.dankLauncherV2BorderColor === "surfaceText" ? 3 : 0
                                onSelectionChanged: (index, selected) => {
                                    if (!selected)
                                        return;
                                    SettingsData.set("dankLauncherV2BorderColor", index === 1 ? "secondary" : index === 2 ? "outline" : index === 3 ? "surfaceText" : "primary");
                                }
                            }
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "open_in_new"
                title: I18n.tr("Niri Integration").replace("Niri", "niri")
                visible: CompositorService.isNiri

                SettingsToggleRow {
                    settingKey: "spotlightCloseNiriOverview"
                    tags: ["launcher", "niri", "overview", "close", "launch"]
                    text: I18n.tr("Close Overview on Launch")
                    description: I18n.tr("Auto-close Niri overview when launching apps.")
                    checked: SettingsData.spotlightCloseNiriOverview
                    onToggled: checked => SettingsData.set("spotlightCloseNiriOverview", checked)
                }

                SettingsToggleRow {
                    settingKey: "niriOverviewOverlayEnabled"
                    tags: ["launcher", "niri", "overview", "overlay", "enable"]
                    text: I18n.tr("Enable Overview Overlay")
                    description: I18n.tr("Show launcher overlay when typing in Niri overview. Disable to use another launcher.")
                    checked: SettingsData.niriOverviewOverlayEnabled
                    onToggled: checked => SettingsData.set("niriOverviewOverlayEnabled", checked)
                }
            }

            SettingsCard {
                id: builtInPluginsCard
                width: parent.width
                iconName: "extension"
                title: "DMS"
                settingKey: "builtInPlugins"

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: ["dms_settings", "dms_notepad", "dms_sysmon", "dms_settings_search"]

                        delegate: Rectangle {
                            id: pluginDelegate
                            required property string modelData
                            required property int index
                            readonly property var plugin: AppSearchService.builtInPlugins[modelData]

                            width: parent.width
                            height: 56
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.3)

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: pluginDelegate.plugin?.cornerIcon ?? "extension"
                                    size: Theme.iconSize
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    StyledText {
                                        text: pluginDelegate.plugin?.name ?? pluginDelegate.modelData
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: pluginDelegate.plugin?.comment ?? ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingM

                                DankTextField {
                                    id: triggerField
                                    width: 60
                                    visible: pluginDelegate.plugin?.isLauncher === true
                                    anchors.verticalCenter: parent.verticalCenter
                                    placeholderText: I18n.tr("Trigger")
                                    onTextEdited: SettingsData.setBuiltInPluginSetting(pluginDelegate.modelData, "trigger", text)
                                    Component.onCompleted: text = SettingsData.getBuiltInPluginSetting(pluginDelegate.modelData, "trigger", pluginDelegate.plugin?.defaultTrigger ?? "")
                                }

                                DankToggle {
                                    id: enableToggle
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: SettingsData.getBuiltInPluginSetting(pluginDelegate.modelData, "enabled", true)
                                    onToggled: SettingsData.setBuiltInPluginSetting(pluginDelegate.modelData, "enabled", checked)
                                }
                            }
                        }
                    }
                }
            }

            SettingsCard {
                id: pluginVisibilityCard
                width: parent.width
                iconName: "filter_list"
                title: I18n.tr("Plugin Visibility")
                settingKey: "pluginVisibility"

                property var allLauncherPlugins: {
                    SettingsData.launcherPluginVisibility;
                    SettingsData.launcherPluginOrder;
                    var plugins = [];
                    var builtIn = AppSearchService.getBuiltInLauncherPlugins() || {};
                    for (var pluginId in builtIn) {
                        var plugin = builtIn[pluginId];
                        plugins.push({
                            id: pluginId,
                            name: plugin.name || pluginId,
                            icon: plugin.cornerIcon || "extension",
                            iconType: "material",
                            isBuiltIn: true,
                            trigger: AppSearchService.getBuiltInPluginTrigger(pluginId) || ""
                        });
                    }
                    var thirdParty = PluginService.getLauncherPlugins() || {};
                    for (var pluginId in thirdParty) {
                        var plugin = thirdParty[pluginId];
                        var rawIcon = plugin.icon || "extension";
                        plugins.push({
                            id: pluginId,
                            name: plugin.name || pluginId,
                            icon: rawIcon.startsWith("material:") ? rawIcon.substring(9) : rawIcon.startsWith("unicode:") ? rawIcon.substring(8) : rawIcon,
                            iconType: rawIcon.startsWith("unicode:") ? "unicode" : "material",
                            isBuiltIn: false,
                            trigger: PluginService.getPluginTrigger(pluginId) || ""
                        });
                    }
                    return SettingsData.getOrderedLauncherPlugins(plugins);
                }

                function reorderPlugin(fromIndex, toIndex) {
                    if (fromIndex === toIndex)
                        return;
                    var currentOrder = allLauncherPlugins.map(p => p.id);
                    var item = currentOrder.splice(fromIndex, 1)[0];
                    currentOrder.splice(toIndex, 0, item);
                    SettingsData.setLauncherPluginOrder(currentOrder);
                }

                StyledText {
                    width: parent.width
                    text: I18n.tr("Control which plugins appear in 'All' mode without requiring a trigger prefix. Drag to reorder.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                Column {
                    id: pluginVisibilityColumn
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: pluginVisibilityCard.allLauncherPlugins

                        delegate: Item {
                            id: visibilityDelegateItem
                            required property var modelData
                            required property int index

                            property bool held: pluginDragArea.pressed
                            property real originalY: y

                            width: pluginVisibilityColumn.width
                            height: 52
                            z: held ? 2 : 1

                            Rectangle {
                                id: visibilityDelegate
                                width: parent.width
                                height: 52
                                radius: Theme.cornerRadius
                                color: visibilityDelegateItem.held ? Theme.surfaceHover : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.3)

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 28
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingM

                                    Item {
                                        width: Theme.iconSize
                                        height: Theme.iconSize
                                        anchors.verticalCenter: parent.verticalCenter

                                        DankIcon {
                                            anchors.centerIn: parent
                                            visible: visibilityDelegateItem.modelData.iconType !== "unicode"
                                            name: visibilityDelegateItem.modelData.icon
                                            size: Theme.iconSize
                                            color: Theme.primary
                                        }

                                        StyledText {
                                            anchors.centerIn: parent
                                            visible: visibilityDelegateItem.modelData.iconType === "unicode"
                                            text: visibilityDelegateItem.modelData.icon
                                            font.pixelSize: Theme.iconSize
                                            color: Theme.primary
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        Row {
                                            spacing: Theme.spacingS

                                            StyledText {
                                                text: visibilityDelegateItem.modelData.name
                                                font.pixelSize: Theme.fontSizeMedium
                                                color: Theme.surfaceText
                                            }

                                            Rectangle {
                                                visible: visibilityDelegateItem.modelData.isBuiltIn
                                                width: dmsBadgeLabel.implicitWidth + Theme.spacingS
                                                height: 16
                                                radius: 8
                                                color: Theme.primaryContainer
                                                anchors.verticalCenter: parent.verticalCenter

                                                StyledText {
                                                    id: dmsBadgeLabel
                                                    anchors.centerIn: parent
                                                    text: "DMS"
                                                    font.pixelSize: Theme.fontSizeSmall - 2
                                                    color: Theme.primary
                                                }
                                            }
                                        }

                                        StyledText {
                                            text: visibilityDelegateItem.modelData.trigger ? I18n.tr("Trigger: %1").arg(visibilityDelegateItem.modelData.trigger) : I18n.tr("No trigger")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                }

                                DankToggle {
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: SettingsData.getPluginAllowWithoutTrigger(visibilityDelegateItem.modelData.id)
                                    onToggled: function (isChecked) {
                                        SettingsData.setPluginAllowWithoutTrigger(visibilityDelegateItem.modelData.id, isChecked);
                                    }
                                }
                            }

                            MouseArea {
                                id: pluginDragArea
                                anchors.left: parent.left
                                anchors.top: parent.top
                                width: 28
                                height: parent.height
                                hoverEnabled: true
                                cursorShape: Qt.SizeVerCursor
                                drag.target: visibilityDelegateItem.held ? visibilityDelegateItem : undefined
                                drag.axis: Drag.YAxis
                                preventStealing: true

                                onPressed: {
                                    visibilityDelegateItem.originalY = visibilityDelegateItem.y;
                                }

                                onReleased: {
                                    if (!drag.active) {
                                        visibilityDelegateItem.y = visibilityDelegateItem.originalY;
                                        return;
                                    }
                                    const spacing = Theme.spacingS;
                                    const itemH = visibilityDelegateItem.height + spacing;
                                    var newIndex = Math.round(visibilityDelegateItem.y / itemH);
                                    newIndex = Math.max(0, Math.min(newIndex, pluginVisibilityCard.allLauncherPlugins.length - 1));
                                    pluginVisibilityCard.reorderPlugin(visibilityDelegateItem.index, newIndex);
                                    visibilityDelegateItem.y = visibilityDelegateItem.originalY;
                                }
                            }

                            DankIcon {
                                x: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter
                                name: "drag_indicator"
                                size: 18
                                color: Theme.outline
                                opacity: pluginDragArea.containsMouse || pluginDragArea.pressed ? 1 : 0.5
                            }

                            Behavior on y {
                                enabled: !pluginDragArea.pressed && !pluginDragArea.drag.active
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("No launcher plugins installed.")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        horizontalAlignment: Text.AlignHCenter
                        visible: pluginVisibilityCard.allLauncherPlugins.length === 0
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "search"
                title: I18n.tr("Search Options")
                settingKey: "searchOptions"

                SettingsToggleRow {
                    settingKey: "searchAppActions"
                    tags: ["launcher", "search", "actions", "shortcuts"]
                    text: I18n.tr("Search App Actions")
                    description: I18n.tr("Include desktop actions (shortcuts) in search results.")
                    checked: SessionData.searchAppActions
                    onToggled: checked => SessionData.setSearchAppActions(checked)
                }
            }

            SettingsCard {
                id: hiddenAppsCard
                width: parent.width
                iconName: "visibility_off"
                title: I18n.tr("Hidden Apps")
                settingKey: "hiddenApps"

                property var hiddenAppsModel: {
                    SessionData.hiddenApps;
                    const apps = [];
                    const allApps = AppSearchService.applications || [];
                    for (const hiddenId of SessionData.hiddenApps) {
                        const app = allApps.find(a => (a.id || a.execString || a.exec) === hiddenId);
                        if (app) {
                            apps.push({
                                id: hiddenId,
                                name: app.name || hiddenId,
                                icon: app.icon || "",
                                comment: app.comment || ""
                            });
                        } else {
                            apps.push({
                                id: hiddenId,
                                name: hiddenId,
                                icon: "",
                                comment: ""
                            });
                        }
                    }
                    return apps.sort((a, b) => a.name.localeCompare(b.name));
                }

                StyledText {
                    width: parent.width
                    text: I18n.tr("Hidden apps won't appear in the launcher. Right-click an app and select 'Hide App' to hide it.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                Column {
                    id: hiddenAppsList
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: hiddenAppsCard.hiddenAppsModel

                        delegate: Rectangle {
                            width: hiddenAppsList.width
                            height: 48
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.3)
                            border.width: 0

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingM

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
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: modelData.comment || modelData.id
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        visible: text.length > 0
                                    }
                                }
                            }

                            DankActionButton {
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                iconName: "visibility"
                                iconSize: 18
                                iconColor: Theme.primary
                                onClicked: SessionData.showApp(modelData.id)
                            }
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("No hidden apps.")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        horizontalAlignment: Text.AlignHCenter
                        visible: hiddenAppsCard.hiddenAppsModel.length === 0
                    }
                }
            }

            SettingsCard {
                id: appOverridesCard
                width: parent.width
                iconName: "edit"
                title: I18n.tr("App Customizations")
                settingKey: "appOverrides"

                property var overridesModel: {
                    SessionData.appOverrides;
                    const items = [];
                    const allApps = AppSearchService.applications || [];
                    for (const appId in SessionData.appOverrides) {
                        const override = SessionData.appOverrides[appId];
                        const app = allApps.find(a => (a.id || a.execString || a.exec) === appId);
                        items.push({
                            id: appId,
                            name: override.name || app?.name || appId,
                            originalName: app?.name || appId,
                            icon: override.icon || app?.icon || "",
                            hasOverride: true
                        });
                    }
                    return items.sort((a, b) => a.name.localeCompare(b.name));
                }

                StyledText {
                    width: parent.width
                    text: I18n.tr("Apps with custom display name, icon, or launch options. Right-click an app and select 'Edit App' to customize.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                Column {
                    id: overridesList
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: appOverridesCard.overridesModel

                        delegate: Rectangle {
                            width: overridesList.width
                            height: 48
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.3)
                            border.width: 0

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingM

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
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: modelData.originalName !== modelData.name ? modelData.originalName : modelData.id
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }

                            DankActionButton {
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                iconName: "delete"
                                iconSize: 18
                                iconColor: Theme.error
                                onClicked: SessionData.clearAppOverride(modelData.id)
                            }
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: I18n.tr("No app customizations.")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        horizontalAlignment: Text.AlignHCenter
                        visible: appOverridesCard.overridesModel.length === 0
                    }
                }
            }

            SettingsCard {
                id: recentAppsCard
                width: parent.width
                iconName: "history"
                title: I18n.tr("Recently Used Apps")
                settingKey: "recentApps"
                collapsible: true
                expanded: false

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
                        text: I18n.tr("No apps have been launched yet.")
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
