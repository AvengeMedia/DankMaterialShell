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
        SettingsData.dankIslandBarId;
        const rows = [({
                    "id": "",
                    "name": I18n.tr("Off", "island instance choice: island disabled")
                })];
        const configs = SettingsData.barConfigs || [];
        for (let i = 0; i < configs.length; i++)
            rows.push({
                "id": configs[i].id,
                "name": configs[i].name || I18n.tr("Bar %1", "island instance choice: unnamed bar, %1 is its number").arg(i + 1)
            });
        return rows;
    }
    readonly property int instanceIndex: Math.max(0, root.instanceChoices.findIndex(row => row.id === SettingsData.dankIslandBarId))
    readonly property var homeSlotValues: ["left", "right", "hidden"]
    readonly property var paletteValues: ["default", "bright", "dim"]
    readonly property var batteryStyleValues: ["solid", "outline"]
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
                title: I18n.tr("Dank Island - Beta", "island settings: page title")
                settingKey: "dankIslandInstance"

                SettingsButtonGroupRow {
                    settingKey: "dankIslandBarId"
                    tags: ["island", "activities", "media", "notifications", "osd", "bar"]
                    text: I18n.tr("Island Instance", "island settings: which bar config the island replaces")
                    model: root.instanceChoices.map(row => row.name)
                    currentIndex: root.instanceIndex
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("dankIslandBarId", root.instanceChoices[index]?.id ?? "");
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "open_with"
                title: I18n.tr("Position", "island settings: position card title")
                settingKey: "dankIslandPlacement"
                enabled: SettingsData.dankIslandEnabled

                SettingsToggleRow {
                    settingKey: "dankIslandFloating"
                    tags: ["island", "placement", "float", "overlay", "exclusive", "reserve"]
                    text: I18n.tr("Float", "island settings: float toggle")
                    description: I18n.tr("Floats above windows and other content", "island settings: float toggle description")
                    checked: SettingsData.dankIslandFloating
                    onToggled: checked => SettingsData.set("dankIslandFloating", checked)
                }

                SettingsToggleRow {
                    settingKey: "dankIslandUseOverlayLayer"
                    tags: ["island", "fullscreen", "overlay", "layer"]
                    text: I18n.tr("Use Overlay Layer", "island layer toggle: use Wayland overlay layer")
                    description: I18n.tr("Stage the Wayland overlay layer to remain visible over fullscreen apps", "island settings: overlay layer description")
                    checked: SettingsData.dankIslandUseOverlayLayer
                    onToggled: checked => SettingsData.set("dankIslandUseOverlayLayer", checked)
                }

                SettingsSliderRow {
                    settingKey: "dankIslandReserveHeight"
                    tags: ["island", "placement", "reservation", "exclusive", "height"]
                    text: I18n.tr("Reserved Height", "island settings: reserved strip height slider")
                    description: I18n.tr("Space kept clear for compact island and satellites", "island settings: reserved height description")
                    unit: "px"
                    minimum: 24
                    maximum: 128
                    step: 1
                    defaultValue: 40
                    value: SettingsData.dankIslandReserveHeight
                    enabled: !SettingsData.dankIslandFloating
                    onSliderValueChanged: value => SettingsData.set("dankIslandReserveHeight", value)
                }

                SettingsSliderRow {
                    settingKey: "dankIslandCompactHeight"
                    tags: ["island", "placement", "compact", "height", "size", "satellite"]
                    text: I18n.tr("Compact Island Height", "island settings: compact pill height slider")
                    description: I18n.tr("Resize the resting island to align with nearby widgets", "island settings: compact height description")
                    unit: "px"
                    minimum: 24
                    maximum: 72
                    step: 1
                    defaultValue: 38
                    value: SettingsData.dankIslandCompactHeight
                    onSliderValueChanged: value => SettingsData.set("dankIslandCompactHeight", value)
                }

                SettingsSliderRow {
                    settingKey: "dankIslandOuterGap"
                    tags: ["island", "placement", "gap", "top", "margin"]
                    text: I18n.tr("Outer Gaps", "island settings: gap between screen edge and island")
                    description: I18n.tr("Distance between display edge and island", "island settings: outer gap description")
                    unit: "px"
                    minimum: 0
                    maximum: 48
                    step: 1
                    defaultValue: 4
                    value: SettingsData.dankIslandOuterGap
                    onSliderValueChanged: value => SettingsData.set("dankIslandOuterGap", value)
                }

                SettingsSliderRow {
                    settingKey: "dankIslandHorizontalOffset"
                    tags: ["island", "placement", "horizontal", "offset", "center"]
                    text: I18n.tr("Horizontal Offset", "island settings: horizontal offset slider")
                    description: I18n.tr("Move island and satellites left or right from display center", "island settings: horizontal offset description")
                    unit: "px"
                    minimum: -600
                    maximum: 600
                    step: 1
                    defaultValue: 0
                    value: SettingsData.dankIslandHorizontalOffset
                    onSliderValueChanged: value => SettingsData.set("dankIslandHorizontalOffset", value)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "home"
                title: I18n.tr("Home Compact", "island settings: home face card title")
                settingKey: "dankIslandActivities"
                enabled: SettingsData.dankIslandEnabled

                StyledText {
                    width: parent.width
                    text: I18n.tr("Choose which shortcuts sit left or right of the clock", "island settings: home face slot hint")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

                SettingsButtonGroupRow {
                    settingKey: "dankIslandHomeMediaSlot"
                    tags: ["island", "home", "compact", "media", "launcher", "search", "cava"]
                    text: I18n.tr("Media / Launcher", "island settings: media or launcher slot row")
                    description: I18n.tr("Search when idle, visualizer when media is playing", "island settings: media slot description")
                    model: [I18n.tr("Left", "island settings: media or launcher slot left of the clock"), I18n.tr("Right", "island settings: media or launcher slot right of the clock"), I18n.tr("Hidden", "island settings: media or launcher slot hidden")]
                    currentIndex: root.valueIndex(root.homeSlotValues, SettingsData.dankIslandHomeMediaSlot, "left")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("dankIslandHomeMediaSlot", root.homeSlotValues[index] ?? "left");
                    }
                }

                SettingsButtonGroupRow {
                    settingKey: "dankIslandHomeStatusSlot"
                    tags: ["island", "home", "compact", "battery", "control center", "tools"]
                    text: I18n.tr("Battery / Control Center", "island settings: battery or control center slot row")
                    description: BatteryService.batteryAvailable ? I18n.tr("Battery gauge opens Control Center", "island settings: status slot description with battery") : I18n.tr("Tools icon opens Control Center", "island settings: status slot description without battery")
                    model: [I18n.tr("Left", "island settings: battery or control center slot left of the clock"), I18n.tr("Right", "island settings: battery or control center slot right of the clock"), I18n.tr("Hidden", "island settings: battery or control center slot hidden")]
                    currentIndex: root.valueIndex(root.homeSlotValues, SettingsData.dankIslandHomeStatusSlot, "hidden")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("dankIslandHomeStatusSlot", root.homeSlotValues[index] ?? "hidden");
                    }
                }

                SettingsButtonGroupRow {
                    settingKey: "dankIslandHomeWeatherSlot"
                    tags: ["island", "home", "compact", "weather", "forecast"]
                    text: I18n.tr("Weather", "island settings: weather slot row")
                    description: SettingsData.weatherEnabled ? I18n.tr("Weather icon and temperature open the weather activity", "island settings: weather slot description") : I18n.tr("Enable weather in Time & Weather to show this shortcut", "island settings: weather slot disabled hint")
                    model: [I18n.tr("Left", "island settings: weather slot left of the clock"), I18n.tr("Right", "island settings: weather slot right of the clock"), I18n.tr("Hidden", "island settings: weather slot hidden")]
                    currentIndex: root.valueIndex(root.homeSlotValues, SettingsData.dankIslandHomeWeatherSlot, "hidden")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("dankIslandHomeWeatherSlot", root.homeSlotValues[index] ?? "hidden");
                    }
                }

                SettingsToggleRow {
                    settingKey: "dankIslandHomeCompactTight"
                    tags: ["island", "home", "compact", "narrow", "width", "height", "clock"]
                    text: I18n.tr("Compact Clock Pill", "island settings: tighter home pill toggle")
                    description: I18n.tr("Compact home clock pill in both width and height", "island settings: tight pill description")
                    checked: SettingsData.dankIslandHomeCompactTight
                    onToggled: checked => SettingsData.set("dankIslandHomeCompactTight", checked)
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
                settingKey: "dankIslandAppearance"
                enabled: SettingsData.dankIslandEnabled

                SettingsButtonGroupRow {
                    settingKey: "dankIslandPalette"
                    tags: ["island", "appearance", "palette", "surface", "bright", "dim"]
                    text: I18n.tr("Palette", "island settings: surface tone choice")
                    model: [I18n.tr("Default", "island settings: default surface tone"), I18n.tr("Bright", "island settings: bright surface tone"), I18n.tr("Dim", "island settings: dim surface tone")]
                    currentIndex: root.valueIndex(root.paletteValues, SettingsData.dankIslandPalette, "default")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("dankIslandPalette", root.paletteValues[index] ?? "default");
                    }
                }

                SettingsSliderRow {
                    settingKey: "dankIslandTransparency"
                    tags: ["island", "appearance", "surface", "opacity", "transparency", "blur"]
                    text: I18n.tr("Opacity", "island settings: island surface opacity slider")
                    unit: "%"
                    minimum: 0
                    maximum: 100
                    step: 1
                    defaultValue: 100
                    value: Math.round(SettingsData.dankIslandTransparency * 100)
                    onSliderValueChanged: value => SettingsData.set("dankIslandTransparency", value / 100)
                }

                SettingsToggleRow {
                    settingKey: "dankIslandHighContrast"
                    tags: ["island", "appearance", "contrast", "accessibility", "outline"]
                    text: I18n.tr("High Contrast", "island settings: high contrast toggle")
                    description: I18n.tr("Draw an outline and use the highest-contrast surface tone", "island settings: high contrast description")
                    checked: SettingsData.dankIslandHighContrast
                    onToggled: checked => SettingsData.set("dankIslandHighContrast", checked)
                }

                SettingsToggleRow {
                    settingKey: "dankIslandMediaClockVisible"
                    tags: ["island", "media", "clock", "compact", "time"]
                    text: I18n.tr("Keep Clock with Media", "island settings: clock in media face toggle")
                    description: I18n.tr("Show a clickable clock beside compact media details", "island settings: media clock description")
                    checked: SettingsData.dankIslandMediaClockVisible
                    onToggled: checked => SettingsData.set("dankIslandMediaClockVisible", checked)
                }

                SettingsButtonGroupRow {
                    settingKey: "dankIslandBatteryStyle"
                    tags: ["island", "battery", "gauge", "solid", "outline", "appearance"]
                    text: I18n.tr("Material Battery Style", "island settings: battery meter style row")
                    description: I18n.tr("Solid material type or Outline", "island settings: battery style description")
                    visible: BatteryService.batteryAvailable
                    model: [I18n.tr("Solid", "island settings: filled battery meter style"), I18n.tr("Outline", "island settings: outlined battery meter style")]
                    currentIndex: root.valueIndex(root.batteryStyleValues, SettingsData.dankIslandBatteryStyle, "solid")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("dankIslandBatteryStyle", root.batteryStyleValues[index] ?? "solid");
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "notifications"
                title: I18n.tr("Notifications", "island settings: notifications card title")
                settingKey: "dankIslandNotifications"
                enabled: SettingsData.dankIslandEnabled

                SettingsToggleRow {
                    settingKey: "dankIslandNotificationExpand"
                    tags: ["island", "notifications", "expand", "arrival", "size"]
                    text: I18n.tr("Expand Notifications", "island settings: expanded notification toggle")
                    description: I18n.tr("Expand notifications by default instead of click or hover", "island settings: expanded notification description")
                    checked: SettingsData.dankIslandNotificationExpand
                    onToggled: checked => SettingsData.set("dankIslandNotificationExpand", checked)
                }

                SettingsToggleRow {
                    settingKey: "dankIslandHomeNotificationBadge"
                    tags: ["island", "home", "notifications", "badge", "unread", "count"]
                    text: I18n.tr("Show Badge", "island settings: unread notification count on the home face")
                    description: I18n.tr("Unread notification count beside the clock", "island settings: notification badge description")
                    checked: SettingsData.dankIslandHomeNotificationBadge
                    onToggled: checked => SettingsData.set("dankIslandHomeNotificationBadge", checked)
                }

                SettingsToggleRow {
                    settingKey: "dankIslandNotificationBadgeClearOnOpen"
                    tags: ["island", "home", "notifications", "badge", "unread", "clear", "dismiss", "open"]
                    text: I18n.tr("Clear Badge on Open", "island settings: clear the notification badge when the center opens")
                    description: I18n.tr("Clears the badge on open but keeps notifications active", "island settings: clear badge on open description")
                    checked: SettingsData.dankIslandNotificationBadgeClearOnOpen
                    enabled: SettingsData.dankIslandHomeNotificationBadge
                    onToggled: checked => SettingsData.set("dankIslandNotificationBadgeClearOnOpen", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "widgets"
                title: I18n.tr("Satellite Widgets", "island settings: satellite widgets card title")
                settingKey: "dankIslandSatellites"
                collapsible: true
                expanded: true
                enabled: SettingsData.dankIslandEnabled

                SettingsToggleRow {
                    settingKey: "dankIslandSatellitesEnabled"
                    tags: ["island", "satellite", "widgets", "left", "right"]
                    text: I18n.tr("Show Satellite Widgets", "island settings: satellite widgets toggle")
                    description: I18n.tr("Place independent widgets to left and right of island", "island settings: satellite widgets description")
                    checked: SettingsData.dankIslandSatellitesEnabled
                    onToggled: checked => SettingsData.set("dankIslandSatellitesEnabled", checked)
                }

                SettingsToggleRow {
                    settingKey: "dankIslandSatelliteBackground"
                    tags: ["island", "satellite", "widgets", "background", "chrome"]
                    text: I18n.tr("Background", "island settings: satellite background toggle")
                    description: I18n.tr("Draw an island-styled background behind satellite widgets", "island settings: satellite background description")
                    checked: SettingsData.dankIslandSatelliteBackground
                    enabled: SettingsData.dankIslandSatellitesEnabled
                    onToggled: checked => SettingsData.set("dankIslandSatelliteBackground", checked)
                }

                SettingsToggleRow {
                    settingKey: "dankIslandSatelliteGothCorners"
                    tags: ["island", "satellite", "goth", "corners", "wing", "sweep"]
                    text: I18n.tr("Goth Corners", "island settings: satellite goth corners toggle")
                    description: I18n.tr("Sweep the background into the screen edges", "island settings: satellite goth corners description")
                    checked: SettingsData.dankIslandSatelliteGothCorners
                    enabled: SettingsData.dankIslandSatellitesEnabled && SettingsData.dankIslandSatelliteBackground
                    onToggled: checked => SettingsData.set("dankIslandSatelliteGothCorners", checked)
                }

                SettingsSliderRow {
                    settingKey: "dankIslandSatelliteSwoopRadius"
                    tags: ["island", "satellite", "goth", "corners", "radius", "sweep", "size"]
                    text: I18n.tr("Corner Radius", "island settings: satellite goth corner radius slider")
                    unit: "px"
                    minimum: 4
                    maximum: 64
                    step: 1
                    defaultValue: 24
                    value: SettingsData.dankIslandSatelliteSwoopRadius
                    enabled: SettingsData.dankIslandSatellitesEnabled && SettingsData.dankIslandSatelliteBackground && SettingsData.dankIslandSatelliteGothCorners
                    onSliderValueChanged: value => SettingsData.set("dankIslandSatelliteSwoopRadius", value)
                }

                SettingsSliderRow {
                    settingKey: "dankIslandSatelliteTransparency"
                    tags: ["island", "satellite", "background", "opacity", "transparency", "blur"]
                    text: I18n.tr("Opacity", "island settings: satellite background opacity slider")
                    unit: "%"
                    minimum: 0
                    maximum: 100
                    step: 1
                    defaultValue: 100
                    value: Math.round(SettingsData.dankIslandSatelliteTransparency * 100)
                    enabled: SettingsData.dankIslandSatellitesEnabled && SettingsData.dankIslandSatelliteBackground
                    onSliderValueChanged: value => SettingsData.set("dankIslandSatelliteTransparency", value / 100)
                }

                SettingsButtonGroupRow {
                    settingKey: "dankIslandSatellitePosition"
                    tags: ["island", "satellite", "widgets", "position", "edges", "center"]
                    text: I18n.tr("Position", "island settings: position card title")
                    description: I18n.tr("Keep widgets beside the island or align them like a standalone bar", "island settings: satellite position description")
                    model: [I18n.tr("Near Island", "island settings: satellites hug the island"), I18n.tr("Screen Edges", "island settings: satellites sit at screen edges")]
                    currentIndex: root.valueIndex(root.satellitePositionValues, SettingsData.dankIslandSatellitePosition, "island")
                    enabled: SettingsData.dankIslandSatellitesEnabled
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("dankIslandSatellitePosition", root.satellitePositionValues[index] ?? "island");
                    }
                }

                SettingsSliderRow {
                    settingKey: "dankIslandSatelliteGap"
                    tags: ["island", "satellite", "widgets", "gap", "spacing"]
                    text: I18n.tr("Island Gap", "island settings: satellite to island gap slider")
                    unit: "px"
                    minimum: 4
                    maximum: 48
                    step: 1
                    defaultValue: 12
                    value: SettingsData.dankIslandSatelliteGap
                    enabled: SettingsData.dankIslandSatellitesEnabled && SettingsData.dankIslandSatellitePosition !== "edges"
                    onSliderValueChanged: value => SettingsData.set("dankIslandSatelliteGap", value)
                }

                StyledText {
                    width: parent.width
                    text: I18n.tr("Satellites widget to place left or right of the island", "island settings: satellite widgets hint")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                    visible: SettingsData.dankIslandSatellitesEnabled
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "touch_app"
                title: I18n.tr("Behavior", "island settings: behavior card title")
                settingKey: "dankIslandInteraction"
                enabled: SettingsData.dankIslandEnabled

                SettingsButtonGroupRow {
                    settingKey: "dankIslandInteractionMode"
                    tags: ["island", "interaction", "click", "hybrid", "expand"]
                    text: I18n.tr("Expansion Mode", "island settings: click or hover expansion row")
                    description: I18n.tr("Click expands only on an intentional press. Hybrid peeks the current compact face on hover", "island settings: expansion mode description")
                    model: [I18n.tr("Click", "island settings: click expansion mode"), I18n.tr("Hybrid", "island settings: hover plus click expansion mode")]
                    currentIndex: root.valueIndex(root.interactionModeValues, SettingsData.dankIslandInteractionMode, "hybrid")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("dankIslandInteractionMode", root.interactionModeValues[index] ?? "hybrid");
                    }
                }

                StyledText {
                    width: parent.width
                    text: I18n.tr("Hybrid peeks the current compact face on hover. Click pins a destination so it stays open", "island settings: hybrid mode hint")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                    visible: SettingsData.dankIslandInteractionMode !== "click"
                }

                SettingsSliderRow {
                    settingKey: "dankIslandHoverOpenDelay"
                    tags: ["island", "interaction", "hover", "open", "delay"]
                    text: I18n.tr("Open Delay", "island settings: hover open delay slider")
                    unit: "ms"
                    minimum: 0
                    maximum: 1000
                    step: 10
                    defaultValue: 150
                    value: SettingsData.dankIslandHoverOpenDelay
                    enabled: SettingsData.dankIslandInteractionMode !== "click"
                    onSliderValueChanged: value => SettingsData.set("dankIslandHoverOpenDelay", value)
                }

                SettingsSliderRow {
                    settingKey: "dankIslandHoverCloseDelay"
                    tags: ["island", "interaction", "hover", "close", "delay"]
                    text: I18n.tr("Hide Delay", "island settings: hover hide delay slider")
                    unit: "ms"
                    minimum: 0
                    maximum: 1000
                    step: 10
                    defaultValue: 150
                    value: SettingsData.dankIslandHoverCloseDelay
                    enabled: SettingsData.dankIslandInteractionMode !== "click"
                    onSliderValueChanged: value => SettingsData.set("dankIslandHoverCloseDelay", value)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "animation"
                title: I18n.tr("Motion & Accessibility", "island settings: motion card title")
                settingKey: "dankIslandMotion"
                collapsible: true
                enabled: SettingsData.dankIslandEnabled

                SettingsToggleRow {
                    settingKey: "dankIslandReducedMotion"
                    tags: ["island", "motion", "animation", "reduce", "accessibility", "spring"]
                    text: I18n.tr("Reduce Motion", "island settings: reduce motion toggle")
                    description: I18n.tr("Apply island geometry changes immediately without spring overshoot", "island settings: reduce motion description")
                    checked: SettingsData.dankIslandReducedMotion
                    onToggled: checked => SettingsData.set("dankIslandReducedMotion", checked)
                }

                SettingsSliderRow {
                    settingKey: "dankIslandSpringStiffness"
                    tags: ["island", "motion", "spring", "stiffness", "animation"]
                    text: I18n.tr("Spring Stiffness", "island settings: spring stiffness slider")
                    description: I18n.tr("Higher values pull island toward its target more strongly", "island settings: stiffness description")
                    minimum: 100
                    maximum: 1200
                    step: 10
                    value: Math.round(SettingsData.dankIslandSpringStiffness)
                    defaultValue: 560
                    enabled: !SettingsData.dankIslandReducedMotion
                    onSliderValueChanged: value => SettingsData.set("dankIslandSpringStiffness", value)
                }

                SettingsSliderRow {
                    settingKey: "dankIslandSpringDamping"
                    tags: ["island", "motion", "spring", "damping", "bounce", "animation"]
                    text: I18n.tr("Spring Damping", "island settings: spring damping slider")
                    description: I18n.tr("Higher values settle island with less bounce", "island settings: damping description")
                    minimum: 10
                    maximum: 100
                    step: 1
                    value: Math.round(SettingsData.dankIslandSpringDamping)
                    defaultValue: 37
                    enabled: !SettingsData.dankIslandReducedMotion
                    onSliderValueChanged: value => SettingsData.set("dankIslandSpringDamping", value)
                }

                SettingsSliderRow {
                    settingKey: "dankIslandSpringMass"
                    tags: ["island", "motion", "spring", "mass", "inertia", "animation"]
                    text: I18n.tr("Spring Mass", "island settings: spring mass slider")
                    description: I18n.tr("Higher percentages give island more inertia", "island settings: mass description")
                    minimum: 25
                    maximum: 300
                    step: 5
                    unit: "%"
                    value: Math.round(SettingsData.dankIslandSpringMass * 100)
                    defaultValue: 100
                    enabled: !SettingsData.dankIslandReducedMotion
                    onSliderValueChanged: value => SettingsData.set("dankIslandSpringMass", value / 100)
                }
            }
        }
    }
}
