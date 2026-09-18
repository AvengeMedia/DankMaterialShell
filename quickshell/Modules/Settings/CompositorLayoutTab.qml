import QtCore
import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    property var parentModal: null

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string xrayConflictSource: ""

    ConfigInclude {
        id: layoutInclude
        includeKind: "layout"
        onFixed: SettingsData.updateCompositorLayout()
    }

    function checkXrayConflicts() {
        if (!CompositorService.isNiri)
            return;
        const configDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation));
        const script = `cd "${configDir}/niri" 2>/dev/null || exit 0
files="config.kdl"
for f in $(sed -nE 's/^[[:space:]]*include[[:space:]]+"([^"]+)".*/\\1/p' config.kdl 2>/dev/null); do
    case "$f" in dms/*|/*dms/*) continue ;; esac
    [ -f "$f" ] && files="$files $f"
done
awk '$1 == "xray" { print FILENAME ":" FNR; exit }' $files 2>/dev/null`;

        Proc.runCommand("check-xray-conflict", ["sh", "-c", script], (output, exitCode) => {
            xrayConflictSource = exitCode === 0 ? output.trim() : "";
        });
    }

    Component.onCompleted: checkXrayConflicts()

    SettingsPage {
        id: layoutColumn

        IncludeSetupBanner {
            include: layoutInclude
            visibleCondition: layoutInclude.compositorSupported
        }

        StyledRect {
            width: parent.width
            height: xrayConflictRow.implicitHeight + Theme.spacingL * 2
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.primary, 0.15)
            border.color: Theme.withAlpha(Theme.primary, 0.3)
            border.width: Theme.outlineWidth
            visible: root.xrayConflictSource !== ""

            Row {
                id: xrayConflictRow
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                DankIcon {
                    name: "warning"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    width: parent.width - Theme.iconSize - Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("An xray rule at %1 may conflict with the Xray settings below", "compositor layout warning, %1 is a config location").arg(root.xrayConflictSource)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }
            }
        }

        SettingsCard {
            width: parent.width
            tags: ["niri", "layout", "gaps", "radius", "window", "border"]
            title: I18n.tr("Layout overrides")
            settingKey: "niriLayout"
            iconName: "layers"
            visible: CompositorService.isNiri

            SettingsButtonGroupRow {
                tags: ["niri", "gaps", "override", "unmanaged"]
                settingKey: "niriLayoutGapsMode"
                resetKeys: ["niriLayoutGapsOverride"]
                text: I18n.tr("Gaps", "noun, window gaps mode in compositor layout settings")
                description: I18n.tr("Auto follows bar spacing, Off keeps your %1 config", "gaps mode description, %1 is the compositor name").arg("niri")
                model: [I18n.tr("Auto"), I18n.tr("Custom"), I18n.tr("Off")]
                currentIndex: {
                    if (SettingsData.niriLayoutGapsOverride === -2)
                        return 2;
                    return SettingsData.niriLayoutGapsOverride >= 0 ? 1 : 0;
                }
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    switch (index) {
                    case 1:
                        SettingsData.set("niriLayoutGapsOverride", Math.max(4, (SettingsData.getPrimaryBarConfig()?.spacing ?? 4)));
                        return;
                    case 2:
                        SettingsData.set("niriLayoutGapsOverride", -2);
                        return;
                    default:
                        SettingsData.set("niriLayoutGapsOverride", -1);
                    }
                }
            }

            SettingsSliderRow {
                tags: ["niri", "gaps", "override"]
                settingKey: "niriLayoutGapsOverride"
                resetKeys: []
                text: I18n.tr("Window gaps")
                visible: SettingsData.niriLayoutGapsOverride >= 0
                value: Math.max(0, SettingsData.niriLayoutGapsOverride)
                minimum: 0
                maximum: 50
                unit: "px"
                onSliderValueChanged: newValue => SettingsData.set("niriLayoutGapsOverride", newValue)
            }

            SettingsControlledBy {
                target: "surfaces"
                parentModal: root.parentModal
                section: "windowRadius"
                settingLabel: I18n.tr("Window radius")
                reason: Math.round(Theme.windowRadius) + "px"
            }

            SettingsToggleRow {
                tags: ["niri", "border", "override", "focus-ring"]
                settingKey: "niriLayoutBorderSizeEnabled"
                resetKeys: ["niriLayoutBorderSize"]
                text: I18n.tr("Override border size")
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
                tags: ["niri", "border", "override", "focus-ring"]
                settingKey: "niriLayoutBorderSize"
                resetKeys: []
                text: I18n.tr("Border size")
                visible: SettingsData.niriLayoutBorderSize >= 0
                value: Math.max(0, SettingsData.niriLayoutBorderSize)
                minimum: 0
                maximum: 10
                unit: "px"
                onSliderValueChanged: newValue => SettingsData.set("niriLayoutBorderSize", newValue)
            }

            SettingsToggleRow {
                visible: CompositorService.isNiri
                tags: ["niri", "xray", "blur", "background-effect", "performance"]
                settingKey: "niriLayoutXrayEnabled"
                text: I18n.tr("Xray blur")
                description: I18n.tr("Blurred surfaces show the wallpaper, not the windows beneath")
                checked: NiriService.layoutXrayEnabled
                onToggled: checked => NiriService.setLayoutXray(checked)
            }

            SettingsToggleRow {
                visible: CompositorService.isNiri && !SettingsData.connectedFrameModeActive
                tags: ["niri", "xray", "bar", "frame", "performance"]
                settingKey: "niriLayoutBarXrayEnabled"
                text: SettingsData.frameEnabled ? I18n.tr("Frame xray") : I18n.tr("Bar xray")
                description: I18n.tr("Blur against the wallpaper even with xray off")
                checked: NiriService.layoutBarXrayEnabled
                onToggled: checked => NiriService.setLayoutBarXray(checked)
            }
        }

        SettingsCard {
            width: parent.width
            tags: ["compositor", "toast"]
            title: I18n.tr("Notifications")
            settingKey: "compositorNotifications"
            iconName: "notifications"
            visible: CompositorService.isNiri || CompositorService.isMango

            SettingsToggleRow {
                tags: ["compositor", "toast", "reload"]
                settingKey: "showConfigReloadToast"
                text: I18n.tr("Show \"config reloaded\" toast")
                checked: SessionData.showConfigReloadToast
                onToggled: checked => SessionData.showConfigReloadToast = checked
            }
        }

        SettingsCard {
            width: parent.width
            tags: ["niri", "overview", "window", "focus", "launch", "launcher", "dock", "settings"]
            title: I18n.tr("Overview")
            settingKey: "niriOverview"
            iconName: "overview"
            visible: CompositorService.isNiri

            SettingsToggleRow {
                tags: ["niri", "overview", "window", "focus", "launch", "launcher", "dock", "settings"]
                settingKey: "closeNiriOverviewOnWindowFocus"
                text: I18n.tr("Close on window focus")
                checked: SettingsData.closeNiriOverviewOnWindowFocus
                onToggled: checked => SettingsData.set("closeNiriOverviewOnWindowFocus", checked)
            }
        }

        SettingsCard {
            id: hyprTilingCard
            width: parent.width
            tags: ["hyprland", "layout", "tiling", "dwindle", "master", "scrolling", "general:layout"]
            title: I18n.tr("Tiling layout")
            settingKey: "hyprlandTilingLayout"
            iconName: "view_quilt"
            visible: CompositorService.isHyprland

            readonly property var layoutIds: ["", "dwindle", "master", "scrolling"]

            SettingsButtonGroupRow {
                tags: ["hyprland", "layout", "tiling", "dwindle", "master", "scrolling"]
                settingKey: "hyprlandTilingLayout"
                text: I18n.tr("Layout")
                model: [I18n.tr("Off"), I18n.tr("Dwindle", "Hyprland tiling layout name"), I18n.tr("Master", "Hyprland tiling layout name"), I18n.tr("Scrolling", "Hyprland tiling layout name")]
                currentIndex: Math.max(0, hyprTilingCard.layoutIds.indexOf(SettingsData.hyprlandTilingLayout))
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    SettingsData.set("hyprlandTilingLayout", hyprTilingCard.layoutIds[index]);
                }
            }

            SettingsToggleRow {
                tags: ["hyprland", "dwindle", "preserve", "split"]
                settingKey: "hyprlandDwindlePreserveSplit"
                visible: SettingsData.hyprlandTilingLayout === "dwindle"
                text: I18n.tr("Preserve split")
                description: I18n.tr("Split direction stays fixed when the container resizes")
                checked: SettingsData.hyprlandDwindlePreserveSplit
                onToggled: checked => SettingsData.set("hyprlandDwindlePreserveSplit", checked)
            }

            SettingsToggleRow {
                tags: ["hyprland", "dwindle", "smart", "split", "cursor"]
                settingKey: "hyprlandDwindleSmartSplit"
                visible: SettingsData.hyprlandTilingLayout === "dwindle"
                text: I18n.tr("Smart split")
                description: I18n.tr("Split direction follows the cursor position in the window")
                checked: SettingsData.hyprlandDwindleSmartSplit
                onToggled: checked => SettingsData.set("hyprlandDwindleSmartSplit", checked)
            }

            SettingsButtonGroupRow {
                tags: ["hyprland", "dwindle", "force", "split", "direction"]
                settingKey: "hyprlandDwindleForceSplit"
                visible: SettingsData.hyprlandTilingLayout === "dwindle"
                text: I18n.tr("Force split")
                model: [I18n.tr("Follow mouse"), I18n.tr("Left"), I18n.tr("Right")]
                currentIndex: SettingsData.hyprlandDwindleForceSplit
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    SettingsData.set("hyprlandDwindleForceSplit", index);
                }
            }

            SettingsDropdownRow {
                readonly property var ids: ["left", "right", "top", "bottom", "center"]
                tags: ["hyprland", "master", "orientation", "position"]
                settingKey: "hyprlandMasterOrientation"
                visible: SettingsData.hyprlandTilingLayout === "master"
                text: I18n.tr("Master position")
                options: [I18n.tr("Left"), I18n.tr("Right"), I18n.tr("Top"), I18n.tr("Bottom"), I18n.tr("Center")]
                currentValue: options[Math.max(0, ids.indexOf(SettingsData.hyprlandMasterOrientation))]
                onValueChanged: value => SettingsData.set("hyprlandMasterOrientation", ids[Math.max(0, options.indexOf(value))])
            }

            SettingsButtonGroupRow {
                readonly property var ids: ["slave", "master", "inherit"]
                tags: ["hyprland", "master", "new", "window", "status", "slave"]
                settingKey: "hyprlandMasterNewStatus"
                visible: SettingsData.hyprlandTilingLayout === "master"
                text: I18n.tr("New windows")
                model: [I18n.tr("Stack"), I18n.tr("Master", "Hyprland tiling layout name"), I18n.tr("Inherit")]
                currentIndex: Math.max(0, ids.indexOf(SettingsData.hyprlandMasterNewStatus))
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    SettingsData.set("hyprlandMasterNewStatus", ids[index]);
                }
            }

            SettingsToggleRow {
                tags: ["hyprland", "master", "new", "top", "stack"]
                settingKey: "hyprlandMasterNewOnTop"
                visible: SettingsData.hyprlandTilingLayout === "master"
                text: I18n.tr("New windows on top of the stack")
                checked: SettingsData.hyprlandMasterNewOnTop
                onToggled: checked => SettingsData.set("hyprlandMasterNewOnTop", checked)
            }

            SettingsSliderRow {
                tags: ["hyprland", "master", "size", "mfact", "ratio"]
                settingKey: "hyprlandMasterSize"
                visible: SettingsData.hyprlandTilingLayout === "master"
                text: I18n.tr("Master size")
                value: SettingsData.hyprlandMasterSize
                minimum: 10
                maximum: 90
                onSliderValueChanged: newValue => SettingsData.set("hyprlandMasterSize", newValue)
            }

            SettingsButtonGroupRow {
                readonly property var ids: ["right", "left", "down", "up"]
                tags: ["hyprland", "scrolling", "direction"]
                settingKey: "hyprlandScrollingDirection"
                visible: SettingsData.hyprlandTilingLayout === "scrolling"
                text: I18n.tr("Direction")
                model: [I18n.tr("Right"), I18n.tr("Left"), I18n.tr("Down"), I18n.tr("Up")]
                currentIndex: Math.max(0, ids.indexOf(SettingsData.hyprlandScrollingDirection))
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    SettingsData.set("hyprlandScrollingDirection", ids[index]);
                }
            }

            SettingsSliderRow {
                tags: ["hyprland", "scrolling", "column", "width"]
                settingKey: "hyprlandScrollingColumnWidth"
                visible: SettingsData.hyprlandTilingLayout === "scrolling"
                text: I18n.tr("Column Width")
                value: SettingsData.hyprlandScrollingColumnWidth
                minimum: 10
                maximum: 100
                onSliderValueChanged: newValue => SettingsData.set("hyprlandScrollingColumnWidth", newValue)
            }

            SettingsToggleRow {
                tags: ["hyprland", "scrolling", "fullscreen", "single", "column"]
                settingKey: "hyprlandScrollingFullscreenOneColumn"
                visible: SettingsData.hyprlandTilingLayout === "scrolling"
                text: I18n.tr("Fullscreen single column")
                checked: SettingsData.hyprlandScrollingFullscreenOneColumn
                onToggled: checked => SettingsData.set("hyprlandScrollingFullscreenOneColumn", checked)
            }

            SettingsToggleRow {
                tags: ["hyprland", "scrolling", "follow", "focus", "scroll"]
                settingKey: "hyprlandScrollingFollowFocus"
                visible: SettingsData.hyprlandTilingLayout === "scrolling"
                text: I18n.tr("Follow focus")
                checked: SettingsData.hyprlandScrollingFollowFocus
                onToggled: checked => SettingsData.set("hyprlandScrollingFollowFocus", checked)
            }
        }

        SettingsCard {
            width: parent.width
            tags: ["hyprland", "layout", "gaps", "radius", "window", "border", "rounding"]
            title: I18n.tr("Layout overrides")
            settingKey: "hyprlandLayout"
            iconName: "crop_square"
            visible: CompositorService.isHyprland

            SettingsButtonGroupRow {
                tags: ["hyprland", "gaps", "override", "inner", "outer", "unmanaged"]
                settingKey: "hyprlandLayoutGapsMode"
                resetKeys: ["hyprlandLayoutGapsOverride"]
                text: I18n.tr("Gaps")
                model: [I18n.tr("Auto"), I18n.tr("Custom"), I18n.tr("Off")]
                currentIndex: {
                    if (SettingsData.hyprlandLayoutGapsOverride === -2)
                        return 2;
                    return SettingsData.hyprlandLayoutGapsOverride >= 0 ? 1 : 0;
                }
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    switch (index) {
                    case 1:
                        SettingsData.set("hyprlandLayoutGapsOverride", Math.max(4, (SettingsData.getPrimaryBarConfig()?.spacing ?? 4)));
                        return;
                    case 2:
                        SettingsData.set("hyprlandLayoutGapsOverride", -2);
                        return;
                    default:
                        SettingsData.set("hyprlandLayoutGapsOverride", -1);
                    }
                }
            }

            SettingsSliderRow {
                tags: ["hyprland", "gaps", "override", "inner", "gaps_in"]
                settingKey: "hyprlandLayoutGapsOverride"
                resetKeys: []
                text: I18n.tr("Inner gaps")
                visible: SettingsData.hyprlandLayoutGapsOverride >= 0
                value: Math.max(0, SettingsData.hyprlandLayoutGapsOverride)
                minimum: 0
                maximum: 50
                unit: "px"
                onSliderValueChanged: newValue => SettingsData.set("hyprlandLayoutGapsOverride", newValue)
            }

            SettingsSliderRow {
                tags: ["hyprland", "gaps", "override", "outer", "edge", "gaps_out"]
                settingKey: "hyprlandLayoutGapsOutOverride"
                text: I18n.tr("Outer gaps")
                visible: SettingsData.hyprlandLayoutGapsOverride >= 0
                value: SettingsData.hyprlandLayoutGapsOutOverride >= 0 ? SettingsData.hyprlandLayoutGapsOutOverride : Math.max(0, SettingsData.hyprlandLayoutGapsOverride)
                minimum: 0
                maximum: 50
                unit: "px"
                onSliderValueChanged: newValue => SettingsData.set("hyprlandLayoutGapsOutOverride", newValue)
            }

            SettingsControlledBy {
                target: "surfaces"
                parentModal: root.parentModal
                section: "windowRadius"
                settingLabel: I18n.tr("Window radius")
                reason: Math.round(Theme.windowRadius) + "px"
            }

            SettingsToggleRow {
                tags: ["hyprland", "border", "override"]
                settingKey: "hyprlandLayoutBorderSizeEnabled"
                resetKeys: ["hyprlandLayoutBorderSize"]
                text: I18n.tr("Override border size")
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
                tags: ["hyprland", "border", "override", "border_size"]
                settingKey: "hyprlandLayoutBorderSize"
                resetKeys: []
                text: I18n.tr("Border size")
                visible: SettingsData.hyprlandLayoutBorderSize >= 0
                value: Math.max(0, SettingsData.hyprlandLayoutBorderSize)
                minimum: 0
                maximum: 10
                unit: "px"
                onSliderValueChanged: newValue => SettingsData.set("hyprlandLayoutBorderSize", newValue)
            }

            SettingsToggleRow {
                tags: ["hyprland", "resize", "border", "mouse", "drag"]
                settingKey: "hyprlandResizeOnBorder"
                text: I18n.tr("Resize on border")
                checked: SettingsData.hyprlandResizeOnBorder
                onToggled: checked => SettingsData.set("hyprlandResizeOnBorder", checked)
            }

            SettingsToggleRow {
                visible: CompositorService.isHyprland
                tags: ["hyprland", "xray", "blur", "background-effect", "performance"]
                settingKey: "hyprlandLayoutXrayEnabled"
                text: I18n.tr("Xray blur")
                description: I18n.tr("Blurred surfaces show the wallpaper, not the windows beneath")
                checked: HyprlandService.layoutXrayEnabled
                onToggled: checked => HyprlandService.setLayoutXray(checked)
            }

            SettingsToggleRow {
                visible: CompositorService.isHyprland && !SettingsData.connectedFrameModeActive
                tags: ["hyprland", "xray", "bar", "frame", "performance"]
                settingKey: "hyprlandLayoutBarXrayEnabled"
                text: SettingsData.frameEnabled ? I18n.tr("Frame xray") : I18n.tr("Bar xray")
                description: I18n.tr("Blur against the wallpaper even with xray off")
                checked: HyprlandService.layoutBarXrayEnabled
                onToggled: checked => HyprlandService.setLayoutBarXray(checked)
            }
        }

        SettingsCard {
            width: parent.width
            tags: ["mangowc", "mango", "dwl", "layout", "gaps", "radius", "window", "border"]
            title: I18n.tr("Layout overrides")
            settingKey: "mangoLayout"
            iconName: "crop_square"
            visible: CompositorService.isMango

            SettingsButtonGroupRow {
                tags: ["mangowc", "mango", "gaps", "override", "inner", "outer", "unmanaged"]
                settingKey: "mangoLayoutGapsMode"
                resetKeys: ["mangoLayoutGapsOverride"]
                text: I18n.tr("Gaps")
                description: I18n.tr("Auto follows bar spacing, Off keeps your %1 config").arg("MangoWC")
                model: [I18n.tr("Auto"), I18n.tr("Custom"), I18n.tr("Off")]
                currentIndex: {
                    if (SettingsData.mangoLayoutGapsOverride === -2)
                        return 2;
                    return SettingsData.mangoLayoutGapsOverride >= 0 ? 1 : 0;
                }
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    switch (index) {
                    case 1:
                        SettingsData.set("mangoLayoutGapsOverride", Math.max(4, (SettingsData.getPrimaryBarConfig()?.spacing ?? 4)));
                        return;
                    case 2:
                        SettingsData.set("mangoLayoutGapsOverride", -2);
                        return;
                    default:
                        SettingsData.set("mangoLayoutGapsOverride", -1);
                    }
                }
            }

            SettingsSliderRow {
                tags: ["mangowc", "mango", "gaps", "override", "inner", "gappih", "gappiv"]
                settingKey: "mangoLayoutGapsOverride"
                resetKeys: []
                text: I18n.tr("Inner gaps")
                visible: SettingsData.mangoLayoutGapsOverride >= 0
                value: Math.max(0, SettingsData.mangoLayoutGapsOverride)
                minimum: 0
                maximum: 50
                unit: "px"
                onSliderValueChanged: newValue => SettingsData.set("mangoLayoutGapsOverride", newValue)
            }

            SettingsSliderRow {
                tags: ["mangowc", "mango", "gaps", "override", "outer", "edge", "gappoh", "gappov"]
                settingKey: "mangoLayoutGapsOutOverride"
                text: I18n.tr("Outer gaps")
                visible: SettingsData.mangoLayoutGapsOverride >= 0
                value: SettingsData.mangoLayoutGapsOutOverride >= 0 ? SettingsData.mangoLayoutGapsOutOverride : Math.max(0, SettingsData.mangoLayoutGapsOverride)
                minimum: 0
                maximum: 50
                unit: "px"
                onSliderValueChanged: newValue => SettingsData.set("mangoLayoutGapsOutOverride", newValue)
            }

            SettingsControlledBy {
                target: "surfaces"
                parentModal: root.parentModal
                section: "windowRadius"
                settingLabel: I18n.tr("Window radius")
                reason: Math.round(Theme.windowRadius) + "px"
            }

            SettingsToggleRow {
                tags: ["mangowc", "mango", "border", "override"]
                settingKey: "mangoLayoutBorderSizeEnabled"
                resetKeys: ["mangoLayoutBorderSize"]
                text: I18n.tr("Override border size")
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
                tags: ["mangowc", "mango", "border", "override", "borderpx"]
                settingKey: "mangoLayoutBorderSize"
                resetKeys: []
                text: I18n.tr("Border size")
                visible: SettingsData.mangoLayoutBorderSize >= 0
                value: Math.max(0, SettingsData.mangoLayoutBorderSize)
                minimum: 0
                maximum: 10
                unit: "px"
                onSliderValueChanged: newValue => SettingsData.set("mangoLayoutBorderSize", newValue)
            }
        }
    }
}
