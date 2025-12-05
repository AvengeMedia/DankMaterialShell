import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: displaysTab

    function getBarComponentsFromSettings() {
        const bars = SettingsData.barConfigs || [];
        return bars.map(bar => ({
                    "id": "bar:" + bar.id,
                    "name": bar.name || "Bar",
                    "description": I18n.tr("Individual bar configuration"),
                    "icon": "toolbar",
                    "barId": bar.id
                }));
    }

    property var variantComponents: getVariantComponentsList()

    function getVariantComponentsList() {
        return [...getBarComponentsFromSettings(),
            {
                "id": "dock",
                "name": I18n.tr("Application Dock"),
                "description": I18n.tr("Bottom dock for pinned and running applications"),
                "icon": "dock"
            },
            {
                "id": "notifications",
                "name": I18n.tr("Notification Popups"),
                "description": I18n.tr("Notification toast popups"),
                "icon": "notifications"
            },
            {
                "id": "wallpaper",
                "name": I18n.tr("Wallpaper"),
                "description": I18n.tr("Desktop background images"),
                "icon": "wallpaper"
            },
            {
                "id": "osd",
                "name": I18n.tr("On-Screen Displays"),
                "description": I18n.tr("Volume, brightness, and other system OSDs"),
                "icon": "picture_in_picture"
            },
            {
                "id": "toast",
                "name": I18n.tr("Toast Messages"),
                "description": I18n.tr("System toast notifications"),
                "icon": "campaign"
            },
            {
                "id": "notepad",
                "name": I18n.tr("Notepad Slideout"),
                "description": I18n.tr("Quick note-taking slideout panel"),
                "icon": "sticky_note_2"
            },
            {
                "id": "systemTray",
                "name": I18n.tr("System Tray"),
                "description": I18n.tr("System tray icons"),
                "icon": "notifications"
            }
        ];
    }

    Connections {
        target: SettingsData
        function onBarConfigsChanged() {
            variantComponents = getVariantComponentsList();
        }
    }

    function getScreenPreferences(componentId) {
        if (componentId.startsWith("bar:")) {
            const barId = componentId.substring(4);
            const barConfig = SettingsData.getBarConfig(barId);
            return barConfig?.screenPreferences || ["all"];
        }
        return SettingsData.screenPreferences && SettingsData.screenPreferences[componentId] || ["all"];
    }

    function setScreenPreferences(componentId, screenNames) {
        if (componentId.startsWith("bar:")) {
            const barId = componentId.substring(4);
            SettingsData.updateBarConfig(barId, {
                screenPreferences: screenNames
            });
            return;
        }
        var prefs = SettingsData.screenPreferences || {};
        var newPrefs = Object.assign({}, prefs);
        newPrefs[componentId] = screenNames;
        SettingsData.set("screenPreferences", newPrefs);
    }

    function getShowOnLastDisplay(componentId) {
        if (componentId.startsWith("bar:")) {
            const barId = componentId.substring(4);
            const barConfig = SettingsData.getBarConfig(barId);
            return barConfig?.showOnLastDisplay ?? true;
        }
        return SettingsData.showOnLastDisplay && SettingsData.showOnLastDisplay[componentId] || false;
    }

    function setShowOnLastDisplay(componentId, enabled) {
        if (componentId.startsWith("bar:")) {
            const barId = componentId.substring(4);
            SettingsData.updateBarConfig(barId, {
                showOnLastDisplay: enabled
            });
            return;
        }
        var prefs = SettingsData.showOnLastDisplay || {};
        var newPrefs = Object.assign({}, prefs);
        newPrefs[componentId] = enabled;
        SettingsData.set("showOnLastDisplay", newPrefs);
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

            StyledRect {
                width: parent.width
                height: gammaSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: gammaSection

                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "brightness_6"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Gamma Control")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankToggle {
                        id: nightModeToggle

                        width: parent.width
                        text: I18n.tr("Night Mode")
                        description: DisplayService.gammaControlAvailable ? I18n.tr("Apply warm color temperature to reduce eye strain. Use automation settings below to control when it activates.") : I18n.tr("Gamma control not available. Requires DMS API v6+.")
                        checked: DisplayService.nightModeEnabled
                        enabled: DisplayService.gammaControlAvailable
                        onToggled: checked => {
                            DisplayService.toggleNightMode();
                        }

                        Connections {
                            function onNightModeEnabledChanged() {
                                nightModeToggle.checked = DisplayService.nightModeEnabled;
                            }

                            target: DisplayService
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        leftPadding: Theme.spacingM
                        rightPadding: Theme.spacingM
                        visible: DisplayService.gammaControlAvailable

                        DankDropdown {
                            width: parent.width - parent.leftPadding - parent.rightPadding
                            text: I18n.tr("Night Temperature")
                            description: I18n.tr("Color temperature for night mode")
                            currentValue: SessionData.nightModeTemperature + "K"
                            options: {
                                var temps = [];
                                for (var i = 2500; i <= 6000; i += 500) {
                                    temps.push(i + "K");
                                }
                                return temps;
                            }
                            onValueChanged: value => {
                                var temp = parseInt(value.replace("K", ""));
                                SessionData.setNightModeTemperature(temp);
                                if (SessionData.nightModeHighTemperature < temp) {
                                    SessionData.setNightModeHighTemperature(temp);
                                }
                            }
                        }

                        DankDropdown {
                            width: parent.width - parent.leftPadding - parent.rightPadding
                            text: I18n.tr("Day Temperature")
                            description: I18n.tr("Color temperature for day time")
                            currentValue: SessionData.nightModeHighTemperature + "K"
                            options: {
                                var temps = [];
                                var minTemp = SessionData.nightModeTemperature;
                                for (var i = Math.max(2500, minTemp); i <= 10000; i += 500) {
                                    temps.push(i + "K");
                                }
                                return temps;
                            }
                            onValueChanged: value => {
                                var temp = parseInt(value.replace("K", ""));
                                if (temp >= SessionData.nightModeTemperature) {
                                    SessionData.setNightModeHighTemperature(temp);
                                }
                            }
                        }
                    }

                    DankToggle {
                        id: automaticToggle
                        width: parent.width
                        text: I18n.tr("Automatic Control")
                        description: I18n.tr("Only adjust gamma based on time or location rules.")
                        checked: SessionData.nightModeAutoEnabled
                        visible: DisplayService.gammaControlAvailable
                        onToggled: checked => {
                            if (checked && !DisplayService.nightModeEnabled) {
                                DisplayService.toggleNightMode();
                            } else if (!checked && DisplayService.nightModeEnabled) {
                                DisplayService.toggleNightMode();
                            }
                            SessionData.setNightModeAutoEnabled(checked);
                        }

                        Connections {
                            target: SessionData
                            function onNightModeAutoEnabledChanged() {
                                automaticToggle.checked = SessionData.nightModeAutoEnabled;
                            }
                        }
                    }

                    Column {
                        id: automaticSettings
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: SessionData.nightModeAutoEnabled && DisplayService.gammaControlAvailable

                        Connections {
                            target: SessionData
                            function onNightModeAutoEnabledChanged() {
                                automaticSettings.visible = SessionData.nightModeAutoEnabled;
                            }
                        }

                        Item {
                            width: parent.width
                            height: 45 + Theme.spacingM

                            DankTabBar {
                                id: modeTabBarNight
                                width: 200
                                height: 45
                                anchors.horizontalCenter: parent.horizontalCenter
                                model: [
                                    {
                                        "text": "Time",
                                        "icon": "access_time"
                                    },
                                    {
                                        "text": "Location",
                                        "icon": "place"
                                    }
                                ]

                                Component.onCompleted: {
                                    currentIndex = SessionData.nightModeAutoMode === "location" ? 1 : 0;
                                    Qt.callLater(updateIndicator);
                                }

                                onTabClicked: index => {
                                    DisplayService.setNightModeAutomationMode(index === 1 ? "location" : "time");
                                    currentIndex = index;
                                }

                                Connections {
                                    target: SessionData
                                    function onNightModeAutoModeChanged() {
                                        modeTabBarNight.currentIndex = SessionData.nightModeAutoMode === "location" ? 1 : 0;
                                        Qt.callLater(modeTabBarNight.updateIndicator);
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingM
                            visible: SessionData.nightModeAutoMode === "time"

                            Column {
                                spacing: Theme.spacingXS
                                anchors.horizontalCenter: parent.horizontalCenter

                                Row {
                                    spacing: Theme.spacingM

                                    StyledText {
                                        text: ""
                                        width: 50
                                        height: 20
                                    }

                                    StyledText {
                                        text: I18n.tr("Hour")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        width: 70
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    StyledText {
                                        text: I18n.tr("Minute")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        width: 70
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                Row {
                                    spacing: Theme.spacingM

                                    StyledText {
                                        text: I18n.tr("Start")
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        width: 50
                                        height: 40
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    DankDropdown {
                                        dropdownWidth: 70
                                        currentValue: SessionData.nightModeStartHour.toString()
                                        options: {
                                            var hours = [];
                                            for (var i = 0; i < 24; i++) {
                                                hours.push(i.toString());
                                            }
                                            return hours;
                                        }
                                        onValueChanged: value => {
                                            SessionData.setNightModeStartHour(parseInt(value));
                                        }
                                    }

                                    DankDropdown {
                                        dropdownWidth: 70
                                        currentValue: SessionData.nightModeStartMinute.toString().padStart(2, '0')
                                        options: {
                                            var minutes = [];
                                            for (var i = 0; i < 60; i += 5) {
                                                minutes.push(i.toString().padStart(2, '0'));
                                            }
                                            return minutes;
                                        }
                                        onValueChanged: value => {
                                            SessionData.setNightModeStartMinute(parseInt(value));
                                        }
                                    }
                                }

                                Row {
                                    spacing: Theme.spacingM

                                    StyledText {
                                        text: I18n.tr("End")
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                        width: 50
                                        height: 40
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    DankDropdown {
                                        dropdownWidth: 70
                                        currentValue: SessionData.nightModeEndHour.toString()
                                        options: {
                                            var hours = [];
                                            for (var i = 0; i < 24; i++) {
                                                hours.push(i.toString());
                                            }
                                            return hours;
                                        }
                                        onValueChanged: value => {
                                            SessionData.setNightModeEndHour(parseInt(value));
                                        }
                                    }

                                    DankDropdown {
                                        dropdownWidth: 70
                                        currentValue: SessionData.nightModeEndMinute.toString().padStart(2, '0')
                                        options: {
                                            var minutes = [];
                                            for (var i = 0; i < 60; i += 5) {
                                                minutes.push(i.toString().padStart(2, '0'));
                                            }
                                            return minutes;
                                        }
                                        onValueChanged: value => {
                                            SessionData.setNightModeEndMinute(parseInt(value));
                                        }
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
                                id: ipLocationToggle
                                width: parent.width
                                text: I18n.tr("Use IP Location")
                                description: I18n.tr("Automatically detect location based on IP address")
                                checked: SessionData.nightModeUseIPLocation || false
                                onToggled: checked => {
                                    SessionData.setNightModeUseIPLocation(checked);
                                }

                                Connections {
                                    target: SessionData
                                    function onNightModeUseIPLocationChanged() {
                                        ipLocationToggle.checked = SessionData.nightModeUseIPLocation;
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: Theme.spacingM
                                leftPadding: Theme.spacingM
                                visible: !SessionData.nightModeUseIPLocation

                                StyledText {
                                    text: I18n.tr("Manual Coordinates")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                }

                                Row {
                                    spacing: Theme.spacingL

                                    Column {
                                        spacing: Theme.spacingXS

                                        StyledText {
                                            text: I18n.tr("Latitude")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }

                                        DankTextField {
                                            width: 120
                                            height: 40
                                            text: SessionData.latitude.toString()
                                            placeholderText: "0.0"
                                            onEditingFinished: {
                                                const lat = parseFloat(text);
                                                if (!isNaN(lat) && lat >= -90 && lat <= 90 && lat !== SessionData.latitude) {
                                                    SessionData.setLatitude(lat);
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        spacing: Theme.spacingXS

                                        StyledText {
                                            text: I18n.tr("Longitude")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }

                                        DankTextField {
                                            width: 120
                                            height: 40
                                            text: SessionData.longitude.toString()
                                            placeholderText: "0.0"
                                            onEditingFinished: {
                                                const lon = parseFloat(text);
                                                if (!isNaN(lon) && lon >= -180 && lon <= 180 && lon !== SessionData.longitude) {
                                                    SessionData.setLongitude(lon);
                                                }
                                            }
                                        }
                                    }
                                }

                                StyledText {
                                    text: I18n.tr("Uses sunrise/sunset times to automatically adjust night mode based on your location.")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: parent.width - parent.leftPadding
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: screensInfoSection.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                border.width: 0

                Column {
                    id: screensInfoSection

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

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: I18n.tr("Connected Displays")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: I18n.tr("Configure which displays show shell components")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        Column {
                            width: parent.width
                            spacing: Theme.spacingXS

                            Row {
                                width: parent.width
                                spacing: Theme.spacingM

                                StyledText {
                                    text: I18n.tr("Available Screens (") + Quickshell.screens.length + ")"
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }

                                Item {
                                    width: 1
                                    height: 1
                                    Layout.fillWidth: true
                                }

                                Column {
                                    spacing: Theme.spacingXS
                                    anchors.verticalCenter: parent.verticalCenter

                                    StyledText {
                                        text: I18n.tr("Display Name Format")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    DankButtonGroup {
                                        id: displayModeGroup
                                        model: [I18n.tr("Name"), I18n.tr("Model")]
                                        currentIndex: SettingsData.displayNameMode === "model" ? 1 : 0
                                        onSelectionChanged: (index, selected) => {
                                            if (!selected)
                                                return;
                                            SettingsData.displayNameMode = index === 1 ? "model" : "system";
                                            SettingsData.saveSettings();
                                        }

                                        Connections {
                                            target: SettingsData
                                            function onDisplayNameModeChanged() {
                                                displayModeGroup.currentIndex = SettingsData.displayNameMode === "model" ? 1 : 0;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: Quickshell.screens

                            delegate: Rectangle {
                                width: parent.width
                                height: screenRow.implicitHeight + Theme.spacingS * 2
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                                border.width: 0

                                Row {
                                    id: screenRow

                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingS
                                    spacing: Theme.spacingM

                                    DankIcon {
                                        name: "desktop_windows"
                                        size: Theme.iconSize - 4
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        width: parent.width - Theme.iconSize - Theme.spacingM * 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Theme.spacingXS / 2

                                        StyledText {
                                            text: SettingsData.getScreenDisplayName(modelData)
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                        }

                                        Row {
                                            spacing: Theme.spacingS

                                            property var wlrOutput: WlrOutputService.wlrOutputAvailable ? WlrOutputService.getOutput(modelData.name) : null
                                            property var currentMode: wlrOutput?.currentMode

                                            StyledText {
                                                text: {
                                                    if (parent.currentMode) {
                                                        return parent.currentMode.width + "×" + parent.currentMode.height + "@" + Math.round(parent.currentMode.refresh / 1000) + "Hz";
                                                    }
                                                    return modelData.width + "×" + modelData.height;
                                                }
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }

                                            StyledText {
                                                text: "•"
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }

                                            StyledText {
                                                text: SettingsData.displayNameMode === "system" ? (modelData.model || "Unknown Model") : modelData.name
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingL

                Repeater {
                    model: displaysTab.variantComponents

                    delegate: StyledRect {
                        width: parent.width
                        height: componentSection.implicitHeight + Theme.spacingL * 2
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                        border.width: 0

                        Column {
                            id: componentSection

                            anchors.fill: parent
                            anchors.margins: Theme.spacingL
                            spacing: Theme.spacingM

                            Row {
                                width: parent.width
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: modelData.icon
                                    size: Theme.iconSize
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    width: parent.width - Theme.iconSize - Theme.spacingM
                                    spacing: Theme.spacingXS
                                    anchors.verticalCenter: parent.verticalCenter

                                    StyledText {
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: modelData.description
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: Theme.spacingS

                                StyledText {
                                    text: I18n.tr("Show on screens:")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    font.weight: Font.Medium
                                }

                                Column {
                                    property string componentId: modelData.id

                                    width: parent.width
                                    spacing: Theme.spacingXS

                                    DankToggle {
                                        width: parent.width
                                        text: I18n.tr("All displays")
                                        description: I18n.tr("Show on all connected displays")
                                        checked: {
                                            var prefs = displaysTab.getScreenPreferences(parent.componentId);
                                            return prefs.includes("all") || (typeof prefs[0] === "string" && prefs[0] === "all");
                                        }
                                        onToggled: checked => {
                                            if (checked) {
                                                displaysTab.setScreenPreferences(parent.componentId, ["all"]);
                                            } else {
                                                displaysTab.setScreenPreferences(parent.componentId, []);
                                                const cid = parent.componentId;
                                                if (["dankBar", "dock", "notifications", "osd", "toast"].includes(cid) || cid.startsWith("bar:")) {
                                                    displaysTab.setShowOnLastDisplay(cid, true);
                                                }
                                            }
                                        }
                                    }

                                    DankToggle {
                                        width: parent.width
                                        text: I18n.tr("Show on Last Display")
                                        description: I18n.tr("Always show when there's only one connected display")
                                        checked: displaysTab.getShowOnLastDisplay(parent.componentId)
                                        visible: {
                                            const prefs = displaysTab.getScreenPreferences(parent.componentId);
                                            const isAll = prefs.includes("all") || (typeof prefs[0] === "string" && prefs[0] === "all");
                                            const cid = parent.componentId;
                                            const isRelevantComponent = ["dankBar", "dock", "notifications", "osd", "toast", "notepad", "systemTray"].includes(cid) || cid.startsWith("bar:");
                                            return !isAll && isRelevantComponent;
                                        }
                                        onToggled: checked => {
                                            displaysTab.setShowOnLastDisplay(parent.componentId, checked);
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 1
                                        color: Theme.outline
                                        opacity: 0.2
                                        visible: {
                                            var prefs = displaysTab.getScreenPreferences(parent.componentId);
                                            return !prefs.includes("all") && !(typeof prefs[0] === "string" && prefs[0] === "all");
                                        }
                                    }

                                    Column {
                                        width: parent.width
                                        spacing: Theme.spacingXS
                                        visible: {
                                            var prefs = displaysTab.getScreenPreferences(parent.componentId);
                                            return !prefs.includes("all") && !(typeof prefs[0] === "string" && prefs[0] === "all");
                                        }

                                        Repeater {
                                            model: Quickshell.screens

                                            delegate: DankToggle {
                                                property var screenData: modelData
                                                property string componentId: parent.parent.componentId

                                                width: parent.width
                                                text: SettingsData.getScreenDisplayName(screenData)
                                                description: screenData.width + "×" + screenData.height + " • " + (SettingsData.displayNameMode === "system" ? (screenData.model || "Unknown Model") : screenData.name)
                                                checked: {
                                                    var prefs = displaysTab.getScreenPreferences(componentId);
                                                    if (typeof prefs[0] === "string" && prefs[0] === "all")
                                                        return false;
                                                    return SettingsData.isScreenInPreferences(screenData, prefs);
                                                }
                                                onToggled: checked => {
                                                    var currentPrefs = displaysTab.getScreenPreferences(componentId);
                                                    if (typeof currentPrefs[0] === "string" && currentPrefs[0] === "all") {
                                                        currentPrefs = [];
                                                    }

                                                    const screenModelIndex = SettingsData.getScreenModelIndex(screenData);

                                                    var newPrefs = currentPrefs.filter(pref => {
                                                        if (typeof pref === "string")
                                                            return false;
                                                        if (pref.modelIndex !== undefined && screenModelIndex >= 0) {
                                                            return !(pref.model === screenData.model && pref.modelIndex === screenModelIndex);
                                                        }
                                                        return pref.name !== screenData.name || pref.model !== screenData.model;
                                                    });

                                                    if (checked) {
                                                        const prefObj = {
                                                            name: screenData.name,
                                                            model: screenData.model || ""
                                                        };
                                                        if (screenModelIndex >= 0) {
                                                            prefObj.modelIndex = screenModelIndex;
                                                        }
                                                        newPrefs.push(prefObj);
                                                    }

                                                    displaysTab.setScreenPreferences(componentId, newPrefs);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}