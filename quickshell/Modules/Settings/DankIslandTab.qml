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
                    "name": I18n.tr("Off")
                })];
        const configs = SettingsData.barConfigs || [];
        for (let i = 0; i < configs.length; i++)
            rows.push({
                "id": configs[i].id,
                "name": configs[i].name || I18n.tr("Bar %1").arg(i + 1)
            });
        return rows;
    }
    readonly property int instanceIndex: Math.max(0, root.instanceChoices.findIndex(row => row.id === SettingsData.dankIslandBarId))

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
                width: parent.width
                iconName: "view_in_ar"
                title: I18n.tr("Dank Island - Beta")
                settingKey: "dankIslandBarId"

                SettingsButtonGroupRow {
                    settingKey: "dankIslandBarId"
                    tags: ["island", "activities", "media", "notifications", "osd", "bar"]
                    text: I18n.tr("Island Instance")
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
                title: I18n.tr("Placement")
                settingKey: "dankIslandPlacement"
                enabled: SettingsData.dankIslandEnabled

                SettingsToggleRow {
                    settingKey: "dankIslandFloating"
                    tags: ["island", "placement", "float", "overlay", "exclusive", "reserve"]
                    text: I18n.tr("Float")
                    description: I18n.tr("Floats above windows and other content")
                    checked: SettingsData.dankIslandFloating
                    onToggled: checked => SettingsData.set("dankIslandFloating", checked)
                }

                SettingsToggleRow {
                    settingKey: "dankIslandUseOverlayLayer"
                    tags: ["island", "fullscreen", "overlay", "layer"]
                    text: I18n.tr("Use Overlay Layer", "island layer toggle: use Wayland overlay layer")
                    description: I18n.tr("Stage the Wayland overlay layer to remain visible over fullscreen apps")
                    checked: SettingsData.dankIslandUseOverlayLayer
                    onToggled: checked => SettingsData.set("dankIslandUseOverlayLayer", checked)
                }

                SettingsSliderRow {
                    settingKey: "dankIslandReserveHeight"
                    tags: ["island", "placement", "reservation", "exclusive", "height"]
                    text: I18n.tr("Reserved Height")
                    description: I18n.tr("Space kept clear for compact island and satellites")
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
                    text: I18n.tr("Compact Island Height")
                    description: I18n.tr("Resize the resting island to align with nearby widgets")
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
                    text: I18n.tr("Outer Gap")
                    description: I18n.tr("Distance between display edge and island")
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
                    text: I18n.tr("Horizontal Offset")
                    description: I18n.tr("Move island and satellites left or right from display center")
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
                id: homeCompactCard

                width: parent.width
                iconName: "home"
                title: I18n.tr("Home Compact")
                settingKey: "dankIslandActivities"
                enabled: SettingsData.dankIslandEnabled

                readonly property var _homeSlotValues: ["left", "right", "hidden"]

                function homeSlotIndex(value, fallback) {
                    const index = _homeSlotValues.indexOf(value);
                    if (index >= 0)
                        return index;
                    return Math.max(0, _homeSlotValues.indexOf(fallback));
                }

                StyledText {
                    width: parent.width
                    text: I18n.tr("Choose which shortcuts sit left or right of the clock")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

                SettingsButtonGroupRow {
                    settingKey: "dankIslandHomeMediaSlot"
                    tags: ["island", "home", "compact", "media", "launcher", "search", "cava"]
                    text: I18n.tr("Media / Launcher")
                    description: I18n.tr("Search when idle, visualizer when media is playing")
                    model: [I18n.tr("Left"), I18n.tr("Right"), I18n.tr("Hidden")]
                    currentIndex: homeCompactCard.homeSlotIndex(SettingsData.dankIslandHomeMediaSlot, "left")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("dankIslandHomeMediaSlot", homeCompactCard._homeSlotValues[index] ?? "left");
                    }
                }

                SettingsButtonGroupRow {
                    settingKey: "dankIslandHomeStatusSlot"
                    tags: ["island", "home", "compact", "battery", "control center", "tools"]
                    text: I18n.tr("Battery / Control Center")
                    description: BatteryService.batteryAvailable ? I18n.tr("Battery gauge opens Control Center") : I18n.tr("Tools icon opens Control Center")
                    model: [I18n.tr("Left"), I18n.tr("Right"), I18n.tr("Hidden")]
                    currentIndex: homeCompactCard.homeSlotIndex(SettingsData.dankIslandHomeStatusSlot, "right")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("dankIslandHomeStatusSlot", homeCompactCard._homeSlotValues[index] ?? "right");
                    }
                }

                SettingsButtonGroupRow {
                    settingKey: "dankIslandHomeWeatherSlot"
                    tags: ["island", "home", "compact", "weather", "forecast"]
                    text: I18n.tr("Weather")
                    description: SettingsData.weatherEnabled ? I18n.tr("Weather icon and temperature open the weather activity") : I18n.tr("Enable weather in Time & Weather to show this shortcut")
                    model: [I18n.tr("Left"), I18n.tr("Right"), I18n.tr("Hidden")]
                    currentIndex: homeCompactCard.homeSlotIndex(SettingsData.dankIslandHomeWeatherSlot, "hidden")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("dankIslandHomeWeatherSlot", homeCompactCard._homeSlotValues[index] ?? "hidden");
                    }
                }

                SettingsToggleRow {
                    settingKey: "dankIslandHomeCompactTight"
                    tags: ["island", "home", "compact", "narrow", "width", "height", "clock"]
                    text: I18n.tr("Compact Clock Pill")
                    description: I18n.tr("Compact home clock pill in both width and height")
                    checked: SettingsData.dankIslandHomeCompactTight
                    onToggled: checked => SettingsData.set("dankIslandHomeCompactTight", checked)
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankButton {
                        text: I18n.tr("Launcher Settings")
                        iconName: "grid_view"
                        onClicked: {
                            if (!root.parentModal)
                                return;
                            SettingsSearchService.navigateToSection("launcherStyle");
                            root.parentModal.showWithTabName("launcher");
                        }
                    }

                    DankButton {
                        text: I18n.tr("Weather Settings")
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
                title: I18n.tr("Appearance")
                settingKey: "dankIslandAppearance"
                enabled: SettingsData.dankIslandEnabled

                SettingsButtonGroupRow {
                    settingKey: "dankIslandPalette"
                    tags: ["island", "appearance", "palette", "surface", "bright", "dim"]
                    text: I18n.tr("Palette")
                    model: [I18n.tr("Default"), I18n.tr("Bright"), I18n.tr("Dim")]
                    currentIndex: SettingsData.dankIslandPalette === "bright" ? 1 : SettingsData.dankIslandPalette === "dim" ? 2 : 0
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        SettingsData.set("dankIslandPalette", index === 1 ? "bright" : index === 2 ? "dim" : "default");
                    }
                }

                SettingsToggleRow {
                    settingKey: "dankIslandHighContrast"
                    tags: ["island", "appearance", "contrast", "accessibility", "outline"]
                    text: I18n.tr("High Contrast")
                    description: I18n.tr("Draw an outline and use the highest-contrast surface tone")
                    checked: SettingsData.dankIslandHighContrast
                    onToggled: checked => SettingsData.set("dankIslandHighContrast", checked)
                }

                SettingsToggleRow {
                    settingKey: "dankIslandNotificationExpand"
                    tags: ["island", "notifications", "expand", "arrival", "size"]
                    text: I18n.tr("Expand Notifications")
                    description: I18n.tr("Expand notifications by default instead of click or hover")
                    checked: SettingsData.dankIslandNotificationExpand
                    onToggled: checked => SettingsData.set("dankIslandNotificationExpand", checked)
                }

                SettingsToggleRow {
                    settingKey: "dankIslandMediaClockVisible"
                    tags: ["island", "media", "clock", "compact", "time"]
                    text: I18n.tr("Keep Clock with Media")
                    description: I18n.tr("Show a clickable clock beside compact media details")
                    checked: SettingsData.dankIslandMediaClockVisible
                    onToggled: checked => SettingsData.set("dankIslandMediaClockVisible", checked)
                }

                SettingsButtonGroupRow {
                    settingKey: "dankIslandBatteryStyle"
                    tags: ["island", "battery", "gauge", "solid", "outline", "appearance"]
                    text: I18n.tr("Battery Gauge")
                    description: I18n.tr("Solid material type or Outline")
                    visible: BatteryService.batteryAvailable
                    model: [I18n.tr("Solid"), I18n.tr("Outline")]
                    currentIndex: SettingsData.dankIslandBatteryStyle === "outline" ? 1 : 0
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("dankIslandBatteryStyle", index === 1 ? "outline" : "solid");
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "widgets"
                title: I18n.tr("Satellite Widgets")
                settingKey: "dankIslandSatellites"
                collapsible: true
                expanded: true
                enabled: SettingsData.dankIslandEnabled

                SettingsToggleRow {
                    settingKey: "dankIslandSatellitesEnabled"
                    tags: ["island", "satellite", "widgets", "left", "right"]
                    text: I18n.tr("Show Satellite Widgets")
                    description: I18n.tr("Place independent widgets to left and right of island")
                    checked: SettingsData.dankIslandSatellitesEnabled
                    onToggled: checked => SettingsData.set("dankIslandSatellitesEnabled", checked)
                }

                SettingsButtonGroupRow {
                    settingKey: "dankIslandSatellitePosition"
                    tags: ["island", "satellite", "widgets", "position", "edges", "center"]
                    text: I18n.tr("Placement")
                    description: I18n.tr("Keep widgets beside the island or align them like a standalone bar")
                    model: [I18n.tr("Near Island"), I18n.tr("Screen Edges")]
                    currentIndex: SettingsData.dankIslandSatellitePosition === "edges" ? 1 : 0
                    enabled: SettingsData.dankIslandSatellitesEnabled
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("dankIslandSatellitePosition", index === 1 ? "edges" : "island");
                    }
                }

                SettingsSliderRow {
                    settingKey: "dankIslandSatelliteGap"
                    tags: ["island", "satellite", "widgets", "gap", "spacing"]
                    text: I18n.tr("Island Gap")
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
                    text: I18n.tr("Satellites widget to place left or right of the island")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                    visible: SettingsData.dankIslandSatellitesEnabled
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "touch_app"
                title: I18n.tr("Interaction")
                settingKey: "dankIslandInteraction"
                enabled: SettingsData.dankIslandEnabled

                SettingsButtonGroupRow {
                    settingKey: "dankIslandInteractionMode"
                    tags: ["island", "interaction", "click", "hybrid", "expand"]
                    text: I18n.tr("Expansion Mode")
                    description: I18n.tr("Click expands only on an intentional press. Hybrid peeks the current compact face on hover")
                    readonly property var _modeValues: ["click", "hybrid"]
                    model: [I18n.tr("Click"), I18n.tr("Hybrid")]
                    currentIndex: SettingsData.dankIslandInteractionMode === "click" ? 0 : 1
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("dankIslandInteractionMode", _modeValues[index] ?? "hybrid");
                    }
                }

                StyledText {
                    width: parent.width
                    text: I18n.tr("Hybrid peeks the current compact face on hover. Click pins a destination so it stays open")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                    visible: SettingsData.dankIslandInteractionMode !== "click"
                }

                SettingsSliderRow {
                    settingKey: "dankIslandHoverOpenDelay"
                    tags: ["island", "interaction", "hover", "open", "delay"]
                    text: I18n.tr("Hover Open Delay")
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
                    text: I18n.tr("Hover Close Delay")
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
                title: I18n.tr("Motion & Accessibility")
                settingKey: "dankIslandMotion"
                collapsible: true
                enabled: SettingsData.dankIslandEnabled

                SettingsToggleRow {
                    settingKey: "dankIslandReducedMotion"
                    text: I18n.tr("Reduce Motion")
                    description: I18n.tr("Apply island geometry changes immediately without spring overshoot")
                    checked: SettingsData.dankIslandReducedMotion
                    onToggled: checked => SettingsData.set("dankIslandReducedMotion", checked)
                }

                SettingsSliderRow {
                    settingKey: "dankIslandSpringStiffness"
                    text: I18n.tr("Spring Stiffness")
                    description: I18n.tr("Higher values pull island toward its target more strongly")
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
                    text: I18n.tr("Spring Damping")
                    description: I18n.tr("Higher values settle island with less bounce")
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
                    text: I18n.tr("Spring Mass")
                    description: I18n.tr("Higher percentages give island more inertia")
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
