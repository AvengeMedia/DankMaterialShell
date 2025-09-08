import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Modals
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

Item {
    id: personalizationTab

    property alias wallpaperBrowser: wallpaperBrowser
    property var parentModal: null
    property var cachedFontFamilies: []
    property var cachedMonoFamilies: []
    property bool fontsEnumerated: false
    property string selectedMonitorName: {
        var screens = Quickshell.screens
        return screens.length > 0 ? screens[0].name : ""
    }

    function enumerateFonts() {
        var fonts = ["Default"]
        var availableFonts = Qt.fontFamilies()
        var rootFamilies = []
        var seenFamilies = new Set()
        for (var i = 0; i < availableFonts.length; i++) {
            var fontName = availableFonts[i]
            if (fontName.startsWith("."))
                continue

            if (fontName === SettingsData.defaultFontFamily)
                continue

            var rootName = fontName.replace(/ (Thin|Extra Light|Light|Regular|Medium|Semi Bold|Demi Bold|Bold|Extra Bold|Black|Heavy)$/i, "").replace(/ (Italic|Oblique|Condensed|Extended|Narrow|Wide)$/i,
                                                                                                                                                      "").replace(/ (UI|Display|Text|Mono|Sans|Serif)$/i, function (match, suffix) {
                                                                                                                                                          return match
                                                                                                                                                      }).trim()
            if (!seenFamilies.has(rootName) && rootName !== "") {
                seenFamilies.add(rootName)
                rootFamilies.push(rootName)
            }
        }
        cachedFontFamilies = fonts.concat(rootFamilies.sort())
        var monoFonts = ["Default"]
        var monoFamilies = []
        var seenMonoFamilies = new Set()
        for (var j = 0; j < availableFonts.length; j++) {
            var fontName2 = availableFonts[j]
            if (fontName2.startsWith("."))
                continue

            if (fontName2 === SettingsData.defaultMonoFontFamily)
                continue

            var lowerName = fontName2.toLowerCase()
            if (lowerName.includes("mono") || lowerName.includes("code") || lowerName.includes("console") || lowerName.includes("terminal") || lowerName.includes("courier") || lowerName.includes("dejavu sans mono") || lowerName.includes(
                        "jetbrains") || lowerName.includes("fira") || lowerName.includes("hack") || lowerName.includes("source code") || lowerName.includes("ubuntu mono") || lowerName.includes("cascadia")) {
                var rootName2 = fontName2.replace(/ (Thin|Extra Light|Light|Regular|Medium|Semi Bold|Demi Bold|Bold|Extra Bold|Black|Heavy)$/i, "").replace(/ (Italic|Oblique|Condensed|Extended|Narrow|Wide)$/i, "").trim()
                if (!seenMonoFamilies.has(rootName2) && rootName2 !== "") {
                    seenMonoFamilies.add(rootName2)
                    monoFamilies.push(rootName2)
                }
            }
        }
        cachedMonoFamilies = monoFonts.concat(monoFamilies.sort())
    }

    Component.onCompleted: {
        // Access WallpaperCyclingService to ensure it's initialized
        WallpaperCyclingService.cyclingActive
        if (!fontsEnumerated) {
            enumerateFonts()
            fontsEnumerated = true
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

            // Wallpaper Section
            StyledRect {
                width: parent.width
                height: wallpaperSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: wallpaperSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "wallpaper"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Wallpaper"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingL

                        StyledRect {
                            width: 160
                            height: 90
                            radius: Theme.cornerRadius
                            color: Theme.surfaceVariant
                            border.color: Theme.outline
                            border.width: 1

                            CachingImage {
                                anchors.fill: parent
                                anchors.margins: 1
                                source: {
                                    var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                    return (currentWallpaper !== "" && !currentWallpaper.startsWith("#")) ? "file://" + currentWallpaper : ""
                                }
                                fillMode: Image.PreserveAspectCrop
                                visible: {
                                    var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                    return currentWallpaper !== "" && !currentWallpaper.startsWith("#")
                                }
                                maxCacheSize: 160
                                layer.enabled: true

                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: wallpaperMask
                                    maskThresholdMin: 0.5
                                    maskSpreadAtMin: 1
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: Theme.cornerRadius - 1
                                color: {
                                    var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                    return currentWallpaper.startsWith("#") ? currentWallpaper : "transparent"
                                }
                                visible: {
                                    var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                    return currentWallpaper !== "" && currentWallpaper.startsWith("#")
                                }
                            }

                            Rectangle {
                                id: wallpaperMask

                                anchors.fill: parent
                                anchors.margins: 1
                                radius: Theme.cornerRadius - 1
                                color: "black"
                                visible: false
                                layer.enabled: true
                            }

                            DankIcon {
                                anchors.centerIn: parent
                                name: "image"
                                size: Theme.iconSizeLarge + 8
                                color: Theme.surfaceVariantText
                                visible: {
                                    var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                    return currentWallpaper === ""
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: Theme.cornerRadius - 1
                                color: Qt.rgba(0, 0, 0, 0.7)
                                visible: wallpaperMouseArea.containsMouse

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: Qt.rgba(255, 255, 255, 0.9)

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "folder_open"
                                            size: 18
                                            color: "black"
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (parentModal) {
                                                    parentModal.allowFocusOverride = true
                                                    parentModal.shouldHaveFocus = false
                                                }
                                                wallpaperBrowser.open()
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: Qt.rgba(255, 255, 255, 0.9)

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "palette"
                                            size: 18
                                            color: "black"
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                colorPicker.open()
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: Qt.rgba(255, 255, 255, 0.9)
                                        visible: {
                                            var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                            return currentWallpaper !== ""
                                        }

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "clear"
                                            size: 18
                                            color: "black"
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (SessionData.perMonitorWallpaper) {
                                                    SessionData.setMonitorWallpaper(selectedMonitorName, "")
                                                } else {
                                                    if (Theme.currentTheme === Theme.dynamic)
                                                        Theme.switchTheme("blue")
                                                    SessionData.clearWallpaper()
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: wallpaperMouseArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                propagateComposedEvents: true
                                acceptedButtons: Qt.NoButton
                            }
                        }

                        Column {
                            width: parent.width - 160 - Theme.spacingL
                            spacing: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: {
                                    var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                    return currentWallpaper ? currentWallpaper.split('/').pop() : "No wallpaper selected"
                                }
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.surfaceText
                                elide: Text.ElideMiddle
                                maximumLineCount: 1
                                width: parent.width
                            }

                            StyledText {
                                text: {
                                    var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                    return currentWallpaper ? currentWallpaper : ""
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideMiddle
                                maximumLineCount: 1
                                width: parent.width
                                visible: {
                                    var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                    return currentWallpaper !== ""
                                }
                            }

                            Row {
                                spacing: Theme.spacingS
                                visible: {
                                    var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                    return currentWallpaper !== ""
                                }

                                DankActionButton {
                                    buttonSize: 32
                                    iconName: "skip_previous"
                                    iconSize: Theme.iconSizeSmall
                                    enabled: {
                                        var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                        return currentWallpaper && !currentWallpaper.startsWith("#")
                                    }
                                    opacity: {
                                        var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                        return (currentWallpaper && !currentWallpaper.startsWith("#")) ? 1 : 0.5
                                    }
                                    backgroundColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                                    iconColor: Theme.surfaceText
                                    onClicked: {
                                        if (SessionData.perMonitorWallpaper) {
                                            WallpaperCyclingService.cyclePrevForMonitor(selectedMonitorName)
                                        } else {
                                            WallpaperCyclingService.cyclePrevManually()
                                        }
                                    }
                                }

                                DankActionButton {
                                    buttonSize: 32
                                    iconName: "skip_next"
                                    iconSize: Theme.iconSizeSmall
                                    enabled: {
                                        var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                        return currentWallpaper && !currentWallpaper.startsWith("#")
                                    }
                                    opacity: {
                                        var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                        return (currentWallpaper && !currentWallpaper.startsWith("#")) ? 1 : 0.5
                                    }
                                    backgroundColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                                    iconColor: Theme.surfaceText
                                    onClicked: {
                                        if (SessionData.perMonitorWallpaper) {
                                            WallpaperCyclingService.cycleNextForMonitor(selectedMonitorName)
                                        } else {
                                            WallpaperCyclingService.cycleNextManually()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Per-Monitor Wallpaper Section - Full Width
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                        visible: SessionData.wallpaperPath !== ""
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: SessionData.wallpaperPath !== ""

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "monitor"
                                size: Theme.iconSize
                                color: SessionData.perMonitorWallpaper ? Theme.primary : Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - Theme.iconSize - Theme.spacingM - perMonitorToggle.width - Theme.spacingM
                                spacing: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    text: "Per-Monitor Wallpapers"
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    text: "Set different wallpapers for each connected monitor"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: parent.width
                                }
                            }

                            DankToggle {
                                id: perMonitorToggle

                                anchors.verticalCenter: parent.verticalCenter
                                checked: SessionData.perMonitorWallpaper
                                onToggled: toggled => {
                                               return SessionData.setPerMonitorWallpaper(toggled)
                                           }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS
                            visible: SessionData.perMonitorWallpaper
                            leftPadding: Theme.iconSize + Theme.spacingM

                            StyledText {
                                text: "Monitor Selection:"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            DankDropdown {
                                id: monitorDropdown

                                width: parent.width - parent.leftPadding
                                text: "Monitor"
                                description: "Select monitor to configure wallpaper"
                                currentValue: selectedMonitorName || "No monitors"
                                options: {
                                    var screenNames = []
                                    var screens = Quickshell.screens
                                    for (var i = 0; i < screens.length; i++) {
                                        screenNames.push(screens[i].name)
                                    }
                                    return screenNames
                                }
                                onValueChanged: value => {
                                                    selectedMonitorName = value
                                                }
                            }
                        }
                    }

                    // Wallpaper Cycling Section - Full Width
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                        visible: SessionData.wallpaperPath !== "" && !SessionData.perMonitorWallpaper
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: SessionData.wallpaperPath !== "" && !SessionData.perMonitorWallpaper

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "schedule"
                                size: Theme.iconSize
                                color: SessionData.wallpaperCyclingEnabled ? Theme.primary : Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - Theme.iconSize - Theme.spacingM - cyclingToggle.width - Theme.spacingM
                                spacing: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    text: "Automatic Cycling"
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    text: "Automatically cycle through wallpapers in the same folder"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: parent.width
                                }
                            }

                            DankToggle {
                                id: cyclingToggle

                                anchors.verticalCenter: parent.verticalCenter
                                checked: SessionData.wallpaperCyclingEnabled
                                enabled: !SessionData.perMonitorWallpaper
                                onToggled: toggled => {
                                               return SessionData.setWallpaperCyclingEnabled(toggled)
                                           }
                            }
                        }

                        // Cycling mode and settings
                        Column {
                            width: parent.width
                            spacing: Theme.spacingS
                            visible: SessionData.wallpaperCyclingEnabled
                            leftPadding: Theme.iconSize + Theme.spacingM

                            Row {
                                spacing: Theme.spacingL
                                width: parent.width - parent.leftPadding

                                StyledText {
                                    text: "Mode:"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                DankTabBar {
                                    id: modeTabBar

                                    width: 200
                                    height: 32
                                    model: [{
                                            "text": "Interval",
                                            "icon": "schedule"
                                        }, {
                                            "text": "Time",
                                            "icon": "access_time"
                                        }]
                                    currentIndex: SessionData.wallpaperCyclingMode === "time" ? 1 : 0
                                    onTabClicked: index => {
                                                      SessionData.setWallpaperCyclingMode(index === 1 ? "time" : "interval")
                                                  }
                                }
                            }

                            // Interval settings
                            DankDropdown {
                                property var intervalOptions: ["1 minute", "5 minutes", "15 minutes", "30 minutes", "1 hour", "1.5 hours", "2 hours", "3 hours", "4 hours", "6 hours", "8 hours", "12 hours"]
                                property var intervalValues: [60, 300, 900, 1800, 3600, 5400, 7200, 10800, 14400, 21600, 28800, 43200]

                                width: parent.width - parent.leftPadding
                                visible: SessionData.wallpaperCyclingMode === "interval"
                                text: "Interval"
                                description: "How often to change wallpaper"
                                options: intervalOptions
                                currentValue: {
                                    const currentSeconds = SessionData.wallpaperCyclingInterval
                                    const index = intervalValues.indexOf(currentSeconds)
                                    return index >= 0 ? intervalOptions[index] : "5 minutes"
                                }
                                onValueChanged: value => {
                                                    const index = intervalOptions.indexOf(value)
                                                    if (index >= 0)
                                                    SessionData.setWallpaperCyclingInterval(intervalValues[index])
                                                }
                            }

                            // Time settings
                            Row {
                                spacing: Theme.spacingM
                                visible: SessionData.wallpaperCyclingMode === "time"
                                width: parent.width - parent.leftPadding

                                StyledText {
                                    text: "Daily at:"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                DankTextField {
                                    width: 100
                                    height: 40
                                    text: SessionData.wallpaperCyclingTime
                                    placeholderText: "00:00"
                                    maximumLength: 5
                                    topPadding: Theme.spacingS
                                    bottomPadding: Theme.spacingS
                                    onAccepted: {
                                        var isValid = /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/.test(text)
                                        if (isValid)
                                            SessionData.setWallpaperCyclingTime(text)
                                        else
                                            text = SessionData.wallpaperCyclingTime
                                    }
                                    onEditingFinished: {
                                        var isValid = /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/.test(text)
                                        if (isValid)
                                            SessionData.setWallpaperCyclingTime(text)
                                        else
                                            text = SessionData.wallpaperCyclingTime
                                    }
                                    anchors.verticalCenter: parent.verticalCenter

                                    validator: RegularExpressionValidator {
                                        regularExpression: /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/
                                    }
                                }

                                StyledText {
                                    text: "24-hour format"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }

            // Dynamic Theme Section
            StyledRect {
                width: parent.width
                height: dynamicThemeSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: dynamicThemeSection

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

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM - toggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: "Dynamic Theming"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Automatically extract colors from wallpaper"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: toggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: Theme.wallpaperPath !== "" && Theme.currentTheme === Theme.dynamic
                            enabled: ToastService.wallpaperErrorStatus !== "matugen_missing" && Theme.wallpaperPath !== ""
                            onToggled: toggled => {
                                           if (toggled)
                                           Theme.switchTheme(Theme.dynamic)
                                           else
                                           Theme.switchTheme("blue")
                                       }
                        }
                    }

                    StyledText {
                        text: "matugen not detected - dynamic theming unavailable"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.error
                        visible: ToastService.wallpaperErrorStatus === "matugen_missing"
                        width: parent.width
                        leftPadding: Theme.iconSize + Theme.spacingM
                    }
                }
            }

            // Display Settings
            StyledRect {
                width: parent.width
                height: displaySection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

                Column {
                    id: displaySection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "monitor"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Display Settings"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        width: parent.width
                        text: "Light Mode"
                        description: "Use light theme instead of dark theme"
                        checked: SessionData.isLightMode
                        onToggled: checked => {
                                       Theme.setLightMode(checked)
                                   }
                    }

                    DankToggle {
                        width: parent.width
                        text: "Hide Brightness Slider"
                        description: "Hide the brightness slider in Control Center and make audio slider full width"
                        checked: SettingsData.hideBrightnessSlider
                        onToggled: checked => {
                                       SettingsData.setHideBrightnessSlider(checked)
                                   }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                    }

                    DankToggle {
                        id: nightModeToggle

                        width: parent.width
                        text: "Night Mode"
                        description: "Apply warm color temperature to reduce eye strain. Use automation settings below to control when it activates."
                        checked: DisplayService.nightModeEnabled
                        onToggled: checked => {
                                       DisplayService.toggleNightMode()
                                   }

                        Connections {
                            function onNightModeEnabledChanged() {
                                nightModeToggle.checked = DisplayService.nightModeEnabled
                            }

                            target: DisplayService
                        }
                    }

                    DankDropdown {
                        width: parent.width
                        text: "Temperature"
                        description: "Color temperature for night mode"
                        currentValue: SessionData.nightModeTemperature + "K"
                        options: {
                            var temps = []
                            for (var i = 2500; i <= 6000; i += 500) {
                                temps.push(i + "K")
                            }
                            return temps
                        }
                        onValueChanged: value => {
                                            var temp = parseInt(value.replace("K", ""))
                                            SessionData.setNightModeTemperature(temp)
                                        }
                    }

                    DankToggle {
                        id: automaticToggle
                        width: parent.width
                        text: "Automatic Control"
                        description: "Only adjust gamma based on time or location rules."
                        checked: SessionData.nightModeAutoEnabled
                        onToggled: checked => {
                                       if (checked && !DisplayService.nightModeEnabled) {
                                           DisplayService.toggleNightMode()
                                       } else if (!checked && DisplayService.nightModeEnabled) {
                                           DisplayService.toggleNightMode()
                                       }
                                       SessionData.setNightModeAutoEnabled(checked)
                                   }

                        Connections {
                            target: SessionData
                            function onNightModeAutoEnabledChanged() {
                                automaticToggle.checked = SessionData.nightModeAutoEnabled
                            }
                        }
                    }

                    Column {
                        id: automaticSettings
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: SessionData.nightModeAutoEnabled
                        leftPadding: Theme.spacingM

                        Connections {
                            target: SessionData
                            function onNightModeAutoEnabledChanged() {
                                automaticSettings.visible = SessionData.nightModeAutoEnabled
                            }
                        }

                        DankTabBar {
                            id: modeTabBarNight
                            width: 200
                            height: 32
                            model: [{
                                    "text": "Time",
                                    "icon": "access_time"
                                }, {
                                    "text": "Location",
                                    "icon": "place"
                                }]

                            Component.onCompleted: {
                                currentIndex = SessionData.nightModeAutoMode === "location" ? 1 : 0
                            }

                            onTabClicked: index => {
                                              console.log("Tab clicked:", index, "Setting mode to:", index === 1 ? "location" : "time")
                                              DisplayService.setNightModeAutomationMode(index === 1 ? "location" : "time")
                                              currentIndex = index
                                          }
                        }

                        Column {
                            property bool isTimeMode: SessionData.nightModeAutoMode === "time"
                            visible: isTimeMode
                            spacing: Theme.spacingM

                            // Header row
                            Row {
                                spacing: Theme.spacingM
                                height: 20
                                leftPadding: 45

                                StyledText {
                                    text: "Hour"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: 50
                                    horizontalAlignment: Text.AlignHCenter
                                    anchors.bottom: parent.bottom
                                }

                                StyledText {
                                    text: "Minute"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: 50
                                    horizontalAlignment: Text.AlignHCenter
                                    anchors.bottom: parent.bottom
                                }
                            }

                            // Start time row
                            Row {
                                spacing: Theme.spacingM
                                height: 32

                                StyledText {
                                    id: startLabel
                                    text: "Start"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    width: 50
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                DankDropdown {
                                    width: 60
                                    height: 32
                                    text: ""
                                    currentValue: SessionData.nightModeStartHour.toString()
                                    options: {
                                        var hours = []
                                        for (var i = 0; i < 24; i++) {
                                            hours.push(i.toString())
                                        }
                                        return hours
                                    }
                                    onValueChanged: value => {
                                                        SessionData.setNightModeStartHour(parseInt(value))
                                                    }
                                }

                                DankDropdown {
                                    width: 60
                                    height: 32
                                    text: ""
                                    currentValue: SessionData.nightModeStartMinute.toString().padStart(2, '0')
                                    options: {
                                        var minutes = []
                                        for (var i = 0; i < 60; i += 5) {
                                            minutes.push(i.toString().padStart(2, '0'))
                                        }
                                        return minutes
                                    }
                                    onValueChanged: value => {
                                                        SessionData.setNightModeStartMinute(parseInt(value))
                                                    }
                                }
                            }

                            // End time row
                            Row {
                                spacing: Theme.spacingM
                                height: 32

                                StyledText {
                                    text: "End"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    width: startLabel.width
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                DankDropdown {
                                    width: 60
                                    height: 32
                                    text: ""
                                    currentValue: SessionData.nightModeEndHour.toString()
                                    options: {
                                        var hours = []
                                        for (var i = 0; i < 24; i++) {
                                            hours.push(i.toString())
                                        }
                                        return hours
                                    }
                                    onValueChanged: value => {
                                                        SessionData.setNightModeEndHour(parseInt(value))
                                                    }
                                }

                                DankDropdown {
                                    width: 60
                                    height: 32
                                    text: ""
                                    currentValue: SessionData.nightModeEndMinute.toString().padStart(2, '0')
                                    options: {
                                        var minutes = []
                                        for (var i = 0; i < 60; i += 5) {
                                            minutes.push(i.toString().padStart(2, '0'))
                                        }
                                        return minutes
                                    }
                                    onValueChanged: value => {
                                                        SessionData.setNightModeEndMinute(parseInt(value))
                                                    }
                                }
                            }
                        }

                        Column {
                            property bool isLocationMode: SessionData.nightModeAutoMode === "location"
                            visible: isLocationMode
                            spacing: Theme.spacingM
                            width: parent.width

                            DankToggle {
                                width: parent.width
                                text: "Auto-location"
                                description: DisplayService.geoclueAvailable ? "Use automatic location detection (geoclue2)" : "Geoclue service not running - cannot auto-detect location"
                                checked: SessionData.nightModeLocationProvider === "geoclue2"
                                enabled: DisplayService.geoclueAvailable
                                onToggled: checked => {
                                               if (checked && DisplayService.geoclueAvailable) {
                                                   SessionData.setNightModeLocationProvider("geoclue2")
                                                   SessionData.setLatitude(0.0)
                                                   SessionData.setLongitude(0.0)
                                               } else {
                                                   SessionData.setNightModeLocationProvider("")
                                               }
                                           }
                            }

                            StyledText {
                                text: "Manual Coordinates"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                visible: SessionData.nightModeLocationProvider !== "geoclue2"
                            }

                            Row {
                                spacing: Theme.spacingM
                                visible: SessionData.nightModeLocationProvider !== "geoclue2"

                                Column {
                                    spacing: Theme.spacingXS

                                    StyledText {
                                        text: "Latitude"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    DankTextField {
                                        width: 120
                                        height: 40
                                        text: SessionData.latitude.toString()
                                        placeholderText: "0.0"
                                        onTextChanged: {
                                            const lat = parseFloat(text) || 0.0
                                            if (lat >= -90 && lat <= 90) {
                                                SessionData.setLatitude(lat)
                                            }
                                        }
                                    }
                                }

                                Column {
                                    spacing: Theme.spacingXS

                                    StyledText {
                                        text: "Longitude"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    DankTextField {
                                        width: 120
                                        height: 40
                                        text: SessionData.longitude.toString()
                                        placeholderText: "0.0"
                                        onTextChanged: {
                                            const lon = parseFloat(text) || 0.0
                                            if (lon >= -180 && lon <= 180) {
                                                SessionData.setLongitude(lon)
                                            }
                                        }
                                    }
                                }
                            }

                            StyledText {
                                text: "Uses sunrise/sunset times to automatically adjust night mode based on your location."
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            // Lock Screen Settings
            StyledRect {
                width: parent.width
                height: lockScreenSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

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
                            text: "Lock Screen"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        width: parent.width
                        text: "Show Power Actions"
                        description: "Show power, restart, and logout buttons on the lock screen"
                        checked: SettingsData.lockScreenShowPowerActions
                        onToggled: checked => {
                                       SettingsData.setLockScreenShowPowerActions(checked)
                                   }
                    }
                }
            }

            // Font Settings
            StyledRect {
                width: parent.width
                height: fontSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 1

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
                            text: "Font Settings"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankDropdown {
                        width: parent.width
                        text: "Font Family"
                        description: "Select system font family"
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
                        width: parent.width
                        text: "Font Weight"
                        description: "Select font weight"
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
                        width: parent.width
                        text: "Monospace Font"
                        description: "Select monospace font for process list and technical displays"
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

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            width: parent.width - fontScaleControls.width - Theme.spacingM
                            spacing: Theme.spacingXS

                            StyledText {
                                text: "Font Scale"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: "Scale all font sizes (" + (SettingsData.fontScale * 100).toFixed(0) + "%)"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                            }
                        }

                        Row {
                            id: fontScaleControls

                            spacing: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter

                            DankActionButton {
                                buttonSize: 32
                                iconName: "remove"
                                iconSize: Theme.iconSizeSmall
                                enabled: SettingsData.fontScale > 1.0
                                backgroundColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
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
                                color: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                border.width: 1

                                StyledText {
                                    anchors.centerIn: parent
                                    text: (SettingsData.fontScale * 100).toFixed(0) + "%"
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
                                backgroundColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.5)
                                iconColor: Theme.surfaceText
                                onClicked: {
                                    var newScale = Math.min(2.0, SettingsData.fontScale + 0.05)
                                    SettingsData.setFontScale(newScale)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    FileBrowserModal {
        id: wallpaperBrowser

        browserTitle: "Select Wallpaper"
        browserIcon: "wallpaper"
        browserType: "wallpaper"
        fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp"]
        onFileSelected: path => {
                            if (SessionData.perMonitorWallpaper) {
                                SessionData.setMonitorWallpaper(selectedMonitorName, path)
                            } else {
                                SessionData.setWallpaper(path)
                            }
                            close()
                        }
        onDialogClosed: {
            if (parentModal) {
                parentModal.allowFocusOverride = false
                parentModal.shouldHaveFocus = Qt.binding(() => {
                                                             return parentModal.shouldBeVisible
                                                         })
            }
        }
    }

    DankColorPicker {
        id: colorPicker

        pickerTitle: "Choose Wallpaper Color"
        onColorSelected: selectedColor => {
                             if (SessionData.perMonitorWallpaper) {
                                 SessionData.setMonitorWallpaper(selectedMonitorName, selectedColor)
                             } else {
                                 SessionData.setWallpaperColor(selectedColor)
                             }
                         }
    }
}
