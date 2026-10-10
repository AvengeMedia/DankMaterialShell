import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Settings.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    readonly property var paletteValues: ["default", "bright", "dim"]

    readonly property IslandSettingsStore dot: IslandSettingsStore {
        barId: SettingsData.dotBarConfig?.id ?? ""
    }

    SettingsPage {
        SettingsCard {
            settingKey: "dotSize"
            tags: ["dot", "dankdot", "size", "diameter", "idle", "fade"]
            iconName: "blur_on"
            title: I18n.tr("General")

            SettingsSliderRow {
                settingKey: "islandFreeSize"
                tags: ["dot", "size", "diameter"]
                resetStore: dot
                resetKeys: ["islandFreeSize"]
                text: I18n.tr("Size")
                unit: "px"
                minimum: 24
                maximum: 160
                step: 1
                value: dot.setting("islandFreeSize")
                onSliderValueChanged: value => dot.apply("islandFreeSize", value)
            }

            SettingsSliderRow {
                settingKey: "islandFreeEdgeMargin"
                tags: ["dot", "edge", "margin", "gap"]
                resetStore: dot
                resetKeys: ["islandFreeEdgeMargin"]
                text: I18n.tr("Edge margin", "island settings: gap kept from the display edge")
                unit: "px"
                minimum: 0
                maximum: 64
                step: 1
                value: dot.setting("islandFreeEdgeMargin")
                onSliderValueChanged: value => dot.apply("islandFreeEdgeMargin", value)
            }

            SettingsSliderRow {
                settingKey: "islandFreeIdleDelay"
                tags: ["dot", "idle", "delay", "fade", "timeout"]
                resetStore: dot
                resetKeys: ["islandFreeIdleDelay"]
                text: I18n.tr("Idle delay", "island settings: time before the dot fades, 0 disables idling")
                unit: "ms"
                minimum: 0
                maximum: 30000
                step: 500
                value: dot.setting("islandFreeIdleDelay")
                onSliderValueChanged: value => dot.apply("islandFreeIdleDelay", value)
            }

            SettingsSliderRow {
                settingKey: "islandFreeIdleScale"
                tags: ["dot", "idle", "shrink", "scale"]
                resetStore: dot
                resetKeys: ["islandFreeIdleScale"]
                text: I18n.tr("Idle size", "island settings: how far the dot shrinks while idle")
                unit: "%"
                minimum: 20
                maximum: 100
                step: 1
                value: Math.round(dot.setting("islandFreeIdleScale") * 100)
                enabled: dot.setting("islandFreeIdleDelay") > 0
                onSliderValueChanged: value => dot.apply("islandFreeIdleScale", value / 100)
            }

            SettingsSliderRow {
                settingKey: "islandFreeIdleOpacity"
                tags: ["dot", "idle", "opacity", "fade"]
                resetStore: dot
                resetKeys: ["islandFreeIdleOpacity"]
                text: I18n.tr("Idle opacity", "island settings: dot opacity while idle")
                unit: "%"
                minimum: 5
                maximum: 100
                step: 1
                value: Math.round(dot.setting("islandFreeIdleOpacity") * 100)
                enabled: dot.setting("islandFreeIdleDelay") > 0
                onSliderValueChanged: value => dot.apply("islandFreeIdleOpacity", value / 100)
            }
        }

        SettingsCard {
            iconName: "palette"
            title: I18n.tr("Surface")
            settingKey: "dotSurface"
            tags: ["dot", "background", "color", "opacity", "palette", "contrast"]

            SurfaceColorRow {
                settingKey: "dotSurfaceColor"
                tags: ["dot", "background", "color", "surface"]
                resetStore: dot
                resetKeys: ["surfaceColor", "surfaceCustomColor"]
                text: I18n.tr("Background")
                defaultColor: Theme.hostSurface
                currentMode: dot.config?.surfaceColor ?? "default"
                customColor: dot.config?.surfaceCustomColor ?? SettingsData.barConfigDefault("surfaceCustomColor")
                pickerTitle: I18n.tr("Background")
                onModeSelected: mode => dot.apply("surfaceColor", mode)
                onCustomColorSelected: selectedColor => dot.apply("surfaceCustomColor", selectedColor.toString())
            }

            SettingsSliderRow {
                settingKey: "dotOpacity"
                tags: ["dot", "opacity", "transparency", "background"]
                resetStore: dot
                resetKeys: ["transparency"]
                text: I18n.tr("Opacity")
                minimum: 0
                maximum: 100
                step: 1
                value: Math.round(SettingsData.barTransparency(dot.config) * 100)
                onSliderDragFinished: finalValue => SettingsData.updateBarConfig(dot.config.id, {
                        followInterfaceStyle: false,
                        transparency: finalValue / 100
                    })
            }

            SettingsButtonGroupRow {
                settingKey: "dotPalette"
                tags: ["dot", "palette", "surface", "bright", "dim"]
                resetStore: dot
                resetKeys: ["islandPalette"]
                text: I18n.tr("Palette", "island settings: surface tone choice")
                model: [I18n.tr("Default", "island settings: default surface tone"), I18n.tr("Bright", "island settings: bright surface tone"), I18n.tr("Dim", "island settings: dim surface tone")]
                values: root.paletteValues
                value: dot.setting("islandPalette")
                fallbackValue: "default"
                onValueSelected: value => dot.apply("islandPalette", value)
            }

            SettingsToggleRow {
                settingKey: "dotHighContrast"
                tags: ["dot", "contrast", "accessibility", "outline"]
                text: I18n.tr("High contrast", "island settings: high contrast toggle")
                checked: dot.setting("islandHighContrast")
                onToggled: checked => dot.apply("islandHighContrast", checked)
            }
        }

        SettingsCard {
            iconName: "display_settings"
            title: I18n.tr("Displays")
            settingKey: "dotDisplays"
            tags: ["dot", "display", "monitor", "screen"]

            SettingsDisplayPicker {
                displayPreferences: dot.config?.screenPreferences || ["all"]
                emptyMeansAll: false
                allowEmpty: true
                showLastDisplay: true
                showOnLastDisplay: dot.config?.showOnLastDisplay ?? true
                onPreferencesChanged: prefs => dot.apply("screenPreferences", prefs)
                onLastDisplayToggled: checked => dot.apply("showOnLastDisplay", checked)
            }
        }

        IslandBehaviorCard {
            store: dot
            keyPrefix: "dot"
            docked: false
            isDot: true
        }

        IslandNotificationsCard {
            store: dot
            keyPrefix: "dot"
            badgeGated: false
        }

        IslandMotionCard {
            store: dot
            keyPrefix: "dot"
        }
    }
}
