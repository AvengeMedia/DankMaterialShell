import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

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
                width: parent.width
                iconName: "swap_vert"
                title: I18n.tr("Dock Position")

                SettingsButtonGroupRow {
                    text: I18n.tr("Position")
                    model: ["Top", "Bottom", "Left", "Right"]
                    currentIndex: {
                        switch (SettingsData.dockPosition) {
                        case SettingsData.Position.Top:
                            return 0;
                        case SettingsData.Position.Bottom:
                            return 1;
                        case SettingsData.Position.Left:
                            return 2;
                        case SettingsData.Position.Right:
                            return 3;
                        default:
                            return 1;
                        }
                    }
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        switch (index) {
                        case 0:
                            SettingsData.setDockPosition(SettingsData.Position.Top);
                            break;
                        case 1:
                            SettingsData.setDockPosition(SettingsData.Position.Bottom);
                            break;
                        case 2:
                            SettingsData.setDockPosition(SettingsData.Position.Left);
                            break;
                        case 3:
                            SettingsData.setDockPosition(SettingsData.Position.Right);
                            break;
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "dock_to_bottom"
                title: I18n.tr("Dock Visibility")

                SettingsToggleRow {
                    text: I18n.tr("Show Dock")
                    description: I18n.tr("Display a dock with pinned and running applications")
                    checked: SettingsData.showDock
                    onToggled: checked => SettingsData.setShowDock(checked)
                }

                SettingsToggleRow {
                    text: I18n.tr("Auto-hide Dock")
                    description: I18n.tr("Hide the dock when not in use and reveal it when hovering near the dock area")
                    checked: SettingsData.dockAutoHide
                    visible: SettingsData.showDock
                    onToggled: checked => SettingsData.set("dockAutoHide", checked)
                }

                SettingsToggleRow {
                    text: I18n.tr("Show on Overview")
                    description: I18n.tr("Always show the dock when niri's overview is open")
                    checked: SettingsData.dockOpenOnOverview
                    visible: CompositorService.isNiri
                    onToggled: checked => SettingsData.set("dockOpenOnOverview", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "apps"
                title: I18n.tr("Behavior")

                SettingsToggleRow {
                    text: I18n.tr("Group by App")
                    description: I18n.tr("Group multiple windows of the same app together with a window count indicator")
                    checked: SettingsData.dockGroupByApp
                    onToggled: checked => SettingsData.set("dockGroupByApp", checked)
                }

                SettingsButtonGroupRow {
                    text: I18n.tr("Indicator Style")
                    model: ["Circle", "Line"]
                    currentIndex: SettingsData.dockIndicatorStyle === "circle" ? 0 : 1
                    onSelectionChanged: (index, selected) => {
                        if (selected) {
                            SettingsData.set("dockIndicatorStyle", index === 0 ? "circle" : "line");
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "photo_size_select_large"
                title: I18n.tr("Sizing")

                SettingsSliderRow {
                    text: I18n.tr("Icon Size")
                    value: SettingsData.dockIconSize
                    minimum: 24
                    maximum: 96
                    defaultValue: 48
                    onSliderValueChanged: newValue => SettingsData.set("dockIconSize", newValue)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "space_bar"
                title: I18n.tr("Spacing")

                SettingsSliderRow {
                    text: I18n.tr("Padding")
                    value: SettingsData.dockSpacing
                    minimum: 0
                    maximum: 32
                    defaultValue: 8
                    onSliderValueChanged: newValue => SettingsData.set("dockSpacing", newValue)
                }

                SettingsSliderRow {
                    text: I18n.tr("Exclusive Zone Offset")
                    value: SettingsData.dockBottomGap
                    minimum: -100
                    maximum: 100
                    defaultValue: 0
                    onSliderValueChanged: newValue => SettingsData.set("dockBottomGap", newValue)
                }

                SettingsSliderRow {
                    text: I18n.tr("Margin")
                    value: SettingsData.dockMargin
                    minimum: 0
                    maximum: 100
                    defaultValue: 0
                    onSliderValueChanged: newValue => SettingsData.set("dockMargin", newValue)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "opacity"
                title: I18n.tr("Transparency")

                SettingsSliderRow {
                    text: I18n.tr("Dock Transparency")
                    value: Math.round(SettingsData.dockTransparency * 100)
                    minimum: 0
                    maximum: 100
                    unit: "%"
                    defaultValue: 85
                    onSliderValueChanged: newValue => SettingsData.set("dockTransparency", newValue / 100)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "border_style"
                title: I18n.tr("Border")

                SettingsToggleRow {
                    text: I18n.tr("Border")
                    description: I18n.tr("Add a border around the dock")
                    checked: SettingsData.dockBorderEnabled
                    onToggled: checked => SettingsData.set("dockBorderEnabled", checked)
                }

                SettingsButtonGroupRow {
                    text: I18n.tr("Border Color")
                    description: I18n.tr("Choose the border accent color")
                    visible: SettingsData.dockBorderEnabled
                    model: ["Surface", "Secondary", "Primary"]
                    currentIndex: {
                        switch (SettingsData.dockBorderColor) {
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
                        switch (index) {
                        case 0:
                            SettingsData.set("dockBorderColor", "surfaceText");
                            break;
                        case 1:
                            SettingsData.set("dockBorderColor", "secondary");
                            break;
                        case 2:
                            SettingsData.set("dockBorderColor", "primary");
                            break;
                        }
                    }
                }

                SettingsSliderRow {
                    text: I18n.tr("Border Opacity")
                    visible: SettingsData.dockBorderEnabled
                    value: SettingsData.dockBorderOpacity * 100
                    minimum: 0
                    maximum: 100
                    unit: "%"
                    defaultValue: 100
                    onSliderValueChanged: newValue => SettingsData.set("dockBorderOpacity", newValue / 100)
                }

                SettingsSliderRow {
                    text: I18n.tr("Border Thickness")
                    visible: SettingsData.dockBorderEnabled
                    value: SettingsData.dockBorderThickness
                    minimum: 1
                    maximum: 10
                    unit: "px"
                    defaultValue: 1
                    onSliderValueChanged: newValue => SettingsData.set("dockBorderThickness", newValue)
                }
            }
        }
    }
}
