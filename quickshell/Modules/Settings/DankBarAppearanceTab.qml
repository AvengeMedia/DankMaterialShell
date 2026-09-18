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
    readonly property bool trayTinted: ["primary", "secondary"].includes(SettingsData.systemTrayIconTintMode || "none")
    readonly property var outlineColors: ["surfaceText", "secondary", "primary"]
    readonly property var outlineColorLabels: [I18n.tr("Surface"), I18n.tr("Secondary"), I18n.tr("Primary")]
    readonly property var paletteValues: ["default", "bright", "dim"]
    readonly property var batteryStyleValues: ["solid", "outline", "ring"]

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
            iconName: "rounded_corner"
            title: I18n.tr("Bar")
            settingKey: "barCorners"
            tags: ["background", "opacity", "corners", "rounded", "goth", "shadow"]
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

            SettingsSliderRow {
                settingKey: "islandTransparency"
                tags: ["island", "appearance", "surface", "opacity", "transparency", "blur"]
                visible: bar.selectedBarIsIsland
                resetStore: bar
                resetKeys: ["islandTransparency"]
                text: I18n.tr("Opacity", "island settings: island surface opacity slider")
                minimum: 0
                maximum: 100
                step: 1
                value: Math.round(bar.islandSetting("islandTransparency") * 100)
                onSliderValueChanged: value => bar.apply("islandTransparency", value / 100)
            }

            SettingsSliderRow {
                settingKey: "islandCornerRadius"
                tags: ["island", "appearance", "corner", "radius", "rounding", "pill", "expanded"]
                visible: bar.selectedBarIsIsland
                resetStore: bar
                resetKeys: ["islandCornerRadius"]
                text: I18n.tr("Corner radius", "island settings: island corner radius slider")
                unit: "px"
                minimum: 0
                maximum: 64
                step: 1
                value: bar.islandSetting("islandCornerRadius")
                onSliderValueChanged: value => bar.apply("islandCornerRadius", value)
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

            SettingsButtonGroupRow {
                settingKey: "islandBatteryStyle"
                tags: ["island", "battery", "gauge", "solid", "outline", "ring", "circle", "appearance"]
                resetStore: bar
                resetKeys: ["islandBatteryStyle"]
                text: I18n.tr("Battery style", "island settings: battery meter style row")
                visible: bar.selectedBarIsIsland && SettingsData.islandHomeGroupEnabled(bar.selectedBarConfig, "status") && BatteryService.batteryAvailable && SettingsData.islandHomeStatusContent(bar.selectedBarConfig) === "battery"
                model: [I18n.tr("Solid", "island settings: filled battery meter style"), I18n.tr("Outline", "island settings: outlined battery meter style"), I18n.tr("Circle", "island settings: circular battery meter style")]
                currentIndex: root.valueIndex(root.batteryStyleValues, bar.islandSetting("islandBatteryStyle"), "solid")
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        bar.apply("islandBatteryStyle", root.batteryStyleValues[index] ?? "solid");
                }
            }

            SettingsToggleRow {
                settingKey: "barNoBackground"
                tags: ["transparent", "background", "invisible"]
                text: I18n.tr("Background")
                visible: !bar.selectedBarFrameStyled && !bar.selectedBarIsIsland
                resetStore: bar
                resetKeys: ["noBackground"]
                checked: !(bar.selectedBarConfig?.noBackground ?? false)
                onToggled: checked => SettingsData.updateBarConfig(bar.selectedBarId, {
                        noBackground: !checked
                    })
            }

            SettingsControlledBy {
                visible: !bar.selectedBarFrameStyled && !bar.islandOwnsSelectedBarTop
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

        SettingsControlledBy {
            visible: (bar.selectedBarConfig?.enabled ?? false) && bar.selectedBarFrameSanitized && !bar.islandOwnsSelectedBarTop
            parentModal: root.parentModal
            section: "frameBorder"
            settingLabel: I18n.tr("Bar surface and spacing")
            reason: SettingsData.connectedFrameModeActive ? I18n.tr("Managed by Frame in Connected Mode") : I18n.tr("Managed by Frame")
        }

        SettingsCard {
            iconName: "space_bar"
            title: I18n.tr("Size & spacing")
            settingKey: "barSpacing"
            tags: ["size", "scale", "font", "icon", "spacing", "padding", "inset", "length"]
            visible: bar.selectedBarConfig?.enabled ?? false

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

            SettingsSliderRow {
                settingKey: "barLengthPadding"
                visible: !bar.selectedBarFrameStyled && !bar.islandOwnsSelectedBarTop
                text: I18n.tr("Length padding")
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
            iconName: "widgets"
            title: I18n.tr("Widgets")
            settingKey: "barWidgets"
            tags: ["widget", "style", "pills", "segments", "opacity", "padding", "maximize"]
            visible: bar.selectedBarConfig?.enabled ?? false

            SettingsRow {
                settingKey: "barWidgetStyle"
                tags: ["widget", "style", "segments", "pills", "flat", "connected", "group"]
                title: I18n.tr("Widget style")
                visible: !bar.selectedBarFrameStyled
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

            SettingsSliderRow {
                text: I18n.tr("Opacity")
                tags: ["widget", "opacity", "transparency"]
                enabled: root.widgetBackgroundEnabled
                resetStore: bar
                resetKeys: ["widgetTransparency"]
                value: (bar.selectedBarConfig?.widgetTransparency ?? 1.0) * 100
                minimum: 0
                maximum: 100
                onSliderDragFinished: finalValue => SettingsData.updateBarConfig(bar.selectedBarId, {
                        widgetTransparency: finalValue / 100
                    })
            }

            SettingsSliderRow {
                visible: !bar.selectedBarFrameStyled
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

        SettingsCard {
            iconName: "palette"
            title: I18n.tr("Icons")
            settingKey: "trayIconTint"
            tags: ["icon", "tray", "tint", "battery", "color"]
            visible: bar.selectedBarConfig?.enabled ?? false

            SettingsButtonGroupRow {
                settingKey: "batteryColorMode"
                tags: ["battery", "color", "level", "theme", "icon", "meter", "indicator", "accent", "green", "red"]
                text: I18n.tr("Battery")
                visible: BatteryService.batteryAvailable
                resetStore: bar
                resetKeys: ["batteryColorMode"]
                model: [I18n.tr("Theme", "battery settings: theme accent indicator colors"), I18n.tr("Level", "battery settings: charge level indicator colors")]
                currentIndex: (bar.selectedBarConfig?.batteryColorMode ?? "theme") === "level" ? 1 : 0
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    SettingsData.updateBarConfig(bar.selectedBarId, {
                        batteryColorMode: index === 1 ? "level" : "theme"
                    });
                }
            }

            SettingsButtonGroupRow {
                readonly property var modes: ["none", "monochrome", "primary", "secondary"]

                tags: ["tray", "icon", "tint", "monochrome", "system tray"]
                text: I18n.tr("Tray icon tint")
                resetKeys: ["systemTrayIconTintMode"]
                model: [I18n.tr("None"), I18n.tr("Monochrome"), I18n.tr("Primary"), I18n.tr("Secondary")]
                currentIndex: Math.max(0, modes.indexOf(SettingsData.systemTrayIconTintMode || "none"))
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    SettingsData.set("systemTrayIconTintMode", modes[index]);
                }
            }

            SettingsSliderRow {
                text: I18n.tr("Tint saturation")
                tags: ["tray", "tint", "saturation"]
                visible: root.trayTinted
                resetKeys: ["systemTrayIconTintSaturation"]
                value: SettingsData.systemTrayIconTintSaturation ?? 50
                minimum: 0
                maximum: 100
                onSliderDragFinished: finalValue => SettingsData.set("systemTrayIconTintSaturation", finalValue)
            }

            SettingsSliderRow {
                text: I18n.tr("Tint strength")
                tags: ["tray", "tint", "strength"]
                visible: root.trayTinted
                resetKeys: ["systemTrayIconTintStrength"]
                value: SettingsData.systemTrayIconTintStrength ?? 135
                minimum: 0
                maximum: 200
                onSliderDragFinished: finalValue => SettingsData.set("systemTrayIconTintStrength", finalValue)
            }
        }

        SettingsCard {
            title: I18n.tr("Advanced")
            settingKey: "barAppearanceAdvanced"
            tags: ["bar", "advanced", "exclusive", "zone", "popup", "gaps"]
            collapsible: true
            expanded: false
            visible: (bar.selectedBarConfig?.enabled ?? false) && !bar.selectedBarFrameStyled

            SettingsSliderRow {
                settingKey: "barExclusiveZone"
                tags: ["exclusive", "zone", "reserved", "offset"]
                visible: !bar.islandOwnsSelectedBarTop
                text: I18n.tr("Exclusive zone offset")
                resetStore: bar
                resetKeys: ["bottomGap"]
                value: bar.selectedBarConfig?.bottomGap ?? 0
                minimum: -50
                maximum: 50
                unit: "px"
                onSliderDragFinished: finalValue => SettingsData.updateBarConfig(bar.selectedBarId, {
                        bottomGap: finalValue
                    })
            }

            SettingsToggleRow {
                text: I18n.tr("Auto popup gaps")
                tags: ["popup", "gaps", "auto"]
                resetStore: bar
                resetKeys: ["popupGapsAuto"]
                checked: bar.selectedBarConfig?.popupGapsAuto ?? true
                onToggled: checked => SettingsData.updateBarConfig(bar.selectedBarId, {
                        popupGapsAuto: checked
                    })
            }

            SettingsSliderRow {
                visible: !(bar.selectedBarConfig?.popupGapsAuto ?? true)
                text: I18n.tr("Gap size")
                tags: ["popup", "gaps", "size"]
                resetStore: bar
                resetKeys: ["popupGapsManual"]
                unit: "px"
                value: bar.selectedBarConfig?.popupGapsManual ?? 4
                minimum: 0
                maximum: 50
                onSliderDragFinished: finalValue => SettingsData.updateBarConfig(bar.selectedBarId, {
                        popupGapsManual: finalValue
                    })
            }
        }
    }
}
