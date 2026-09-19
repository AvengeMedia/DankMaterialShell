import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets
import "../../Common/ThemePalette.js" as ThemePalette

Item {
    id: themeColorsTab

    property var parentModal: null
    property string pendingExtractJson: ""
    property var cachedSourceModes: Theme.availableSourceModes.map(option => option.label)
    property var matugenSchemePreviews: ({})
    property string matugenPreviewRequestKey: ""
    property string matugenPreviewLoadedKey: ""
    readonly property string matugenPreviewSource: SettingsData.matugenSeedColor || Theme.getMatugenColor("source_color", Theme.primary).toString()
    readonly property string matugenPreviewImage: (!SettingsData.matugenSeedColor && Theme.rawWallpaperPath && !Theme.rawWallpaperPath.startsWith("#")) ? Theme.rawWallpaperPath : ""
    readonly property string matugenPreviewKey: matugenPreviewSource + "|" + (SettingsData.matugenContrast ?? 0) + "|" + matugenPreviewImage + "|" + SettingsData.matugenSpec
    property bool matugenGenerating: false
    readonly property var currentPalette: ThemePalette.pick({
        "primary": Theme.primary,
        "secondary": Theme.secondary,
        "tertiary": Theme.tertiary,
        "primaryContainer": Theme.primaryContainer,
        "info": Theme.info,
        "error": Theme.error,
        "warning": Theme.warning
    })
    property bool matugenPreviewFailed: false
    readonly property bool matugenPreviewsReady: !matugenGenerating && (matugenPreviewLoadedKey === matugenPreviewKey || matugenPreviewFailed || !Theme.matugenAvailable)
    onMatugenPreviewKeyChanged: refreshMatugenSchemePreviews()
    property var installedRegistryThemes: []
    readonly property var matugenSchemeOptions: {
        const mode = SessionData.isLightMode ? "light" : "dark";
        const options = [];
        for (const option of Theme.availableMatugenSchemes) {
            if (option.value === "scheme-smart" && !DMSService.matugenSmartSupported)
                continue;
            const colors = (matugenSchemePreviews[option.value] ?? matugenSchemePreviews["scheme-tonal-spot"])?.[mode];
            // a dms binary older than the tri-color preview returns the primary hex as a plain string
            const primary = typeof colors === "string" ? colors : (colors?.primary ?? Theme.primary.toString());
            options.push({
                "value": option.value,
                "label": option.label,
                "primary": primary,
                "secondary": colors?.secondary ?? primary,
                "tertiary": colors?.tertiary ?? primary
            });
        }
        return options;
    }

    function refreshMatugenSchemePreviews() {
        if (!Theme.matugenAvailable)
            return;
        const requestKey = matugenPreviewKey;
        if (requestKey === matugenPreviewLoadedKey || requestKey === matugenPreviewRequestKey)
            return;
        matugenPreviewRequestKey = requestKey;
        matugenPreviewFailed = false;

        const args = [Proc.dmsBin, "matugen", "preview", "--source-color", matugenPreviewSource, "--contrast", String(SettingsData.matugenContrast ?? 0)];
        if (matugenPreviewImage)
            args.push("--image", matugenPreviewImage);
        if (SettingsData.matugenSpec === "2025")
            args.push("--spec", "2025");
        Proc.runCommand("", args, (output, exitCode) => {
            if (requestKey !== themeColorsTab.matugenPreviewRequestKey)
                return;
            themeColorsTab.matugenPreviewRequestKey = "";
            if (exitCode !== 0) {
                themeColorsTab.matugenPreviewFailed = true;
                return;
            }
            try {
                themeColorsTab.matugenSchemePreviews = JSON.parse(output.trim());
                themeColorsTab.matugenPreviewLoadedKey = requestKey;
            } catch (e) {
                themeColorsTab.matugenPreviewFailed = true;
            }
        });
    }

    Component.onCompleted: {
        if (DMSService.dmsAvailable)
            DMSService.listInstalledThemes();
        if (PopoutService.pendingThemeInstall)
            Qt.callLater(() => showThemeBrowser());
        refreshMatugenSchemePreviews();
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
                showThemeBrowser();
        }
    }

    Connections {
        target: Theme
        function onMatugenAvailableChanged() {
            themeColorsTab.refreshMatugenSchemePreviews();
        }
        function onThemeGenerationStarting() {
            themeColorsTab.matugenGenerating = true;
        }
        function onMatugenCompleted() {
            themeColorsTab.matugenGenerating = false;
        }
    }

    SettingsPage {
        id: mainColumn

        SettingsCard {
            tab: "theme"
            tags: ["color", "palette", "theme", "appearance"]
            title: I18n.tr("Theme")
            settingKey: "themeColor"
            iconName: "palette"

            SettingsRow {
                body: Column {
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
                            if (Theme.currentThemeCategory === "registry" && registryThemeName)
                                return I18n.tr("Current Theme: %1", "current theme label").arg(registryThemeName);
                            return I18n.tr("Current Theme: %1", "current theme label").arg(Theme.currentThemeLabel);
                        }
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        font.weight: Theme.fontWeightMedium
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
            }

            SettingsRow {
                body: Column {
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
                            property int pendingIndex: -1
                            property int computedIndex: {
                                if (isRegistryTheme)
                                    return 3;
                                if (Theme.currentTheme === Theme.dynamic)
                                    return 1;
                                if (Theme.currentThemeName === "custom")
                                    return 2;
                                return 0;
                            }

                            model: DMSService.dmsAvailable ? [I18n.tr("Generic", "theme category option"), I18n.tr("Auto", "theme category option"), I18n.tr("Custom", "theme category option"), I18n.tr("Browse", "theme category option")] : [I18n.tr("Generic", "theme category option"), I18n.tr("Auto", "theme category option"), I18n.tr("Custom", "theme category option")]
                            currentIndex: pendingIndex >= 0 ? pendingIndex : computedIndex
                            selectionMode: "single"
                            onSelectionChanged: (index, selected) => {
                                if (!selected)
                                    return;
                                pendingIndex = index;
                            }
                            onAnimationCompleted: {
                                if (pendingIndex < 0)
                                    return;
                                const idx = pendingIndex;
                                pendingIndex = -1;
                                switch (idx) {
                                case 0:
                                    Theme.switchThemeCategory("generic", "blue");
                                    break;
                                case 1:
                                    if (ToastService.wallpaperErrorStatus === "matugen_missing" || ToastService.wallpaperErrorStatus === "error") {
                                        ToastService.showError(ToastService.wallpaperErrorStatus === "matugen_missing" ? I18n.tr("matugen not found - install matugen package for dynamic theming", "matugen error") : I18n.tr("Wallpaper processing failed - check wallpaper path", "wallpaper error"));
                                        break;
                                    }
                                    Theme.switchThemeCategory("dynamic", Theme.dynamic);
                                    break;
                                case 2:
                                    Theme.switchThemeCategory("custom", "custom");
                                    break;
                                case 3:
                                    Theme.switchThemeCategory("registry", "");
                                    break;
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: genericColorGrid.implicitHeight + Math.ceil(genericColorGrid.dotSize * 0.05)
                        visible: Theme.currentThemeCategory === "generic" && Theme.currentTheme !== Theme.dynamic && Theme.currentThemeName !== "custom"

                        Grid {
                            id: genericColorGrid
                            property var colorList: ["blue", "purple", "green", "orange", "red", "cyan", "pink", "amber", "coral", "monochrome"]
                            property int dotSize: Theme.minimumTouchTargetSize
                            columns: Math.ceil(colorList.length / 2)
                            rowSpacing: Theme.spacingS
                            columnSpacing: Theme.spacingS
                            anchors.horizontalCenter: parent.horizontalCenter

                            Repeater {
                                model: genericColorGrid.colorList

                                Rectangle {
                                    required property string modelData
                                    property string themeName: modelData
                                    readonly property var colors: Theme.getThemeColors(themeName)
                                    readonly property var palette: ThemePalette.pick(colors)
                                    readonly property bool isActive: Theme.currentThemeName === themeName && Theme.currentTheme !== Theme.dynamic
                                    width: genericColorGrid.dotSize
                                    height: genericColorGrid.dotSize
                                    radius: width / 2
                                    color: "transparent"
                                    scale: isActive ? 1.1 : 1

                                    DankPaletteSwatch {
                                        anchors.fill: parent
                                        primaryColor: parent.palette.primary
                                        secondaryColor: parent.palette.secondary
                                        tertiaryColor: parent.palette.tertiary
                                    }

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "check"
                                        size: Theme.iconSizeMedium
                                        color: Theme.isLightColor(parent.colors.primary) ? Theme.contrastDark : Theme.contrastLight
                                        visible: parent.isActive
                                    }

                                    DankTooltipHost {
                                        text: parent.colors.name
                                        target: parent
                                        hoverArea: mouseArea
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

                    Row {
                        visible: Theme.currentTheme === Theme.dynamic && Theme.currentThemeCategory !== "registry"
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledRect {
                            width: 120
                            height: 90
                            radius: Theme.cornerRadius
                            color: Theme.floatingWindowNestedSurface

                            ClippingRectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: Theme.cornerRadius - Theme.outlineWidth
                                color: "transparent"

                                Image {
                                    anchors.fill: parent
                                    source: {
                                        var wp = Theme.wallpaperPath;
                                        if (!wp || wp === "" || wp.startsWith("#"))
                                            return "";
                                        if (wp.startsWith("file://"))
                                            wp = wp.substring(7);
                                        return "file://" + wp.split('/').map(s => encodeURIComponent(s)).join('/');
                                    }
                                    fillMode: Image.PreserveAspectCrop
                                    visible: Theme.wallpaperPath && !Theme.wallpaperPath.startsWith("#")
                                    sourceSize.width: 120
                                    sourceSize.height: 120
                                    asynchronous: true
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: Theme.cornerRadius - Theme.outlineWidth
                                color: Theme.wallpaperPath && Theme.wallpaperPath.startsWith("#") ? Theme.wallpaperPath : Theme.withAlpha(Theme.wallpaperPath, 0)
                                visible: Theme.wallpaperPath && Theme.wallpaperPath.startsWith("#")
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
                            width: parent.width - 120 - Theme.spacingM - 36 - Theme.spacingM
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
                                id: wallpaperPathText
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

                        DankActionButton {
                            buttonSize: 36
                            iconName: "download"
                            iconSize: Theme.iconSize
                            backgroundColor: Theme.primaryHover
                            iconColor: Theme.primary
                            tooltipText: I18n.tr("Extract theme to JSON", "extract theme tooltip")
                            anchors.bottom: parent.bottom
                            onClicked: {
                                pendingExtractJson = Theme.extractCurrentTheme();
                                saveBrowserLoader.active = true;
                                if (saveBrowserLoader.item)
                                    saveBrowserLoader.item.open();
                            }
                        }
                    }

                    SettingsRow {
                        visible: Theme.currentTheme === Theme.dynamic && Theme.currentThemeCategory !== "registry"
                        tab: "theme"
                        tags: ["matugen", "palette", "algorithm", "dynamic"]
                        settingKey: "matugenScheme"
                        title: I18n.tr("Matugen palette")
                        enabled: Theme.matugenAvailable
                        body: Item {
                            width: parent.width
                            // the grid keeps its height while previews regenerate so the page does not jump
                            height: schemeGrid.implicitHeight

                            SettingsSwatchGrid {
                                id: schemeGrid
                                options: themeColorsTab.matugenSchemeOptions
                                currentValue: SettingsData.matugenScheme
                                enabled: themeColorsTab.matugenPreviewsReady
                                opacity: themeColorsTab.matugenPreviewsReady ? 1 : Theme.pendingOpacity
                                onSelected: value => SettingsData.setMatugenScheme(value)

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                    }
                                }
                            }

                            DankSpinner {
                                anchors.centerIn: parent
                                running: !themeColorsTab.matugenPreviewsReady
                                visible: running
                            }
                        }
                    }

                    StyledText {
                        visible: Theme.currentTheme === Theme.dynamic && Theme.currentThemeCategory !== "registry"
                        text: {
                            var scheme = Theme.getMatugenScheme(SettingsData.matugenScheme);
                            return scheme.description + " (" + scheme.value + ")";
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width - Theme.spacingM * 2
                        x: Theme.spacingM
                    }

                    SettingsDropdownRow {
                        visible: Theme.currentTheme === Theme.dynamic && Theme.currentThemeCategory !== "registry"
                        tab: "theme"
                        tags: ["matugen", "seed", "source", "wallpaper", "dynamic"]
                        settingKey: "matugenSourceMode"
                        text: I18n.tr("Source color")
                        options: cachedSourceModes
                        currentValue: Theme.getSourceMode(SettingsData.matugenSourceMode).label
                        enabled: Theme.matugenAvailable && !SettingsData.matugenSeedColor
                        onValueChanged: value => {
                            for (var i = 0; i < Theme.availableSourceModes.length; i++) {
                                var option = Theme.availableSourceModes[i];
                                if (option.label === value) {
                                    SettingsData.setMatugenSourceMode(option.value);
                                    break;
                                }
                            }
                        }
                    }

                    ColorDropdownRow {
                        visible: Theme.currentTheme === Theme.dynamic && Theme.currentThemeCategory !== "registry"
                        tab: "theme"
                        tags: ["matugen", "seed", "pick", "eyedropper", "dynamic"]
                        settingKey: "matugenSeedColor"
                        text: I18n.tr("Derived color")
                        enabled: Theme.matugenAvailable
                        options: [
                            {
                                "value": "default",
                                "previewColor": Theme.getMatugenColor("source_color", Theme.primary),
                                "label": I18n.tr("From wallpaper", "matugen seed color option")
                            },
                            {
                                "value": "custom",
                                "label": I18n.tr("Custom")
                            }
                        ]
                        currentMode: SettingsData.matugenSeedColor ? "custom" : "default"
                        customColor: SettingsData.matugenSeedColor || Theme.getMatugenColor("source_color", Theme.primary)
                        pickerTitle: I18n.tr("Seed color")
                        onModeSelected: mode => {
                            if (mode !== "custom") {
                                SettingsData.setMatugenSeedColor("");
                                return;
                            }
                            if (SettingsData.matugenSeedColor)
                                return;
                            SettingsData.setMatugenSeedColor(Theme.getMatugenColor("source_color", Theme.primary).toString());
                        }
                        onCustomColorSelected: selectedColor => SettingsData.setMatugenSeedColor(Theme.withAlpha(selectedColor, 1).toString())
                    }

                    SettingsButtonGroupRow {
                        visible: Theme.currentTheme === Theme.dynamic && Theme.currentThemeCategory !== "registry"
                        tab: "theme"
                        tags: ["matugen", "spec", "expressive", "vivid", "saturated", "bold", "dynamic"]
                        settingKey: "matugenSpec"
                        text: I18n.tr("Material palette")
                        enabled: Theme.matugenAvailable
                        model: [I18n.tr("Standard", "adjective, panel motion option and bar layout mode option"), I18n.tr("Expressive", "matugen color scheme option")]
                        currentIndex: SettingsData.matugenSpec === "2025" ? 1 : 0
                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            SettingsData.setMatugenSpec(index === 1 ? "2025" : "2021");
                        }
                    }

                    SettingsSliderRow {
                        id: contrastRow
                        visible: Theme.currentTheme === Theme.dynamic && Theme.currentThemeCategory !== "registry"
                        tab: "theme"
                        tags: ["matugen", "contrast", "dynamic"]
                        settingKey: "matugenContrast"
                        text: I18n.tr("Contrast", "noun, slider label for color or display contrast")
                        value: Math.round(SettingsData.matugenContrast * 100)
                        minimum: -100
                        maximum: 100
                        enabled: Theme.matugenAvailable
                        onSliderDragFinished: finalValue => {
                            const clamped = SettingsData.matugenSpec === "2025" ? Math.max(0, finalValue) : finalValue;
                            SettingsData.setMatugenContrast(clamped / 100);
                            if (clamped !== finalValue)
                                contrastRow.resync();
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
                                buttonSize: Theme.minimumTouchTargetSize
                                iconName: "folder_open"
                                Accessible.name: I18n.tr("Browse Files")
                                iconSize: Theme.iconSize
                                backgroundColor: Theme.primaryHover
                                iconColor: Theme.primary
                                onClicked: fileBrowserModal.open()
                            }

                            DankPaletteSwatch {
                                id: customSwatch
                                width: Theme.minimumTouchTargetSize
                                height: Theme.minimumTouchTargetSize
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !!SettingsData.customThemeFile
                                primaryColor: themeColorsTab.currentPalette.primary
                                secondaryColor: themeColorsTab.currentPalette.secondary
                                tertiaryColor: themeColorsTab.currentPalette.tertiary
                            }

                            Column {
                                width: parent.width - Theme.minimumTouchTargetSize - Theme.spacingM - (customSwatch.visible ? customSwatch.width + Theme.spacingM : 0)
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
                                    color: Theme.floatingWindowNestedSurface
                                    border.color: isActive ? Theme.primary : Theme.outline
                                    border.width: isActive ? Theme.outlineWidthFocused : Theme.outlineWidth
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
                                        anchors.margins: Theme.spacingXXS
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

                                    DankPaletteSwatch {
                                        readonly property var palette: ThemePalette.pick((Theme.isLightMode ? themeCard.modelData.light : themeCard.modelData.dark) ?? themeCard.modelData.dark)
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.margins: Theme.spacingXS
                                        width: Theme.iconSizeMedium
                                        height: Theme.iconSizeMedium
                                        visible: !!palette
                                        primaryColor: palette?.primary ?? Theme.primary
                                        secondaryColor: palette?.secondary ?? primaryColor
                                        tertiaryColor: palette?.tertiary ?? secondaryColor
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
                                            font.weight: Theme.fontWeightMedium
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
                                            font.weight: Theme.fontWeightMedium
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
                                        Accessible.role: Accessible.Button
                                        Accessible.name: I18n.tr("Delete")
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
                            onClicked: showThemeBrowser()
                        }
                    }

                    Column {
                        id: variantSelector
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: activeThemeId !== "" && activeThemeVariants !== null && (isMultiVariant || (activeThemeVariants.options && activeThemeVariants.options.length > 0))

                        property string activeThemeId: {
                            switch (Theme.currentThemeCategory) {
                            case "registry":
                                if (Theme.currentTheme !== "custom")
                                    return "";
                                for (var i = 0; i < themeColorsTab.installedRegistryThemes.length; i++) {
                                    var t = themeColorsTab.installedRegistryThemes[i];
                                    if (SettingsData.customThemeFile && SettingsData.customThemeFile.endsWith((t.sourceDir || t.id) + "/theme.json"))
                                        return t.id;
                                }
                                return "";
                            case "custom":
                                return Theme.currentThemeId || "";
                            default:
                                return "";
                            }
                        }
                        property var activeThemeVariants: {
                            if (!activeThemeId)
                                return null;
                            switch (Theme.currentThemeCategory) {
                            case "registry":
                                for (var i = 0; i < themeColorsTab.installedRegistryThemes.length; i++) {
                                    var t = themeColorsTab.installedRegistryThemes[i];
                                    if (t.id === activeThemeId && t.hasVariants)
                                        return t.variants;
                                }
                                return null;
                            case "custom":
                                return Theme.currentThemeVariants || null;
                            default:
                                return null;
                            }
                        }
                        property bool isMultiVariant: activeThemeVariants?.type === "multi"
                        property string colorMode: Theme.isLightMode ? "light" : "dark"
                        property var multiDefaults: {
                            if (!isMultiVariant || !activeThemeVariants?.defaults)
                                return {};
                            return activeThemeVariants.defaults[colorMode] || activeThemeVariants.defaults.dark || {};
                        }
                        property var storedMulti: activeThemeId ? SettingsData.getRegistryThemeMultiVariant(activeThemeId, multiDefaults, colorMode) : multiDefaults
                        property string selectedFlavor: {
                            var sf = storedMulti.flavor || multiDefaults.flavor || "";
                            for (var i = 0; i < flavorOptions.length; i++) {
                                if (flavorOptions[i].id === sf)
                                    return sf;
                            }
                            if (flavorOptions.length > 0)
                                return flavorOptions[0].id;
                            return sf;
                        }
                        property string selectedAccent: storedMulti.accent || multiDefaults.accent || ""
                        property var flavorOptions: {
                            if (!isMultiVariant || !activeThemeVariants?.flavors)
                                return [];
                            return activeThemeVariants.flavors.filter(f => {
                                if (f.mode)
                                    return f.mode === colorMode || f.mode === "both";
                                return !!f[colorMode];
                            });
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
                                property int _count: variantSelector.flavorNames.length
                                property real _maxPerItem: _count > 1 ? (parent.width - (_count - 1) * spacing) / _count : parent.width
                                buttonPadding: _maxPerItem < 55 ? Theme.spacingXS : (_maxPerItem < 75 ? Theme.spacingS : Theme.spacingL)
                                minButtonWidth: Math.min(_maxPerItem < 55 ? 28 : (_maxPerItem < 75 ? 44 : 64), Math.max(28, Math.floor(_maxPerItem)))
                                textSize: _maxPerItem < 55 ? Theme.fontSizeSmall - 2 : (_maxPerItem < 75 ? Theme.fontSizeSmall : Theme.fontSizeMedium)
                                checkEnabled: _maxPerItem >= 55
                                property int pendingIndex: -1
                                model: variantSelector.flavorNames
                                currentIndex: pendingIndex >= 0 ? pendingIndex : variantSelector.flavorIndex
                                selectionMode: "single"
                                onSelectionChanged: (index, selected) => {
                                    if (!selected)
                                        return;
                                    pendingIndex = index;
                                }
                                onAnimationCompleted: {
                                    if (pendingIndex < 0 || pendingIndex >= variantSelector.flavorOptions.length)
                                        return;
                                    const flavorId = variantSelector.flavorOptions[pendingIndex]?.id;
                                    const idx = pendingIndex;
                                    pendingIndex = -1;
                                    if (!flavorId || flavorId === variantSelector.selectedFlavor)
                                        return;
                                    Theme.screenTransition();
                                    SettingsData.setRegistryThemeMultiVariant(variantSelector.activeThemeId, flavorId, variantSelector.selectedAccent, variantSelector.colorMode);
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
                                        color: modelData.color || modelData[variantSelector.selectedFlavor]?.primary || Theme.primary
                                        border.color: Theme.outline
                                        border.width: isSelected ? Theme.outlineWidthFocused : Theme.outlineWidth
                                        scale: isSelected ? 1.1 : 1

                                        Rectangle {
                                            width: accentNameText.contentWidth + Theme.spacingS * 2
                                            height: accentNameText.contentHeight + Theme.spacingXS * 2
                                            color: Theme.floatingWindowSurface
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
                                                SettingsData.setRegistryThemeMultiVariant(variantSelector.activeThemeId, variantSelector.selectedFlavor, parent.accentId, variantSelector.colorMode);
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
                                property int _count: variantSelector.variantNames.length
                                property real _maxPerItem: _count > 1 ? (parent.width - (_count - 1) * spacing) / _count : parent.width
                                buttonPadding: _maxPerItem < 55 ? Theme.spacingXS : (_maxPerItem < 75 ? Theme.spacingS : Theme.spacingL)
                                minButtonWidth: Math.min(_maxPerItem < 55 ? 28 : (_maxPerItem < 75 ? 44 : 64), Math.max(28, Math.floor(_maxPerItem)))
                                textSize: _maxPerItem < 55 ? Theme.fontSizeSmall - 2 : (_maxPerItem < 75 ? Theme.fontSizeSmall : Theme.fontSizeMedium)
                                checkEnabled: _maxPerItem >= 55
                                property int pendingIndex: -1
                                model: variantSelector.variantNames
                                currentIndex: pendingIndex >= 0 ? pendingIndex : variantSelector.selectedIndex
                                selectionMode: "single"
                                onSelectionChanged: (index, selected) => {
                                    if (!selected)
                                        return;
                                    pendingIndex = index;
                                }
                                onAnimationCompleted: {
                                    if (pendingIndex < 0 || !variantSelector.activeThemeVariants?.options)
                                        return;
                                    const variantId = variantSelector.activeThemeVariants.options[pendingIndex]?.id;
                                    const idx = pendingIndex;
                                    pendingIndex = -1;
                                    if (!variantId || variantId === variantSelector.selectedVariant)
                                        return;
                                    Theme.screenTransition();
                                    SettingsData.setRegistryThemeVariant(variantSelector.activeThemeId, variantId);
                                }
                            }
                        }
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

    LazyLoader {
        id: saveBrowserLoader
        active: false

        FileBrowserSurfaceModal {
            id: saveBrowser

            browserTitle: I18n.tr("Save Extracted Theme", "extract theme save dialog title")
            browserType: "default"
            fileExtensions: ["*.json"]
            allowStacking: true
            saveMode: true
            defaultFileName: "dms-extracted-theme.json"

            onFileSelected: path => {
                saveExtractedTheme(pendingExtractJson, Paths.strip(path));
                close();
            }
        }
    }

    LazyLoader {
        id: themeBrowserLoader
        active: false

        ThemeBrowser {
            id: themeBrowserItem
            parentModal: themeColorsTab.parentModal
        }
    }

    property bool _themeBrowserShowQueued: false

    Connections {
        target: themeBrowserLoader

        function onItemChanged() {
            if (!themeColorsTab._themeBrowserShowQueued || !themeBrowserLoader.item)
                return;
            themeColorsTab._themeBrowserShowQueued = false;
            themeBrowserLoader.item.show();
        }
    }

    function showThemeBrowser() {
        themeBrowserLoader.active = true;
        if (themeBrowserLoader.item) {
            themeBrowserLoader.item.show();
            return;
        }
        // LazyLoader can't incubate on its first event-loop tick; show once item lands
        _themeBrowserShowQueued = true;
    }

    FileView {
        id: extractSaveFileView
        blockWrites: true
        preload: false
        atomicWrites: true
        printErrors: true

        onSaved: {
            ToastService.showInfo(I18n.tr("Theme extracted to: %1", "extract theme success").arg(Paths.strip(extractSaveFileView.path)));
        }

        onSaveFailed: error => {
            ToastService.showError(I18n.tr("Failed to extract theme", "extract theme error"));
            log.warn("Failed to write extracted theme to " + extractSaveFileView.path + ": " + error);
        }
    }

    function saveExtractedTheme(json, outputPath) {
        extractSaveFileView.path = outputPath;
        extractSaveFileView.setText(json);
    }
}
