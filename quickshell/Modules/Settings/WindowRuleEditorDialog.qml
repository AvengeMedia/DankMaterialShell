pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

DankDialog {
    id: root

    property var editingRule: null
    property var targetWindow: null
    property bool submitting: false
    readonly property bool isEditMode: editingRule !== null
    readonly property bool isNiri: CompositorService.isNiri
    readonly property bool isHyprland: CompositorService.isHyprland
    readonly property bool isMango: CompositorService.isMango
    readonly property bool fieldsEnabled: !submitting
    readonly property bool halfPair: isHyprland && (!!moveXInput.text.trim() !== !!moveYInput.text.trim() || !!sizeWInput.text.trim() !== !!sizeHInput.text.trim())

    property int floatingTri: 0
    property var openingFlags: []
    property var dynamicFlags: []
    property var hyprFlags: []
    property var mangoFlags: []
    property bool opacityOn: false
    property int opacityValue: 100
    property bool scrollFactorOn: false
    property int scrollFactorValue: 100
    property bool cornerRadiusOn: false
    property int cornerRadiusValue: 12
    property bool noiseOn: false
    property int noiseValue: 5
    property bool saturationOn: false
    property int saturationValue: 100
    property string blockOutValue: ""
    property string columnDisplayValue: ""
    property string floatingRelativeValue: "top-left"

    readonly property var triLabels: [I18n.tr("Default"), I18n.tr("On"), I18n.tr("Off")]
    readonly property var blockOutOptions: ["", "screencast", "screen-capture"]
    readonly property var columnDisplayOptions: ["", "tabbed"]
    readonly property var anchorOptions: ["top-left", "top-right", "bottom-left", "bottom-right", "top", "bottom", "left", "right"]
    readonly property var openingOptions: {
        const options = [];
        if (!isNiri)
            options.push({
                "label": I18n.tr("Float"),
                "value": "float"
            });
        if (!isMango)
            options.push({
                "label": I18n.tr("Maximize", "verb, window rule action to open the window maximized"),
                "value": "maximize"
            });
        options.push({
            "label": I18n.tr("Fullscreen", "window rule action, open the window fullscreen"),
            "value": "fullscreen"
        });
        if (isNiri) {
            options.push({
                "label": I18n.tr("Max edges", "window rule action, open maximized to screen edges"),
                "value": "maxEdges"
            });
            options.push({
                "label": I18n.tr("Focus", "verb, window rule action to focus the window when it opens"),
                "value": "focus"
            });
        }
        return options;
    }
    readonly property var dynamicOptions: [
        {
            "label": I18n.tr("VRR On-Demand"),
            "value": "vrr"
        },
        {
            "label": I18n.tr("Clip to Geometry"),
            "value": "clip"
        },
        {
            "label": I18n.tr("Tiled State"),
            "value": "tiled"
        },
        {
            "label": I18n.tr("Border with Background"),
            "value": "borderBg"
        }
    ]
    readonly property var hyprOptions: [
        {
            "label": I18n.tr("Tile"),
            "value": "tile"
        },
        {
            "label": I18n.tr("No focus"),
            "value": "nofocus"
        },
        {
            "label": I18n.tr("No border"),
            "value": "noborder"
        },
        {
            "label": I18n.tr("No shadow"),
            "value": "noshadow"
        },
        {
            "label": I18n.tr("No dim"),
            "value": "nodim"
        },
        {
            "label": I18n.tr("No blur"),
            "value": "noblur"
        },
        {
            "label": I18n.tr("No anim"),
            "value": "noanim"
        },
        {
            "label": I18n.tr("No Rounding"),
            "value": "norounding"
        },
        {
            "label": I18n.tr("Pin", "verb, keep an item pinned in place"),
            "value": "pin"
        },
        {
            "label": I18n.tr("Opaque", "adjective, window rule checkbox forcing an opaque window"),
            "value": "opaque"
        }
    ]
    readonly property var mangoOptions: [
        {
            "label": I18n.tr("No blur"),
            "value": "noblur"
        },
        {
            "label": I18n.tr("No border"),
            "value": "noborder"
        },
        {
            "label": I18n.tr("No shadow"),
            "value": "noshadow"
        },
        {
            "label": I18n.tr("No Rounding"),
            "value": "norounding"
        },
        {
            "label": I18n.tr("No anim"),
            "value": "noanim"
        }
    ]

    signal ruleSubmitted

    embedded: nativeWindow
    opened: nativeWindow
    maximumWidth: SettingsMetrics.formDialogWidth
    surfaceColor: Theme.hostSurface
    title: isEditMode ? I18n.tr("Edit Window Rule") : I18n.tr("New Window Rule")
    closeEnabled: !submitting
    acceptEnabled: !submitting && !halfPair
    onAccepted: submit()

    ListModel {
        id: extraMatchModel
    }

    function show(window) {
        editingRule = null;
        targetWindow = window || null;
        resetForm();
        if (targetWindow?.appId) {
            nameInput.text = targetWindow.appId;
            appIdInput.text = isMango ? targetWindow.appId : "^" + targetWindow.appId + "$";
        }
        present();
    }

    function showEdit(rule) {
        if (!rule) {
            show();
            return;
        }
        editingRule = rule;
        targetWindow = null;
        resetForm();
        populateForm(rule);
        present();
    }

    function showCopy(rule) {
        if (!rule) {
            show();
            return;
        }
        editingRule = null;
        targetWindow = null;
        resetForm();
        populateForm(rule);
        present();
    }

    function present() {
        opened = true;
        forceActiveFocus();
        nameInput.forceActiveFocus();
    }

    function flagSet(flags, value, checked) {
        const next = flags.filter(flag => flag !== value);
        if (checked)
            next.push(value);
        return next;
    }

    function triFromBool(value) {
        if (value === true)
            return 1;
        if (value === false)
            return 2;
        return 0;
    }

    function applyCond(target, key, triState) {
        if (triState === 1)
            target[key] = true;
        else if (triState === 2)
            target[key] = false;
    }

    function blockOutLabel(value) {
        return value === "" ? I18n.tr("None") : value;
    }

    function columnDisplayLabel(value) {
        return value === "" ? I18n.tr("Normal") : value;
    }

    function resetForm() {
        nameInput.text = "";
        appIdInput.text = "";
        titleInput.text = "";
        extraMatchModel.clear();
        for (const cond of matchConditions)
            cond.triState = 0;
        floatingTri = 0;
        openingFlags = [];
        dynamicFlags = [];
        hyprFlags = [];
        mangoFlags = [];
        opacityOn = false;
        opacityValue = 100;
        scrollFactorOn = false;
        scrollFactorValue = 100;
        cornerRadiusOn = false;
        cornerRadiusValue = 12;
        noiseOn = false;
        noiseValue = 5;
        saturationOn = false;
        saturationValue = 100;
        blockOutValue = "";
        columnDisplayValue = "";
        floatingRelativeValue = "top-left";
        blurCond.triState = 0;
        xrayCond.triState = 0;
        for (const field of [outputInput, workspaceInput, columnWidthInput, windowHeightInput, floatingXInput, floatingYInput, minWidthInput, maxWidthInput, minHeightInput, maxHeightInput, moveXInput, moveYInput, sizeWInput, sizeHInput, monitorInput, hyprWorkspaceInput, mangoTagsInput, mangoMonitorInput, mangoSizeInput])
            field.text = "";
    }

    function populateForm(rule) {
        nameInput.text = rule.name || "";
        const matchList = (rule.matches && rule.matches.length > 0) ? rule.matches : [rule.matchCriteria || {}];
        const match = matchList[0] || {};
        appIdInput.text = match.appId || "";
        titleInput.text = match.title || "";
        for (let i = 1; i < matchList.length; i++)
            extraMatchModel.append({
                "rowAppId": matchList[i].appId || "",
                "rowTitle": matchList[i].title || ""
            });
        for (const cond of matchConditions)
            cond.triState = triFromBool(match[cond.key]);

        const actions = rule.actions || {};
        const flags = [];
        if (!isNiri && actions.openFloating)
            flags.push("float");
        if (actions.openMaximized)
            flags.push("maximize");
        if (actions.openFullscreen)
            flags.push("fullscreen");
        if (actions.openMaximizedToEdges)
            flags.push("maxEdges");
        if (actions.openFocused)
            flags.push("focus");
        openingFlags = flags;
        floatingTri = triFromBool(actions.openFloating);

        const dynamic = [];
        if (actions.variableRefreshRate)
            dynamic.push("vrr");
        if (actions.clipToGeometry)
            dynamic.push("clip");
        if (actions.tiledState)
            dynamic.push("tiled");
        if (actions.drawBorderWithBackground)
            dynamic.push("borderBg");
        dynamicFlags = dynamic;

        opacityOn = actions.opacity !== undefined && actions.opacity !== null;
        opacityValue = opacityOn ? Math.round(actions.opacity * 100) : 100;
        scrollFactorOn = actions.scrollFactor !== undefined && actions.scrollFactor !== null;
        scrollFactorValue = scrollFactorOn ? Math.round(actions.scrollFactor * 100) : 100;
        cornerRadiusOn = actions.cornerRadius !== undefined && actions.cornerRadius !== null;
        cornerRadiusValue = cornerRadiusOn ? actions.cornerRadius : 12;
        noiseOn = actions.backgroundNoise !== undefined && actions.backgroundNoise !== null;
        noiseValue = noiseOn ? Math.round(actions.backgroundNoise * 100) : 5;
        saturationOn = actions.backgroundSaturation !== undefined && actions.backgroundSaturation !== null;
        saturationValue = saturationOn ? Math.round(actions.backgroundSaturation * 100) : 100;
        blockOutValue = actions.blockOutFrom || "";
        columnDisplayValue = actions.defaultColumnDisplay || "";
        blurCond.triState = triFromBool(actions.backgroundBlur);
        xrayCond.triState = triFromBool(actions.backgroundXray);

        outputInput.text = actions.openOnOutput || "";
        workspaceInput.text = actions.openOnWorkspace || "";
        columnWidthInput.text = actions.defaultColumnWidth || "";
        windowHeightInput.text = actions.defaultWindowHeight || "";
        floatingXInput.text = (actions.defaultFloatingX !== undefined && actions.defaultFloatingX !== null) ? String(actions.defaultFloatingX) : "";
        floatingYInput.text = (actions.defaultFloatingY !== undefined && actions.defaultFloatingY !== null) ? String(actions.defaultFloatingY) : "";
        floatingRelativeValue = actions.defaultFloatingRelativeTo || "top-left";
        minWidthInput.text = actions.minWidth !== undefined ? String(actions.minWidth) : "";
        maxWidthInput.text = actions.maxWidth !== undefined ? String(actions.maxWidth) : "";
        minHeightInput.text = actions.minHeight !== undefined ? String(actions.minHeight) : "";
        maxHeightInput.text = actions.maxHeight !== undefined ? String(actions.maxHeight) : "";

        hyprFlags = hyprOptions.map(option => option.value).filter(value => actions[value]);
        moveXInput.text = actions.moveX || "";
        moveYInput.text = actions.moveY || "";
        sizeWInput.text = actions.sizeWidth || "";
        sizeHInput.text = actions.sizeHeight || "";
        monitorInput.text = actions.monitor || "";
        hyprWorkspaceInput.text = actions.workspace || "";

        mangoFlags = mangoOptions.map(option => option.value).filter(value => actions[value]);
        mangoTagsInput.text = actions.workspace || "";
        mangoMonitorInput.text = actions.monitor || "";
        mangoSizeInput.text = (actions.sizeWidth && actions.sizeHeight) ? actions.sizeWidth + "x" + actions.sizeHeight : "";
    }

    function collectMatches() {
        const matchCriteria = {};
        if (appIdInput.text.trim())
            matchCriteria.appId = appIdInput.text.trim();
        if (titleInput.text.trim())
            matchCriteria.title = titleInput.text.trim();
        for (const cond of matchConditions) {
            if (cond.visible)
                applyCond(matchCriteria, cond.key, cond.triState);
        }
        const matches = [];
        if (Object.keys(matchCriteria).length > 0)
            matches.push(matchCriteria);
        if (!isNiri)
            return {
                matchCriteria,
                matches
            };
        for (let i = 0; i < extraMatchModel.count; i++) {
            const row = extraMatchModel.get(i);
            const extra = {};
            if ((row.rowAppId || "").trim())
                extra.appId = row.rowAppId.trim();
            if ((row.rowTitle || "").trim())
                extra.title = row.rowTitle.trim();
            if (Object.keys(extra).length > 0)
                matches.push(extra);
        }
        return {
            matchCriteria,
            matches
        };
    }

    function collectActions() {
        const actions = {};
        const has = value => openingFlags.includes(value);
        if (opacityOn)
            actions.opacity = opacityValue / 100;
        if (isNiri)
            applyCond(actions, "openFloating", floatingTri);
        else if (has("float"))
            actions.openFloating = true;
        if (has("maximize"))
            actions.openMaximized = true;
        if (has("maxEdges") && isNiri)
            actions.openMaximizedToEdges = true;
        if (has("fullscreen"))
            actions.openFullscreen = true;
        if (has("focus") && isNiri)
            actions.openFocused = true;
        if (isNiri && outputInput.text.trim())
            actions.openOnOutput = outputInput.text.trim();
        if (isNiri && workspaceInput.text.trim())
            actions.openOnWorkspace = workspaceInput.text.trim();
        if (cornerRadiusOn)
            actions.cornerRadius = cornerRadiusValue;

        const minW = parseInt(minWidthInput.text);
        const maxW = parseInt(maxWidthInput.text);
        const minH = parseInt(minHeightInput.text);
        const maxH = parseInt(maxHeightInput.text);
        if (isNiri) {
            if (!isNaN(minW))
                actions.minWidth = minW;
            if (!isNaN(maxW))
                actions.maxWidth = maxW;
            if (!isNaN(minH))
                actions.minHeight = minH;
            if (!isNaN(maxH))
                actions.maxHeight = maxH;
        }

        if (isNiri) {
            if (columnWidthInput.text.trim())
                actions.defaultColumnWidth = columnWidthInput.text.trim();
            if (windowHeightInput.text.trim())
                actions.defaultWindowHeight = windowHeightInput.text.trim();
            if (dynamicFlags.includes("vrr"))
                actions.variableRefreshRate = true;
            if (dynamicFlags.includes("clip"))
                actions.clipToGeometry = true;
            if (dynamicFlags.includes("tiled"))
                actions.tiledState = true;
            if (dynamicFlags.includes("borderBg"))
                actions.drawBorderWithBackground = true;
            if (blockOutValue)
                actions.blockOutFrom = blockOutValue;
            if (columnDisplayValue)
                actions.defaultColumnDisplay = columnDisplayValue;
            if (scrollFactorOn)
                actions.scrollFactor = scrollFactorValue / 100;
            applyCond(actions, "backgroundBlur", blurCond.triState);
            applyCond(actions, "backgroundXray", xrayCond.triState);
            if (noiseOn)
                actions.backgroundNoise = noiseValue / 100;
            if (saturationOn)
                actions.backgroundSaturation = saturationValue / 100;
            const floatX = parseInt(floatingXInput.text);
            const floatY = parseInt(floatingYInput.text);
            if (!isNaN(floatX) && !isNaN(floatY)) {
                actions.defaultFloatingX = floatX;
                actions.defaultFloatingY = floatY;
                if (floatingRelativeValue !== "top-left")
                    actions.defaultFloatingRelativeTo = floatingRelativeValue;
            }
        }

        if (isHyprland) {
            for (const flag of hyprFlags)
                actions[flag] = true;
            if (sizeWInput.text.trim())
                actions.sizeWidth = sizeWInput.text.trim();
            if (sizeHInput.text.trim())
                actions.sizeHeight = sizeHInput.text.trim();
            if (moveXInput.text.trim())
                actions.moveX = moveXInput.text.trim();
            if (moveYInput.text.trim())
                actions.moveY = moveYInput.text.trim();
            if (monitorInput.text.trim())
                actions.monitor = monitorInput.text.trim();
            if (hyprWorkspaceInput.text.trim())
                actions.workspace = hyprWorkspaceInput.text.trim();
        }

        if (isMango) {
            for (const flag of mangoFlags)
                actions[flag] = true;
            if (mangoTagsInput.text.trim())
                actions.workspace = mangoTagsInput.text.trim();
            if (mangoMonitorInput.text.trim())
                actions.monitor = mangoMonitorInput.text.trim();
            const parts = mangoSizeInput.text.trim().split(/x/i);
            if (mangoSizeInput.text.trim() && parts.length === 2) {
                actions.sizeWidth = parts[0].trim();
                actions.sizeHeight = parts[1].trim();
            }
        }
        return actions;
    }

    function submit() {
        if (submitting || !acceptEnabled)
            return;
        const {
            matchCriteria,
            matches
        } = collectMatches();
        const ruleData = {
            name: nameInput.text.trim() || matchCriteria.appId || I18n.tr("Rule", "noun, fallback name for an unnamed window rule"),
            matchCriteria: matchCriteria,
            actions: collectActions(),
            enabled: true
        };
        if (isNiri && extraMatchModel.count > 0)
            ruleData.matches = matches;
        // No exclude editor yet; carry existing excludes through so an edit doesn't delete them (#2996)
        if (isEditMode && (editingRule.excludes?.length ?? 0) > 0)
            ruleData.excludes = editingRule.excludes;

        const compositor = CompositorService.compositor;
        const ruleJson = JSON.stringify(ruleData);
        const args = isEditMode ? [Proc.dmsBin, "config", "windowrules", "update", compositor, editingRule.id, ruleJson] : [Proc.dmsBin, "config", "windowrules", "add", compositor, ruleJson];
        submitting = true;
        Proc.runCommand(isEditMode ? "update-windowrule" : "add-windowrule", args, (output, exitCode) => {
            root.submitting = false;
            if (exitCode !== 0)
                return;
            CompositorService.reloadAfterWindowRuleWrite();
            root.ruleSubmitted();
        });
    }

    component MatchCond: StyledButton {
        id: mc

        property string label: ""
        property string key: ""
        property int triState: 0
        property string unsetLabel: I18n.tr("Default")
        readonly property var stateText: [mc.unsetLabel, "true", "false"]
        readonly property var stateColor: [Theme.surfaceVariantText, Theme.primary, Theme.error]

        width: condRow.implicitWidth + Theme.spacingM * 2
        height: Theme.buttonHeightXS
        radius: Theme.cornerRadiusS
        color: enabled ? Theme.chipSurface : Theme.onSurface_12
        border.width: Theme.outlineWidth
        border.color: !enabled ? "transparent" : mc.triState === 0 ? Theme.outlineVariant : mc.stateColor[mc.triState]
        enabled: root.fieldsEnabled
        Accessible.role: Accessible.Button
        Accessible.name: label + ": " + stateText[triState]
        onClicked: triState = (triState + 1) % 3

        Row {
            id: condRow
            anchors.centerIn: parent
            spacing: Theme.spacingXS

            StyledText {
                text: mc.label
                font.pixelSize: Theme.fontSizeSmall
                color: mc.enabled ? Theme.onSurface : Theme.onSurface_38
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: stateBadge.implicitWidth + Theme.spacingS * 2
                height: stateBadge.implicitHeight + Theme.spacingXXS * 2
                radius: Theme.fullRadius(width, height)
                color: mc.enabled ? Theme.withAlpha(mc.stateColor[mc.triState], Theme.stateLayerPressed) : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    id: stateBadge
                    anchors.centerIn: parent
                    text: mc.stateText[mc.triState]
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: mc.enabled ? mc.stateColor[mc.triState] : Theme.onSurface_38
                }
            }
        }

        StateLayer {
            control: mc
            disabled: !mc.enabled
            stateColor: Theme.primary
        }

        FocusRing {
            visible: mc.visualFocus
        }
    }

    component FieldRow: SettingsRow {
        default property alias fields: fieldRow.data

        body: Row {
            id: fieldRow
            width: parent.width
            spacing: Theme.spacingS
        }
    }

    component Field: DankTextField {
        property int share: 1
        property int shares: 2

        width: Math.round((parent.width - parent.spacing * (shares - 1)) * share / shares)
        outlined: true
        enabled: root.fieldsEnabled
        onAccepted: root.submit()
    }

    readonly property var matchConditions: [condFloating, condActive, condFocused, condActiveInColumn, condCastTarget, condUrgent, condAtStartup, condXwayland, condFullscreen, condPinned]

    actions: [
        DankButton {
            text: I18n.tr("Cancel")
            enabled: root.closeEnabled
            backgroundColor: "transparent"
            textColor: Theme.primary
            onClicked: root.rejected()
        },
        DankButton {
            text: root.isEditMode ? I18n.tr("Save") : I18n.tr("Add")
            enabled: root.acceptEnabled
            busy: root.submitting
            onClicked: root.submit()
        }
    ]

    SettingsGroup {
        SettingsRow {
            body: DankTextField {
                id: nameInput
                width: parent.width
                outlined: true
                leftIconName: "edit"
                labelText: I18n.tr("Rule Name")
                enabled: root.fieldsEnabled
                onAccepted: root.submit()
            }
        }
    }

    SettingsCard {
        title: I18n.tr("Match Criteria")
        headerActions: DankButton {
            visible: root.isNiri
            text: I18n.tr("Add match")
            iconName: "add"
            buttonHeight: Theme.buttonHeightXS
            backgroundColor: "transparent"
            textColor: Theme.primary
            enabled: root.fieldsEnabled
            onClicked: extraMatchModel.append({
                "rowAppId": "",
                "rowTitle": ""
            })
        }

        SettingsRow {
            visible: root.isNiri
            subtitle: I18n.tr("The rule applies to any window matching one of these.")
        }

        SettingsRow {
            body: DankTextField {
                id: appIdInput
                width: parent.width
                outlined: true
                leftIconName: "apps"
                labelText: root.isMango ? I18n.tr("App ID (e.g. firefox)") : root.isHyprland ? I18n.tr("Class regex (e.g. ^firefox$)") : I18n.tr("App ID regex (e.g. ^firefox$)")
                enabled: root.fieldsEnabled
                onAccepted: root.submit()
            }
        }

        FieldRow {
            Field {
                id: titleInput
                width: parent.width - (addTitle.visible ? addTitle.width + parent.spacing : 0)
                leftIconName: "title"
                labelText: root.isMango ? I18n.tr("Title (optional)") : I18n.tr("Title regex (optional)")
            }

            DankActionButton {
                id: addTitle
                anchors.verticalCenter: parent.verticalCenter
                iconName: "add"
                visible: !root.isEditMode && !!root.targetWindow?.title
                tooltipText: I18n.tr("Add Title")
                onClicked: titleInput.text = root.isMango ? root.targetWindow.title : "^" + root.targetWindow.title + "$"
            }
        }

        Repeater {
            model: extraMatchModel

            delegate: FieldRow {
                id: extraRow

                required property int index
                required property string rowAppId
                required property string rowTitle

                Field {
                    width: Math.round((parent.width - parent.spacing * 2 - removeMatch.width) / 2)
                    leftIconName: "apps"
                    labelText: I18n.tr("App ID regex")
                    text: extraRow.rowAppId
                    onTextEdited: extraMatchModel.setProperty(extraRow.index, "rowAppId", text)
                }

                Field {
                    width: Math.round((parent.width - parent.spacing * 2 - removeMatch.width) / 2)
                    leftIconName: "title"
                    labelText: I18n.tr("Title regex (optional)")
                    text: extraRow.rowTitle
                    onTextEdited: extraMatchModel.setProperty(extraRow.index, "rowTitle", text)
                }

                DankActionButton {
                    id: removeMatch
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "close"
                    Accessible.name: I18n.tr("Remove match")
                    onClicked: extraMatchModel.remove(extraRow.index)
                }
            }
        }
    }

    SettingsCard {
        title: I18n.tr("Match Conditions")
        visible: root.isNiri || root.isHyprland

        SettingsRow {
            subtitle: I18n.tr("Optional state-based conditions applied to the first match.")
        }

        SettingsRow {
            body: Flow {
                width: parent.width
                spacing: Theme.spacingS

                MatchCond {
                    id: condFloating
                    key: "isFloating"
                    label: I18n.tr("Floating", "adjective, window rule match condition for floating windows")
                }
                MatchCond {
                    id: condActive
                    key: "isActive"
                    label: I18n.tr("Active")
                    visible: root.isNiri
                }
                MatchCond {
                    id: condFocused
                    key: "isFocused"
                    label: I18n.tr("Focused", "adjective, window rule match condition for the focused window")
                    visible: root.isNiri
                }
                MatchCond {
                    id: condActiveInColumn
                    key: "isActiveInColumn"
                    label: I18n.tr("Active in column")
                    visible: root.isNiri
                }
                MatchCond {
                    id: condCastTarget
                    key: "isWindowCastTarget"
                    label: I18n.tr("Cast target")
                    visible: root.isNiri
                }
                MatchCond {
                    id: condUrgent
                    key: "isUrgent"
                    label: I18n.tr("Urgent", "adjective, window rule match condition for windows requesting attention")
                    visible: root.isNiri
                }
                MatchCond {
                    id: condAtStartup
                    key: "atStartup"
                    label: I18n.tr("At startup")
                    visible: root.isNiri
                }
                MatchCond {
                    id: condXwayland
                    key: "xwayland"
                    label: "XWayland"
                    visible: root.isHyprland
                }
                MatchCond {
                    id: condFullscreen
                    key: "fullscreen"
                    label: I18n.tr("Fullscreen", "adjective, window rule match condition for fullscreen windows")
                    visible: root.isHyprland
                }
                MatchCond {
                    id: condPinned
                    key: "pinned"
                    label: I18n.tr("Pinned", "adjective, state of a pinned window, clipboard entry or item")
                    visible: root.isHyprland
                }
            }
        }
    }

    SettingsCard {
        title: I18n.tr("Window Opening")

        SettingsButtonGroupRow {
            visible: root.isNiri
            text: I18n.tr("Float")
            model: root.triLabels
            currentIndex: root.floatingTri
            enabled: root.fieldsEnabled
            onSelectionChanged: (index, selected) => {
                if (selected)
                    root.floatingTri = index;
            }
        }

        SettingsRow {
            body: DankFilterChips {
                width: parent.width
                multiSelect: true
                showCounts: false
                enabled: root.fieldsEnabled
                model: root.openingOptions
                selectedValues: root.openingFlags
                onSelectionToggled: (index, selected) => root.openingFlags = root.flagSet(root.openingFlags, root.openingOptions[index].value, selected)
            }
        }

        FieldRow {
            visible: root.isNiri

            Field {
                id: outputInput
                leftIconName: "monitor"
                labelText: I18n.tr("Output", "noun, display output a window opens on, window rule field")
                placeholderText: "HDMI-A-1"
            }

            Field {
                id: workspaceInput
                leftIconName: "view_module"
                labelText: I18n.tr("Workspace")
                placeholderText: "chat"
            }
        }

        FieldRow {
            visible: root.isNiri

            Field {
                id: columnWidthInput
                leftIconName: "width"
                labelText: I18n.tr("Column Width")
                placeholderText: "800"
            }

            Field {
                id: windowHeightInput
                leftIconName: "height"
                labelText: I18n.tr("Window Height")
                placeholderText: "600"
            }
        }
    }

    SettingsCard {
        title: I18n.tr("Dynamic Properties")
        visible: root.isNiri || root.isHyprland

        SettingsToggleRow {
            text: I18n.tr("Opacity")
            checked: root.opacityOn
            enabled: root.fieldsEnabled
            onToggled: checked => root.opacityOn = checked
        }

        SettingsSliderRow {
            visible: root.opacityOn
            text: I18n.tr("Opacity")
            value: root.opacityValue
            minimum: 10
            unit: "%"
            enabled: root.fieldsEnabled
            onSliderValueChanged: newValue => root.opacityValue = newValue
        }

        SettingsToggleRow {
            text: I18n.tr("Corner radius")
            checked: root.cornerRadiusOn
            enabled: root.fieldsEnabled
            onToggled: checked => root.cornerRadiusOn = checked
        }

        SettingsSliderRow {
            visible: root.cornerRadiusOn
            text: I18n.tr("Corner radius")
            value: root.cornerRadiusValue
            maximum: 24
            unit: "px"
            enabled: root.fieldsEnabled
            onSliderValueChanged: newValue => root.cornerRadiusValue = newValue
        }

        SettingsToggleRow {
            visible: root.isNiri
            text: I18n.tr("Scroll Factor")
            checked: root.scrollFactorOn
            enabled: root.fieldsEnabled
            onToggled: checked => root.scrollFactorOn = checked
        }

        SettingsSliderRow {
            visible: root.isNiri && root.scrollFactorOn
            text: I18n.tr("Scroll Factor")
            value: root.scrollFactorValue
            minimum: 10
            maximum: 200
            unit: "%"
            enabled: root.fieldsEnabled
            onSliderValueChanged: newValue => root.scrollFactorValue = newValue
        }

        SettingsRow {
            visible: root.isNiri

            body: DankFilterChips {
                width: parent.width
                multiSelect: true
                showCounts: false
                enabled: root.fieldsEnabled
                model: root.dynamicOptions
                selectedValues: root.dynamicFlags
                onSelectionToggled: (index, selected) => root.dynamicFlags = root.flagSet(root.dynamicFlags, root.dynamicOptions[index].value, selected)
            }
        }

        SettingsDropdownRow {
            visible: root.isNiri
            text: I18n.tr("Block Out From")
            options: root.blockOutOptions.map(root.blockOutLabel)
            currentValue: root.blockOutLabel(root.blockOutValue)
            enabled: root.fieldsEnabled
            onValueChanged: value => root.blockOutValue = root.blockOutOptions.find(option => root.blockOutLabel(option) === value) ?? ""
        }

        SettingsDropdownRow {
            visible: root.isNiri
            text: I18n.tr("Column Display")
            options: root.columnDisplayOptions.map(root.columnDisplayLabel)
            currentValue: root.columnDisplayLabel(root.columnDisplayValue)
            enabled: root.fieldsEnabled
            onValueChanged: value => root.columnDisplayValue = root.columnDisplayOptions.find(option => root.columnDisplayLabel(option) === value) ?? ""
        }
    }

    SettingsCard {
        title: I18n.tr("Background Effect")
        visible: root.isNiri

        SettingsRow {
            subtitle: I18n.tr("Xray blurs only the wallpaper (efficient) and is the default when Blur is on. Set Xray to Off for regular full blur of everything beneath the window (more expensive).")
        }

        SettingsRow {
            body: Flow {
                width: parent.width
                spacing: Theme.spacingS

                MatchCond {
                    id: blurCond
                    label: I18n.tr("Blur", "noun, background blur effect option")
                    unsetLabel: I18n.tr("Inherit")
                }

                MatchCond {
                    id: xrayCond
                    label: I18n.tr("X-Ray", "window rule background xray effect option")
                    unsetLabel: I18n.tr("Inherit")
                }
            }
        }

        SettingsToggleRow {
            text: I18n.tr("Noise", "window rule background noise effect checkbox")
            checked: root.noiseOn
            enabled: root.fieldsEnabled
            onToggled: checked => root.noiseOn = checked
        }

        SettingsSliderRow {
            visible: root.noiseOn
            text: I18n.tr("Noise", "window rule background noise effect checkbox")
            value: root.noiseValue
            unit: "%"
            enabled: root.fieldsEnabled
            onSliderValueChanged: newValue => root.noiseValue = newValue
        }

        SettingsToggleRow {
            text: I18n.tr("Saturation", "window rule background color saturation checkbox")
            checked: root.saturationOn
            enabled: root.fieldsEnabled
            onToggled: checked => root.saturationOn = checked
        }

        SettingsSliderRow {
            visible: root.saturationOn
            text: I18n.tr("Saturation", "window rule background color saturation checkbox")
            value: root.saturationValue
            maximum: 200
            unit: "%"
            enabled: root.fieldsEnabled
            onSliderValueChanged: newValue => root.saturationValue = newValue
        }
    }

    SettingsCard {
        title: I18n.tr("Floating Position")
        visible: root.isNiri

        SettingsRow {
            subtitle: I18n.tr("Initial position for floating windows. Set both X and Y; anchor controls which corner/edge they're relative to.")
        }

        FieldRow {
            Field {
                id: floatingXInput
                leftIconName: "open_with"
                labelText: "X"
                placeholderText: "px"
            }

            Field {
                id: floatingYInput
                leftIconName: "open_with"
                labelText: "Y"
                placeholderText: "px"
            }
        }

        SettingsDropdownRow {
            text: I18n.tr("Anchor", "noun, screen corner or edge a floating window position is relative to")
            options: root.anchorOptions
            currentValue: root.floatingRelativeValue
            enabled: root.fieldsEnabled
            onValueChanged: value => root.floatingRelativeValue = value
        }
    }

    SettingsCard {
        title: I18n.tr("Size Constraints")
        visible: root.isNiri

        FieldRow {
            Field {
                id: minWidthInput
                leftIconName: "width"
                labelText: I18n.tr("Min W")
                placeholderText: "px"
            }

            Field {
                id: maxWidthInput
                leftIconName: "width"
                labelText: I18n.tr("Max W")
                placeholderText: "px"
            }
        }

        FieldRow {
            Field {
                id: minHeightInput
                leftIconName: "height"
                labelText: I18n.tr("Min H")
                placeholderText: "px"
            }

            Field {
                id: maxHeightInput
                leftIconName: "height"
                labelText: I18n.tr("Max H")
                placeholderText: "px"
            }
        }
    }

    SettingsCard {
        title: I18n.tr("Hyprland Options")
        visible: root.isHyprland

        SettingsRow {
            body: DankFilterChips {
                width: parent.width
                multiSelect: true
                showCounts: false
                enabled: root.fieldsEnabled
                model: root.hyprOptions
                selectedValues: root.hyprFlags
                onSelectionToggled: (index, selected) => root.hyprFlags = root.flagSet(root.hyprFlags, root.hyprOptions[index].value, selected)
            }
        }

        FieldRow {
            Field {
                id: moveXInput
                leftIconName: "open_with"
                labelText: "X"
                placeholderText: "0"
            }

            Field {
                id: moveYInput
                leftIconName: "open_with"
                labelText: "Y"
                placeholderText: "0"
            }
        }

        FieldRow {
            Field {
                id: sizeWInput
                leftIconName: "width"
                labelText: I18n.tr("W")
                placeholderText: "800"
            }

            Field {
                id: sizeHInput
                leftIconName: "height"
                labelText: I18n.tr("H", "abbreviation of height, window rule size field label")
                placeholderText: "600"
            }
        }

        FieldRow {
            Field {
                id: monitorInput
                leftIconName: "monitor"
                labelText: I18n.tr("Monitor", "noun, display output field in window rule editor")
                placeholderText: "DP-1"
            }

            Field {
                id: hyprWorkspaceInput
                leftIconName: "view_module"
                labelText: I18n.tr("Workspace")
                placeholderText: "1"
            }
        }
    }

    SettingsCard {
        title: I18n.tr("Mango Options")
        visible: root.isMango

        SettingsRow {
            body: DankFilterChips {
                width: parent.width
                multiSelect: true
                showCounts: false
                enabled: root.fieldsEnabled
                model: root.mangoOptions
                selectedValues: root.mangoFlags
                onSelectionToggled: (index, selected) => root.mangoFlags = root.flagSet(root.mangoFlags, root.mangoOptions[index].value, selected)
            }
        }

        FieldRow {
            Field {
                id: mangoTagsInput
                leftIconName: "view_module"
                labelText: I18n.tr("Tags", "noun, mango compositor workspace tags field in window rule editor")
                placeholderText: "1"
            }

            Field {
                id: mangoMonitorInput
                leftIconName: "monitor"
                labelText: I18n.tr("Monitor")
                placeholderText: "HDMI-A-1"
            }
        }

        FieldRow {
            Field {
                id: mangoSizeInput
                shares: 1
                leftIconName: "aspect_ratio"
                labelText: I18n.tr("Size")
                placeholderText: "800x600"
            }
        }
    }
}
