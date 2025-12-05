import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: dankBarTab

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

    Timer {
        id: edgeSpacingDebounce
        interval: 100
        repeat: false
        property real pendingValue: 4
        onTriggered: {
            SettingsData.updateBarConfig(selectedBarId, {
                spacing: pendingValue
            });
            notifyHorizontalBarChange();
        }
    }

    Timer {
        id: exclusiveZoneDebounce
        interval: 100
        repeat: false
        property real pendingValue: 0
        onTriggered: {
            SettingsData.updateBarConfig(selectedBarId, {
                bottomGap: pendingValue
            });
            notifyHorizontalBarChange();
        }
    }

    Timer {
        id: sizeDebounce
        interval: 100
        repeat: false
        property real pendingValue: 4
        onTriggered: {
            SettingsData.updateBarConfig(selectedBarId, {
                innerPadding: pendingValue
            });
            notifyHorizontalBarChange();
        }
    }

    Timer {
        id: popupGapsManualDebounce
        interval: 100
        repeat: false
        property real pendingValue: 4
        onTriggered: {
            SettingsData.updateBarConfig(selectedBarId, {
                popupGapsManual: pendingValue
            });
            notifyHorizontalBarChange();
        }
    }

    Timer {
        id: gothCornerRadiusDebounce
        interval: 100
        repeat: false
        property real pendingValue: 12
        onTriggered: SettingsData.updateBarConfig(selectedBarId, {
            gothCornerRadiusValue: pendingValue
        })
    }

    Timer {
        id: borderOpacityDebounce
        interval: 100
        repeat: false
        property real pendingValue: 1.0
        onTriggered: SettingsData.updateBarConfig(selectedBarId, {
            borderOpacity: pendingValue
        })
    }

    Timer {
        id: borderThicknessDebounce
        interval: 100
        repeat: false
        property real pendingValue: 1
        onTriggered: SettingsData.updateBarConfig(selectedBarId, {
            borderThickness: pendingValue
        })
    }

    Timer {
        id: widgetOutlineOpacityDebounce
        interval: 100
        repeat: false
        property real pendingValue: 1.0
        onTriggered: SettingsData.updateBarConfig(selectedBarId, {
            widgetOutlineOpacity: pendingValue
        })
    }

    Timer {
        id: widgetOutlineThicknessDebounce
        interval: 100
        repeat: false
        property real pendingValue: 1
        onTriggered: SettingsData.updateBarConfig(selectedBarId, {
            widgetOutlineThickness: pendingValue
        })
    }

    Timer {
        id: barTransparencyDebounce
        interval: 100
        repeat: false
        property real pendingValue: 1.0
        onTriggered: {
            SettingsData.updateBarConfig(selectedBarId, {
                transparency: pendingValue
            });
            notifyHorizontalBarChange();
        }
    }

    Timer {
        id: widgetTransparencyDebounce
        interval: 100
        repeat: false
        property real pendingValue: 1.0
        onTriggered: {
            SettingsData.updateBarConfig(selectedBarId, {
                widgetTransparency: pendingValue
            });
            notifyHorizontalBarChange();
        }
    }

    Timer {
        id: fontScaleDebounce
        interval: 100
        repeat: false
        property real pendingValue: 1.0
        onTriggered: {
            SettingsData.updateBarConfig(selectedBarId, {
                fontScale: pendingValue
            });
            notifyHorizontalBarChange();
        }
    }

    function notifyHorizontalBarChange() {
        if (selectedBarIsVertical)
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
            fontScale: defaultBar.fontScale ?? 1.0,
            autoHide: defaultBar.autoHide ?? false,
            autoHideDelay: defaultBar.autoHideDelay ?? 250,
            openOnOverview: defaultBar.openOnOverview ?? false,
            visible: defaultBar.visible ?? true,
            popupGapsAuto: defaultBar.popupGapsAuto ?? true,
            popupGapsManual: defaultBar.popupGapsManual ?? 4,
            maximizeDetection: defaultBar.maximizeDetection ?? true
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
    }

    function getBarShowOnLastDisplay(barId) {
        const config = SettingsData.getBarConfig(barId);
        return config?.showOnLastDisplay ?? true;
    }

    function setBarShowOnLastDisplay(barId, value) {
        SettingsData.updateBarConfig(barId, {
            showOnLastDisplay: value
        });
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                iconName: "dashboard"
                title: I18n.tr("Bar Configurations")

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
                                    }

                                    Row {
                                        spacing: Theme.spacingS

                                        StyledText {
                                            text: {
                                                switch (barCard.modelData.position) {
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
                                        }

                                        StyledText {
                                            text: "•"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }

                                        StyledText {
                                            text: {
                                                const prefs = barCard.modelData.screenPreferences || ["all"];
                                                if (prefs.includes("all") || (typeof prefs[0] === "string" && prefs[0] === "all"))
                                                    return I18n.tr("All displays");
                                                return I18n.tr("%1 display(s)").replace("%1", prefs.length);
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }

                                        StyledText {
                                            text: "•"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }

                                        StyledText {
                                            text: {
                                                const left = barCard.modelData.leftWidgets?.length || 0;
                                                const center = barCard.modelData.centerWidgets?.length || 0;
                                                const right = barCard.modelData.rightWidgets?.length || 0;
                                                return I18n.tr("%1 widgets").replace("%1", left + center + right);
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }

                                        StyledText {
                                            text: "•"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            visible: !barCard.modelData.enabled && barCard.modelData.id !== "default"
                                        }

                                        StyledText {
                                            text: I18n.tr("Disabled")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.error
                                            visible: !barCard.modelData.enabled && barCard.modelData.id !== "default"
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
                visible: selectedBarConfig?.enabled

                StyledText {
                    width: parent.width
                    text: I18n.tr("Configure which displays show \"%1\"").replace("%1", selectedBarConfig?.name || "this bar")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
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
                            const wasVertical = selectedBarIsVertical;
                            SettingsData.updateBarConfig(selectedBarId, {
                                position: newPos
                            });
                            const isVertical = newPos === SettingsData.Position.Left || newPos === SettingsData.Position.Right;
                            if (wasVertical !== isVertical || !isVertical)
                                notifyHorizontalBarChange();
                        }
                    }
                }
            }

            SettingsCard {
                iconName: "visibility_off"
                title: I18n.tr("Visibility")
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
                            notifyHorizontalBarChange();
                        }

                        Binding {
                            target: hideDelaySlider
                            property: "value"
                            value: selectedBarConfig?.autoHideDelay ?? 250
                            restoreMode: Binding.RestoreBinding
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
                        notifyHorizontalBarChange();
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

            SettingsCard {
                iconName: "space_bar"
                title: I18n.tr("Spacing")
                visible: selectedBarConfig?.enabled

                SettingsSliderRow {
                    id: edgeSpacingSlider
                    text: I18n.tr("Edge Spacing")
                    value: selectedBarConfig?.spacing ?? 4
                    minimum: 0
                    maximum: 32
                    defaultValue: 4
                    onSliderValueChanged: newValue => {
                        edgeSpacingDebounce.pendingValue = newValue;
                        edgeSpacingDebounce.restart();
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
                    onSliderValueChanged: newValue => {
                        exclusiveZoneDebounce.pendingValue = newValue;
                        exclusiveZoneDebounce.restart();
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
                    onSliderValueChanged: newValue => {
                        sizeDebounce.pendingValue = newValue;
                        sizeDebounce.restart();
                    }

                    Binding {
                        target: sizeSlider
                        property: "value"
                        value: selectedBarConfig?.innerPadding ?? 4
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
                        notifyHorizontalBarChange();
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
                        onSliderValueChanged: newValue => {
                            popupGapsManualDebounce.pendingValue = newValue;
                            popupGapsManualDebounce.restart();
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

            SettingsCard {
                iconName: "rounded_corner"
                title: I18n.tr("Corners & Background")
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
                        onSliderValueChanged: newValue => {
                            gothCornerRadiusDebounce.pendingValue = newValue;
                            gothCornerRadiusDebounce.restart();
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
                    onSliderValueChanged: newValue => {
                        borderOpacityDebounce.pendingValue = newValue / 100;
                        borderOpacityDebounce.restart();
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
                    onSliderValueChanged: newValue => {
                        borderThicknessDebounce.pendingValue = newValue;
                        borderThicknessDebounce.restart();
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
                    onSliderValueChanged: newValue => {
                        widgetOutlineOpacityDebounce.pendingValue = newValue / 100;
                        widgetOutlineOpacityDebounce.restart();
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
                    onSliderValueChanged: newValue => {
                        widgetOutlineThicknessDebounce.pendingValue = newValue;
                        widgetOutlineThicknessDebounce.restart();
                    }

                    Binding {
                        target: widgetOutlineThicknessSlider
                        property: "value"
                        value: selectedBarConfig?.widgetOutlineThickness ?? 1
                        restoreMode: Binding.RestoreBinding
                    }
                }
            }

            SettingsCard {
                iconName: "opacity"
                title: I18n.tr("Transparency")
                visible: selectedBarConfig?.enabled

                SettingsSliderRow {
                    id: barTransparencySlider
                    text: I18n.tr("Bar Transparency")
                    value: (selectedBarConfig?.transparency ?? 1.0) * 100
                    minimum: 0
                    maximum: 100
                    unit: "%"
                    defaultValue: 100
                    onSliderValueChanged: newValue => {
                        barTransparencyDebounce.pendingValue = newValue / 100;
                        barTransparencyDebounce.restart();
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
                    onSliderValueChanged: newValue => {
                        widgetTransparencyDebounce.pendingValue = newValue / 100;
                        widgetTransparencyDebounce.restart();
                    }

                    Binding {
                        target: widgetTransparencySlider
                        property: "value"
                        value: (selectedBarConfig?.widgetTransparency ?? 1.0) * 100
                        restoreMode: Binding.RestoreBinding
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
                    fontScaleDebounce.pendingValue = newValue / 100;
                    fontScaleDebounce.restart();
                }

                Binding {
                    target: fontScaleSliderCard
                    property: "value"
                    value: Math.round((selectedBarConfig?.fontScale ?? 1.0) * 100)
                    restoreMode: Binding.RestoreBinding
                }
            }
        }
    }
}
