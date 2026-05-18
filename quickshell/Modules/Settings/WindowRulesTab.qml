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
    property var windowRulesIncludeStatus: ({
            "exists": false,
            "included": false
        })
    property bool checkingInclude: false
    property bool fixingInclude: false
    property var windowRules: []
    property var activeWindows: getActiveWindows()

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
        default:
            return null;
        }
    }

    function loadWindowRules() {
        const compositor = CompositorService.compositor;
        if (compositor !== "niri" && compositor !== "hyprland") {
            windowRules = [];
            return;
        }

        Proc.runCommand("load-windowrules", ["dms", "config", "windowrules", "list", compositor], (output, exitCode) => {
            if (exitCode !== 0) {
                windowRules = [];
                return;
            }
            try {
                const result = JSON.parse(output.trim());
                const allRules = result.rules || [];
                windowRules = allRules.filter(r => (r.source || "").includes("dms/windowrules"));
                if (result.dmsStatus) {
                    windowRulesIncludeStatus = {
                        "exists": result.dmsStatus.exists,
                        "included": result.dmsStatus.included
                    };
                }
            } catch (e) {
                windowRules = [];
            }
        });
    }

    function removeRule(ruleId) {
        const compositor = CompositorService.compositor;
        if (compositor !== "niri" && compositor !== "hyprland")
            return;

        Proc.runCommand("remove-windowrule", ["dms", "config", "windowrules", "remove", compositor, ruleId], (output, exitCode) => {
            if (exitCode === 0) {
                loadWindowRules();
                rulesChanged();
            }
        });
    }

    function reorderRules(fromIndex, toIndex) {
        if (fromIndex === toIndex)
            return;

        const compositor = CompositorService.compositor;
        if (compositor !== "niri" && compositor !== "hyprland")
            return;

        let ids = windowRules.map(r => r.id);
        const [moved] = ids.splice(fromIndex, 1);
        ids.splice(toIndex, 0, moved);

        Proc.runCommand("reorder-windowrules", ["dms", "config", "windowrules", "reorder", compositor, JSON.stringify(ids)], (output, exitCode) => {
            if (exitCode === 0) {
                loadWindowRules();
                rulesChanged();
            }
        });
    }

    function checkWindowRulesIncludeStatus() {
        const compositor = CompositorService.compositor;
        if (compositor !== "niri" && compositor !== "hyprland") {
            windowRulesIncludeStatus = {
                "exists": false,
                "included": false
            };
            return;
        }

        const filename = (compositor === "niri") ? "windowrules.kdl" : "windowrules.lua";
        checkingInclude = true;
        Proc.runCommand("check-windowrules-include", ["dms", "config", "resolve-include", compositor, filename], (output, exitCode) => {
            checkingInclude = false;
            if (exitCode !== 0) {
                windowRulesIncludeStatus = {
                    "exists": false,
                    "included": false
                };
                return;
            }
            try {
                windowRulesIncludeStatus = JSON.parse(output.trim());
            } catch (e) {
                windowRulesIncludeStatus = {
                    "exists": false,
                    "included": false
                };
            }
        });
    }

    function fixWindowRulesInclude() {
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
            checkWindowRulesIncludeStatus();
            loadWindowRules();
        });
    }

    function openRuleModal(window) {
        if (!PopoutService.windowRuleModalLoader)
            return;
        PopoutService.windowRuleModalLoader.active = true;
        if (PopoutService.windowRuleModalLoader.item) {
            PopoutService.windowRuleModalLoader.item.onRuleSubmitted.connect(loadWindowRules);
            PopoutService.windowRuleModalLoader.item.show(window || null);
        }
    }

    function editRule(rule) {
        if (!PopoutService.windowRuleModalLoader)
            return;
        PopoutService.windowRuleModalLoader.active = true;
        if (PopoutService.windowRuleModalLoader.item) {
            PopoutService.windowRuleModalLoader.item.onRuleSubmitted.connect(loadWindowRules);
            PopoutService.windowRuleModalLoader.item.showEdit(rule);
        }
    }

    Component.onCompleted: {
        if (CompositorService.isNiri || CompositorService.isHyprland) {
            checkWindowRulesIncludeStatus();
            loadWindowRules();
        }
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
                                text: I18n.tr("Define rules for window behavior. Saves to %1").arg(CompositorService.isNiri ? "dms/windowrules.kdl" : "dms/windowrules.lua")
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

                readonly property bool showError: root.windowRulesIncludeStatus.exists && !root.windowRulesIncludeStatus.included
                readonly property bool showSetup: !root.windowRulesIncludeStatus.exists && !root.windowRulesIncludeStatus.included

                color: (showError || showSetup) ? Theme.withAlpha(Theme.warning, 0.15) : "transparent"
                border.color: (showError || showSetup) ? Theme.withAlpha(Theme.warning, 0.3) : "transparent"
                border.width: 1
                visible: (showError || showSetup) && !root.checkingInclude && (CompositorService.isNiri || CompositorService.isHyprland)

                Row {
                    id: warningSection
                    anchors.fill: parent
                    anchors.margins: Theme.spacingL
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "warning"
                        size: Theme.iconSize
                        color: Theme.warning
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - Theme.iconSize - (fixButton.visible ? fixButton.width + Theme.spacingM : 0) - Theme.spacingM
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: warningBox.showSetup ? I18n.tr("Window Rules Not Configured") : I18n.tr("Window Rules Include Missing")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.warning
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        StyledText {
                            readonly property string rulesFile: CompositorService.isNiri ? "dms/windowrules.kdl" : "dms/windowrules.lua"
                            text: warningBox.showSetup ? I18n.tr("Click 'Setup' to create %1 and add include to your compositor config.").arg(rulesFile) : I18n.tr("%1 exists but is not included. Window rules won't apply.").arg(rulesFile)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }
                    }

                    DankButton {
                        id: fixButton
                        visible: warningBox.showError || warningBox.showSetup
                        text: root.fixingInclude ? I18n.tr("Fixing...") : (warningBox.showSetup ? I18n.tr("Setup") : I18n.tr("Fix Now"))
                        backgroundColor: Theme.warning
                        textColor: Theme.background
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
                                                        const labels = {
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
                                                            "workspace": I18n.tr("Workspace")
                                                        };
                                                        return Object.keys(a).filter(k => a[k] !== undefined && a[k] !== null && a[k] !== "").map(k => {
                                                            const val = a[k];
                                                            if (typeof val === "boolean")
                                                                return labels[k] || k;
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
                                                onClicked: root.editRule(ruleDelegateItem.liveRuleData)
                                            }

                                            DankActionButton {
                                                id: deleteBtn
                                                buttonSize: 28
                                                iconName: "delete"
                                                iconSize: 16
                                                backgroundColor: "transparent"
                                                iconColor: deleteArea.containsMouse ? Theme.error : Theme.surfaceVariantText

                                                MouseArea {
                                                    id: deleteArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.removeRule(ruleDelegateItem.ruleIdRef)
                                                }
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
                                    cursorShape: Qt.SizeVerCursor
                                    drag.target: ruleDelegateItem.held ? ruleDelegateItem : undefined
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
        }
    }
}
