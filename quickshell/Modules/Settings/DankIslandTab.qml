pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets
import qs.Services
import qs.Widgets

Item {
    id: root

    property var parentModal: null
    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    readonly property var instanceChoices: {
        SettingsData.barConfigs;
        const rows = [];
        const configs = SettingsData.islandBarConfigs || [];
        for (let i = 0; i < configs.length; i++)
            rows.push({
                "id": configs[i].id,
                "name": configs[i].name || I18n.tr("Bar %1", "island instance choice: unnamed bar, %1 is its number").arg(i + 1)
            });
        return rows;
    }
    // Follows the Bars tab selection when that instance is an island, so the two stay in step.
    readonly property string selectedIslandId: {
        SettingsUiState.selectedBarId;
        const choices = root.instanceChoices;
        if (choices.length === 0)
            return "";
        if (choices.some(row => row.id === SettingsUiState.selectedBarId))
            return SettingsUiState.selectedBarId;
        return choices[0].id;
    }
    readonly property var config: {
        SettingsData.barConfigs;
        return SettingsData.getBarConfig(root.selectedIslandId);
    }
    readonly property bool islandEnabled: root.config?.enabled ?? false
    readonly property bool isVertical: SettingsData.islandVertical(root.config)
    readonly property int instanceIndex: Math.max(0, root.instanceChoices.findIndex(row => row.id === root.selectedIslandId))

    function setting(key) {
        return SettingsData.islandSetting(root.config, key);
    }

    function apply(key, value) {
        if (!root.selectedIslandId)
            return;
        const updates = {};
        updates[key] = value;
        SettingsData.updateBarConfig(root.selectedIslandId, updates);
    }
    readonly property var clockDisplayValues: ["time", "date", "both"]
    readonly property var systemLevelDisplayValues: ["icon", "percentage", "both"]
    readonly property var paletteValues: ["default", "bright", "dim"]
    readonly property var batteryStyleValues: ["solid", "outline", "ring"]
    readonly property var satellitePositionValues: ["island", "edges"]
    readonly property var interactionModeValues: ["click", "hybrid"]

    function valueIndex(values, value, fallback) {
        const index = values.indexOf(value);
        return index >= 0 ? index : Math.max(0, values.indexOf(fallback));
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn

            topPadding: Theme.spacingXS
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                width: parent.width
                iconName: "view_in_ar"
                title: I18n.tr("Dank Island", "island settings: page title")
                settingKey: "islandInstance"
                tags: ["island", "layout", "standard", "frame", "mode", "bar"]

                SettingsLayoutPicker {}

                SettingsButtonGroupRow {
                    settingKey: "islandInstanceSelect"
                    tags: ["island", "activities", "media", "notifications", "osd", "bar"]
                    visible: root.instanceChoices.length > 1
                    text: I18n.tr("Island Instance", "island settings: which island instance these settings edit")
                    model: root.instanceChoices.map(row => row.name)
                    currentIndex: root.instanceIndex
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsUiState.selectedBarId = root.instanceChoices[index]?.id ?? "";
                    }
                }

                SettingsToggleRow {
                    settingKey: "islandEnable"
                    tags: ["island", "enable", "show", "hide"]
                    visible: !!root.selectedIslandId
                    text: I18n.tr("Enable Island")
                    description: I18n.tr("Toggle the Island on this instance's displays")
                    checked: root.islandEnabled
                    onToggled: checked => SettingsData.updateBarConfig(root.selectedIslandId, {
                            enabled: checked
                        })
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "monitor"
                title: I18n.tr("Display Assignment")
                settingKey: "islandDisplays"
                collapsible: true
                expanded: false
                visible: root.islandEnabled

                SettingsDisplayPicker {
                    emptyMeansAll: false
                    displayPreferences: root.config?.screenPreferences ?? ["all"]
                    onPreferencesChanged: prefs => SettingsData.updateBarConfig(root.selectedIslandId, {
                            screenPreferences: prefs
                        })
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "open_with"
                title: I18n.tr("Position", "island settings: position card title")
                settingKey: "islandPlacement"
                visible: root.islandEnabled

                SettingsToggleRow {
                    settingKey: "islandFloating"
                    tags: ["island", "placement", "float", "overlay", "exclusive", "reserve"]
                    text: I18n.tr("Float", "island settings: float toggle")
                    description: I18n.tr("Floats above windows and other content", "island settings: float toggle description")
                    checked: root.setting("islandFloating")
                    onToggled: checked => root.apply("islandFloating", checked)
                }

                SettingsToggleRow {
                    settingKey: "islandUseOverlayLayer"
                    tags: ["island", "fullscreen", "overlay", "layer"]
                    text: I18n.tr("Use Overlay Layer", "island layer toggle: use Wayland overlay layer")
                    description: I18n.tr("Stage the Wayland overlay layer to remain visible over fullscreen apps", "island settings: overlay layer description")
                    checked: root.setting("islandUseOverlayLayer")
                    onToggled: checked => root.apply("islandUseOverlayLayer", checked)
                }

                SettingsSliderRow {
                    settingKey: "islandReserveThickness"
                    tags: ["island", "placement", "reservation", "exclusive", "height", "width", "thickness"]
                    text: !root.isVertical ? I18n.tr("Reserved Height", "island settings: reserved strip height slider") : I18n.tr("Reserved Width", "island settings: reserved strip width slider")
                    description: I18n.tr("Space kept clear for compact island and satellites", "island settings: reserved height description")
                    unit: "px"
                    minimum: 24
                    maximum: 128
                    step: 1
                    defaultValue: 40
                    value: root.setting("islandReserveThickness")
                    enabled: !root.setting("islandFloating")
                    onSliderValueChanged: value => root.apply("islandReserveThickness", value)
                }

                SettingsSliderRow {
                    settingKey: "islandCompactThickness"
                    tags: ["island", "placement", "compact", "height", "width", "thickness", "size", "satellite"]
                    text: !root.isVertical ? I18n.tr("Compact Island Height", "island settings: compact pill height slider") : I18n.tr("Compact Island Width", "island settings: compact pill width slider")
                    description: I18n.tr("Resize the resting island to align with nearby widgets", "island settings: compact height description")
                    unit: "px"
                    minimum: 24
                    maximum: 72
                    step: 1
                    defaultValue: 38
                    value: root.setting("islandCompactThickness")
                    onSliderValueChanged: value => root.apply("islandCompactThickness", value)
                }

                SettingsSliderRow {
                    settingKey: "islandOuterGap"
                    tags: ["island", "placement", "gap", "top", "margin"]
                    text: I18n.tr("Outer Gaps", "island settings: gap between screen edge and island")
                    description: I18n.tr("Distance between display edge and island", "island settings: outer gap description")
                    unit: "px"
                    minimum: 0
                    maximum: 48
                    step: 1
                    defaultValue: 4
                    value: root.setting("islandOuterGap")
                    onSliderValueChanged: value => root.apply("islandOuterGap", value)
                }

                SettingsSliderRow {
                    settingKey: "islandAlongOffset"
                    tags: ["island", "placement", "horizontal", "vertical", "offset", "center"]
                    text: !root.isVertical ? I18n.tr("Horizontal Offset", "island settings: horizontal offset slider") : I18n.tr("Vertical Offset", "island settings: vertical offset slider")
                    description: !root.isVertical ? I18n.tr("Move island and satellites left or right from display center", "island settings: horizontal offset description") : I18n.tr("Move island and satellites up or down from display center", "island settings: vertical offset description")
                    unit: "px"
                    minimum: -600
                    maximum: 600
                    step: 1
                    defaultValue: 0
                    value: root.setting("islandAlongOffset")
                    onSliderValueChanged: value => root.apply("islandAlongOffset", value)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "home"
                title: I18n.tr("Home Compact", "island settings: home face card title")
                settingKey: "islandActivities"
                visible: root.islandEnabled

                StyledText {
                    width: parent.width
                    text: I18n.tr("Drag groups above the clock to sit left of it, below to sit right. Click the eye to hide a group.", "island settings: home layout editor hint")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

                IslandHomeLayoutEditor {
                    width: parent.width
                    barId: root.selectedIslandId
                }

                SettingsButtonGroupRow {
                    settingKey: "islandHomeClockDisplay"
                    tags: ["island", "home", "compact", "clock", "time", "date"]
                    text: I18n.tr("Clock Style", "island settings: clock display mode row")
                    description: I18n.tr("Current time and date pill", "island settings: clock display mode description")
                    model: [I18n.tr("Time", "island settings: clock shows time only"), I18n.tr("Date", "island settings: clock shows date only"), I18n.tr("Both", "island settings: clock shows time and date")]
                    currentIndex: root.valueIndex(root.clockDisplayValues, root.setting("islandHomeClockDisplay"), "both")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            root.apply("islandHomeClockDisplay", root.clockDisplayValues[index] ?? "both");
                    }
                }

                SettingsButtonGroupRow {
                    settingKey: "islandHomeVolumeDisplay"
                    tags: ["island", "home", "compact", "volume", "icon", "percentage"]
                    text: I18n.tr("Volume Style", "island settings: volume display mode row")
                    visible: SettingsData.islandHomeGroupEnabled(root.config, "volume")
                    model: [I18n.tr("Icon", "island settings: level shown as icon only"), I18n.tr("Percentage", "island settings: level shown as percentage only"), I18n.tr("Both", "island settings: level shown as icon and percentage")]
                    currentIndex: root.valueIndex(root.systemLevelDisplayValues, root.setting("islandHomeVolumeDisplay"), "both")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            root.apply("islandHomeVolumeDisplay", root.systemLevelDisplayValues[index] ?? "both");
                    }
                }

                SettingsButtonGroupRow {
                    settingKey: "islandHomeBrightnessDisplay"
                    tags: ["island", "home", "compact", "brightness", "icon", "percentage"]
                    text: I18n.tr("Brightness Style", "island settings: brightness display mode row")
                    visible: SettingsData.islandHomeGroupEnabled(root.config, "brightness")
                    model: [I18n.tr("Icon", "island settings: level shown as icon only"), I18n.tr("Percentage", "island settings: level shown as percentage only"), I18n.tr("Both", "island settings: level shown as icon and percentage")]
                    currentIndex: root.valueIndex(root.systemLevelDisplayValues, root.setting("islandHomeBrightnessDisplay"), "both")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            root.apply("islandHomeBrightnessDisplay", root.systemLevelDisplayValues[index] ?? "both");
                    }
                }

                SettingsToggleRow {
                    settingKey: "islandHomeCompactTight"
                    tags: ["island", "home", "compact", "narrow", "width", "height", "clock"]
                    text: I18n.tr("Compact Pill", "island settings: tighter home pill toggle")
                    description: I18n.tr("Compact home clock pill in both width and height", "island settings: tight pill description")
                    checked: root.setting("islandHomeCompactTight")
                    onToggled: checked => root.apply("islandHomeCompactTight", checked)
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankButton {
                        text: I18n.tr("Launcher", "island settings: button to launcher tab")
                        iconName: "grid_view"
                        onClicked: {
                            if (!root.parentModal)
                                return;
                            SettingsSearchService.navigateToSection("launcherStyle");
                            root.parentModal.showWithTabName("launcher");
                        }
                    }

                    DankButton {
                        text: I18n.tr("Time & Weather", "island settings: button to weather tab")
                        iconName: "cloud"
                        onClicked: {
                            if (!root.parentModal)
                                return;
                            SettingsSearchService.navigateToSection("weatherEnabled");
                            root.parentModal.showWithTabName("time_weather");
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "palette"
                title: I18n.tr("Appearance", "island settings: appearance card title")
                settingKey: "islandAppearance"
                visible: root.islandEnabled

                SettingsButtonGroupRow {
                    settingKey: "islandPalette"
                    tags: ["island", "appearance", "palette", "surface", "bright", "dim"]
                    text: I18n.tr("Palette", "island settings: surface tone choice")
                    model: [I18n.tr("Default", "island settings: default surface tone"), I18n.tr("Bright", "island settings: bright surface tone"), I18n.tr("Dim", "island settings: dim surface tone")]
                    currentIndex: root.valueIndex(root.paletteValues, root.setting("islandPalette"), "default")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            root.apply("islandPalette", root.paletteValues[index] ?? "default");
                    }
                }

                SettingsSliderRow {
                    settingKey: "islandTransparency"
                    tags: ["island", "appearance", "surface", "opacity", "transparency", "blur"]
                    text: I18n.tr("Opacity", "island settings: island surface opacity slider")
                    unit: "%"
                    minimum: 0
                    maximum: 100
                    step: 1
                    defaultValue: 100
                    value: Math.round(root.setting("islandTransparency") * 100)
                    onSliderValueChanged: value => root.apply("islandTransparency", value / 100)
                }

                SettingsSliderRow {
                    settingKey: "islandCornerRadius"
                    tags: ["island", "appearance", "corner", "radius", "rounding", "pill", "expanded"]
                    text: I18n.tr("Corner Radius", "island settings: island corner radius slider")
                    unit: "px"
                    minimum: 0
                    maximum: 64
                    step: 1
                    defaultValue: 34
                    value: root.setting("islandCornerRadius")
                    onSliderValueChanged: value => root.apply("islandCornerRadius", value)
                }

                SettingsToggleRow {
                    settingKey: "islandHighContrast"
                    tags: ["island", "appearance", "contrast", "accessibility", "outline"]
                    text: I18n.tr("High Contrast", "island settings: high contrast toggle")
                    description: I18n.tr("Draw an outline and use the highest-contrast surface tone", "island settings: high contrast description")
                    checked: root.setting("islandHighContrast")
                    onToggled: checked => root.apply("islandHighContrast", checked)
                }

                SettingsToggleRow {
                    settingKey: "islandMediaClockVisible"
                    tags: ["island", "media", "clock", "compact", "time"]
                    text: I18n.tr("Keep Clock with Media", "island settings: clock in media face toggle")
                    description: I18n.tr("Show a clickable clock beside compact media details", "island settings: media clock description")
                    checked: root.setting("islandMediaClockVisible")
                    onToggled: checked => root.apply("islandMediaClockVisible", checked)
                }

                SettingsButtonGroupRow {
                    settingKey: "islandBatteryStyle"
                    tags: ["island", "battery", "gauge", "solid", "outline", "ring", "circle", "appearance"]
                    text: I18n.tr("Battery Style", "island settings: battery meter style row")
                    description: I18n.tr("Solid or outlined material meter, or a circular gauge", "island settings: battery style description")
                    visible: BatteryService.batteryAvailable
                    model: [I18n.tr("Solid", "island settings: filled battery meter style"), I18n.tr("Outline", "island settings: outlined battery meter style"), I18n.tr("Circle", "island settings: circular battery meter style")]
                    currentIndex: root.valueIndex(root.batteryStyleValues, root.setting("islandBatteryStyle"), "solid")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            root.apply("islandBatteryStyle", root.batteryStyleValues[index] ?? "solid");
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "notifications"
                title: I18n.tr("Notifications", "island settings: notifications card title")
                settingKey: "islandNotifications"
                visible: root.islandEnabled

                SettingsToggleRow {
                    settingKey: "islandNotificationExpand"
                    tags: ["island", "notifications", "expand", "arrival", "size"]
                    text: I18n.tr("Expand Notifications", "island settings: expanded notification toggle")
                    description: I18n.tr("Expand notifications by default instead of click or hover", "island settings: expanded notification description")
                    checked: root.setting("islandNotificationExpand")
                    onToggled: checked => root.apply("islandNotificationExpand", checked)
                }

                SettingsToggleRow {
                    settingKey: "islandNotificationBadgeClearOnOpen"
                    tags: ["island", "home", "notifications", "badge", "unread", "clear", "dismiss", "open"]
                    text: I18n.tr("Clear Badge on Open", "island settings: clear the notification badge when the center opens")
                    description: I18n.tr("Clears the badge on open but keeps notifications active", "island settings: clear badge on open description")
                    checked: root.setting("islandNotificationBadgeClearOnOpen")
                    enabled: SettingsData.islandHomeGroupEnabled(root.config, "notifications")
                    onToggled: checked => root.apply("islandNotificationBadgeClearOnOpen", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "widgets"
                title: I18n.tr("Satellite Widgets", "island settings: satellite widgets card title")
                settingKey: "islandSatellites"
                collapsible: true
                expanded: true
                visible: root.islandEnabled

                SettingsToggleRow {
                    settingKey: "islandSatellitesEnabled"
                    tags: ["island", "satellite", "widgets", "left", "right"]
                    text: I18n.tr("Show Satellite Widgets", "island settings: satellite widgets toggle")
                    description: I18n.tr("Place independent widgets to left and right of island", "island settings: satellite widgets description")
                    checked: root.setting("islandSatellitesEnabled")
                    onToggled: checked => root.apply("islandSatellitesEnabled", checked)
                }

                SettingsToggleRow {
                    settingKey: "islandSatelliteBackground"
                    tags: ["island", "satellite", "widgets", "background", "chrome"]
                    text: I18n.tr("Background", "island settings: satellite background toggle")
                    description: I18n.tr("Draw an island-styled background behind satellite widgets", "island settings: satellite background description")
                    checked: root.setting("islandSatelliteBackground")
                    enabled: root.setting("islandSatellitesEnabled")
                    onToggled: checked => root.apply("islandSatelliteBackground", checked)
                }

                SettingsToggleRow {
                    settingKey: "islandSatelliteGothCorners"
                    tags: ["island", "satellite", "goth", "corners", "wing", "sweep"]
                    text: I18n.tr("Goth Corners", "island settings: satellite goth corners toggle")
                    description: I18n.tr("Sweep the background into the screen edges", "island settings: satellite goth corners description")
                    checked: root.setting("islandSatelliteGothCorners")
                    enabled: root.setting("islandSatellitesEnabled") && root.setting("islandSatelliteBackground")
                    onToggled: checked => root.apply("islandSatelliteGothCorners", checked)
                }

                SettingsSliderRow {
                    settingKey: "islandSatelliteSwoopRadius"
                    tags: ["island", "satellite", "goth", "corners", "radius", "sweep", "size"]
                    text: I18n.tr("Goth Corner Radius", "island settings: satellite goth corner radius slider")
                    unit: "px"
                    minimum: 4
                    maximum: 64
                    step: 1
                    defaultValue: 24
                    value: root.setting("islandSatelliteSwoopRadius")
                    enabled: root.setting("islandSatellitesEnabled") && root.setting("islandSatelliteBackground") && root.setting("islandSatelliteGothCorners")
                    onSliderValueChanged: value => root.apply("islandSatelliteSwoopRadius", value)
                }

                SettingsSliderRow {
                    settingKey: "islandSatelliteTransparency"
                    tags: ["island", "satellite", "background", "opacity", "transparency", "blur"]
                    text: I18n.tr("Opacity", "island settings: satellite background opacity slider")
                    unit: "%"
                    minimum: 0
                    maximum: 100
                    step: 1
                    defaultValue: 100
                    value: Math.round(root.setting("islandSatelliteTransparency") * 100)
                    enabled: root.setting("islandSatellitesEnabled") && root.setting("islandSatelliteBackground")
                    onSliderValueChanged: value => root.apply("islandSatelliteTransparency", value / 100)
                }

                SettingsButtonGroupRow {
                    settingKey: "islandSatellitePosition"
                    tags: ["island", "satellite", "widgets", "position", "edges", "center"]
                    text: I18n.tr("Position", "island settings: position card title")
                    description: I18n.tr("Keep widgets beside the island or align them like a standalone bar", "island settings: satellite position description")
                    model: [I18n.tr("Near Island", "island settings: satellites hug the island"), I18n.tr("Screen Edges", "island settings: satellites sit at screen edges")]
                    currentIndex: root.valueIndex(root.satellitePositionValues, root.setting("islandSatellitePosition"), "island")
                    enabled: root.setting("islandSatellitesEnabled")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            root.apply("islandSatellitePosition", root.satellitePositionValues[index] ?? "island");
                    }
                }

                SettingsSliderRow {
                    settingKey: "islandSatelliteGap"
                    tags: ["island", "satellite", "widgets", "gap", "spacing"]
                    text: I18n.tr("Island Gap", "island settings: satellite to island gap slider")
                    unit: "px"
                    minimum: 4
                    maximum: 48
                    step: 1
                    defaultValue: 12
                    value: root.setting("islandSatelliteGap")
                    enabled: root.setting("islandSatellitesEnabled") && root.setting("islandSatellitePosition") !== "edges"
                    onSliderValueChanged: value => root.apply("islandSatelliteGap", value)
                }

                StyledText {
                    width: parent.width
                    text: I18n.tr("Satellites widget to place left or right of the island", "island settings: satellite widgets hint")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                    visible: root.setting("islandSatellitesEnabled")
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "touch_app"
                title: I18n.tr("Behavior", "island settings: behavior card title")
                settingKey: "islandInteraction"
                visible: root.islandEnabled

                SettingsButtonGroupRow {
                    settingKey: "islandInteractionMode"
                    tags: ["island", "interaction", "click", "hybrid", "expand"]
                    text: I18n.tr("Expansion Mode", "island settings: click or hover expansion row")
                    description: I18n.tr("Click expands only on an intentional press. Hybrid peeks the current compact face on hover", "island settings: expansion mode description")
                    model: [I18n.tr("Click", "island settings: click expansion mode"), I18n.tr("Hybrid", "island settings: hover plus click expansion mode")]
                    currentIndex: root.valueIndex(root.interactionModeValues, root.setting("islandInteractionMode"), "hybrid")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            root.apply("islandInteractionMode", root.interactionModeValues[index] ?? "hybrid");
                    }
                }

                StyledText {
                    width: parent.width
                    text: I18n.tr("Hybrid peeks the current compact face on hover. Click pins a destination so it stays open", "island settings: hybrid mode hint")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                    visible: root.setting("islandInteractionMode") !== "click"
                }

                SettingsSliderRow {
                    settingKey: "islandHoverOpenDelay"
                    tags: ["island", "interaction", "hover", "open", "delay"]
                    text: I18n.tr("Open Delay", "island settings: hover open delay slider")
                    unit: "ms"
                    minimum: 0
                    maximum: 1000
                    step: 10
                    defaultValue: 150
                    value: root.setting("islandHoverOpenDelay")
                    enabled: root.setting("islandInteractionMode") !== "click"
                    onSliderValueChanged: value => root.apply("islandHoverOpenDelay", value)
                }

                SettingsSliderRow {
                    settingKey: "islandHoverCloseDelay"
                    tags: ["island", "interaction", "hover", "close", "delay"]
                    text: I18n.tr("Hide Delay", "island settings: hover hide delay slider")
                    unit: "ms"
                    minimum: 0
                    maximum: 1000
                    step: 10
                    defaultValue: 150
                    value: root.setting("islandHoverCloseDelay")
                    enabled: root.setting("islandInteractionMode") !== "click"
                    onSliderValueChanged: value => root.apply("islandHoverCloseDelay", value)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "animation"
                title: I18n.tr("Motion & Accessibility", "island settings: motion card title")
                settingKey: "islandMotion"
                collapsible: true
                visible: root.islandEnabled

                SettingsToggleRow {
                    settingKey: "islandReducedMotion"
                    tags: ["island", "motion", "animation", "reduce", "accessibility", "spring"]
                    text: I18n.tr("Reduce Motion", "island settings: reduce motion toggle")
                    description: I18n.tr("Apply island geometry changes immediately without spring overshoot", "island settings: reduce motion description")
                    checked: root.setting("islandReducedMotion")
                    onToggled: checked => root.apply("islandReducedMotion", checked)
                }

                SettingsSliderRow {
                    settingKey: "islandSpringStiffness"
                    tags: ["island", "motion", "spring", "stiffness", "animation"]
                    text: I18n.tr("Spring Stiffness", "island settings: spring stiffness slider")
                    description: I18n.tr("Higher values pull island toward its target more strongly", "island settings: stiffness description")
                    minimum: 100
                    maximum: 1200
                    step: 10
                    value: Math.round(root.setting("islandSpringStiffness"))
                    defaultValue: 560
                    enabled: !root.setting("islandReducedMotion")
                    onSliderValueChanged: value => root.apply("islandSpringStiffness", value)
                }

                SettingsSliderRow {
                    settingKey: "islandSpringDamping"
                    tags: ["island", "motion", "spring", "damping", "bounce", "animation"]
                    text: I18n.tr("Spring Damping", "island settings: spring damping slider")
                    description: I18n.tr("Higher values settle island with less bounce", "island settings: damping description")
                    minimum: 10
                    maximum: 100
                    step: 1
                    value: Math.round(root.setting("islandSpringDamping"))
                    defaultValue: 37
                    enabled: !root.setting("islandReducedMotion")
                    onSliderValueChanged: value => root.apply("islandSpringDamping", value)
                }

                SettingsSliderRow {
                    settingKey: "islandSpringMass"
                    tags: ["island", "motion", "spring", "mass", "inertia", "animation"]
                    text: I18n.tr("Spring Mass", "island settings: spring mass slider")
                    description: I18n.tr("Higher percentages give island more inertia", "island settings: mass description")
                    minimum: 25
                    maximum: 300
                    step: 5
                    unit: "%"
                    value: Math.round(root.setting("islandSpringMass") * 100)
                    defaultValue: 100
                    enabled: !root.setting("islandReducedMotion")
                    onSliderValueChanged: value => root.apply("islandSpringMass", value / 100)
                }
            }
        }
    }
}
