import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: themeColorsTab

    property var cachedIconThemes: SettingsData.availableIconThemes
    property var cachedMatugenSchemes: Theme.availableMatugenSchemes.map(option => option.label)
    property var installedRegistryThemes: []

    Component.onCompleted: {
        SettingsData.detectAvailableIconThemes();
        if (DMSService.dmsAvailable)
            DMSService.listInstalledThemes();
        if (PopoutService.pendingThemeInstall)
            Qt.callLater(() => themeBrowser.show());
    }

    Connections {
        target: DMSService
        function onInstalledThemesReceived(themes) {
            themeColorsTab.installedRegistryThemes = themes;
        }
    }

    Connections {
        target: PopoutService
        function onPendingThemeInstallChanged() {
            if (PopoutService.pendingThemeInstall)
                themeBrowser.show();
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

            SettingsCard {
                tab: "theme"
                tags: ["color", "palette", "theme", "appearance"]
                title: I18n.tr("Theme Color")
                settingKey: "themeColor"
                iconName: "palette"

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        property string registryThemeName: {
                            if (Theme.currentThemeCategory !== "registry")
                                return "";
                            for (var i = 0; i < themeColorsTab.installedRegistryThemes.length; i++) {
                                var t = themeColorsTab.installedRegistryThemes[i];
                                if (SettingsData.customThemeFile && SettingsData.customThemeFile.endsWith((t.sourceDir || t.id) + "/theme.json"))
                                    return t.name;
                            }
                            return "";
                        }
                        text: {
                            if (Theme.currentTheme === Theme.dynamic)
                                return I18n.tr("Current Theme: %1", "current theme label").arg(I18n.tr("Dynamic", "dynamic theme name"));
                            if (Theme.currentThemeCategory === "registry" && registryThemeName)
                                return I18n.tr("Current Theme: %1", "current theme label").arg(registryThemeName);
                            return I18n.tr("Current Theme: %1", "current theme label").arg(Theme.getThemeColors(Theme.currentThemeName).name);
                        }
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: {
                            if (Theme.currentTheme === Theme.dynamic)
                                return I18n.tr("Material colors generated from wallpaper", "dynamic theme description");
                            if (Theme.currentThemeCategory === "registry")
                                return I18n.tr("Color theme from DMS registry", "registry theme description");
                            if (Theme.currentTheme === Theme.custom)
                                return I18n.tr("Custom theme loaded from JSON file", "custom theme description");
                            return I18n.tr("Material Design inspired color themes", "generic theme description");
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                        wrapMode: Text.WordWrap
                        width: Math.min(parent.width, 400)
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Column {
                    id: themeCategoryColumn
                    spacing: Theme.spacingM
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width

                    Item {
                        width: parent.width
                        height: themeCategoryGroup.implicitHeight
                        clip: true

                        DankButtonGroup {
                            id: themeCategoryGroup
                            anchors.horizontalCenter: parent.horizontalCenter
                            buttonPadding: parent.width < 420 ? Theme.spacingS : Theme.spacingL
                            minButtonWidth: parent.width < 420 ? 44 : 64
                            textSize: parent.width < 420 ? Theme.fontSizeSmall : Theme.fontSizeMedium
                            property bool isRegistryTheme: Theme.currentThemeCategory === "registry"
                            property int currentThemeIndex: {
                                if (isRegistryTheme)
                                    return 3;
                                if (Theme.currentTheme === Theme.dynamic)
                                    return 1;
                                if (Theme.currentThemeName === "custom")
                                    return 2;
                                return 0;
                            }
                            property int pendingThemeIndex: -1

                            model: DMSService.dmsAvailable ? ["Generic", "Auto", "Custom", "Browse"] : ["Generic", "Auto", "Custom"]
                            currentIndex: currentThemeIndex
                            selectionMode: "single"
                            onSelectionChanged: (index, selected) => {
                                if (!selected)
                                    return;
                                pendingThemeIndex = index;
                            }
                            onAnimationCompleted: {
                                if (pendingThemeIndex === -1)
                                    return;
                                switch (pendingThemeIndex) {
                                case 0:
                                    Theme.switchThemeCategory("generic", "blue");
                                    break;
                                case 1:
                                    if (ToastService.wallpaperErrorStatus === "matugen_missing")
                                        ToastService.showError(I18n.tr("matugen not found - install matugen package for dynamic theming", "matugen error"));
                                    else if (ToastService.wallpaperErrorStatus === "error")
                                        ToastService.showError(I18n.tr("Wallpaper processing failed - check wallpaper path", "wallpaper error"));
                                    else
                                        Theme.switchThemeCategory("dynamic", Theme.dynamic);
                                    break;
                                case 2:
                                    Theme.switchThemeCategory("custom", "custom");
                                    break;
                                case 3:
                                    Theme.switchThemeCategory("registry", "");
                                    break;
                                }
                                pendingThemeIndex = -1;
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: genericColorGrid.implicitHeight
                        visible: Theme.currentThemeCategory === "generic" && Theme.currentTheme !== Theme.dynamic && Theme.currentThemeName !== "custom"

                        Grid {
                            id: genericColorGrid
                            property var colorList: ["blue", "purple", "green", "orange", "red", "cyan", "pink", "amber", "coral", "monochrome"]
                            property int dotSize: parent.width < 300 ? 28 : 32
                            columns: Math.ceil(colorList.length / 2)
                            rowSpacing: Theme.spacingS
                            columnSpacing: Theme.spacingS
                            anchors.horizontalCenter: parent.horizontalCenter

                            Repeater {
                                model: genericColorGrid.colorList

                                Rectangle {
                                    required property string modelData
                                    property string themeName: modelData
                                    width: genericColorGrid.dotSize
                                    height: genericColorGrid.dotSize
                                    radius: width / 2
                                    color: Theme.getThemeColors(themeName).primary
                                    border.color: Theme.outline
                                    border.width: (Theme.currentThemeName === themeName && Theme.currentTheme !== Theme.dynamic) ? 2 : 1
                                    scale: (Theme.currentThemeName === themeName && Theme.currentTheme !== Theme.dynamic) ? 1.1 : 1

                                    Rectangle {
                                        width: nameText.contentWidth + Theme.spacingS * 2
                                        height: nameText.contentHeight + Theme.spacingXS * 2
                                        color: Theme.surfaceContainer
                                        radius: Theme.cornerRadius
                                        anchors.bottom: parent.top
                                        anchors.bottomMargin: Theme.spacingXS
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: mouseArea.containsMouse

                                        StyledText {
                                            id: nameText
                                            text: Theme.getThemeColors(parent.parent.themeName).name
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            anchors.centerIn: parent
                                        }
                                    }

                                    MouseArea {
                                        id: mouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Theme.switchTheme(parent.themeName)
                                    }

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Theme.emphasizedEasing
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: Theme.currentTheme === Theme.dynamic && Theme.currentThemeCategory !== "registry"

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            StyledRect {
                                width: 120
                                height: 90
                                radius: Theme.cornerRadius
                                color: Theme.surfaceVariant

                                CachingImage {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    source: Theme.wallpaperPath ? "file://" + Theme.wallpaperPath : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: Theme.wallpaperPath && !Theme.wallpaperPath.startsWith("#")
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: autoWallpaperMask
                                        maskThresholdMin: 0.5
                                        maskSpreadAtMin: 1
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: Theme.cornerRadius - 1
                                    color: Theme.wallpaperPath && Theme.wallpaperPath.startsWith("#") ? Theme.wallpaperPath : "transparent"
                                    visible: Theme.wallpaperPath && Theme.wallpaperPath.startsWith("#")
                                }

                                Rectangle {
                                    id: autoWallpaperMask
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: Theme.cornerRadius - 1
                                    color: "black"
                                    visible: false
                                    layer.enabled: true
                                }

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: (ToastService.wallpaperErrorStatus === "error" || ToastService.wallpaperErrorStatus === "matugen_missing") ? "error" : "palette"
                                    size: Theme.iconSizeLarge
                                    color: (ToastService.wallpaperErrorStatus === "error" || ToastService.wallpaperErrorStatus === "matugen_missing") ? Theme.error : Theme.surfaceVariantText
                                    visible: !Theme.wallpaperPath
                                }
                            }

                            Column {
                                width: parent.width - 120 - Theme.spacingM
                                spacing: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    text: {
                                        if (ToastService.wallpaperErrorStatus === "error")
                                            return I18n.tr("Wallpaper Error", "wallpaper error status");
                                        if (ToastService.wallpaperErrorStatus === "matugen_missing")
                                            return I18n.tr("Matugen Missing", "matugen not found status");
                                        if (Theme.wallpaperPath)
                                            return Theme.wallpaperPath.split('/').pop();
                                        return I18n.tr("No wallpaper selected", "no wallpaper status");
                                    }
                                    font.pixelSize: Theme.fontSizeLarge
                                    color: Theme.surfaceText
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 1
                                    width: parent.width
                                }

                                StyledText {
                                    text: {
                                        if (ToastService.wallpaperErrorStatus === "error")
                                            return I18n.tr("Wallpaper processing failed", "wallpaper processing error");
                                        if (ToastService.wallpaperErrorStatus === "matugen_missing")
                                            return I18n.tr("Install matugen package for dynamic theming", "matugen installation hint");
                                        if (Theme.wallpaperPath)
                                            return Theme.wallpaperPath;
                                        return I18n.tr("Dynamic colors from wallpaper", "dynamic colors description");
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: (ToastService.wallpaperErrorStatus === "error" || ToastService.wallpaperErrorStatus === "matugen_missing") ? Theme.error : Theme.surfaceVariantText
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 2
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        SettingsDropdownRow {
                            tab: "theme"
                            tags: ["matugen", "palette", "algorithm", "dynamic"]
                            settingKey: "matugenScheme"
                            text: I18n.tr("Matugen Palette")
                            description: I18n.tr("Select the palette algorithm used for wallpaper-based colors")
                            options: cachedMatugenSchemes
                            currentValue: Theme.getMatugenScheme(SettingsData.matugenScheme).label
                            enabled: Theme.matugenAvailable
                            opacity: enabled ? 1 : 0.4
                            onValueChanged: value => {
                                for (var i = 0; i < Theme.availableMatugenSchemes.length; i++) {
                                    var option = Theme.availableMatugenSchemes[i];
                                    if (option.label === value) {
                                        SettingsData.setMatugenScheme(option.value);
                                        break;
                                    }
                                }
                            }
                        }

                        StyledText {
                            text: {
                                var scheme = Theme.getMatugenScheme(SettingsData.matugenScheme);
                                return scheme.description + " (" + scheme.value + ")";
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: Theme.currentThemeName === "custom" && Theme.currentThemeCategory !== "registry"

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            DankActionButton {
                                buttonSize: 48
                                iconName: "folder_open"
                                iconSize: Theme.iconSize
                                backgroundColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                iconColor: Theme.primary
                                onClicked: fileBrowserModal.open()
                            }

                            Column {
                                width: parent.width - 48 - Theme.spacingM
                                spacing: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    text: SettingsData.customThemeFile ? SettingsData.customThemeFile.split('/').pop() : I18n.tr("No custom theme file", "no custom theme file status")
                                    font.pixelSize: Theme.fontSizeLarge
                                    color: Theme.surfaceText
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 1
                                    width: parent.width
                                }

                                StyledText {
                                    text: SettingsData.customThemeFile || I18n.tr("Click to select a custom theme JSON file", "custom theme file hint")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 1
                                    width: parent.width
                                }
                            }
                        }
                    }

                    Column {
                        id: registrySection
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: Theme.currentThemeCategory === "registry"

                        Grid {
                            id: themeGrid
                            property int cardWidth: registrySection.width < 350 ? 100 : 140
                            property int cardHeight: registrySection.width < 350 ? 72 : 100
                            columns: Math.max(1, Math.floor((registrySection.width + spacing) / (cardWidth + spacing)))
                            spacing: Theme.spacingS
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: themeColorsTab.installedRegistryThemes.length > 0

                            Repeater {
                                model: themeColorsTab.installedRegistryThemes

                                Rectangle {
                                    id: themeCard
                                    property bool isActive: Theme.currentThemeCategory === "registry" && Theme.currentThemeName === "custom" && SettingsData.customThemeFile && SettingsData.customThemeFile.endsWith((modelData.sourceDir || modelData.id) + "/theme.json")
                                    property bool hasVariants: modelData.hasVariants || false
                                    property var variants: modelData.variants || null
                                    property string selectedVariant: hasVariants ? SettingsData.getRegistryThemeVariant(modelData.id, variants?.default || "") : ""
                                    property string previewPath: {
                                        const baseDir = Quickshell.env("HOME") + "/.config/DankMaterialShell/themes/" + (modelData.sourceDir || modelData.id);
                                        const mode = Theme.isLightMode ? "light" : "dark";
                                        if (hasVariants && selectedVariant)
                                            return baseDir + "/preview-" + selectedVariant + "-" + mode + ".svg";
                                        return baseDir + "/preview-" + mode + ".svg";
                                    }
                                    width: themeGrid.cardWidth
                                    height: themeGrid.cardHeight
                                    radius: Theme.cornerRadius
                                    color: Theme.surfaceVariant
                                    border.color: isActive ? Theme.primary : Theme.outline
                                    border.width: isActive ? 2 : 1
                                    scale: isActive ? 1.03 : 1

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Theme.emphasizedEasing
                                        }
                                    }

                                    Image {
                                        id: previewImage
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        source: "file://" + themeCard.previewPath
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        mipmap: true
                                    }

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "palette"
                                        size: themeGrid.cardWidth < 120 ? 24 : 32
                                        color: Theme.primary
                                        visible: previewImage.status === Image.Error || previewImage.status === Image.Null
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: themeGrid.cardWidth < 120 ? 18 : 22
                                        radius: Theme.cornerRadius
                                        color: Qt.rgba(0, 0, 0, 0.6)

                                        StyledText {
                                            anchors.centerIn: parent
                                            text: modelData.name
                                            font.pixelSize: themeGrid.cardWidth < 120 ? Theme.fontSizeSmall - 2 : Theme.fontSizeSmall
                                            color: "white"
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            width: parent.width - Theme.spacingXS * 2
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: themeGrid.cardWidth < 120 ? 2 : 4
                                        width: themeGrid.cardWidth < 120 ? 16 : 20
                                        height: width
                                        radius: width / 2
                                        color: Theme.primary
                                        visible: themeCard.isActive

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "check"
                                            size: themeGrid.cardWidth < 120 ? 10 : 14
                                            color: Theme.surface
                                        }
                                    }

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.margins: themeGrid.cardWidth < 120 ? 2 : 4
                                        width: themeGrid.cardWidth < 120 ? 16 : 20
                                        height: width
                                        radius: width / 2
                                        color: Theme.secondary
                                        visible: themeCard.hasVariants && !deleteButton.visible

                                        StyledText {
                                            anchors.centerIn: parent
                                            text: {
                                                if (themeCard.variants?.type === "multi")
                                                    return themeCard.variants?.accents?.length || 0;
                                                return themeCard.variants?.options?.length || 0;
                                            }
                                            font.pixelSize: themeGrid.cardWidth < 120 ? Theme.fontSizeSmall - 4 : Theme.fontSizeSmall - 2
                                            color: Theme.surface
                                            font.weight: Font.Bold
                                        }
                                    }

                                    MouseArea {
                                        id: cardMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const themesDir = Quickshell.env("HOME") + "/.config/DankMaterialShell/themes";
                                            const themePath = themesDir + "/" + (modelData.sourceDir || modelData.id) + "/theme.json";
                                            SettingsData.set("customThemeFile", themePath);
                                            Theme.switchTheme("custom", true, true);
                                        }
                                    }

                                    Rectangle {
                                        id: deleteButton
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.margins: themeGrid.cardWidth < 120 ? 2 : 4
                                        width: themeGrid.cardWidth < 120 ? 18 : 24
                                        height: width
                                        radius: width / 2
                                        color: deleteMouseArea.containsMouse ? Theme.error : Qt.rgba(0, 0, 0, 0.6)
                                        opacity: cardMouseArea.containsMouse || deleteMouseArea.containsMouse ? 1 : 0
                                        visible: opacity > 0

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Theme.shortDuration
                                            }
                                        }

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "close"
                                            size: themeGrid.cardWidth < 120 ? 10 : 14
                                            color: "white"
                                        }

                                        MouseArea {
                                            id: deleteMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                ToastService.showInfo(I18n.tr("Uninstalling: %1", "uninstallation progress").arg(modelData.name));
                                                DMSService.uninstallTheme(modelData.id, response => {
                                                    if (response.error) {
                                                        ToastService.showError(I18n.tr("Uninstall failed: %1", "uninstallation error").arg(response.error));
                                                        return;
                                                    }
                                                    ToastService.showInfo(I18n.tr("Uninstalled: %1", "uninstallation success").arg(modelData.name));
                                                    DMSService.listInstalledThemes();
                                                });
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            id: variantSelector
                            width: parent.width
                            spacing: Theme.spacingS
                            visible: activeThemeId !== "" && activeThemeVariants !== null && (isMultiVariant || (activeThemeVariants.options && activeThemeVariants.options.length > 0))

                            property string activeThemeId: {
                                if (Theme.currentThemeCategory !== "registry" || Theme.currentTheme !== "custom")
                                    return "";
                                for (var i = 0; i < themeColorsTab.installedRegistryThemes.length; i++) {
                                    var t = themeColorsTab.installedRegistryThemes[i];
                                    if (SettingsData.customThemeFile && SettingsData.customThemeFile.endsWith((t.sourceDir || t.id) + "/theme.json"))
                                        return t.id;
                                }
                                return "";
                            }
                            property var activeThemeVariants: {
                                if (!activeThemeId)
                                    return null;
                                for (var i = 0; i < themeColorsTab.installedRegistryThemes.length; i++) {
                                    var t = themeColorsTab.installedRegistryThemes[i];
                                    if (t.id === activeThemeId && t.hasVariants)
                                        return t.variants;
                                }
                                return null;
                            }
                            property bool isMultiVariant: activeThemeVariants?.type === "multi"
                            property string colorMode: Theme.isLightMode ? "light" : "dark"
                            property var multiDefaults: {
                                if (!isMultiVariant || !activeThemeVariants?.defaults)
                                    return {};
                                return activeThemeVariants.defaults[colorMode] || activeThemeVariants.defaults.dark || {};
                            }
                            property var storedMulti: activeThemeId ? SettingsData.getRegistryThemeMultiVariant(activeThemeId, multiDefaults) : multiDefaults
                            property string selectedFlavor: storedMulti.flavor || multiDefaults.flavor || ""
                            property string selectedAccent: storedMulti.accent || multiDefaults.accent || ""
                            property var flavorOptions: {
                                if (!isMultiVariant || !activeThemeVariants?.flavors)
                                    return [];
                                return activeThemeVariants.flavors.filter(f => f.mode === colorMode || f.mode === "both");
                            }
                            property var flavorNames: flavorOptions.map(f => f.name)
                            property int flavorIndex: {
                                for (var i = 0; i < flavorOptions.length; i++) {
                                    if (flavorOptions[i].id === selectedFlavor)
                                        return i;
                                }
                                return 0;
                            }
                            property string selectedVariant: activeThemeId ? SettingsData.getRegistryThemeVariant(activeThemeId, activeThemeVariants?.default || "") : ""
                            property var variantNames: {
                                if (!activeThemeVariants?.options)
                                    return [];
                                return activeThemeVariants.options.map(v => v.name);
                            }
                            property int selectedIndex: {
                                if (!activeThemeVariants?.options || !selectedVariant)
                                    return 0;
                                for (var i = 0; i < activeThemeVariants.options.length; i++) {
                                    if (activeThemeVariants.options[i].id === selectedVariant)
                                        return i;
                                }
                                return 0;
                            }

                            Item {
                                width: parent.width
                                height: flavorButtonGroup.implicitHeight
                                clip: true
                                visible: variantSelector.isMultiVariant && variantSelector.flavorOptions.length > 1

                                DankButtonGroup {
                                    id: flavorButtonGroup
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    buttonPadding: parent.width < 400 ? Theme.spacingS : Theme.spacingL
                                    minButtonWidth: parent.width < 400 ? 44 : 64
                                    textSize: parent.width < 400 ? Theme.fontSizeSmall : Theme.fontSizeMedium
                                    model: variantSelector.flavorNames
                                    currentIndex: variantSelector.flavorIndex
                                    selectionMode: "single"
                                    onAnimationCompleted: {
                                        if (currentIndex < 0 || currentIndex >= variantSelector.flavorOptions.length)
                                            return;
                                        const flavorId = variantSelector.flavorOptions[currentIndex]?.id;
                                        if (!flavorId || flavorId === variantSelector.selectedFlavor)
                                            return;
                                        Theme.screenTransition();
                                        SettingsData.setRegistryThemeMultiVariant(variantSelector.activeThemeId, flavorId, variantSelector.selectedAccent);
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: accentColorsGrid.implicitHeight
                                visible: variantSelector.isMultiVariant && variantSelector.activeThemeVariants?.accents?.length > 0

                                Grid {
                                    id: accentColorsGrid
                                    property int accentCount: variantSelector.activeThemeVariants?.accents?.length ?? 0
                                    property int dotSize: parent.width < 300 ? 28 : 32
                                    columns: accentCount > 0 ? Math.ceil(accentCount / 2) : 1
                                    rowSpacing: Theme.spacingS
                                    columnSpacing: Theme.spacingS
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    Repeater {
                                        model: variantSelector.activeThemeVariants?.accents || []

                                        Rectangle {
                                            required property var modelData
                                            required property int index
                                            property string accentId: modelData.id
                                            property bool isSelected: accentId === variantSelector.selectedAccent
                                            width: accentColorsGrid.dotSize
                                            height: accentColorsGrid.dotSize
                                            radius: width / 2
                                            color: modelData.color || Theme.primary
                                            border.color: Theme.outline
                                            border.width: isSelected ? 2 : 1
                                            scale: isSelected ? 1.1 : 1

                                            Rectangle {
                                                width: accentNameText.contentWidth + Theme.spacingS * 2
                                                height: accentNameText.contentHeight + Theme.spacingXS * 2
                                                color: Theme.surfaceContainer
                                                radius: Theme.cornerRadius
                                                anchors.bottom: parent.top
                                                anchors.bottomMargin: Theme.spacingXS
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                visible: accentMouseArea.containsMouse

                                                StyledText {
                                                    id: accentNameText
                                                    text: modelData.name
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    color: Theme.surfaceText
                                                    anchors.centerIn: parent
                                                }
                                            }

                                            MouseArea {
                                                id: accentMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (parent.isSelected)
                                                        return;
                                                    Theme.screenTransition();
                                                    SettingsData.setRegistryThemeMultiVariant(variantSelector.activeThemeId, variantSelector.selectedFlavor, parent.accentId);
                                                }
                                            }

                                            Behavior on scale {
                                                NumberAnimation {
                                                    duration: Theme.shortDuration
                                                    easing.type: Theme.emphasizedEasing
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: variantButtonGroup.implicitHeight
                                clip: true
                                visible: !variantSelector.isMultiVariant && variantSelector.variantNames.length > 0

                                DankButtonGroup {
                                    id: variantButtonGroup
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    buttonPadding: parent.width < 400 ? Theme.spacingS : Theme.spacingL
                                    minButtonWidth: parent.width < 400 ? 44 : 64
                                    textSize: parent.width < 400 ? Theme.fontSizeSmall : Theme.fontSizeMedium
                                    model: variantSelector.variantNames
                                    currentIndex: variantSelector.selectedIndex
                                    selectionMode: "single"
                                    onAnimationCompleted: {
                                        if (currentIndex < 0 || !variantSelector.activeThemeVariants?.options)
                                            return;
                                        const variantId = variantSelector.activeThemeVariants.options[currentIndex]?.id;
                                        if (!variantId || variantId === variantSelector.selectedVariant)
                                            return;
                                        Theme.screenTransition();
                                        SettingsData.setRegistryThemeVariant(variantSelector.activeThemeId, variantId);
                                    }
                                }
                            }
                        }

                        StyledText {
                            text: I18n.tr("No themes installed. Browse themes to install from the registry.", "no registry themes installed hint")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            width: parent.width
                            visible: themeColorsTab.installedRegistryThemes.length === 0
                            horizontalAlignment: Text.AlignHCenter
                        }

                        DankButton {
                            text: I18n.tr("Browse Themes", "browse themes button")
                            iconName: "store"
                            anchors.horizontalCenter: parent.horizontalCenter
                            onClicked: themeBrowser.show()
                        }
                    }
                }
            }

            SettingsCard {
                tab: "theme"
                tags: ["light", "dark", "mode", "appearance"]
                title: I18n.tr("Color Mode")
                settingKey: "colorMode"
                iconName: "contrast"

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["light", "dark", "mode"]
                    settingKey: "isLightMode"
                    text: I18n.tr("Light Mode")
                    description: I18n.tr("Use light theme instead of dark theme")
                    checked: SessionData.isLightMode
                    onToggled: checked => {
                        Theme.screenTransition();
                        Theme.setLightMode(checked);
                    }
                }
            }

            SettingsCard {
                tab: "theme"
                tags: ["transparency", "opacity", "widget", "styling"]
                title: I18n.tr("Widget Styling")
                settingKey: "widgetStyling"
                iconName: "opacity"

                SettingsButtonGroupRow {
                    tab: "theme"
                    tags: ["widget", "style", "colorful", "default"]
                    settingKey: "widgetColorMode"
                    text: I18n.tr("Widget Style")
                    description: I18n.tr("Change bar appearance")
                    model: ["default", "colorful"]
                    currentIndex: SettingsData.widgetColorMode === "colorful" ? 1 : 0
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        SettingsData.set("widgetColorMode", index === 1 ? "colorful" : "default");
                    }
                }

                SettingsButtonGroupRow {
                    tab: "theme"
                    tags: ["widget", "background", "color"]
                    settingKey: "widgetBackgroundColor"
                    text: I18n.tr("Widget Background Color")
                    description: I18n.tr("Choose the background color for widgets")
                    model: ["sth", "s", "sc", "sch"]
                    buttonHeight: 20
                    minButtonWidth: 32
                    buttonPadding: Theme.spacingS
                    checkIconSize: Theme.iconSizeSmall - 2
                    textSize: Theme.fontSizeSmall - 2
                    spacing: 1
                    currentIndex: {
                        switch (SettingsData.widgetBackgroundColor) {
                        case "sth":
                            return 0;
                        case "s":
                            return 1;
                        case "sc":
                            return 2;
                        case "sch":
                            return 3;
                        default:
                            return 0;
                        }
                    }
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        const colorOptions = ["sth", "s", "sc", "sch"];
                        SettingsData.set("widgetBackgroundColor", colorOptions[index]);
                    }
                }

                SettingsSliderRow {
                    tab: "theme"
                    tags: ["popup", "transparency", "opacity", "modal"]
                    settingKey: "popupTransparency"
                    text: I18n.tr("Popup Transparency")
                    description: I18n.tr("Controls opacity of all popouts, modals, and their content layers")
                    value: Math.round(SettingsData.popupTransparency * 100)
                    minimum: 0
                    maximum: 100
                    unit: "%"
                    defaultValue: 100
                    onSliderValueChanged: newValue => SettingsData.set("popupTransparency", newValue / 100)
                }

                SettingsSliderRow {
                    tab: "theme"
                    tags: ["corner", "radius", "rounded", "square"]
                    settingKey: "cornerRadius"
                    text: I18n.tr("Corner Radius")
                    description: I18n.tr("0 = square corners")
                    value: SettingsData.cornerRadius
                    minimum: 0
                    maximum: 32
                    unit: "px"
                    defaultValue: 12
                    onSliderValueChanged: newValue => SettingsData.setCornerRadius(newValue)
                }
            }

            SettingsCard {
                tab: "theme"
                tags: ["niri", "layout", "gaps", "radius", "window"]
                title: I18n.tr("Niri Layout Overrides")
                settingKey: "niriLayout"
                iconName: "crop_square"
                visible: CompositorService.isNiri

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["niri", "gaps", "override"]
                    settingKey: "niriLayoutGapsOverrideEnabled"
                    text: I18n.tr("Override Gaps")
                    description: I18n.tr("Use custom gaps instead of bar spacing")
                    checked: SettingsData.niriLayoutGapsOverride >= 0
                    onToggled: checked => {
                        if (checked) {
                            const currentGaps = Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4));
                            SettingsData.set("niriLayoutGapsOverride", currentGaps);
                            return;
                        }
                        SettingsData.set("niriLayoutGapsOverride", -1);
                    }
                }

                SettingsSliderRow {
                    tab: "theme"
                    tags: ["niri", "gaps", "override"]
                    settingKey: "niriLayoutGapsOverride"
                    text: I18n.tr("Window Gaps")
                    description: I18n.tr("Space between windows")
                    visible: SettingsData.niriLayoutGapsOverride >= 0
                    value: Math.max(0, SettingsData.niriLayoutGapsOverride)
                    minimum: 0
                    maximum: 50
                    unit: "px"
                    defaultValue: Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4))
                    onSliderValueChanged: newValue => SettingsData.set("niriLayoutGapsOverride", newValue)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["niri", "radius", "override"]
                    settingKey: "niriLayoutRadiusOverrideEnabled"
                    text: I18n.tr("Override Corner Radius")
                    description: I18n.tr("Use custom window radius instead of theme radius")
                    checked: SettingsData.niriLayoutRadiusOverride >= 0
                    onToggled: checked => {
                        if (checked) {
                            SettingsData.set("niriLayoutRadiusOverride", SettingsData.cornerRadius);
                            return;
                        }
                        SettingsData.set("niriLayoutRadiusOverride", -1);
                    }
                }

                SettingsSliderRow {
                    tab: "theme"
                    tags: ["niri", "radius", "override"]
                    settingKey: "niriLayoutRadiusOverride"
                    text: I18n.tr("Window Corner Radius")
                    description: I18n.tr("Rounded corners for windows")
                    visible: SettingsData.niriLayoutRadiusOverride >= 0
                    value: Math.max(0, SettingsData.niriLayoutRadiusOverride)
                    minimum: 0
                    maximum: 100
                    unit: "px"
                    defaultValue: SettingsData.cornerRadius
                    onSliderValueChanged: newValue => SettingsData.set("niriLayoutRadiusOverride", newValue)
                }
            }

            SettingsCard {
                tab: "theme"
                tags: ["modal", "darken", "background", "overlay"]
                title: I18n.tr("Modal Background")
                settingKey: "modalBackground"

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["modal", "darken", "background", "overlay"]
                    settingKey: "modalDarkenBackground"
                    text: I18n.tr("Darken Modal Background")
                    description: I18n.tr("Show darkened overlay behind modal dialogs")
                    checked: SettingsData.modalDarkenBackground
                    onToggled: checked => SettingsData.set("modalDarkenBackground", checked)
                }
            }

            SettingsCard {
                tab: "theme"
                tags: ["applications", "portal", "dark", "terminal"]
                title: I18n.tr("Applications")
                settingKey: "applications"
                iconName: "terminal"

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["portal", "sync", "dark", "mode"]
                    settingKey: "syncModeWithPortal"
                    text: I18n.tr("Sync Mode with Portal")
                    description: I18n.tr("Sync dark mode with settings portals for system-wide theme hints")
                    checked: SettingsData.syncModeWithPortal
                    onToggled: checked => SettingsData.set("syncModeWithPortal", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["terminal", "dark", "always"]
                    settingKey: "terminalsAlwaysDark"
                    text: I18n.tr("Terminals - Always use Dark Theme")
                    description: I18n.tr("Force terminal applications to always use dark color schemes")
                    checked: SettingsData.terminalsAlwaysDark
                    onToggled: checked => SettingsData.set("terminalsAlwaysDark", checked)
                }
            }

            SettingsCard {
                tab: "theme"
                tags: ["matugen", "templates", "theming"]
                title: I18n.tr("Matugen Templates")
                settingKey: "matugenTemplates"
                iconName: "auto_awesome"
                visible: Theme.matugenAvailable

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "user", "templates"]
                    settingKey: "runUserMatugenTemplates"
                    text: I18n.tr("Run User Templates")
                    description: ""
                    checked: SettingsData.runUserMatugenTemplates
                    onToggled: checked => SettingsData.set("runUserMatugenTemplates", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "dms", "templates"]
                    settingKey: "runDmsMatugenTemplates"
                    text: I18n.tr("Run DMS Templates")
                    description: ""
                    checked: SettingsData.runDmsMatugenTemplates
                    onToggled: checked => SettingsData.set("runDmsMatugenTemplates", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "gtk", "template"]
                    settingKey: "matugenTemplateGtk"
                    text: "GTK"
                    description: ""
                    visible: SettingsData.runDmsMatugenTemplates
                    checked: SettingsData.matugenTemplateGtk
                    onToggled: checked => SettingsData.set("matugenTemplateGtk", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "niri", "template"]
                    settingKey: "matugenTemplateNiri"
                    text: "niri"
                    description: ""
                    visible: SettingsData.runDmsMatugenTemplates
                    checked: SettingsData.matugenTemplateNiri
                    onToggled: checked => SettingsData.set("matugenTemplateNiri", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "qt5ct", "template"]
                    settingKey: "matugenTemplateQt5ct"
                    text: "qt5ct"
                    description: ""
                    visible: SettingsData.runDmsMatugenTemplates
                    checked: SettingsData.matugenTemplateQt5ct
                    onToggled: checked => SettingsData.set("matugenTemplateQt5ct", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "qt6ct", "template"]
                    settingKey: "matugenTemplateQt6ct"
                    text: "qt6ct"
                    description: ""
                    visible: SettingsData.runDmsMatugenTemplates
                    checked: SettingsData.matugenTemplateQt6ct
                    onToggled: checked => SettingsData.set("matugenTemplateQt6ct", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "firefox", "template"]
                    settingKey: "matugenTemplateFirefox"
                    text: "Firefox"
                    description: ""
                    visible: SettingsData.runDmsMatugenTemplates
                    checked: SettingsData.matugenTemplateFirefox
                    onToggled: checked => SettingsData.set("matugenTemplateFirefox", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "pywalfox", "template"]
                    settingKey: "matugenTemplatePywalfox"
                    text: "pywalfox"
                    description: ""
                    visible: SettingsData.runDmsMatugenTemplates
                    checked: SettingsData.matugenTemplatePywalfox
                    onToggled: checked => SettingsData.set("matugenTemplatePywalfox", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "zenbrowser", "template"]
                    settingKey: "matugenTemplateZenBrowser"
                    text: "zenbrowser"
                    description: ""
                    visible: SettingsData.runDmsMatugenTemplates
                    checked: SettingsData.matugenTemplateZenBrowser
                    onToggled: checked => SettingsData.set("matugenTemplateZenBrowser", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "vesktop", "discord", "template"]
                    settingKey: "matugenTemplateVesktop"
                    text: "vesktop"
                    description: ""
                    visible: SettingsData.runDmsMatugenTemplates
                    checked: SettingsData.matugenTemplateVesktop
                    onToggled: checked => SettingsData.set("matugenTemplateVesktop", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "equibop", "discord", "template"]
                    settingKey: "matugenTemplateEquibop"
                    text: "equibop"
                    description: ""
                    visible: SettingsData.runDmsMatugenTemplates
                    checked: SettingsData.matugenTemplateEquibop
                    onToggled: checked => SettingsData.set("matugenTemplateEquibop", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "ghostty", "terminal", "template"]
                    settingKey: "matugenTemplateGhostty"
                    text: "Ghostty"
                    description: ""
                    visible: SettingsData.runDmsMatugenTemplates
                    checked: SettingsData.matugenTemplateGhostty
                    onToggled: checked => SettingsData.set("matugenTemplateGhostty", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "kitty", "terminal", "template"]
                    settingKey: "matugenTemplateKitty"
                    text: "kitty"
                    description: ""
                    visible: SettingsData.runDmsMatugenTemplates
                    checked: SettingsData.matugenTemplateKitty
                    onToggled: checked => SettingsData.set("matugenTemplateKitty", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "foot", "terminal", "template"]
                    settingKey: "matugenTemplateFoot"
                    text: "foot"
                    description: ""
                    visible: SettingsData.runDmsMatugenTemplates
                    checked: SettingsData.matugenTemplateFoot
                    onToggled: checked => SettingsData.set("matugenTemplateFoot", checked)
                }
                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "neovim", "terminal", "template"]
                    settingKey: "matugenTemplateNeovim"
                    text: "neovim"
                    description: "Requires lazy plugin manager"
                    visible: SettingsData.runDmsMatugenTemplates
                    checked: SettingsData.matugenTemplateNeovim
                    onToggled: checked => SettingsData.set("matugenTemplateNeovim", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "alacritty", "terminal", "template"]
                    settingKey: "matugenTemplateAlacritty"
                    text: "Alacritty"
                    description: ""
                    visible: SettingsData.runDmsMatugenTemplates
                    checked: SettingsData.matugenTemplateAlacritty
                    onToggled: checked => SettingsData.set("matugenTemplateAlacritty", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "wezterm", "terminal", "template"]
                    settingKey: "matugenTemplateWezterm"
                    text: "WezTerm"
                    description: ""
                    visible: SettingsData.runDmsMatugenTemplates
                    checked: SettingsData.matugenTemplateWezterm
                    onToggled: checked => SettingsData.set("matugenTemplateWezterm", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "dgop", "template"]
                    settingKey: "matugenTemplateDgop"
                    text: "dgop"
                    description: ""
                    visible: SettingsData.runDmsMatugenTemplates
                    checked: SettingsData.matugenTemplateDgop
                    onToggled: checked => SettingsData.set("matugenTemplateDgop", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "kcolorscheme", "kde", "template"]
                    settingKey: "matugenTemplateKcolorscheme"
                    text: "KColorScheme"
                    description: ""
                    visible: SettingsData.runDmsMatugenTemplates
                    checked: SettingsData.matugenTemplateKcolorscheme
                    onToggled: checked => SettingsData.set("matugenTemplateKcolorscheme", checked)
                }

                SettingsToggleRow {
                    tab: "theme"
                    tags: ["matugen", "vscode", "code", "template"]
                    settingKey: "matugenTemplateVscode"
                    text: "VS Code"
                    description: ""
                    visible: SettingsData.runDmsMatugenTemplates
                    checked: SettingsData.matugenTemplateVscode
                    onToggled: checked => SettingsData.set("matugenTemplateVscode", checked)
                }
            }

            Rectangle {
                width: parent.width
                height: warningText.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)

                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "info"
                        size: Theme.iconSizeSmall
                        color: Theme.warning
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        id: warningText
                        font.pixelSize: Theme.fontSizeSmall
                        text: I18n.tr("The below settings will modify your GTK and Qt settings. If you wish to preserve your current configurations, please back them up (qt5ct.conf|qt6ct.conf and ~/.config/gtk-3.0|gtk-4.0).")
                        wrapMode: Text.WordWrap
                        width: parent.width - Theme.iconSizeSmall - Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            SettingsCard {
                tab: "theme"
                tags: ["icon", "theme", "system"]
                title: I18n.tr("Icon Theme")
                settingKey: "iconTheme"

                SettingsDropdownRow {
                    tab: "theme"
                    tags: ["icon", "theme", "system"]
                    settingKey: "iconTheme"
                    text: I18n.tr("Icon Theme")
                    description: I18n.tr("DankShell & System Icons (requires restart)")
                    currentValue: SettingsData.iconTheme
                    enableFuzzySearch: true
                    popupWidthOffset: 100
                    maxPopupHeight: 236
                    options: cachedIconThemes
                    onValueChanged: value => {
                        SettingsData.setIconTheme(value);
                        if (Quickshell.env("QT_QPA_PLATFORMTHEME") != "gtk3" && Quickshell.env("QT_QPA_PLATFORMTHEME") != "qt6ct" && Quickshell.env("QT_QPA_PLATFORMTHEME_QT6") != "qt6ct") {
                            ToastService.showError("Missing Environment Variables", "You need to set either:\nQT_QPA_PLATFORMTHEME=gtk3 OR\nQT_QPA_PLATFORMTHEME=qt6ct\nas environment variables, and then restart the shell.\n\nqt6ct requires qt6ct-kde to be installed.");
                        }
                    }
                }
            }

            SettingsCard {
                tab: "theme"
                tags: ["system", "app", "theming", "gtk", "qt"]
                title: I18n.tr("System App Theming")
                settingKey: "systemAppTheming"
                iconName: "extension"
                visible: Theme.matugenAvailable

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    Rectangle {
                        width: (parent.width - Theme.spacingM) / 2
                        height: 48
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "folder"
                                size: 16
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: I18n.tr("Apply GTK Colors")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.primary
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Theme.applyGtkColors()
                        }
                    }

                    Rectangle {
                        width: (parent.width - Theme.spacingM) / 2
                        height: 48
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "settings"
                                size: 16
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: I18n.tr("Apply Qt Colors")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.primary
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Theme.applyQtColors()
                        }
                    }
                }

                StyledText {
                    text: I18n.tr(`Generate baseline GTK3/4 or QT5/QT6 (requires qt6ct-kde) configurations to follow DMS colors. Only needed once.<br /><br />It is recommended to configure <a href="https://github.com/AvengeMedia/DankMaterialShell/blob/master/README.md#Theming" style="text-decoration:none; color:${Theme.primary};">adw-gtk3</a> prior to applying GTK themes.`)
                    textFormat: Text.RichText
                    linkColor: Theme.primary
                    onLinkActivated: url => Qt.openUrlExternally(url)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                        acceptedButtons: Qt.NoButton
                        propagateComposedEvents: true
                    }
                }
            }
        }
    }

    FileBrowserModal {
        id: fileBrowserModal
        browserTitle: I18n.tr("Select Custom Theme", "custom theme file browser title")
        filterExtensions: ["*.json"]
        showHiddenFiles: true

        function selectCustomTheme() {
            shouldBeVisible = true;
        }

        onFileSelected: function (filePath) {
            if (filePath.endsWith(".json")) {
                SettingsData.set("customThemeFile", filePath);
                Theme.switchTheme("custom");
                close();
            }
        }
    }

    ThemeBrowser {
        id: themeBrowser
    }
}
