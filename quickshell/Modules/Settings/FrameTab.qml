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

            // ── Enable Frame ──────────────────────────────────────────────────
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

            // ── Border ────────────────────────────────────────────────────────
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
                    text: I18n.tr("Border rounding")
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
                    text: I18n.tr("Border thickness")
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
                    settingKey: "frameBarThickness"
                    tags: ["frame", "bar", "thickness", "size", "height", "width"]
                    text: I18n.tr("Bar-edge thickness")
                    description: I18n.tr("Height of horizontal bars / width of vertical bars in frame mode")
                    unit: "px"
                    minimum: 24
                    maximum: 100
                    step: 1
                    defaultValue: 42
                    value: SettingsData.frameBarThickness
                    onSliderDragFinished: v => SettingsData.set("frameBarThickness", v)

                    Binding {
                        target: barThicknessSlider
                        property: "value"
                        value: SettingsData.frameBarThickness
                    }
                }

                SettingsSliderRow {
                    id: opacitySlider
                    settingKey: "frameOpacity"
                    tags: ["frame", "border", "opacity", "transparency"]
                    text: I18n.tr("Frame Opacity")
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

                // Color mode buttons
                SettingsButtonGroupRow {
                    settingKey: "frameColor"
                    tags: ["frame", "border", "color", "theme", "primary", "surface", "default"]
                    text: I18n.tr("Border color")
                    model: [I18n.tr("Default"), I18n.tr("Primary"), I18n.tr("Surface"), I18n.tr("Custom")]
                    currentIndex: {
                        const fc = SettingsData.frameColor;
                        if (!fc || fc === "default") return 0;
                        if (fc === "primary") return 1;
                        if (fc === "surface") return 2;
                        return 3;
                    }
                    onSelectionChanged: (index, selected) => {
                        if (!selected) return;
                        switch (index) {
                        case 0: SettingsData.set("frameColor", ""); break;
                        case 1: SettingsData.set("frameColor", "primary"); break;
                        case 2: SettingsData.set("frameColor", "surface"); break;
                        case 3:
                            const cur = SettingsData.frameColor;
                            const isPreset = !cur || cur === "primary" || cur === "surface";
                            if (isPreset) SettingsData.set("frameColor", "#2a2a2a");
                            break;
                        }
                    }
                }

                // Custom color swatch — only visible when a hex color is stored (Custom mode)
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
                            text: I18n.tr("Custom color")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }

                        Rectangle {
                            id: colorSwatch
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

            // ── Bar Integration ───────────────────────────────────────────────
            SettingsCard {
                width: parent.width
                iconName: "toolbar"
                title: I18n.tr("Bar Integration")
                settingKey: "frameBarIntegration"
                collapsible: true
                visible: SettingsData.frameEnabled

                SettingsToggleRow {
                    settingKey: "frameSyncBarColor"
                    tags: ["frame", "bar", "sync", "color", "background"]
                    text: I18n.tr("Sync bar background to frame")
                    description: I18n.tr("Sets the bar background color to match the frame border color for a seamless look")
                    checked: SettingsData.frameSyncBarColor
                    onToggled: checked => SettingsData.set("frameSyncBarColor", checked)
                }

                SettingsToggleRow {
                    visible: CompositorService.isNiri
                    settingKey: "frameShowOnOverview"
                    tags: ["frame", "overview", "show", "hide", "niri"]
                    text: I18n.tr("Show on Overview")
                    description: I18n.tr("Show the bar and frame during Niri overview mode")
                    checked: SettingsData.frameShowOnOverview
                    onToggled: checked => SettingsData.set("frameShowOnOverview", checked)
                }
            }

            // ── Display Assignment ────────────────────────────────────────────
            SettingsCard {
                width: parent.width
                iconName: "monitor"
                title: I18n.tr("Display Assignment")
                settingKey: "frameDisplays"
                collapsible: true
                visible: SettingsData.frameEnabled

                SettingsDisplayPicker {
                    displayPreferences: SettingsData.frameScreenPreferences
                    onPreferencesChanged: prefs => SettingsData.set("frameScreenPreferences", prefs)
                }
            }
        }
    }
}
