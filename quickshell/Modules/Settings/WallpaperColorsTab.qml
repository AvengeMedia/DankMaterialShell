pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets
import "../../Common/Format.js" as Format
import "../../Common/ThemePalette.js" as ThemePalette

Column {
    id: root

    property var parentModal: null
    property var cachedIconThemes: SettingsData.availableIconThemes
    property var cachedCursorThemes: SettingsData.availableCursorThemes

    readonly property bool perMonitor: SessionData.perMonitorWallpaper
    readonly property bool perMode: SessionData.perModeWallpaper
    readonly property string selectedScreen: SettingsUiState.selectedWallpaperScreen || firstScreenName()
    readonly property string currentWallpaper: {
        SessionData.monitorWallpapers;
        return perMonitor ? SessionData.getMonitorWallpaper(selectedScreen) : SessionData.wallpaperPath;
    }
    readonly property bool hasWallpaper: currentWallpaper !== ""
    readonly property bool wallpaperIsImage: hasWallpaper && !currentWallpaper.startsWith("#")
    readonly property bool cyclingEnabled: {
        SessionData.monitorCyclingSettings;
        return perMonitor ? SessionData.getMonitorCyclingSettings(selectedScreen).enabled : SessionData.wallpaperCyclingEnabled;
    }
    readonly property var themePalette: ThemePalette.pick({
        "primary": Theme.primary,
        "secondary": Theme.secondary,
        "tertiary": Theme.tertiary,
        "primaryContainer": Theme.primaryContainer,
        "info": Theme.info,
        "error": Theme.error,
        "warning": Theme.warning
    })
    readonly property bool dynamicTheme: Theme.currentTheme === Theme.dynamic && Theme.currentThemeCategory !== "registry"
    readonly property bool genericTheme: Theme.currentThemeCategory === "generic" && Theme.currentTheme !== Theme.dynamic && Theme.currentThemeName !== "custom"
    readonly property var genericOptions: ["blue", "purple", "green", "orange", "red", "cyan", "pink", "amber", "coral", "monochrome"].map(name => {
        const colors = Theme.getThemeColors(name);
        const palette = ThemePalette.pick(colors) ?? {};
        return {
            "value": name,
            "label": colors.name,
            "primary": palette.primary ?? Theme.primary.toString(),
            "secondary": palette.secondary,
            "tertiary": palette.tertiary
        };
    })
    readonly property string themesDir: Quickshell.env("HOME") + "/.config/DankMaterialShell/themes"
    readonly property var installedRegistryThemes: DMSService.installedThemes
    readonly property var registryOptions: {
        const mode = Theme.isLightMode ? "light" : "dark";
        return installedRegistryThemes.map(theme => {
            const palette = ThemePalette.pick(theme.palette?.[mode] ?? theme.palette?.dark) ?? {};
            return {
                "value": theme.sourceDir || theme.id,
                "label": theme.name,
                "primary": palette.primary ?? Theme.primary.toString(),
                "secondary": palette.secondary,
                "tertiary": palette.tertiary
            };
        });
    }
    readonly property string activeRegistryTheme: {
        if (Theme.currentThemeName !== "custom" || !SettingsData.customThemeFile)
            return "";
        for (const theme of installedRegistryThemes) {
            if (SettingsData.customThemeFile.endsWith((theme.sourceDir || theme.id) + "/theme.json"))
                return theme.sourceDir || theme.id;
        }
        return "";
    }
    readonly property bool registryGridShown: !dynamicTheme && !genericTheme && registryOptions.length > 0
    readonly property bool registryPending: !dynamicTheme && !genericTheme && DMSService.dmsAvailable && !DMSService.installedThemesLoaded
    readonly property string matugenPreviewKey: MatugenPreviewService.key
    readonly property bool matugenAvailable: Theme.matugenAvailable
    onMatugenPreviewKeyChanged: refreshPreviews()
    onMatugenAvailableChanged: refreshPreviews()
    onDynamicThemeChanged: refreshPreviews()
    onVisibleChanged: refreshPreviews()
    readonly property string colorModeStatus: {
        if (SettingsData.matugenSmartMode)
            return I18n.tr("Wallpaper");
        if (!SessionData.themeModeAutoEnabled)
            return I18n.tr("Manual");
        const label = SessionData.themeModeAutoMode === "location" ? I18n.tr("Location") : I18n.tr("Schedule");
        if (!SessionData.themeModeNextTransition)
            return label;
        return label + " · " + Format.formatIsoTime(SessionData.themeModeNextTransition);
    }

    width: parent?.width ?? 0
    spacing: Theme.spacingL

    Component.onCompleted: {
        WallpaperCyclingService.cyclingActive;
        SettingsData.detectAvailableIconThemes();
        SettingsData.detectAvailableCursorThemes();
        refreshPreviews();
        if (DMSService.dmsAvailable)
            DMSService.listInstalledThemes();
    }

    function refreshPreviews() {
        if (visible && dynamicTheme)
            MatugenPreviewService.refresh();
    }

    function firstScreenName() {
        const screens = Quickshell.screens;
        return screens.length > 0 ? screens[0].name : "";
    }

    function screenNames() {
        const names = [];
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++)
            names.push(SettingsData.getScreenDisplayName(screens[i]));
        return names;
    }

    function screenForDisplayName(value) {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (SettingsData.getScreenDisplayName(screens[i]) === value)
                return screens[i].name;
        }
        return "";
    }

    function displayNameForScreen(name) {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === name)
                return SettingsData.getScreenDisplayName(screens[i]);
        }
        return I18n.tr("No displays");
    }

    function openBrowser() {
        wallpaperBrowserLoader.active = true;
        if (wallpaperBrowserLoader.item)
            wallpaperBrowserLoader.item.open();
    }

    function applyWallpaper(path) {
        if (perMonitor) {
            SessionData.setMonitorWallpaper(selectedScreen, path);
            SessionData.setMonitorCyclingFolderPath(selectedScreen, "");
            return;
        }
        SessionData.setWallpaper(path);
        SessionData.wallpaperCyclingFolderPath = "";
        SessionData.saveSettings();
    }

    function pickColor() {
        const picker = PopoutService.colorPickerModal;
        if (!picker)
            return;
        picker.selectedColor = currentWallpaper.startsWith("#") ? currentWallpaper : Theme.primary;
        picker.pickerTitle = I18n.tr("Choose Wallpaper Color", "wallpaper color picker title");
        picker.onColorSelectedCallback = function (color) {
            root.applyWallpaper(color.toString());
        };
        picker.show();
    }

    function clearWallpaper() {
        if (perMonitor) {
            SessionData.setMonitorWallpaper(selectedScreen, "");
            SessionData.setMonitorCyclingFolderPath(selectedScreen, "");
            return;
        }
        if (perMode) {
            SessionData.setWallpaperForMode("", SessionData.isLightMode);
            return;
        }
        if (Theme.currentTheme === Theme.dynamic)
            Theme.switchTheme("blue");
        SessionData.clearWallpaper();
        SessionData.wallpaperCyclingFolderPath = "";
        SessionData.saveSettings();
    }

    ConfigInclude {
        id: cursorInclude
        includeKind: "cursor"
        onFixed: SettingsData.updateCompositorCursor()
    }

    function setCursorHideTimeout(value) {
        const updated = JSON.parse(JSON.stringify(SettingsData.cursorSettings));
        if (CompositorService.isNiri) {
            updated.niri = updated.niri || {};
            updated.niri.hideAfterInactiveMs = value;
        } else if (CompositorService.isHyprland) {
            updated.hyprland = updated.hyprland || {};
            updated.hyprland.inactiveTimeout = value;
        } else {
            updated.mango = updated.mango || {};
            updated.mango.cursorHideTimeout = value;
        }
        SettingsData.set("cursorSettings", updated);
    }

    function warnIfMissingQtTheme() {
        if (Quickshell.env("QT_QPA_PLATFORMTHEME") === "gtk3" || Quickshell.env("QT_QPA_PLATFORMTHEME") === "qt6ct" || Quickshell.env("QT_QPA_PLATFORMTHEME_QT6") === "qt6ct" || SettingsData.qtengineActive || Quickshell.env("QT_QPA_PLATFORMTHEME") === "kde")
            return;
        ToastService.showError(I18n.tr("Missing Environment Variables", "qt theme env error title"), I18n.tr("You need to set one of:\nQT_QPA_PLATFORMTHEME=gtk3 OR\nQT_QPA_PLATFORMTHEME=qt6ct OR\nQT_QPA_PLATFORMTHEME=qtengine\nas environment variables, and then restart the shell.\n\nOnly qt6ct requires qt6ct-kde to be installed.", "qt theme env error body"));
    }

    SettingsCard {
        tab: "wallpaper"
        tags: ["background", "image", "picture", "light", "dark", "mode", "theme", "color", "palette"]
        title: I18n.tr("Appearance")
        settingKey: "wallpaper"
        SettingsDropdownRow {
            tab: "wallpaper"
            tags: ["monitor", "display", "screen"]
            settingKey: "selectedMonitor"
            visible: root.perMonitor
            text: I18n.tr("Display")
            currentValue: root.displayNameForScreen(root.selectedScreen)
            options: root.screenNames()
            onValueChanged: value => SettingsUiState.selectedWallpaperScreen = root.screenForDisplayName(value)
        }

        SettingsRow {
            settingKey: "colorMode"
            tags: ["light", "dark", "mode", "theme", "color", "palette"]
            body: Flow {
                id: hero

                readonly property bool stacked: width < SettingsMetrics.wallpaperHeroStackWidth
                readonly property real thumbWidth: stacked ? width : Math.round(width * SettingsMetrics.wallpaperHeroSplit)

                width: parent.width
                spacing: Theme.spacingL

                SettingsWallpaperThumb {
                    width: hero.thumbWidth
                    height: {
                        const natural = width * SettingsMetrics.wallpaperThumbRatio;
                        if (hero.stacked)
                            return natural;
                        return root.registryPending ? Math.max(natural, side.implicitHeight) : side.implicitHeight;
                    }
                    path: root.currentWallpaper
                    onBrowse: root.openBrowser()
                    onPickColor: root.pickColor()
                    onClear: root.clearWallpaper()
                }

                Column {
                    id: side
                    width: hero.stacked ? hero.width : hero.width - hero.thumbWidth - hero.spacing
                    spacing: Theme.spacingM

                    Row {
                        id: modeRow
                        width: parent.width
                        spacing: Theme.spacingS

                        DankButtonGroup {
                            width: parent.width - scheduleButton.width - parent.spacing
                            fillWidth: true
                            checkEnabled: false
                            anchors.verticalCenter: parent.verticalCenter
                            model: [
                                {
                                    "text": I18n.tr("Light", "adjective, wallpaper thumbnail label for light mode"),
                                    "icon": "light_mode"
                                },
                                {
                                    "text": I18n.tr("Dark", "adjective, wallpaper thumbnail label for dark mode"),
                                    "icon": "dark_mode"
                                }
                            ]
                            currentIndex: SessionData.isLightMode ? 0 : 1
                            selectionMode: "single"
                            onSelectionChanged: (index, selected) => {
                                if (!selected)
                                    return;
                                const light = index === 0;
                                if (light === SessionData.isLightMode)
                                    return;
                                Theme.screenTransition();
                                Theme.setLightMode(light);
                            }
                        }

                        DankActionButton {
                            id: scheduleButton
                            iconName: "schedule"
                            anchors.verticalCenter: parent.verticalCenter
                            Accessible.name: I18n.tr("Dark mode")
                            tooltipText: root.colorModeStatus
                            onClicked: root.parentModal?.navigateTo("theme_schedule")
                        }
                    }

                    SettingsSwatchGrid {
                        width: parent.width
                        visible: root.dynamicTheme
                        compact: true
                        options: MatugenPreviewService.schemeOptions
                        currentValue: SettingsData.matugenScheme
                        enabled: Theme.matugenAvailable && MatugenPreviewService.ready
                        opacity: MatugenPreviewService.ready ? 1 : Theme.pendingOpacity
                        onSelected: value => SettingsData.setMatugenScheme(value)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.shortDuration
                            }
                        }
                    }

                    SettingsSwatchGrid {
                        width: parent.width
                        visible: root.genericTheme
                        compact: true
                        options: root.genericOptions
                        currentValue: root.genericTheme ? Theme.currentThemeName : ""
                        onSelected: value => Theme.switchTheme(value)
                    }

                    SettingsSwatchGrid {
                        width: parent.width
                        visible: root.registryGridShown
                        compact: true
                        maxHeight: hero.stacked ? 0 : hero.thumbWidth * SettingsMetrics.wallpaperThumbRatio - modeRow.height - side.spacing
                        options: root.registryOptions
                        currentValue: root.activeRegistryTheme
                        onSelected: value => {
                            SettingsData.set("customThemeFile", root.themesDir + "/" + value + "/theme.json");
                            Theme.switchTheme("custom", true, true);
                        }
                    }

                    Rectangle {
                        id: themeTile
                        width: parent.width
                        visible: !root.dynamicTheme && !root.genericTheme && !root.registryGridShown && !root.registryPending
                        height: hero.stacked ? Theme.listItemTwoLineHeight : Math.max(Theme.listItemTwoLineHeight, hero.thumbWidth * SettingsMetrics.wallpaperThumbRatio - modeRow.height - side.spacing)
                        radius: Theme.cornerRadiusM
                        color: Theme.foregroundColor(Theme.chipSurface, true)

                        activeFocusOnTab: visible
                        Accessible.role: Accessible.Button
                        Accessible.name: I18n.tr("Theme & colors")
                        Accessible.description: Theme.currentThemeLabel
                        Accessible.onPressAction: root.parentModal?.navigateTo("theme")
                        Keys.onSpacePressed: root.parentModal?.navigateTo("theme")
                        Keys.onReturnPressed: root.parentModal?.navigateTo("theme")

                        FocusRing {}

                        DankPaletteSwatch {
                            id: themeSwatch
                            width: Theme.avatarSize
                            height: Theme.avatarSize
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            primaryColor: root.themePalette.primary
                            secondaryColor: root.themePalette.secondary
                            tertiaryColor: root.themePalette.tertiary
                        }

                        Column {
                            anchors.left: themeSwatch.right
                            anchors.leftMargin: Theme.spacingM
                            anchors.right: themeChevron.left
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXXS

                            StyledText {
                                width: parent.width
                                text: I18n.tr("Theme & colors")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Theme.fontWeightMedium
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                            }

                            StyledText {
                                width: parent.width
                                text: Theme.currentThemeLabel
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideRight
                            }
                        }

                        DankIcon {
                            id: themeChevron
                            name: "chevron_right"
                            size: Theme.iconSize
                            color: Theme.surfaceVariantText
                            rotation: I18n.isRtl ? 180 : 0
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StateLayer {
                            stateColor: Theme.surfaceText
                            cornerRadius: themeTile.radius
                            onClicked: root.parentModal?.navigateTo("theme")
                        }
                    }
                }
            }
        }

        SettingsNavRow {
            tab: "wallpaper"
            tags: ["theme", "color", "palette", "matugen", "dynamic", "custom", "registry"]
            settingKey: "themeNav"
            iconName: "format_paint"
            title: I18n.tr("Theme & colors")
            hint: I18n.tr("Choose and install themes", "theme and colors row hint")
            onClicked: root.parentModal?.navigateTo("theme")
        }
    }

    SettingsCard {
        tab: "wallpaper"
        tags: ["background", "image", "picture", "fill", "cycling", "transition", "monitor", "display"]
        title: I18n.tr("Wallpaper")
        settingKey: "wallpaperOptions"

        SettingsDropdownRow {
            id: fillModeRow

            readonly property var fillModes: ["Stretch", "Fit", "Fill", "Scrolling", "Tile", "TileVertically", "TileHorizontally", "Pad"]
            readonly property var fillModeLabels: [I18n.tr("Stretch", "wallpaper fill mode"), I18n.tr("Fit", "wallpaper fill mode"), I18n.tr("Fill", "wallpaper fill mode"), I18n.tr("Scroll", "wallpaper fill mode"), I18n.tr("Tile", "wallpaper fill mode"), I18n.tr("Tile Vertically", "wallpaper fill mode"), I18n.tr("Tile Horizontally", "wallpaper fill mode"), I18n.tr("Pad", "wallpaper fill mode")]

            tab: "wallpaper"
            tags: ["background", "fill", "fit", "stretch", "tile", "scale"]
            settingKey: "wallpaperFillMode"
            resetKeys: root.perMonitor ? [] : ["wallpaperFillMode"]
            text: I18n.tr("Fill mode")
            visible: root.wallpaperIsImage
            dropdownWidth: 190
            options: fillModeLabels
            optionIcons: ["aspect_ratio", "fit_screen", "zoom_out_map", "swipe", "grid_view", "view_agenda", "view_column", "padding"]
            currentValue: {
                SessionData.monitorWallpaperFillModes;
                const mode = root.perMonitor ? SessionData.getMonitorWallpaperFillMode(root.selectedScreen) : SettingsData.wallpaperFillMode;
                const idx = fillModes.indexOf(mode);
                return idx >= 0 ? fillModeLabels[idx] : "";
            }
            onValueChanged: value => {
                const idx = fillModeLabels.indexOf(value);
                if (idx < 0)
                    return;
                if (root.perMonitor) {
                    SessionData.setMonitorWallpaperFillMode(root.selectedScreen, fillModes[idx]);
                    return;
                }
                SettingsData.set("wallpaperFillMode", fillModes[idx]);
            }
        }

        ColorDropdownRow {
            tab: "wallpaper"
            tags: ["background", "color", "fill", "fit", "custom"]
            settingKey: "wallpaperBackgroundColorMode"
            resetKeys: ["wallpaperBackgroundColorMode", "wallpaperBackgroundCustomColor"]
            text: I18n.tr("Background color")
            visible: root.wallpaperIsImage
            dropdownWidth: 220
            options: [
                {
                    "value": "black",
                    "previewColor": SettingsData.wallpaperBackgroundColorFor("black"),
                    "label": I18n.tr("Black", "wallpaper background color option")
                },
                {
                    "value": "white",
                    "previewColor": SettingsData.wallpaperBackgroundColorFor("white"),
                    "label": I18n.tr("White", "wallpaper background color option")
                },
                {
                    "value": "primary",
                    "previewColor": SettingsData.wallpaperBackgroundColorFor("primary"),
                    "label": I18n.tr("Primary")
                },
                {
                    "value": "surface",
                    "previewColor": SettingsData.wallpaperBackgroundColorFor("surface"),
                    "label": I18n.tr("Surface Container")
                },
                {
                    "value": "custom",
                    "label": I18n.tr("Custom")
                }
            ]
            currentMode: SettingsData.wallpaperBackgroundColorMode
            customColor: SettingsData.wallpaperBackgroundCustomColor || "#000000"
            pickerTitle: I18n.tr("Background color")
            onModeSelected: mode => SettingsData.set("wallpaperBackgroundColorMode", mode)
            onCustomColorSelected: selectedColor => SettingsData.set("wallpaperBackgroundCustomColor", selectedColor.toString())
        }

        SettingsToggleRow {
            tab: "wallpaper"
            tags: ["per-mode", "light", "dark", "theme"]
            settingKey: "perModeWallpaper"
            visible: SessionData.wallpaperPath !== ""
            text: I18n.tr("Separate light and dark")
            checked: SessionData.perModeWallpaper
            onToggled: toggled => SessionData.setPerModeWallpaper(toggled)
        }

        SettingsToggleRow {
            tab: "wallpaper"
            tags: ["per-monitor", "multi-monitor", "display", "monitor"]
            settingKey: "perMonitorWallpaper"
            visible: SessionData.wallpaperPath !== ""
            text: I18n.tr("Separate per display")
            checked: SessionData.perMonitorWallpaper
            onToggled: toggled => SessionData.setPerMonitorWallpaper(toggled)
        }

        SettingsDropdownRow {
            tab: "wallpaper"
            tags: ["matugen", "target", "monitor", "theming", "dynamic", "colors"]
            settingKey: "matugenTargetMonitor"
            visible: root.perMonitor
            text: I18n.tr("Matugen source display")
            currentValue: {
                if (!SettingsData.matugenTargetMonitor)
                    return root.displayNameForScreen(root.firstScreenName()) + " (" + I18n.tr("Default") + ")";
                return root.displayNameForScreen(SettingsData.matugenTargetMonitor);
            }
            options: root.screenNames()
            onValueChanged: value => {
                const screen = root.screenForDisplayName(value);
                if (screen)
                    SettingsData.setMatugenTargetMonitor(screen);
            }
        }

        SettingsSplitRow {
            tab: "wallpaper"
            tags: ["cycling", "automatic", "rotate", "slideshow", "folder", "interval"]
            settingKey: "wallpaperCyclingEnabled"
            visible: (SessionData.wallpaperPath !== "" || root.perMonitor) && !root.perMode
            title: I18n.tr("Automatic cycling")
            subtitle: SettingsTabs.page("wallpaper_cycling")?.hint ?? ""
            checked: root.cyclingEnabled
            onNavigated: root.parentModal?.navigateTo("wallpaper_cycling")
            onToggled: toggled => {
                if (root.perMonitor) {
                    SessionData.setMonitorCyclingEnabled(root.selectedScreen, toggled);
                    return;
                }
                SessionData.setWallpaperCyclingEnabled(toggled);
            }
        }

        SettingsDropdownRow {
            tab: "wallpaper"
            tags: ["transition", "effect", "animation", "change"]
            settingKey: "wallpaperTransition"
            resetStore: SessionData
            resetKeys: ["wallpaperTransition"]
            text: I18n.tr("Transition", "noun, wallpaper change animation setting label")

            function getTransitionLabel(t) {
                switch (t) {
                case "random":
                    return I18n.tr("Random", "wallpaper transition option");
                case "none":
                    return I18n.tr("None", "wallpaper transition option");
                case "fade":
                    return I18n.tr("Fade", "wallpaper transition option");
                case "wipe":
                    return I18n.tr("Wipe", "wallpaper transition option");
                case "disc":
                    return I18n.tr("Disc", "wallpaper transition option");
                case "stripes":
                    return I18n.tr("Stripes", "wallpaper transition option");
                case "iris bloom":
                    return I18n.tr("Iris Bloom", "wallpaper transition option");
                case "pixelate":
                    return I18n.tr("Pixelate", "wallpaper transition option");
                case "portal":
                    return I18n.tr("Portal", "wallpaper transition option");
                default:
                    return t.charAt(0).toUpperCase() + t.slice(1);
                }
            }

            currentValue: getTransitionLabel(SessionData.wallpaperTransition)
            options: [I18n.tr("Random", "wallpaper transition option")].concat(SessionData.availableWallpaperTransitions.map(t => getTransitionLabel(t)))
            onValueChanged: value => {
                const transitionMap = {};
                transitionMap[I18n.tr("Random", "wallpaper transition option")] = "random";
                SessionData.availableWallpaperTransitions.forEach(t => {
                    transitionMap[getTransitionLabel(t)] = t;
                });
                SessionData.setWallpaperTransition(transitionMap[value] || value.toLowerCase());
            }
        }

        SettingsRow {
            visible: SessionData.wallpaperTransition === "random"
            body: Column {
                width: parent.width
                spacing: Theme.spacingS

                StyledText {
                    text: I18n.tr("Include transitions")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Theme.fontWeightMedium
                    color: Theme.surfaceText
                }

                DankFilterChips {
                    width: parent.width
                    multiSelect: true
                    model: SessionData.availableWallpaperTransitions.filter(t => t !== "none").map(t => ({
                                "value": t,
                                "label": t.replace(/\b\w/g, c => c.toUpperCase())
                            }))
                    selectedValues: SessionData.includedTransitions
                    onSelectionToggled: (index, selected) => {
                        const transition = model[index].value;
                        let included = SessionData.includedTransitions.slice();
                        if (selected && !included.includes(transition))
                            included.push(transition);
                        else if (!selected)
                            included = included.filter(t => t !== transition);
                        SessionData.includedTransitions = included;
                    }
                }
            }
        }

        SettingsNavRow {
            tab: "wallpaper"
            tags: ["lock", "screen", "background"]
            iconName: "lock"
            title: I18n.tr("Lock screen")
            hint: SettingsData.lockScreenWallpaperPath ? SettingsData.lockScreenWallpaperPath.split("/").pop() : I18n.tr("Use desktop wallpaper")
            onClicked: {
                SettingsSearchService.navigateToSection("lockScreenWallpaperPath");
                root.parentModal?.navigateTo("lock_screen");
            }
        }

        SettingsToggleRow {
            tab: "wallpaper"
            tags: ["blur", "overview", "niri"]
            settingKey: "blurWallpaperOnOverview"
            visible: CompositorService.isNiri
            text: I18n.tr("Blur on overview")
            checked: SettingsData.blurWallpaperOnOverview
            onToggled: checked => SettingsData.set("blurWallpaperOnOverview", checked)
        }
    }

    SettingsCard {
        tab: "theme"
        tags: ["icon", "theme", "system"]
        title: I18n.tr("Icons", "settings card title for icon theme and icon options")
        settingKey: "iconTheme"

        SettingsToggleRow {
            tab: "theme"
            tags: ["icon", "theme", "light", "dark", "mode"]
            settingKey: "iconThemePerMode"
            text: I18n.tr("Separate light and dark themes")
            checked: SettingsData.iconThemePerMode
            onToggled: checked => SettingsData.setIconThemePerMode(checked)
        }

        SettingsDropdownRow {
            enabled: !SettingsData.iconThemePerMode
            tab: "theme"
            tags: ["icon", "theme", "system"]
            settingKey: "iconTheme"
            resetKeys: ["iconThemeDark"]
            resetByKeys: false
            onResetRequested: SettingsData.setIconThemeForMode(SettingsData.specDefault("iconThemeDark"), false)
            text: I18n.tr("Theme")
            description: I18n.tr("Requires restart")
            currentValue: SettingsData.iconThemeDark
            enableFuzzySearch: true
            popupWidthOffset: 100
            maxPopupHeight: 236
            options: root.cachedIconThemes
            onValueChanged: value => {
                SettingsData.setIconThemeForMode(value, false);
                root.warnIfMissingQtTheme();
            }
        }

        SettingsDropdownRow {
            enabled: SettingsData.iconThemePerMode
            tab: "theme"
            tags: ["icon", "theme", "system", "dark"]
            settingKey: "iconThemeDark"
            resetByKeys: false
            onResetRequested: SettingsData.setIconThemeForMode(SettingsData.specDefault("iconThemeDark"), false)
            text: I18n.tr("Dark mode theme")
            description: I18n.tr("Requires restart")
            currentValue: SettingsData.iconThemeDark
            enableFuzzySearch: true
            popupWidthOffset: 100
            maxPopupHeight: 236
            options: root.cachedIconThemes
            onValueChanged: value => {
                SettingsData.setIconThemeForMode(value, false);
                root.warnIfMissingQtTheme();
            }
        }

        SettingsDropdownRow {
            enabled: SettingsData.iconThemePerMode
            tab: "theme"
            tags: ["icon", "theme", "system", "light"]
            settingKey: "iconThemeLight"
            resetByKeys: false
            onResetRequested: SettingsData.setIconThemeForMode(SettingsData.specDefault("iconThemeLight"), true)
            text: I18n.tr("Light mode theme")
            description: I18n.tr("Requires restart")
            currentValue: SettingsData.iconThemeLight
            enableFuzzySearch: true
            popupWidthOffset: 100
            maxPopupHeight: 236
            options: root.cachedIconThemes
            onValueChanged: value => {
                SettingsData.setIconThemeForMode(value, true);
                root.warnIfMissingQtTheme();
            }
        }
    }

    Loader {
        width: parent.width
        active: CompositorService.isAqueous
        sourceComponent: AqueousAppearanceSettings {
            cursor: true
            settingKey: "aqueousCursor"
            title: I18n.tr("Aqueous cursor", "Aqueous compositor cursor synchronization settings")
            visible: CompositorService.isAqueous
        }
    }

    SettingsCard {
        tab: "theme"
        tags: ["cursor", "mouse", "pointer", "theme", "size", "hide", "typing", "touch", "timeout"]
        title: I18n.tr("Cursor", "settings card title for mouse cursor theme")
        settingKey: "cursorTheme"
        visible: CompositorService.supportsCursorConfig

        IncludeSetupBanner {
            include: cursorInclude
        }

        SettingsDropdownRow {
            tab: "theme"
            tags: ["cursor", "mouse", "pointer", "theme"]
            settingKey: "cursorTheme"
            text: I18n.tr("Theme")
            currentValue: SettingsData.cursorSettings.theme
            enableFuzzySearch: true
            popupWidthOffset: 100
            maxPopupHeight: 236
            options: root.cachedCursorThemes
            modified: SettingsData.cursorSettings.theme !== SettingsData.specDefault("cursorSettings").theme
            onResetRequested: SettingsData.setCursorTheme(SettingsData.specDefault("cursorSettings").theme)
            onValueChanged: value => SettingsData.setCursorTheme(value)
        }

        SettingsSliderRow {
            tab: "theme"
            tags: ["cursor", "mouse", "pointer", "size"]
            settingKey: "cursorSize"
            text: I18n.tr("Size")
            value: SettingsData.cursorSettings.size
            minimum: 12
            maximum: 128
            unit: "px"
            modified: SettingsData.cursorSettings.size !== SettingsData.specDefault("cursorSettings").size
            onResetRequested: SettingsData.setCursorSize(SettingsData.specDefault("cursorSettings").size)
            onSliderValueChanged: newValue => SettingsData.setCursorSize(newValue)
        }

        SettingsToggleRow {
            tab: "theme"
            tags: ["cursor", "hide", "typing", "keyboard"]
            settingKey: "cursorHideWhenTyping"
            text: I18n.tr("Hide cursor when typing")
            visible: CompositorService.isNiri || CompositorService.isHyprland
            modified: checked
            checked: CompositorService.isNiri ? (SettingsData.cursorSettings.niri?.hideWhenTyping || false) : (SettingsData.cursorSettings.hyprland?.hideOnKeyPress || false)
            onToggled: checked => {
                const updated = JSON.parse(JSON.stringify(SettingsData.cursorSettings));
                if (CompositorService.isNiri) {
                    updated.niri = updated.niri || {};
                    updated.niri.hideWhenTyping = checked;
                } else {
                    updated.hyprland = updated.hyprland || {};
                    updated.hyprland.hideOnKeyPress = checked;
                }
                SettingsData.set("cursorSettings", updated);
            }
        }

        SettingsToggleRow {
            tab: "theme"
            tags: ["cursor", "hide", "touch"]
            settingKey: "cursorHideOnTouch"
            text: I18n.tr("Hide cursor on touch")
            visible: CompositorService.isHyprland
            modified: checked
            checked: SettingsData.cursorSettings.hyprland?.hideOnTouch || false
            onToggled: checked => {
                const updated = JSON.parse(JSON.stringify(SettingsData.cursorSettings));
                updated.hyprland = updated.hyprland || {};
                updated.hyprland.hideOnTouch = checked;
                SettingsData.set("cursorSettings", updated);
            }
        }

        SettingsSliderRow {
            tab: "theme"
            tags: ["cursor", "hide", "timeout", "inactive"]
            settingKey: "cursorHideAfterInactive"
            text: I18n.tr("Cursor auto-hide timeout")
            minimumLabel: I18n.tr("Off")
            visible: CompositorService.supportsCursorConfig
            value: {
                if (CompositorService.isNiri)
                    return SettingsData.cursorSettings.niri?.hideAfterInactiveMs || 0;
                if (CompositorService.isHyprland)
                    return SettingsData.cursorSettings.hyprland?.inactiveTimeout || 0;
                return SettingsData.cursorSettings.mango?.cursorHideTimeout || 0;
            }
            minimum: 0
            maximum: CompositorService.isNiri ? 5000 : 10
            unit: CompositorService.isNiri ? "ms" : "s"
            modified: value !== 0
            onResetRequested: root.setCursorHideTimeout(0)
            onSliderValueChanged: newValue => root.setCursorHideTimeout(newValue)
        }
    }

    SettingsCard {
        tab: "wallpaper"
        tags: ["blur", "layer", "external", "disable", "swww", "hyprpaper", "swaybg"]
        title: I18n.tr("Advanced")
        settingKey: "wallpaperAdvanced"
        collapsible: true
        expanded: false

        SettingsToggleRow {
            tab: "wallpaper"
            tags: ["disable", "external", "management", "swww", "hyprpaper", "swaybg"]
            settingKey: "disableWallpapers"
            text: I18n.tr("Use external manager")
            checked: {
                const prefs = SettingsData.screenPreferences?.wallpaper;
                return Array.isArray(prefs) && prefs.length === 0;
            }
            onToggled: checked => {
                const prefs = Object.assign({}, SettingsData.screenPreferences || {});
                prefs.wallpaper = checked ? [] : ["all"];
                SettingsData.set("screenPreferences", prefs);
            }
        }

        SettingsToggleRow {
            tab: "wallpaper"
            tags: ["blur", "duplicate", "layer", "compositor", "niri", "blurwallpaper"]
            settingKey: "blurredWallpaperLayer"
            visible: CompositorService.isNiri
            text: I18n.tr("Blur layer")
            description: I18n.tr("Layer namespace dms:blurwallpaper, needs a niri blur rule")
            checked: SettingsData.blurredWallpaperLayer
            onToggled: checked => SettingsData.set("blurredWallpaperLayer", checked)
        }
    }

    LazyLoader {
        id: wallpaperBrowserLoader
        active: false

        FileBrowserModal {
            parentModal: root.parentModal
            browserTitle: I18n.tr("Select Wallpaper", "wallpaper file browser title")
            browserType: "wallpaper"
            showHiddenFiles: true
            revealPath: root.currentWallpaper
            fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp", "*.jxl", "*.avif", "*.heif", "*.exr", "*.svg"]
            onFileSelected: path => {
                root.applyWallpaper(path);
                close();
            }
        }
    }
}
