import QtQuick
import qs.Common
import qs.Services
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
            iconName: "layers"
            title: I18n.tr("Layers", "noun plural, dock settings card for overlay layer and fullscreen options")
            settingKey: "dockAdvanced"
            tags: ["dock", "advanced", "overlay", "fullscreen", "overview", "exclusive"]

            SettingsToggleRow {
                settingKey: "dockUseOverlayLayer"
                tags: ["dock", "fullscreen", "overlay", "layer"]
                resetStore: dock
                resetKeys: ["useOverlayLayer"]
                text: I18n.tr("Use overlay layer")
                checked: dock.config?.useOverlayLayer ?? false
                onToggled: checked => dock.setOption("useOverlayLayer", checked)
            }

            SettingsToggleRow {
                settingKey: "dockShowOnFullscreen"
                tags: ["dock", "fullscreen", "overlay", "show", "visibility"]
                resetStore: dock
                resetKeys: ["showOnFullscreen"]
                text: I18n.tr("Over fullscreen")
                checked: dock.config?.showOnFullscreen ?? false
                onToggled: checked => dock.setOption("showOnFullscreen", checked)
            }

            SettingsToggleRow {
                settingKey: "dockOpenOnOverview"
                tags: ["dock", "overview", "niri"]
                resetStore: dock
                resetKeys: ["openOnOverview"]
                text: I18n.tr("Show on overview")
                visible: CompositorService.isNiri
                checked: dock.config?.openOnOverview ?? false
                onToggled: checked => dock.setOption("openOnOverview", checked)
            }

            SettingsSliderRow {
                settingKey: "dockExclusiveZone"
                tags: ["exclusive", "zone", "reserved", "offset"]
                resetStore: dock
                resetKeys: ["bottomGap"]
                text: I18n.tr("Exclusive zone offset")
                visible: dock.reservesSpace
                value: dock.config?.bottomGap ?? 0
                minimum: -100
                maximum: 100
                unit: "px"
                onSliderValueChanged: value => dock.setOption("bottomGap", value)
            }
        }

        SettingsCard {
            width: parent.width
            visible: dock.hasConfig
            iconName: "monitor"
            title: I18n.tr("Displays")
            settingKey: "dockAdvancedDisplays"
            tags: ["dock", "isolate", "monitor", "multi-monitor"]

            SettingsToggleRow {
                settingKey: "dockIsolateDisplays"
                tags: ["dock", "isolate", "monitor", "multi-monitor"]
                resetStore: dock
                resetKeys: ["isolateDisplays"]
                text: I18n.tr("Isolate displays")
                checked: dock.config?.isolateDisplays ?? false
                onToggled: checked => dock.setOption("isolateDisplays", checked)
            }

            SettingsToggleRow {
                settingKey: "dockRestoreSpecialWorkspaceOnClick"
                tags: ["dock", "hyprland", "special", "workspace", "restore"]
                resetStore: dock
                resetKeys: ["restoreSpecialWorkspaceOnClick"]
                text: I18n.tr("Restore special workspace")
                visible: CompositorService.isHyprland
                checked: dock.config?.restoreSpecialWorkspaceOnClick ?? false
                onToggled: checked => dock.setOption("restoreSpecialWorkspaceOnClick", checked)
            }
        }
    }
}
