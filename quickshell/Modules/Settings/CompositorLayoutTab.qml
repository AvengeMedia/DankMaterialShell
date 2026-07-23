import QtCore
import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets
import "../../Common/ConfigIncludeResolve.js" as ConfigIncludeResolve

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var layoutIncludeStatus: ({
            "exists": false,
            "included": false,
            "configFormat": "",
            "readOnly": false
        })
    readonly property bool readOnly: CompositorService.isHyprland && layoutIncludeStatus.readOnly === true
    property bool checkingInclude: false
    property bool fixingInclude: false
    property string xrayConflictSource: ""

    function getLayoutConfigPaths() {
        const configDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation));
        switch (CompositorService.compositor) {
        case "niri":
            return {
                "configFile": configDir + "/niri/config.kdl",
                "layoutFile": configDir + "/niri/dms/layout.kdl",
                "grepPattern": 'include.*"dms/layout.kdl"',
                "includeLine": 'include "dms/layout.kdl"'
            };
        case "hyprland":
            return {
                "configFile": configDir + "/hypr/hyprland.lua",
                "layoutFile": configDir + "/hypr/dms/layout.lua",
                "grepPattern": "dms.layout",
                "includeLine": "require(\"dms.layout\")"
            };
        case "mango":
            return {
                "configFile": configDir + "/mango/config.conf",
                "layoutFile": configDir + "/mango/dms/layout.conf",
                "grepPattern": "source.*dms/layout.conf",
                "includeLine": "source=./dms/layout.conf"
            };
        default:
            return null;
        }
    }

    function checkLayoutIncludeStatus() {
        const compositor = CompositorService.compositor;
        if (compositor !== "niri" && compositor !== "hyprland" && compositor !== "mango") {
            layoutIncludeStatus = {
                "exists": false,
                "included": false,
                "configFormat": "",
                "readOnly": false
            };
            return;
        }

        const filename = compositor === "niri" ? "layout.kdl" : (compositor === "hyprland" ? "layout.lua" : "layout.conf");
        const compositorArg = compositor === "mango" ? "mangowc" : compositor;

        checkingInclude = true;
        Proc.runCommand("check-layout-include", [Proc.dmsBin, "config", "resolve-include", compositorArg, filename], (output, exitCode) => {
            checkingInclude = false;
            if (exitCode !== 0) {
                layoutIncludeStatus = {
                    "exists": false,
                    "included": false,
                    "configFormat": "",
                    "readOnly": false
                };
                return;
            }
            try {
                layoutIncludeStatus = JSON.parse(output.trim());
            } catch (e) {
                layoutIncludeStatus = {
                    "exists": false,
                    "included": false,
                    "configFormat": "",
                    "readOnly": false
                };
            }
        });
    }

    function fixLayoutInclude() {
        if (readOnly) {
            ToastService.showWarning(I18n.tr("Hyprland conf mode"), I18n.tr("This install is still using hyprland.conf. Run dms setup to migrate before changing these settings."), "dms setup", "hyprland-migration");
            return;
        }
        const paths = getLayoutConfigPaths();
        if (!paths)
            return;

        fixingInclude = true;
        const unixTime = Math.floor(Date.now() / 1000);
        const backupFile = paths.configFile + ".backup" + unixTime;
        const script = ConfigIncludeResolve.buildRepairScript({
            configFile: paths.configFile,
            backupFile: backupFile,
            fragmentFile: paths.layoutFile,
            grepPattern: paths.grepPattern,
            includeLine: paths.includeLine
        });
        Proc.runCommand("fix-layout-include", ["sh", "-c", script], (output, exitCode) => {
            fixingInclude = false;
            if (exitCode !== 0)
                return;
            checkLayoutIncludeStatus();
            SettingsData.updateCompositorLayout();
        });
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

    Component.onCompleted: {
        if (CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango) {
            checkLayoutIncludeStatus();
            checkXrayConflicts();
        }
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: layoutColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: layoutColumn

            topPadding: 4
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            StyledRect {
                id: warningBox
                width: parent.width
                height: warningContent.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius

                readonly property bool showLegacy: root.readOnly
                readonly property bool showSetup: !showLegacy && !root.layoutIncludeStatus.included

                color: (showLegacy || showSetup) ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.primary, 0)
                border.color: (showLegacy || showSetup) ? Theme.withAlpha(Theme.primary, 0.3) : Theme.withAlpha(Theme.primary, 0)
                border.width: 1
                visible: (showLegacy || showSetup) && !root.checkingInclude && (CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango)

                Row {
                    id: warningContent
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "warning"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - Theme.iconSize - (fixButton.visible ? fixButton.width + Theme.spacingM : 0) - Theme.spacingM
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: {
                                if (warningBox.showLegacy)
                                    return I18n.tr("Hyprland conf mode");
                                if (warningBox.showSetup)
                                    return I18n.tr("First Time Setup");
                                return "";
                            }
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.primary
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        StyledText {
                            text: {
                                if (warningBox.showLegacy)
                                    return I18n.tr("This install is still using hyprland.conf. Run dms setup to migrate before changing these settings.");
                                if (warningBox.showSetup)
                                    return I18n.tr("Click 'Setup' to create %1 and add include to your compositor config.").arg("dms/layout");
                                return "";
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }
                    }

                    DankButton {
                        id: fixButton
                        visible: !warningBox.showLegacy && warningBox.showSetup
                        text: root.fixingInclude ? I18n.tr("Setting up...") : I18n.tr("Setup")
                        backgroundColor: Theme.primary
                        textColor: Theme.primaryText
                        enabled: !root.fixingInclude
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.fixLayoutInclude()
                    }
                }
            }

            StyledRect {
                width: parent.width
                height: xrayConflictRow.implicitHeight + Theme.spacingL * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.primary, 0.15)
                border.color: Theme.withAlpha(Theme.primary, 0.3)
                border.width: 1
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
                        text: I18n.tr("An xray rule at %1 may conflict with the Xray settings below").arg(root.xrayConflictSource)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }
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
                    text: I18n.tr("Show \"config reloaded\" Toast")
                    description: I18n.tr("Show a toast when the compositor config is reloaded")
                    checked: SessionData.showConfigReloadToast
                    onToggled: checked => SessionData.showConfigReloadToast = checked
                }
            }

            SettingsCard {
                width: parent.width
                tags: ["niri", "layout", "gaps", "radius", "window", "border"]
                title: I18n.tr("%1 Layout Overrides").arg("niri")
                settingKey: "niriLayout"
                iconName: "layers"
                visible: CompositorService.isNiri

                SettingsButtonGroupRow {
                    tags: ["niri", "gaps", "override", "unmanaged"]
                    settingKey: "niriLayoutGapsMode"
                    text: I18n.tr("Gaps")
                    description: I18n.tr("Auto matches bar spacing; Off leaves gaps to your %1 config").arg("niri")
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
                            SettingsData.set("niriLayoutGapsOverride", Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4)));
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

                SettingsToggleRow {
                    visible: CompositorService.isNiri
                    tags: ["niri", "xray", "blur", "background-effect", "performance"]
                    settingKey: "niriLayoutXrayEnabled"
                    text: I18n.tr("Xray Blur Effect")
                    description: I18n.tr("Blurred surfaces show the wallpaper instead of the content beneath")
                    checked: NiriService.layoutXrayEnabled
                    onToggled: checked => NiriService.setLayoutXray(checked)
                }

                SettingsToggleRow {
                    // Hidden in Frame Connected mode, where it has no target
                    visible: CompositorService.isNiri && !SettingsData.connectedFrameModeActive
                    tags: ["niri", "xray", "bar", "frame", "performance"]
                    settingKey: "niriLayoutBarXrayEnabled"
                    text: SettingsData.frameEnabled ? I18n.tr("Frame Xray") : I18n.tr("Dank Bar Xray")
                    description: I18n.tr("Always blur against the wallpaper, even with Xray off")
                    checked: NiriService.layoutBarXrayEnabled
                    onToggled: checked => NiriService.setLayoutBarXray(checked)
                }
            }

            SettingsCard {
                width: parent.width
                tags: ["hyprland", "layout", "gaps", "radius", "window", "border", "rounding"]
                title: I18n.tr("%1 Layout Overrides").arg("Hyprland")
                settingKey: "hyprlandLayout"
                iconName: "crop_square"
                visible: CompositorService.isHyprland

                SettingsButtonGroupRow {
                    tags: ["hyprland", "gaps", "override", "inner", "outer", "unmanaged"]
                    settingKey: "hyprlandLayoutGapsMode"
                    text: I18n.tr("Gaps")
                    description: I18n.tr("Auto matches bar spacing; Off leaves gaps to your %1 config").arg("Hyprland")
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
                            SettingsData.set("hyprlandLayoutGapsOverride", Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4)));
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
                    tags: ["hyprland", "gaps", "override", "inner"]
                    settingKey: "hyprlandLayoutGapsOverride"
                    text: I18n.tr("Inner Gaps")
                    description: I18n.tr("Space between windows") + " (gaps_in)"
                    visible: SettingsData.hyprlandLayoutGapsOverride >= 0
                    value: Math.max(0, SettingsData.hyprlandLayoutGapsOverride)
                    minimum: 0
                    maximum: 50
                    unit: "px"
                    defaultValue: Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4))
                    onSliderValueChanged: newValue => SettingsData.set("hyprlandLayoutGapsOverride", newValue)
                }

                SettingsSliderRow {
                    tags: ["hyprland", "gaps", "override", "outer", "edge"]
                    settingKey: "hyprlandLayoutGapsOutOverride"
                    text: I18n.tr("Outer Gaps")
                    description: I18n.tr("Space between windows and screen edges") + " (gaps_out)"
                    visible: SettingsData.hyprlandLayoutGapsOverride >= 0
                    value: SettingsData.hyprlandLayoutGapsOutOverride >= 0 ? SettingsData.hyprlandLayoutGapsOutOverride : Math.max(0, SettingsData.hyprlandLayoutGapsOverride)
                    minimum: 0
                    maximum: 50
                    unit: "px"
                    defaultValue: Math.max(0, SettingsData.hyprlandLayoutGapsOverride)
                    onSliderValueChanged: newValue => SettingsData.set("hyprlandLayoutGapsOutOverride", newValue)
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

                SettingsToggleRow {
                    visible: CompositorService.isHyprland
                    tags: ["hyprland", "xray", "blur", "background-effect", "performance"]
                    settingKey: "hyprlandLayoutXrayEnabled"
                    text: I18n.tr("Xray Blur Effect")
                    description: I18n.tr("Blurred surfaces show the wallpaper instead of the content beneath")
                    checked: HyprlandService.layoutXrayEnabled
                    onToggled: checked => HyprlandService.setLayoutXray(checked)
                }

                SettingsToggleRow {
                    // Hidden in Frame Connected mode, where it has no target
                    visible: CompositorService.isHyprland && !SettingsData.connectedFrameModeActive
                    tags: ["hyprland", "xray", "bar", "frame", "performance"]
                    settingKey: "hyprlandLayoutBarXrayEnabled"
                    text: SettingsData.frameEnabled ? I18n.tr("Frame Xray") : I18n.tr("Dank Bar Xray")
                    description: I18n.tr("Always blur against the wallpaper, even with Xray off")
                    checked: HyprlandService.layoutBarXrayEnabled
                    onToggled: checked => HyprlandService.setLayoutBarXray(checked)
                }
            }

            SettingsCard {
                width: parent.width
                tags: ["mangowc", "mango", "dwl", "layout", "gaps", "radius", "window", "border"]
                title: I18n.tr("%1 Layout Overrides").arg("MangoWC")
                settingKey: "mangoLayout"
                iconName: "crop_square"
                visible: CompositorService.isMango

                SettingsButtonGroupRow {
                    tags: ["mangowc", "mango", "gaps", "override", "inner", "outer", "unmanaged"]
                    settingKey: "mangoLayoutGapsMode"
                    text: I18n.tr("Gaps")
                    description: I18n.tr("Auto matches bar spacing; Off leaves gaps to your %1 config").arg("MangoWC")
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
                            SettingsData.set("mangoLayoutGapsOverride", Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4)));
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
                    tags: ["mangowc", "mango", "gaps", "override", "inner"]
                    settingKey: "mangoLayoutGapsOverride"
                    text: I18n.tr("Inner Gaps")
                    description: I18n.tr("Space between windows") + " (gappih/gappiv)"
                    visible: SettingsData.mangoLayoutGapsOverride >= 0
                    value: Math.max(0, SettingsData.mangoLayoutGapsOverride)
                    minimum: 0
                    maximum: 50
                    unit: "px"
                    defaultValue: Math.max(4, (SettingsData.barConfigs[0]?.spacing ?? 4))
                    onSliderValueChanged: newValue => SettingsData.set("mangoLayoutGapsOverride", newValue)
                }

                SettingsSliderRow {
                    tags: ["mangowc", "mango", "gaps", "override", "outer", "edge"]
                    settingKey: "mangoLayoutGapsOutOverride"
                    text: I18n.tr("Outer Gaps")
                    description: I18n.tr("Space between windows and screen edges") + " (gappoh/gappov)"
                    visible: SettingsData.mangoLayoutGapsOverride >= 0
                    value: SettingsData.mangoLayoutGapsOutOverride >= 0 ? SettingsData.mangoLayoutGapsOutOverride : Math.max(0, SettingsData.mangoLayoutGapsOverride)
                    minimum: 0
                    maximum: 50
                    unit: "px"
                    defaultValue: Math.max(0, SettingsData.mangoLayoutGapsOverride)
                    onSliderValueChanged: newValue => SettingsData.set("mangoLayoutGapsOutOverride", newValue)
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
