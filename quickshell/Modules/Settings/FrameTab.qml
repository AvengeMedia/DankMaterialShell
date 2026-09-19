pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    // Bar Inset Padding: resolve the "auto" sentinel (stored < 0) to the frame thickness for the slider display.
    readonly property int frameInsetPaddingDisplay: Math.round(SettingsData.frameBarContentGap)

    SettingsPage {
        id: mainColumn

        SettingsCard {
            width: parent.width
            iconName: "tune"
            title: I18n.tr("Behavior")
            settingKey: "frameEnabled"
            tags: ["frame", "mode", "bar", "overview"]
            visible: SettingsData.frameEnabled

            SettingsButtonGroupRow {
                settingKey: "frameModeSelector"
                tags: ["frame", "mode", "connected", "separate", "popout", "flush", "float"]
                resetKeys: ["frameMode"]
                text: I18n.tr("Surfaces")
                model: [I18n.tr("Separate", "adjective, frame surfaces mode option, opposite of connected"), I18n.tr("Connected")]
                currentIndex: SettingsData.frameMode === "connected" ? 1 : 0
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    switch (index) {
                    case 1:
                        SettingsData.set("frameMode", "connected");
                        break;
                    default:
                        SettingsData.set("frameMode", "separate");
                        break;
                    }
                }
            }

            SettingsToggleRow {
                settingKey: "frameShowOnOverview"
                tags: ["frame", "overview", "show", "hide", "niri"]
                text: I18n.tr("Show on overview")
                visible: CompositorService.supportsNativeOverview
                checked: SettingsData.frameShowOnOverview
                onToggled: checked => SettingsData.set("frameShowOnOverview", checked)
            }
        }

        SettingsCard {
            width: parent.width
            iconName: "border_outer"
            title: I18n.tr("Border")
            settingKey: "frameBorder"
            collapsible: true
            visible: SettingsData.frameEnabled

            SettingsSliderRow {
                settingKey: "frameRounding"
                tags: ["frame", "border", "rounding", "radius", "corner"]
                text: I18n.tr("Radius", "corner radius slider label")
                unit: "px"
                minimum: 0
                maximum: 100
                step: 1
                value: SettingsData.frameRounding
                onSliderDragFinished: v => SettingsData.set("frameRounding", v)
            }

            SettingsSliderRow {
                settingKey: "frameThickness"
                tags: ["frame", "border", "thickness", "size", "width"]
                text: I18n.tr("Width")
                unit: "px"
                minimum: 2
                maximum: 100
                step: 1
                value: SettingsData.frameThickness
                onSliderDragFinished: v => SettingsData.set("frameThickness", v)
            }

            SettingsSliderRow {
                settingKey: "frameBarSize"
                tags: ["frame", "bar", "thickness", "size", "height", "width"]
                text: I18n.tr("Bar size")
                unit: "px"
                minimum: 24
                maximum: 100
                step: 1
                value: SettingsData.frameBarSize
                onSliderDragFinished: v => SettingsData.set("frameBarSize", v)
            }

            SettingsSliderRow {
                settingKey: "frameBarInsetPadding"
                tags: ["frame", "bar", "edge", "inset", "padding", "corner", "end"]
                text: I18n.tr("Bar inset padding")
                minimumLabel: I18n.tr("Edge to edge", "slider minimum label, bar touches the screen edges")
                unit: "px"
                minimum: 0
                maximum: 48
                step: 1
                value: root.frameInsetPaddingDisplay
                onSliderDragFinished: v => SettingsData.set("frameBarInsetPadding", v)
            }

            SettingsToggleRow {
                id: frameBlurToggle
                settingKey: "frameBlurEnabled"
                tags: ["frame", "blur", "background", "glass", "transparency", "frosted"]
                text: I18n.tr("Blur")
                checked: SettingsData.frameBlurEnabled
                onToggled: checked => SettingsData.set("frameBlurEnabled", checked)
                enabled: BlurService.available && SettingsData.blurEnabled
                visible: BlurService.available
            }

            SettingsRow {
                visible: BlurService.available && !SettingsData.blurEnabled
                body: Item {
                    width: parent.width
                    height: blurToggleNote.height + Theme.spacingM * 2

                    Row {
                        id: blurToggleNote
                        x: Theme.spacingM
                        width: parent.width - Theme.spacingM * 2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "blur_on"
                            size: Theme.fontSizeMedium
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Frame Blur follows Background Blur in Theme & Colors")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            width: parent.width - Theme.fontSizeMedium - Theme.spacingS
                        }
                    }
                }
            }
        }

        SettingsCard {
            width: parent.width
            iconName: "blur_linear"
            title: I18n.tr("Connected")
            settingKey: "frameConnectedOptions"
            collapsible: true
            expanded: true
            visible: SettingsData.frameEnabled && SettingsData.frameMode === "connected"

            SettingsToggleRow {
                settingKey: "frameCloseGaps"
                tags: ["frame", "connected", "gap", "edge", "curves", "arcs", "expose", "popout", "notification"]
                text: I18n.tr("Expose the arcs")
                checked: !SettingsData.frameCloseGaps
                onToggled: checked => SettingsData.set("frameCloseGaps", !checked)
            }

            SettingsButtonGroupRow {
                settingKey: "frameLauncherEmergeSide"
                tags: ["frame", "connected", "launcher", "modal", "emerge", "direction", "bottom", "top"]
                text: I18n.tr("Launcher emerge side")
                model: [I18n.tr("Bottom"), I18n.tr("Top")]
                currentIndex: SettingsData.frameLauncherEmergeSide === "top" ? 1 : 0
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    SettingsData.set("frameLauncherEmergeSide", index === 1 ? "top" : "bottom");
                }
            }

            SettingsToggleRow {
                settingKey: "frameLauncherArcExtender"
                tags: ["frame", "connected", "launcher", "arc", "extender", "center"]
                text: I18n.tr("Arc extender")
                checked: SettingsData.frameLauncherArcExtender
                onToggled: checked => SettingsData.set("frameLauncherArcExtender", checked)
            }

            SettingsToggleRow {
                settingKey: "frameLauncherEdgeHover"
                tags: ["frame", "connected", "launcher", "hover", "edge", "reveal"]
                text: I18n.tr("Edge hover reveal")
                checked: SettingsData.frameLauncherEdgeHover
                onToggled: checked => SettingsData.set("frameLauncherEdgeHover", checked)
            }
        }

        SettingsCard {
            width: parent.width
            iconName: "monitor"
            title: I18n.tr("Displays")
            settingKey: "frameDisplays"
            collapsible: true
            expanded: false
            visible: SettingsData.frameEnabled

            SettingsDisplayPicker {
                displayPreferences: SettingsData.frameScreenPreferences
                onPreferencesChanged: prefs => SettingsData.set("frameScreenPreferences", prefs)
            }
        }
    }
}
