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
        id: settingsColumn
        width: parent.width
        spacing: Theme.spacingS
        visible: root.expanded
        topPadding: Theme.spacingS

        property int currentBitdepth: {
            DisplayConfigState.pendingHyprlandChanges;
            return DisplayConfigState.getHyprlandSetting(root.outputData, root.outputName, "bitdepth", 8);
        }
        property bool is10Bit: currentBitdepth === 10

        property string currentCm: {
            DisplayConfigState.pendingHyprlandChanges;
            return DisplayConfigState.getHyprlandSetting(root.outputData, root.outputName, "colorManagement", "auto");
        }
        property bool isHdrMode: currentCm === "hdr" || currentCm === "hdredid"

        DankToggle {
            width: parent.width
            text: I18n.tr("Disable Output")
            checked: DisplayConfigState.getHyprlandSetting(root.outputData, root.outputName, "disabled", false)
            onToggled: checked => DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "disabled", checked)
        }

        DankDropdown {
            width: parent.width
            text: I18n.tr("Mirror Display")
            addHorizontalPadding: true

            property var otherOutputs: {
                const list = [I18n.tr("None")];
                for (const name in DisplayConfigState.outputs) {
                    if (name !== root.outputName)
                        list.push(name);
                }
                return list;
            }
            options: otherOutputs

            currentValue: {
                DisplayConfigState.pendingChanges;
                const pending = DisplayConfigState.getPendingValue(root.outputName, "mirror");
                const val = pending !== undefined ? pending : (root.outputData.mirror || "");
                return val === "" ? I18n.tr("None") : val;
            }

            onValueChanged: value => {
                const realVal = value === I18n.tr("None") ? "" : value;
                DisplayConfigState.setPendingChange(root.outputName, "mirror", realVal);
            }
        }

        DankToggle {
            width: parent.width
            text: I18n.tr("10-bit Color")
            description: I18n.tr("Enable 10-bit color depth for wider color gamut and HDR support")
            checked: settingsColumn.is10Bit
            onToggled: checked => {
                if (checked) {
                    DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "bitdepth", 10);
                } else {
                    DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "bitdepth", null);
                    if (settingsColumn.isHdrMode)
                        DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "colorManagement", "auto");
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: settingsColumn.is10Bit

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.withAlpha(Theme.outline, 0.15)
            }

            DankDropdown {
                width: parent.width
                text: I18n.tr("Color Gamut")
                addHorizontalPadding: true
                currentValue: {
                    DisplayConfigState.pendingHyprlandChanges;
                    const val = DisplayConfigState.getHyprlandSetting(root.outputData, root.outputName, "colorManagement", "auto");
                    return cmLabelMap[val] || I18n.tr("Auto (Wide)");
                }
                options: [I18n.tr("Auto (Wide)"), I18n.tr("Wide (BT2020)"), "DCI-P3", "Apple P3", "Adobe RGB", "EDID", "HDR", I18n.tr("HDR (EDID)")]

                property var cmValueMap: ({
                        [I18n.tr("Auto (Wide)")]: "auto",
                        [I18n.tr("Wide (BT2020)")]: "wide",
                        "DCI-P3": "dcip3",
                        "Apple P3": "dp3",
                        "Adobe RGB": "adobe",
                        "EDID": "edid",
                        "HDR": "hdr",
                        [I18n.tr("HDR (EDID)")]: "hdredid"
                    })

                property var cmLabelMap: ({
                        "auto": I18n.tr("Auto (Wide)"),
                        "wide": I18n.tr("Wide (BT2020)"),
                        "dcip3": "DCI-P3",
                        "dp3": "Apple P3",
                        "adobe": "Adobe RGB",
                        "edid": "EDID",
                        "hdr": "HDR",
                        "hdredid": I18n.tr("HDR (EDID)")
                    })

                onValueChanged: value => {
                    const cmValue = cmValueMap[value] || "auto";
                    DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "colorManagement", cmValue);
                }
            }

            Rectangle {
                width: parent.width - Theme.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                height: warningColumn.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadius / 2
                color: Theme.withAlpha(Theme.warning, 0.15)
                border.color: Theme.withAlpha(Theme.warning, 0.3)
                border.width: 1
                visible: settingsColumn.isHdrMode

                Column {
                    id: warningColumn
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingXS

                    Row {
                        spacing: Theme.spacingS
                        DankIcon {
                            name: "warning"
                            size: Theme.iconSize - 4
                            color: Theme.warning
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: I18n.tr("Experimental Feature")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.warning
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    StyledText {
                        text: I18n.tr("HDR mode is experimental. Verify your monitor supports HDR before enabling.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingS
                visible: settingsColumn.isHdrMode

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.withAlpha(Theme.outline, 0.15)
                }

                StyledText {
                    text: I18n.tr("HDR Tone Mapping")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceVariantText
                    leftPadding: Theme.spacingM
                }

                Row {
                    width: parent.width - Theme.spacingM * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingM

                    Column {
                        width: (parent.width - Theme.spacingM) / 2
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("SDR Brightness")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        DankTextField {
                            width: parent.width
                            height: 40
                            placeholderText: "1.0 - 2.0"
                            text: {
                                DisplayConfigState.pendingHyprlandChanges;
                                const val = DisplayConfigState.getHyprlandSetting(root.outputData, root.outputName, "sdrBrightness", null);
                                return val !== null ? val.toString() : "";
                            }
                            onEditingFinished: {
                                const trimmed = text.trim();
                                if (!trimmed) {
                                    DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "sdrBrightness", null);
                                    return;
                                }
                                const val = parseFloat(trimmed);
                                if (isNaN(val) || val < 0.1 || val > 5.0)
                                    return;
                                DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "sdrBrightness", parseFloat(val.toFixed(2)));
                            }
                        }
                    }

                    Column {
                        width: (parent.width - Theme.spacingM) / 2
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("SDR Saturation")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        DankTextField {
                            width: parent.width
                            height: 40
                            placeholderText: "0.5 - 1.5"
                            text: {
                                DisplayConfigState.pendingHyprlandChanges;
                                const val = DisplayConfigState.getHyprlandSetting(root.outputData, root.outputName, "sdrSaturation", null);
                                return val !== null ? val.toString() : "";
                            }
                            onEditingFinished: {
                                const trimmed = text.trim();
                                if (!trimmed) {
                                    DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "sdrSaturation", null);
                                    return;
                                }
                                const val = parseFloat(trimmed);
                                if (isNaN(val) || val < 0.0 || val > 3.0)
                                    return;
                                DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "sdrSaturation", parseFloat(val.toFixed(2)));
                            }
                        }
                    }
                }
            }
        }
    }
}
