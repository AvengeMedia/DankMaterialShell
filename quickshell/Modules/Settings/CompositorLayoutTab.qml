import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: layoutColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: layoutColumn

            topPadding: Theme.spacingXL
            bottomPadding: Theme.spacingXL
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                width: parent.width
                tags: ["niri", "layout", "gaps", "radius", "window", "border"]
                title: I18n.tr("Niri Layout Overrides")
                settingKey: "niriLayout"
                iconName: "layers"
                visible: CompositorService.isNiri

                SettingsToggleRow {
                    tags: ["niri", "gaps", "override"]
                    settingKey: "niriLayoutGapsOverrideEnabled"
                    text: I18n.tr("Override Gaps")
                    description: I18n.tr("Use custom gaps instead of bar spacing")
                    checked: SettingsData.niriLayoutGapsOverride >= 0
                    onToggled: checked => {
                        if (checked) {
                            const currentGaps = Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4));
                            SettingsData.set("niriLayoutGapsOverride", currentGaps);
                            return;
                        }
                        SettingsData.set("niriLayoutGapsOverride", -1);
                    }
                }

                SettingsSliderRow {
                    tags: ["niri", "gaps", "override"]
                    settingKey: "niriLayoutGapsOverride"
                    text: I18n.tr("Window Gaps")
                    description: I18n.tr("Space between windows")
                    visible: SettingsData.niriLayoutGapsOverride >= 0
                    value: Math.max(0, SettingsData.niriLayoutGapsOverride)
                    minimum: 0
                    maximum: 50
                    unit: "px"
                    defaultValue: Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4))
                    onSliderValueChanged: newValue => SettingsData.set("niriLayoutGapsOverride", newValue)
                }

                SettingsToggleRow {
                    tags: ["niri", "radius", "override"]
                    settingKey: "niriLayoutRadiusOverrideEnabled"
                    text: I18n.tr("Override Corner Radius")
                    description: I18n.tr("Use custom window radius instead of theme radius")
                    checked: SettingsData.niriLayoutRadiusOverride >= 0
                    onToggled: checked => {
                        if (checked) {
                            SettingsData.set("niriLayoutRadiusOverride", SettingsData.cornerRadius);
                            return;
                        }
                        SettingsData.set("niriLayoutRadiusOverride", -1);
                    }
                }

                SettingsSliderRow {
                    tags: ["niri", "radius", "override"]
                    settingKey: "niriLayoutRadiusOverride"
                    text: I18n.tr("Window Corner Radius")
                    description: I18n.tr("Rounded corners for windows")
                    visible: SettingsData.niriLayoutRadiusOverride >= 0
                    value: Math.max(0, SettingsData.niriLayoutRadiusOverride)
                    minimum: 0
                    maximum: 100
                    unit: "px"
                    defaultValue: SettingsData.cornerRadius
                    onSliderValueChanged: newValue => SettingsData.set("niriLayoutRadiusOverride", newValue)
                }

                SettingsToggleRow {
                    tags: ["niri", "border", "override"]
                    settingKey: "niriLayoutBorderSizeEnabled"
                    text: I18n.tr("Override Border Size")
                    description: I18n.tr("Use custom border/focus-ring width")
                    checked: SettingsData.niriLayoutBorderSize >= 0
                    onToggled: checked => {
                        if (checked) {
                            SettingsData.set("niriLayoutBorderSize", 2);
                            return;
                        }
                        SettingsData.set("niriLayoutBorderSize", -1);
                    }
                }

                SettingsSliderRow {
                    tags: ["niri", "border", "override"]
                    settingKey: "niriLayoutBorderSize"
                    text: I18n.tr("Border Size")
                    description: I18n.tr("Width of window border and focus ring")
                    visible: SettingsData.niriLayoutBorderSize >= 0
                    value: Math.max(0, SettingsData.niriLayoutBorderSize)
                    minimum: 0
                    maximum: 10
                    unit: "px"
                    defaultValue: 2
                    onSliderValueChanged: newValue => SettingsData.set("niriLayoutBorderSize", newValue)
                }
            }

            SettingsCard {
                width: parent.width
                tags: ["hyprland", "layout", "gaps", "radius", "window", "border", "rounding"]
                title: I18n.tr("Hyprland Layout Overrides")
                settingKey: "hyprlandLayout"
                iconName: "crop_square"
                visible: CompositorService.isHyprland

                SettingsToggleRow {
                    tags: ["hyprland", "gaps", "override"]
                    settingKey: "hyprlandLayoutGapsOverrideEnabled"
                    text: I18n.tr("Override Gaps")
                    description: I18n.tr("Use custom gaps instead of bar spacing")
                    checked: SettingsData.hyprlandLayoutGapsOverride >= 0
                    onToggled: checked => {
                        if (checked) {
                            const currentGaps = Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4));
                            SettingsData.set("hyprlandLayoutGapsOverride", currentGaps);
                            return;
                        }
                        SettingsData.set("hyprlandLayoutGapsOverride", -1);
                    }
                }

                SettingsSliderRow {
                    tags: ["hyprland", "gaps", "override"]
                    settingKey: "hyprlandLayoutGapsOverride"
                    text: I18n.tr("Window Gaps")
                    description: I18n.tr("Space between windows") + " (gaps_in/gaps_out)"
                    visible: SettingsData.hyprlandLayoutGapsOverride >= 0
                    value: Math.max(0, SettingsData.hyprlandLayoutGapsOverride)
                    minimum: 0
                    maximum: 50
                    unit: "px"
                    defaultValue: Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4))
                    onSliderValueChanged: newValue => SettingsData.set("hyprlandLayoutGapsOverride", newValue)
                }

                SettingsToggleRow {
                    tags: ["hyprland", "radius", "override", "rounding"]
                    settingKey: "hyprlandLayoutRadiusOverrideEnabled"
                    text: I18n.tr("Override Corner Radius")
                    description: I18n.tr("Use custom window radius instead of theme radius")
                    checked: SettingsData.hyprlandLayoutRadiusOverride >= 0
                    onToggled: checked => {
                        if (checked) {
                            SettingsData.set("hyprlandLayoutRadiusOverride", SettingsData.cornerRadius);
                            return;
                        }
                        SettingsData.set("hyprlandLayoutRadiusOverride", -1);
                    }
                }

                SettingsSliderRow {
                    tags: ["hyprland", "radius", "override", "rounding"]
                    settingKey: "hyprlandLayoutRadiusOverride"
                    text: I18n.tr("Window Corner Radius")
                    description: I18n.tr("Rounded corners for windows") + " (decoration.rounding)"
                    visible: SettingsData.hyprlandLayoutRadiusOverride >= 0
                    value: Math.max(0, SettingsData.hyprlandLayoutRadiusOverride)
                    minimum: 0
                    maximum: 100
                    unit: "px"
                    defaultValue: SettingsData.cornerRadius
                    onSliderValueChanged: newValue => SettingsData.set("hyprlandLayoutRadiusOverride", newValue)
                }

                SettingsToggleRow {
                    tags: ["hyprland", "border", "override"]
                    settingKey: "hyprlandLayoutBorderSizeEnabled"
                    text: I18n.tr("Override Border Size")
                    description: I18n.tr("Use custom border size")
                    checked: SettingsData.hyprlandLayoutBorderSize >= 0
                    onToggled: checked => {
                        if (checked) {
                            SettingsData.set("hyprlandLayoutBorderSize", 2);
                            return;
                        }
                        SettingsData.set("hyprlandLayoutBorderSize", -1);
                    }
                }

                SettingsSliderRow {
                    tags: ["hyprland", "border", "override"]
                    settingKey: "hyprlandLayoutBorderSize"
                    text: I18n.tr("Border Size")
                    description: I18n.tr("Width of window border") + " (general.border_size)"
                    visible: SettingsData.hyprlandLayoutBorderSize >= 0
                    value: Math.max(0, SettingsData.hyprlandLayoutBorderSize)
                    minimum: 0
                    maximum: 10
                    unit: "px"
                    defaultValue: 2
                    onSliderValueChanged: newValue => SettingsData.set("hyprlandLayoutBorderSize", newValue)
                }

                SettingsToggleRow {
                    tags: ["hyprland", "resize", "border", "mouse", "drag"]
                    settingKey: "hyprlandResizeOnBorder"
                    text: I18n.tr("Resize on Border")
                    description: I18n.tr("Resize windows by dragging their edges with the mouse")
                    checked: SettingsData.hyprlandResizeOnBorder
                    onToggled: checked => SettingsData.set("hyprlandResizeOnBorder", checked)
                }
            }

            SettingsCard {
                width: parent.width
                tags: ["mangowc", "mango", "dwl", "layout", "gaps", "radius", "window", "border"]
                title: I18n.tr("MangoWC Layout Overrides")
                settingKey: "mangoLayout"
                iconName: "crop_square"
                visible: CompositorService.isMango

                SettingsToggleRow {
                    tags: ["mangowc", "mango", "gaps", "override"]
                    settingKey: "mangoLayoutGapsOverrideEnabled"
                    text: I18n.tr("Override Gaps")
                    description: I18n.tr("Use custom gaps instead of bar spacing")
                    checked: SettingsData.mangoLayoutGapsOverride >= 0
                    onToggled: checked => {
                        if (checked) {
                            const currentGaps = Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4));
                            SettingsData.set("mangoLayoutGapsOverride", currentGaps);
                            return;
                        }
                        SettingsData.set("mangoLayoutGapsOverride", -1);
                    }
                }

                SettingsSliderRow {
                    tags: ["mangowc", "mango", "gaps", "override"]
                    settingKey: "mangoLayoutGapsOverride"
                    text: I18n.tr("Window Gaps")
                    description: I18n.tr("Space between windows") + " (gappih/gappiv/gappoh/gappov)"
                    visible: SettingsData.mangoLayoutGapsOverride >= 0
                    value: Math.max(0, SettingsData.mangoLayoutGapsOverride)
                    minimum: 0
                    maximum: 50
                    unit: "px"
                    defaultValue: Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4))
                    onSliderValueChanged: newValue => SettingsData.set("mangoLayoutGapsOverride", newValue)
                }

                SettingsToggleRow {
                    tags: ["mangowc", "mango", "radius", "override"]
                    settingKey: "mangoLayoutRadiusOverrideEnabled"
                    text: I18n.tr("Override Corner Radius")
                    description: I18n.tr("Use custom window radius instead of theme radius")
                    checked: SettingsData.mangoLayoutRadiusOverride >= 0
                    onToggled: checked => {
                        if (checked) {
                            SettingsData.set("mangoLayoutRadiusOverride", SettingsData.cornerRadius);
                            return;
                        }
                        SettingsData.set("mangoLayoutRadiusOverride", -1);
                    }
                }

                SettingsSliderRow {
                    tags: ["mangowc", "mango", "radius", "override"]
                    settingKey: "mangoLayoutRadiusOverride"
                    text: I18n.tr("Window Corner Radius")
                    description: I18n.tr("Rounded corners for windows") + " (border_radius)"
                    visible: SettingsData.mangoLayoutRadiusOverride >= 0
                    value: Math.max(0, SettingsData.mangoLayoutRadiusOverride)
                    minimum: 0
                    maximum: 100
                    unit: "px"
                    defaultValue: SettingsData.cornerRadius
                    onSliderValueChanged: newValue => SettingsData.set("mangoLayoutRadiusOverride", newValue)
                }

                SettingsToggleRow {
                    tags: ["mangowc", "mango", "border", "override"]
                    settingKey: "mangoLayoutBorderSizeEnabled"
                    text: I18n.tr("Override Border Size")
                    description: I18n.tr("Use custom border size")
                    checked: SettingsData.mangoLayoutBorderSize >= 0
                    onToggled: checked => {
                        if (checked) {
                            SettingsData.set("mangoLayoutBorderSize", 2);
                            return;
                        }
                        SettingsData.set("mangoLayoutBorderSize", -1);
                    }
                }

                SettingsSliderRow {
                    tags: ["mangowc", "mango", "border", "override"]
                    settingKey: "mangoLayoutBorderSize"
                    text: I18n.tr("Border Size")
                    description: I18n.tr("Width of window border") + " (borderpx)"
                    visible: SettingsData.mangoLayoutBorderSize >= 0
                    value: Math.max(0, SettingsData.mangoLayoutBorderSize)
                    minimum: 0
                    maximum: 10
                    unit: "px"
                    defaultValue: 2
                    onSliderValueChanged: newValue => SettingsData.set("mangoLayoutBorderSize", newValue)
                }
            }
        }
    }
}
