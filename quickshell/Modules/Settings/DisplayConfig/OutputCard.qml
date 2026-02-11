import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

StyledRect {
    id: root

    required property string outputName
    required property var outputData
    property bool isConnected: outputData?.connected ?? false

    width: parent.width
    height: settingsColumn.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, isConnected ? 0.5 : 0.3)
    border.color: Theme.withAlpha(Theme.outline, 0.3)
    border.width: 1
    opacity: isConnected ? 1.0 : 0.7

    Column {
        id: settingsColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        Row {
            width: parent.width
            spacing: Theme.spacingM

            DankIcon {
                name: root.isConnected ? "desktop_windows" : "desktop_access_disabled"
                size: Theme.iconSize - 4
                color: root.isConnected ? Theme.primary : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - Theme.iconSize - Theme.spacingM - (disconnectedBadge.visible ? disconnectedBadge.width + deleteButton.width + Theme.spacingS * 2 : 0)
                spacing: 2

                StyledText {
                    text: DisplayConfigState.getOutputDisplayName(root.outputData, root.outputName)
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: root.isConnected ? Theme.surfaceText : Theme.surfaceVariantText
                }

                StyledText {
                    text: (root.outputData?.model ?? "") + (root.outputData?.make ? " - " + root.outputData.make : "")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }

            Rectangle {
                id: disconnectedBadge
                visible: !root.isConnected
                width: disconnectedText.implicitWidth + Theme.spacingM
                height: disconnectedText.implicitHeight + Theme.spacingXS
                radius: height / 2
                color: Theme.withAlpha(Theme.outline, 0.3)
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    id: disconnectedText
                    text: I18n.tr("Disconnected")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.centerIn: parent
                }
            }

            Rectangle {
                id: deleteButton
                visible: !root.isConnected
                width: 28
                height: 28
                radius: Theme.cornerRadius
                color: deleteArea.containsMouse ? Theme.errorHover : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    anchors.centerIn: parent
                    name: "delete"
                    size: 18
                    color: deleteArea.containsMouse ? Theme.error : Theme.surfaceVariantText
                }

                MouseArea {
                    id: deleteArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DisplayConfigState.deleteDisconnectedOutput(root.outputName)
                }
            }
        }

        DankDropdown {
            width: parent.width
            text: I18n.tr("Resolution & Refresh")
            visible: root.isConnected
            currentValue: {
                const pendingMode = DisplayConfigState.getPendingValue(root.outputName, "mode");
                if (pendingMode)
                    return pendingMode;
                const data = DisplayConfigState.outputs[root.outputName];
                if (!data?.modes || data?.current_mode === undefined)
                    return "Auto";
                const mode = data.modes[data.current_mode];
                return mode ? DisplayConfigState.formatMode(mode) : "Auto";
            }
            options: {
                const data = DisplayConfigState.outputs[root.outputName];
                if (!data?.modes)
                    return ["Auto"];
                const opts = [];
                for (var i = 0; i < data.modes.length; i++) {
                    opts.push(DisplayConfigState.formatMode(data.modes[i]));
                }
                return opts;
            }
            onValueChanged: value => DisplayConfigState.setPendingChange(root.outputName, "mode", value)
        }

        StyledText {
            visible: !root.isConnected
            text: I18n.tr("Configuration will be preserved when this display reconnects")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Row {
            width: parent.width
            spacing: Theme.spacingM
            visible: root.isConnected

            Column {
                width: (parent.width - Theme.spacingM) / 2
                spacing: Theme.spacingXS

                StyledText {
                    text: I18n.tr("Scale")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                Item {
                    id: scaleContainer
                    width: parent.width
                    height: scaleDropdown.visible ? scaleDropdown.height : scaleInput.height

                    property bool customMode: false
                    property string currentScale: {
                        const pendingScale = DisplayConfigState.getPendingValue(root.outputName, "scale");
                        if (pendingScale !== undefined)
                            return parseFloat(pendingScale.toFixed(2)).toString();
                        const scale = DisplayConfigState.outputs[root.outputName]?.logical?.scale ?? 1.0;
                        return parseFloat(scale.toFixed(2)).toString();
                    }

                    DankDropdown {
                        id: scaleDropdown
                        width: parent.width
                        dropdownWidth: parent.width
                        visible: !scaleContainer.customMode
                        currentValue: scaleContainer.currentScale
                        options: {
                            const standard = ["0.5", "0.75", "1", "1.25", "1.5", "1.75", "2", "2.5", "3", I18n.tr("Custom...")];
                            const current = scaleContainer.currentScale;
                            if (standard.slice(0, -1).includes(current))
                                return standard;
                            const opts = [...standard.slice(0, -1), current, standard[standard.length - 1]];
                            return opts.sort((a, b) => {
                                if (a === I18n.tr("Custom..."))
                                    return 1;
                                if (b === I18n.tr("Custom..."))
                                    return -1;
                                return parseFloat(a) - parseFloat(b);
                            });
                        }
                        onValueChanged: value => {
                            if (value === I18n.tr("Custom...")) {
                                scaleContainer.customMode = true;
                                scaleInput.text = scaleContainer.currentScale;
                                scaleInput.forceActiveFocus();
                                scaleInput.selectAll();
                                return;
                            }
                            DisplayConfigState.setPendingChange(root.outputName, "scale", parseFloat(value));
                        }
                    }

                    DankTextField {
                        id: scaleInput
                        width: parent.width
                        height: 40
                        visible: scaleContainer.customMode
                        placeholderText: "0.5 - 4.0"

                        function applyValue() {
                            const val = parseFloat(text);
                            if (isNaN(val) || val < 0.25 || val > 4) {
                                text = scaleContainer.currentScale;
                                scaleContainer.customMode = false;
                                return;
                            }
                            DisplayConfigState.setPendingChange(root.outputName, "scale", parseFloat(val.toFixed(2)));
                            scaleContainer.customMode = false;
                        }

                        onAccepted: applyValue()
                        onEditingFinished: applyValue()
                        Keys.onEscapePressed: {
                            text = scaleContainer.currentScale;
                            scaleContainer.customMode = false;
                        }
                    }
                }
            }

            Column {
                width: (parent.width - Theme.spacingM) / 2
                spacing: Theme.spacingXS

                StyledText {
                    text: I18n.tr("Transform")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankDropdown {
                    width: parent.width
                    dropdownWidth: parent.width
                    currentValue: {
                        const pendingTransform = DisplayConfigState.getPendingValue(root.outputName, "transform");
                        if (pendingTransform)
                            return DisplayConfigState.getTransformLabel(pendingTransform);
                        const data = DisplayConfigState.outputs[root.outputName];
                        return DisplayConfigState.getTransformLabel(data?.logical?.transform ?? "Normal");
                    }
                    options: [I18n.tr("Normal"), I18n.tr("90°"), I18n.tr("180°"), I18n.tr("270°"), I18n.tr("Flipped"), I18n.tr("Flipped 90°"), I18n.tr("Flipped 180°"), I18n.tr("Flipped 270°")]
                    onValueChanged: value => DisplayConfigState.setPendingChange(root.outputName, "transform", DisplayConfigState.getTransformValue(value))
                }
            }
        }

        DankToggle {
            width: parent.width
            text: I18n.tr("Variable Refresh Rate")
            visible: root.isConnected && !CompositorService.isDwl && !CompositorService.isHyprland && !CompositorService.isNiri && (DisplayConfigState.outputs[root.outputName]?.vrr_supported ?? false)
            checked: {
                const pendingVrr = DisplayConfigState.getPendingValue(root.outputName, "vrr");
                if (pendingVrr !== undefined)
                    return pendingVrr;
                return DisplayConfigState.outputs[root.outputName]?.vrr_enabled ?? false;
            }
            onToggled: checked => DisplayConfigState.setPendingChange(root.outputName, "vrr", checked)
        }

        DankDropdown {
            width: parent.width
            text: I18n.tr("Variable Refresh Rate")
            addHorizontalPadding: true
            visible: root.isConnected && CompositorService.isHyprland && (DisplayConfigState.outputs[root.outputName]?.vrr_supported ?? false)
            options: [I18n.tr("Off"), I18n.tr("On"), I18n.tr("Fullscreen Only")]
            currentValue: {
                DisplayConfigState.pendingHyprlandChanges;
                if (DisplayConfigState.getHyprlandSetting(root.outputData, root.outputName, "vrrFullscreenOnly", false))
                    return I18n.tr("Fullscreen Only");
                const pendingVrr = DisplayConfigState.getPendingValue(root.outputName, "vrr");
                const vrrEnabled = pendingVrr !== undefined ? pendingVrr : (DisplayConfigState.outputs[root.outputName]?.vrr_enabled ?? false);
                if (vrrEnabled)
                    return I18n.tr("On");
                return I18n.tr("Off");
            }
            onValueChanged: value => {
                const off = I18n.tr("Off");
                const fullscreen = I18n.tr("Fullscreen Only");
                DisplayConfigState.setPendingChange(root.outputName, "vrr", value !== off);
                DisplayConfigState.setHyprlandSetting(root.outputData, root.outputName, "vrrFullscreenOnly", value === fullscreen || null);
            }
        }

        DankDropdown {
            width: parent.width
            text: I18n.tr("Variable Refresh Rate")
            addHorizontalPadding: true
            visible: root.isConnected && CompositorService.isNiri && (DisplayConfigState.outputs[root.outputName]?.vrr_supported ?? false)
            options: [I18n.tr("Off"), I18n.tr("On"), I18n.tr("On-Demand")]
            currentValue: {
                DisplayConfigState.pendingNiriChanges;
                if (DisplayConfigState.getNiriSetting(root.outputData, root.outputName, "vrrOnDemand", false))
                    return I18n.tr("On-Demand");
                const pendingVrr = DisplayConfigState.getPendingValue(root.outputName, "vrr");
                const vrrEnabled = pendingVrr !== undefined ? pendingVrr : (DisplayConfigState.outputs[root.outputName]?.vrr_enabled ?? false);
                if (!vrrEnabled)
                    return I18n.tr("Off");
                return I18n.tr("On");
            }
            onValueChanged: value => {
                const off = I18n.tr("Off");
                const onDemand = I18n.tr("On-Demand");
                DisplayConfigState.setPendingChange(root.outputName, "vrr", value !== off);
                DisplayConfigState.setNiriSetting(root.outputData, root.outputName, "vrrOnDemand", value === onDemand || null);
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.withAlpha(Theme.outline, 0.2)
            visible: compositorSettingsLoader.active
        }

        Loader {
            id: compositorSettingsLoader
            width: parent.width
            active: root.isConnected && compositorSettingsSource !== ""
            source: compositorSettingsSource

            property string compositorSettingsSource: {
                switch (CompositorService.compositor) {
                case "niri":
                    return "NiriOutputSettings.qml";
                case "hyprland":
                    return "HyprlandOutputSettings.qml";
                default:
                    return "";
                }
            }

            onLoaded: {
                item.outputName = root.outputName;
                item.outputData = root.outputData;
            }
        }
    }
}
