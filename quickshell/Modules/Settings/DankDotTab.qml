import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    readonly property var routingValues: ["normal", "always", "last-used"]
    readonly property var paletteValues: ["default", "bright", "dim"]

    function valueIndex(values, value, fallback) {
        const index = values.indexOf(value);
        return index >= 0 ? index : Math.max(0, values.indexOf(fallback));
    }

    QtObject {
        id: dot

        readonly property var config: SettingsData.dotBarConfig

        function setting(key) {
            return SettingsData.islandSetting(config, key);
        }

        function apply(key, value) {
            if (!config)
                return;
            SettingsData.updateBarConfig(config.id, {
                [key]: value
            });
        }

        function defaultFor(key) {
            return key in SettingsData.islandDefaults ? SettingsData.islandDefaults[key] : SettingsData.barConfigDefault(key);
        }

        function isDefault(keys) {
            if (!config)
                return true;
            return keys.every(key => config[key] === undefined || JSON.stringify(config[key]) === JSON.stringify(defaultFor(key)));
        }

        function resetToDefault(keys) {
            if (!config)
                return;
            const patch = {};
            for (const key of keys)
                patch[key] = defaultFor(key);
            SettingsData.updateBarConfig(config.id, patch);
        }
    }

    SettingsPage {
        SettingsCard {
            settingKey: "dotSize"
            tags: ["dot", "dankdot", "size", "diameter", "idle", "fade"]
            iconName: "blur_on"
            title: I18n.tr("Dot", "bar layout: free-floating dot that opens island activities")

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
                currentIndex: root.valueIndex(root.paletteValues, dot.setting("islandPalette"), "default")
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        dot.apply("islandPalette", root.paletteValues[index] ?? "default");
                }
            }

            SettingsToggleRow {
                settingKey: "dotHighContrast"
                tags: ["dot", "contrast", "accessibility", "outline"]
                resetStore: dot
                resetKeys: ["islandHighContrast"]
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

        SettingsCard {
            iconName: "touch_app"
            title: I18n.tr("Behavior", "island settings: behavior card title")
            settingKey: "dotBehavior"
            tags: ["dot", "routing", "shortcuts", "motion", "spring", "animation"]

            SettingsDropdownRow {
                settingKey: "dotSharedRouting"
                tags: ["dot", "routing", "launcher", "dash", "control center", "ipc", "last used"]
                resetStore: dot
                resetKeys: ["islandSharedRouting"]
                text: I18n.tr("Shared shortcuts")
                description: I18n.tr("Routes launcher, dash, control center and notification shortcuts")
                options: [I18n.tr("Normal routing"), I18n.tr("Always here"), I18n.tr("Last used on this screen")]
                dropdownWidth: Theme.smallBreakpoint / 2
                currentValue: options[root.valueIndex(root.routingValues, SettingsData.islandSharedRoutingMode(dot.config), "normal")]
                onValueChanged: value => SettingsData.setIslandSharedRouting(dot.config.id, root.routingValues[options.indexOf(value)] ?? "normal")
            }

            SettingsToggleRow {
                settingKey: "dotReducedMotion"
                tags: ["dot", "motion", "animation", "reduce", "accessibility", "spring"]
                resetStore: dot
                resetKeys: ["islandReducedMotion"]
                text: I18n.tr("Reduce motion")
                checked: dot.setting("islandReducedMotion")
                onToggled: checked => dot.apply("islandReducedMotion", checked)
            }

            SettingsSliderRow {
                settingKey: "dotSpringStiffness"
                tags: ["dot", "motion", "spring", "stiffness", "animation"]
                resetStore: dot
                resetKeys: ["islandSpringStiffness"]
                text: I18n.tr("Spring stiffness", "island settings: spring stiffness slider")
                unit: ""
                minimum: 100
                maximum: 1200
                step: 10
                value: Math.round(dot.setting("islandSpringStiffness"))
                enabled: !dot.setting("islandReducedMotion")
                onSliderValueChanged: value => dot.apply("islandSpringStiffness", value)
            }

            SettingsSliderRow {
                settingKey: "dotSpringDamping"
                tags: ["dot", "motion", "spring", "damping", "bounce", "animation"]
                resetStore: dot
                resetKeys: ["islandSpringDamping"]
                text: I18n.tr("Spring damping", "island settings: spring damping slider")
                unit: ""
                minimum: 10
                maximum: 100
                step: 1
                value: Math.round(dot.setting("islandSpringDamping"))
                enabled: !dot.setting("islandReducedMotion")
                onSliderValueChanged: value => dot.apply("islandSpringDamping", value)
            }

            SettingsSliderRow {
                settingKey: "dotSpringMass"
                tags: ["dot", "motion", "spring", "mass", "inertia", "animation"]
                resetStore: dot
                resetKeys: ["islandSpringMass"]
                text: I18n.tr("Spring mass", "island settings: spring mass slider")
                minimum: 25
                maximum: 300
                step: 5
                unit: ""
                decimals: 2
                value: Math.round(dot.setting("islandSpringMass") * 100)
                enabled: !dot.setting("islandReducedMotion")
                onSliderValueChanged: value => dot.apply("islandSpringMass", value / 100)
            }
        }

        SettingsCard {
            iconName: "notifications"
            title: I18n.tr("Notifications", "island settings: notifications card title")
            settingKey: "dotNotifications"
            tags: ["dot", "notifications", "popup", "badge", "expand"]

            SettingsToggleRow {
                settingKey: "dotNotificationPopups"
                tags: ["dot", "notifications", "popup", "standard", "stack", "arrival"]
                resetStore: dot
                resetKeys: ["islandNotificationPopups"]
                text: I18n.tr("Use standard popups", "island settings: show arriving notifications as stacked popups instead of in the island")
                checked: dot.setting("islandNotificationPopups")
                onToggled: checked => dot.apply("islandNotificationPopups", checked)
            }

            SettingsToggleRow {
                settingKey: "dotNotificationExpand"
                tags: ["dot", "notifications", "expand", "arrival", "size"]
                resetStore: dot
                resetKeys: ["islandNotificationExpand"]
                text: I18n.tr("Expand by default", "island settings: expanded notification toggle")
                checked: dot.setting("islandNotificationExpand")
                onToggled: checked => dot.apply("islandNotificationExpand", checked)
            }

            SettingsToggleRow {
                settingKey: "dotNotificationBadgeClearOnOpen"
                tags: ["dot", "notifications", "badge", "unread", "clear", "dismiss", "open"]
                resetStore: dot
                resetKeys: ["islandNotificationBadgeClearOnOpen"]
                text: I18n.tr("Clear badge on open", "island settings: clear the notification badge when the center opens")
                checked: dot.setting("islandNotificationBadgeClearOnOpen")
                onToggled: checked => dot.apply("islandNotificationBadgeClearOnOpen", checked)
            }
        }
    }
}
