import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    property var parentModal: null
    property string selectedMonitorName: {
        var screens = Quickshell.screens;
        return screens.length > 0 ? screens[0].name : "";
    }

    Component.onCompleted: {
        WallpaperCyclingService.cyclingActive;
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
                tab: "wallpaper"
                tags: ["background", "image", "picture"]
                title: I18n.tr("Wallpaper")
                settingKey: "wallpaper"
                iconName: "wallpaper"

                Row {
                    width: parent.width
                    spacing: Theme.spacingL

                    StyledRect {
                        id: wallpaperPreview
                        width: 160
                        height: 90
                        radius: Theme.cornerRadius
                        color: Theme.surfaceVariant

                        CachingImage {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: {
                                var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath;
                                return (currentWallpaper !== "" && !currentWallpaper.startsWith("#")) ? "file://" + currentWallpaper : "";
                            }
                            fillMode: Image.PreserveAspectCrop
                            visible: {
                                var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath;
                                return currentWallpaper !== "" && !currentWallpaper.startsWith("#");
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
                                var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath;
                                return currentWallpaper.startsWith("#") ? currentWallpaper : "transparent";
                            }
                            visible: {
                                var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath;
                                return currentWallpaper !== "" && currentWallpaper.startsWith("#");
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
                                var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath;
                                return currentWallpaper === "";
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
                                        onClicked: mainWallpaperBrowser.open()
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
                                            if (!PopoutService.colorPickerModal)
                                                return;
                                            var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath;
                                            PopoutService.colorPickerModal.selectedColor = currentWallpaper.startsWith("#") ? currentWallpaper : Theme.primary;
                                            PopoutService.colorPickerModal.pickerTitle = "Choose Wallpaper Color";
                                            PopoutService.colorPickerModal.onColorSelectedCallback = function (selectedColor) {
                                                if (SessionData.perMonitorWallpaper) {
                                                    SessionData.setMonitorWallpaper(selectedMonitorName, selectedColor);
                                                } else {
                                                    SessionData.setWallpaperColor(selectedColor);
                                                }
                                            };
                                            PopoutService.colorPickerModal.show();
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: Qt.rgba(255, 255, 255, 0.9)
                                    visible: {
                                        var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath;
                                        return currentWallpaper !== "";
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
                                                SessionData.setMonitorWallpaper(selectedMonitorName, "");
                                            } else {
                                                if (Theme.currentTheme === Theme.dynamic)
                                                    Theme.switchTheme("blue");
                                                SessionData.clearWallpaper();
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
                                var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath;
                                return currentWallpaper ? currentWallpaper.split('/').pop() : "No wallpaper selected";
                            }
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            elide: Text.ElideMiddle
                            maximumLineCount: 1
                            width: parent.width
                        }

                        StyledText {
                            text: {
                                var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath;
                                return currentWallpaper ? currentWallpaper : "";
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            elide: Text.ElideMiddle
                            maximumLineCount: 1
                            width: parent.width
                            visible: {
                                var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath;
                                return currentWallpaper !== "";
                            }
                        }

                        Row {
                            spacing: Theme.spacingS
                            visible: {
                                var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath;
                                return currentWallpaper !== "";
                            }

                            DankActionButton {
                                buttonSize: 32
                                iconName: "skip_previous"
                                iconSize: Theme.iconSizeSmall
                                enabled: {
                                    var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath;
                                    return currentWallpaper && !currentWallpaper.startsWith("#") && !currentWallpaper.startsWith("we");
                                }
                                opacity: enabled ? 1 : 0.5
                                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                iconColor: Theme.surfaceText
                                onClicked: {
                                    if (SessionData.perMonitorWallpaper) {
                                        WallpaperCyclingService.cyclePrevForMonitor(selectedMonitorName);
                                    } else {
                                        WallpaperCyclingService.cyclePrevManually();
                                    }
                                }
                            }

                            DankActionButton {
                                buttonSize: 32
                                iconName: "skip_next"
                                iconSize: Theme.iconSizeSmall
                                enabled: {
                                    var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath;
                                    return currentWallpaper && !currentWallpaper.startsWith("#") && !currentWallpaper.startsWith("we");
                                }
                                opacity: enabled ? 1 : 0.5
                                backgroundColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                iconColor: Theme.surfaceText
                                onClicked: {
                                    if (SessionData.perMonitorWallpaper) {
                                        WallpaperCyclingService.cycleNextForMonitor(selectedMonitorName);
                                    } else {
                                        WallpaperCyclingService.cycleNextManually();
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
                        var currentWallpaper = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaper(selectedMonitorName) : SessionData.wallpaperPath;
                        return currentWallpaper !== "" && !currentWallpaper.startsWith("#");
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
                            const modes = ["Stretch", "Fit", "Fill", "Tile", "TileVertically", "TileHorizontally", "Pad"];
                            return modes.indexOf(SettingsData.wallpaperFillMode);
                        }
                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            const modes = ["Stretch", "Fit", "Fill", "Tile", "TileVertically", "TileHorizontally", "Pad"];
                            SettingsData.set("wallpaperFillMode", modes[index]);
                        }

                        Connections {
                            target: SettingsData
                            function onWallpaperFillModeChanged() {
                                const modes = ["Stretch", "Fit", "Fill", "Tile", "TileVertically", "TileHorizontally", "Pad"];
                                fillModeGroup.currentIndex = modes.indexOf(SettingsData.wallpaperFillMode);
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.2
                    visible: SessionData.wallpaperPath !== ""
                }

                SettingsToggleRow {
                    tab: "wallpaper"
                    tags: ["per-mode", "light", "dark", "theme"]
                    settingKey: "perModeWallpaper"
                    visible: SessionData.wallpaperPath !== ""
                    text: I18n.tr("Per-Mode Wallpapers")
                    description: I18n.tr("Set different wallpapers for light and dark mode")
                    checked: SessionData.perModeWallpaper
                    onToggled: toggled => SessionData.setPerModeWallpaper(toggled)
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: SessionData.perModeWallpaper
                    leftPadding: Theme.spacingM
                    rightPadding: Theme.spacingM

                    Row {
                        width: parent.width - Theme.spacingM * 2
                        spacing: Theme.spacingL

                        Column {
                            width: (parent.width - Theme.spacingL) / 2
                            spacing: Theme.spacingS

                            StyledText {
                                text: I18n.tr("Light Mode")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            StyledRect {
                                width: parent.width
                                height: width * 9 / 16
                                radius: Theme.cornerRadius
                                color: Theme.surfaceVariant

                                CachingImage {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    source: {
                                        var lightWallpaper = SessionData.wallpaperPathLight;
                                        return (lightWallpaper !== "" && !lightWallpaper.startsWith("#")) ? "file://" + lightWallpaper : "";
                                    }
                                    fillMode: Image.PreserveAspectCrop
                                    visible: {
                                        var lightWallpaper = SessionData.wallpaperPathLight;
                                        return lightWallpaper !== "" && !lightWallpaper.startsWith("#");
                                    }
                                    maxCacheSize: 160
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: lightMask
                                        maskThresholdMin: 0.5
                                        maskSpreadAtMin: 1
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: Theme.cornerRadius - 1
                                    color: {
                                        var lightWallpaper = SessionData.wallpaperPathLight;
                                        return lightWallpaper.startsWith("#") ? lightWallpaper : "transparent";
                                    }
                                    visible: {
                                        var lightWallpaper = SessionData.wallpaperPathLight;
                                        return lightWallpaper !== "" && lightWallpaper.startsWith("#");
                                    }
                                }

                                Rectangle {
                                    id: lightMask
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: Theme.cornerRadius - 1
                                    color: "black"
                                    visible: false
                                    layer.enabled: true
                                }

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "light_mode"
                                    size: Theme.iconSizeLarge
                                    color: Theme.surfaceVariantText
                                    visible: SessionData.wallpaperPathLight === ""
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: Theme.cornerRadius - 1
                                    color: Qt.rgba(0, 0, 0, 0.7)
                                    visible: lightModeMouseArea.containsMouse

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Rectangle {
                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: Qt.rgba(255, 255, 255, 0.9)

                                            DankIcon {
                                                anchors.centerIn: parent
                                                name: "folder_open"
                                                size: 16
                                                color: "black"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: lightWallpaperBrowser.open()
                                            }
                                        }

                                        Rectangle {
                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: Qt.rgba(255, 255, 255, 0.9)

                                            DankIcon {
                                                anchors.centerIn: parent
                                                name: "palette"
                                                size: 16
                                                color: "black"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (!PopoutService.colorPickerModal)
                                                        return;
                                                    var lightWallpaper = SessionData.wallpaperPathLight;
                                                    PopoutService.colorPickerModal.selectedColor = lightWallpaper.startsWith("#") ? lightWallpaper : Theme.primary;
                                                    PopoutService.colorPickerModal.pickerTitle = "Choose Light Mode Color";
                                                    PopoutService.colorPickerModal.onColorSelectedCallback = function (selectedColor) {
                                                        SessionData.wallpaperPathLight = selectedColor;
                                                        SessionData.syncWallpaperForCurrentMode();
                                                        SessionData.saveSettings();
                                                    };
                                                    PopoutService.colorPickerModal.show();
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: Qt.rgba(255, 255, 255, 0.9)
                                            visible: SessionData.wallpaperPathLight !== ""

                                            DankIcon {
                                                anchors.centerIn: parent
                                                name: "clear"
                                                size: 16
                                                color: "black"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    SessionData.wallpaperPathLight = "";
                                                    SessionData.syncWallpaperForCurrentMode();
                                                    SessionData.saveSettings();
                                                }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: lightModeMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    propagateComposedEvents: true
                                    acceptedButtons: Qt.NoButton
                                }
                            }

                            StyledText {
                                text: {
                                    var lightWallpaper = SessionData.wallpaperPathLight;
                                    return lightWallpaper ? lightWallpaper.split('/').pop() : "Not set";
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideMiddle
                                maximumLineCount: 1
                                width: parent.width
                            }
                        }

                        Column {
                            width: (parent.width - Theme.spacingL) / 2
                            spacing: Theme.spacingS

                            StyledText {
                                text: I18n.tr("Dark Mode")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                font.weight: Font.Medium
                            }

                            StyledRect {
                                width: parent.width
                                height: width * 9 / 16
                                radius: Theme.cornerRadius
                                color: Theme.surfaceVariant

                                CachingImage {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    source: {
                                        var darkWallpaper = SessionData.wallpaperPathDark;
                                        return (darkWallpaper !== "" && !darkWallpaper.startsWith("#")) ? "file://" + darkWallpaper : "";
                                    }
                                    fillMode: Image.PreserveAspectCrop
                                    visible: {
                                        var darkWallpaper = SessionData.wallpaperPathDark;
                                        return darkWallpaper !== "" && !darkWallpaper.startsWith("#");
                                    }
                                    maxCacheSize: 160
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: darkMask
                                        maskThresholdMin: 0.5
                                        maskSpreadAtMin: 1
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: Theme.cornerRadius - 1
                                    color: {
                                        var darkWallpaper = SessionData.wallpaperPathDark;
                                        return darkWallpaper.startsWith("#") ? darkWallpaper : "transparent";
                                    }
                                    visible: {
                                        var darkWallpaper = SessionData.wallpaperPathDark;
                                        return darkWallpaper !== "" && darkWallpaper.startsWith("#");
                                    }
                                }

                                Rectangle {
                                    id: darkMask
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: Theme.cornerRadius - 1
                                    color: "black"
                                    visible: false
                                    layer.enabled: true
                                }

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "dark_mode"
                                    size: Theme.iconSizeLarge
                                    color: Theme.surfaceVariantText
                                    visible: SessionData.wallpaperPathDark === ""
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: Theme.cornerRadius - 1
                                    color: Qt.rgba(0, 0, 0, 0.7)
                                    visible: darkModeMouseArea.containsMouse

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Rectangle {
                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: Qt.rgba(255, 255, 255, 0.9)

                                            DankIcon {
                                                anchors.centerIn: parent
                                                name: "folder_open"
                                                size: 16
                                                color: "black"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: darkWallpaperBrowser.open()
                                            }
                                        }

                                        Rectangle {
                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: Qt.rgba(255, 255, 255, 0.9)

                                            DankIcon {
                                                anchors.centerIn: parent
                                                name: "palette"
                                                size: 16
                                                color: "black"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (!PopoutService.colorPickerModal)
                                                        return;
                                                    var darkWallpaper = SessionData.wallpaperPathDark;
                                                    PopoutService.colorPickerModal.selectedColor = darkWallpaper.startsWith("#") ? darkWallpaper : Theme.primary;
                                                    PopoutService.colorPickerModal.pickerTitle = "Choose Dark Mode Color";
                                                    PopoutService.colorPickerModal.onColorSelectedCallback = function (selectedColor) {
                                                        SessionData.wallpaperPathDark = selectedColor;
                                                        SessionData.syncWallpaperForCurrentMode();
                                                        SessionData.saveSettings();
                                                    };
                                                    PopoutService.colorPickerModal.show();
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: Qt.rgba(255, 255, 255, 0.9)
                                            visible: SessionData.wallpaperPathDark !== ""

                                            DankIcon {
                                                anchors.centerIn: parent
                                                name: "clear"
                                                size: 16
                                                color: "black"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    SessionData.wallpaperPathDark = "";
                                                    SessionData.syncWallpaperForCurrentMode();
                                                    SessionData.saveSettings();
                                                }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: darkModeMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    propagateComposedEvents: true
                                    acceptedButtons: Qt.NoButton
                                }
                            }

                            StyledText {
                                text: {
                                    var darkWallpaper = SessionData.wallpaperPathDark;
                                    return darkWallpaper ? darkWallpaper.split('/').pop() : "Not set";
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideMiddle
                                maximumLineCount: 1
                                width: parent.width
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.2
                    visible: CompositorService.isNiri
                }

                SettingsToggleRow {
                    tab: "wallpaper"
                    tags: ["blur", "overview", "niri"]
                    settingKey: "blurWallpaperOnOverview"
                    visible: CompositorService.isNiri
                    text: I18n.tr("Blur on Overview")
                    description: I18n.tr("Blur wallpaper when niri overview is open")
                    checked: SettingsData.blurWallpaperOnOverview
                    onToggled: checked => SettingsData.set("blurWallpaperOnOverview", checked)
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.2
                    visible: SessionData.wallpaperPath !== ""
                }

                SettingsToggleRow {
                    tab: "wallpaper"
                    tags: ["per-monitor", "multi-monitor", "display"]
                    settingKey: "perMonitorWallpaper"
                    visible: SessionData.wallpaperPath !== ""
                    text: I18n.tr("Per-Monitor Wallpapers")
                    description: I18n.tr("Set different wallpapers for each connected monitor")
                    checked: SessionData.perMonitorWallpaper
                    onToggled: toggled => SessionData.setPerMonitorWallpaper(toggled)
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: SessionData.perMonitorWallpaper
                    leftPadding: Theme.spacingM
                    rightPadding: Theme.spacingM

                    SettingsDropdownRow {
                        tab: "wallpaper"
                        tags: ["monitor", "display", "screen"]
                        settingKey: "selectedMonitor"
                        width: parent.width - Theme.spacingM * 2
                        text: I18n.tr("Wallpaper Monitor")
                        description: I18n.tr("Select monitor to configure wallpaper")
                        currentValue: {
                            var screens = Quickshell.screens;
                            for (var i = 0; i < screens.length; i++) {
                                if (screens[i].name === selectedMonitorName) {
                                    return SettingsData.getScreenDisplayName(screens[i]);
                                }
                            }
                            return "No monitors";
                        }
                        options: {
                            var screenNames = [];
                            var screens = Quickshell.screens;
                            for (var i = 0; i < screens.length; i++) {
                                screenNames.push(SettingsData.getScreenDisplayName(screens[i]));
                            }
                            return screenNames;
                        }
                        onValueChanged: value => {
                            var screens = Quickshell.screens;
                            for (var i = 0; i < screens.length; i++) {
                                if (SettingsData.getScreenDisplayName(screens[i]) === value) {
                                    selectedMonitorName = screens[i].name;
                                    return;
                                }
                            }
                        }
                    }

                    SettingsDropdownRow {
                        tab: "wallpaper"
                        tags: ["matugen", "target", "monitor", "theming"]
                        settingKey: "matugenTargetMonitor"
                        width: parent.width - Theme.spacingM * 2
                        text: I18n.tr("Matugen Target Monitor")
                        description: I18n.tr("Monitor whose wallpaper drives dynamic theming colors")
                        currentValue: {
                            var screens = Quickshell.screens;
                            if (!SettingsData.matugenTargetMonitor || SettingsData.matugenTargetMonitor === "") {
                                return screens.length > 0 ? SettingsData.getScreenDisplayName(screens[0]) + " (Default)" : "No monitors";
                            }
                            for (var i = 0; i < screens.length; i++) {
                                if (screens[i].name === SettingsData.matugenTargetMonitor) {
                                    return SettingsData.getScreenDisplayName(screens[i]);
                                }
                            }
                            return SettingsData.matugenTargetMonitor;
                        }
                        options: {
                            var screenNames = [];
                            var screens = Quickshell.screens;
                            for (var i = 0; i < screens.length; i++) {
                                var label = SettingsData.getScreenDisplayName(screens[i]);
                                if (i === 0 && (!SettingsData.matugenTargetMonitor || SettingsData.matugenTargetMonitor === "")) {
                                    label += " (Default)";
                                }
                                screenNames.push(label);
                            }
                            return screenNames;
                        }
                        onValueChanged: value => {
                            var cleanValue = value.replace(" (Default)", "");
                            var screens = Quickshell.screens;
                            for (var i = 0; i < screens.length; i++) {
                                if (SettingsData.getScreenDisplayName(screens[i]) === cleanValue) {
                                    SettingsData.setMatugenTargetMonitor(screens[i].name);
                                    return;
                                }
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

                SettingsToggleRow {
                    id: cyclingToggle
                    tab: "wallpaper"
                    tags: ["cycling", "automatic", "rotate", "slideshow"]
                    settingKey: "wallpaperCyclingEnabled"
                    visible: (SessionData.wallpaperPath !== "" || SessionData.perMonitorWallpaper) && !SessionData.perModeWallpaper
                    text: I18n.tr("Automatic Cycling")
                    description: I18n.tr("Automatically cycle through wallpapers in the same folder")
                    checked: SessionData.perMonitorWallpaper ? SessionData.getMonitorCyclingSettings(selectedMonitorName).enabled : SessionData.wallpaperCyclingEnabled
                    onToggled: toggled => {
                        if (SessionData.perMonitorWallpaper) {
                            SessionData.setMonitorCyclingEnabled(selectedMonitorName, toggled);
                        } else {
                            SessionData.setWallpaperCyclingEnabled(toggled);
                        }
                    }

                    Connections {
                        target: root
                        function onSelectedMonitorNameChanged() {
                            cyclingToggle.checked = Qt.binding(() => {
                                return SessionData.perMonitorWallpaper ? SessionData.getMonitorCyclingSettings(selectedMonitorName).enabled : SessionData.wallpaperCyclingEnabled;
                            });
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: SessionData.perMonitorWallpaper ? SessionData.getMonitorCyclingSettings(selectedMonitorName).enabled : SessionData.wallpaperCyclingEnabled
                    leftPadding: Theme.spacingM
                    rightPadding: Theme.spacingM

                    Row {
                        spacing: Theme.spacingL
                        width: parent.width - Theme.spacingM * 2

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
                                model: [
                                    {
                                        "text": "Interval",
                                        "icon": "schedule"
                                    },
                                    {
                                        "text": "Time",
                                        "icon": "access_time"
                                    }
                                ]
                                currentIndex: {
                                    if (SessionData.perMonitorWallpaper) {
                                        return SessionData.getMonitorCyclingSettings(selectedMonitorName).mode === "time" ? 1 : 0;
                                    }
                                    return SessionData.wallpaperCyclingMode === "time" ? 1 : 0;
                                }
                                onTabClicked: index => {
                                    if (SessionData.perMonitorWallpaper) {
                                        SessionData.setMonitorCyclingMode(selectedMonitorName, index === 1 ? "time" : "interval");
                                    } else {
                                        SessionData.setWallpaperCyclingMode(index === 1 ? "time" : "interval");
                                    }
                                }

                                Connections {
                                    target: root
                                    function onSelectedMonitorNameChanged() {
                                        modeTabBar.currentIndex = Qt.binding(() => {
                                            if (SessionData.perMonitorWallpaper) {
                                                return SessionData.getMonitorCyclingSettings(selectedMonitorName).mode === "time" ? 1 : 0;
                                            }
                                            return SessionData.wallpaperCyclingMode === "time" ? 1 : 0;
                                        });
                                        Qt.callLater(modeTabBar.updateIndicator);
                                    }
                                }
                            }
                        }
                    }

                    SettingsDropdownRow {
                        id: intervalDropdown
                        property var intervalOptions: [
                            "5 seconds", "10 seconds", "15 seconds", "20 seconds", "25 seconds", "30 seconds",
                            "35 seconds", "40 seconds", "45 seconds", "50 seconds", "55 seconds",
                            "1 minute", "5 minutes", "15 minutes", "30 minutes", "1 hour", "1.5 hours", "2 hours",
                            "3 hours", "4 hours", "6 hours", "8 hours", "12 hours"
                        ]

                        property var intervalValues: [
                            5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60,
                            300, 900, 1800, 3600, 5400, 7200, 10800, 14400, 21600, 28800, 43200
                        ]
                        tab: "wallpaper"
                        tags: ["interval", "cycling", "time", "frequency"]
                        settingKey: "wallpaperCyclingInterval"
                        width: parent.width - Theme.spacingM * 2
                        visible: {
                            if (SessionData.perMonitorWallpaper) {
                                return SessionData.getMonitorCyclingSettings(selectedMonitorName).mode === "interval";
                            }
                            return SessionData.wallpaperCyclingMode === "interval";
                        }
                        text: I18n.tr("Interval")
                        description: I18n.tr("How often to change wallpaper")
                        options: intervalOptions
                        currentValue: {
                            var currentSeconds;
                            if (SessionData.perMonitorWallpaper) {
                                currentSeconds = SessionData.getMonitorCyclingSettings(selectedMonitorName).interval;
                            } else {
                                currentSeconds = SessionData.wallpaperCyclingInterval;
                            }
                            const index = intervalValues.indexOf(currentSeconds);
                            return index >= 0 ? intervalOptions[index] : "5 minutes";
                        }
                        onValueChanged: value => {
                            const index = intervalOptions.indexOf(value);
                            if (index < 0)
                                return;
                            if (SessionData.perMonitorWallpaper) {
                                SessionData.setMonitorCyclingInterval(selectedMonitorName, intervalValues[index]);
                            } else {
                                SessionData.setWallpaperCyclingInterval(intervalValues[index]);
                            }
                        }

                        Connections {
                            target: root
                            function onSelectedMonitorNameChanged() {
                                Qt.callLater(() => {
                                    var currentSeconds;
                                    if (SessionData.perMonitorWallpaper) {
                                        currentSeconds = SessionData.getMonitorCyclingSettings(selectedMonitorName).interval;
                                    } else {
                                        currentSeconds = SessionData.wallpaperCyclingInterval;
                                    }
                                    const index = intervalDropdown.intervalValues.indexOf(currentSeconds);
                                    intervalDropdown.currentValue = index >= 0 ? intervalDropdown.intervalOptions[index] : "5 minutes";
                                });
                            }
                        }
                    }

                    Row {
                        spacing: Theme.spacingM
                        visible: {
                            if (SessionData.perMonitorWallpaper) {
                                return SessionData.getMonitorCyclingSettings(selectedMonitorName).mode === "time";
                            }
                            return SessionData.wallpaperCyclingMode === "time";
                        }
                        width: parent.width - Theme.spacingM * 2

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
                                    return SessionData.getMonitorCyclingSettings(selectedMonitorName).time;
                                }
                                return SessionData.wallpaperCyclingTime;
                            }
                            placeholderText: "00:00"
                            maximumLength: 5
                            topPadding: Theme.spacingS
                            bottomPadding: Theme.spacingS
                            onAccepted: {
                                var isValid = /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/.test(text);
                                if (isValid) {
                                    if (SessionData.perMonitorWallpaper) {
                                        SessionData.setMonitorCyclingTime(selectedMonitorName, text);
                                    } else {
                                        SessionData.setWallpaperCyclingTime(text);
                                    }
                                } else {
                                    if (SessionData.perMonitorWallpaper) {
                                        text = SessionData.getMonitorCyclingSettings(selectedMonitorName).time;
                                    } else {
                                        text = SessionData.wallpaperCyclingTime;
                                    }
                                }
                            }
                            onEditingFinished: {
                                var isValid = /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/.test(text);
                                if (isValid) {
                                    if (SessionData.perMonitorWallpaper) {
                                        SessionData.setMonitorCyclingTime(selectedMonitorName, text);
                                    } else {
                                        SessionData.setWallpaperCyclingTime(text);
                                    }
                                } else {
                                    if (SessionData.perMonitorWallpaper) {
                                        text = SessionData.getMonitorCyclingSettings(selectedMonitorName).time;
                                    } else {
                                        text = SessionData.wallpaperCyclingTime;
                                    }
                                }
                            }
                            anchors.verticalCenter: parent.verticalCenter

                            validator: RegularExpressionValidator {
                                regularExpression: /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/
                            }

                            Connections {
                                target: root
                                function onSelectedMonitorNameChanged() {
                                    Qt.callLater(() => {
                                        if (SessionData.perMonitorWallpaper) {
                                            timeTextField.text = SessionData.getMonitorCyclingSettings(selectedMonitorName).time;
                                        } else {
                                            timeTextField.text = SessionData.wallpaperCyclingTime;
                                        }
                                    });
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

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.2
                }

                SettingsDropdownRow {
                    tab: "wallpaper"
                    tags: ["transition", "effect", "animation", "change"]
                    settingKey: "wallpaperTransition"
                    text: I18n.tr("Transition Effect")
                    description: I18n.tr("Visual effect used when wallpaper changes")
                    currentValue: {
                        if (SessionData.wallpaperTransition === "random")
                            return "Random";
                        return SessionData.wallpaperTransition.charAt(0).toUpperCase() + SessionData.wallpaperTransition.slice(1);
                    }
                    options: ["Random"].concat(SessionData.availableWallpaperTransitions.map(t => t.charAt(0).toUpperCase() + t.slice(1)))
                    onValueChanged: value => {
                        var transition = value.toLowerCase();
                        SessionData.setWallpaperTransition(transition);
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: SessionData.wallpaperTransition === "random"
                    leftPadding: Theme.spacingM
                    rightPadding: Theme.spacingM

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
                        width: parent.width - Theme.spacingM * 2
                    }

                    DankButtonGroup {
                        id: transitionGroup
                        width: parent.width - Theme.spacingM * 2
                        selectionMode: "multi"
                        model: SessionData.availableWallpaperTransitions.filter(t => t !== "none")
                        initialSelection: SessionData.includedTransitions
                        currentSelection: SessionData.includedTransitions

                        onSelectionChanged: (index, selected) => {
                            const transition = model[index];
                            let newIncluded = SessionData.includedTransitions.slice();

                            if (selected && !newIncluded.includes(transition)) {
                                newIncluded.push(transition);
                            } else if (!selected && newIncluded.includes(transition)) {
                                newIncluded = newIncluded.filter(t => t !== transition);
                            }

                            SessionData.includedTransitions = newIncluded;
                        }
                    }
                }
            }

            SettingsCard {
                tab: "wallpaper"
                tags: ["external", "disable", "swww", "hyprpaper", "swaybg"]
                title: I18n.tr("External Wallpaper Management", "wallpaper settings external management")
                settingKey: "disableWallpaper"
                iconName: "wallpaper"

                SettingsToggleRow {
                    tab: "wallpaper"
                    tags: ["disable", "external", "management"]
                    settingKey: "disableWallpapers"
                    text: I18n.tr("Disable Built-in Wallpapers", "wallpaper settings disable toggle")
                    description: I18n.tr("Use an external wallpaper manager like swww, hyprpaper, or swaybg.", "wallpaper settings disable description")
                    checked: {
                        var prefs = SettingsData.screenPreferences?.wallpaper;
                        if (!prefs)
                            return false;
                        if (Array.isArray(prefs) && prefs.length === 0)
                            return true;
                        return false;
                    }
                    onToggled: checked => {
                        var prefs = SettingsData.screenPreferences || {};
                        var newPrefs = Object.assign({}, prefs);
                        newPrefs.wallpaper = checked ? [] : ["all"];
                        SettingsData.set("screenPreferences", newPrefs);
                    }
                }
            }

            SettingsCard {
                tab: "wallpaper"
                tags: ["blur", "layer", "niri", "compositor"]
                title: I18n.tr("Blur Wallpaper Layer")
                settingKey: "blurWallpaper"
                visible: CompositorService.isNiri

                SettingsToggleRow {
                    tab: "wallpaper"
                    tags: ["blur", "duplicate", "layer", "compositor"]
                    settingKey: "blurredWallpaperLayer"
                    text: I18n.tr("Duplicate Wallpaper with Blur")
                    description: I18n.tr("Enable compositor-targetable blur layer (namespace: dms:blurwallpaper). Requires manual niri configuration.")
                    checked: SettingsData.blurredWallpaperLayer
                    onToggled: checked => SettingsData.set("blurredWallpaperLayer", checked)
                }
            }
        }
    }

    FileBrowserModal {
        id: mainWallpaperBrowser
        parentModal: root.parentModal
        browserTitle: I18n.tr("Select Wallpaper", "wallpaper file browser title")
        browserIcon: "wallpaper"
        browserType: "wallpaper"
        showHiddenFiles: true
        fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp"]
        onFileSelected: path => {
            if (SessionData.perMonitorWallpaper) {
                SessionData.setMonitorWallpaper(selectedMonitorName, path);
            } else {
                SessionData.setWallpaper(path);
            }
            close();
        }
    }

    FileBrowserModal {
        id: lightWallpaperBrowser
        parentModal: root.parentModal
        browserTitle: I18n.tr("Select Wallpaper", "light mode wallpaper file browser title")
        browserIcon: "light_mode"
        browserType: "wallpaper"
        showHiddenFiles: true
        fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp"]
        onFileSelected: path => {
            SessionData.wallpaperPathLight = path;
            SessionData.syncWallpaperForCurrentMode();
            SessionData.saveSettings();
            close();
        }
    }

    FileBrowserModal {
        id: darkWallpaperBrowser
        parentModal: root.parentModal
        browserTitle: I18n.tr("Select Wallpaper", "dark mode wallpaper file browser title")
        browserIcon: "dark_mode"
        browserType: "wallpaper"
        showHiddenFiles: true
        fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp"]
        onFileSelected: path => {
            SessionData.wallpaperPathDark = path;
            SessionData.syncWallpaperForCurrentMode();
            SessionData.saveSettings();
            close();
        }
    }
}
