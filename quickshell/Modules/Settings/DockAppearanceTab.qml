import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    property var parentModal: null

    DockSelectionState {
        id: dock
    }

    SettingsPage {
        SettingsCard {
            width: parent.width
            visible: dock.hasConfig
            iconName: "photo_size_select_large"
            title: I18n.tr("Size")
            settingKey: "dockSizing"
            tags: ["dock", "size", "icon", "spacing", "padding", "margin", "thickness"]

            SettingsSliderRow {
                settingKey: "dockIconSize"
                tags: ["dock", "icon", "size", "scale"]
                resetStore: dock
                resetKeys: ["iconSize"]
                text: I18n.tr("Icon size")
                value: dock.config?.iconSize ?? 42
                minimum: 24
                maximum: 96
                unit: "px"
                onSliderValueChanged: value => dock.setOption("iconSize", value)
            }

            SettingsSliderRow {
                settingKey: "dockItemSpacing"
                tags: ["dock", "spacing", "icon", "widget", "gap"]
                resetStore: dock
                resetKeys: ["itemSpacing"]
                text: I18n.tr("Spacing", "slider label, gap between dock items")
                value: dock.config?.itemSpacing ?? 8
                minimum: 0
                maximum: 32
                unit: "px"
                onSliderValueChanged: value => dock.setOption("itemSpacing", value)
            }

            SettingsSliderRow {
                settingKey: "dockSpacing"
                tags: ["dock", "spacing", "padding"]
                resetStore: dock
                resetKeys: ["spacing"]
                text: I18n.tr("Padding", "noun, spacing setting label")
                value: dock.config?.spacing ?? 8
                minimum: 0
                maximum: 32
                unit: "px"
                onSliderValueChanged: value => dock.setOption("spacing", value)
            }

            SettingsSliderRow {
                settingKey: "dockMargin"
                tags: ["dock", "margin", "edge", "gap"]
                resetStore: dock
                resetKeys: ["margin"]
                text: I18n.tr("Margin", "slider label, gap between dock and screen edge")
                visible: !dock.connectedFrameModeActive
                value: dock.config?.margin ?? 8
                minimum: 0
                maximum: 100
                unit: "px"
                onSliderValueChanged: value => dock.setOption("margin", value)
            }
        }

        SettingsControlledBy {
            visible: dock.hasConfig && !dock.connectedFrameModeActive
            target: "surfaces"
            parentModal: root.parentModal
            section: "surfaceOpacity_dock_" + dock.selectedDockId
            settingLabel: I18n.tr("Opacity")
        }

        SettingsToggleCard {
            width: parent.width
            visible: dock.hasConfig && !dock.connectedFrameModeActive
            iconName: "border_style"
            settingKey: "dockBorder"
            tags: ["dock", "border", "outline"]
            resetStore: dock
            resetKeys: ["borderEnabled"]
            title: I18n.tr("Border")
            checked: dock.config?.borderEnabled ?? false
            onToggled: checked => dock.setOption("borderEnabled", checked)

            SettingsButtonGroupRow {
                resetStore: dock
                resetKeys: ["borderColor"]
                readonly property var colors: ["surfaceText", "secondary", "primary"]

                text: I18n.tr("Color", "noun, settings label for choosing a border, shadow or frame color")
                model: [I18n.tr("Surface", "color option"), I18n.tr("Secondary", "color option"), I18n.tr("Primary", "color option")]
                buttonPadding: Theme.spacingS
                minButtonWidth: 44
                textSize: Theme.fontSizeSmall
                currentIndex: Math.max(0, colors.indexOf(dock.config?.borderColor ?? "surfaceText"))
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    dock.setOption("borderColor", colors[index]);
                }
            }

            SettingsSliderRow {
                resetStore: dock
                resetKeys: ["borderOpacity"]
                text: I18n.tr("Opacity")
                value: Math.round((dock.config?.borderOpacity ?? 1) * 100)
                minimum: 0
                maximum: 100
                onSliderValueChanged: value => dock.setOption("borderOpacity", value / 100)
            }

            SettingsSliderRow {
                resetStore: dock
                resetKeys: ["borderThickness"]
                text: I18n.tr("Thickness", "slider label, border or outline width in pixels")
                value: dock.config?.borderThickness ?? 1
                minimum: 1
                maximum: 10
                unit: "px"
                onSliderValueChanged: value => dock.setOption("borderThickness", value)
            }
        }

        SettingsControlledBy {
            visible: dock.connectedFrameModeActive
            parentModal: root.parentModal
            section: "frameBorder"
            settingLabel: I18n.tr("Dock margin, opacity, and border")
            reason: I18n.tr("Managed by Frame in Connected Mode")
        }
    }
}
