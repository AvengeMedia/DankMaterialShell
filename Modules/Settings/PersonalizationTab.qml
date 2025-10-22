import QtCore
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

    property var wallpaperBrowser: wallpaperBrowserLoader.item
    property var parentModal: null
    property var cachedFontFamilies: []
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
    }

    Timer {
        id: fontEnumerationTimer
        interval: 50
        running: false
        onTriggered: {
            if (!fontsEnumerated) {
                enumerateFonts()
                fontsEnumerated = true
            }
        }
    }

    Component.onCompleted: {
        WallpaperCyclingService.cyclingActive
        fontEnumerationTimer.start()
        if (AudioService.gsettingsAvailable) {
            AudioService.scanSoundThemes()
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
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

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
                            text: I18n.tr("Wallpaper")
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
                            border.width: 0

                            CachingImage {
                                anchors.fill: parent
                                anchors.margins: 1
                                property var weExtensions: [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tga"]
                                property int weExtIndex: 0
                                source: {
                                    var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                    if (currentWallpaper && currentWallpaper.startsWith("we:")) {
                                        var sceneId = currentWallpaper.substring(3)
                                        return StandardPaths.writableLocation(StandardPaths.HomeLocation)
                                            + "/.local/share/Steam/steamapps/workshop/content/431960/"
                                            + sceneId + "/preview" + weExtensions[weExtIndex]
                                    }
                                    return (currentWallpaper !== "" && !currentWallpaper.startsWith("#")) ? "file://" + currentWallpaper : ""
                                }
                                onStatusChanged: {
                                    var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                    if (currentWallpaper && currentWallpaper.startsWith("we:") && status === Image.Error) {
                                        if (weExtIndex < weExtensions.length - 1) {
                                            weExtIndex++
                                            source = StandardPaths.writableLocation(StandardPaths.HomeLocation)
                                                + "/.local/share/Steam/steamapps/workshop/content/431960/"
                                                + currentWallpaper.substring(3)
                                                + "/preview" + weExtensions[weExtIndex]
                                        } else {
                                            visible = false
                                        }
                                    }
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
                                                wallpaperBrowserLoader.active = true
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
                                                if (PopoutService.colorPickerModal) {
                                                    var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                                    PopoutService.colorPickerModal.selectedColor = currentWallpaper.startsWith("#") ? currentWallpaper : Theme.primary
                                                    PopoutService.colorPickerModal.pickerTitle = "Choose Wallpaper Color"
                                                    PopoutService.colorPickerModal.onColorSelectedCallback = function(selectedColor) {
                                                        if (SessionData.perMonitorWallpaper) {
                                                            SessionData.setMonitorWallpaper(selectedMonitorName, selectedColor)
                                                        } else {
                                                            SessionData.setWallpaperColor(selectedColor)
                                                        }
                                                    }
                                                    PopoutService.colorPickerModal.show()
                                                }
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
                                        return currentWallpaper && !currentWallpaper.startsWith("#") && !currentWallpaper.startsWith("we")
                                    }
                                    opacity: {
                                        var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                        return (currentWallpaper && !currentWallpaper.startsWith("#") && !currentWallpaper.startsWith("we")) ? 1 : 0.5
                                    }
                                    backgroundColor: Theme.surfaceContainerHigh
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
                                        return currentWallpaper && !currentWallpaper.startsWith("#") && !currentWallpaper.startsWith("we")
                                    }
                                    opacity: {
                                        var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                                        return (currentWallpaper && !currentWallpaper.startsWith("#") && !currentWallpaper.startsWith("we")) ? 1 : 0.5
                                    }
                                    backgroundColor: Theme.surfaceContainerHigh
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

                    Item {
                        width: parent.width
                        height: fillModeGroup.height
                        visible: {
                            var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath
                            return currentWallpaper !== "" && !currentWallpaper.startsWith("#")
                        }

                        DankButtonGroup {
                            id: fillModeGroup
                            anchors.horizontalCenter: parent.horizontalCenter
                            model: ["Stretch", "Fit", "Fill", "Tile", "Tile V", "Tile H", "Pad"]
                            selectionMode: "single"
                            buttonHeight: 28
                            minButtonWidth: 48
                            buttonPadding: Theme.spacingS
                            checkIconSize: 0
                            textSize: Theme.fontSizeSmall
                            checkEnabled: false
                            currentIndex: {
                                const modes = ["Stretch", "Fit", "Fill", "Tile", "TileVertically", "TileHorizontally", "Pad"]
                                return modes.indexOf(SettingsData.wallpaperFillMode)
                            }
                            onSelectionChanged: (index, selected) => {
                                if (selected) {
                                    const modes = ["Stretch", "Fit", "Fill", "Tile", "TileVertically", "TileHorizontally", "Pad"]
                                    SettingsData.setWallpaperFillMode(modes[index])
                                }
                            }

                            Connections {
                                target: SettingsData
                                function onWallpaperFillModeChanged() {
                                    const modes = ["Stretch", "Fit", "Fill", "Tile", "TileVertically", "TileHorizontally", "Pad"]
                                    fillModeGroup.currentIndex = modes.indexOf(SettingsData.wallpaperFillMode)
                                }
                            }

                            Connections {
                                target: personalizationTab
                                function onSelectedMonitorNameChanged() {
                                    Qt.callLater(() => {
                                        const modes = ["Stretch", "Fit", "Fill", "Tile", "TileVertically", "TileHorizontally", "Pad"]
                                        fillModeGroup.currentIndex = modes.indexOf(SettingsData.wallpaperFillMode)
                                    })
                                }
                            }
                        }
                    }

                    // Per-Mode Wallpaper Section - Full Width
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
                                name: "brightness_6"
                                size: Theme.iconSize
                                color: SessionData.perModeWallpaper ? Theme.primary : Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - Theme.iconSize - Theme.spacingM - perModeToggle.width - Theme.spacingM
                                spacing: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    text: I18n.tr("Per-Mode Wallpapers")
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    text: I18n.tr("Set different wallpapers for light and dark mode")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: parent.width
                                }
                            }

                            DankToggle {
                                id: perModeToggle

                                anchors.verticalCenter: parent.verticalCenter
                                checked: SessionData.perModeWallpaper
                                onToggled: toggled => {
                                               return SessionData.setPerModeWallpaper(toggled)
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
                                    text: I18n.tr("Per-Monitor Wallpapers")
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    text: I18n.tr("Set different wallpapers for each connected monitor")
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
                            width: parent.width - (Theme.iconSize + Theme.spacingM)
                            spacing: Theme.spacingS
                            visible: SessionData.perMonitorWallpaper
                            leftPadding: Theme.iconSize + Theme.spacingM

                            StyledText {
                                text: I18n.tr("Monitor Selection:")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            DankDropdown {
                                id: monitorDropdown

                                text: I18n.tr("Monitor")
                                description: I18n.tr("Select monitor to configure wallpaper")
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

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                        visible: (SessionData.wallpaperPath !== "" || SessionData.perMonitorWallpaper) && !SessionData.perModeWallpaper
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: (SessionData.wallpaperPath !== "" || SessionData.perMonitorWallpaper) && !SessionData.perModeWallpaper

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
                                    text: I18n.tr("Automatic Cycling")
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    text: I18n.tr("Automatically cycle through wallpapers in the same folder")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: parent.width
                                }
                            }

                            DankToggle {
                                id: cyclingToggle

                                anchors.verticalCenter: parent.verticalCenter
                                checked: SessionData.perMonitorWallpaper ? SessionData.getMonitorCyclingSettings(selectedMonitorName).enabled : SessionData.wallpaperCyclingEnabled
                                onToggled: toggled => {
                                               if (SessionData.perMonitorWallpaper) {
                                                   return SessionData.setMonitorCyclingEnabled(selectedMonitorName, toggled)
                                               } else {
                                                   return SessionData.setWallpaperCyclingEnabled(toggled)
                                               }
                                           }

                                Connections {
                                    target: personalizationTab
                                    function onSelectedMonitorNameChanged() {
                                        cyclingToggle.checked = Qt.binding(() => {
                                            return SessionData.perMonitorWallpaper ? SessionData.getMonitorCyclingSettings(selectedMonitorName).enabled : SessionData.wallpaperCyclingEnabled
                                        })
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS
                            visible: SessionData.perMonitorWallpaper ? SessionData.getMonitorCyclingSettings(selectedMonitorName).enabled : SessionData.wallpaperCyclingEnabled
                            leftPadding: Theme.iconSize + Theme.spacingM

                            Row {
                                spacing: Theme.spacingL
                                width: parent.width - parent.leftPadding

                                StyledText {
                                    text: I18n.tr("Mode:")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Item {
                                    width: 200
                                    height: 45 + Theme.spacingM

                                    DankTabBar {
                                        id: modeTabBar

                                        width: 200
                                        height: 45
                                        model: [{
                                                "text": "Interval",
                                                "icon": "schedule"
                                            }, {
                                                "text": "Time",
                                                "icon": "access_time"
                                            }]
                                        currentIndex: {
                                            if (SessionData.perMonitorWallpaper) {
                                                return SessionData.getMonitorCyclingSettings(selectedMonitorName).mode === "time" ? 1 : 0
                                            } else {
                                                return SessionData.wallpaperCyclingMode === "time" ? 1 : 0
                                            }
                                        }
                                        onTabClicked: index => {
                                                          if (SessionData.perMonitorWallpaper) {
                                                              SessionData.setMonitorCyclingMode(selectedMonitorName, index === 1 ? "time" : "interval")
                                                          } else {
                                                              SessionData.setWallpaperCyclingMode(index === 1 ? "time" : "interval")
                                                          }
                                                      }

                                        Connections {
                                            target: personalizationTab
                                            function onSelectedMonitorNameChanged() {
                                                modeTabBar.currentIndex = Qt.binding(() => {
                                                    if (SessionData.perMonitorWallpaper) {
                                                        return SessionData.getMonitorCyclingSettings(selectedMonitorName).mode === "time" ? 1 : 0
                                                    } else {
                                                        return SessionData.wallpaperCyclingMode === "time" ? 1 : 0
                                                    }
                                                })
                                                Qt.callLater(modeTabBar.updateIndicator)
                                            }
                                        }
                                    }
                                }
                            }

                            // Interval settings
                            DankDropdown {
                                id: intervalDropdown
                                property var intervalOptions: ["1 minute", "5 minutes", "15 minutes", "30 minutes", "1 hour", "1.5 hours", "2 hours", "3 hours", "4 hours", "6 hours", "8 hours", "12 hours"]
                                property var intervalValues: [60, 300, 900, 1800, 3600, 5400, 7200, 10800, 14400, 21600, 28800, 43200]

                                width: parent.width - parent.leftPadding
                                visible: {
                                    if (SessionData.perMonitorWallpaper) {
                                        return SessionData.getMonitorCyclingSettings(selectedMonitorName).mode === "interval"
                                    } else {
                                        return SessionData.wallpaperCyclingMode === "interval"
                                    }
                                }
                                text: I18n.tr("Interval")
                                description: I18n.tr("How often to change wallpaper")
                                options: intervalOptions
                                currentValue: {
                                    var currentSeconds
                                    if (SessionData.perMonitorWallpaper) {
                                        currentSeconds = SessionData.getMonitorCyclingSettings(selectedMonitorName).interval
                                    } else {
                                        currentSeconds = SessionData.wallpaperCyclingInterval
                                    }
                                    const index = intervalValues.indexOf(currentSeconds)
                                    return index >= 0 ? intervalOptions[index] : "5 minutes"
                                }
                                onValueChanged: value => {
                                                    const index = intervalOptions.indexOf(value)
                                                    if (index >= 0) {
                                                        if (SessionData.perMonitorWallpaper) {
                                                            SessionData.setMonitorCyclingInterval(selectedMonitorName, intervalValues[index])
                                                        } else {
                                                            SessionData.setWallpaperCyclingInterval(intervalValues[index])
                                                        }
                                                    }
                                                }

                                Connections {
                                    target: personalizationTab
                                    function onSelectedMonitorNameChanged() {
                                        // Force dropdown to refresh its currentValue
                                        Qt.callLater(() => {
                                            var currentSeconds
                                            if (SessionData.perMonitorWallpaper) {
                                                currentSeconds = SessionData.getMonitorCyclingSettings(selectedMonitorName).interval
                                            } else {
                                                currentSeconds = SessionData.wallpaperCyclingInterval
                                            }
                                            const index = intervalDropdown.intervalValues.indexOf(currentSeconds)
                                            intervalDropdown.currentValue = index >= 0 ? intervalDropdown.intervalOptions[index] : "5 minutes"
                                        })
                                    }
                                }
                            }

                            // Time settings
                            Row {
                                spacing: Theme.spacingM
                                visible: {
                                    if (SessionData.perMonitorWallpaper) {
                                        return SessionData.getMonitorCyclingSettings(selectedMonitorName).mode === "time"
                                    } else {
                                        return SessionData.wallpaperCyclingMode === "time"
                                    }
                                }
                                width: parent.width - parent.leftPadding

                                StyledText {
                                    text: I18n.tr("Daily at:")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                DankTextField {
                                    id: timeTextField
                                    width: 100
                                    height: 40
                                    text: {
                                        if (SessionData.perMonitorWallpaper) {
                                            return SessionData.getMonitorCyclingSettings(selectedMonitorName).time
                                        } else {
                                            return SessionData.wallpaperCyclingTime
                                        }
                                    }
                                    placeholderText: "00:00"
                                    maximumLength: 5
                                    topPadding: Theme.spacingS
                                    bottomPadding: Theme.spacingS
                                    onAccepted: {
                                        var isValid = /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/.test(text)
                                        if (isValid) {
                                            if (SessionData.perMonitorWallpaper) {
                                                SessionData.setMonitorCyclingTime(selectedMonitorName, text)
                                            } else {
                                                SessionData.setWallpaperCyclingTime(text)
                                            }
                                        } else {
                                            if (SessionData.perMonitorWallpaper) {
                                                text = SessionData.getMonitorCyclingSettings(selectedMonitorName).time
                                            } else {
                                                text = SessionData.wallpaperCyclingTime
                                            }
                                        }
                                    }
                                    onEditingFinished: {
                                        var isValid = /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/.test(text)
                                        if (isValid) {
                                            if (SessionData.perMonitorWallpaper) {
                                                SessionData.setMonitorCyclingTime(selectedMonitorName, text)
                                            } else {
                                                SessionData.setWallpaperCyclingTime(text)
                                            }
                                        } else {
                                            if (SessionData.perMonitorWallpaper) {
                                                text = SessionData.getMonitorCyclingSettings(selectedMonitorName).time
                                            } else {
                                                text = SessionData.wallpaperCyclingTime
                                            }
                                        }
                                    }
                                    anchors.verticalCenter: parent.verticalCenter

                                    validator: RegularExpressionValidator {
                                        regularExpression: /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/
                                    }

                                    Connections {
                                        target: personalizationTab
                                        function onSelectedMonitorNameChanged() {
                                            // Force text field to refresh its value
                                            Qt.callLater(() => {
                                                if (SessionData.perMonitorWallpaper) {
                                                    timeTextField.text = SessionData.getMonitorCyclingSettings(selectedMonitorName).time
                                                } else {
                                                    timeTextField.text = SessionData.wallpaperCyclingTime
                                                }
                                            })
                                        }
                                    }
                                }

                                StyledText {
                                    text: I18n.tr("24-hour format")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                    }

                    DankDropdown {
                        text: I18n.tr("Transition Effect")
                        description: I18n.tr("Visual effect used when wallpaper changes")
                        currentValue: {
                            if (SessionData.wallpaperTransition === "random") return "Random"
                            return SessionData.wallpaperTransition.charAt(0).toUpperCase() + SessionData.wallpaperTransition.slice(1)
                        }
                        options: ["Random"].concat(SessionData.availableWallpaperTransitions.map(t => t.charAt(0).toUpperCase() + t.slice(1)))
                        onValueChanged: value => {
                            var transition = value.toLowerCase()
                            SessionData.setWallpaperTransition(transition)
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: SessionData.wallpaperTransition === "random"

                        StyledText {
                            text: I18n.tr("Include Transitions")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: I18n.tr("Select which transitions to include in randomization")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        DankButtonGroup {
                            id: transitionGroup
                            width: parent.width
                            selectionMode: "multi"
                            model: SessionData.availableWallpaperTransitions.filter(t => t !== "none")
                            initialSelection: SessionData.includedTransitions
                            currentSelection: SessionData.includedTransitions

                            onSelectionChanged: (index, selected) => {
                                const transition = model[index]
                                let newIncluded = [...SessionData.includedTransitions]

                                if (selected && !newIncluded.includes(transition)) {
                                    newIncluded.push(transition)
                                } else if (!selected && newIncluded.includes(transition)) {
                                    newIncluded = newIncluded.filter(t => t !== transition)
                                }

                                SessionData.includedTransitions = newIncluded
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: lightModeRow.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Row {
                    id: lightModeRow

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "contrast"
                        size: Theme.iconSize
                        color: Theme.primary
                        rotation: SessionData.isLightMode ? 180 : 0
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - Theme.iconSize - Theme.spacingM - lightModeToggle.width - Theme.spacingM
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: I18n.tr("Light Mode")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: I18n.tr("Use light theme instead of dark theme")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }

                    DankToggle {
                        id: lightModeToggle

                        anchors.verticalCenter: parent.verticalCenter
                        checked: SessionData.isLightMode
                        onToggleCompleted: checked => {
                                       Theme.screenTransition()
                                       Theme.setLightMode(checked)
                                   }
                    }
                }
            }

            // Animation Settings
            StyledRect {
                width: parent.width
                height: animationSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: animationSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "animation"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Animation Speed")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item {
                        width: parent.width
                        height: childrenRect.height

                        DankButtonGroup {
                            id: animationSpeedGroup
                            x: (parent.width - width) / 2
                            model: ["None", "Short", "Medium", "Long", "Custom"]
                            selectionMode: "single"
                            currentIndex: SettingsData.animationSpeed
                            onSelectionChanged: (index, selected) => {
                                if (selected) {
                                    SettingsData.setAnimationSpeed(index)
                                }
                            }

                            Connections {
                                target: SettingsData
                                function onAnimationSpeedChanged() {
                                    animationSpeedGroup.currentIndex = SettingsData.animationSpeed
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outline
                            opacity: 0.2
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS

                            Row {
                                width: parent.width
                                spacing: Theme.spacingM

                                StyledText {
                                    text: I18n.tr("Duration")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Item {
                                    width: 1
                                    height: 1
                                }

                                StyledText {
                                    text: Theme.currentAnimationBaseDuration + "ms"
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.primary
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Row {
                                width: parent.width
                                height: 40
                                spacing: Theme.spacingM

                                StyledText {
                                    text: "0ms"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Item {
                                    width: parent.width - 100
                                    height: 40
                                    anchors.verticalCenter: parent.verticalCenter

                                    DankSlider {
                                        id: customDurationSlider
                                        anchors.fill: parent
                                        minimum: 0
                                        maximum: 750
                                        value: Theme.currentAnimationBaseDuration
                                        unit: "ms"
                                        showValue: false
                                        wheelEnabled: false

                                        onSliderValueChanged: (newValue) => {
                                            SettingsData.setAnimationSpeed(SettingsData.AnimationSpeed.Custom)
                                            SettingsData.setCustomAnimationDuration(newValue)
                                        }

                                        Connections {
                                            target: SettingsData
                                            function onAnimationSpeedChanged() {
                                                if (SettingsData.animationSpeed !== SettingsData.AnimationSpeed.Custom) {
                                                    customDurationSlider.value = Theme.currentAnimationBaseDuration
                                                }
                                            }
                                        }

                                        Connections {
                                            target: Theme
                                            function onCurrentAnimationBaseDurationChanged() {
                                                if (SettingsData.animationSpeed !== SettingsData.AnimationSpeed.Custom) {
                                                    customDurationSlider.value = Theme.currentAnimationBaseDuration
                                                }
                                            }
                                        }
                                    }
                                }

                                StyledText {
                                    text: "750ms"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            StyledText {
                                text: I18n.tr("Select a preset or drag the slider to customize")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: dynamicThemeSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

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

                        StyledText {
                            text: I18n.tr("Matugen Settings")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "auto_awesome"
                            size: Theme.iconSize
                            color: Theme.currentTheme === Theme.dynamic ? Theme.primary : Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM - toggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Dynamic Theming")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Automatically extract colors from wallpaper")
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

                    DankDropdown {
                        id: personalizationMatugenPaletteDropdown
                        text: I18n.tr("Matugen Palette")
                        description: I18n.tr("Select the palette algorithm used for wallpaper-based colors")
                        options: Theme.availableMatugenSchemes.map(function (option) { return option.label })
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

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.2
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "code"
                            size: Theme.iconSize
                            color: SettingsData.runUserMatugenTemplates ? Theme.primary : Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM - runUserTemplatesToggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Run User Templates")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Execute templates from ~/.config/matugen/config.toml")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: runUserTemplatesToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.runUserMatugenTemplates
                            enabled: Theme.matugenAvailable
                            onToggled: checked => {
                                SettingsData.setRunUserMatugenTemplates(checked)
                            }
                        }
                    }

                    StyledText {
                        text: I18n.tr("matugen not detected - dynamic theming unavailable")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.error
                        visible: ToastService.wallpaperErrorStatus === "matugen_missing"
                        width: parent.width
                        leftPadding: Theme.iconSize + Theme.spacingM
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: soundsSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0
                visible: AudioService.soundsAvailable

                Column {
                    id: soundsSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "volume_up"
                            size: Theme.iconSize
                            color: SettingsData.soundsEnabled ? Theme.primary : Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM - soundsToggle.width - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Enable System Sounds")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Play sounds for system events")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                            }
                        }

                        DankToggle {
                            id: soundsToggle

                            anchors.verticalCenter: parent.verticalCenter
                            checked: SettingsData.soundsEnabled
                            onToggled: checked => {
                                SettingsData.setSoundsEnabled(checked)
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: SettingsData.soundsEnabled
                        leftPadding: Theme.iconSize + Theme.spacingM

                        Rectangle {
                            width: parent.width - parent.leftPadding
                            height: 1
                            color: Theme.outline
                            opacity: 0.2
                        }

                        Row {
                            width: parent.width - parent.leftPadding
                            spacing: Theme.spacingM
                            visible: AudioService.gsettingsAvailable

                            Column {
                                width: parent.width - useSystemSoundThemeToggle.width - Theme.spacingM
                                spacing: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    text: I18n.tr("Use System Theme")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    text: I18n.tr("Use sound theme from system settings")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: parent.width
                                }
                            }

                            DankToggle {
                                id: useSystemSoundThemeToggle

                                anchors.verticalCenter: parent.verticalCenter
                                checked: SettingsData.useSystemSoundTheme
                                onToggled: checked => {
                                    SettingsData.setUseSystemSoundTheme(checked)
                                }
                            }
                        }

                        DankDropdown {
                            id: soundThemeDropdown

                            width: parent.width - parent.leftPadding
                            text: I18n.tr("Sound Theme")
                            description: I18n.tr("Select system sound theme")
                            visible: SettingsData.useSystemSoundTheme && AudioService.availableSoundThemes.length > 0
                            enabled: SettingsData.useSystemSoundTheme && AudioService.availableSoundThemes.length > 0
                            options: AudioService.availableSoundThemes
                            currentValue: {
                                const theme = AudioService.currentSoundTheme
                                if (theme && AudioService.availableSoundThemes.includes(theme)) {
                                    return theme
                                }
                                return AudioService.availableSoundThemes.length > 0 ? AudioService.availableSoundThemes[0] : ""
                            }
                            onValueChanged: value => {
                                if (value && value !== AudioService.currentSoundTheme) {
                                    AudioService.setSoundTheme(value)
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width - parent.leftPadding
                            height: 1
                            color: Theme.outline
                            opacity: 0.2
                            visible: AudioService.gsettingsAvailable
                        }

                        Row {
                            width: parent.width - parent.leftPadding
                            spacing: Theme.spacingM

                            Column {
                                width: parent.width - notificationSoundToggle.width - Theme.spacingM
                                spacing: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    text: I18n.tr("New Notification")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    text: I18n.tr("Play sound when new notification arrives")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: parent.width
                                }
                            }

                            DankToggle {
                                id: notificationSoundToggle

                                anchors.verticalCenter: parent.verticalCenter
                                checked: SettingsData.soundNewNotification
                                onToggled: checked => {
                                    SettingsData.setSoundNewNotification(checked)
                                }
                            }
                        }

                        Row {
                            width: parent.width - parent.leftPadding
                            spacing: Theme.spacingM

                            Column {
                                width: parent.width - volumeSoundToggle.width - Theme.spacingM
                                spacing: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    text: I18n.tr("Volume Changed")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    text: I18n.tr("Play sound when volume is adjusted")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: parent.width
                                }
                            }

                            DankToggle {
                                id: volumeSoundToggle

                                anchors.verticalCenter: parent.verticalCenter
                                checked: SettingsData.soundVolumeChanged
                                onToggled: checked => {
                                    SettingsData.setSoundVolumeChanged(checked)
                                }
                            }
                        }

                        Row {
                            width: parent.width - parent.leftPadding
                            spacing: Theme.spacingM
                            visible: BatteryService.batteryAvailable

                            Column {
                                width: parent.width - pluggedInSoundToggle.width - Theme.spacingM
                                spacing: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    text: I18n.tr("Plugged In")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    text: I18n.tr("Play sound when power cable is connected")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: parent.width
                                }
                            }

                            DankToggle {
                                id: pluggedInSoundToggle

                                anchors.verticalCenter: parent.verticalCenter
                                checked: SettingsData.soundPluggedIn
                                onToggled: checked => {
                                    SettingsData.setSoundPluggedIn(checked)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: wallpaperBrowserLoader
        active: false
        asynchronous: true

        sourceComponent: FileBrowserModal {
            parentModal: personalizationTab.parentModal
            Component.onCompleted: {
                open()
            }
            browserTitle: "Select Wallpaper"
            browserIcon: "wallpaper"
            browserType: "wallpaper"
            showHiddenFiles: true
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
                Qt.callLater(() => wallpaperBrowserLoader.active = false)
            }
        }
    }
}
