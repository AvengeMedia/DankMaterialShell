import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankFloatingWindow {
    id: root

    property var editingRule: null
    property bool isEditMode: editingRule !== null
    property bool isNiri: CompositorService.isNiri
    property bool isHyprland: CompositorService.isHyprland
    property bool isMango: CompositorService.isMango
    property bool submitting: false
    property var targetWindow: null

    signal ruleSubmitted

    readonly property int inputFieldHeight: Theme.fontSizeMedium + Theme.spacingL * 2
    readonly property int sectionSpacing: Theme.spacingL

    ListModel {
        id: extraMatchModel
    }

    objectName: "windowRuleModal"
    title: isEditMode ? I18n.tr("Edit Window Rule") : I18n.tr("Create Window Rule")
    minimumSize: Qt.size(500, 600)
    maximumSize: Qt.size(500, 600)
    visible: false

    onClosed: hide()

    function resetForm() {
        nameInput.text = "";
        appIdInput.text = "";
        titleInput.text = "";
        extraMatchModel.clear();
        condFloating.triState = 0;
        condActive.triState = 0;
        condFocused.triState = 0;
        condActiveInColumn.triState = 0;
        condCastTarget.triState = 0;
        condUrgent.triState = 0;
        condAtStartup.triState = 0;
        condXwayland.triState = 0;
        condFullscreen.triState = 0;
        condPinned.triState = 0;
        condInitialised.triState = 0;
        opacityEnabled.checked = false;
        opacitySlider.value = 100;
        floatingCond.triState = 0;
        floatingToggle.checked = false;
        maximizedToggle.checked = false;
        maximizedToEdgesToggle.checked = false;
        fullscreenToggle.checked = false;
        openFocusedToggle.checked = false;
        outputInput.text = "";
        workspaceInput.text = "";
        columnWidthInput.text = "";
        windowHeightInput.text = "";
        vrrToggle.checked = false;
        blockOutDropdown.currentValue = "";
        columnDisplayDropdown.currentValue = "";
        scrollFactorEnabled.checked = false;
        scrollFactorSlider.value = 100;
        cornerRadiusEnabled.checked = false;
        cornerRadiusSlider.value = 12;
        clipToGeometryToggle.checked = false;
        tiledStateToggle.checked = false;
        drawBorderBgToggle.checked = false;
        blurCond.triState = 0;
        xrayCond.triState = 0;
        noiseEnabled.checked = false;
        noiseSlider.value = 5;
        saturationEnabled.checked = false;
        saturationSlider.value = 100;
        floatingXInput.text = "";
        floatingYInput.text = "";
        floatingRelativeDropdown.currentValue = "top-left";
        minWidthInput.text = "";
        maxWidthInput.text = "";
        minHeightInput.text = "";
        maxHeightInput.text = "";
        tileToggle.checked = false;
        noFocusToggle.checked = false;
        noBorderToggle.checked = false;
        noShadowToggle.checked = false;
        noDimToggle.checked = false;
        noBlurToggle.checked = false;
        noAnimToggle.checked = false;
        noRoundingToggle.checked = false;
        pinToggle.checked = false;
        opaqueToggle.checked = false;
        moveXInput.text = "";
        moveYInput.text = "";
        sizeWInput.text = "";
        sizeHInput.text = "";
        monitorInput.text = "";
        hyprWorkspaceInput.text = "";
        mangoTagsInput.text = "";
        mangoMonitorInput.text = "";
        mangoSizeInput.text = "";
        mangoNoBlurToggle.checked = false;
        mangoNoBorderToggle.checked = false;
        mangoNoShadowToggle.checked = false;
        mangoNoRoundingToggle.checked = false;
        mangoNoAnimToggle.checked = false;
    }

    function show(window) {
        editingRule = null;
        targetWindow = window || null;
        resetForm();
        if (targetWindow) {
            nameInput.text = targetWindow.appId || "";
            if (targetWindow.appId)
                appIdInput.text = isMango ? targetWindow.appId : "^" + targetWindow.appId + "$";
            else
                appIdInput.text = "";
        }
        visible = true;
        Qt.callLater(() => nameInput.forceActiveFocus());
    }

    function triFromBool(v) {
        if (v === true)
            return 1;
        if (v === false)
            return 2;
        return 0;
    }

    function populateForm(rule) {
        nameInput.text = rule.name || "";
        const matchList = (rule.matches && rule.matches.length > 0) ? rule.matches : [rule.matchCriteria || {}];
        const match = matchList[0] || {};
        appIdInput.text = match.appId || "";
        titleInput.text = match.title || "";
        extraMatchModel.clear();
        for (let i = 1; i < matchList.length; i++) {
            extraMatchModel.append({
                "rowAppId": matchList[i].appId || "",
                "rowTitle": matchList[i].title || ""
            });
        }

        condFloating.triState = triFromBool(match.isFloating);
        condActive.triState = triFromBool(match.isActive);
        condFocused.triState = triFromBool(match.isFocused);
        condActiveInColumn.triState = triFromBool(match.isActiveInColumn);
        condCastTarget.triState = triFromBool(match.isWindowCastTarget);
        condUrgent.triState = triFromBool(match.isUrgent);
        condAtStartup.triState = triFromBool(match.atStartup);
        condXwayland.triState = triFromBool(match.xwayland);
        condFullscreen.triState = triFromBool(match.fullscreen);
        condPinned.triState = triFromBool(match.pinned);
        condInitialised.triState = triFromBool(match.initialised);

        const actions = rule.actions || {};
        const hasOpacity = actions.opacity !== undefined && actions.opacity !== null;
        opacityEnabled.checked = hasOpacity;
        opacitySlider.value = hasOpacity ? Math.round(actions.opacity * 100) : 100;

        floatingCond.triState = triFromBool(actions.openFloating);
        floatingToggle.checked = actions.openFloating || false;
        maximizedToggle.checked = actions.openMaximized || false;
        maximizedToEdgesToggle.checked = actions.openMaximizedToEdges || false;
        fullscreenToggle.checked = actions.openFullscreen || false;

        openFocusedToggle.checked = actions.openFocused || false;

        outputInput.text = actions.openOnOutput || "";
        workspaceInput.text = actions.openOnWorkspace || "";
        columnWidthInput.text = actions.defaultColumnWidth || "";
        windowHeightInput.text = actions.defaultWindowHeight || "";
        vrrToggle.checked = actions.variableRefreshRate || false;

        blockOutDropdown.currentValue = actions.blockOutFrom || "";
        columnDisplayDropdown.currentValue = actions.defaultColumnDisplay || "";

        const hasScrollFactor = actions.scrollFactor !== undefined && actions.scrollFactor !== null;
        scrollFactorEnabled.checked = hasScrollFactor;
        scrollFactorSlider.value = hasScrollFactor ? Math.round(actions.scrollFactor * 100) : 100;

        const hasCornerRadius = actions.cornerRadius !== undefined && actions.cornerRadius !== null;
        cornerRadiusEnabled.checked = hasCornerRadius;
        cornerRadiusSlider.value = hasCornerRadius ? actions.cornerRadius : 12;

        clipToGeometryToggle.checked = actions.clipToGeometry || false;
        tiledStateToggle.checked = actions.tiledState || false;

        drawBorderBgToggle.checked = actions.drawBorderWithBackground || false;

        xrayCond.triState = triFromBool(actions.backgroundXray);
        blurCond.triState = triFromBool(actions.backgroundBlur);
        const hasNoise = actions.backgroundNoise !== undefined && actions.backgroundNoise !== null;
        noiseEnabled.checked = hasNoise;
        noiseSlider.value = hasNoise ? Math.round(actions.backgroundNoise * 100) : 5;
        const hasSaturation = actions.backgroundSaturation !== undefined && actions.backgroundSaturation !== null;
        saturationEnabled.checked = hasSaturation;
        saturationSlider.value = hasSaturation ? Math.round(actions.backgroundSaturation * 100) : 100;

        floatingXInput.text = (actions.defaultFloatingX !== undefined && actions.defaultFloatingX !== null) ? String(actions.defaultFloatingX) : "";
        floatingYInput.text = (actions.defaultFloatingY !== undefined && actions.defaultFloatingY !== null) ? String(actions.defaultFloatingY) : "";
        floatingRelativeDropdown.currentValue = actions.defaultFloatingRelativeTo || "top-left";

        minWidthInput.text = actions.minWidth !== undefined ? String(actions.minWidth) : "";
        maxWidthInput.text = actions.maxWidth !== undefined ? String(actions.maxWidth) : "";
        minHeightInput.text = actions.minHeight !== undefined ? String(actions.minHeight) : "";
        maxHeightInput.text = actions.maxHeight !== undefined ? String(actions.maxHeight) : "";

        tileToggle.checked = actions.tile || false;
        noFocusToggle.checked = actions.nofocus || false;
        noBorderToggle.checked = actions.noborder || false;
        noShadowToggle.checked = actions.noshadow || false;
        noDimToggle.checked = actions.nodim || false;
        noBlurToggle.checked = actions.noblur || false;
        noAnimToggle.checked = actions.noanim || false;
        noRoundingToggle.checked = actions.norounding || false;
        pinToggle.checked = actions.pin || false;
        opaqueToggle.checked = actions.opaque || false;
        moveXInput.text = actions.moveX || "";
        moveYInput.text = actions.moveY || "";
        sizeWInput.text = actions.sizeWidth || "";
        sizeHInput.text = actions.sizeHeight || "";
        monitorInput.text = actions.monitor || "";
        hyprWorkspaceInput.text = actions.workspace || "";

        mangoTagsInput.text = actions.workspace || "";
        mangoMonitorInput.text = actions.monitor || "";
        mangoSizeInput.text = (actions.sizeWidth && actions.sizeHeight) ? actions.sizeWidth + "x" + actions.sizeHeight : "";
        mangoNoBlurToggle.checked = actions.noblur || false;
        mangoNoBorderToggle.checked = actions.noborder || false;
        mangoNoShadowToggle.checked = actions.noshadow || false;
        mangoNoRoundingToggle.checked = actions.norounding || false;
        mangoNoAnimToggle.checked = actions.noanim || false;
    }

    function showEdit(rule) {
        if (!rule) {
            show();
            return;
        }
        editingRule = rule;
        resetForm();
        populateForm(rule);
        visible = true;
        Qt.callLater(() => nameInput.forceActiveFocus());
    }

    function showCopy(rule) {
        if (!rule) {
            show();
            return;
        }
        editingRule = null;
        resetForm();
        populateForm(rule);
        visible = true;
        Qt.callLater(() => nameInput.forceActiveFocus());
    }

    function hide() {
        visible = false;
        editingRule = null;
        targetWindow = null;
    }

    function applyCond(obj, key, triState) {
        if (triState === 1)
            obj[key] = true;
        else if (triState === 2)
            obj[key] = false;
    }

    function submitAndClose() {
        if (submitting)
            return;
        const matchCriteria = {};
        if (appIdInput.text.trim())
            matchCriteria.appId = appIdInput.text.trim();
        if (titleInput.text.trim())
            matchCriteria.title = titleInput.text.trim();

        applyCond(matchCriteria, "isFloating", condFloating.triState);
        if (isNiri) {
            applyCond(matchCriteria, "isActive", condActive.triState);
            applyCond(matchCriteria, "isFocused", condFocused.triState);
            applyCond(matchCriteria, "isActiveInColumn", condActiveInColumn.triState);
            applyCond(matchCriteria, "isWindowCastTarget", condCastTarget.triState);
            applyCond(matchCriteria, "isUrgent", condUrgent.triState);
            applyCond(matchCriteria, "atStartup", condAtStartup.triState);
        }
        if (isHyprland) {
            applyCond(matchCriteria, "xwayland", condXwayland.triState);
            applyCond(matchCriteria, "fullscreen", condFullscreen.triState);
            applyCond(matchCriteria, "pinned", condPinned.triState);
            applyCond(matchCriteria, "initialised", condInitialised.triState);
        }

        const matches = [];
        if (Object.keys(matchCriteria).length > 0)
            matches.push(matchCriteria);
        if (isNiri) {
            for (let i = 0; i < extraMatchModel.count; i++) {
                const row = extraMatchModel.get(i);
                const m = {};
                if ((row.rowAppId || "").trim())
                    m.appId = row.rowAppId.trim();
                if ((row.rowTitle || "").trim())
                    m.title = row.rowTitle.trim();
                if (Object.keys(m).length > 0)
                    matches.push(m);
            }
        }

        const actions = {};

        if (opacityEnabled.checked)
            actions.opacity = opacitySlider.value / 100;
        if (isNiri)
            applyCond(actions, "openFloating", floatingCond.triState);
        else if (floatingToggle.checked)
            actions.openFloating = true;
        if (maximizedToggle.checked)
            actions.openMaximized = true;
        if (maximizedToEdgesToggle.checked && isNiri)
            actions.openMaximizedToEdges = true;
        if (fullscreenToggle.checked)
            actions.openFullscreen = true;
        if (openFocusedToggle.checked && isNiri)
            actions.openFocused = true;
        if (outputInput.text.trim())
            actions.openOnOutput = outputInput.text.trim();
        if (workspaceInput.text.trim())
            actions.openOnWorkspace = workspaceInput.text.trim();
        if (columnWidthInput.text.trim() && isNiri)
            actions.defaultColumnWidth = columnWidthInput.text.trim();
        if (windowHeightInput.text.trim() && isNiri)
            actions.defaultWindowHeight = windowHeightInput.text.trim();
        if (vrrToggle.checked && isNiri)
            actions.variableRefreshRate = true;
        if (blockOutDropdown.currentValue && isNiri)
            actions.blockOutFrom = blockOutDropdown.currentValue;
        if (columnDisplayDropdown.currentValue && isNiri)
            actions.defaultColumnDisplay = columnDisplayDropdown.currentValue;
        if (scrollFactorEnabled.checked && isNiri)
            actions.scrollFactor = scrollFactorSlider.value / 100;
        if (cornerRadiusEnabled.checked)
            actions.cornerRadius = cornerRadiusSlider.value;
        if (clipToGeometryToggle.checked && isNiri)
            actions.clipToGeometry = true;
        if (tiledStateToggle.checked && isNiri)
            actions.tiledState = true;
        if (drawBorderBgToggle.checked && isNiri)
            actions.drawBorderWithBackground = true;
        if (isNiri) {
            applyCond(actions, "backgroundBlur", blurCond.triState);
            applyCond(actions, "backgroundXray", xrayCond.triState);
        }
        if (noiseEnabled.checked && isNiri)
            actions.backgroundNoise = noiseSlider.value / 100;
        if (saturationEnabled.checked && isNiri)
            actions.backgroundSaturation = saturationSlider.value / 100;

        const floatX = parseInt(floatingXInput.text);
        const floatY = parseInt(floatingYInput.text);
        if (isNiri && !isNaN(floatX) && !isNaN(floatY)) {
            actions.defaultFloatingX = floatX;
            actions.defaultFloatingY = floatY;
            if (floatingRelativeDropdown.currentValue && floatingRelativeDropdown.currentValue !== "top-left")
                actions.defaultFloatingRelativeTo = floatingRelativeDropdown.currentValue;
        }

        const minW = parseInt(minWidthInput.text);
        const maxW = parseInt(maxWidthInput.text);
        const minH = parseInt(minHeightInput.text);
        const maxH = parseInt(maxHeightInput.text);
        if (!isNaN(minW))
            actions.minWidth = minW;
        if (!isNaN(maxW))
            actions.maxWidth = maxW;
        if (!isNaN(minH))
            actions.minHeight = minH;
        if (!isNaN(maxH))
            actions.maxHeight = maxH;

        if (isHyprland) {
            if (tileToggle.checked)
                actions.tile = true;
            if (noFocusToggle.checked)
                actions.nofocus = true;
            if (noBorderToggle.checked)
                actions.noborder = true;
            if (noShadowToggle.checked)
                actions.noshadow = true;
            if (noDimToggle.checked)
                actions.nodim = true;
            if (noBlurToggle.checked)
                actions.noblur = true;
            if (noAnimToggle.checked)
                actions.noanim = true;
            if (noRoundingToggle.checked)
                actions.norounding = true;
            if (pinToggle.checked)
                actions.pin = true;
            if (opaqueToggle.checked)
                actions.opaque = true;
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
            if (mangoTagsInput.text.trim())
                actions.workspace = mangoTagsInput.text.trim();
            if (mangoMonitorInput.text.trim())
                actions.monitor = mangoMonitorInput.text.trim();
            if (mangoSizeInput.text.trim()) {
                const parts = mangoSizeInput.text.trim().split(/x/i);
                if (parts.length === 2) {
                    actions.sizeWidth = parts[0].trim();
                    actions.sizeHeight = parts[1].trim();
                }
            }
            if (mangoNoBlurToggle.checked)
                actions.noblur = true;
            if (mangoNoBorderToggle.checked)
                actions.noborder = true;
            if (mangoNoShadowToggle.checked)
                actions.noshadow = true;
            if (mangoNoRoundingToggle.checked)
                actions.norounding = true;
            if (mangoNoAnimToggle.checked)
                actions.noanim = true;
        }

        const name = nameInput.text.trim() || matchCriteria.appId || I18n.tr("Rule", "noun, fallback name for an unnamed window rule");
        const compositor = CompositorService.compositor;

        const ruleData = {
            name: name,
            matchCriteria: matchCriteria,
            actions: actions,
            enabled: true
        };
        if (isNiri && extraMatchModel.count > 0)
            ruleData.matches = matches;
        // No exclude editor yet — carry existing excludes through so an edit doesn't delete them (#2996)
        if (isEditMode && (editingRule.excludes?.length ?? 0) > 0)
            ruleData.excludes = editingRule.excludes;

        submitting = true;

        const shouldValidate = CompositorService.isNiri;

        if (isEditMode) {
            const ruleJson = JSON.stringify(ruleData);
            Proc.runCommand("update-windowrule", [Proc.dmsBin, "config", "windowrules", "update", compositor, editingRule.id, ruleJson], (output, exitCode) => {
                root.submitting = false;
                if (exitCode !== 0)
                    return;
                if (shouldValidate)
                    NiriService.validate();
                if (CompositorService.isMango)
                    MangoService.reloadConfig();
                root.ruleSubmitted();
                root.hide();
            });
        } else {
            const ruleJson = JSON.stringify(ruleData);
            Proc.runCommand("add-windowrule", [Proc.dmsBin, "config", "windowrules", "add", compositor, ruleJson], (output, exitCode) => {
                root.submitting = false;
                if (exitCode !== 0)
                    return;
                if (shouldValidate)
                    NiriService.validate();
                if (CompositorService.isMango)
                    MangoService.reloadConfig();
                root.ruleSubmitted();
                root.hide();
            });
        }
    }

    onVisibleChanged: {
        if (!visible) {
            editingRule = null;
            targetWindow = null;
        }
    }

    component SectionHeader: StyledText {
        property string title
        text: title
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Theme.fontWeightMedium
        color: Theme.primary
        topPadding: Theme.spacingM
        bottomPadding: Theme.spacingXS
        width: parent.width
        horizontalAlignment: Text.AlignLeft
    }

    component CheckboxRow: DankButton {
        property string label: ""
        property bool indeterminate: false

        text: label
        maximumWidth: parent.width
        wrapText: true
        iconName: indeterminate ? "indeterminate_check_box" : checked ? "check_box" : "check_box_outline_blank"
        backgroundColor: checked ? Theme.secondaryContainer : "transparent"
        textColor: checked ? Theme.onSecondaryContainer : Theme.onSurface
        shape: checked ? "round" : "square"
        checkable: true
        Accessible.role: Accessible.CheckBox
        Accessible.checked: checked
        onClicked: {
            if (indeterminate) {
                indeterminate = false;
                checked = true;
                return;
            }
            checked = !checked;
        }
    }

    component MatchCond: StyledButton {
        id: mc
        property string label: ""
        property int triState: 0
        property string unsetLabel: I18n.tr("Default")
        property bool readOnly: false
        readonly property var stateText: [mc.unsetLabel, "true", "false"]
        readonly property var stateColor: [Theme.surfaceVariantText, Theme.primary, Theme.error]

        width: condRow.implicitWidth + Theme.spacingM * 2
        height: root.inputFieldHeight
        radius: Theme.cornerRadiusM
        color: enabled ? Theme.chipSurface : Theme.onSurface_12
        border.width: Theme.outlineWidth
        border.color: !enabled ? "transparent" : mc.triState === 0 ? Theme.outlineStrong : mc.stateColor[mc.triState]
        enabled: root.visible && !mc.readOnly
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
                height: 18
                radius: Theme.fullRadius(width, height)
                color: mc.enabled ? Theme.withAlpha(mc.stateColor[mc.triState], Theme.stateLayerPressed) : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    id: stateBadge
                    anchors.centerIn: parent
                    text: mc.stateText[mc.triState]
                    font.pixelSize: Theme.fontSizeSmall - 2
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

    DankDialog {
        id: ruleDialog

        anchors.fill: parent
        windowControls: ruleWindowControls
        title: root.isEditMode ? I18n.tr("Edit Window Rule") : I18n.tr("New Window Rule")
        supportingText: I18n.tr("Configure match criteria and actions")
        acceptEnabled: !root.submitting
        onRejected: root.hide()
        onAccepted: root.submitAndClose()

        Column {
            id: contentCol
            width: parent.width
            spacing: Theme.spacingXS

            DankTextField {
                id: nameInput
                outlined: true
                controlHeight: Theme.fieldHeightLarge
                labelText: I18n.tr("Rule Name")
                leftIconName: "edit"
                onAccepted: root.submitAndClose()
                width: parent.width
                font.pixelSize: Theme.fontSizeSmall
                textColor: Theme.surfaceText
                enabled: root.visible
            }

            SectionHeader {
                title: I18n.tr("Match Criteria")
            }

            DankTextField {
                id: appIdInput
                outlined: true
                controlHeight: Theme.fieldHeightLarge
                labelText: isMango ? I18n.tr("App ID (e.g. firefox)") : isHyprland ? I18n.tr("Class regex (e.g. ^firefox$)") : I18n.tr("App ID regex (e.g. ^firefox$)")
                leftIconName: "apps"
                onAccepted: root.submitAndClose()
                width: parent.width
                font.pixelSize: Theme.fontSizeSmall
                textColor: Theme.surfaceText
                enabled: root.visible
            }

            Row {
                width: parent.width
                spacing: Theme.spacingS

                DankTextField {
                    id: titleInput
                    outlined: true
                    controlHeight: Theme.fieldHeightLarge
                    labelText: isMango ? I18n.tr("Title (optional)") : I18n.tr("Title regex (optional)")
                    leftIconName: "title"
                    onAccepted: root.submitAndClose()
                    width: addTitleBtn.visible ? parent.width - addTitleBtn.width - Theme.spacingS : parent.width
                    font.pixelSize: Theme.fontSizeSmall
                    textColor: Theme.surfaceText
                    enabled: root.visible
                }

                DankActionButton {
                    id: addTitleBtn
                    width: root.inputFieldHeight
                    height: root.inputFieldHeight
                    circular: false
                    iconName: "add"
                    iconSize: 16
                    iconColor: Theme.surfaceVariantText
                    visible: !root.isEditMode && !!root.targetWindow?.title
                    tooltipText: I18n.tr("Add Title")
                    tooltipSide: "left"
                    onClicked: {
                        if (!root.targetWindow?.title)
                            return;
                        titleInput.text = isMango ? root.targetWindow.title : "^" + root.targetWindow.title + "$";
                    }
                }
            }

            StyledText {
                width: parent.width
                visible: root.isNiri
                text: I18n.tr("The rule applies to any window matching one of these.")
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: extraMatchModel

                delegate: Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankTextField {
                        id: extraAppId
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: root.isNiri ? I18n.tr("App ID regex") : I18n.tr("Class regex")
                        leftIconName: "apps"
                        onAccepted: root.submitAndClose()
                        width: (parent.width - removeMatchBtn.width - Theme.spacingS * 2) / 2
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        enabled: root.visible
                        text: rowAppId
                        onTextEdited: extraMatchModel.setProperty(index, "rowAppId", text)
                    }

                    DankTextField {
                        id: extraTitle
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: I18n.tr("Title regex (optional)")
                        leftIconName: "title"
                        onAccepted: root.submitAndClose()
                        width: (parent.width - removeMatchBtn.width - Theme.spacingS * 2) / 2
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        enabled: root.visible
                        text: rowTitle
                        onTextEdited: extraMatchModel.setProperty(index, "rowTitle", text)
                    }

                    DankActionButton {
                        id: removeMatchBtn
                        width: root.inputFieldHeight
                        height: root.inputFieldHeight
                        circular: false
                        iconName: "close"
                        iconSize: 16
                        iconColor: Theme.surfaceVariantText
                        Accessible.name: I18n.tr("Remove match")
                        tooltipSide: "left"
                        onClicked: extraMatchModel.remove(index)
                    }
                }
            }

            DankButton {
                text: I18n.tr("Add match")
                iconName: "add"
                backgroundColor: "transparent"
                textColor: Theme.primary
                visible: root.isNiri
                onClicked: extraMatchModel.append({
                    "rowAppId": "",
                    "rowTitle": ""
                })
            }

            SectionHeader {
                title: I18n.tr("Match Conditions")
                visible: isNiri || isHyprland
            }

            StyledText {
                width: parent.width
                visible: isNiri || isHyprland
                text: I18n.tr("Optional state-based conditions applied to the first match.")
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingS
                visible: isNiri || isHyprland

                MatchCond {
                    id: condFloating
                    label: I18n.tr("Floating", "adjective, window rule match condition for floating windows")
                }
                MatchCond {
                    id: condActive
                    label: I18n.tr("Active")
                    visible: isNiri
                }
                MatchCond {
                    id: condFocused
                    label: I18n.tr("Focused", "adjective, window rule match condition for the focused window")
                    visible: isNiri
                }
                MatchCond {
                    id: condActiveInColumn
                    label: I18n.tr("Active in column")
                    visible: isNiri
                }
                MatchCond {
                    id: condCastTarget
                    label: I18n.tr("Cast target")
                    visible: isNiri
                }
                MatchCond {
                    id: condUrgent
                    label: I18n.tr("Urgent", "adjective, window rule match condition for windows requesting attention")
                    visible: isNiri
                }
                MatchCond {
                    id: condAtStartup
                    label: I18n.tr("At startup")
                    visible: isNiri
                }
                MatchCond {
                    id: condXwayland
                    label: "XWayland"
                    visible: isHyprland
                }
                MatchCond {
                    id: condFullscreen
                    label: I18n.tr("Fullscreen", "adjective, window rule match condition for fullscreen windows")
                    visible: isHyprland
                }
                MatchCond {
                    id: condPinned
                    label: I18n.tr("Pinned", "adjective, state of a pinned window, clipboard entry or item")
                    visible: isHyprland
                }
                MatchCond {
                    id: condInitialised
                    label: I18n.tr("Initialised", "adjective, hyprland window rule match condition")
                    visible: isHyprland
                }
            }

            SectionHeader {
                title: I18n.tr("Window Opening")
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingS
                visible: isNiri

                MatchCond {
                    id: floatingCond
                    label: I18n.tr("Float")
                }
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingL

                CheckboxRow {
                    id: floatingToggle
                    label: I18n.tr("Float")
                    visible: !isNiri
                }
                CheckboxRow {
                    id: maximizedToggle
                    label: I18n.tr("Maximize", "verb, window rule action to open the window maximized")
                    visible: !isMango
                }
                CheckboxRow {
                    id: fullscreenToggle
                    label: I18n.tr("Fullscreen", "window rule action, open the window fullscreen")
                }
                CheckboxRow {
                    id: maximizedToEdgesToggle
                    label: I18n.tr("Max edges", "window rule action, open maximized to screen edges")
                    visible: isNiri
                }
                CheckboxRow {
                    id: openFocusedToggle
                    label: I18n.tr("Focus", "verb, window rule action to focus the window when it opens")
                    visible: isNiri
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: isNiri || isHyprland

                Column {
                    width: (parent.width - Theme.spacingM) / 2
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: outputInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: I18n.tr("Output", "noun, display output a window opens on, window rule field")
                        leftIconName: "monitor"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "HDMI-A-1"
                        enabled: root.visible
                    }
                }

                Column {
                    width: (parent.width - Theme.spacingM) / 2
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: workspaceInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: I18n.tr("Workspace")
                        leftIconName: "view_module"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "chat"
                        enabled: root.visible
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: isNiri

                Column {
                    width: (parent.width - Theme.spacingM) / 2
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: columnWidthInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: I18n.tr("Column Width")
                        leftIconName: "width"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "800"
                        enabled: root.visible
                    }
                }

                Column {
                    width: (parent.width - Theme.spacingM) / 2
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: windowHeightInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: I18n.tr("Window Height")
                        leftIconName: "height"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "600"
                        enabled: root.visible
                    }
                }
            }

            SectionHeader {
                title: I18n.tr("Dynamic Properties")
                visible: isNiri || isHyprland
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: isNiri || isHyprland

                CheckboxRow {
                    id: opacityEnabled
                    label: I18n.tr("Opacity")
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankSlider {
                    id: opacitySlider
                    wheelEnabled: false
                    width: Math.max(0, parent.width - opacityEnabled.width - parent.spacing)
                    Accessible.name: opacityEnabled.label
                    minimum: 10
                    maximum: 100
                    value: 100
                    enabled: opacityEnabled.checked
                }
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingL
                visible: isNiri

                CheckboxRow {
                    id: vrrToggle
                    label: I18n.tr("VRR On-Demand")
                }
                CheckboxRow {
                    id: clipToGeometryToggle
                    label: I18n.tr("Clip to Geometry")
                }
                CheckboxRow {
                    id: tiledStateToggle
                    label: I18n.tr("Tiled State")
                }
                CheckboxRow {
                    id: drawBorderBgToggle
                    label: I18n.tr("Border with Background")
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: isNiri

                Column {
                    width: (parent.width - Theme.spacingM) / 2
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Block Out From")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
                    }

                    DankDropdown {
                        id: blockOutDropdown
                        width: parent.width
                        dropdownWidth: parent.width
                        compactMode: true
                        options: ["", "screencast", "screen-capture"]
                        emptyText: I18n.tr("None")
                    }
                }

                Column {
                    width: (parent.width - Theme.spacingM) / 2
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Column Display")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
                    }

                    DankDropdown {
                        id: columnDisplayDropdown
                        width: parent.width
                        dropdownWidth: parent.width
                        compactMode: true
                        options: ["", "tabbed"]
                        emptyText: I18n.tr("Normal")
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: isNiri

                CheckboxRow {
                    id: scrollFactorEnabled
                    label: I18n.tr("Scroll Factor")
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankSlider {
                    id: scrollFactorSlider
                    wheelEnabled: false
                    width: Math.max(0, parent.width - scrollFactorEnabled.width - parent.spacing)
                    Accessible.name: scrollFactorEnabled.label
                    minimum: 10
                    maximum: 200
                    value: 100
                    enabled: scrollFactorEnabled.checked
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: isNiri || isHyprland

                CheckboxRow {
                    id: cornerRadiusEnabled
                    label: I18n.tr("Corner radius")
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankSlider {
                    id: cornerRadiusSlider
                    wheelEnabled: false
                    width: Math.max(0, parent.width - cornerRadiusEnabled.width - parent.spacing)
                    Accessible.name: cornerRadiusEnabled.label
                    minimum: 0
                    maximum: 24
                    value: 12
                    enabled: cornerRadiusEnabled.checked
                }
            }

            SectionHeader {
                title: I18n.tr("Background Effect")
                visible: isNiri
            }

            StyledText {
                width: parent.width
                visible: isNiri
                text: I18n.tr("Xray blurs only the wallpaper (efficient) and is the default when Blur is on. Set Xray to Off for regular full blur of everything beneath the window (more expensive).")
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingS
                visible: isNiri

                MatchCond {
                    id: blurCond
                    label: I18n.tr("Blur", "noun, background blur effect option")
                    unsetLabel: I18n.tr("Inherit")
                    onTriStateChanged: {
                        if (triState === 2)
                            xrayCond.triState = 0;
                    }
                }
                MatchCond {
                    id: xrayCond
                    label: I18n.tr("X-Ray", "window rule background xray effect option")
                    unsetLabel: I18n.tr("Inherit")
                    readOnly: blurCond.triState === 2
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: isNiri

                CheckboxRow {
                    id: noiseEnabled
                    label: I18n.tr("Noise", "window rule background noise effect checkbox")
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankSlider {
                    id: noiseSlider
                    wheelEnabled: false
                    width: Math.max(0, parent.width - noiseEnabled.width - parent.spacing)
                    Accessible.name: noiseEnabled.label
                    minimum: 0
                    maximum: 100
                    value: 5
                    enabled: noiseEnabled.checked
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: isNiri

                CheckboxRow {
                    id: saturationEnabled
                    label: I18n.tr("Saturation", "window rule background color saturation checkbox")
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankSlider {
                    id: saturationSlider
                    wheelEnabled: false
                    width: Math.max(0, parent.width - saturationEnabled.width - parent.spacing)
                    Accessible.name: saturationEnabled.label
                    minimum: 0
                    maximum: 200
                    value: 100
                    enabled: saturationEnabled.checked
                }
            }

            SectionHeader {
                title: I18n.tr("Floating Position")
                visible: isNiri
            }

            StyledText {
                width: parent.width
                visible: isNiri
                text: I18n.tr("Initial position for floating windows. Set both X and Y; anchor controls which corner/edge they're relative to.")
                font.pixelSize: Theme.fontSizeSmall - 1
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: isNiri

                Column {
                    width: (parent.width - Theme.spacingM * 2) / 3
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: floatingXInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: "X"
                        leftIconName: "open_with"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "px"
                        enabled: root.visible
                    }
                }

                Column {
                    width: (parent.width - Theme.spacingM * 2) / 3
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: floatingYInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: "Y"
                        leftIconName: "open_with"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "px"
                        enabled: root.visible
                    }
                }

                Column {
                    width: (parent.width - Theme.spacingM * 2) / 3
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Anchor", "noun, screen corner or edge a floating window position is relative to")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
                    }

                    DankDropdown {
                        id: floatingRelativeDropdown
                        width: parent.width
                        dropdownWidth: parent.width
                        compactMode: true
                        options: ["top-left", "top-right", "bottom-left", "bottom-right", "top", "bottom", "left", "right"]
                    }
                }
            }

            SectionHeader {
                title: I18n.tr("Size Constraints")
                visible: isNiri || isHyprland
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: isNiri || isHyprland

                Column {
                    width: (parent.width - Theme.spacingM * 3) / 4
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: minWidthInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: I18n.tr("Min W")
                        leftIconName: "width"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "px"
                        enabled: root.visible
                    }
                }

                Column {
                    width: (parent.width - Theme.spacingM * 3) / 4
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: maxWidthInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: I18n.tr("Max W")
                        leftIconName: "width"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "px"
                        enabled: root.visible
                    }
                }

                Column {
                    width: (parent.width - Theme.spacingM * 3) / 4
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: minHeightInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: I18n.tr("Min H")
                        leftIconName: "height"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "px"
                        enabled: root.visible
                    }
                }

                Column {
                    width: (parent.width - Theme.spacingM * 3) / 4
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: maxHeightInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: I18n.tr("Max H")
                        leftIconName: "height"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "px"
                        enabled: root.visible
                    }
                }
            }

            SectionHeader {
                title: I18n.tr("Hyprland Options")
                visible: isHyprland
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingL
                visible: isHyprland

                CheckboxRow {
                    id: tileToggle
                    label: I18n.tr("Tile")
                }
                CheckboxRow {
                    id: noFocusToggle
                    label: I18n.tr("No focus")
                }
                CheckboxRow {
                    id: noBorderToggle
                    label: I18n.tr("No border")
                }
                CheckboxRow {
                    id: noShadowToggle
                    label: I18n.tr("No shadow")
                }
                CheckboxRow {
                    id: noDimToggle
                    label: I18n.tr("No dim")
                }
                CheckboxRow {
                    id: noBlurToggle
                    label: I18n.tr("No blur")
                }
                CheckboxRow {
                    id: noAnimToggle
                    label: I18n.tr("No anim")
                }
                CheckboxRow {
                    id: noRoundingToggle
                    label: I18n.tr("No Rounding")
                }
                CheckboxRow {
                    id: pinToggle
                    label: I18n.tr("Pin", "verb, keep an item pinned in place")
                }
                CheckboxRow {
                    id: opaqueToggle
                    label: I18n.tr("Opaque", "adjective, window rule checkbox forcing an opaque window")
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: isHyprland

                Column {
                    width: (parent.width - Theme.spacingM * 3) / 4
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: moveXInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: "X"
                        leftIconName: "open_with"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "0"
                        enabled: root.visible
                    }
                }

                Column {
                    width: (parent.width - Theme.spacingM * 3) / 4
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: moveYInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: "Y"
                        leftIconName: "open_with"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "0"
                        enabled: root.visible
                    }
                }

                Column {
                    width: (parent.width - Theme.spacingM * 3) / 4
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: sizeWInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: I18n.tr("W")
                        leftIconName: "width"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "800"
                        enabled: root.visible
                    }
                }

                Column {
                    width: (parent.width - Theme.spacingM * 3) / 4
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: sizeHInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: I18n.tr("H", "abbreviation of height, window rule size field label")
                        leftIconName: "height"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "600"
                        enabled: root.visible
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: isHyprland

                Column {
                    width: (parent.width - Theme.spacingM) / 2
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: monitorInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: I18n.tr("Monitor", "noun, display output field in window rule editor")
                        leftIconName: "monitor"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "DP-1"
                        enabled: root.visible
                    }
                }

                Column {
                    width: (parent.width - Theme.spacingM) / 2
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: hyprWorkspaceInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: I18n.tr("Workspace")
                        leftIconName: "view_module"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "1"
                        enabled: root.visible
                    }
                }
            }

            SectionHeader {
                title: I18n.tr("Mango Options")
                visible: isMango
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingL
                visible: isMango

                CheckboxRow {
                    id: mangoNoBlurToggle
                    label: I18n.tr("No blur")
                }
                CheckboxRow {
                    id: mangoNoBorderToggle
                    label: I18n.tr("No border")
                }
                CheckboxRow {
                    id: mangoNoShadowToggle
                    label: I18n.tr("No shadow")
                }
                CheckboxRow {
                    id: mangoNoRoundingToggle
                    label: I18n.tr("No Rounding")
                }
                CheckboxRow {
                    id: mangoNoAnimToggle
                    label: I18n.tr("No anim")
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: isMango

                Column {
                    width: (parent.width - Theme.spacingM) / 2
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: mangoTagsInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: I18n.tr("Tags", "noun, mango compositor workspace tags field in window rule editor")
                        leftIconName: "label"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "1"
                        enabled: root.visible
                    }
                }

                Column {
                    width: (parent.width - Theme.spacingM) / 2
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: mangoMonitorInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: I18n.tr("Monitor")
                        leftIconName: "monitor"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "HDMI-A-1"
                        enabled: root.visible
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                visible: isMango

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    DankTextField {
                        id: mangoSizeInput
                        outlined: true
                        controlHeight: Theme.fieldHeightLarge
                        labelText: I18n.tr("Size")
                        leftIconName: "aspect_ratio"
                        onAccepted: root.submitAndClose()
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: "800x600"
                        enabled: root.visible
                    }
                }
            }

            Item {
                width: 1
                height: Theme.spacingM
            }
        }

        actions: [
            DankButton {
                maximumWidth: ruleDialog.actionWidth
                wrapText: true
                text: I18n.tr("Cancel")
                backgroundColor: "transparent"
                textColor: Theme.primary
                onClicked: root.hide()
            },
            DankButton {
                maximumWidth: ruleDialog.actionWidth
                wrapText: true
                text: root.submitting ? I18n.tr("Saving...") : (root.isEditMode ? I18n.tr("Update", "verb, button saving changes to an existing window rule") : I18n.tr("Create", "verb, button creating a new window rule or display profile"))
                enabled: !root.submitting
                busy: root.submitting
                onClicked: root.submitAndClose()
            }
        ]
    }

    FloatingWindowControls {
        id: ruleWindowControls
        targetWindow: root
    }
}
