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
                width: parent.width
                iconName: "frame_source"
                title: I18n.tr("Frame")
                settingKey: "frameEnabled"

                SettingsToggleRow {
                    settingKey: "frameEnable"
                    tags: ["frame", "border", "outline", "display"]
                    text: I18n.tr("Enable Frame")
                    description: I18n.tr("Draw a connected picture-frame border around the entire display")
                    checked: SettingsData.frameEnabled
                    onToggled: checked => SettingsData.set("frameEnabled", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "tune"
                title: I18n.tr("Mode")
                settingKey: "frameMode"
                visible: SettingsData.frameEnabled

                SettingsButtonGroupRow {
                    settingKey: "frameModeSelector"
                    tags: ["frame", "mode", "connected", "separate", "popout"]
                    text: I18n.tr("Surface Behavior")
                    description: SettingsData.frameMode === "connected" ? I18n.tr("Surfaces emerge flush from the bar") : I18n.tr("Surfaces float independently of the frame")
                    model: [I18n.tr("Separate"), I18n.tr("Connected")]
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
            }

            SettingsCard {
                width: parent.width
                iconName: "border_outer"
                title: I18n.tr("Border")
                settingKey: "frameBorder"
                collapsible: true
                visible: SettingsData.frameEnabled

                SettingsSliderRow {
                    id: roundingSlider
                    settingKey: "frameRounding"
                    tags: ["frame", "border", "rounding", "radius", "corner"]
                    text: I18n.tr("Border Radius")
                    unit: "px"
                    minimum: 0
                    maximum: 100
                    step: 1
                    defaultValue: 23
                    value: SettingsData.frameRounding
                    onSliderDragFinished: v => SettingsData.set("frameRounding", v)

                    Binding {
                        target: roundingSlider
                        property: "value"
                        value: SettingsData.frameRounding
                    }
                }

                SettingsSliderRow {
                    id: thicknessSlider
                    settingKey: "frameThickness"
                    tags: ["frame", "border", "thickness", "size", "width"]
                    text: I18n.tr("Border Width")
                    unit: "px"
                    minimum: 2
                    maximum: 100
                    step: 1
                    defaultValue: 16
                    value: SettingsData.frameThickness
                    onSliderDragFinished: v => SettingsData.set("frameThickness", v)

                    Binding {
                        target: thicknessSlider
                        property: "value"
                        value: SettingsData.frameThickness
                    }
                }

                SettingsSliderRow {
                    id: barThicknessSlider
                    settingKey: "frameBarSize"
                    tags: ["frame", "bar", "thickness", "size", "height", "width"]
                    text: I18n.tr("Size")
                    description: I18n.tr("Horizontal and vertical bar thickness")
                    unit: "px"
                    minimum: 24
                    maximum: 100
                    step: 1
                    defaultValue: 40
                    value: SettingsData.frameBarSize
                    onSliderDragFinished: v => SettingsData.set("frameBarSize", v)

                    Binding {
                        target: barThicknessSlider
                        property: "value"
                        value: SettingsData.frameBarSize
                    }
                }

                SettingsSliderRow {
                    id: opacitySlider
                    settingKey: "frameOpacity"
                    tags: ["frame", "border", "surface", "popup", "opacity", "transparency"]
                    text: I18n.tr("Surface Opacity")
                    unit: "%"
                    minimum: 0
                    maximum: 100
                    defaultValue: 100
                    value: SettingsData.frameOpacity * 100
                    onSliderDragFinished: v => SettingsData.set("frameOpacity", v / 100)

                    Binding {
                        target: opacitySlider
                        property: "value"
                        value: SettingsData.frameOpacity * 100
                    }
                }

                SettingsToggleRow {
                    id: frameBlurToggle
                    settingKey: "frameBlurEnabled"
                    tags: ["frame", "blur", "background", "glass", "transparency", "frosted"]
                    text: I18n.tr("Frame Blur")
                    description: !BlurService.available ? I18n.tr("Requires a newer version of Quickshell") : I18n.tr("Apply compositor blur behind the frame border")
                    checked: SettingsData.frameBlurEnabled
                    onToggled: checked => SettingsData.set("frameBlurEnabled", checked)
                    enabled: BlurService.available && SettingsData.blurEnabled
                    opacity: enabled ? 1.0 : 0.5
                    visible: BlurService.available
                }

                Item {
                    visible: BlurService.available && !SettingsData.blurEnabled
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

                SettingsButtonGroupRow {
                    settingKey: "frameColor"
                    tags: ["frame", "border", "color", "theme", "primary", "surface", "default"]
                    text: I18n.tr("Border Color")
                    model: [I18n.tr("Default"), I18n.tr("Primary"), I18n.tr("Surface"), I18n.tr("Custom")]
                    currentIndex: {
                        const fc = SettingsData.frameColor;
                        if (!fc || fc === "default")
                            return 0;
                        switch (fc) {
                        case "primary":
                            return 1;
                        case "surface":
                            return 2;
                        default:
                            return 3;
                        }
                    }
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        switch (index) {
                        case 0:
                            SettingsData.set("frameColor", "");
                            break;
                        case 1:
                            SettingsData.set("frameColor", "primary");
                            break;
                        case 2:
                            SettingsData.set("frameColor", "surface");
                            break;
                        case 3:
                            const cur = SettingsData.frameColor;
                            const isPreset = !cur || cur === "primary" || cur === "surface";
                            if (isPreset)
                                SettingsData.set("frameColor", "#2a2a2a");
                            break;
                        }
                    }
                }

                Item {
                    visible: {
                        const fc = SettingsData.frameColor;
                        return !!(fc && fc !== "primary" && fc !== "surface");
                    }
                    width: parent.width
                    height: customColorRow.height + Theme.spacingM * 2

                    Row {
                        id: customColorRow
                        width: parent.width - Theme.spacingM * 2
                        x: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Custom Color")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 32
                            radius: 16
                            color: SettingsData.effectiveFrameColor
                            border.color: Theme.outline
                            border.width: 1

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    PopoutService.colorPickerModal.selectedColor = SettingsData.effectiveFrameColor;
                                    PopoutService.colorPickerModal.pickerTitle = I18n.tr("Frame Border Color");
                                    PopoutService.colorPickerModal.onColorSelectedCallback = function (color) {
                                        SettingsData.set("frameColor", color.toString());
                                    };
                                    PopoutService.colorPickerModal.show();
                                }
                            }
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "blur_linear"
                title: I18n.tr("Connected Options")
                settingKey: "frameConnectedOptions"
                collapsible: true
                expanded: true
                visible: SettingsData.frameEnabled && SettingsData.frameMode === "connected"

                SettingsToggleRow {
                    settingKey: "frameCloseGaps"
                    tags: ["frame", "connected", "gap", "edge", "curves", "arcs", "expose", "popout", "notification"]
                    text: I18n.tr("Expose the Arcs")
                    description: I18n.tr("Reveal the arcs where surfaces meet the frame")
                    checked: !SettingsData.frameCloseGaps
                    onToggled: checked => SettingsData.set("frameCloseGaps", !checked)
                }

                SettingsButtonGroupRow {
                    settingKey: "frameLauncherEmergeSide"
                    tags: ["frame", "connected", "launcher", "modal", "emerge", "direction", "bottom", "top"]
                    text: I18n.tr("Launcher Emerge Side")
                    description: I18n.tr("Edge the launcher slides from")
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
                    text: I18n.tr("Arc Extender")
                    description: I18n.tr("Use the extended surface for launcher content")
                    checked: SettingsData.frameLauncherArcExtender
                    onToggled: checked => SettingsData.set("frameLauncherArcExtender", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "toolbar"
                title: I18n.tr("Integrations")
                settingKey: "frameBarIntegration"
                collapsible: true
                expanded: true
                visible: SettingsData.frameEnabled && CompositorService.isNiri

                SettingsToggleRow {
                    settingKey: "frameShowOnOverview"
                    tags: ["frame", "overview", "show", "hide", "niri"]
                    text: I18n.tr("Show on Overview")
                    description: I18n.tr("Show during Niri overview")
                    checked: SettingsData.frameShowOnOverview
                    onToggled: checked => SettingsData.set("frameShowOnOverview", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "monitor"
                title: I18n.tr("Display Assignment")
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
}
