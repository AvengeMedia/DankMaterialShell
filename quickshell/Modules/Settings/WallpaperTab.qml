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

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var parentModal: null
    property string selectedMonitorName: {
        var screens = Quickshell.screens;
        return screens.length > 0 ? screens[0].name : "";
    }
    property string currentWallpaper: {
        if (!SessionData.perMonitorWallpaper)
            return SessionData.wallpaperPath;
        var map = SessionData.monitorWallpapers;
        var screens = Quickshell.screens;
        for (var i = 0; i < screens.length; i++) {
            if (screens[i].name !== selectedMonitorName)
                continue;
            var screen = screens[i];
            if (map[screen.name] !== undefined)
                return map[screen.name];
            if (screen.model && map[screen.model] !== undefined)
                return map[screen.model];
            var displayName = SettingsData.getScreenDisplayName(screen);
            if (displayName && map[displayName] !== undefined)
                return map[displayName];
            break;
        }
        return SessionData.wallpaperPath;
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

                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: {
                                var wp = root.currentWallpaper;
                                if (wp === "" || wp.startsWith("#"))
                                    return "";
                                if (wp.startsWith("file://"))
                                    wp = wp.substring(7);
                                return "file://" + wp.split('/').map(s => encodeURIComponent(s)).join('/');
                            }
                            fillMode: Image.PreserveAspectCrop
                            visible: root.currentWallpaper !== "" && !root.currentWallpaper.startsWith("#")
                            sourceSize.width: 160
                            sourceSize.height: 160
                            asynchronous: true
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
                            color: root.currentWallpaper.startsWith("#") ? root.currentWallpaper : "transparent"
                            visible: root.currentWallpaper !== "" && root.currentWallpaper.startsWith("#")
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
                            visible: root.currentWallpaper === ""
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
                                        onClicked: root.openMainWallpaperBrowser()
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
                                            PopoutService.colorPickerModal.selectedColor = root.currentWallpaper.startsWith("#") ? root.currentWallpaper : Theme.primary;
                                            PopoutService.colorPickerModal.pickerTitle = I18n.tr("Choose Wallpaper Color", "wallpaper color picker title");
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
                                    visible: root.currentWallpaper !== ""

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
                            text: root.currentWallpaper ? root.currentWallpaper.split('/').pop() : I18n.tr("No wallpaper selected")
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            elide: Text.ElideMiddle
                            maximumLineCount: 1
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        StyledText {
                            text: root.currentWallpaper
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            elide: Text.ElideMiddle
                            maximumLineCount: 1
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                            visible: root.currentWallpaper !== ""
                        }

                        Row {
                            anchors.left: parent.left
                            spacing: Theme.spacingS
                            layoutDirection: I18n.isRtl ? Qt.RightToLeft : Qt.LeftToRight
                            visible: root.currentWallpaper !== ""

                            DankActionButton {
                                buttonSize: 32
                                iconName: "skip_previous"
                                iconSize: Theme.iconSizeSmall
                                enabled: root.currentWallpaper && !root.currentWallpaper.startsWith("#") && !root.currentWallpaper.startsWith("we")
                                opacity: enabled ? 1 : 0.5
                                backgroundColor: Theme.surfaceContainerHigh
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
                                enabled: root.currentWallpaper && !root.currentWallpaper.startsWith("#") && !root.currentWallpaper.startsWith("we")
                                opacity: enabled ? 1 : 0.5
                                backgroundColor: Theme.surfaceContainerHigh
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
                    visible: root.currentWallpaper !== "" && !root.currentWallpaper.startsWith("#")

                    DankButtonGroup {
                        id: fillModeGroup
                        property var internalModes: ["Stretch", "Fit", "Fill", "Tile", "TileVertically", "TileHorizontally", "Pad"]
                        anchors.horizontalCenter: parent.horizontalCenter
                        model: [I18n.tr("Stretch", "wallpaper fill mode"), I18n.tr("Fit", "wallpaper fill mode"), I18n.tr("Fill", "wallpaper fill mode"), I18n.tr("Tile", "wallpaper fill mode"), I18n.tr("Tile V", "wallpaper fill mode"), I18n.tr("Tile H", "wallpaper fill mode"), I18n.tr("Pad", "wallpaper fill mode")]
                        selectionMode: "single"
                        buttonHeight: 28
                        minButtonWidth: 48
                        buttonPadding: Theme.spacingS
                        checkIconSize: 0
                        textSize: Theme.fontSizeSmall
                        checkEnabled: false
                        currentIndex: {
                            var mode = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaperFillMode(selectedMonitorName) : SettingsData.wallpaperFillMode;
                            return internalModes.indexOf(mode);
                        }
                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            if (SessionData.perMonitorWallpaper) {
                                SessionData.setMonitorWallpaperFillMode(selectedMonitorName, internalModes[index]);
                            } else {
                                SettingsData.set("wallpaperFillMode", internalModes[index]);
                            }
                        }

                        Connections {
                            target: SettingsData
                            function onWallpaperFillModeChanged() {
                                if (SessionData.perMonitorWallpaper)
                                    return;
                                fillModeGroup.currentIndex = fillModeGroup.internalModes.indexOf(SettingsData.wallpaperFillMode);
                            }
                        }

                        Connections {
                            target: root
                            function onSelectedMonitorNameChanged() {
                                if (!SessionData.perMonitorWallpaper)
                                    return;
                                fillModeGroup.currentIndex = Qt.binding(() => {
                                    var mode = SessionData.perMonitorWallpaper ? SessionData.getMonitorWallpaperFillMode(selectedMonitorName) : SettingsData.wallpaperFillMode;
                                    return fillModeGroup.internalModes.indexOf(mode);
                                });
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

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    source: {
                                        var wp = SessionData.wallpaperPathLight;
                                        if (wp === "" || wp.startsWith("#"))
                                            return "";
                                        if (wp.startsWith("file://"))
                                            wp = wp.substring(7);
                                        return "file://" + wp.split('/').map(s => encodeURIComponent(s)).join('/');
                                    }
                                    fillMode: Image.PreserveAspectCrop
                                    visible: {
                                        var lightWallpaper = SessionData.wallpaperPathLight;
                                        return lightWallpaper !== "" && !lightWallpaper.startsWith("#");
                                    }
                                    sourceSize.width: 160
                                    sourceSize.height: 160
                                    asynchronous: true
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
                                                onClicked: root.openLightWallpaperBrowser()
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
                                                    PopoutService.colorPickerModal.pickerTitle = I18n.tr("Choose Light Mode Color", "light mode wallpaper color picker title");
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
                                    return lightWallpaper ? lightWallpaper.split('/').pop() : I18n.tr("Not set", "wallpaper not set label");
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

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    source: {
                                        var wp = SessionData.wallpaperPathDark;
                                        if (wp === "" || wp.startsWith("#"))
                                            return "";
                                        if (wp.startsWith("file://"))
                                            wp = wp.substring(7);
                                        return "file://" + wp.split('/').map(s => encodeURIComponent(s)).join('/');
                                    }
                                    fillMode: Image.PreserveAspectCrop
                                    visible: {
                                        var darkWallpaper = SessionData.wallpaperPathDark;
                                        return darkWallpaper !== "" && !darkWallpaper.startsWith("#");
                                    }
                                    sourceSize.width: 160
                                    sourceSize.height: 160
                                    asynchronous: true
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
                                                onClicked: root.openDarkWallpaperBrowser()
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
                                                    PopoutService.colorPickerModal.pickerTitle = I18n.tr("Choose Dark Mode Color", "dark mode wallpaper color picker title");
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
                                    return darkWallpaper ? darkWallpaper.split('/').pop() : I18n.tr("Not set", "wallpaper not set label");
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
                            return I18n.tr("No monitors", "no monitors available label");
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
                                return screens.length > 0 ? SettingsData.getScreenDisplayName(screens[0]) + " " + I18n.tr("(Default)", "default monitor label suffix") : I18n.tr("No monitors", "no monitors available label");
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
                                    label += " " + I18n.tr("(Default)", "default monitor label suffix");
                                }
                                screenNames.push(label);
                            }
                            return screenNames;
                        }
                        onValueChanged: value => {
                            var cleanValue = value.replace(" " + I18n.tr("(Default)", "default monitor label suffix"), "");
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
                                        "text": I18n.tr("Interval", "wallpaper cycling mode tab"),
                                        "icon": "schedule"
                                    },
                                    {
                                        "text": I18n.tr("Time", "wallpaper cycling mode tab"),
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
                        property var intervalOptions: [I18n.tr("5 seconds", "wallpaper interval"), I18n.tr("10 seconds", "wallpaper interval"), I18n.tr("15 seconds", "wallpaper interval"), I18n.tr("20 seconds", "wallpaper interval"), I18n.tr("25 seconds", "wallpaper interval"), I18n.tr("30 seconds", "wallpaper interval"), I18n.tr("35 seconds", "wallpaper interval"), I18n.tr("40 seconds", "wallpaper interval"), I18n.tr("45 seconds", "wallpaper interval"), I18n.tr("50 seconds", "wallpaper interval"), I18n.tr("55 seconds", "wallpaper interval"), I18n.tr("1 minute", "wallpaper interval"), I18n.tr("5 minutes", "wallpaper interval"), I18n.tr("15 minutes", "wallpaper interval"), I18n.tr("30 minutes", "wallpaper interval"), I18n.tr("1 hour", "wallpaper interval"), I18n.tr("1 hour 30 minutes", "wallpaper interval"), I18n.tr("2 hours", "wallpaper interval"), I18n.tr("3 hours", "wallpaper interval"), I18n.tr("4 hours", "wallpaper interval"), I18n.tr("6 hours", "wallpaper interval"), I18n.tr("8 hours", "wallpaper interval"), I18n.tr("12 hours", "wallpaper interval")]

                        property var intervalValues: [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 300, 900, 1800, 3600, 5400, 7200, 10800, 14400, 21600, 28800, 43200]
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
                            return index >= 0 ? intervalOptions[index] : I18n.tr("5 minutes", "wallpaper interval");
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
                                    intervalDropdown.currentValue = index >= 0 ? intervalDropdown.intervalOptions[index] : I18n.tr("5 minutes", "wallpaper interval");
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

    function openMainWallpaperBrowser() {
        mainWallpaperBrowserLoader.active = true;
        if (mainWallpaperBrowserLoader.item)
            mainWallpaperBrowserLoader.item.open();
    }

    function openLightWallpaperBrowser() {
        lightWallpaperBrowserLoader.active = true;
        if (lightWallpaperBrowserLoader.item)
            lightWallpaperBrowserLoader.item.open();
    }

    function openDarkWallpaperBrowser() {
        darkWallpaperBrowserLoader.active = true;
        if (darkWallpaperBrowserLoader.item)
            darkWallpaperBrowserLoader.item.open();
    }

    LazyLoader {
        id: mainWallpaperBrowserLoader
        active: false

        FileBrowserModal {
            parentModal: root.parentModal
            browserTitle: I18n.tr("Select Wallpaper", "wallpaper file browser title")
            browserIcon: "wallpaper"
            browserType: "wallpaper"
            showHiddenFiles: true
            fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp", "*.jxl", "*.avif", "*.heif", "*.exr"]
            onFileSelected: path => {
                if (SessionData.perMonitorWallpaper) {
                    SessionData.setMonitorWallpaper(selectedMonitorName, path);
                } else {
                    SessionData.setWallpaper(path);
                }
                close();
            }
        }
    }

    LazyLoader {
        id: lightWallpaperBrowserLoader
        active: false

        FileBrowserModal {
            parentModal: root.parentModal
            browserTitle: I18n.tr("Select Wallpaper", "light mode wallpaper file browser title")
            browserIcon: "light_mode"
            browserType: "wallpaper"
            showHiddenFiles: true
            fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp", "*.jxl", "*.avif", "*.heif", "*.exr"]
            onFileSelected: path => {
                SessionData.wallpaperPathLight = path;
                SessionData.syncWallpaperForCurrentMode();
                SessionData.saveSettings();
                close();
            }
        }
    }

    LazyLoader {
        id: darkWallpaperBrowserLoader
        active: false

        FileBrowserModal {
            parentModal: root.parentModal
            browserTitle: I18n.tr("Select Wallpaper", "dark mode wallpaper file browser title")
            browserIcon: "dark_mode"
            browserType: "wallpaper"
            showHiddenFiles: true
            fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp", "*.jxl", "*.avif", "*.heif", "*.exr"]
            onFileSelected: path => {
                SessionData.wallpaperPathDark = path;
                SessionData.syncWallpaperForCurrentMode();
                SessionData.saveSettings();
                close();
            }
        }
    }
}
