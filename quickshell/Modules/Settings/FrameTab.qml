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
                    defaultValue: 24
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
                    defaultValue: 15
                    value: SettingsData.frameThickness
                    onSliderDragFinished: v => SettingsData.set("frameThickness", v)

                    Binding {
                        target: thicknessSlider
                        property: "value"
                        value: SettingsData.frameThickness
                    }
                }

                SettingsSliderRow {
                    id: opacitySlider
                    settingKey: "frameOpacity"
                    tags: ["frame", "border", "opacity", "transparency"]
                    text: I18n.tr("Border opacity")
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

                // Color row
                Item {
                    width: parent.width
                    height: colorRow.height + Theme.spacingM * 2

                    Row {
                        id: colorRow
                        width: parent.width - Theme.spacingM * 2
                        x: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Border color")
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
                            color: SettingsData.frameColor
                            border.color: Theme.outline
                            border.width: 1

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    PopoutService.colorPickerModal.selectedColor = SettingsData.frameColor;
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
