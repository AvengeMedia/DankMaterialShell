import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

FloatingWindow {
    id: root

    property bool disablePopupTransparency: true
    property var editingRule: null
    property bool isEditMode: editingRule !== null
    property bool isNiri: CompositorService.isNiri
    property bool isHyprland: CompositorService.isHyprland
    property bool submitting: false
    property var targetWindow: null

    signal ruleSubmitted

    readonly property int inputFieldHeight: Theme.fontSizeMedium + Theme.spacingL * 2
    readonly property int sectionSpacing: Theme.spacingL

    objectName: "windowRuleModal"
    title: isEditMode ? I18n.tr("Edit Window Rule") : I18n.tr("Create Window Rule")
    minimumSize: Qt.size(500, 600)
    maximumSize: Qt.size(500, 600)
    color: Theme.surfaceContainer
    visible: false

    function resetForm() {
        nameInput.text = "";
        appIdInput.text = "";
        titleInput.text = "";
        opacityEnabled.checked = false;
        opacitySlider.value = 100;
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
        sizeInput.text = "";
        moveInput.text = "";
        monitorInput.text = "";
        hyprWorkspaceInput.text = "";
    }

    function show(window) {
        editingRule = null;
        targetWindow = window || null;
        resetForm();
        if (targetWindow) {
            nameInput.text = targetWindow.appId || "";
            appIdInput.text = targetWindow.appId ? "^" + targetWindow.appId + "$" : "";
        }
        visible = true;
        Qt.callLater(() => nameInput.forceActiveFocus());
    }

    function showEdit(rule) {
        if (!rule) {
            show();
            return;
        }
        editingRule = rule;
        resetForm();

        nameInput.text = rule.name || "";
        const match = rule.matchCriteria || {};
        appIdInput.text = match.appId || "";
        titleInput.text = match.title || "";

        const actions = rule.actions || {};
        const hasOpacity = actions.opacity !== undefined && actions.opacity !== null;
        opacityEnabled.checked = hasOpacity;
        opacitySlider.value = hasOpacity ? Math.round(actions.opacity * 100) : 100;

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
        sizeInput.text = actions.size || "";
        moveInput.text = actions.move || "";
        monitorInput.text = actions.monitor || "";
        hyprWorkspaceInput.text = actions.workspace || "";

        visible = true;
        Qt.callLater(() => nameInput.forceActiveFocus());
    }

    function hide() {
        visible = false;
        editingRule = null;
        targetWindow = null;
    }

    function submitAndClose() {
        const matchCriteria = {};
        if (appIdInput.text.trim())
            matchCriteria.appId = appIdInput.text.trim();
        if (titleInput.text.trim())
            matchCriteria.title = titleInput.text.trim();

        const actions = {};

        if (opacityEnabled.checked)
            actions.opacity = opacitySlider.value / 100;
        if (floatingToggle.checked)
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
            if (sizeInput.text.trim())
                actions.size = sizeInput.text.trim();
            if (moveInput.text.trim())
                actions.move = moveInput.text.trim();
            if (monitorInput.text.trim())
                actions.monitor = monitorInput.text.trim();
            if (hyprWorkspaceInput.text.trim())
                actions.workspace = hyprWorkspaceInput.text.trim();
        }

        const name = nameInput.text.trim() || matchCriteria.appId || I18n.tr("Rule");
        const compositor = CompositorService.compositor;

        const ruleData = {
            name: name,
            matchCriteria: matchCriteria,
            actions: actions,
            enabled: true
        };

        submitting = true;

        const shouldValidate = CompositorService.isNiri;

        if (isEditMode) {
            const ruleJson = JSON.stringify(ruleData);
            Proc.runCommand("update-windowrule", ["dms", "config", "windowrules", "update", compositor, editingRule.id, ruleJson], (output, exitCode) => {
                root.submitting = false;
                if (exitCode !== 0)
                    return;
                if (shouldValidate)
                    NiriService.validate();
                root.ruleSubmitted();
                root.hide();
            });
        } else {
            const ruleJson = JSON.stringify(ruleData);
            Proc.runCommand("add-windowrule", ["dms", "config", "windowrules", "add", compositor, ruleJson], (output, exitCode) => {
                root.submitting = false;
                if (exitCode !== 0)
                    return;
                if (shouldValidate)
                    NiriService.validate();
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

    FocusScope {
        anchors.fill: parent
        focus: true

        LayoutMirroring.enabled: I18n.isRtl
        LayoutMirroring.childrenInherit: true

        Keys.onEscapePressed: event => {
            hide();
            event.accepted = true;
        }

        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.spacingL
            height: Math.max(headerCol.height, closeBtn.height)

            MouseArea {
                anchors.left: parent.left
                anchors.right: closeBtn.left
                anchors.rightMargin: Theme.spacingM
                height: headerCol.height
                onPressed: windowControls.tryStartMove()

                Column {
                    id: headerCol
                    width: parent.width
                    spacing: Theme.spacingXS

                    StyledText {
                        text: root.isEditMode ? I18n.tr("Edit Window Rule") : I18n.tr("New Window Rule")
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
                    }

                    StyledText {
                        text: I18n.tr("Configure match criteria and actions")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                        width: parent.width
                        horizontalAlignment: Text.AlignLeft
                    }
                }
            }

            DankActionButton {
                id: closeBtn
                anchors.right: parent.right
                iconName: "close"
                iconSize: Theme.iconSize - 4
                iconColor: Theme.surfaceText
                onClicked: hide()
            }
        }

        DankFlickable {
            id: flickable
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footer.top
            anchors.margins: Theme.spacingL
            anchors.topMargin: Theme.spacingM
            contentWidth: width
            contentHeight: contentCol.implicitHeight
            clip: true

            Column {
                id: contentCol
                width: flickable.width - Theme.spacingM
                spacing: Theme.spacingXS

                WindowRuleInputField {
                    hasFocus: nameInput.activeFocus
                    DankTextField {
                        id: nameInput
                        anchors.fill: parent
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: I18n.tr("Rule Name")
                        backgroundColor: "transparent"
                        enabled: root.visible
                    }
                }

                WindowRuleSectionHeader {
                    title: I18n.tr("Match Criteria")
                }

                WindowRuleInputField {
                    hasFocus: appIdInput.activeFocus
                    DankTextField {
                        id: appIdInput
                        anchors.fill: parent
                        font.pixelSize: Theme.fontSizeSmall
                        textColor: Theme.surfaceText
                        placeholderText: isNiri ? I18n.tr("App ID regex (e.g. ^firefox$)") : I18n.tr("Class regex (e.g. ^firefox$)")
                        backgroundColor: "transparent"
                        enabled: root.visible
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    WindowRuleInputField {
                        width: addTitleBtn.visible ? parent.width - addTitleBtn.width - Theme.spacingS : parent.width
                        hasFocus: titleInput.activeFocus
                        DankTextField {
                            id: titleInput
                            anchors.fill: parent
                            font.pixelSize: Theme.fontSizeSmall
                            textColor: Theme.surfaceText
                            placeholderText: I18n.tr("Title regex (optional)")
                            backgroundColor: "transparent"
                            enabled: root.visible
                        }
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
                            titleInput.text = "^" + root.targetWindow.title + "$";
                        }
                    }
                }

                WindowRuleSectionHeader {
                    title: I18n.tr("Window Opening")
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingL

                    WindowRuleCheckboxRow {
                        id: floatingToggle
                        label: I18n.tr("Float")
                    }
                    WindowRuleCheckboxRow {
                        id: maximizedToggle
                        label: I18n.tr("Maximize")
                    }
                    WindowRuleCheckboxRow {
                        id: fullscreenToggle
                        label: I18n.tr("Fullscreen")
                    }
                    WindowRuleCheckboxRow {
                        id: maximizedToEdgesToggle
                        label: I18n.tr("Max to Edges")
                        visible: isNiri
                    }
                    WindowRuleCheckboxRow {
                        id: openFocusedToggle
                        label: I18n.tr("Focus")
                        visible: isNiri
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: true

                    Column {
                        width: (parent.width - Theme.spacingM) / 2
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Output")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        WindowRuleInputField {
                            width: parent.width
                            hasFocus: outputInput.activeFocus
                            DankTextField {
                                id: outputInput
                                anchors.fill: parent
                                font.pixelSize: Theme.fontSizeSmall
                                textColor: Theme.surfaceText
                                placeholderText: "HDMI-A-1"
                                backgroundColor: "transparent"
                                enabled: root.visible
                            }
                        }
                    }

                    Column {
                        width: (parent.width - Theme.spacingM) / 2
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Workspace")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        WindowRuleInputField {
                            width: parent.width
                            hasFocus: workspaceInput.activeFocus
                            DankTextField {
                                id: workspaceInput
                                anchors.fill: parent
                                font.pixelSize: Theme.fontSizeSmall
                                textColor: Theme.surfaceText
                                placeholderText: "chat"
                                backgroundColor: "transparent"
                                enabled: root.visible
                            }
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

                        StyledText {
                            text: I18n.tr("Column Width")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        WindowRuleInputField {
                            width: parent.width
                            hasFocus: columnWidthInput.activeFocus
                            DankTextField {
                                id: columnWidthInput
                                anchors.fill: parent
                                font.pixelSize: Theme.fontSizeSmall
                                textColor: Theme.surfaceText
                                placeholderText: "800"
                                backgroundColor: "transparent"
                                enabled: root.visible
                            }
                        }
                    }

                    Column {
                        width: (parent.width - Theme.spacingM) / 2
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Window Height")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        WindowRuleInputField {
                            width: parent.width
                            hasFocus: windowHeightInput.activeFocus
                            DankTextField {
                                id: windowHeightInput
                                anchors.fill: parent
                                font.pixelSize: Theme.fontSizeSmall
                                textColor: Theme.surfaceText
                                placeholderText: "600"
                                backgroundColor: "transparent"
                                enabled: root.visible
                            }
                        }
                    }
                }

                WindowRuleSectionHeader {
                    title: I18n.tr("Dynamic Properties")
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    WindowRuleCheckboxRow {
                        id: opacityEnabled
                        label: I18n.tr("Opacity")
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankSlider {
                        id: opacitySlider
                        width: parent.width - 100
                        minimum: 10
                        maximum: 100
                        value: 100
                        enabled: opacityEnabled.checked
                        opacity: enabled ? 1 : 0.4
                    }
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingL
                    visible: isNiri

                    WindowRuleCheckboxRow {
                        id: vrrToggle
                        label: I18n.tr("VRR On-Demand")
                    }
                    WindowRuleCheckboxRow {
                        id: clipToGeometryToggle
                        label: I18n.tr("Clip to Geometry")
                    }
                    WindowRuleCheckboxRow {
                        id: tiledStateToggle
                        label: I18n.tr("Tiled State")
                    }
                    WindowRuleCheckboxRow {
                        id: drawBorderBgToggle
                        label: I18n.tr("Border with BG")
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

                    WindowRuleCheckboxRow {
                        id: scrollFactorEnabled
                        label: I18n.tr("Scroll Factor")
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankSlider {
                        id: scrollFactorSlider
                        width: parent.width - 120
                        minimum: 10
                        maximum: 200
                        value: 100
                        enabled: scrollFactorEnabled.checked
                        opacity: enabled ? 1 : 0.4
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    WindowRuleCheckboxRow {
                        id: cornerRadiusEnabled
                        label: I18n.tr("Corner Radius")
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DankSlider {
                        id: cornerRadiusSlider
                        width: parent.width - 130
                        minimum: 0
                        maximum: 24
                        value: 12
                        enabled: cornerRadiusEnabled.checked
                        opacity: enabled ? 1 : 0.4
                    }
                }

                WindowRuleSectionHeader {
                    title: I18n.tr("Size Constraints")
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    Column {
                        width: (parent.width - Theme.spacingM * 3) / 4
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Min W")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        WindowRuleInputField {
                            width: parent.width
                            hasFocus: minWidthInput.activeFocus
                            DankTextField {
                                id: minWidthInput
                                anchors.fill: parent
                                font.pixelSize: Theme.fontSizeSmall
                                textColor: Theme.surfaceText
                                placeholderText: "px"
                                backgroundColor: "transparent"
                                enabled: root.visible
                            }
                        }
                    }

                    Column {
                        width: (parent.width - Theme.spacingM * 3) / 4
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Max W")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        WindowRuleInputField {
                            width: parent.width
                            hasFocus: maxWidthInput.activeFocus
                            DankTextField {
                                id: maxWidthInput
                                anchors.fill: parent
                                font.pixelSize: Theme.fontSizeSmall
                                textColor: Theme.surfaceText
                                placeholderText: "px"
                                backgroundColor: "transparent"
                                enabled: root.visible
                            }
                        }
                    }

                    Column {
                        width: (parent.width - Theme.spacingM * 3) / 4
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Min H")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        WindowRuleInputField {
                            width: parent.width
                            hasFocus: minHeightInput.activeFocus
                            DankTextField {
                                id: minHeightInput
                                anchors.fill: parent
                                font.pixelSize: Theme.fontSizeSmall
                                textColor: Theme.surfaceText
                                placeholderText: "px"
                                backgroundColor: "transparent"
                                enabled: root.visible
                            }
                        }
                    }

                    Column {
                        width: (parent.width - Theme.spacingM * 3) / 4
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Max H")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        WindowRuleInputField {
                            width: parent.width
                            hasFocus: maxHeightInput.activeFocus
                            DankTextField {
                                id: maxHeightInput
                                anchors.fill: parent
                                font.pixelSize: Theme.fontSizeSmall
                                textColor: Theme.surfaceText
                                placeholderText: "px"
                                backgroundColor: "transparent"
                                enabled: root.visible
                            }
                        }
                    }
                }

                WindowRuleSectionHeader {
                    title: I18n.tr("Hyprland Options")
                    visible: isHyprland
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingL
                    visible: isHyprland

                    WindowRuleCheckboxRow {
                        id: tileToggle
                        label: I18n.tr("Tile")
                    }
                    WindowRuleCheckboxRow {
                        id: noFocusToggle
                        label: I18n.tr("No Focus")
                    }
                    WindowRuleCheckboxRow {
                        id: noBorderToggle
                        label: I18n.tr("No Border")
                    }
                    WindowRuleCheckboxRow {
                        id: noShadowToggle
                        label: I18n.tr("No Shadow")
                    }
                    WindowRuleCheckboxRow {
                        id: noDimToggle
                        label: I18n.tr("No Dim")
                    }
                    WindowRuleCheckboxRow {
                        id: noBlurToggle
                        label: I18n.tr("No Blur")
                    }
                    WindowRuleCheckboxRow {
                        id: noAnimToggle
                        label: I18n.tr("No Anim")
                    }
                    WindowRuleCheckboxRow {
                        id: noRoundingToggle
                        label: I18n.tr("No Rounding")
                    }
                    WindowRuleCheckboxRow {
                        id: pinToggle
                        label: I18n.tr("Pin")
                    }
                    WindowRuleCheckboxRow {
                        id: opaqueToggle
                        label: I18n.tr("Opaque")
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: isHyprland

                    Column {
                        width: (parent.width - Theme.spacingM) / 2
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Size")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        WindowRuleInputField {
                            width: parent.width
                            hasFocus: sizeInput.activeFocus
                            DankTextField {
                                id: sizeInput
                                anchors.fill: parent
                                font.pixelSize: Theme.fontSizeSmall
                                textColor: Theme.surfaceText
                                placeholderText: "800 600"
                                backgroundColor: "transparent"
                                enabled: root.visible
                            }
                        }
                    }

                    Column {
                        width: (parent.width - Theme.spacingM) / 2
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Move")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        WindowRuleInputField {
                            width: parent.width
                            hasFocus: moveInput.activeFocus
                            DankTextField {
                                id: moveInput
                                anchors.fill: parent
                                font.pixelSize: Theme.fontSizeSmall
                                textColor: Theme.surfaceText
                                placeholderText: "100 100"
                                backgroundColor: "transparent"
                                enabled: root.visible
                            }
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

                        StyledText {
                            text: I18n.tr("Monitor")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        WindowRuleInputField {
                            width: parent.width
                            hasFocus: monitorInput.activeFocus
                            DankTextField {
                                id: monitorInput
                                anchors.fill: parent
                                font.pixelSize: Theme.fontSizeSmall
                                textColor: Theme.surfaceText
                                placeholderText: "DP-1"
                                backgroundColor: "transparent"
                                enabled: root.visible
                            }
                        }
                    }

                    Column {
                        width: (parent.width - Theme.spacingM) / 2
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Workspace")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            horizontalAlignment: Text.AlignLeft
                        }

                        WindowRuleInputField {
                            width: parent.width
                            hasFocus: hyprWorkspaceInput.activeFocus
                            DankTextField {
                                id: hyprWorkspaceInput
                                anchors.fill: parent
                                font.pixelSize: Theme.fontSizeSmall
                                textColor: Theme.surfaceText
                                placeholderText: "1"
                                backgroundColor: "transparent"
                                enabled: root.visible
                            }
                        }
                    }
                }

                Item {
                    width: 1
                    height: Theme.spacingM
                }
            }
        }

        Item {
            id: footer
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.spacingL
            height: 44

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingM

                Rectangle {
                    width: Math.max(70, cancelText.contentWidth + Theme.spacingM * 2)
                    height: 36
                    radius: Theme.cornerRadius
                    color: cancelArea.containsMouse ? Theme.surfaceTextHover : "transparent"
                    border.color: Theme.surfaceVariantAlpha
                    border.width: 1

                    StyledText {
                        id: cancelText
                        anchors.centerIn: parent
                        text: I18n.tr("Cancel")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: cancelArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: hide()
                    }
                }

                Rectangle {
                    width: Math.max(80, createText.contentWidth + Theme.spacingM * 2)
                    height: 36
                    radius: Theme.cornerRadius
                    color: root.submitting ? Theme.surfaceVariant : (createArea.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary)

                    StyledText {
                        id: createText
                        anchors.centerIn: parent
                        text: root.submitting ? I18n.tr("Saving...") : (root.isEditMode ? I18n.tr("Update") : I18n.tr("Create"))
                        font.pixelSize: Theme.fontSizeMedium
                        color: root.submitting ? Theme.surfaceVariantText : Theme.background
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: createArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.submitting ? Qt.ArrowCursor : Qt.PointingHandCursor
                        enabled: !root.submitting
                        onClicked: submitAndClose()
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: root
    }
}
