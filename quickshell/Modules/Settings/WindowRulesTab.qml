pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import "../../Common/ConfigIncludeResolve.js" as ConfigIncludeResolve

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var parentModal: null
    property bool pageActive: true
    property bool componentReady: false
    property var windowRulesIncludeStatus: ({
            "exists": false,
            "included": false,
            "configFormat": "",
            "readOnly": false
        })
    readonly property bool readOnly: CompositorService.isHyprland && windowRulesIncludeStatus.readOnly === true
    property bool checkingInclude: false
    property bool fixingInclude: false
    property var windowRules: []
    property var externalRules: []
    property var activeWindows: getActiveWindows()
    property string expandedExternalId: ""
    readonly property string dmsRulesFileName: CompositorService.isNiri ? "dms/windowrules.kdl" : CompositorService.isMango ? "dms/windowrules.conf" : "dms/windowrules.lua"

    Component.onDestruction: SettingsSearchService.unregisterCard("windowRules")

    onPageActiveChanged: {
        if (componentReady && pageActive)
            loadWindowRules();
    }

    readonly property var matchLabels: ({
            "appId": I18n.tr("App ID"),
            "title": I18n.tr("Title"),
            "isFloating": I18n.tr("Floating"),
            "isActive": I18n.tr("Active"),
            "isFocused": I18n.tr("Focused"),
            "isActiveInColumn": I18n.tr("Active in Column"),
            "isWindowCastTarget": I18n.tr("Cast Target"),
            "isUrgent": I18n.tr("Urgent"),
            "atStartup": I18n.tr("At Startup"),
            "xwayland": I18n.tr("XWayland"),
            "fullscreen": I18n.tr("Fullscreen"),
            "pinned": I18n.tr("Pinned"),
            "initialised": I18n.tr("Initialised")
        })

    function matchesOf(rule) {
        const m = rule.matches;
        if (m && m.length > 0)
            return m;
        return [rule.matchCriteria || {}];
    }

    function formatCriteria(obj, labels) {
        let out = [];
        const keys = Object.keys(obj || {});
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i];
            const v = obj[k];
            if (v === undefined || v === null || v === "")
                continue;
            const label = labels[k] || k;
            if (typeof v === "boolean")
                out.push(label + ": " + (v ? I18n.tr("Yes") : I18n.tr("No")));
            else
                out.push(label + ": " + v);
        }
        return out;
    }

    function matchSummary(rule) {
        const matches = matchesOf(rule);
        const first = matches[0] || {};
        const label = first.appId || first.title || I18n.tr("Any window");
        if (matches.length > 1)
            return I18n.tr("%1 (+%2 more)").arg(label).arg(matches.length - 1);
        return label;
    }

    readonly property var actionLabels: ({
            "opacity": I18n.tr("Opacity"),
            "openFloating": I18n.tr("Float"),
            "openMaximized": I18n.tr("Maximize"),
            "openMaximizedToEdges": I18n.tr("Max Edges"),
            "openFullscreen": I18n.tr("Fullscreen"),
            "openFocused": I18n.tr("Focus"),
            "openOnOutput": I18n.tr("Output"),
            "openOnWorkspace": I18n.tr("Workspace"),
            "defaultColumnWidth": I18n.tr("Width"),
            "defaultWindowHeight": I18n.tr("Height"),
            "variableRefreshRate": I18n.tr("VRR"),
            "blockOutFrom": I18n.tr("Block Out"),
            "defaultColumnDisplay": I18n.tr("Display"),
            "scrollFactor": I18n.tr("Scroll"),
            "cornerRadius": I18n.tr("Radius"),
            "clipToGeometry": I18n.tr("Clip"),
            "tiledState": I18n.tr("Tiled"),
            "minWidth": I18n.tr("Min W"),
            "maxWidth": I18n.tr("Max W"),
            "minHeight": I18n.tr("Min H"),
            "maxHeight": I18n.tr("Max H"),
            "tile": I18n.tr("Tile"),
            "nofocus": I18n.tr("No Focus"),
            "noborder": I18n.tr("No Border"),
            "noshadow": I18n.tr("No Shadow"),
            "nodim": I18n.tr("No Dim"),
            "noblur": I18n.tr("No Blur"),
            "noanim": I18n.tr("No Anim"),
            "norounding": I18n.tr("No Round"),
            "pin": I18n.tr("Pin"),
            "opaque": I18n.tr("Opaque"),
            "size": I18n.tr("Size"),
            "move": I18n.tr("Move"),
            "monitor": I18n.tr("Monitor"),
            "workspace": I18n.tr("Workspace"),
            "drawBorderWithBackground": I18n.tr("Border w/ Bg"),
            "backgroundBlur": I18n.tr("Blur"),
            "backgroundXray": I18n.tr("X-Ray"),
            "backgroundNoise": I18n.tr("Noise"),
            "backgroundSaturation": I18n.tr("Saturation"),
            "defaultFloatingX": I18n.tr("Float X"),
            "defaultFloatingY": I18n.tr("Float Y"),
            "defaultFloatingRelativeTo": I18n.tr("Float Anchor"),
            "borderColor": I18n.tr("Border Color"),
            "focusRingColor": I18n.tr("Focus Ring Color"),
            "focusRingOff": I18n.tr("Focus Ring Off"),
            "borderOff": I18n.tr("Border Off"),
            "forcergbx": I18n.tr("Force RGBX"),
            "idleinhibit": I18n.tr("Idle Inhibit")
        })

    signal rulesChanged

    function getActiveWindows() {
        const toplevels = ToplevelManager.toplevels?.values || [];
        return toplevels.map(t => ({
                    appId: t.appId || "",
                    title: t.title || ""
                }));
    }

    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() {
            root.activeWindows = root.getActiveWindows();
        }
    }

    function getWindowRulesConfigPaths() {
        const configDir = Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation));
        switch (CompositorService.compositor) {
        case "niri":
            return {
                "configFile": configDir + "/niri/config.kdl",
                "rulesFile": configDir + "/niri/dms/windowrules.kdl",
                "grepPattern": 'include.*"dms/windowrules.kdl"',
                "includeLine": 'include "dms/windowrules.kdl"'
            };
        case "hyprland":
            return {
                "configFile": configDir + "/hypr/hyprland.lua",
                "rulesFile": configDir + "/hypr/dms/windowrules.lua",
                "grepPattern": "dms.windowrules",
                "includeLine": "require(\"dms.windowrules\")"
            };
        case "mango":
            return {
                "configFile": configDir + "/mango/config.conf",
                "rulesFile": configDir + "/mango/dms/windowrules.conf",
                "grepPattern": "dms/windowrules.conf",
                "includeLine": "source=./dms/windowrules.conf"
            };
        default:
            return null;
        }
    }

    function loadWindowRules() {
        const compositor = CompositorService.compositor;
        if (compositor !== "niri" && compositor !== "hyprland" && compositor !== "mango") {
            checkingInclude = false;
            windowRules = [];
            externalRules = [];
            return;
        }

        checkingInclude = true;
        Proc.runCommand("load-windowrules", ["dms", "config", "windowrules", "list", compositor], (output, exitCode) => {
            checkingInclude = false;
            if (exitCode !== 0) {
                windowRules = [];
                externalRules = [];
                return;
            }
            try {
                const result = JSON.parse(output.trim());
                const allRules = result.rules || [];
                windowRules = allRules.filter(r => (r.source || "").includes("dms/windowrules"));
                externalRules = allRules.filter(r => !(r.source || "").includes("dms/windowrules"));
                if (result.dmsStatus) {
                    windowRulesIncludeStatus = {
                        "exists": result.dmsStatus.exists,
                        "included": result.dmsStatus.included,
                        "configFormat": result.dmsStatus.configFormat ?? "",
                        "readOnly": result.dmsStatus.readOnly === true
                    };
                }
            } catch (e) {
                windowRules = [];
                externalRules = [];
            }
        });
    }

    function removeRule(ruleId) {
        if (readOnly) {
            showHyprlandReadOnlyWarning();
            return;
        }
        const compositor = CompositorService.compositor;
        if (compositor !== "niri" && compositor !== "hyprland" && compositor !== "mango")
            return;

        Proc.runCommand("remove-windowrule", ["dms", "config", "windowrules", "remove", compositor, ruleId], (output, exitCode) => {
            if (exitCode === 0) {
                if (CompositorService.isMango)
                    MangoService.reloadConfig();
                loadWindowRules();
                rulesChanged();
            }
        });
    }

    function reorderRules(fromIndex, toIndex) {
        if (readOnly) {
            showHyprlandReadOnlyWarning();
            return;
        }
        if (fromIndex === toIndex)
            return;

        const compositor = CompositorService.compositor;
        if (compositor !== "niri" && compositor !== "hyprland" && compositor !== "mango")
            return;

        let ids = windowRules.map(r => r.id);
        const [moved] = ids.splice(fromIndex, 1);
        ids.splice(toIndex, 0, moved);

        Proc.runCommand("reorder-windowrules", ["dms", "config", "windowrules", "reorder", compositor, JSON.stringify(ids)], (output, exitCode) => {
            if (exitCode === 0) {
                if (CompositorService.isMango)
                    MangoService.reloadConfig();
                loadWindowRules();
                rulesChanged();
            }
        });
    }

    function fixWindowRulesInclude() {
        if (readOnly) {
            showHyprlandReadOnlyWarning();
            return;
        }
        const paths = getWindowRulesConfigPaths();
        if (!paths)
            return;
        fixingInclude = true;
        const unixTime = Math.floor(Date.now() / 1000);
        const backupFile = paths.configFile + ".backup" + unixTime;
        const script = ConfigIncludeResolve.buildRepairScript({
            configFile: paths.configFile,
            backupFile: backupFile,
            fragmentFile: paths.rulesFile,
            grepPattern: paths.grepPattern,
            includeLine: paths.includeLine
        });
        Proc.runCommand("fix-windowrules-include", ["sh", "-c", script], (output, exitCode) => {
            fixingInclude = false;
            if (exitCode !== 0)
                return;
            if (CompositorService.isMango)
                MangoService.reloadConfig();
            loadWindowRules();
        });
    }

    function openRuleModal(window) {
        if (readOnly) {
            showHyprlandReadOnlyWarning();
            return;
        }
        if (!PopoutService.windowRuleModalLoader)
            return;
        PopoutService.windowRuleModalLoader.active = true;
        if (PopoutService.windowRuleModalLoader.item) {
            PopoutService.windowRuleModalLoader.item.onRuleSubmitted.connect(loadWindowRules);
            PopoutService.windowRuleModalLoader.item.show(window || null);
        }
    }

    function editRule(rule) {
        if (readOnly) {
            showHyprlandReadOnlyWarning();
            return;
        }
        if (!PopoutService.windowRuleModalLoader)
            return;
        PopoutService.windowRuleModalLoader.active = true;
        if (PopoutService.windowRuleModalLoader.item) {
            PopoutService.windowRuleModalLoader.item.onRuleSubmitted.connect(loadWindowRules);
            PopoutService.windowRuleModalLoader.item.showEdit(rule);
        }
    }

    function copyRuleToDms(rule) {
        if (readOnly) {
            showHyprlandReadOnlyWarning();
            return;
        }
        if (!PopoutService.windowRuleModalLoader)
            return;
        PopoutService.windowRuleModalLoader.active = true;
        if (PopoutService.windowRuleModalLoader.item) {
            PopoutService.windowRuleModalLoader.item.onRuleSubmitted.connect(loadWindowRules);
            PopoutService.windowRuleModalLoader.item.showCopy(rule);
        }
    }

    function showHyprlandReadOnlyWarning() {
        ToastService.showWarning(I18n.tr("Hyprland conf mode"), I18n.tr("This install is still using hyprland.conf. Run dms setup to migrate before editing window rules in Settings."), "dms setup", "hyprland-migration");
    }

    Component.onCompleted: {
        componentReady = true;
        Qt.callLater(() => {
            SettingsSearchService.registerCard("windowRules", headerSection, flickable);
            if (CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango)
                loadWindowRules();
        });
    }

    DankFlickable {
        id: flickable
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight

        Column {
            id: contentColumn
            width: flickable.width
            spacing: Theme.spacingL
            topPadding: Theme.spacingXL
            bottomPadding: Theme.spacingXL

            StyledRect {
                width: Math.min(650, parent.width - Theme.spacingL * 2)
                height: headerSection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh

                Column {
                    id: headerSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "select_window"
                            size: Theme.iconSize
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Window Rules")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: I18n.tr("Define rules for window behavior. Saves to %1").arg(root.dmsRulesFileName)
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        DankActionButton {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            circular: false
                            iconName: "add"
                            iconSize: Theme.iconSize
                            iconColor: Theme.primary
                            enabled: !root.readOnly
                            opacity: enabled ? 1 : 0.5
                            tooltipText: I18n.tr("Add Window Rule")
                            tooltipSide: "left"
                            onClicked: root.openRuleModal()
                        }
                    }

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM
                        visible: root.activeWindows.length > 0

                        StyledText {
                            text: I18n.tr("Create rule for:")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            Layout.alignment: Qt.AlignVCenter
                        }

                        DankDropdown {
                            id: windowSelector
                            Layout.fillWidth: true
                            dropdownWidth: 400
                            compactMode: true
                            emptyText: I18n.tr("Select a window...")
                            options: root.activeWindows.map(w => {
                                const label = w.appId + (w.title ? " - " + w.title : "");
                                return label.length > 60 ? label.substring(0, 57) + "..." : label;
                            })
                            onValueChanged: value => {
                                if (!value)
                                    return;
                                const index = options.indexOf(value);
                                if (index < 0 || index >= root.activeWindows.length)
                                    return;
                                const window = root.activeWindows[index];
                                root.openRuleModal(window);
                                currentValue = "";
                            }
                        }
                    }
                }
            }

            StyledRect {
                id: warningBox
                width: Math.min(650, parent.width - Theme.spacingL * 2)
                height: warningSection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius

                readonly property bool showLegacy: root.readOnly
                readonly property bool showSetup: !showLegacy && !root.windowRulesIncludeStatus.included

                color: (showLegacy || showSetup) ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.primary, 0)
                border.color: (showLegacy || showSetup) ? Theme.withAlpha(Theme.primary, 0.3) : Theme.withAlpha(Theme.primary, 0)
                border.width: 1
                visible: (showLegacy || showSetup) && !root.checkingInclude && (CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango)

                Row {
                    id: warningSection
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
                            text: warningBox.showLegacy ? I18n.tr("Hyprland conf mode") : I18n.tr("First Time Setup")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.primary
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        StyledText {
                            text: warningBox.showLegacy ? I18n.tr("This install is still using hyprland.conf. Run dms setup to migrate before editing window rules in Settings.") : I18n.tr("Click 'Setup' to create %1 and add include to your compositor config.").arg("dms/windowrules")
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
                        onClicked: root.fixWindowRulesInclude()
                    }
                }
            }

            StyledRect {
                width: Math.min(650, parent.width - Theme.spacingL * 2)
                height: rulesSection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh

                Column {
                    id: rulesSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "list"
                            size: Theme.iconSize
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: I18n.tr("Rules (%1)").arg(root.windowRules?.length ?? 0)
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            Layout.fillWidth: true
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: !root.windowRules || root.windowRules.length === 0

                        Item {
                            width: 1
                            height: Theme.spacingM
                        }

                        DankIcon {
                            name: "select_window"
                            size: 40
                            color: Theme.surfaceVariantText
                            anchors.horizontalCenter: parent.horizontalCenter
                            opacity: 0.5
                        }

                        StyledText {
                            text: I18n.tr("No window rules configured")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Item {
                            width: 1
                            height: Theme.spacingM
                        }
                    }

                    Column {
                        id: rulesListColumn
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: root.windowRules && root.windowRules.length > 0

                        Repeater {
                            model: ScriptModel {
                                objectProp: "id"
                                values: root.windowRules || []
                            }

                            delegate: Item {
                                id: ruleDelegateItem
                                required property var modelData
                                required property int index

                                property bool held: ruleDragArea.pressed
                                property real originalY: y

                                readonly property string ruleIdRef: modelData.id
                                readonly property var liveRuleData: {
                                    const rules = root.windowRules || [];
                                    return rules.find(r => r.id === ruleIdRef) ?? modelData;
                                }
                                readonly property string displayName: {
                                    const name = liveRuleData.name || "";
                                    if (name)
                                        return name;
                                    const m = liveRuleData.matchCriteria || {};
                                    return m.appId || m.title || I18n.tr("Unnamed Rule");
                                }

                                width: rulesListColumn.width
                                height: ruleCard.height
                                z: held ? 2 : 1

                                Rectangle {
                                    id: ruleCard
                                    width: parent.width
                                    height: ruleContent.implicitHeight + Theme.spacingM * 2
                                    radius: Theme.cornerRadius
                                    color: ruleDelegateItem.liveRuleData.enabled !== false ? Theme.surfaceContainer : Theme.withAlpha(Theme.surfaceContainer, 0.4)

                                    RowLayout {
                                        id: ruleContent
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingM
                                        anchors.leftMargin: 28
                                        spacing: Theme.spacingM

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            StyledText {
                                                text: ruleDelegateItem.displayName
                                                font.pixelSize: Theme.fontSizeMedium
                                                font.weight: Font.Medium
                                                color: ruleDelegateItem.liveRuleData.enabled !== false ? Theme.surfaceText : Theme.surfaceVariantText
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            StyledText {
                                                text: {
                                                    const m = ruleDelegateItem.liveRuleData.matchCriteria || {};
                                                    let parts = [];
                                                    if (m.appId)
                                                        parts.push(m.appId);
                                                    if (m.title)
                                                        parts.push("title: " + m.title);
                                                    return parts.length > 0 ? parts.join(" · ") : I18n.tr("No match criteria");
                                                }
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Flow {
                                                Layout.fillWidth: true
                                                Layout.topMargin: 4
                                                spacing: Theme.spacingXS
                                                visible: {
                                                    const a = ruleDelegateItem.liveRuleData.actions || {};
                                                    return Object.keys(a).some(k => a[k] !== undefined && a[k] !== null && a[k] !== "");
                                                }

                                                Repeater {
                                                    model: {
                                                        const a = ruleDelegateItem.liveRuleData.actions || {};
                                                        const labels = root.actionLabels;
                                                        return Object.keys(a).filter(k => a[k] !== undefined && a[k] !== null && a[k] !== "").map(k => {
                                                            const val = a[k];
                                                            if (typeof val === "boolean")
                                                                return val ? (labels[k] || k) : (labels[k] || k) + ": " + I18n.tr("Off");
                                                            return (labels[k] || k) + ": " + val;
                                                        });
                                                    }

                                                    delegate: Rectangle {
                                                        required property string modelData
                                                        width: chipText.implicitWidth + Theme.spacingS * 2
                                                        height: 20
                                                        radius: 10
                                                        color: Theme.withAlpha(Theme.primary, 0.15)

                                                        StyledText {
                                                            id: chipText
                                                            anchors.centerIn: parent
                                                            text: modelData
                                                            font.pixelSize: Theme.fontSizeSmall - 2
                                                            color: Theme.primary
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        RowLayout {
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 2

                                            DankActionButton {
                                                buttonSize: 28
                                                iconName: "edit"
                                                iconSize: 16
                                                backgroundColor: "transparent"
                                                iconColor: Theme.surfaceVariantText
                                                enabled: !root.readOnly
                                                opacity: enabled ? 1 : 0.5
                                                tooltipText: I18n.tr("Edit Rule")
                                                tooltipSide: "top"
                                                onClicked: root.editRule(ruleDelegateItem.liveRuleData)
                                            }

                                            DankActionButton {
                                                id: deleteBtn
                                                property bool hovered: false
                                                buttonSize: 28
                                                iconName: "delete"
                                                iconSize: 16
                                                backgroundColor: "transparent"
                                                iconColor: hovered ? Theme.error : Theme.surfaceVariantText
                                                enabled: !root.readOnly
                                                opacity: enabled ? 1 : 0.5
                                                tooltipText: I18n.tr("Delete Rule")
                                                tooltipSide: "top"
                                                onEntered: hovered = true
                                                onExited: hovered = false
                                                onClicked: root.removeRule(ruleDelegateItem.ruleIdRef)
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: ruleDragArea
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    width: 40
                                    height: ruleCard.height
                                    hoverEnabled: true
                                    cursorShape: root.readOnly ? Qt.ArrowCursor : Qt.SizeVerCursor
                                    drag.target: !root.readOnly && ruleDelegateItem.held ? ruleDelegateItem : undefined
                                    drag.axis: Drag.YAxis
                                    preventStealing: true

                                    onPressed: {
                                        ruleDelegateItem.z = 2;
                                        ruleDelegateItem.originalY = ruleDelegateItem.y;
                                    }
                                    onReleased: {
                                        ruleDelegateItem.z = 1;
                                        if (!drag.active) {
                                            ruleDelegateItem.y = ruleDelegateItem.originalY;
                                            return;
                                        }
                                        const spacing = Theme.spacingXS;
                                        const itemH = ruleDelegateItem.height + spacing;
                                        var newIndex = Math.round(ruleDelegateItem.y / itemH);
                                        newIndex = Math.max(0, Math.min(newIndex, (root.windowRules?.length ?? 1) - 1));
                                        if (newIndex !== ruleDelegateItem.index)
                                            root.reorderRules(ruleDelegateItem.index, newIndex);
                                        ruleDelegateItem.y = ruleDelegateItem.originalY;
                                    }
                                }

                                DankIcon {
                                    x: Theme.spacingM - 2
                                    y: (ruleCard.height / 2) - (size / 2)
                                    name: "drag_indicator"
                                    size: 18
                                    color: Theme.outline
                                    opacity: ruleDragArea.containsMouse || ruleDragArea.pressed ? 1 : 0.5
                                }

                                Behavior on y {
                                    enabled: !ruleDragArea.pressed && !ruleDragArea.drag.active
                                    NumberAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Theme.standardEasing
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                width: Math.min(650, parent.width - Theme.spacingL * 2)
                height: externalSection.implicitHeight + Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                visible: root.externalRules && root.externalRules.length > 0

                Column {
                    id: externalSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "description"
                            size: Theme.iconSize
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("User Window Rules (%1)").arg(root.externalRules?.length ?? 0)
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: I18n.tr("Rules found in your compositor config. These are read-only here, use Convert to DMS to make an editable copy.")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS

                        Repeater {
                            model: ScriptModel {
                                objectProp: "id"
                                values: root.externalRules || []
                            }

                            delegate: Rectangle {
                                id: externalCard
                                required property var modelData

                                readonly property string displayName: {
                                    const name = externalCard.modelData.name || "";
                                    if (name)
                                        return name;
                                    return root.matchSummary(externalCard.modelData);
                                }
                                readonly property string sourceFile: (externalCard.modelData.source || "").split("/").pop()
                                readonly property bool expanded: root.expandedExternalId === externalCard.modelData.id

                                width: parent.width
                                height: externalContent.implicitHeight + Theme.spacingM * 2
                                radius: Theme.cornerRadius
                                color: Theme.withAlpha(Theme.surfaceContainer, 0.4)

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.expandedExternalId = externalCard.expanded ? "" : externalCard.modelData.id
                                }

                                Column {
                                    id: externalContent
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingS

                                    RowLayout {
                                        width: parent.width
                                        spacing: Theme.spacingM

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: Theme.spacingS

                                                StyledText {
                                                    text: externalCard.displayName
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    font.weight: Font.Medium
                                                    color: Theme.surfaceText
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                Rectangle {
                                                    visible: externalCard.sourceFile.length > 0
                                                    width: sourceText.implicitWidth + Theme.spacingS * 2
                                                    height: 20
                                                    radius: 10
                                                    color: Theme.withAlpha(Theme.surfaceVariantText, 0.15)
                                                    Layout.alignment: Qt.AlignVCenter

                                                    StyledText {
                                                        id: sourceText
                                                        anchors.centerIn: parent
                                                        text: externalCard.sourceFile
                                                        font.pixelSize: Theme.fontSizeSmall - 2
                                                        color: Theme.surfaceVariantText
                                                    }
                                                }
                                            }

                                            StyledText {
                                                text: {
                                                    const m = externalCard.modelData.matchCriteria || {};
                                                    let parts = [];
                                                    if (m.appId)
                                                        parts.push(m.appId);
                                                    if (m.title)
                                                        parts.push("title: " + m.title);
                                                    const base = parts.length > 0 ? parts.join(" · ") : I18n.tr("No match criteria");
                                                    const count = root.matchesOf(externalCard.modelData).length;
                                                    return count > 1 ? I18n.tr("%1 (+%2 more)").arg(base).arg(count - 1) : base;
                                                }
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Flow {
                                                Layout.fillWidth: true
                                                Layout.topMargin: 4
                                                spacing: Theme.spacingXS
                                                visible: {
                                                    const a = externalCard.modelData.actions || {};
                                                    return Object.keys(a).some(k => a[k] !== undefined && a[k] !== null && a[k] !== "");
                                                }

                                                Repeater {
                                                    model: {
                                                        const a = externalCard.modelData.actions || {};
                                                        const labels = root.actionLabels;
                                                        return Object.keys(a).filter(k => a[k] !== undefined && a[k] !== null && a[k] !== "").map(k => {
                                                            const val = a[k];
                                                            if (typeof val === "boolean")
                                                                return val ? (labels[k] || k) : (labels[k] || k) + ": " + I18n.tr("Off");
                                                            return (labels[k] || k) + ": " + val;
                                                        });
                                                    }

                                                    delegate: Rectangle {
                                                        required property string modelData
                                                        width: extChipText.implicitWidth + Theme.spacingS * 2
                                                        height: 20
                                                        radius: 10
                                                        color: Theme.withAlpha(Theme.primary, 0.15)

                                                        StyledText {
                                                            id: extChipText
                                                            anchors.centerIn: parent
                                                            text: modelData
                                                            font.pixelSize: Theme.fontSizeSmall - 2
                                                            color: Theme.primary
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        DankIcon {
                                            name: externalCard.expanded ? "expand_less" : "expand_more"
                                            size: 20
                                            color: Theme.surfaceVariantText
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        DankActionButton {
                                            buttonSize: 28
                                            iconName: "content_copy"
                                            iconSize: 16
                                            backgroundColor: "transparent"
                                            iconColor: Theme.surfaceVariantText
                                            enabled: !root.readOnly
                                            opacity: enabled ? 1 : 0.5
                                            Layout.alignment: Qt.AlignVCenter
                                            tooltipText: I18n.tr("Convert to DMS")
                                            tooltipSide: "left"
                                            onClicked: root.copyRuleToDms(externalCard.modelData)
                                        }
                                    }

                                    Column {
                                        width: parent.width
                                        spacing: Theme.spacingXS
                                        visible: externalCard.expanded

                                        Rectangle {
                                            width: parent.width
                                            height: 1
                                            color: Theme.withAlpha(Theme.outline, 0.5)
                                        }

                                        StyledText {
                                            text: I18n.tr("Match (%1)").arg(root.matchesOf(externalCard.modelData).length)
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                        }

                                        Repeater {
                                            model: root.matchesOf(externalCard.modelData)

                                            delegate: StyledText {
                                                required property var modelData
                                                width: parent.width
                                                text: {
                                                    const c = root.formatCriteria(modelData, root.matchLabels);
                                                    return "• " + (c.length > 0 ? c.join("   ·   ") : I18n.tr("Any window"));
                                                }
                                                font.pixelSize: Theme.fontSizeSmall
                                                color: Theme.surfaceVariantText
                                                wrapMode: Text.WordWrap
                                            }
                                        }

                                        StyledText {
                                            text: I18n.tr("Actions")
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                            topPadding: Theme.spacingXS
                                        }

                                        StyledText {
                                            width: parent.width
                                            text: {
                                                const a = root.formatCriteria(externalCard.modelData.actions, root.actionLabels);
                                                return a.length > 0 ? a.join("   ·   ") : I18n.tr("None");
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            wrapMode: Text.WordWrap
                                        }

                                        StyledText {
                                            width: parent.width
                                            text: I18n.tr("Source: %1").arg(externalCard.modelData.source || "")
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: Theme.surfaceVariantText
                                            elide: Text.ElideMiddle
                                            topPadding: Theme.spacingXS
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
