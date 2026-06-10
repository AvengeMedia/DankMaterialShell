import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Settings.Widgets

SettingsCard {
    iconName: "palette"
    title: I18n.tr("Workspace Appearance")
    settingKey: "workspaceAppearance"
    collapsible: true
    expanded: false

    SettingsButtonGroupRow {
        text: I18n.tr("Focused Color")
        model: ["pri", "s", "sc", "sch", "none"]
        buttonHeight: 22
        minButtonWidth: 36
        buttonPadding: Theme.spacingS
        checkIconSize: Theme.iconSizeSmall - 2
        textSize: Theme.fontSizeSmall - 1
        spacing: 1
        currentIndex: {
            switch (SettingsData.workspaceColorMode) {
            case "s":
                return 1;
            case "sc":
                return 2;
            case "sch":
                return 3;
            case "none":
                return 4;
            default:
                return 0;
            }
        }
        onSelectionChanged: (index, selected) => {
            if (!selected)
                return;
            const modes = ["default", "s", "sc", "sch", "none"];
            SettingsData.set("workspaceColorMode", modes[index]);
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.15
    }

    SettingsButtonGroupRow {
        text: I18n.tr("Occupied Color")
        model: ["none", "sec", "s", "sc", "sch", "schh"]
        visible: CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango
        buttonHeight: 22
        minButtonWidth: 36
        buttonPadding: Theme.spacingS
        checkIconSize: Theme.iconSizeSmall - 2
        textSize: Theme.fontSizeSmall - 1
        spacing: 1
        currentIndex: {
            switch (SettingsData.workspaceOccupiedColorMode) {
            case "sec":
                return 1;
            case "s":
                return 2;
            case "sc":
                return 3;
            case "sch":
                return 4;
            case "schh":
                return 5;
            default:
                return 0;
            }
        }
        onSelectionChanged: (index, selected) => {
            if (!selected)
                return;
            const modes = ["none", "sec", "s", "sc", "sch", "schh"];
            SettingsData.set("workspaceOccupiedColorMode", modes[index]);
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.15
        visible: CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango
    }

    SettingsButtonGroupRow {
        text: I18n.tr("Unfocused Color")
        model: ["def", "s", "sc", "sch"]
        buttonHeight: 22
        minButtonWidth: 36
        buttonPadding: Theme.spacingS
        checkIconSize: Theme.iconSizeSmall - 2
        textSize: Theme.fontSizeSmall - 1
        spacing: 1
        currentIndex: {
            switch (SettingsData.workspaceUnfocusedColorMode) {
            case "s":
                return 1;
            case "sc":
                return 2;
            case "sch":
                return 3;
            default:
                return 0;
            }
        }
        onSelectionChanged: (index, selected) => {
            if (!selected)
                return;
            const modes = ["default", "s", "sc", "sch"];
            SettingsData.set("workspaceUnfocusedColorMode", modes[index]);
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.15
        visible: CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango || CompositorService.isSway || CompositorService.isScroll || CompositorService.isMiracle
    }

    SettingsButtonGroupRow {
        text: I18n.tr("Urgent Color")
        visible: CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango || CompositorService.isSway || CompositorService.isScroll || CompositorService.isMiracle
        model: ["err", "pri", "sec", "s", "sc"]
        buttonHeight: 22
        minButtonWidth: 36
        buttonPadding: Theme.spacingS
        checkIconSize: Theme.iconSizeSmall - 2
        textSize: Theme.fontSizeSmall - 1
        spacing: 1
        currentIndex: {
            switch (SettingsData.workspaceUrgentColorMode) {
            case "primary":
                return 1;
            case "secondary":
                return 2;
            case "s":
                return 3;
            case "sc":
                return 4;
            default:
                return 0;
            }
        }
        onSelectionChanged: (index, selected) => {
            if (!selected)
                return;
            const modes = ["default", "primary", "secondary", "s", "sc"];
            SettingsData.set("workspaceUrgentColorMode", modes[index]);
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.15
    }

    SettingsToggleRow {
        settingKey: "workspaceFocusedBorderEnabled"
        tags: ["workspace", "border", "outline", "focused", "ring"]
        text: I18n.tr("Focused Border")
        description: I18n.tr("Show an outline ring around the focused workspace indicator")
        checked: SettingsData.workspaceFocusedBorderEnabled
        onToggled: checked => SettingsData.set("workspaceFocusedBorderEnabled", checked)
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: SettingsData.workspaceFocusedBorderEnabled
        leftPadding: Theme.spacingM

        SettingsButtonGroupRow {
            width: parent.width - parent.leftPadding
            text: I18n.tr("Border Color")
            model: [I18n.tr("Surface"), I18n.tr("Secondary"), I18n.tr("Primary")]
            currentIndex: {
                switch (SettingsData.workspaceFocusedBorderColor) {
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
                SettingsData.set("workspaceFocusedBorderColor", newColor);
            }
        }

        SettingsSliderRow {
            width: parent.width - parent.leftPadding
            text: I18n.tr("Thickness")
            value: SettingsData.workspaceFocusedBorderThickness
            minimum: 1
            maximum: 6
            unit: "px"
            defaultValue: 2
            onSliderValueChanged: newValue => SettingsData.set("workspaceFocusedBorderThickness", newValue)
        }
    }
}
