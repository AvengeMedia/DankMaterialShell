import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modals
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

Item {
    id: themeColorsTab

    property var cachedFontFamilies: []
    property var cachedMonoFamilies: []
    property var cachedIconThemes: []
    property var cachedMatugenSchemes: []
    property bool fontsEnumerated: false

    function enumerateFonts() {
        var fonts = []
        var availableFonts = Qt.fontFamilies()

        for (var i = 0; i < availableFonts.length; i++) {
            var fontName = availableFonts[i]
            if (fontName.startsWith("."))
                continue
            fonts.push(fontName)
        }
        fonts.sort()
        fonts.unshift("Default")
        cachedFontFamilies = fonts

        var monoFonts = []
        for (var j = 0; j < availableFonts.length; j++) {
            var fontName2 = availableFonts[j]
            if (fontName2.startsWith("."))
                continue

            var lowerName = fontName2.toLowerCase()
            if (lowerName.includes("mono") || lowerName.includes("code") ||
                lowerName.includes("console") || lowerName.includes("terminal") ||
                lowerName.includes("courier") || lowerName.includes("jetbrains") ||
                lowerName.includes("fira") || lowerName.includes("hack") ||
                lowerName.includes("source code") || lowerName.includes("cascadia")) {
                monoFonts.push(fontName2)
            }
        }
        monoFonts.sort()
        monoFonts.unshift("Default")
        cachedMonoFamilies = monoFonts
    }

    Component.onCompleted: {
        if (!fontsEnumerated) {
            enumerateFonts()
            fontsEnumerated = true
        }
        SettingsData.detectAvailableIconThemes()
        cachedIconThemes = SettingsData.availableIconThemes
        cachedMatugenSchemes = Theme.availableMatugenSchemes.map(function (option) { return option.label })
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


            // Theme Color
            StyledRect {
                width: parent.width
                height: themeSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: themeSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "palette"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Theme Color")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            width: parent.width - parent.children[0].width - parent.children[1].width - surfaceBaseGroup.width - Theme.spacingM * 3
                            height: 1
                        }

                        DankButtonGroup {
                            id: surfaceBaseGroup
                            property int currentSurfaceIndex: {
                                switch (SettingsData.surfaceBase) {
                                    case "sc": return 0
                                    case "s": return 1
                                    default: return 0
                                }
                            }

                            model: ["Container", "Surface"]
                            currentIndex: currentSurfaceIndex
                            selectionMode: "single"
                            anchors.verticalCenter: parent.verticalCenter

                            buttonHeight: 20
                            minButtonWidth: 48
                            buttonPadding: Theme.spacingS
                            checkIconSize: Theme.iconSizeSmall - 2
                            textSize: Theme.fontSizeSmall - 2
                            spacing: 1

                            onSelectionChanged: (index, selected) => {
                                if (!selected) return
                                const surfaceOptions = ["sc", "s"]
                                SettingsData.setSurfaceBase(surfaceOptions[index])
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: {
                                if (Theme.currentTheme === Theme.dynamic) {
                                    return "Current Theme: Dynamic"
                                } else if (Theme.currentThemeCategory === "catppuccin") {
                                    return "Current Theme: Catppuccin " + Theme.getThemeColors(Theme.currentThemeName).name
                                } else {
                                    return "Current Theme: " + Theme.getThemeColors(Theme.currentThemeName).name
                                }
                            }
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: {
                                if (Theme.currentTheme === Theme.dynamic) {
                                    return "Material colors generated from wallpaper"
                                }
                                if (Theme.currentThemeCategory === "catppuccin") {
                                    return "Soothing pastel theme based on Catppuccin"
                                }
                                if (Theme.currentTheme === Theme.custom) {
                                    return "Custom theme loaded from JSON file"
                                }
                                return "Material Design inspired color themes"
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
                                if (Theme.currentTheme === Theme.dynamic) return 2
                                if (Theme.currentThemeName === "custom") return 3
                                if (Theme.currentThemeCategory === "catppuccin") return 1
                                return 0
                            }
                            property int pendingThemeIndex: -1

                            model: ["Generic", "Catppuccin", "Auto", "Custom"]
                            currentIndex: currentThemeIndex
                            selectionMode: "single"
                            anchors.horizontalCenter: parent.horizontalCenter
                            onSelectionChanged: (index, selected) => {
                                if (!selected) return
                                pendingThemeIndex = index
                            }
                            onAnimationCompleted: {
                                if (pendingThemeIndex === -1) return
                                switch (pendingThemeIndex) {
                                    case 0: Theme.switchThemeCategory("generic", "blue"); break
                                    case 1: Theme.switchThemeCategory("catppuccin", "cat-mauve"); break
                                    case 2:
                                        if (ToastService.wallpaperErrorStatus === "matugen_missing")
                                            ToastService.showError("matugen not found - install matugen package for dynamic theming")
                                        else if (ToastService.wallpaperErrorStatus === "error")
                                            ToastService.showError("Wallpaper processing failed - check wallpaper path")
                                        else
                                            Theme.switchTheme(Theme.dynamic, true, true)
                                        break
                                    case 3:
                                        if (Theme.currentThemeName !== "custom") {
                                            Theme.switchTheme("custom", true, true)
                                        }
                                        break
                                }
                                pendingThemeIndex = -1
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
                                            border.color: Theme.outline
                                            border.width: 0
                                            radius: Theme.cornerRadius
                                            anchors.bottom: parent.top
                                            anchors.bottomMargin: Theme.spacingXS
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            visible: mouseArea.containsMouse

                                            StyledText {
                                                id: nameText
                                                text: Theme.getThemeColors(themeName).name
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
                                            onClicked: {
                                                Theme.switchTheme(themeName)
                                            }
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
                                            border.color: Theme.outline
                                            border.width: 0
                                            radius: Theme.cornerRadius
                                            anchors.bottom: parent.top
                                            anchors.bottomMargin: Theme.spacingXS
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            visible: mouseArea2.containsMouse

                                            StyledText {
                                                id: nameText2
                                                text: Theme.getThemeColors(themeName).name
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
                                            onClicked: {
                                                Theme.switchTheme(themeName)
                                            }
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
                                            border.color: Theme.outline
                                            border.width: 0
                                            radius: Theme.cornerRadius
                                            anchors.bottom: parent.top
                                            anchors.bottomMargin: Theme.spacingXS
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            visible: mouseAreaCat.containsMouse

                                            StyledText {
                                                id: nameTextCat
                                                text: Theme.getCatppuccinVariantName(themeName)
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
                                            onClicked: {
                                                Theme.switchTheme(themeName)
                                            }
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
                                            border.color: Theme.outline
                                            border.width: 0
                                            radius: Theme.cornerRadius
                                            anchors.bottom: parent.top
                                            anchors.bottomMargin: Theme.spacingXS
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            visible: mouseAreaCat2.containsMouse

                                            StyledText {
                                                id: nameTextCat2
                                                text: Theme.getCatppuccinVariantName(themeName)
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
                                            onClicked: {
                                                Theme.switchTheme(themeName)
                                            }
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
                                    border.color: Theme.outline
                                    border.width: 0

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
                                        name: {
                                            if (ToastService.wallpaperErrorStatus === "error" || ToastService.wallpaperErrorStatus === "matugen_missing")
                                                return "error"
                                            else
                                                return "palette"
                                        }
                                        size: Theme.iconSizeLarge
                                        color: {
                                            if (ToastService.wallpaperErrorStatus === "error" || ToastService.wallpaperErrorStatus === "matugen_missing")
                                                return Theme.error
                                            else
                                                return Theme.surfaceVariantText
                                        }
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
                                                return "Wallpaper Error"
                                            else if (ToastService.wallpaperErrorStatus === "matugen_missing")
                                                return "Matugen Missing"
                                            else if (Theme.wallpaperPath)
                                                return Theme.wallpaperPath.split('/').pop()
                                            else
                                                return "No wallpaper selected"
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
                                                return "Wallpaper processing failed"
                                            else if (ToastService.wallpaperErrorStatus === "matugen_missing")
                                                return "Install matugen package for dynamic theming"
                                            else if (Theme.wallpaperPath)
                                                return Theme.wallpaperPath
                                            else
                                                return "Dynamic colors from wallpaper"
                                        }
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: {
                                            if (ToastService.wallpaperErrorStatus === "error" || ToastService.wallpaperErrorStatus === "matugen_missing")
                                                return Theme.error
                                            else
                                                return Theme.surfaceVariantText
                                        }
                                        elide: Text.ElideMiddle
                                        maximumLineCount: 2
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            DankDropdown {
                                id: matugenPaletteDropdown
                                text: I18n.tr("Matugen Palette")
                                description: "Select the palette algorithm used for wallpaper-based colors"
                                options: cachedMatugenSchemes
                                currentValue: Theme.getMatugenScheme(SettingsData.matugenScheme).label
                                enabled: Theme.matugenAvailable
                                opacity: enabled ? 1 : 0.4
                                onValueChanged: value => {
                                    for (var i = 0; i < Theme.availableMatugenSchemes.length; i++) {
                                        var option = Theme.availableMatugenSchemes[i]
                                        if (option.label === value) {
                                            SettingsData.setMatugenScheme(option.value)
                                            break
                                        }
                                    }
                                }
                            }

                            StyledText {
                                text: {
                                    var scheme = Theme.getMatugenScheme(SettingsData.matugenScheme)
                                    return scheme.description + " (" + scheme.value + ")"
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
            }

            // Transparency Settings
            StyledRect {
                width: parent.width
                height: transparencySection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: transparencySection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "opacity"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Widget Styling")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Dank Bar Transparency")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        DankSlider {
                            width: parent.width
                            height: 24
                            value: Math.round(
                                       SettingsData.dankBarTransparency * 100)
                            minimum: 0
                            maximum: 100
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainerHigh
                            onSliderValueChanged: newValue => {
                                                      SettingsData.setDankBarTransparency(
                                                          newValue / 100)
                                                  }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        Item {
                            width: parent.width
                            height: Math.max(transparencyLabel.height, widgetColorGroup.height)

                            StyledText {
                                id: transparencyLabel
                                text: I18n.tr("Dank Bar Widget Transparency")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            DankButtonGroup {
                                id: widgetColorGroup
                                property int currentColorIndex: {
                                    switch (SettingsData.widgetBackgroundColor) {
                                        case "sth": return 0
                                        case "s": return 1
                                        case "sc": return 2
                                        case "sch": return 3
                                        default: return 0
                                    }
                                }

                                model: ["sth", "s", "sc", "sch"]
                                currentIndex: currentColorIndex
                                selectionMode: "single"
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter

                                buttonHeight: 20
                                minButtonWidth: 32
                                buttonPadding: Theme.spacingS
                                checkIconSize: Theme.iconSizeSmall - 2
                                textSize: Theme.fontSizeSmall - 2
                                spacing: 1

                                onSelectionChanged: (index, selected) => {
                                    if (!selected) return
                                    const colorOptions = ["sth", "s", "sc", "sch"]
                                    SettingsData.setWidgetBackgroundColor(colorOptions[index])
                                }
                            }
                        }

                        DankSlider {
                            width: parent.width
                            height: 24
                            value: Math.round(
                                       SettingsData.dankBarWidgetTransparency * 100)
                            minimum: 0
                            maximum: 100
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainerHigh
                            onSliderValueChanged: newValue => {
                                                      SettingsData.setDankBarWidgetTransparency(
                                                          newValue / 100)
                                                  }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Popup Transparency")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        DankSlider {
                            width: parent.width
                            height: 24
                            value: Math.round(
                                       SettingsData.popupTransparency * 100)
                            minimum: 0
                            maximum: 100
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainerHigh
                            onSliderValueChanged: newValue => {
                                                      SettingsData.setPopupTransparency(
                                                          newValue / 100)
                                                  }
                        }
                    }


                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Corner Radius (0 = square corners)")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        DankSlider {
                            width: parent.width
                            height: 24
                            value: SettingsData.cornerRadius
                            minimum: 0
                            maximum: 32
                            unit: ""
                            showValue: true
                            wheelEnabled: false
                            thumbOutlineColor: Theme.surfaceContainerHigh
                            onSliderValueChanged: newValue => {
                                                      SettingsData.setCornerRadius(
                                                          newValue)
                                                  }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: fontSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: fontSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "font_download"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Font Settings")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankDropdown {
                        text: I18n.tr("Font Family")
                        description: I18n.tr("Select system font family")
                        currentValue: {
                            if (SettingsData.fontFamily === SettingsData.defaultFontFamily)
                                return "Default"
                            else
                                return SettingsData.fontFamily || "Default"
                        }
                        enableFuzzySearch: true
                        popupWidthOffset: 100
                        maxPopupHeight: 400
                        options: cachedFontFamilies
                        onValueChanged: value => {
                                            if (value.startsWith("Default"))
                                            SettingsData.setFontFamily(SettingsData.defaultFontFamily)
                                            else
                                            SettingsData.setFontFamily(value)
                                        }
                    }

                    DankDropdown {
                        text: I18n.tr("Font Weight")
                        description: I18n.tr("Select font weight")
                        currentValue: {
                            switch (SettingsData.fontWeight) {
                            case Font.Thin:
                                return "Thin"
                            case Font.ExtraLight:
                                return "Extra Light"
                            case Font.Light:
                                return "Light"
                            case Font.Normal:
                                return "Regular"
                            case Font.Medium:
                                return "Medium"
                            case Font.DemiBold:
                                return "Demi Bold"
                            case Font.Bold:
                                return "Bold"
                            case Font.ExtraBold:
                                return "Extra Bold"
                            case Font.Black:
                                return "Black"
                            default:
                                return "Regular"
                            }
                        }
                        options: ["Thin", "Extra Light", "Light", "Regular", "Medium", "Demi Bold", "Bold", "Extra Bold", "Black"]
                        onValueChanged: value => {
                                            var weight
                                            switch (value) {
                                                case "Thin":
                                                weight = Font.Thin
                                                break
                                                case "Extra Light":
                                                weight = Font.ExtraLight
                                                break
                                                case "Light":
                                                weight = Font.Light
                                                break
                                                case "Regular":
                                                weight = Font.Normal
                                                break
                                                case "Medium":
                                                weight = Font.Medium
                                                break
                                                case "Demi Bold":
                                                weight = Font.DemiBold
                                                break
                                                case "Bold":
                                                weight = Font.Bold
                                                break
                                                case "Extra Bold":
                                                weight = Font.ExtraBold
                                                break
                                                case "Black":
                                                weight = Font.Black
                                                break
                                                default:
                                                weight = Font.Normal
                                                break
                                            }
                                            SettingsData.setFontWeight(weight)
                                        }
                    }

                    DankDropdown {
                        text: I18n.tr("Monospace Font")
                        description: I18n.tr("Select monospace font for process list and technical displays")
                        currentValue: {
                            if (SettingsData.monoFontFamily === SettingsData.defaultMonoFontFamily)
                                return "Default"

                            return SettingsData.monoFontFamily || "Default"
                        }
                        enableFuzzySearch: true
                        popupWidthOffset: 100
                        maxPopupHeight: 400
                        options: cachedMonoFamilies
                        onValueChanged: value => {
                                            if (value === "Default")
                                            SettingsData.setMonoFontFamily(SettingsData.defaultMonoFontFamily)
                                            else
                                            SettingsData.setMonoFontFamily(value)
                                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 60
                        radius: Theme.cornerRadius
                        color: "transparent"

                        Column {
                            anchors.left: parent.left
                            anchors.right: fontScaleControls.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Font Scale")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Scale all font sizes")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                            }
                        }

                        Row {
                            id: fontScaleControls

                            width: 180
                            height: 36
                            anchors.right: parent.right
                            anchors.rightMargin: 0
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankActionButton {
                                buttonSize: 32
                                iconName: "remove"
                                iconSize: Theme.iconSizeSmall
                                enabled: SettingsData.fontScale > 1.0
                                backgroundColor: Theme.surfaceContainerHigh
                                iconColor: Theme.surfaceText
                                onClicked: {
                                    var newScale = Math.max(1.0, SettingsData.fontScale - 0.05)
                                    SettingsData.setFontScale(newScale)
                                }
                            }

                            StyledRect {
                                width: 60
                                height: 32
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh
                                border.color: Qt.rgba(Theme.outline.r,
                                                      Theme.outline.g,
                                                      Theme.outline.b, 0.2)
                                border.width: 0

                                StyledText {
                                    anchors.centerIn: parent
                                    text: (SettingsData.fontScale * 100).toFixed(
                                              0) + "%"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }
                            }

                            DankActionButton {
                                buttonSize: 32
                                iconName: "add"
                                iconSize: Theme.iconSizeSmall
                                enabled: SettingsData.fontScale < 2.0
                                backgroundColor: Theme.surfaceContainerHigh
                                iconColor: Theme.surfaceText
                                onClicked: {
                                    var newScale = Math.min(2.0,
                                                            SettingsData.fontScale + 0.05)
                                    SettingsData.setFontScale(newScale)
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: portalSyncSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Row {
                    id: portalSyncSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "sync"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - Theme.iconSize - Theme.spacingM - syncToggle.width - Theme.spacingM
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: I18n.tr("Sync Mode with Portal")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: I18n.tr("Sync dark mode with settings portals for system-wide theme hints")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }

                    DankToggle {
                        id: syncToggle

                        width: 48
                        height: 32
                        checked: SettingsData.syncModeWithPortal
                        anchors.verticalCenter: parent.verticalCenter
                        onToggled: checked => SettingsData.setSyncModeWithPortal(checked)
                    }
                }
            }

            // System Configuration Warning
            Rectangle {
                width: parent.width
                height: warningText.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.warning.r, Theme.warning.g,
                               Theme.warning.b, 0.12)
                border.color: Qt.rgba(Theme.warning.r, Theme.warning.g,
                                      Theme.warning.b, 0.3)
                border.width: 0

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

            // Icon Theme
            StyledRect {
                width: parent.width
                height: iconThemeSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: iconThemeSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: "image"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        DankDropdown {
                            width: parent.width - Theme.iconSize - Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Icon Theme")
                            description: "DankShell & System Icons\n(requires restart)"
                            currentValue: SettingsData.iconTheme
                            enableFuzzySearch: true
                            popupWidthOffset: 100
                            maxPopupHeight: 236
                            options: cachedIconThemes
                            onValueChanged: value => {
                                                SettingsData.setIconTheme(value)
                                                if (Quickshell.env("QT_QPA_PLATFORMTHEME") != "gtk3" &&
                                                    Quickshell.env("QT_QPA_PLATFORMTHEME") != "qt6ct" &&
                                                    Quickshell.env("QT_QPA_PLATFORMTHEME_QT6") != "qt6ct") {
                                                    ToastService.showError("Missing Environment Variables", "You need to set either:\nQT_QPA_PLATFORMTHEME=gtk3 OR\nQT_QPA_PLATFORMTHEME=qt6ct\nas environment variables, and then restart the shell.\n\nqt6ct requires qt6ct-kde to be installed.")
                                                }
                                            }
                        }
                    }
                }
            }

            // System App Theming
            StyledRect {
                width: parent.width
                height: systemThemingSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g,
                                      Theme.outline.b, 0.2)
                border.width: 0
                visible: Theme.matugenAvailable

                Column {
                    id: systemThemingSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "extension"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("System App Theming")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Rectangle {
                            width: (parent.width - Theme.spacingM) / 2
                            height: 48
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            border.color: Theme.primary
                            border.width: 0

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
                            border.color: Theme.primary
                            border.width: 0

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
                        text: `Generate baseline GTK3/4 or QT5/QT6 (requires qt6ct-kde) configurations to follow DMS colors. Only needed once.<br /><br />It is recommended to install <a href="https://github.com/AvengeMedia/DankMaterialShell/blob/master/README.md#Theming" style="text-decoration:none; color:${Theme.primary};">Colloid</a> GTK theme prior to applying GTK themes.`
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
    }

    FileBrowserModal {
        id: fileBrowserModal
        browserTitle: "Select Custom Theme"
        filterExtensions: ["*.json"]
        showHiddenFiles: true

        function selectCustomTheme() {
            shouldBeVisible = true
        }

        onFileSelected: function(filePath) {
            // Save the custom theme file path and switch to custom theme
            if (filePath.endsWith(".json")) {
                SettingsData.setCustomThemeFile(filePath)
                Theme.switchTheme("custom")
                close()
            }
        }
    }
}
