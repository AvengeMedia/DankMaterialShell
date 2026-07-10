import QtQuick
import qs.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

Column {
    id: root

    property string outputName: ""
    property var outputData: null
    property bool expanded: false

    width: parent.width
    spacing: 0

    readonly property var liveOutput: AsteroidzService.getOutputState(root.outputName)
    readonly property bool hdrCapable: liveOutput?.hdrCapable ?? false

    Rectangle {
        width: parent.width
        height: headerRow.implicitHeight + Theme.spacingS * 2
        color: headerMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.1) : Theme.withAlpha(Theme.primary, 0)
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

    FileBrowserModal {
        id: iccBrowserModal
        browserTitle: I18n.tr("Select ICC profile")
        browserIcon: "palette"
        browserType: "generic"
        fileExtensions: ["*.icc", "*.icm"]
        onFileSelected: path => {
            DisplayConfigState.setAsteroidzSetting(root.outputData, root.outputName, "icc_profile", path);
            close();
        }
    }

    Column {
        id: settingsColumn
        width: parent.width
        spacing: Theme.spacingS
        visible: root.expanded
        topPadding: Theme.spacingS

        property bool hdrEnabled: {
            DisplayConfigState.pendingAsteroidzChanges;
            return DisplayConfigState.getAsteroidzSetting(root.outputData, root.outputName, "hdr", root.liveOutput?.hdrEnabled ?? false);
        }
        property int currentBitdepth: {
            DisplayConfigState.pendingAsteroidzChanges;
            return DisplayConfigState.getAsteroidzSetting(root.outputData, root.outputName, "bitdepth", root.liveOutput?.bitdepth ?? 8);
        }
        property bool is10Bit: currentBitdepth === 10

        StyledText {
            width: parent.width
            visible: !root.hdrCapable
            text: I18n.tr("This display does not report HDR support (BT.2020 + PQ). HDR options are unavailable.")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        DankToggle {
            width: parent.width
            text: I18n.tr("HDR")
            description: I18n.tr("BT.2020 primaries + PQ transfer function on this output")
            enabled: root.hdrCapable
            checked: root.hdrCapable && settingsColumn.hdrEnabled
            onToggled: checked => {
                DisplayConfigState.setAsteroidzSetting(root.outputData, root.outputName, "hdr", checked);
                if (checked)
                    DisplayConfigState.setAsteroidzSetting(root.outputData, root.outputName, "bitdepth", 10);
            }
        }

        DankToggle {
            width: parent.width
            text: I18n.tr("10-bit Color")
            description: I18n.tr("10-bit framebuffer depth (reduces banding); implied automatically while HDR is on")
            enabled: !settingsColumn.hdrEnabled
            checked: settingsColumn.is10Bit
            onToggled: checked => DisplayConfigState.setAsteroidzSetting(root.outputData, root.outputName, "bitdepth", checked ? 10 : null)
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: settingsColumn.hdrEnabled

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.withAlpha(Theme.outline, 0.15)
            }

            StyledText {
                text: I18n.tr("HDR Metadata")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceVariantText
                leftPadding: Theme.spacingM
            }

            StyledText {
                width: parent.width
                text: I18n.tr("Your panel's real luminance range, from its EDID (e.g. via edid-decode). Prevents the display from tone-mapping for brightness it can't produce.")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                leftPadding: Theme.spacingM
                rightPadding: Theme.spacingM
            }

            Row {
                width: parent.width - Theme.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingM

                Column {
                    width: (parent.width - Theme.spacingM * 2) / 3
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Max Luminance (nits)")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    DankTextField {
                        width: parent.width
                        height: 40
                        placeholderText: "0 - 10000"
                        text: {
                            DisplayConfigState.pendingAsteroidzChanges;
                            const val = DisplayConfigState.getAsteroidzSetting(root.outputData, root.outputName, "hdr_max_luminance", root.liveOutput?.hdrMaxLuminance || null);
                            return val !== null ? val.toString() : "";
                        }
                        onEditingFinished: {
                            const trimmed = text.trim();
                            if (!trimmed) {
                                DisplayConfigState.setAsteroidzSetting(root.outputData, root.outputName, "hdr_max_luminance", null);
                                return;
                            }
                            const val = parseFloat(trimmed);
                            if (isNaN(val) || val < 0 || val > 10000)
                                return;
                            DisplayConfigState.setAsteroidzSetting(root.outputData, root.outputName, "hdr_max_luminance", val);
                        }
                    }
                }

                Column {
                    width: (parent.width - Theme.spacingM * 2) / 3
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Min Luminance (nits)")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    DankTextField {
                        width: parent.width
                        height: 40
                        placeholderText: "0 - 1"
                        text: {
                            DisplayConfigState.pendingAsteroidzChanges;
                            const val = DisplayConfigState.getAsteroidzSetting(root.outputData, root.outputName, "hdr_min_luminance", root.liveOutput?.hdrMinLuminance || null);
                            return val !== null ? val.toString() : "";
                        }
                        onEditingFinished: {
                            const trimmed = text.trim();
                            if (!trimmed) {
                                DisplayConfigState.setAsteroidzSetting(root.outputData, root.outputName, "hdr_min_luminance", null);
                                return;
                            }
                            const val = parseFloat(trimmed);
                            if (isNaN(val) || val < 0 || val > 1)
                                return;
                            DisplayConfigState.setAsteroidzSetting(root.outputData, root.outputName, "hdr_min_luminance", val);
                        }
                    }
                }

                Column {
                    width: (parent.width - Theme.spacingM * 2) / 3
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Max Frame-Avg (nits)")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    DankTextField {
                        width: parent.width
                        height: 40
                        placeholderText: "0 - 10000"
                        text: {
                            DisplayConfigState.pendingAsteroidzChanges;
                            const val = DisplayConfigState.getAsteroidzSetting(root.outputData, root.outputName, "hdr_max_fall", root.liveOutput?.hdrMaxFall || null);
                            return val !== null ? val.toString() : "";
                        }
                        onEditingFinished: {
                            const trimmed = text.trim();
                            if (!trimmed) {
                                DisplayConfigState.setAsteroidzSetting(root.outputData, root.outputName, "hdr_max_fall", null);
                                return;
                            }
                            const val = parseFloat(trimmed);
                            if (isNaN(val) || val < 0 || val > 10000)
                                return;
                            DisplayConfigState.setAsteroidzSetting(root.outputData, root.outputName, "hdr_max_fall", val);
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.withAlpha(Theme.outline, 0.15)
        }

        StyledText {
            text: I18n.tr("ICC Profile (SDR)")
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceVariantText
            leftPadding: Theme.spacingM
        }

        Row {
            width: parent.width
            spacing: Theme.spacingS

            DankTextField {
                id: iccPathField
                width: parent.width - browseIccButton.width - Theme.spacingS
                placeholderText: I18n.tr("None")
                text: {
                    DisplayConfigState.pendingAsteroidzChanges;
                    return DisplayConfigState.getAsteroidzSetting(root.outputData, root.outputName, "icc_profile", root.liveOutput?.iccProfile || "");
                }
                onEditingFinished: DisplayConfigState.setAsteroidzSetting(root.outputData, root.outputName, "icc_profile", text.trim() || null)
            }

            DankButton {
                id: browseIccButton
                text: I18n.tr("Browse")
                horizontalPadding: Theme.spacingL
                onClicked: iccBrowserModal.open()
            }
        }
    }
}
