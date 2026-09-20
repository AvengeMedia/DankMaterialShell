import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Column {
    id: root

    property var parentModal: null
    readonly property bool followsSurfaces: SettingsData.floatingWindowSyncGlobal ?? true
    readonly property bool borderEnabled: SettingsData.blurBorderEnabled ?? true
    readonly property string windowRadiusKey: CompositorService.supportsLayoutConfig ? CompositorService.configKey + "LayoutRadiusOverride" : ""

    width: parent?.width ?? 0
    spacing: Theme.spacingL

    ConfigInclude {
        id: windowRulesInclude
        includeKind: "windowrules"
        procTag: "windowrules-include-theme"
        onFixed: {
            if (CompositorService.isMango)
                MangoService.reloadConfig();
            CompositorService.applyDmsWindowFloatingRule();
        }
    }

    readonly property var opacityTargets: {
        SettingsData.barConfigs;
        SettingsData.dockConfigs;
        const bars = SettingsData.barConfigs.map(config => ({
                    kind: "bar",
                    id: config.id,
                    name: config.name || config.id,
                    enabled: config.enabled !== false,
                    override: config.followInterfaceStyle === false,
                    transparency: config.transparency ?? 1
                }));
        const docks = SettingsData.dockConfigs.map(config => ({
                    kind: "dock",
                    id: config.id,
                    name: config.name,
                    enabled: config.enabled !== false,
                    override: config.followInterfaceStyle === false,
                    transparency: config.transparency ?? 1
                }));
        return bars.concat(docks);
    }

    function setOpacityOverride(target, patch) {
        if (target.kind === "bar") {
            SettingsData.updateBarConfig(target.id, patch);
            return;
        }
        SettingsData.updateDockConfig(target.id, patch);
    }

    function openSurfaceBorderColorPicker() {
        PopoutService.colorPickerModal.selectedColor = SettingsData.blurBorderCustomColor ?? "#ffffff";
        PopoutService.colorPickerModal.pickerTitle = I18n.tr("Surface Border Color");
        PopoutService.colorPickerModal.onColorSelectedCallback = function (color) {
            SettingsData.set("blurBorderCustomColor", color.toString());
        };
        PopoutService.colorPickerModal.open();
    }

    SettingsCard {
        tab: "theme"
        tags: ["surface", "popup", "transparency", "opacity", "modal", "corner", "radius", "blur", "background", "glass", "frosted", "shadow", "elevation", "foreground", "layers"]
        title: I18n.tr("Surfaces", "plural noun, settings title, shell surfaces like popouts and modals")
        settingKey: "surfaceStyling"

        SettingsSliderRow {
            tab: "theme"
            tags: ["surface", "popup", "transparency", "opacity", "modal"]
            settingKey: "popupTransparency"
            text: I18n.tr("Opacity")
            value: Math.round(SettingsData.popupTransparency * 100)
            minimum: 0
            maximum: 100
            onSliderValueChanged: newValue => SettingsData.set("popupTransparency", newValue / 100)
        }

        SettingsToggleRow {
            tab: "theme"
            tags: ["foreground", "layers", "contrast", "surface", "blur", "glass", "frosted"]
            settingKey: "blurForegroundLayers"
            text: I18n.tr("Foreground layers")
            checked: SettingsData.blurForegroundLayers ?? true
            onToggled: checked => SettingsData.set("blurForegroundLayers", checked)
        }

        SettingsSliderRow {
            tab: "theme"
            tags: ["foreground", "layers", "opacity", "transparency", "contrast", "cards"]
            settingKey: "foregroundLayerTransparency"
            text: I18n.tr("Foreground opacity")
            visible: SettingsData.blurForegroundLayers ?? true
            value: Math.round((SettingsData.foregroundLayerTransparency ?? 1.0) * 100)
            minimum: 0
            maximum: 100
            onSliderValueChanged: newValue => SettingsData.set("foregroundLayerTransparency", newValue / 100)
        }

        SettingsSliderRow {
            tab: "theme"
            tags: ["foreground", "layers", "outline", "border", "cards", "pills", "widgets", "notifications", "control center"]
            settingKey: "blurLayerOutlineOpacity"
            text: I18n.tr("Layer outline opacity")
            value: Math.round((SettingsData.blurLayerOutlineOpacity ?? 0.12) * 100)
            minimum: 0
            maximum: 40
            onSliderValueChanged: newValue => SettingsData.set("blurLayerOutlineOpacity", newValue / 100)
        }

        SettingsToggleRow {
            tab: "theme"
            tags: ["blur", "background", "transparency", "glass", "frosted"]
            settingKey: "blurEnabled"
            text: I18n.tr("Background blur")
            description: BlurService.available ? "" : I18n.tr("Your compositor does not support background blur (ext-background-effect-v1)")
            checked: SettingsData.blurEnabled ?? false
            enabled: BlurService.available
            onToggled: checked => SettingsData.set("blurEnabled", checked)
        }

        SettingsNavRow {
            tab: "theme"
            tags: ["blur", "xray", "compositor", "layout"]
            settingKey: "blurXrayLink"
            visible: CompositorService.isNiri || CompositorService.isHyprland
            title: I18n.tr("Xray options are in Compositor → Layout")
            onClicked: root.parentModal?.navigateTo("compositor_layout")
        }

        SettingsButtonGroupRow {
            tab: "theme"
            tags: ["corner", "radius", "rounded", "square", "fixed", "material", "shape"]
            settingKey: "radiusMode"
            text: I18n.tr("Corner style")
            model: [I18n.tr("Material scale", "corner style: Material shape scale with a strength slider"), I18n.tr("Fixed", "corner style: one radius for every corner")]
            currentIndex: SettingsData.radiusMode === "fixed" ? 1 : 0
            onSelectionChanged: (index, selected) => {
                if (selected)
                    SettingsData.set("radiusMode", index === 1 ? "fixed" : "scale");
            }
        }

        SettingsSliderRow {
            tab: "theme"
            tags: ["corner", "radius", "rounded", "square", "strength"]
            settingKey: "radiusStrength"
            visible: SettingsData.radiusMode !== "fixed"
            text: I18n.tr("Radius strength", "global component corner rounding")
            description: I18n.tr("50 uses Material shapes. Lower values reduce rounding; higher values increase it.", "radius strength slider description")
            minimumLabel: I18n.tr("Square")
            value: SettingsData.radiusStrength
            minimum: 0
            maximum: 100
            unit: ""
            onSliderValueChanged: newValue => SettingsData.set("radiusStrength", newValue)
        }

        SettingsSliderRow {
            tab: "theme"
            tags: ["corner", "radius", "rounded", "square", "fixed"]
            settingKey: "fixedRadius"
            visible: SettingsData.radiusMode === "fixed"
            text: I18n.tr("Corner radius")
            minimumLabel: I18n.tr("Square")
            value: SettingsData.fixedRadius
            minimum: 0
            maximum: 32
            unit: "px"
            onSliderValueChanged: newValue => SettingsData.set("fixedRadius", newValue)
        }

        SettingsSliderRow {
            tab: "theme"
            tags: ["window", "corner", "radius", "rounded", "popout", "menu", "modal", "compositor", "niri", "hyprland", "mango"]
            settingKey: "windowRadius"
            text: I18n.tr("Window radius")
            visible: root.windowRadiusKey !== ""
            resetKeys: root.windowRadiusKey !== "" ? [root.windowRadiusKey] : []
            value: Theme.windowRadius
            minimum: 0
            maximum: 64
            unit: "px"
            onSliderDragFinished: finalValue => SettingsData.set(root.windowRadiusKey, finalValue)
        }

        SettingsSplitRow {
            tab: "theme"
            tags: ["elevation", "shadow", "lift", "m3", "material"]
            settingKey: "m3ElevationLink"
            title: I18n.tr("Shadows")
            subtitle: SettingsTabs.page("surface_shadows")?.hint ?? ""
            resetKeys: ["m3ElevationEnabled"]
            checked: SettingsData.m3ElevationEnabled ?? true
            onNavigated: root.parentModal?.navigateTo("surface_shadows")
            onToggled: checked => SettingsData.set("m3ElevationEnabled", checked)
        }
    }

    SettingsCard {
        tab: "theme"
        tags: ["floating", "window", "settings", "notepad", "authentication", "polkit", "opacity", "transparency", "foreground", "tile", "tiling", "override"]
        title: I18n.tr("Floating windows")
        settingKey: "floatingWindows"

        SettingsToggleRow {
            tab: "theme"
            tags: ["floating", "window", "sync", "global", "surface", "opacity", "override"]
            settingKey: "floatingWindowSyncGlobal"
            text: I18n.tr("Override", "verb, toggle to override the global setting for this item")
            checked: !root.followsSurfaces
            onToggled: checked => SettingsData.set("floatingWindowSyncGlobal", !checked)
        }

        SettingsSliderRow {
            enabled: !root.followsSurfaces
            tab: "theme"
            tags: ["floating", "window", "opacity", "transparency", "settings", "notepad", "authentication", "polkit"]
            settingKey: "floatingWindowTransparency"
            text: I18n.tr("Opacity")
            value: Math.round(Theme.floatingWindowTransparency * 100)
            minimum: 0
            maximum: 100
            onSliderValueChanged: newValue => SettingsData.set("floatingWindowTransparency", newValue / 100)
        }

        SettingsToggleRow {
            enabled: !root.followsSurfaces
            tab: "theme"
            tags: ["floating", "window", "foreground", "layers", "contrast", "cards", "blur", "glass"]
            settingKey: "floatingWindowForegroundLayers"
            text: I18n.tr("Foreground layers")
            checked: Theme.floatingWindowForegroundLayers
            onToggled: checked => SettingsData.set("floatingWindowForegroundLayers", checked)
        }

        SettingsSliderRow {
            tab: "theme"
            tags: ["floating", "window", "foreground", "layers", "opacity", "transparency", "cards"]
            settingKey: "floatingWindowForegroundTransparency"
            text: I18n.tr("Foreground opacity")
            visible: !root.followsSurfaces && Theme.floatingWindowForegroundLayers
            value: Math.round(Theme.floatingWindowForegroundTransparency * 100)
            minimum: 0
            maximum: 100
            onSliderValueChanged: newValue => SettingsData.set("floatingWindowForegroundTransparency", newValue / 100)
        }

        SettingsToggleRow {
            tab: "theme"
            tags: ["floating", "window", "tile", "tiling", "compositor", "rule", "niri", "hyprland", "mango"]
            settingKey: "dmsWindowsFloating"
            text: I18n.tr("Open floating")
            visible: windowRulesInclude.compositorSupported
            checked: SettingsData.dmsWindowsFloating ?? true
            onToggled: checked => {
                SettingsData.set("dmsWindowsFloating", checked);
                if (checked)
                    windowRulesInclude.check();
            }
        }

        IncludeSetupBanner {
            include: windowRulesInclude
            visibleCondition: windowRulesInclude.compositorSupported && (SettingsData.dmsWindowsFloating ?? true)
        }
    }

    Component {
        id: opacityTargetRow

        SettingsToggleRow {
            id: overrideRow

            required property var modelData

            tab: "theme"
            tags: ["surface", "opacity", "transparency", "bar", "dock", "override"]
            settingKey: "surfaceOpacity_" + modelData.kind + "_" + modelData.id
            text: modelData.name
            description: I18n.tr("Override")
            checked: modelData.override
            modified: modelData.override
            resetByKeys: false
            onResetRequested: root.setOpacityOverride(modelData, {
                followInterfaceStyle: true,
                transparency: 1
            })
            onToggled: checked => root.setOpacityOverride(modelData, {
                    followInterfaceStyle: !checked
                })

            body: SettingsSliderRow {
                width: parent.width
                enabled: overrideRow.modelData.override
                text: I18n.tr("Opacity")
                value: Math.round(overrideRow.modelData.transparency * 100)
                minimum: 0
                maximum: 100
                modified: value !== 100
                resetByKeys: false
                onResetRequested: root.setOpacityOverride(overrideRow.modelData, {
                    transparency: 1
                })
                onSliderDragFinished: finalValue => root.setOpacityOverride(overrideRow.modelData, {
                        transparency: finalValue / 100
                    })
            }
        }
    }

    Repeater {
        model: [
            {
                kind: "bar",
                title: I18n.tr("Bars"),
                settingKey: "barOpacityOverrides"
            },
            {
                kind: "dock",
                title: I18n.tr("Docks"),
                settingKey: "dockOpacityOverrides"
            }
        ]

        SettingsCard {
            id: targetCard

            required property var modelData
            readonly property var targets: root.opacityTargets.filter(target => target.kind === modelData.kind)
            readonly property var activeTargets: targets.filter(target => target.enabled)
            readonly property var hiddenTargets: targets.filter(target => !target.enabled)
            property bool showHidden: false

            tab: "theme"
            tags: ["surface", "opacity", "transparency", modelData.kind, "override"]
            title: modelData.title
            settingKey: modelData.settingKey
            visible: targets.length > 0

            Repeater {
                model: targetCard.activeTargets
                delegate: opacityTargetRow
            }

            SettingsRow {
                tab: "theme"
                tags: ["surface", "opacity", "transparency", targetCard.modelData.kind, "hidden", "disabled"]
                title: I18n.tr("Hidden (%1)", "island settings: hidden groups divider, %1 is count").arg(targetCard.hiddenTargets.length)
                iconName: "visibility_off"
                visible: targetCard.hiddenTargets.length > 0
                clickable: true
                onClicked: targetCard.showHidden = !targetCard.showHidden

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: targetCard.showHidden ? "expand_less" : "expand_more"
                    size: Theme.iconSize
                    color: Theme.onSurfaceVariant
                }
            }

            Repeater {
                model: targetCard.showHidden ? targetCard.hiddenTargets : []
                delegate: opacityTargetRow
            }
        }
    }

    SettingsToggleCard {
        tab: "theme"
        tags: ["surface", "popup", "modal", "border", "outline", "edge"]
        settingKey: "blurBorderEnabled"
        iconName: "border_style"
        title: I18n.tr("Border")
        checked: root.borderEnabled
        onToggled: checked => SettingsData.set("blurBorderEnabled", checked)

        SettingsDropdownRow {
            tab: "theme"
            tags: ["surface", "popup", "modal", "border", "outline", "edge", "color"]
            settingKey: "blurBorderColor"
            resetKeys: ["blurBorderColor", "blurBorderCustomColor"]
            text: I18n.tr("Border color")
            options: [I18n.tr("Outline", "surface border color"), I18n.tr("Primary", "surface border color"), I18n.tr("Secondary", "surface border color"), I18n.tr("Text Color", "surface border color"), I18n.tr("Custom", "surface border color")]
            optionColorMap: ({
                    [I18n.tr("Outline", "surface border color")]: Theme.outline,
                    [I18n.tr("Primary", "surface border color")]: Theme.primary,
                    [I18n.tr("Secondary", "surface border color")]: Theme.secondary,
                    [I18n.tr("Text Color", "surface border color")]: Theme.surfaceText,
                    [I18n.tr("Custom", "surface border color")]: SettingsData.blurBorderCustomColor ?? "#ffffff"
                })
            currentValue: {
                switch (SettingsData.blurBorderColor) {
                case "primary":
                    return I18n.tr("Primary", "surface border color");
                case "secondary":
                    return I18n.tr("Secondary", "surface border color");
                case "surfaceText":
                    return I18n.tr("Text Color", "surface border color");
                case "custom":
                    return I18n.tr("Custom", "surface border color");
                default:
                    return I18n.tr("Outline", "surface border color");
                }
            }
            onValueChanged: value => {
                switch (value) {
                case I18n.tr("Primary", "surface border color"):
                    SettingsData.set("blurBorderColor", "primary");
                    return;
                case I18n.tr("Secondary", "surface border color"):
                    SettingsData.set("blurBorderColor", "secondary");
                    return;
                case I18n.tr("Text Color", "surface border color"):
                    SettingsData.set("blurBorderColor", "surfaceText");
                    return;
                case I18n.tr("Custom", "surface border color"):
                    SettingsData.set("blurBorderColor", "custom");
                    root.openSurfaceBorderColorPicker();
                    return;
                }
                SettingsData.set("blurBorderColor", "outline");
            }
        }

        SettingsSliderRow {
            tab: "theme"
            tags: ["surface", "popup", "modal", "border", "opacity"]
            settingKey: "blurBorderOpacity"
            text: I18n.tr("Border opacity")
            value: Math.round((SettingsData.blurBorderOpacity ?? 0.35) * 100)
            minimum: 0
            maximum: 100
            onSliderValueChanged: newValue => SettingsData.set("blurBorderOpacity", newValue / 100)
        }
    }

    SettingsToggleCard {
        tab: "theme"
        tags: ["focus", "ring", "keyboard", "outline", "highlight"]
        settingKey: "focusRingEnabled"
        iconName: "center_focus_strong"
        title: I18n.tr("Focus ring")
        checked: SettingsData.focusRingEnabled
        onToggled: checked => SettingsData.set("focusRingEnabled", checked)

        SettingsSliderRow {
            tab: "theme"
            tags: ["focus", "ring", "thickness", "width"]
            settingKey: "focusRingWidth"
            text: I18n.tr("Thickness")
            value: Math.round(SettingsData.focusRingWidth * 10)
            minimum: 10
            maximum: 40
            step: 5
            decimals: 1
            unit: "px"
            onSliderValueChanged: newValue => SettingsData.set("focusRingWidth", newValue / 10)
        }

        SettingsDropdownRow {
            tab: "theme"
            tags: ["focus", "ring", "color"]
            settingKey: "focusRingColor"
            text: I18n.tr("Color")
            options: [I18n.tr("Primary", "surface border color"), I18n.tr("Secondary", "surface border color"), I18n.tr("Outline", "surface border color"), I18n.tr("Text Color", "surface border color")]
            optionColorMap: ({
                    [I18n.tr("Primary", "surface border color")]: Theme.primary,
                    [I18n.tr("Secondary", "surface border color")]: Theme.secondary,
                    [I18n.tr("Outline", "surface border color")]: Theme.outline,
                    [I18n.tr("Text Color", "surface border color")]: Theme.surfaceText
                })
            currentValue: {
                switch (SettingsData.focusRingColor) {
                case "secondary":
                    return I18n.tr("Secondary", "surface border color");
                case "outline":
                    return I18n.tr("Outline", "surface border color");
                case "surfaceText":
                    return I18n.tr("Text Color", "surface border color");
                default:
                    return I18n.tr("Primary", "surface border color");
                }
            }
            onValueChanged: value => {
                switch (value) {
                case I18n.tr("Secondary", "surface border color"):
                    SettingsData.set("focusRingColor", "secondary");
                    return;
                case I18n.tr("Outline", "surface border color"):
                    SettingsData.set("focusRingColor", "outline");
                    return;
                case I18n.tr("Text Color", "surface border color"):
                    SettingsData.set("focusRingColor", "surfaceText");
                    return;
                }
                SettingsData.set("focusRingColor", "primary");
            }
        }
    }

    SettingsCard {
        tab: "theme"
        tags: ["button", "color", "accent"]
        title: I18n.tr("Colors")
        settingKey: "surfaceColors"

        SettingsDropdownRow {
            tab: "theme"
            tags: ["button", "color", "primary", "accent", "action"]
            settingKey: "buttonColorMode"
            text: I18n.tr("Button color")
            options: [I18n.tr("Primary", "button color option"), I18n.tr("Primary Container", "button color option"), I18n.tr("Secondary", "button color option"), I18n.tr("Surface Variant", "button color option")]
            optionColorMap: ({
                    [I18n.tr("Primary", "button color option")]: Theme.roleColor("primary"),
                    [I18n.tr("Primary Container", "button color option")]: Theme.roleColor("primaryContainer"),
                    [I18n.tr("Secondary", "button color option")]: Theme.roleColor("secondary"),
                    [I18n.tr("Surface Variant", "button color option")]: Theme.roleColor("surfaceVariant")
                })
            currentValue: {
                switch (SettingsData.buttonColorMode) {
                case "primaryContainer":
                    return I18n.tr("Primary Container", "button color option");
                case "secondary":
                    return I18n.tr("Secondary", "button color option");
                case "surfaceVariant":
                    return I18n.tr("Surface Variant", "button color option");
                default:
                    return I18n.tr("Primary", "button color option");
                }
            }
            onValueChanged: value => {
                switch (value) {
                case I18n.tr("Primary Container", "button color option"):
                    SettingsData.set("buttonColorMode", "primaryContainer");
                    return;
                case I18n.tr("Secondary", "button color option"):
                    SettingsData.set("buttonColorMode", "secondary");
                    return;
                case I18n.tr("Surface Variant", "button color option"):
                    SettingsData.set("buttonColorMode", "surfaceVariant");
                    return;
                }
                SettingsData.set("buttonColorMode", "primary");
            }
        }
    }

    SettingsCard {
        tab: "theme"
        tags: ["control center", "icon", "scale", "size", "tile"]
        title: I18n.tr("Control Center", "Control Center")
        settingKey: "controlCenterIcons"

        SettingsDropdownRow {
            tab: "theme"
            tags: ["control", "center", "tile", "button", "color", "active"]
            settingKey: "controlCenterTileColorMode"
            text: I18n.tr("Tile color")
            options: [I18n.tr("Primary", "tile color option"), I18n.tr("Primary Container", "tile color option"), I18n.tr("Secondary", "tile color option"), I18n.tr("Surface Variant", "tile color option")]
            optionColorMap: ({
                    [I18n.tr("Primary", "tile color option")]: Theme.roleColor("primary"),
                    [I18n.tr("Primary Container", "tile color option")]: Theme.roleColor("primaryContainer"),
                    [I18n.tr("Secondary", "tile color option")]: Theme.roleColor("secondary"),
                    [I18n.tr("Surface Variant", "tile color option")]: Theme.roleColor("surfaceVariant")
                })
            currentValue: {
                switch (SettingsData.controlCenterTileColorMode) {
                case "primaryContainer":
                    return I18n.tr("Primary Container", "tile color option");
                case "secondary":
                    return I18n.tr("Secondary", "tile color option");
                case "surfaceVariant":
                    return I18n.tr("Surface Variant", "tile color option");
                default:
                    return I18n.tr("Primary", "tile color option");
                }
            }
            onValueChanged: value => {
                switch (value) {
                case I18n.tr("Primary Container", "tile color option"):
                    SettingsData.set("controlCenterTileColorMode", "primaryContainer");
                    return;
                case I18n.tr("Secondary", "tile color option"):
                    SettingsData.set("controlCenterTileColorMode", "secondary");
                    return;
                case I18n.tr("Surface Variant", "tile color option"):
                    SettingsData.set("controlCenterTileColorMode", "surfaceVariant");
                    return;
                }
                SettingsData.set("controlCenterTileColorMode", "primary");
            }
        }

        SettingsSliderRow {
            tab: "theme"
            tags: ["control", "center", "icon", "scale", "size", "tile", "header"]
            settingKey: "controlCenterIconScale"
            text: I18n.tr("Icon scale")
            minimum: 50
            maximum: 150
            step: 5
            unit: ""
            decimals: 2
            value: Math.round(SettingsData.controlCenterIconScale * 100)
            onSliderValueChanged: value => SettingsData.set("controlCenterIconScale", value / 100)
        }
    }
}
