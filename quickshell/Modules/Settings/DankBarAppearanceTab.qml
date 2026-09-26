import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var parentModal: null
    readonly property bool widgetBackgroundEnabled: !(bar.selectedBarConfig?.noBackground ?? false)
    readonly property var outlineColors: ["surfaceText", "secondary", "primary"]
    readonly property var outlineColorLabels: [I18n.tr("Surface"), I18n.tr("Secondary"), I18n.tr("Primary")]
    readonly property var paletteValues: ["default", "bright", "dim"]
    readonly property var batteryStyleValues: ["solid", "outline", "ring"]
    readonly property var satellitePositionValues: ["island", "edges"]
    readonly property var clockDisplayValues: ["time", "date", "both"]
    readonly property var systemLevelDisplayValues: ["icon", "percentage", "both"]
    readonly property var statusContentValues: ["battery", "connectivity"]
    readonly property bool selectedIslandEnabled: bar.selectedBarIsIsland && (bar.selectedBarConfig?.enabled ?? false)
    readonly property bool selectedIslandFree: bar.selectedBarIsIsland && SettingsData.islandFreePlacement(bar.selectedBarConfig)
    readonly property bool homeBatteryShown: root.selectedIslandEnabled && SettingsData.islandHomeGroupEnabled(bar.selectedBarConfig, "status") && BatteryService.batteryAvailable && SettingsData.islandHomeStatusContent(bar.selectedBarConfig) === "battery"
    readonly property int frameInsetPaddingDisplay: Math.round(SettingsData.frameBarContentGap)

    function valueIndex(values, value, fallback) {
        const index = values.indexOf(value);
        return index >= 0 ? index : Math.max(0, values.indexOf(fallback));
    }

    BarSelectionState {
        id: bar
    }

    SettingsPage {
        id: mainColumn

        SettingsCard {
            iconName: "border_outer"
            title: I18n.tr("Frame")
            settingKey: "frameBorder"
            collapsible: true
            visible: SettingsData.frameEnabled

            SettingsSliderRow {
                settingKey: "frameRounding"
                tags: ["frame", "border", "rounding", "radius", "corner"]
                text: I18n.tr("Radius", "corner radius slider label")
                unit: "px"
                minimum: 0
                maximum: 100
                step: 1
                value: SettingsData.frameRounding
                onSliderDragFinished: v => SettingsData.set("frameRounding", v)
            }

            SettingsSliderRow {
                settingKey: "frameThickness"
                tags: ["frame", "border", "thickness", "size", "width"]
                text: I18n.tr("Width")
                unit: "px"
                minimum: 2
                maximum: 100
                step: 1
                value: SettingsData.frameThickness
                onSliderDragFinished: v => SettingsData.set("frameThickness", v)
            }

            SettingsSliderRow {
                settingKey: "frameBarSize"
                tags: ["frame", "bar", "thickness", "size", "height", "width"]
                text: I18n.tr("Bar size")
                unit: "px"
                minimum: 24
                maximum: 100
                step: 1
                value: SettingsData.frameBarSize
                onSliderDragFinished: v => SettingsData.set("frameBarSize", v)
            }

            SettingsSliderRow {
                settingKey: "frameBarInsetPadding"
                tags: ["frame", "bar", "edge", "inset", "padding", "corner", "end"]
                text: I18n.tr("Bar inset padding")
                minimumLabel: I18n.tr("Edge to edge", "slider minimum label, bar touches the screen edges")
                unit: "px"
                minimum: 0
                maximum: 48
                step: 1
                value: root.frameInsetPaddingDisplay
                onSliderDragFinished: v => SettingsData.set("frameBarInsetPadding", v)
            }

            SettingsToggleRow {
                id: frameBlurToggle
                settingKey: "frameBlurEnabled"
                tags: ["frame", "blur", "background", "glass", "transparency", "frosted"]
                text: I18n.tr("Blur")
                checked: SettingsData.frameBlurEnabled
                onToggled: checked => SettingsData.set("frameBlurEnabled", checked)
                enabled: BlurService.available && SettingsData.blurEnabled
                visible: BlurService.available
            }

            SettingsRow {
                visible: BlurService.available && !SettingsData.blurEnabled
                body: Item {
                    width: parent.width
                    height: blurToggleNote.height + Theme.spacingM * 2

                    Row {
                        id: blurToggleNote
                        x: Theme.spacingM
                        width: parent.width - Theme.spacingM * 2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "blur_on"
                            size: Theme.fontSizeMedium
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Frame Blur follows Background Blur in Theme & Colors")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            width: parent.width - Theme.fontSizeMedium - Theme.spacingS
                        }
                    }
                }
            }
        }

        SettingsCard {
            iconName: "rounded_corner"
            title: I18n.tr("Surface")
            settingKey: "barCorners"
            tags: ["background", "opacity", "corners", "rounded", "goth", "shadow", "palette", "contrast"]
            visible: (bar.selectedBarConfig?.enabled ?? false) && !bar.selectedBarFrameStyled

            SettingsButtonGroupRow {
                settingKey: "islandPalette"
                tags: ["island", "appearance", "palette", "surface", "bright", "dim"]
                visible: bar.selectedBarIsIsland
                resetStore: bar
                resetKeys: ["islandPalette"]
                text: I18n.tr("Palette", "island settings: surface tone choice")
                model: [I18n.tr("Default", "island settings: default surface tone"), I18n.tr("Bright", "island settings: bright surface tone"), I18n.tr("Dim", "island settings: dim surface tone")]
                currentIndex: root.valueIndex(root.paletteValues, bar.islandSetting("islandPalette"), "default")
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        bar.apply("islandPalette", root.paletteValues[index] ?? "default");
                }
            }

            SettingsToggleRow {
                settingKey: "islandHighContrast"
                tags: ["island", "appearance", "contrast", "accessibility", "outline"]
                visible: bar.selectedBarIsIsland
                resetStore: bar
                resetKeys: ["islandHighContrast"]
                text: I18n.tr("High contrast", "island settings: high contrast toggle")
                checked: bar.islandSetting("islandHighContrast")
                onToggled: checked => bar.apply("islandHighContrast", checked)
            }

            SurfaceColorRow {
                settingKey: "barSurfaceColor"
                tags: ["background", "color", "surface", "bar", "material"]
                resetStore: bar
                resetKeys: ["surfaceColor", "surfaceCustomColor"]
                text: I18n.tr("Background")
                defaultColor: Theme.hostSurface
                currentMode: bar.selectedBarConfig?.surfaceColor ?? "default"
                customColor: bar.selectedBarConfig?.surfaceCustomColor ?? SettingsData.barConfigDefault("surfaceCustomColor")
                pickerTitle: I18n.tr("Background")
                onModeSelected: mode => bar.apply("surfaceColor", mode)
                onCustomColorSelected: selectedColor => bar.apply("surfaceCustomColor", selectedColor.toString())
            }

            SettingsControlledBy {
                visible: !bar.islandOwnsSelectedBarTop
                target: "surfaces"
                parentModal: root.parentModal
                section: "surfaceOpacity_bar_" + bar.selectedBarId
                settingLabel: I18n.tr("Opacity")
            }

            SettingsButtonGroupRow {
                settingKey: "barCornerStyle"
                tags: ["rounded", "attached", "square", "corners", "edge", "screen", "flush"]
                text: I18n.tr("Corner style")
                visible: !bar.selectedBarFrameSanitized && !bar.islandOwnsSelectedBarTop
                resetStore: bar
                resetKeys: ["squareCorners", "attachToScreenEdge"]
                model: [I18n.tr("Rounded", "bar corner style option"), I18n.tr("Flush", "bar corner style option"), I18n.tr("Square", "bar corner style option")]
                currentIndex: {
                    if (bar.selectedBarConfig?.squareCorners ?? false)
                        return 2;
                    if (bar.selectedBarConfig?.attachToScreenEdge ?? false)
                        return 1;
                    return 0;
                }
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    SettingsData.updateBarConfig(bar.selectedBarId, {
                        squareCorners: index === 2,
                        attachToScreenEdge: index === 1
                    });
                }
            }

            SettingsToggleRow {
                settingKey: "barGothCorners"
                tags: ["goth", "corners", "concave", "cutout"]
                text: I18n.tr("Goth corners")
                description: I18n.tr("Adds concave curves where the bar meets the screen edge", "bar goth corners toggle description")
                visible: !bar.selectedBarFrameSanitized && !bar.islandOwnsSelectedBarTop
                resetStore: bar
                resetKeys: ["gothCornersEnabled"]
                checked: bar.selectedBarConfig?.gothCornersEnabled ?? false
                onToggled: checked => SettingsData.updateBarConfig(bar.selectedBarId, {
                        gothCornersEnabled: checked
                    })
            }

            SettingsToggleRow {
                text: I18n.tr("Custom radius")
                tags: ["goth", "corners", "radius"]
                visible: (bar.selectedBarConfig?.gothCornersEnabled ?? false) && !bar.selectedBarFrameSanitized && !bar.islandOwnsSelectedBarTop
                resetStore: bar
                resetKeys: ["gothCornerRadiusOverride"]
                checked: bar.selectedBarConfig?.gothCornerRadiusOverride ?? false
                onToggled: checked => SettingsData.updateBarConfig(bar.selectedBarId, {
                        gothCornerRadiusOverride: checked
                    })
            }

            SettingsSliderRow {
                visible: (bar.selectedBarConfig?.gothCornersEnabled ?? false) && (bar.selectedBarConfig?.gothCornerRadiusOverride ?? false) && !bar.selectedBarFrameSanitized && !bar.islandOwnsSelectedBarTop
                text: I18n.tr("Radius")
                unit: "px"
                resetStore: bar
                resetKeys: ["gothCornerRadiusValue"]
                value: bar.selectedBarConfig?.gothCornerRadiusValue ?? 12
                minimum: 0
                maximum: 64
                onSliderDragFinished: finalValue => SettingsData.updateBarConfig(bar.selectedBarId, {
                        gothCornerRadiusValue: finalValue
                    })
            }

            SettingsControlledBy {
                visible: !bar.selectedBarFrameSanitized && !bar.islandOwnsSelectedBarTop
                target: "shadows"
                parentModal: root.parentModal
                section: "barShadow"
                settingLabel: I18n.tr("Shadow", "bar shadow settings card")
            }
        }

        SettingsToggleCard {
            settingKey: "barBorder"
            iconName: "border_style"
            title: I18n.tr("Border", "noun, settings toggle card title for an outline around a surface")
            visible: (bar.selectedBarConfig?.enabled ?? false) && !bar.selectedBarFrameSanitized && !bar.islandOwnsSelectedBarTop
            resetStore: bar
            resetKeys: ["borderEnabled"]
            checked: bar.selectedBarConfig?.borderEnabled ?? false
            onToggled: checked => SettingsData.updateBarConfig(bar.selectedBarId, {
                    borderEnabled: checked
                })

            SettingsButtonGroupRow {
                text: I18n.tr("Color")
                resetStore: bar
                resetKeys: ["borderColor"]
                model: root.outlineColorLabels
                currentIndex: Math.max(0, root.outlineColors.indexOf(bar.selectedBarConfig?.borderColor || "surfaceText"))
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    SettingsData.updateBarConfig(bar.selectedBarId, {
                        borderColor: root.outlineColors[index]
                    });
                }
            }

            SettingsSliderRow {
                text: I18n.tr("Opacity")
                resetStore: bar
                resetKeys: ["borderOpacity"]
                value: (bar.selectedBarConfig?.borderOpacity ?? 1.0) * 100
                minimum: 0
                maximum: 100
                onSliderDragFinished: finalValue => SettingsData.updateBarConfig(bar.selectedBarId, {
                        borderOpacity: finalValue / 100
                    })
            }

            SettingsSliderRow {
                text: I18n.tr("Thickness")
                resetStore: bar
                resetKeys: ["borderThickness"]
                value: bar.selectedBarConfig?.borderThickness ?? 1
                minimum: 1
                maximum: 10
                unit: "px"
                onSliderDragFinished: finalValue => SettingsData.updateBarConfig(bar.selectedBarId, {
                        borderThickness: finalValue
                    })
            }
        }

        SettingsCard {
            iconName: "space_bar"
            title: I18n.tr("Size & spacing")
            settingKey: "barSpacing"
            tags: ["size", "scale", "font", "icon", "spacing", "padding", "inset", "length"]
            visible: bar.selectedBarConfig?.enabled ?? false

            SettingsSliderRow {
                settingKey: "islandCompactThickness"
                tags: ["island", "placement", "compact", "height", "width", "thickness", "size", "satellite"]
                visible: bar.selectedBarIsIsland && !root.selectedIslandFree
                resetStore: bar
                resetKeys: ["islandCompactThickness"]
                text: bar.selectedBarIsVertical ? I18n.tr("Compact width", "island settings: compact pill width slider") : I18n.tr("Compact height", "island settings: compact pill height slider")
                unit: "px"
                minimum: 24
                maximum: 72
                step: 1
                value: bar.islandSetting("islandCompactThickness")
                onSliderValueChanged: value => bar.apply("islandCompactThickness", value)
            }

            SettingsSliderRow {
                settingKey: "barSize"
                tags: ["size", "thickness", "height", "inner"]
                visible: !bar.selectedBarFrameStyled
                text: I18n.tr("Size")
                resetStore: bar
                resetKeys: ["innerPadding"]
                value: bar.selectedBarConfig?.innerPadding ?? 4
                minimum: -8
                maximum: 24
                unit: "px"
                onSliderDragFinished: finalValue => SettingsData.updateBarConfig(bar.selectedBarId, {
                        innerPadding: finalValue
                    })
            }

            SettingsSliderRow {
                settingKey: "barFontScale"
                tags: ["font", "text", "scale", "size"]
                text: I18n.tr("Font scale")
                resetStore: bar
                resetKeys: ["fontScale"]
                value: Math.round((bar.selectedBarConfig?.fontScale ?? 1.0) * 100)
                minimum: 50
                maximum: 200
                onSliderValueChanged: newValue => SettingsData.updateBarConfig(bar.selectedBarId, {
                        fontScale: newValue / 100
                    })
            }

            SettingsSliderRow {
                settingKey: "barIconScale"
                tags: ["icon", "scale", "size"]
                text: I18n.tr("Icon scale")
                resetStore: bar
                resetKeys: ["iconScale"]
                value: Math.round((bar.selectedBarConfig?.iconScale ?? 1.0) * 100)
                minimum: 50
                maximum: 200
                onSliderValueChanged: newValue => SettingsData.updateBarConfig(bar.selectedBarId, {
                        iconScale: newValue / 100
                    })
            }

            SettingsSliderRow {
                visible: !bar.selectedBarFrameStyled && !bar.islandOwnsSelectedBarTop
                text: I18n.tr("Edge spacing")
                tags: ["edge", "spacing", "gap", "margin"]
                resetStore: bar
                resetKeys: ["spacing"]
                value: bar.selectedBarConfig?.spacing ?? 4
                minimum: 0
                maximum: 32
                unit: "px"
                onSliderDragFinished: finalValue => SettingsData.updateBarConfig(bar.selectedBarId, {
                        spacing: finalValue
                    })
            }

            SettingsRow {
                settingKey: "barLengthMode"
                tags: ["bar", "width", "height", "length", "fit", "full", "custom", "percent", "compact", "widgets", "hug", "shrink"]
                title: bar.selectedBarIsVertical ? I18n.tr("Height") : I18n.tr("Width")
                visible: !bar.selectedBarFrameStyled && !bar.islandOwnsSelectedBarTop
                resetStore: bar
                resetKeys: ["barLengthMode", "barLengthPercent"]

                body: SettingsLayoutPicker {
                    barLength: true
                    vertical: bar.selectedBarIsVertical
                    choices: [
                        {
                            key: "full",
                            label: I18n.tr("Full", "bar length option, the bar spans the whole edge")
                        },
                        {
                            key: "percent",
                            label: I18n.tr("Custom", "bar length option, the bar spans a percentage of the edge")
                        },
                        {
                            key: "fit",
                            label: I18n.tr("Fit", "bar length option, the bar spans only its widgets")
                        }
                    ]
                    selectedKey: bar.selectedBarConfig?.barLengthMode ?? "full"
                    onSelected: key => SettingsData.updateBarConfig(bar.selectedBarId, {
                            barLengthMode: key
                        })
                }
            }

            SettingsSliderRow {
                settingKey: "barLengthPercent"
                tags: ["bar", "width", "height", "length", "percent", "custom"]
                visible: !bar.selectedBarFrameStyled && !bar.islandOwnsSelectedBarTop && (bar.selectedBarConfig?.barLengthMode ?? "full") === "percent"
                text: I18n.tr("Percentage")
                resetStore: bar
                resetKeys: ["barLengthPercent"]
                unit: "%"
                minimum: 10
                maximum: 100
                value: bar.selectedBarConfig?.barLengthPercent ?? 80
                onSliderDragFinished: finalValue => SettingsData.updateBarConfig(bar.selectedBarId, {
                        barLengthPercent: finalValue
                    })
            }

            SettingsSliderRow {
                settingKey: "barLengthPadding"
                visible: !bar.selectedBarFrameStyled && !bar.islandOwnsSelectedBarTop && (bar.selectedBarConfig?.barLengthMode ?? "full") === "full"
                text: I18n.tr("Length padding")
                description: I18n.tr("Shortens the bar at both ends", "bar length padding slider description")
                tags: ["bar", "length", "padding", "size", "shorter", "ends"]
                resetStore: bar
                resetKeys: ["barLengthPadding"]
                unit: "px"
                minimum: 0
                maximum: 512
                value: bar.selectedBarConfig?.barLengthPadding ?? 0
                onSliderDragFinished: finalValue => SettingsData.updateBarConfig(bar.selectedBarId, {
                        barLengthPadding: finalValue
                    })
            }

            SettingsSliderRow {
                visible: !bar.selectedBarFrameStyled
                text: I18n.tr("Inset padding")
                description: I18n.tr("Gap between the bar ends and the outermost widgets", "bar inset padding slider description")
                tags: ["bar", "padding", "inset", "edge", "corner", "end", "gap"]
                minimumLabel: I18n.tr("Edge to edge", "slider minimum label, bar touches the screen edges")
                resetStore: SettingsData.barInsetPaddingSyncAll ? SettingsData : bar
                resetKeys: SettingsData.barInsetPaddingSyncAll ? ["barInsetPaddingShared"] : ["barInsetPadding"]
                unit: "px"
                minimum: 0
                maximum: 48
                value: bar.insetPadDisplayValue
                onSliderDragFinished: finalValue => {
                    if (SettingsData.barInsetPaddingSyncAll) {
                        SettingsData.set("barInsetPaddingShared", finalValue);
                        return;
                    }
                    SettingsData.updateBarConfig(bar.selectedBarId, {
                        barInsetPadding: finalValue
                    });
                }
            }

            SettingsToggleRow {
                visible: !bar.selectedBarFrameStyled && SettingsData.barConfigs.length > 1
                text: I18n.tr("Sync inset padding")
                tags: ["bar", "padding", "inset", "edge", "sync", "all", "global"]
                resetKeys: ["barInsetPaddingSyncAll"]
                checked: SettingsData.barInsetPaddingSyncAll
                onToggled: checked => SettingsData.set("barInsetPaddingSyncAll", checked)
            }
        }

        SettingsCard {
            iconName: "home"
            title: I18n.tr("Home compact", "island settings: home face card title")
            settingKey: "islandActivities"
            tags: ["island", "home", "compact", "clock", "volume", "brightness", "battery", "pill"]
            visible: root.selectedIslandEnabled

            SettingsRow {
                title: I18n.tr("Layout", "noun, settings section title for arrangement options")

                DankButton {
                    text: I18n.tr("Bar widgets")
                    iconName: "widgets"
                    onClicked: {
                        if (!root.parentModal)
                            return;
                        SettingsSearchService.navigateToSection("islandHomeLayout");
                        root.parentModal.navigateTo("dankbar_widgets");
                    }
                }
            }

            SettingsButtonGroupRow {
                settingKey: "islandHomeClockDisplay"
                tags: ["island", "home", "compact", "clock", "time", "date"]
                resetStore: bar
                resetKeys: ["islandHomeClockDisplay"]
                text: I18n.tr("Clock style", "island settings: clock display mode row")
                model: [I18n.tr("Time", "island settings: clock shows time only"), I18n.tr("Date", "island settings: clock shows date only"), I18n.tr("Both", "island settings: clock shows time and date")]
                currentIndex: root.valueIndex(root.clockDisplayValues, bar.islandSetting("islandHomeClockDisplay"), "both")
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        bar.apply("islandHomeClockDisplay", root.clockDisplayValues[index] ?? "both");
                }
            }

            SettingsButtonGroupRow {
                settingKey: "islandHomeVolumeDisplay"
                tags: ["island", "home", "compact", "volume", "icon", "percentage"]
                resetStore: bar
                resetKeys: ["islandHomeVolumeDisplay"]
                text: I18n.tr("Volume style", "island settings: volume display mode row")
                visible: SettingsData.islandHomeGroupEnabled(bar.selectedBarConfig, "volume")
                model: [I18n.tr("Icon", "island settings: level shown as icon only"), I18n.tr("Percentage", "island settings: level shown as percentage only"), I18n.tr("Both", "island settings: level shown as icon and percentage")]
                currentIndex: root.valueIndex(root.systemLevelDisplayValues, bar.islandSetting("islandHomeVolumeDisplay"), "both")
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        bar.apply("islandHomeVolumeDisplay", root.systemLevelDisplayValues[index] ?? "both");
                }
            }

            SettingsButtonGroupRow {
                settingKey: "islandHomeBrightnessDisplay"
                tags: ["island", "home", "compact", "brightness", "icon", "percentage"]
                resetStore: bar
                resetKeys: ["islandHomeBrightnessDisplay"]
                text: I18n.tr("Brightness style", "island settings: brightness display mode row")
                visible: SettingsData.islandHomeGroupEnabled(bar.selectedBarConfig, "brightness")
                model: [I18n.tr("Icon", "island settings: level shown as icon only"), I18n.tr("Percentage", "island settings: level shown as percentage only"), I18n.tr("Both", "island settings: level shown as icon and percentage")]
                currentIndex: root.valueIndex(root.systemLevelDisplayValues, bar.islandSetting("islandHomeBrightnessDisplay"), "both")
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        bar.apply("islandHomeBrightnessDisplay", root.systemLevelDisplayValues[index] ?? "both");
                }
            }

            SettingsButtonGroupRow {
                settingKey: "islandHomeStatusContent"
                tags: ["island", "home", "compact", "status", "battery", "wifi", "bluetooth", "connectivity"]
                text: I18n.tr("Control Center", "island settings: status group content row")
                visible: SettingsData.islandHomeGroupEnabled(bar.selectedBarConfig, "status")
                model: [I18n.tr("Battery", "island settings: status group battery content"), I18n.tr("Wi-Fi & Bluetooth", "island settings: status group connectivity content")]
                currentIndex: root.valueIndex(root.statusContentValues, SettingsData.islandHomeStatusContent(bar.selectedBarConfig), "battery")
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        bar.apply("islandHomeStatusContent", root.statusContentValues[index] ?? "battery");
                }
            }

            SettingsButtonGroupRow {
                settingKey: "islandBatteryStyle"
                tags: ["island", "battery", "gauge", "solid", "outline", "ring", "circle", "appearance"]
                resetStore: bar
                resetKeys: ["islandBatteryStyle"]
                text: I18n.tr("Battery style", "island settings: battery meter style row")
                visible: root.homeBatteryShown
                model: [I18n.tr("Solid", "island settings: filled battery meter style"), I18n.tr("Outline", "island settings: outlined battery meter style"), I18n.tr("Circle", "island settings: circular battery meter style")]
                currentIndex: root.valueIndex(root.batteryStyleValues, bar.islandSetting("islandBatteryStyle"), "solid")
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        bar.apply("islandBatteryStyle", root.batteryStyleValues[index] ?? "solid");
                }
            }

            SettingsButtonGroupRow {
                settingKey: "islandBatteryColorMode"
                tags: ["island", "battery", "color", "level", "theme", "meter", "accent", "green", "red"]
                resetStore: bar
                resetKeys: ["batteryColorMode"]
                text: I18n.tr("Battery")
                visible: root.homeBatteryShown
                model: [I18n.tr("Theme", "battery settings: theme accent indicator colors"), I18n.tr("Level", "battery settings: charge level indicator colors")]
                currentIndex: (bar.selectedBarConfig?.batteryColorMode ?? "theme") === "level" ? 1 : 0
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        bar.apply("batteryColorMode", index === 1 ? "level" : "theme");
                }
            }

            SettingsToggleRow {
                settingKey: "islandHomeCompactTight"
                tags: ["island", "home", "compact", "narrow", "width", "height", "clock"]
                resetStore: bar
                resetKeys: ["islandHomeCompactTight"]
                text: I18n.tr("Compact pill", "island settings: tighter home pill toggle")
                checked: bar.islandSetting("islandHomeCompactTight")
                onToggled: checked => bar.apply("islandHomeCompactTight", checked)
            }
        }

        SettingsCard {
            iconName: "widgets"
            title: I18n.tr("Satellites", "island settings: satellite widgets card title")
            settingKey: "islandSatellites"
            collapsible: true
            expanded: true
            visible: root.selectedIslandEnabled

            SettingsToggleRow {
                settingKey: "islandSatellitesEnabled"
                tags: ["island", "satellite", "widgets", "left", "right"]
                resetStore: bar
                resetKeys: ["islandSatellitesEnabled"]
                text: I18n.tr("Show", "island settings: satellite widgets toggle")
                checked: bar.islandSetting("islandSatellitesEnabled")
                onToggled: checked => bar.apply("islandSatellitesEnabled", checked)
            }

            SettingsButtonGroupRow {
                settingKey: "islandSatellitePosition"
                tags: ["island", "satellite", "widgets", "position", "edges", "center"]
                resetStore: bar
                resetKeys: ["islandSatellitePosition"]
                text: I18n.tr("Position", "island settings: position card title")
                model: [I18n.tr("Near island", "island settings: satellites hug the island"), I18n.tr("Display edges", "island settings: satellites sit at screen edges")]
                currentIndex: root.valueIndex(root.satellitePositionValues, bar.islandSetting("islandSatellitePosition"), "island")
                enabled: bar.islandSetting("islandSatellitesEnabled")
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        bar.apply("islandSatellitePosition", root.satellitePositionValues[index] ?? "island");
                }
            }

            SettingsToggleRow {
                settingKey: "islandSatelliteBackground"
                tags: ["island", "satellite", "widgets", "background", "chrome"]
                resetStore: bar
                resetKeys: ["islandSatelliteBackground"]
                text: I18n.tr("Background", "island settings: satellite background toggle")
                checked: bar.islandSetting("islandSatelliteBackground")
                visible: bar.islandSetting("islandSatellitesEnabled")
                onToggled: checked => bar.apply("islandSatelliteBackground", checked)
            }

            SettingsToggleRow {
                settingKey: "islandSatelliteGothCorners"
                tags: ["island", "satellite", "goth", "corners", "wing", "sweep"]
                resetStore: bar
                resetKeys: ["islandSatelliteGothCorners"]
                text: I18n.tr("Goth corners", "island settings: satellite goth corners toggle")
                checked: bar.islandSetting("islandSatelliteGothCorners")
                visible: bar.islandSetting("islandSatellitesEnabled")
                enabled: bar.islandSetting("islandSatelliteBackground")
                onToggled: checked => bar.apply("islandSatelliteGothCorners", checked)
            }

            SettingsSliderRow {
                settingKey: "islandSatelliteSwoopRadius"
                tags: ["island", "satellite", "goth", "corners", "radius", "sweep", "size"]
                resetStore: bar
                resetKeys: ["islandSatelliteSwoopRadius"]
                text: I18n.tr("Goth corner radius", "island settings: satellite goth corner radius slider")
                unit: "px"
                minimum: 4
                maximum: 64
                step: 1
                value: bar.islandSetting("islandSatelliteSwoopRadius")
                visible: bar.islandSetting("islandSatellitesEnabled")
                enabled: bar.islandSetting("islandSatelliteBackground") && bar.islandSetting("islandSatelliteGothCorners")
                onSliderValueChanged: value => bar.apply("islandSatelliteSwoopRadius", value)
            }

            SettingsToggleRow {
                id: satelliteOpacityRow

                readonly property bool overridden: !bar.islandSetting("islandSatelliteFollowInterfaceStyle")

                settingKey: "islandSatelliteTransparency"
                tags: ["island", "satellite", "background", "opacity", "transparency", "blur", "override", "interface", "style"]
                resetStore: bar
                resetKeys: ["islandSatelliteFollowInterfaceStyle", "islandSatelliteTransparency"]
                resetByKeys: true
                text: I18n.tr("Override", "verb, toggle to override the global setting for this item")
                checked: overridden
                visible: bar.islandSetting("islandSatellitesEnabled")
                enabled: bar.islandSetting("islandSatelliteBackground")
                onToggled: checked => bar.apply("islandSatelliteFollowInterfaceStyle", !checked)

                body: SettingsSliderRow {
                    width: parent.width
                    text: I18n.tr("Opacity", "island settings: satellite background opacity slider")
                    resetStore: bar
                    resetKeys: ["islandSatelliteTransparency"]
                    minimum: 0
                    maximum: 100
                    step: 1
                    value: Math.round(SettingsData.islandSatelliteTransparency(bar.selectedBarConfig) * 100)
                    enabled: bar.islandSetting("islandSatelliteBackground") && satelliteOpacityRow.overridden
                    onSliderValueChanged: value => bar.apply("islandSatelliteTransparency", value / 100)
                }
            }

            SettingsSliderRow {
                settingKey: "islandSatelliteGap"
                tags: ["island", "satellite", "widgets", "gap", "spacing"]
                resetStore: bar
                resetKeys: ["islandSatelliteGap"]
                text: I18n.tr("Gap", "island settings: satellite to island gap slider")
                unit: "px"
                minimum: 4
                maximum: 48
                step: 1
                value: bar.islandSetting("islandSatelliteGap")
                visible: bar.islandSetting("islandSatellitesEnabled")
                enabled: bar.islandSetting("islandSatellitePosition") !== "edges"
                onSliderValueChanged: value => bar.apply("islandSatelliteGap", value)
            }
        }

        SettingsCard {
            iconName: "widgets"
            title: I18n.tr("Widgets")
            settingKey: "barWidgets"
            tags: ["widget", "style", "pills", "segments", "opacity", "padding", "maximize"]
            visible: bar.selectedBarConfig?.enabled ?? false

            SettingsRow {
                settingKey: "barWidgetStyle"
                tags: ["widget", "style", "segments", "pills", "flat", "connected", "group"]
                title: I18n.tr("Widget style")
                enabled: root.widgetBackgroundEnabled
                resetStore: bar
                resetKeys: ["widgetStyle"]

                body: SettingsLayoutPicker {
                    widgetStyle: true
                    choices: [
                        {
                            key: "pills",
                            label: I18n.tr("Pills", "bar widget style option")
                        },
                        {
                            key: "segments",
                            label: I18n.tr("Segments", "bar widget style option")
                        },
                        {
                            key: "flat",
                            label: I18n.tr("Flat", "adjective, bar widget style option")
                        }
                    ]
                    selectedKey: bar.selectedBarConfig?.widgetStyle ?? "pills"
                    onSelected: key => SettingsData.updateBarConfig(bar.selectedBarId, {
                            widgetStyle: key
                        })
                }
            }

            SettingsToggleRow {
                id: widgetOpacityRow

                readonly property bool overridden: bar.selectedBarConfig?.widgetFollowInterfaceStyle === false

                text: I18n.tr("Override", "verb, toggle to override the global setting for this item")
                tags: ["widget", "opacity", "transparency", "override", "foreground", "interface", "style"]
                enabled: root.widgetBackgroundEnabled
                resetStore: bar
                resetKeys: ["widgetFollowInterfaceStyle", "widgetTransparency"]
                resetByKeys: true
                checked: overridden
                onToggled: checked => SettingsData.updateBarConfig(bar.selectedBarId, {
                        widgetFollowInterfaceStyle: !checked
                    })

                body: SettingsSliderRow {
                    width: parent.width
                    text: I18n.tr("Opacity")
                    enabled: root.widgetBackgroundEnabled && widgetOpacityRow.overridden
                    resetStore: bar
                    resetKeys: ["widgetTransparency"]
                    value: Math.round(SettingsData.barWidgetTransparency(bar.selectedBarConfig) * 100)
                    minimum: 0
                    maximum: 100
                    onSliderDragFinished: finalValue => SettingsData.updateBarConfig(bar.selectedBarId, {
                            widgetTransparency: finalValue / 100
                        })
                }
            }

            SettingsSliderRow {
                text: I18n.tr("Padding")
                tags: ["widget", "padding", "spacing", "compact", "remove"]
                resetStore: bar
                resetKeys: ["widgetPadding"]
                value: bar.selectedBarConfig?.widgetPadding ?? 8
                minimum: 0
                maximum: 32
                unit: "px"
                onSliderValueChanged: newValue => SettingsData.updateBarConfig(bar.selectedBarId, {
                        widgetPadding: newValue
                    })
            }

            SettingsToggleRow {
                settingKey: "barNoBackground"
                tags: ["transparent", "background", "invisible"]
                text: I18n.tr("Background")
                resetStore: bar
                resetKeys: ["noBackground"]
                checked: !(bar.selectedBarConfig?.noBackground ?? false)
                onToggled: checked => SettingsData.updateBarConfig(bar.selectedBarId, {
                        noBackground: !checked
                    })
            }

            SettingsToggleRow {
                settingKey: "barMaximizeWidgetIcons"
                tags: ["maximize", "icons", "stretch"]
                text: I18n.tr("Maximize widget icons")
                resetStore: bar
                resetKeys: ["maximizeWidgetIcons"]
                checked: bar.selectedBarConfig?.maximizeWidgetIcons ?? false
                onToggled: checked => SettingsData.updateBarConfig(bar.selectedBarId, {
                        maximizeWidgetIcons: checked
                    })
            }

            SettingsToggleRow {
                settingKey: "barMaximizeWidgetText"
                tags: ["maximize", "text", "stretch"]
                text: I18n.tr("Maximize widget text")
                resetStore: bar
                resetKeys: ["maximizeWidgetText"]
                checked: bar.selectedBarConfig?.maximizeWidgetText ?? false
                onToggled: checked => SettingsData.updateBarConfig(bar.selectedBarId, {
                        maximizeWidgetText: checked
                    })
            }
        }

        SettingsToggleCard {
            settingKey: "barWidgetOutline"
            iconName: "highlight"
            title: I18n.tr("Widget outline")
            visible: bar.selectedBarConfig?.enabled ?? false
            enabled: root.widgetBackgroundEnabled
            resetStore: bar
            resetKeys: ["widgetOutlineEnabled"]
            checked: bar.selectedBarConfig?.widgetOutlineEnabled ?? false
            onToggled: checked => SettingsData.updateBarConfig(bar.selectedBarId, {
                    widgetOutlineEnabled: checked
                })

            SettingsButtonGroupRow {
                text: I18n.tr("Color")
                resetStore: bar
                resetKeys: ["widgetOutlineColor"]
                model: root.outlineColorLabels
                currentIndex: {
                    const index = root.outlineColors.indexOf(bar.selectedBarConfig?.widgetOutlineColor || "primary");
                    return index >= 0 ? index : 2;
                }
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    SettingsData.updateBarConfig(bar.selectedBarId, {
                        widgetOutlineColor: root.outlineColors[index]
                    });
                }
            }

            SettingsSliderRow {
                text: I18n.tr("Opacity")
                resetStore: bar
                resetKeys: ["widgetOutlineOpacity"]
                value: (bar.selectedBarConfig?.widgetOutlineOpacity ?? 1.0) * 100
                minimum: 0
                maximum: 100
                onSliderDragFinished: finalValue => SettingsData.updateBarConfig(bar.selectedBarId, {
                        widgetOutlineOpacity: finalValue / 100
                    })
            }

            SettingsSliderRow {
                text: I18n.tr("Thickness")
                resetStore: bar
                resetKeys: ["widgetOutlineThickness"]
                value: bar.selectedBarConfig?.widgetOutlineThickness ?? 1
                minimum: 1
                maximum: 10
                unit: "px"
                onSliderDragFinished: finalValue => SettingsData.updateBarConfig(bar.selectedBarId, {
                        widgetOutlineThickness: finalValue
                    })
            }
        }

        SettingsCard {
            iconName: "format_color_fill"
            title: I18n.tr("Widget colors")
            settingKey: "widgetStyling"
            tags: ["widget", "background", "color", "colorful", "text", "all", "bars"]

            WidgetTextStyleRow {}

            WidgetBackgroundRow {
                enabled: root.widgetBackgroundEnabled
            }

            WidgetBackgroundStrengthRow {
                enabled: root.widgetBackgroundEnabled
            }
        }
    }
}
