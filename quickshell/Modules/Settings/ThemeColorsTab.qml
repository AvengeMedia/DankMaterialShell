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

    property var cachedIconThemes: []
    property var cachedMatugenSchemes: []

    Component.onCompleted: {
        SettingsData.detectAvailableIconThemes();
        cachedIconThemes = SettingsData.availableIconThemes;
        cachedMatugenSchemes = Theme.availableMatugenSchemes.map(function (option) {
            return option.label;
        });
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
                tab: "theme"
                tags: ["color", "palette", "theme", "appearance"]
                title: I18n.tr("Theme Color")
                iconName: "palette"

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: {
                            if (Theme.currentTheme === Theme.dynamic)
                                return "Current Theme: Dynamic";
                            if (Theme.currentThemeCategory === "catppuccin")
                                return "Current Theme: Catppuccin " + Theme.getThemeColors(Theme.currentThemeName).name;
                            return "Current Theme: " + Theme.getThemeColors(Theme.currentThemeName).name;
                        }
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: {
                            if (Theme.currentTheme === Theme.dynamic)
                                return "Material colors generated from wallpaper";
                            if (Theme.currentThemeCategory === "catppuccin")
                                return "Soothing pastel theme based on Catppuccin";
                            if (Theme.currentTheme === Theme.custom)
                                return "Custom theme loaded from JSON file";
                            return "Material Design inspired color themes";
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
                    spacing: Theme.spacingM
                    anchors.horizontalCenter: parent.horizontalCenter

                    DankButtonGroup {
                        property int currentThemeIndex: {
                            if (Theme.currentTheme === Theme.dynamic)
                                return 2;
                            if (Theme.currentThemeName === "custom")
                                return 3;
                            if (Theme.currentThemeCategory === "catppuccin")
                                return 1;
                            return 0;
                        }
                        property int pendingThemeIndex: -1

                        model: ["Generic", "Catppuccin", "Auto", "Custom"]
                        currentIndex: currentThemeIndex
                        selectionMode: "single"
                        anchors.horizontalCenter: parent.horizontalCenter
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
                                Theme.switchThemeCategory("catppuccin", "cat-mauve");
                                break;
                            case 2:
                                if (ToastService.wallpaperErrorStatus === "matugen_missing")
                                    ToastService.showError("matugen not found - install matugen package for dynamic theming");
                                else if (ToastService.wallpaperErrorStatus === "error")
                                    ToastService.showError("Wallpaper processing failed - check wallpaper path");
                                else
                                    Theme.switchTheme(Theme.dynamic, true, true);
                                break;
                            case 3:
                                if (Theme.currentThemeName !== "custom")
                                    Theme.switchTheme("custom", true, true);
                                break;
                            }
                            pendingThemeIndex = -1;
                        }
                    }

                    Column {
                        spacing: Theme.spacingS
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: Theme.currentThemeCategory === "generic" && Theme.currentTheme !== Theme.dynamic && Theme.currentThemeName !== "custom"

                        Row {
                            spacing: Theme.spacingM
                            anchors.horizontalCenter: parent.horizontalCenter

                            Repeater {
                                model: ["blue", "purple", "green", "orange", "red"]

                                Rectangle {
                                    required property string modelData
                                    property string themeName: modelData
                                    width: 32
                                    height: 32
                                    radius: 16
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

                                    Behavior on border.width {
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Theme.emphasizedEasing
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            spacing: Theme.spacingM
                            anchors.horizontalCenter: parent.horizontalCenter

                            Repeater {
                                model: ["cyan", "pink", "amber", "coral", "monochrome"]

                                Rectangle {
                                    required property string modelData
                                    property string themeName: modelData
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: Theme.getThemeColors(themeName).primary
                                    border.color: Theme.outline
                                    border.width: (Theme.currentThemeName === themeName && Theme.currentTheme !== Theme.dynamic) ? 2 : 1
                                    scale: (Theme.currentThemeName === themeName && Theme.currentTheme !== Theme.dynamic) ? 1.1 : 1

                                    Rectangle {
                                        width: nameText2.contentWidth + Theme.spacingS * 2
                                        height: nameText2.contentHeight + Theme.spacingXS * 2
                                        color: Theme.surfaceContainer
                                        radius: Theme.cornerRadius
                                        anchors.bottom: parent.top
                                        anchors.bottomMargin: Theme.spacingXS
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: mouseArea2.containsMouse

                                        StyledText {
                                            id: nameText2
                                            text: Theme.getThemeColors(parent.parent.themeName).name
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            anchors.centerIn: parent
                                        }
                                    }

                                    MouseArea {
                                        id: mouseArea2
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

                                    Behavior on border.width {
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
                        spacing: Theme.spacingS
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: Theme.currentThemeCategory === "catppuccin" && Theme.currentTheme !== Theme.dynamic && Theme.currentThemeName !== "custom"

                        Row {
                            spacing: Theme.spacingM
                            anchors.horizontalCenter: parent.horizontalCenter

                            Repeater {
                                model: ["cat-rosewater", "cat-flamingo", "cat-pink", "cat-mauve", "cat-red", "cat-maroon", "cat-peach"]

                                Rectangle {
                                    required property string modelData
                                    property string themeName: modelData
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: Theme.getCatppuccinColor(themeName)
                                    border.color: Theme.outline
                                    border.width: (Theme.currentThemeName === themeName && Theme.currentTheme !== Theme.dynamic) ? 2 : 1
                                    scale: (Theme.currentThemeName === themeName && Theme.currentTheme !== Theme.dynamic) ? 1.1 : 1

                                    Rectangle {
                                        width: nameTextCat.contentWidth + Theme.spacingS * 2
                                        height: nameTextCat.contentHeight + Theme.spacingXS * 2
                                        color: Theme.surfaceContainer
                                        radius: Theme.cornerRadius
                                        anchors.bottom: parent.top
                                        anchors.bottomMargin: Theme.spacingXS
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: mouseAreaCat.containsMouse

                                        StyledText {
                                            id: nameTextCat
                                            text: Theme.getCatppuccinVariantName(parent.parent.themeName)
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            anchors.centerIn: parent
                                        }
                                    }

                                    MouseArea {
                                        id: mouseAreaCat
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

                                    Behavior on border.width {
                                        NumberAnimation {
                                            duration: Theme.shortDuration
                                            easing.type: Theme.emphasizedEasing
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            spacing: Theme.spacingM
                            anchors.horizontalCenter: parent.horizontalCenter

                            Repeater {
                                model: ["cat-yellow", "cat-green", "cat-teal", "cat-sky", "cat-sapphire", "cat-blue", "cat-lavender"]

                                Rectangle {
                                    required property string modelData
                                    property string themeName: modelData
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: Theme.getCatppuccinColor(themeName)
                                    border.color: Theme.outline
                                    border.width: (Theme.currentThemeName === themeName && Theme.currentTheme !== Theme.dynamic) ? 2 : 1
                                    scale: (Theme.currentThemeName === themeName && Theme.currentTheme !== Theme.dynamic) ? 1.1 : 1

                                    Rectangle {
                                        width: nameTextCat2.contentWidth + Theme.spacingS * 2
                                        height: nameTextCat2.contentHeight + Theme.spacingXS * 2
                                        color: Theme.surfaceContainer
                                        radius: Theme.cornerRadius
                                        anchors.bottom: parent.top
                                        anchors.bottomMargin: Theme.spacingXS
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: mouseAreaCat2.containsMouse

                                        StyledText {
                                            id: nameTextCat2
                                            text: Theme.getCatppuccinVariantName(parent.parent.themeName)
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            anchors.centerIn: parent
                                        }
                                    }

                                    MouseArea {
                                        id: mouseAreaCat2
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

                                    Behavior on border.width {
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
                        visible: Theme.currentTheme === Theme.dynamic

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
                                            return "Wallpaper Error";
                                        if (ToastService.wallpaperErrorStatus === "matugen_missing")
                                            return "Matugen Missing";
                                        if (Theme.wallpaperPath)
                                            return Theme.wallpaperPath.split('/').pop();
                                        return "No wallpaper selected";
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
                                            return "Wallpaper processing failed";
                                        if (ToastService.wallpaperErrorStatus === "matugen_missing")
                                            return "Install matugen package for dynamic theming";
                                        if (Theme.wallpaperPath)
                                            return Theme.wallpaperPath;
                                        return "Dynamic colors from wallpaper";
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
                        visible: Theme.currentThemeName === "custom"

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
                                    text: SettingsData.customThemeFile ? SettingsData.customThemeFile.split('/').pop() : "No custom theme file"
                                    font.pixelSize: Theme.fontSizeLarge
                                    color: Theme.surfaceText
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 1
                                    width: parent.width
                                }

                                StyledText {
                                    text: SettingsData.customThemeFile || "Click to select a custom theme JSON file"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 1
                                    width: parent.width
                                }
                            }
                        }
                    }
                }
            }

            SettingsCard {
                tab: "theme"
                tags: ["light", "dark", "mode", "appearance"]
                title: I18n.tr("Color Mode")
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
                tags: ["modal", "darken", "background", "overlay"]

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
}
