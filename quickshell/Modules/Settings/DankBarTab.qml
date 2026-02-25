import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: dankBarTab

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property var parentModal: null
    property string selectedBarId: "default"

    property var selectedBarConfig: {
        selectedBarId;
        SettingsData.barConfigs;
        const index = SettingsData.barConfigs.findIndex(cfg => cfg.id === selectedBarId);
        return index !== -1 ? SettingsData.barConfigs[index] : SettingsData.barConfigs[0];
    }

    property bool selectedBarIsVertical: {
        selectedBarId;
        const pos = selectedBarConfig?.position ?? SettingsData.Position.Top;
        return pos === SettingsData.Position.Left || pos === SettingsData.Position.Right;
    }

    Timer {
        id: horizontalBarChangeDebounce
        interval: 500
        repeat: false
        onTriggered: {
            const verticalBars = SettingsData.barConfigs.filter(cfg => {
                const pos = cfg.position ?? SettingsData.Position.Top;
                return pos === SettingsData.Position.Left || pos === SettingsData.Position.Right;
            });

            verticalBars.forEach(bar => {
                if (!bar.enabled)
                    return;
                SettingsData.updateBarConfig(bar.id, {
                    enabled: false
                });
                Qt.callLater(() => SettingsData.updateBarConfig(bar.id, {
                        enabled: true
                    }));
            });
        }
    }

    function _isBarActive(c) {
        if (!c.enabled) return false;
        const prefs = c.screenPreferences || ["all"];
        if (prefs.length > 0) return true;
        return (c.showOnLastDisplay ?? true) && Quickshell.screens.length === 1;
    }

    function notifyHorizontalBarChange() {
        const configs = SettingsData.barConfigs;
        if (configs.length < 2)
            return;

        const hasHorizontal = configs.some(c => {
            if (!_isBarActive(c)) return false;
            const p = c.position ?? SettingsData.Position.Top;
            return p === SettingsData.Position.Top || p === SettingsData.Position.Bottom;
        });
        if (!hasHorizontal)
            return;

        const hasVertical = configs.some(c => {
            if (!_isBarActive(c)) return false;
            const p = c.position ?? SettingsData.Position.Top;
            return p === SettingsData.Position.Left || p === SettingsData.Position.Right;
        });
        if (!hasVertical)
            return;

        horizontalBarChangeDebounce.restart();
    }

    function createNewBar() {
        if (SettingsData.barConfigs.length >= 4)
            return;
        const defaultBar = SettingsData.getBarConfig("default");
        if (!defaultBar)
            return;
        const newId = "bar" + Date.now();
        const newBar = {
            id: newId,
            name: "Bar " + (SettingsData.barConfigs.length + 1),
            enabled: true,
            position: defaultBar.position ?? 0,
            screenPreferences: [],
            showOnLastDisplay: false,
            leftWidgets: defaultBar.leftWidgets || [],
            centerWidgets: defaultBar.centerWidgets || [],
            rightWidgets: defaultBar.rightWidgets || [],
            spacing: defaultBar.spacing ?? 4,
            innerPadding: defaultBar.innerPadding ?? 4,
            bottomGap: defaultBar.bottomGap ?? 0,
            transparency: defaultBar.transparency ?? 1.0,
            widgetTransparency: defaultBar.widgetTransparency ?? 1.0,
            squareCorners: defaultBar.squareCorners ?? false,
            noBackground: defaultBar.noBackground ?? false,
            gothCornersEnabled: defaultBar.gothCornersEnabled ?? false,
            gothCornerRadiusOverride: defaultBar.gothCornerRadiusOverride ?? false,
            gothCornerRadiusValue: defaultBar.gothCornerRadiusValue ?? 12,
            borderEnabled: defaultBar.borderEnabled ?? false,
            borderColor: defaultBar.borderColor || "surfaceText",
            borderOpacity: defaultBar.borderOpacity ?? 1.0,
            borderThickness: defaultBar.borderThickness ?? 1,
            widgetOutlineEnabled: defaultBar.widgetOutlineEnabled ?? false,
            widgetOutlineColor: defaultBar.widgetOutlineColor || "primary",
            widgetOutlineOpacity: defaultBar.widgetOutlineOpacity ?? 1.0,
            widgetOutlineThickness: defaultBar.widgetOutlineThickness ?? 1,
            widgetPadding: defaultBar.widgetPadding ?? 8,
            maximizeWidgetIcons: defaultBar.maximizeWidgetIcons ?? false,
            maximizeWidgetText: defaultBar.maximizeWidgetText ?? false,
            removeWidgetPadding: defaultBar.removeWidgetPadding ?? false,
            fontScale: defaultBar.fontScale ?? 1.0,
            iconScale: defaultBar.iconScale ?? 1.0,
            autoHide: defaultBar.autoHide ?? false,
            autoHideDelay: defaultBar.autoHideDelay ?? 250,
            showOnWindowsOpen: defaultBar.showOnWindowsOpen ?? false,
            openOnOverview: defaultBar.openOnOverview ?? false,
            visible: defaultBar.visible ?? true,
            popupGapsAuto: defaultBar.popupGapsAuto ?? true,
            popupGapsManual: defaultBar.popupGapsManual ?? 4,
            maximizeDetection: defaultBar.maximizeDetection ?? true,
            scrollEnabled: defaultBar.scrollEnabled ?? true,
            scrollXBehavior: defaultBar.scrollXBehavior ?? "column",
            scrollYBehavior: defaultBar.scrollYBehavior ?? "workspace",
            shadowIntensity: defaultBar.shadowIntensity ?? 0,
            shadowOpacity: defaultBar.shadowOpacity ?? 60,
            shadowColorMode: defaultBar.shadowColorMode ?? "text",
            shadowCustomColor: defaultBar.shadowCustomColor ?? "#000000"
        };
        SettingsData.addBarConfig(newBar);
        selectedBarId = newId;
    }

    function deleteBar(barId) {
        if (barId === "default")
            return;
        if (SettingsData.barConfigs.length <= 1)
            return;
        SettingsData.deleteBarConfig(barId);
        selectedBarId = "default";
    }

    function toggleBarEnabled(barId) {
        if (barId === "default")
            return;
        const config = SettingsData.getBarConfig(barId);
        if (!config)
            return;
        SettingsData.updateBarConfig(barId, {
            enabled: !config.enabled
        });
    }

    function getBarScreenPreferences(barId) {
        const config = SettingsData.getBarConfig(barId);
        return config?.screenPreferences || ["all"];
    }

    function setBarScreenPreferences(barId, prefs) {
        SettingsData.updateBarConfig(barId, {
            screenPreferences: prefs
        });
        notifyHorizontalBarChange();
    }

    function getBarShowOnLastDisplay(barId) {
        const config = SettingsData.getBarConfig(barId);
        return config?.showOnLastDisplay ?? true;
    }

    function setBarShowOnLastDisplay(barId, value) {
        SettingsData.updateBarConfig(barId, {
            showOnLastDisplay: value
        });
        if (Quickshell.screens.length === 1)
            notifyHorizontalBarChange();
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                iconName: "dashboard"
                title: I18n.tr("Bar Configurations")
                settingKey: "barConfigurations"

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingM

                    StyledText {
                        text: I18n.tr("Manage up to 4 independent bar configurations. Each bar has its own position, widgets, styling, and display assignment.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    DankButton {
                        text: I18n.tr("Add Bar")
                        iconName: "add"
                        buttonHeight: 32
                        visible: SettingsData.barConfigs.length < 4
                        onClicked: dankBarTab.createNewBar()
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Repeater {
                        model: SettingsData.barConfigs

                        Rectangle {
                            id: barCard
                            required property var modelData
                            required property int index

                            width: parent.width
                            height: barCardContent.implicitHeight + Theme.spacingM * 2
                            radius: Theme.cornerRadius
                            color: dankBarTab.selectedBarId === modelData.id ? Theme.withAlpha(Theme.primary, 0.15) : Theme.surfaceVariant
                            border.width: dankBarTab.selectedBarId === modelData.id ? 2 : 0
                            border.color: Theme.primary

                            Row {
                                id: barCardContent
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                Column {
                                    width: parent.width - deleteBtn.width - Theme.spacingM
                                    spacing: Theme.spacingXS / 2

                                    StyledText {
                                        text: barCard.modelData.name || "Bar " + (barCard.index + 1)
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        width: parent.width
                                        horizontalAlignment: Text.AlignLeft
                                    }

                                    Row {
                                        width: parent.width
                                        spacing: Theme.spacingS

                                        StyledText {
                                            text: {
                                                SettingsData.barConfigs;
                                                const cfg = SettingsData.getBarConfig(barCard.modelData.id);
                                                switch (cfg?.position ?? SettingsData.Position.Top) {
                                                case SettingsData.Position.Top:
                                                    return I18n.tr("Top");
                                                case SettingsData.Position.Bottom:
                                                    return I18n.tr("Bottom");
                                                case SettingsData.Position.Left:
                                                    return I18n.tr("Left");
                                                case SettingsData.Position.Right:
                                                    return I18n.tr("Right");
                                                default:
                                                    return I18n.tr("Top");
                                                }
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            horizontalAlignment: Text.AlignLeft
                                        }

                                        StyledText {
                                            text: "•"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            horizontalAlignment: Text.AlignLeft
                                        }

                                        StyledText {
                                            text: {
                                                SettingsData.barConfigs;
                                                const cfg = SettingsData.getBarConfig(barCard.modelData.id);
                                                const prefs = cfg?.screenPreferences || ["all"];
                                                if (prefs.includes("all") || (typeof prefs[0] === "string" && prefs[0] === "all"))
                                                    return I18n.tr("All displays");
                                                return I18n.tr("%1 display(s)").replace("%1", prefs.length);
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            horizontalAlignment: Text.AlignLeft
                                        }

                                        StyledText {
                                            text: "•"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            horizontalAlignment: Text.AlignLeft
                                        }

                                        StyledText {
                                            text: {
                                                SettingsData.barConfigs;
                                                const cfg = SettingsData.getBarConfig(barCard.modelData.id);
                                                const left = cfg?.leftWidgets?.length || 0;
                                                const center = cfg?.centerWidgets?.length || 0;
                                                const right = cfg?.rightWidgets?.length || 0;
                                                return I18n.tr("%1 widgets").replace("%1", left + center + right);
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            horizontalAlignment: Text.AlignLeft
                                        }

                                        StyledText {
                                            text: "•"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            horizontalAlignment: Text.AlignLeft
                                            visible: {
                                                SettingsData.barConfigs;
                                                const cfg = SettingsData.getBarConfig(barCard.modelData.id);
                                                return !cfg?.enabled && barCard.modelData.id !== "default";
                                            }
                                        }

                                        StyledText {
                                            text: I18n.tr("Disabled")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.error
                                            horizontalAlignment: Text.AlignLeft
                                            visible: {
                                                SettingsData.barConfigs;
                                                const cfg = SettingsData.getBarConfig(barCard.modelData.id);
                                                return !cfg?.enabled && barCard.modelData.id !== "default";
                                            }
                                        }
                                    }
                                }

                                DankActionButton {
                                    id: deleteBtn
                                    buttonSize: 32
                                    iconName: "delete"
                                    iconSize: 16
                                    backgroundColor: Theme.withAlpha(Theme.error, 0.15)
                                    iconColor: Theme.error
                                    visible: barCard.modelData.id !== "default"
                                    enabled: SettingsData.barConfigs.length > 1
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: dankBarTab.deleteBar(barCard.modelData.id)
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                z: -1
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dankBarTab.selectedBarId = barCard.modelData.id
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }

                            Behavior on border.width {
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                    }
                }
            }

            SettingsCard {
                iconName: selectedBarConfig?.enabled ? "visibility" : "visibility_off"
                title: I18n.tr("Enable Bar")
                visible: selectedBarId !== "default"

                SettingsToggleRow {
                    text: I18n.tr("Toggle visibility of this bar configuration")
                    checked: {
                        selectedBarId;
                        return selectedBarConfig?.enabled ?? false;
                    }
                    onToggled: toggled => dankBarTab.toggleBarEnabled(selectedBarId)
                }
            }

            SettingsCard {
                iconName: "display_settings"
                title: I18n.tr("Display Assignment")
                settingKey: "barDisplay"
                visible: selectedBarConfig?.enabled

                StyledText {
                    width: parent.width
                    text: I18n.tr("Configure which displays show \"%1\"").replace("%1", selectedBarConfig?.name || "this bar")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignLeft
                }

                Column {
                    id: displayAssignmentColumn
                    width: parent.width
                    spacing: Theme.spacingS

                    property bool showingAll: {
                        const prefs = selectedBarConfig?.screenPreferences || ["all"];
                        return prefs.includes("all") || (typeof prefs[0] === "string" && prefs[0] === "all");
                    }

                    SettingsToggleRow {
                        text: I18n.tr("All displays")
                        checked: displayAssignmentColumn.showingAll
                        onToggled: checked => {
                            if (checked) {
                                dankBarTab.setBarScreenPreferences(selectedBarId, ["all"]);
                            } else {
                                dankBarTab.setBarScreenPreferences(selectedBarId, []);
                            }
                        }
                    }

                    SettingsToggleRow {
                        text: I18n.tr("Show on Last Display")
                        checked: selectedBarConfig?.showOnLastDisplay ?? true
                        visible: !displayAssignmentColumn.showingAll
                        onToggled: checked => dankBarTab.setBarShowOnLastDisplay(selectedBarId, checked)
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.outline
                        opacity: 0.15
                        visible: !displayAssignmentColumn.showingAll
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: !displayAssignmentColumn.showingAll

                        Repeater {
                            model: Quickshell.screens

                            delegate: SettingsToggleRow {
                                id: screenToggle
                                required property var modelData

                                text: SettingsData.getScreenDisplayName(modelData)
                                description: modelData.width + "×" + modelData.height + " • " + (SettingsData.displayNameMode === "system" ? (modelData.model || "Unknown Model") : modelData.name)
                                checked: {
                                    const prefs = selectedBarConfig?.screenPreferences || [];
                                    if (typeof prefs[0] === "string" && prefs[0] === "all")
                                        return false;
                                    return SettingsData.isScreenInPreferences(modelData, prefs);
                                }
                                onToggled: checked => {
                                    let currentPrefs = selectedBarConfig?.screenPreferences || [];
                                    if (typeof currentPrefs[0] === "string" && currentPrefs[0] === "all")
                                        currentPrefs = [];

                                    const screenModelIndex = SettingsData.getScreenModelIndex(modelData);

                                    let newPrefs = currentPrefs.filter(pref => {
                                        if (typeof pref === "string")
                                            return false;
                                        if (pref.modelIndex !== undefined && screenModelIndex >= 0)
                                            return !(pref.model === modelData.model && pref.modelIndex === screenModelIndex);
                                        return pref.name !== modelData.name || pref.model !== modelData.model;
                                    });

                                    if (checked) {
                                        const prefObj = {
                                            name: modelData.name,
                                            model: modelData.model || ""
                                        };
                                        if (screenModelIndex >= 0)
                                            prefObj.modelIndex = screenModelIndex;
                                        newPrefs.push(prefObj);
                                    }

                                    dankBarTab.setBarScreenPreferences(selectedBarId, newPrefs);
                                }
                            }
                        }
                    }
                }
            }

            SettingsCard {
                iconName: "vertical_align_center"
                title: I18n.tr("Position")
                settingKey: "barPosition"
                visible: selectedBarConfig?.enabled

                Item {
                    width: parent.width
                    height: positionButtonGroup.height

                    DankButtonGroup {
                        id: positionButtonGroup
                        anchors.horizontalCenter: parent.horizontalCenter
                        model: [I18n.tr("Top"), I18n.tr("Bottom"), I18n.tr("Left"), I18n.tr("Right")]
                        currentIndex: {
                            selectedBarId;
                            const config = SettingsData.getBarConfig(selectedBarId);
                            const pos = config?.position ?? 0;
                            switch (pos) {
                            case SettingsData.Position.Top:
                                return 0;
                            case SettingsData.Position.Bottom:
                                return 1;
                            case SettingsData.Position.Left:
                                return 2;
                            case SettingsData.Position.Right:
                                return 3;
                            default:
                                return 0;
                            }
                        }
                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            let newPos = 0;
                            switch (index) {
                            case 0:
                                newPos = SettingsData.Position.Top;
                                break;
                            case 1:
                                newPos = SettingsData.Position.Bottom;
                                break;
                            case 2:
                                newPos = SettingsData.Position.Left;
                                break;
                            case 3:
                                newPos = SettingsData.Position.Right;
                                break;
                            }
                            SettingsData.updateBarConfig(selectedBarId, {
                                position: newPos
                            });
                            notifyHorizontalBarChange();
                        }
                    }
                }
            }

            SettingsCard {
                iconName: "visibility_off"
                title: I18n.tr("Visibility")
                settingKey: "barVisibility"
                visible: selectedBarConfig?.enabled

                SettingsToggleRow {
                    text: I18n.tr("Auto-hide")
                    checked: selectedBarConfig?.autoHide ?? false
                    onToggled: toggled => {
                        SettingsData.updateBarConfig(selectedBarId, {
                            autoHide: toggled
                        });
                        notifyHorizontalBarChange();
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: selectedBarConfig?.autoHide ?? false
                    leftPadding: Theme.spacingM

                    Rectangle {
                        width: parent.width - parent.leftPadding
                        height: 1
                        color: Theme.outline
                        opacity: 0.15
                    }

                    SettingsSliderRow {
                        id: hideDelaySlider
                        width: parent.width - parent.parent.leftPadding
                        text: I18n.tr("Hide Delay")
                        value: selectedBarConfig?.autoHideDelay ?? 250
                        minimum: 0
                        maximum: 2000
                        unit: "ms"
                        defaultValue: 250
                        onSliderValueChanged: newValue => {
                            SettingsData.updateBarConfig(selectedBarId, {
                                autoHideDelay: newValue
                            });
                        }

                        Binding {
                            target: hideDelaySlider
                            property: "value"
                            value: selectedBarConfig?.autoHideDelay ?? 250
                            restoreMode: Binding.RestoreBinding
                        }
                    }

                    SettingsToggleRow {
                        width: parent.width - parent.leftPadding
                        visible: CompositorService.isNiri || CompositorService.isHyprland
                        text: I18n.tr("Hide When Windows Open")
                        checked: selectedBarConfig?.showOnWindowsOpen ?? false
                        onToggled: toggled => {
                            SettingsData.updateBarConfig(selectedBarId, {
                                showOnWindowsOpen: toggled
                            });
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.15
                }

                SettingsToggleRow {
                    text: I18n.tr("Manual Show/Hide")
                    checked: selectedBarConfig?.visible ?? true
                    onToggled: toggled => {
                        SettingsData.updateBarConfig(selectedBarId, {
                            visible: toggled
                        });
                        notifyHorizontalBarChange();
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.15
                }

                SettingsToggleRow {
                    text: I18n.tr("Click Through")
                    checked: selectedBarConfig?.clickThrough ?? false
                    onToggled: toggled => SettingsData.updateBarConfig(selectedBarId, {
                            clickThrough: toggled
                        })
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.15
                    visible: CompositorService.isNiri
                }

                SettingsToggleRow {
                    visible: CompositorService.isNiri
                    text: I18n.tr("Show on Overview")
                    checked: selectedBarConfig?.openOnOverview ?? false
                    onToggled: toggled => {
                        SettingsData.updateBarConfig(selectedBarId, {
                            openOnOverview: toggled
                        });
                    }
                }
            }

            SettingsToggleCard {
                iconName: "fit_screen"
                title: I18n.tr("Maximize Detection")
                description: I18n.tr("Remove gaps and border when windows are maximized")
                visible: selectedBarConfig?.enabled && (CompositorService.isNiri || CompositorService.isHyprland)
                checked: selectedBarConfig?.maximizeDetection ?? true
                onToggled: checked => SettingsData.updateBarConfig(selectedBarId, {
                        maximizeDetection: checked
                    })
            }

            SettingsToggleCard {
                iconName: "mouse"
                title: I18n.tr("Scroll Wheel")
                description: I18n.tr("Control workspaces and columns by scrolling on the bar")
                visible: selectedBarConfig?.enabled
                checked: selectedBarConfig?.scrollEnabled ?? true
                onToggled: checked => SettingsData.updateBarConfig(selectedBarId, {
                        scrollEnabled: checked
                    })

                SettingsButtonGroupRow {
                    text: I18n.tr("Y Axis")
                    model: CompositorService.isNiri ? [I18n.tr("None"), I18n.tr("Workspace"), I18n.tr("Column")] : [I18n.tr("None"), I18n.tr("Workspace")]
                    currentIndex: {
                        switch (selectedBarConfig?.scrollYBehavior || "workspace") {
                        case "none":
                            return 0;
                        case "workspace":
                            return 1;
                        case "column":
                            return 2;
                        default:
                            return 1;
                        }
                    }
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        let behavior = "workspace";
                        switch (index) {
                        case 0:
                            behavior = "none";
                            break;
                        case 1:
                            behavior = "workspace";
                            break;
                        case 2:
                            behavior = "column";
                            break;
                        }
                        SettingsData.updateBarConfig(selectedBarId, {
                            scrollYBehavior: behavior
                        });
                    }
                }

                SettingsButtonGroupRow {
                    text: I18n.tr("X Axis")
                    visible: CompositorService.isNiri
                    model: [I18n.tr("None"), I18n.tr("Workspace"), I18n.tr("Column")]
                    currentIndex: {
                        switch (selectedBarConfig?.scrollXBehavior || "column") {
                        case "none":
                            return 0;
                        case "workspace":
                            return 1;
                        case "column":
                            return 2;
                        default:
                            return 2;
                        }
                    }
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        let behavior = "column";
                        switch (index) {
                        case 0:
                            behavior = "none";
                            break;
                        case 1:
                            behavior = "workspace";
                            break;
                        case 2:
                            behavior = "column";
                            break;
                        }
                        SettingsData.updateBarConfig(selectedBarId, {
                            scrollXBehavior: behavior
                        });
                    }
                }
            }

            SettingsCard {
                iconName: "space_bar"
                title: I18n.tr("Spacing")
                settingKey: "barSpacing"
                visible: selectedBarConfig?.enabled

                SettingsSliderRow {
                    id: edgeSpacingSlider
                    text: I18n.tr("Edge Spacing")
                    value: selectedBarConfig?.spacing ?? 4
                    minimum: 0
                    maximum: 32
                    defaultValue: 4
                    onSliderDragFinished: finalValue => {
                        SettingsData.updateBarConfig(selectedBarId, {
                            spacing: finalValue
                        });
                    }

                    Binding {
                        target: edgeSpacingSlider
                        property: "value"
                        value: selectedBarConfig?.spacing ?? 4
                        restoreMode: Binding.RestoreBinding
                    }
                }

                SettingsSliderRow {
                    id: exclusiveZoneSlider
                    text: I18n.tr("Exclusive Zone Offset")
                    value: selectedBarConfig?.bottomGap ?? 0
                    minimum: -50
                    maximum: 50
                    defaultValue: 0
                    onSliderDragFinished: finalValue => {
                        SettingsData.updateBarConfig(selectedBarId, {
                            bottomGap: finalValue
                        });
                    }

                    Binding {
                        target: exclusiveZoneSlider
                        property: "value"
                        value: selectedBarConfig?.bottomGap ?? 0
                        restoreMode: Binding.RestoreBinding
                    }
                }

                SettingsSliderRow {
                    id: sizeSlider
                    text: I18n.tr("Size")
                    value: selectedBarConfig?.innerPadding ?? 4
                    minimum: -8
                    maximum: 24
                    defaultValue: 4
                    onSliderDragFinished: finalValue => {
                        SettingsData.updateBarConfig(selectedBarId, {
                            innerPadding: finalValue
                        });
                    }

                    Binding {
                        target: sizeSlider
                        property: "value"
                        value: selectedBarConfig?.innerPadding ?? 4
                        restoreMode: Binding.RestoreBinding
                    }
                }

                SettingsSliderRow {
                    id: widgetPaddingSlider
                    text: I18n.tr("Padding")
                    value: selectedBarConfig?.widgetPadding ?? 8
                    minimum: 0
                    maximum: 32
                    unit: "px"
                    defaultValue: 8
                    opacity: (selectedBarConfig?.removeWidgetPadding ?? false) ? 0.5 : 1.0
                    enabled: !(selectedBarConfig?.removeWidgetPadding ?? false)
                    onSliderValueChanged: newValue => {
                        SettingsData.updateBarConfig(selectedBarId, {
                            widgetPadding: newValue
                        });
                    }

                    Binding {
                        target: widgetPaddingSlider
                        property: "value"
                        value: selectedBarConfig?.widgetPadding ?? 12
                        restoreMode: Binding.RestoreBinding
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.15
                }

                SettingsToggleRow {
                    text: I18n.tr("Auto Popup Gaps")
                    checked: selectedBarConfig?.popupGapsAuto ?? true
                    onToggled: checked => {
                        SettingsData.updateBarConfig(selectedBarId, {
                            popupGapsAuto: checked
                        });
                    }
                }

                Column {
                    width: parent.width
                    leftPadding: Theme.spacingM
                    spacing: Theme.spacingM
                    visible: !(selectedBarConfig?.popupGapsAuto ?? true)

                    Rectangle {
                        width: parent.width - parent.leftPadding
                        height: 1
                        color: Theme.outline
                        opacity: 0.15
                    }

                    SettingsSliderRow {
                        id: popupGapsManualSlider
                        width: parent.width - parent.parent.leftPadding
                        text: I18n.tr("Manual Gap Size")
                        value: selectedBarConfig?.popupGapsManual ?? 4
                        minimum: 0
                        maximum: 50
                        defaultValue: 4
                        onSliderDragFinished: finalValue => {
                            SettingsData.updateBarConfig(selectedBarId, {
                                popupGapsManual: finalValue
                            });
                        }

                        Binding {
                            target: popupGapsManualSlider
                            property: "value"
                            value: selectedBarConfig?.popupGapsManual ?? 4
                            restoreMode: Binding.RestoreBinding
                        }
                    }
                }
            }

            SettingsSliderCard {
                id: fontScaleSliderCard
                iconName: "text_fields"
                title: I18n.tr("Font Scale")
                description: I18n.tr("Scale DankBar font sizes independently")
                visible: selectedBarConfig?.enabled
                minimum: 50
                maximum: 200
                value: Math.round((selectedBarConfig?.fontScale ?? 1.0) * 100)
                unit: "%"
                defaultValue: 100
                onSliderValueChanged: newValue => {
                    SettingsData.updateBarConfig(selectedBarId, {
                        fontScale: newValue / 100
                    });
                }

                Binding {
                    target: fontScaleSliderCard
                    property: "value"
                    value: Math.round((selectedBarConfig?.fontScale ?? 1.0) * 100)
                    restoreMode: Binding.RestoreBinding
                }
            }

            SettingsSliderCard {
                id: iconScaleSliderCard
                iconName: "interests"
                title: I18n.tr("Icon Scale")
                description: I18n.tr("Scale DankBar icon sizes independently")
                visible: selectedBarConfig?.enabled
                minimum: 50
                maximum: 200
                value: Math.round((selectedBarConfig?.iconScale ?? 1.0) * 100)
                unit: "%"
                defaultValue: 100
                onSliderValueChanged: newValue => {
                    SettingsData.updateBarConfig(selectedBarId, {
                        iconScale: newValue / 100
                    });
                }

                Binding {
                    target: iconScaleSliderCard
                    property: "value"
                    value: Math.round((selectedBarConfig?.iconScale ?? 1.0) * 100)
                    restoreMode: Binding.RestoreBinding
                }
            }

            SettingsCard {
                iconName: "opacity"
                title: I18n.tr("Transparency")
                settingKey: "barTransparency"
                visible: selectedBarConfig?.enabled

                SettingsSliderRow {
                    id: barTransparencySlider
                    text: I18n.tr("Bar Transparency")
                    value: (selectedBarConfig?.transparency ?? 1.0) * 100
                    minimum: 0
                    maximum: 100
                    unit: "%"
                    defaultValue: 100
                    onSliderDragFinished: finalValue => {
                        SettingsData.updateBarConfig(selectedBarId, {
                            transparency: finalValue / 100
                        });
                    }

                    Binding {
                        target: barTransparencySlider
                        property: "value"
                        value: (selectedBarConfig?.transparency ?? 1.0) * 100
                        restoreMode: Binding.RestoreBinding
                    }
                }

                SettingsSliderRow {
                    id: widgetTransparencySlider
                    text: I18n.tr("Widget Transparency")
                    value: (selectedBarConfig?.widgetTransparency ?? 1.0) * 100
                    minimum: 0
                    maximum: 100
                    unit: "%"
                    defaultValue: 100
                    onSliderDragFinished: finalValue => {
                        SettingsData.updateBarConfig(selectedBarId, {
                            widgetTransparency: finalValue / 100
                        });
                    }

                    Binding {
                        target: widgetTransparencySlider
                        property: "value"
                        value: (selectedBarConfig?.widgetTransparency ?? 1.0) * 100
                        restoreMode: Binding.RestoreBinding
                    }
                }
            }

            SettingsCard {
                iconName: "rounded_corner"
                title: I18n.tr("Corners & Background")
                settingKey: "barCorners"
                collapsible: true
                expanded: false
                visible: selectedBarConfig?.enabled

                SettingsToggleRow {
                    text: I18n.tr("Square Corners")
                    checked: selectedBarConfig?.squareCorners ?? false
                    onToggled: checked => SettingsData.updateBarConfig(selectedBarId, {
                            squareCorners: checked
                        })
                }

                SettingsToggleRow {
                    text: I18n.tr("No Background")
                    checked: selectedBarConfig?.noBackground ?? false
                    onToggled: checked => SettingsData.updateBarConfig(selectedBarId, {
                            noBackground: checked
                        })
                }

                SettingsToggleRow {
                    text: I18n.tr("Maximize Widget Icons")
                    checked: selectedBarConfig?.maximizeWidgetIcons ?? false
                    onToggled: checked => SettingsData.updateBarConfig(selectedBarId, {
                            maximizeWidgetIcons: checked
                        })
                }

                SettingsToggleRow {
                    text: I18n.tr("Maximize Widget Text")
                    checked: selectedBarConfig?.maximizeWidgetText ?? false
                    onToggled: checked => SettingsData.updateBarConfig(selectedBarId, {
                            maximizeWidgetText: checked
                        })
                }

                SettingsToggleRow {
                    text: I18n.tr("Remove Widget Padding")
                    checked: selectedBarConfig?.removeWidgetPadding ?? false
                    onToggled: checked => SettingsData.updateBarConfig(selectedBarId, {
                            removeWidgetPadding: checked
                        })
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.15
                }

                SettingsToggleRow {
                    text: I18n.tr("Goth Corners")
                    checked: selectedBarConfig?.gothCornersEnabled ?? false
                    onToggled: checked => SettingsData.updateBarConfig(selectedBarId, {
                            gothCornersEnabled: checked
                        })
                }

                SettingsToggleRow {
                    text: I18n.tr("Corner Radius Override")
                    checked: selectedBarConfig?.gothCornerRadiusOverride ?? false
                    visible: selectedBarConfig?.gothCornersEnabled ?? false
                    onToggled: checked => SettingsData.updateBarConfig(selectedBarId, {
                            gothCornerRadiusOverride: checked
                        })
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: (selectedBarConfig?.gothCornersEnabled ?? false) && (selectedBarConfig?.gothCornerRadiusOverride ?? false)
                    leftPadding: Theme.spacingM

                    SettingsSliderRow {
                        id: gothCornerRadiusSlider
                        width: parent.width - parent.leftPadding
                        text: I18n.tr("Goth Corner Radius")
                        value: selectedBarConfig?.gothCornerRadiusValue ?? 12
                        minimum: 0
                        maximum: 64
                        defaultValue: 12
                        onSliderDragFinished: finalValue => {
                            SettingsData.updateBarConfig(selectedBarId, {
                                gothCornerRadiusValue: finalValue
                            });
                        }

                        Binding {
                            target: gothCornerRadiusSlider
                            property: "value"
                            value: selectedBarConfig?.gothCornerRadiusValue ?? 12
                            restoreMode: Binding.RestoreBinding
                        }
                    }
                }
            }

            SettingsCard {
                id: shadowCard
                iconName: "layers"
                title: I18n.tr("Shadow", "bar shadow settings card")
                settingKey: "barShadow"
                collapsible: true
                expanded: false
                visible: selectedBarConfig?.enabled

                readonly property bool shadowActive: (selectedBarConfig?.shadowIntensity ?? 0) > 0
                readonly property bool isCustomColor: (selectedBarConfig?.shadowColorMode ?? "text") === "custom"

                SettingsSliderRow {
                    text: I18n.tr("Intensity", "shadow intensity slider")
                    minimum: 0
                    maximum: 100
                    unit: "%"
                    value: selectedBarConfig?.shadowIntensity ?? 0
                    onSliderValueChanged: newValue => SettingsData.updateBarConfig(selectedBarId, {
                            shadowIntensity: newValue
                        })
                }

                SettingsSliderRow {
                    visible: shadowCard.shadowActive
                    text: I18n.tr("Opacity")
                    minimum: 10
                    maximum: 100
                    unit: "%"
                    value: selectedBarConfig?.shadowOpacity ?? 60
                    onSliderValueChanged: newValue => SettingsData.updateBarConfig(selectedBarId, {
                            shadowOpacity: newValue
                        })
                }

                Column {
                    visible: shadowCard.shadowActive
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: I18n.tr("Color")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        horizontalAlignment: Text.AlignLeft
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                    }

                    Item {
                        width: parent.width
                        height: shadowColorGroup.implicitHeight

                        DankButtonGroup {
                            id: shadowColorGroup
                            anchors.horizontalCenter: parent.horizontalCenter
                            buttonPadding: parent.width < 420 ? Theme.spacingXS : Theme.spacingS
                            minButtonWidth: parent.width < 420 ? 36 : 56
                            textSize: parent.width < 420 ? Theme.fontSizeSmall : Theme.fontSizeMedium
                            model: [I18n.tr("Text", "shadow color option"), I18n.tr("Surface", "shadow color option"), I18n.tr("Primary"), I18n.tr("Secondary"), I18n.tr("Custom")]
                            selectionMode: "single"
                            currentIndex: {
                                switch (selectedBarConfig?.shadowColorMode || "text") {
                                case "surface":
                                    return 1;
                                case "primary":
                                    return 2;
                                case "secondary":
                                    return 3;
                                case "custom":
                                    return 4;
                                default:
                                    return 0;
                                }
                            }
                            onSelectionChanged: (index, selected) => {
                                if (!selected)
                                    return;
                                let mode = "text";
                                switch (index) {
                                case 1:
                                    mode = "surface";
                                    break;
                                case 2:
                                    mode = "primary";
                                    break;
                                case 3:
                                    mode = "secondary";
                                    break;
                                case 4:
                                    mode = "custom";
                                    break;
                                }
                                SettingsData.updateBarConfig(selectedBarId, {
                                    shadowColorMode: mode
                                });
                            }
                        }
                    }

                    Rectangle {
                        visible: selectedBarConfig?.shadowColorMode === "custom"
                        width: 32
                        height: 32
                        radius: 16
                        color: selectedBarConfig?.shadowCustomColor ?? "#000000"
                        border.color: Theme.outline
                        border.width: 1
                        anchors.horizontalCenter: parent.horizontalCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                PopoutService.colorPickerModal.selectedColor = selectedBarConfig?.shadowCustomColor ?? "#000000";
                                PopoutService.colorPickerModal.pickerTitle = I18n.tr("Color");
                                PopoutService.colorPickerModal.onColorSelectedCallback = function (color) {
                                    SettingsData.updateBarConfig(selectedBarId, {
                                        shadowCustomColor: color.toString()
                                    });
                                };
                                PopoutService.colorPickerModal.show();
                            }
                        }
                    }
                }
            }

            SettingsToggleCard {
                iconName: "border_style"
                title: I18n.tr("Border")
                visible: selectedBarConfig?.enabled
                checked: selectedBarConfig?.borderEnabled ?? false
                onToggled: checked => SettingsData.updateBarConfig(selectedBarId, {
                        borderEnabled: checked
                    })

                SettingsButtonGroupRow {
                    text: I18n.tr("Color")
                    model: ["Surface", "Secondary", "Primary"]
                    currentIndex: {
                        switch (selectedBarConfig?.borderColor || "surfaceText") {
                        case "surfaceText":
                            return 0;
                        case "secondary":
                            return 1;
                        case "primary":
                            return 2;
                        default:
                            return 0;
                        }
                    }
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        let newColor = "surfaceText";
                        switch (index) {
                        case 0:
                            newColor = "surfaceText";
                            break;
                        case 1:
                            newColor = "secondary";
                            break;
                        case 2:
                            newColor = "primary";
                            break;
                        }
                        SettingsData.updateBarConfig(selectedBarId, {
                            borderColor: newColor
                        });
                    }
                }

                SettingsSliderRow {
                    id: borderOpacitySlider
                    text: I18n.tr("Opacity")
                    value: (selectedBarConfig?.borderOpacity ?? 1.0) * 100
                    minimum: 0
                    maximum: 100
                    unit: "%"
                    defaultValue: 100
                    onSliderDragFinished: finalValue => {
                        SettingsData.updateBarConfig(selectedBarId, {
                            borderOpacity: finalValue / 100
                        });
                    }

                    Binding {
                        target: borderOpacitySlider
                        property: "value"
                        value: (selectedBarConfig?.borderOpacity ?? 1.0) * 100
                        restoreMode: Binding.RestoreBinding
                    }
                }

                SettingsSliderRow {
                    id: borderThicknessSlider
                    text: I18n.tr("Thickness")
                    value: selectedBarConfig?.borderThickness ?? 1
                    minimum: 1
                    maximum: 10
                    unit: "px"
                    defaultValue: 1
                    onSliderDragFinished: finalValue => {
                        SettingsData.updateBarConfig(selectedBarId, {
                            borderThickness: finalValue
                        });
                    }

                    Binding {
                        target: borderThicknessSlider
                        property: "value"
                        value: selectedBarConfig?.borderThickness ?? 1
                        restoreMode: Binding.RestoreBinding
                    }
                }
            }

            SettingsToggleCard {
                iconName: "highlight"
                title: I18n.tr("Widget Outline")
                visible: selectedBarConfig?.enabled
                checked: selectedBarConfig?.widgetOutlineEnabled ?? false
                onToggled: checked => SettingsData.updateBarConfig(selectedBarId, {
                        widgetOutlineEnabled: checked
                    })

                SettingsButtonGroupRow {
                    text: I18n.tr("Color")
                    model: ["Surface", "Secondary", "Primary"]
                    currentIndex: {
                        switch (selectedBarConfig?.widgetOutlineColor || "primary") {
                        case "surfaceText":
                            return 0;
                        case "secondary":
                            return 1;
                        case "primary":
                            return 2;
                        default:
                            return 2;
                        }
                    }
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        let newColor = "primary";
                        switch (index) {
                        case 0:
                            newColor = "surfaceText";
                            break;
                        case 1:
                            newColor = "secondary";
                            break;
                        case 2:
                            newColor = "primary";
                            break;
                        }
                        SettingsData.updateBarConfig(selectedBarId, {
                            widgetOutlineColor: newColor
                        });
                    }
                }

                SettingsSliderRow {
                    id: widgetOutlineOpacitySlider
                    text: I18n.tr("Opacity")
                    value: (selectedBarConfig?.widgetOutlineOpacity ?? 1.0) * 100
                    minimum: 0
                    maximum: 100
                    unit: "%"
                    defaultValue: 100
                    onSliderDragFinished: finalValue => {
                        SettingsData.updateBarConfig(selectedBarId, {
                            widgetOutlineOpacity: finalValue / 100
                        });
                    }

                    Binding {
                        target: widgetOutlineOpacitySlider
                        property: "value"
                        value: (selectedBarConfig?.widgetOutlineOpacity ?? 1.0) * 100
                        restoreMode: Binding.RestoreBinding
                    }
                }

                SettingsSliderRow {
                    id: widgetOutlineThicknessSlider
                    text: I18n.tr("Thickness")
                    value: selectedBarConfig?.widgetOutlineThickness ?? 1
                    minimum: 1
                    maximum: 10
                    unit: "px"
                    defaultValue: 1
                    onSliderDragFinished: finalValue => {
                        SettingsData.updateBarConfig(selectedBarId, {
                            widgetOutlineThickness: finalValue
                        });
                    }

                    Binding {
                        target: widgetOutlineThicknessSlider
                        property: "value"
                        value: selectedBarConfig?.widgetOutlineThickness ?? 1
                        restoreMode: Binding.RestoreBinding
                    }
                }
            }
        }
    }
}
