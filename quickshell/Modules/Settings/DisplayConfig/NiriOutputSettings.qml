import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    property string outputName: ""
    property var outputData: null
    property bool expanded: false

    width: parent.width
    spacing: 0

    Rectangle {
        width: parent.width
        height: headerRow.implicitHeight + Theme.spacingS * 2
        color: headerMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.1) : "transparent"
        radius: Theme.cornerRadius / 2

        Row {
            id: headerRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.spacingS
            anchors.rightMargin: Theme.spacingS
            spacing: Theme.spacingS

            DankIcon {
                name: root.expanded ? "expand_more" : "chevron_right"
                size: Theme.iconSize
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: I18n.tr("Compositor Settings")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: headerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.expanded
        topPadding: Theme.spacingS

        DankToggle {
            width: parent.width
            text: I18n.tr("Disable Output")
            checked: DisplayConfigState.getNiriSetting(root.outputData, root.outputName, "disabled", false)
            onToggled: checked => DisplayConfigState.setNiriSetting(root.outputData, root.outputName, "disabled", checked)
        }

        DankToggle {
            width: parent.width
            text: I18n.tr("Focus at Startup")
            checked: DisplayConfigState.getNiriSetting(root.outputData, root.outputName, "focusAtStartup", false)
            onToggled: checked => DisplayConfigState.setNiriSetting(root.outputData, root.outputName, "focusAtStartup", checked)
        }

        DankDropdown {
            width: parent.width
            text: I18n.tr("Hot Corners")
            addHorizontalPadding: true

            property var hotCornersData: {
                void (DisplayConfigState.pendingNiriChanges);
                return DisplayConfigState.getNiriSetting(root.outputData, root.outputName, "hotCorners", null);
            }

            currentValue: {
                if (!hotCornersData)
                    return I18n.tr("Inherit");
                if (hotCornersData.off)
                    return I18n.tr("Off");
                const corners = hotCornersData.corners || [];
                if (corners.length === 0)
                    return I18n.tr("Inherit");
                if (corners.length === 4)
                    return I18n.tr("All");
                return I18n.tr("Select...");
            }
            options: [I18n.tr("Inherit"), I18n.tr("Off"), I18n.tr("All"), I18n.tr("Select...")]

            onValueChanged: value => {
                switch (value) {
                case I18n.tr("Inherit"):
                    DisplayConfigState.setNiriSetting(root.outputData, root.outputName, "hotCorners", null);
                    break;
                case I18n.tr("Off"):
                    DisplayConfigState.setNiriSetting(root.outputData, root.outputName, "hotCorners", {
                        "off": true
                    });
                    break;
                case I18n.tr("All"):
                    DisplayConfigState.setNiriSetting(root.outputData, root.outputName, "hotCorners", {
                        "corners": ["top-left", "top-right", "bottom-left", "bottom-right"]
                    });
                    break;
                case I18n.tr("Select..."):
                    DisplayConfigState.setNiriSetting(root.outputData, root.outputName, "hotCorners", {
                        "corners": []
                    });
                    break;
                }
            }
        }

        Item {
            width: parent.width
            height: hotCornersGroup.implicitHeight
            clip: true

            property var hotCornersData: {
                void (DisplayConfigState.pendingNiriChanges);
                return DisplayConfigState.getNiriSetting(root.outputData, root.outputName, "hotCorners", null);
            }

            visible: hotCornersData && !hotCornersData.off && hotCornersData.corners !== undefined

            DankButtonGroup {
                id: hotCornersGroup
                anchors.horizontalCenter: parent.horizontalCenter
                selectionMode: "multi"
                checkEnabled: false
                buttonHeight: 32
                buttonPadding: parent.width < 400 ? Theme.spacingXS : Theme.spacingM
                minButtonWidth: parent.width < 400 ? 28 : 56
                textSize: parent.width < 400 ? 11 : Theme.fontSizeMedium
                model: [I18n.tr("Top Left"), I18n.tr("Top Right"), I18n.tr("Bottom Left"), I18n.tr("Bottom Right")]

                property var cornerKeys: ["top-left", "top-right", "bottom-left", "bottom-right"]

                currentSelection: {
                    const hcData = parent.hotCornersData;
                    if (!hcData?.corners)
                        return [];
                    return hcData.corners.map(key => {
                        const idx = cornerKeys.indexOf(key);
                        return idx >= 0 ? model[idx] : null;
                    }).filter(v => v !== null);
                }

                onSelectionChanged: (index, selected) => {
                    const corners = currentSelection.map(label => {
                        const idx = model.indexOf(label);
                        return idx >= 0 ? cornerKeys[idx] : null;
                    }).filter(v => v !== null);
                    DisplayConfigState.setNiriSetting(root.outputData, root.outputName, "hotCorners", {
                        "corners": corners
                    });
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.withAlpha(Theme.outline, 0.15)
        }

        Item {
            width: parent.width
            height: layoutColumn.implicitHeight

            Column {
                id: layoutColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                spacing: Theme.spacingS

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Layout Overrides")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                    }

                    StyledText {
                        text: I18n.tr("Override global layout settings for this output")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.withAlpha(Theme.surfaceVariantText, 0.7)
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    Column {
                        width: (parent.width - Theme.spacingM) / 2
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Window Gaps (px)")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        DankTextField {
                            width: parent.width
                            height: 40
                            placeholderText: I18n.tr("Inherit")
                            text: {
                                const layout = DisplayConfigState.getNiriSetting(root.outputData, root.outputName, "layout", null);
                                if (layout?.gaps === undefined)
                                    return "";
                                return layout.gaps.toString();
                            }
                            onEditingFinished: {
                                const layout = DisplayConfigState.getNiriSetting(root.outputData, root.outputName, "layout", {}) || {};
                                const trimmed = text.trim();
                                if (!trimmed) {
                                    delete layout.gaps;
                                    DisplayConfigState.setNiriSetting(root.outputData, root.outputName, "layout", Object.keys(layout).length > 0 ? layout : null);
                                    return;
                                }
                                const val = parseInt(trimmed);
                                if (isNaN(val) || val < 0)
                                    return;
                                layout.gaps = val;
                                DisplayConfigState.setNiriSetting(root.outputData, root.outputName, "layout", layout);
                            }
                        }
                    }

                    Column {
                        width: (parent.width - Theme.spacingM) / 2
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Default Width (%)")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        DankTextField {
                            width: parent.width
                            height: 40
                            placeholderText: I18n.tr("Inherit")
                            text: {
                                const layout = DisplayConfigState.getNiriSetting(root.outputData, root.outputName, "layout", null);
                                if (!layout?.defaultColumnWidth)
                                    return "";
                                if (layout.defaultColumnWidth.type !== "proportion")
                                    return "";
                                const percent = layout.defaultColumnWidth.value * 100;
                                return parseFloat(percent.toFixed(4)).toString();
                            }
                            onEditingFinished: {
                                const layout = DisplayConfigState.getNiriSetting(root.outputData, root.outputName, "layout", {}) || {};
                                const trimmed = text.trim().replace("%", "");
                                if (!trimmed) {
                                    delete layout.defaultColumnWidth;
                                    DisplayConfigState.setNiriSetting(root.outputData, root.outputName, "layout", Object.keys(layout).length > 0 ? layout : null);
                                    return;
                                }
                                const val = parseFloat(trimmed);
                                if (isNaN(val) || val <= 0 || val > 100)
                                    return;
                                layout.defaultColumnWidth = {
                                    "type": "proportion",
                                    "value": parseFloat((val / 100).toFixed(6))
                                };
                                DisplayConfigState.setNiriSetting(root.outputData, root.outputName, "layout", layout);
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Preset Widths (%)")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    StyledText {
                        text: "e.g. 33.33, 50, 66.67"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.withAlpha(Theme.surfaceVariantText, 0.7)
                    }

                    DankTextField {
                        width: parent.width
                        height: 40
                        placeholderText: I18n.tr("Inherit")
                        text: {
                            const layout = DisplayConfigState.getNiriSetting(root.outputData, root.outputName, "layout", null);
                            const presets = layout?.presetColumnWidths || [];
                            if (presets.length === 0)
                                return "";
                            return presets.filter(p => p.type === "proportion").map(p => parseFloat((p.value * 100).toFixed(4))).join(", ");
                        }
                        onEditingFinished: {
                            const layout = DisplayConfigState.getNiriSetting(root.outputData, root.outputName, "layout", {}) || {};
                            const trimmed = text.trim();
                            if (!trimmed) {
                                delete layout.presetColumnWidths;
                                DisplayConfigState.setNiriSetting(root.outputData, root.outputName, "layout", Object.keys(layout).length > 0 ? layout : null);
                                return;
                            }
                            const parts = trimmed.split(/[,\s]+/).filter(s => s);
                            const presets = [];
                            for (const part of parts) {
                                const val = parseFloat(part.replace("%", ""));
                                if (!isNaN(val) && val > 0 && val <= 100)
                                    presets.push({
                                        "type": "proportion",
                                        "value": parseFloat((val / 100).toFixed(6))
                                    });
                            }
                            if (presets.length === 0) {
                                delete layout.presetColumnWidths;
                                DisplayConfigState.setNiriSetting(root.outputData, root.outputName, "layout", Object.keys(layout).length > 0 ? layout : null);
                                return;
                            }
                            presets.sort((a, b) => a.value - b.value);
                            layout.presetColumnWidths = presets;
                            DisplayConfigState.setNiriSetting(root.outputData, root.outputName, "layout", layout);
                        }
                    }
                }
            }
        }

        DankToggle {
            width: parent.width
            text: I18n.tr("Center Single Column")
            property var layoutData: DisplayConfigState.getNiriSetting(root.outputData, root.outputName, "layout", null)
            checked: layoutData?.alwaysCenterSingleColumn ?? false
            onToggled: checked => {
                const layout = DisplayConfigState.getNiriSetting(root.outputData, root.outputName, "layout", {}) || {};
                if (checked) {
                    layout.alwaysCenterSingleColumn = true;
                } else {
                    delete layout.alwaysCenterSingleColumn;
                }
                DisplayConfigState.setNiriSetting(root.outputData, root.outputName, "layout", Object.keys(layout).length > 0 ? layout : null);
            }
        }
    }
}
