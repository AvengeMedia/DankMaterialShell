import QtQuick
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

    BarSelectionState {
        id: bar
    }

    readonly property var interactionModeValues: ["click", "hybrid"]

    function valueIndex(values, value, fallback) {
        const index = values.indexOf(value);
        return index >= 0 ? index : Math.max(0, values.indexOf(fallback));
    }

    function setBarScreenPreferences(barId, prefs) {
        SettingsData.updateBarConfig(barId, {
            screenPreferences: prefs
        });
        bar.notifyHorizontalBarChange();
    }

    function setBarShowOnLastDisplay(barId, value) {
        SettingsData.updateBarConfig(barId, {
            showOnLastDisplay: value
        });
        if (Quickshell.screens.length === 1)
            bar.notifyHorizontalBarChange();
    }

    SettingsPage {
        id: mainColumn

        SettingsCard {
            iconName: "vertical_align_center"
            title: I18n.tr("Position")
            settingKey: "barPosition"
            visible: bar.selectedBarConfig?.enabled

            SettingsRow {
                iconName: "info"
                iconColor: Theme.surfaceVariantText
                visible: bar.islandShadowedScreenCount > 0
                title: I18n.tr("%1 position", "bar info row title, %1 is the bar edge name").arg(bar.positionLabel(bar.selectedBarConfig?.position ?? SettingsData.Position.Top))
                subtitle: I18n.tr("The Island holds this edge on a display this bar covers, so the bar stays hidden there")
            }

            SettingsRow {
                body: Item {
                    width: parent.width
                    height: positionButtonGroup.height

                    DankButtonGroup {
                        id: positionButtonGroup
                        anchors.horizontalCenter: parent.horizontalCenter
                        model: bar.positionChoices.map(pos => bar.positionLabel(pos))
                        currentIndex: {
                            bar.selectedBarId;
                            const config = SettingsData.getBarConfig(bar.selectedBarId);
                            return bar.positionChoices.indexOf(config?.position ?? SettingsData.Position.Top);
                        }
                        onSelectionChanged: (index, selected) => {
                            if (!selected || index < 0 || index >= bar.positionChoices.length)
                                return;
                            SettingsData.updateBarConfig(bar.selectedBarId, {
                                position: bar.positionChoices[index]
                            });
                            bar.notifyHorizontalBarChange();
                        }
                    }
                }
            }

            SettingsToggleRow {
                settingKey: "islandFloating"
                tags: ["island", "placement", "float", "overlay", "exclusive", "reserve"]
                visible: bar.selectedBarIsIsland
                resetStore: bar
                resetKeys: ["islandFloating"]
                text: I18n.tr("Float", "island settings: float toggle")
                checked: bar.islandSetting("islandFloating")
                onToggled: checked => bar.apply("islandFloating", checked)
            }

            SettingsSliderRow {
                settingKey: "islandReserveThickness"
                tags: ["island", "placement", "reservation", "exclusive", "height", "width", "thickness"]
                visible: bar.selectedBarIsIsland
                resetStore: bar
                resetKeys: ["islandReserveThickness"]
                text: bar.selectedBarIsVertical ? I18n.tr("Reserved width", "island settings: reserved strip width slider") : I18n.tr("Reserved height", "island settings: reserved strip height slider")
                unit: "px"
                minimum: 24
                maximum: 128
                step: 1
                value: bar.islandSetting("islandReserveThickness")
                enabled: !bar.islandSetting("islandFloating")
                onSliderValueChanged: value => bar.apply("islandReserveThickness", value)
            }

            SettingsSliderRow {
                settingKey: "islandCompactThickness"
                tags: ["island", "placement", "compact", "height", "width", "thickness", "size", "satellite"]
                visible: bar.selectedBarIsIsland
                resetStore: bar
                resetKeys: ["islandCompactThickness"]
                text: bar.selectedBarIsVertical ? I18n.tr("Compact width", "island settings: compact pill width slider") : I18n.tr("Compact height", "island settings: compact pill height slider")
                unit: "px"
                minimum: 24
                maximum: 72
                step: 1
                value: bar.islandSetting("islandCompactThickness")
                onSliderValueChanged: value => bar.apply("islandCompactThickness", value)
            }

            SettingsSliderRow {
                settingKey: "islandOuterGap"
                tags: ["island", "placement", "gap", "top", "margin"]
                visible: bar.selectedBarIsIsland
                resetStore: bar
                resetKeys: ["islandOuterGap"]
                text: I18n.tr("Outer gap", "island settings: gap between screen edge and island")
                unit: "px"
                minimum: 0
                maximum: 48
                step: 1
                value: bar.islandSetting("islandOuterGap")
                onSliderValueChanged: value => bar.apply("islandOuterGap", value)
            }

            SettingsSliderRow {
                settingKey: "islandAlongOffset"
                tags: ["island", "placement", "horizontal", "vertical", "offset", "center"]
                visible: bar.selectedBarIsIsland
                resetStore: bar
                resetKeys: ["islandAlongOffset"]
                text: bar.selectedBarIsVertical ? I18n.tr("Vertical offset", "island settings: vertical offset slider") : I18n.tr("Horizontal offset", "island settings: horizontal offset slider")
                unit: "px"
                minimum: -600
                maximum: 600
                step: 1
                value: bar.islandSetting("islandAlongOffset")
                onSliderValueChanged: value => bar.apply("islandAlongOffset", value)
            }
        }

        SettingsCard {
            iconName: "display_settings"
            title: I18n.tr("Displays")
            settingKey: "barDisplay"
            collapsible: true
            expanded: true
            visible: bar.selectedBarConfig?.enabled

            SettingsDisplayPicker {
                displayPreferences: bar.selectedBarConfig?.screenPreferences || ["all"]
                emptyMeansAll: false
                allowEmpty: true
                showLastDisplay: true
                showOnLastDisplay: bar.selectedBarConfig?.showOnLastDisplay ?? true
                onPreferencesChanged: prefs => dankBarTab.setBarScreenPreferences(bar.selectedBarId, prefs)
                onLastDisplayToggled: checked => dankBarTab.setBarShowOnLastDisplay(bar.selectedBarId, checked)
            }
        }

        SettingsCard {
            iconName: "visibility"
            title: I18n.tr("Visibility", "settings card title for bar or dock show and hide behavior")
            settingKey: "barVisibility"
            collapsible: true
            expanded: true
            visible: (bar.selectedBarConfig?.enabled ?? false) && !bar.selectedBarIsIsland

            SettingsRow {
                iconName: "info"
                iconColor: Theme.surfaceVariantText
                visible: bar.islandShadowsSelectedBar
                title: I18n.tr("Bar visibility")
                subtitle: I18n.tr("The Island holds this edge on a display this bar covers, so the bar stays hidden there")
            }

            SettingsToggleRow {
                settingKey: "barAutoHide"
                tags: ["autohide", "auto-hide", "reveal", "intellihide"]
                visible: !bar.islandOwnsSelectedBarTop
                text: I18n.tr("Auto-hide", "toggle to automatically hide the bar or dock")
                resetStore: bar
                resetKeys: ["autoHide"]
                checked: bar.selectedBarConfig?.autoHide ?? false
                onToggled: toggled => {
                    SettingsData.updateBarConfig(bar.selectedBarId, {
                        autoHide: toggled
                    });
                    bar.notifyHorizontalBarChange();
                }
            }

            SettingsSliderRow {
                visible: (bar.selectedBarConfig?.autoHide ?? false) && !bar.islandOwnsSelectedBarTop
                text: I18n.tr("Hide delay")
                tags: ["autohide", "delay", "hide"]
                resetStore: bar
                resetKeys: ["autoHideDelay"]
                value: bar.selectedBarConfig?.autoHideDelay ?? 250
                minimum: 0
                maximum: 2000
                unit: "ms"
                onSliderValueChanged: newValue => SettingsData.updateBarConfig(bar.selectedBarId, {
                        autoHideDelay: newValue
                    })
            }

            SettingsToggleRow {
                settingKey: "barAutoHideStrict"
                visible: (bar.selectedBarConfig?.autoHide ?? false) && !bar.islandOwnsSelectedBarTop
                tags: ["autohide", "strict", "popout"]
                text: I18n.tr("Strict auto-hide", "Dank bar setting: hide the bar when the pointer leaves even if a menu or bar popover is still open")
                resetStore: bar
                resetKeys: ["autoHideStrict"]
                checked: bar.selectedBarConfig?.autoHideStrict ?? false
                onToggled: toggled => {
                    SettingsData.updateBarConfig(bar.selectedBarId, {
                        autoHideStrict: toggled
                    });
                    bar.notifyHorizontalBarChange();
                }
            }

            SettingsToggleRow {
                settingKey: "barHideWhenWindowsOpen"
                tags: ["hide", "windows", "empty", "workspace"]
                visible: (bar.selectedBarConfig?.autoHide ?? false) && !bar.islandOwnsSelectedBarTop && CompositorService.supportsBarAutoHideReveal
                text: I18n.tr("Hide when windows open")
                resetStore: bar
                resetKeys: ["showOnWindowsOpen"]
                checked: bar.selectedBarConfig?.showOnWindowsOpen ?? false
                onToggled: toggled => SettingsData.updateBarConfig(bar.selectedBarId, {
                        showOnWindowsOpen: toggled
                    })
            }

            SettingsToggleRow {
                settingKey: "barOpenOnOverview"
                tags: ["bar", "overview", "niri", "show", "frame"]
                visible: CompositorService.supportsNativeOverview && !bar.islandOwnsSelectedBarTop
                text: I18n.tr("Show on overview")
                resetStore: bar.selectedBarFrameStyled ? SettingsData : bar
                resetKeys: bar.selectedBarFrameStyled ? ["frameShowOnOverview"] : ["openOnOverview"]
                checked: bar.selectedBarFrameStyled ? SettingsData.frameShowOnOverview : (bar.selectedBarConfig?.openOnOverview ?? false)
                onToggled: toggled => {
                    if (bar.selectedBarFrameStyled) {
                        SettingsData.set("frameShowOnOverview", toggled);
                        return;
                    }
                    SettingsData.updateBarConfig(bar.selectedBarId, {
                        openOnOverview: toggled
                    });
                }
            }

            SettingsToggleRow {
                settingKey: "barManualVisibility"
                tags: ["manual", "show", "hide", "ipc", "toggle"]
                visible: !bar.islandOwnsSelectedBarTop
                text: I18n.tr("Manual show/hide")
                resetStore: bar
                resetKeys: ["visible"]
                checked: bar.selectedBarConfig?.visible ?? true
                onToggled: toggled => {
                    SettingsData.updateBarConfig(bar.selectedBarId, {
                        visible: toggled
                    });
                    bar.notifyHorizontalBarChange();
                }
            }
        }

        SettingsCard {
            iconName: "touch_app"
            title: I18n.tr("Behavior", "island settings: behavior card title")
            settingKey: "islandInteraction"
            tags: ["island", "interaction", "click", "hybrid", "expand", "hover", "delay"]
            visible: (bar.selectedBarConfig?.enabled ?? false) && bar.selectedBarIsIsland

            SettingsButtonGroupRow {
                settingKey: "islandInteractionMode"
                tags: ["island", "interaction", "click", "hybrid", "expand"]
                resetStore: bar
                resetKeys: ["islandInteractionMode"]
                text: I18n.tr("Expansion mode", "island settings: click or hover expansion row")
                model: [I18n.tr("Click", "island settings: click expansion mode"), I18n.tr("Hybrid", "island settings: hover plus click expansion mode")]
                currentIndex: dankBarTab.valueIndex(dankBarTab.interactionModeValues, bar.islandSetting("islandInteractionMode"), "hybrid")
                onSelectionChanged: (index, selected) => {
                    if (selected)
                        bar.apply("islandInteractionMode", dankBarTab.interactionModeValues[index] ?? "hybrid");
                }
            }

            SettingsRow {
                visible: bar.islandSetting("islandInteractionMode") !== "click"
                body: StyledText {
                    width: parent.width
                    text: I18n.tr("Hybrid peeks the current compact face on hover. Click pins a destination so it stays open", "island settings: hybrid mode hint")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }
            }

            SettingsSliderRow {
                settingKey: "islandHoverOpenDelay"
                tags: ["island", "interaction", "hover", "open", "delay"]
                resetStore: bar
                resetKeys: ["islandHoverOpenDelay"]
                text: I18n.tr("Open delay", "island settings: hover open delay slider")
                unit: "ms"
                minimum: 0
                maximum: 1000
                step: 10
                value: bar.islandSetting("islandHoverOpenDelay")
                visible: bar.islandSetting("islandInteractionMode") !== "click"
                onSliderValueChanged: value => bar.apply("islandHoverOpenDelay", value)
            }

            SettingsSliderRow {
                settingKey: "islandHoverCloseDelay"
                tags: ["island", "interaction", "hover", "close", "delay"]
                resetStore: bar
                resetKeys: ["islandHoverCloseDelay"]
                text: I18n.tr("Hide delay", "island settings: hover hide delay slider")
                unit: "ms"
                minimum: 0
                maximum: 1000
                step: 10
                value: bar.islandSetting("islandHoverCloseDelay")
                visible: bar.islandSetting("islandInteractionMode") !== "click"
                onSliderValueChanged: value => bar.apply("islandHoverCloseDelay", value)
            }

            SettingsToggleRow {
                settingKey: "islandMediaClockVisible"
                tags: ["island", "media", "clock", "compact", "time"]
                resetStore: bar
                resetKeys: ["islandMediaClockVisible"]
                text: I18n.tr("Keep clock with media", "island settings: clock in media face toggle")
                checked: bar.islandSetting("islandMediaClockVisible")
                onToggled: checked => bar.apply("islandMediaClockVisible", checked)
            }
        }

        SettingsToggleCard {
            settingKey: "hoverPopouts"
            resetStore: bar
            resetKeys: ["hoverPopouts"]
            tags: ["bar", "hover", "popout", "reveal", "widget", "delay"]
            iconName: "touch_app"
            title: I18n.tr("Hover popouts")
            visible: bar.selectedBarConfig?.enabled ?? false
            enabled: !(bar.selectedBarConfig?.clickThrough ?? false)
            opacity: (bar.selectedBarConfig?.clickThrough ?? false) ? 0.5 : 1.0
            checked: bar.selectedBarConfig?.hoverPopouts ?? false
            onToggled: checked => SettingsData.updateBarConfig(bar.selectedBarId, {
                    hoverPopouts: checked
                })

            Column {
                width: parent.width
                spacing: Theme.spacingS
                visible: bar.selectedBarConfig?.hoverPopouts ?? false
                leftPadding: Theme.spacingM

                SettingsSliderRow {
                    width: parent.width - parent.leftPadding
                    text: I18n.tr("Open delay")
                    resetStore: bar
                    resetKeys: ["hoverPopoutDelay"]
                    value: bar.selectedBarConfig?.hoverPopoutDelay ?? 150
                    minimum: 0
                    maximum: 1000
                    unit: "ms"
                    onSliderValueChanged: newValue => {
                        SettingsData.updateBarConfig(bar.selectedBarId, {
                            hoverPopoutDelay: newValue
                        });
                    }
                }
            }
        }

        SettingsToggleCard {
            iconName: "mouse"
            settingKey: "barScrollWheel"
            resetStore: bar
            resetKeys: ["scrollEnabled"]
            tags: ["scroll", "wheel", "workspace", "column", "axis"]
            title: I18n.tr("Scroll wheel")
            visible: (bar.selectedBarConfig?.enabled ?? false) && !bar.selectedBarIsIsland
            checked: bar.selectedBarConfig?.scrollEnabled ?? true
            onToggled: checked => SettingsData.updateBarConfig(bar.selectedBarId, {
                    scrollEnabled: checked
                })

            SettingsButtonGroupRow {
                text: I18n.tr("Y axis")
                resetStore: bar
                resetKeys: ["scrollYBehavior"]
                model: CompositorService.isNiri ? [I18n.tr("None"), I18n.tr("Workspace"), I18n.tr("Column", "noun, bar scroll behavior option, niri window column")] : [I18n.tr("None"), I18n.tr("Workspace")]
                buttonPadding: Theme.spacingS
                minButtonWidth: 44
                textSize: Theme.fontSizeSmall
                currentIndex: {
                    switch (bar.selectedBarConfig?.scrollYBehavior || "workspace") {
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
                    SettingsData.updateBarConfig(bar.selectedBarId, {
                        scrollYBehavior: behavior
                    });
                }
            }

            SettingsButtonGroupRow {
                text: I18n.tr("X axis")
                resetStore: bar
                resetKeys: ["scrollXBehavior"]
                visible: CompositorService.isNiri
                model: [I18n.tr("None"), I18n.tr("Workspace"), I18n.tr("Column")]
                buttonPadding: Theme.spacingS
                minButtonWidth: 44
                textSize: Theme.fontSizeSmall
                currentIndex: {
                    switch (bar.selectedBarConfig?.scrollXBehavior || "column") {
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
                    SettingsData.updateBarConfig(bar.selectedBarId, {
                        scrollXBehavior: behavior
                    });
                }
            }
        }

        SettingsCard {
            title: I18n.tr("Advanced")
            settingKey: "barAdvanced"
            tags: ["bar", "advanced", "overlay", "layer", "click", "through", "maximize", "island", "spring", "motion"]
            collapsible: true
            expanded: false
            visible: bar.selectedBarConfig?.enabled ?? false

            SettingsToggleRow {
                settingKey: "barClickThrough"
                resetStore: bar
                resetKeys: ["clickThrough"]
                tags: ["clickthrough", "click", "through", "mouse", "input", "mask", "passthrough"]
                visible: !bar.islandOwnsSelectedBarTop
                text: I18n.tr("Click through")
                checked: bar.selectedBarConfig?.clickThrough ?? false
                onToggled: toggled => SettingsData.updateBarConfig(bar.selectedBarId, {
                        clickThrough: toggled
                    })
            }

            SettingsToggleRow {
                settingKey: "barUseOverlayLayer"
                resetStore: bar
                resetKeys: ["useOverlayLayer"]
                tags: ["bar", "fullscreen", "overlay", "layer"]
                visible: !bar.islandOwnsSelectedBarTop
                text: I18n.tr("Use overlay layer")
                checked: bar.selectedBarConfig?.useOverlayLayer ?? false
                onToggled: toggled => {
                    SettingsData.updateBarConfig(bar.selectedBarId, {
                        useOverlayLayer: toggled
                    });
                    bar.notifyHorizontalBarChange();
                }
            }

            SettingsToggleRow {
                settingKey: "islandUseOverlayLayer"
                tags: ["island", "fullscreen", "overlay", "layer"]
                visible: bar.selectedBarIsIsland
                resetStore: bar
                resetKeys: ["islandUseOverlayLayer"]
                text: I18n.tr("Use overlay layer")
                checked: bar.islandSetting("islandUseOverlayLayer")
                onToggled: checked => bar.apply("islandUseOverlayLayer", checked)
            }

            SettingsToggleRow {
                settingKey: "islandReducedMotion"
                tags: ["island", "motion", "animation", "reduce", "accessibility", "spring"]
                visible: bar.selectedBarIsIsland
                resetStore: bar
                resetKeys: ["islandReducedMotion"]
                text: I18n.tr("Reduce motion")
                checked: bar.islandSetting("islandReducedMotion")
                onToggled: checked => bar.apply("islandReducedMotion", checked)
            }

            SettingsSliderRow {
                settingKey: "islandSpringStiffness"
                tags: ["island", "motion", "spring", "stiffness", "animation"]
                visible: bar.selectedBarIsIsland
                resetStore: bar
                resetKeys: ["islandSpringStiffness"]
                text: I18n.tr("Spring stiffness", "island settings: spring stiffness slider")
                unit: ""
                minimum: 100
                maximum: 1200
                step: 10
                value: Math.round(bar.islandSetting("islandSpringStiffness"))
                enabled: !bar.islandSetting("islandReducedMotion")
                onSliderValueChanged: value => bar.apply("islandSpringStiffness", value)
            }

            SettingsSliderRow {
                settingKey: "islandSpringDamping"
                tags: ["island", "motion", "spring", "damping", "bounce", "animation"]
                visible: bar.selectedBarIsIsland
                resetStore: bar
                resetKeys: ["islandSpringDamping"]
                text: I18n.tr("Spring damping", "island settings: spring damping slider")
                unit: ""
                minimum: 10
                maximum: 100
                step: 1
                value: Math.round(bar.islandSetting("islandSpringDamping"))
                enabled: !bar.islandSetting("islandReducedMotion")
                onSliderValueChanged: value => bar.apply("islandSpringDamping", value)
            }

            SettingsSliderRow {
                settingKey: "islandSpringMass"
                tags: ["island", "motion", "spring", "mass", "inertia", "animation"]
                visible: bar.selectedBarIsIsland
                resetStore: bar
                resetKeys: ["islandSpringMass"]
                text: I18n.tr("Spring mass", "island settings: spring mass slider")
                minimum: 25
                maximum: 300
                step: 5
                unit: ""
                decimals: 2
                value: Math.round(bar.islandSetting("islandSpringMass") * 100)
                enabled: !bar.islandSetting("islandReducedMotion")
                onSliderValueChanged: value => bar.apply("islandSpringMass", value / 100)
            }

            SettingsToggleRow {
                settingKey: "barMaximizeDetection"
                resetStore: bar
                resetKeys: ["maximizeDetection"]
                tags: ["maximize", "gaps", "border", "fullscreen"]
                visible: CompositorService.supportsBarAutoHideReveal
                text: I18n.tr("Maximize detection")
                checked: bar.selectedBarConfig?.maximizeDetection ?? true
                onToggled: toggled => SettingsData.updateBarConfig(bar.selectedBarId, {
                        maximizeDetection: toggled
                    })
            }
        }
    }
}
