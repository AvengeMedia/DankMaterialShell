import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

StyledRect {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    signal requestICCBrowse(string outputName)

    required property string outputName
    required property var outputData
    property bool isConnected: outputData?.connected ?? false
    property bool isDisabled: {
        void (DisplayConfigState.pendingHyprlandChanges);
        void (DisplayConfigState.pendingNiriChanges);
        if (!root.isConnected)
            return false;
        if (CompositorService.isHyprland)
            return DisplayConfigState.getHyprlandSetting(root.outputData, root.outputName, "disabled", false);
        if (CompositorService.isNiri)
            return DisplayConfigState.getNiriSetting(root.outputData, root.outputName, "disabled", false);
        return false;
    }

    width: parent.width
    height: settingsColumn.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.floatingWindowForegroundLayers ? Theme.floatingWindowForegroundTransparency * (isConnected ? 0.5 : 0.3) : 0)
    border.color: Theme.outlineMedium
    border.width: Theme.layerOutlineWidth
    opacity: isConnected ? (isDisabled ? 0.5 : 1.0) : 0.7

    Column {
        id: settingsColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        Row {
            width: parent.width
            spacing: Theme.spacingM

            DankIcon {
                name: root.isConnected && !root.isDisabled ? "desktop_windows" : "desktop_access_disabled"
                size: Theme.iconSize - 4
                color: root.isConnected && !root.isDisabled ? Theme.primary : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - Theme.iconSize - Theme.spacingM - (disconnectedBadge.visible ? disconnectedBadge.width + deleteButton.width + Theme.spacingS * 2 : disabledBadge.visible ? disabledBadge.width + Theme.spacingS : 0)
                spacing: Theme.spacingXXS

                StyledText {
                    text: DisplayConfigState.getOutputDisplayName(root.outputData, root.outputName)
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: root.isConnected ? Theme.surfaceText : Theme.surfaceVariantText
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
                }

                StyledText {
                    text: (root.outputData?.model ?? "") + (root.outputData?.make ? " - " + root.outputData.make : "")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
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
                color: deleteArea.containsMouse ? Theme.errorHover : Theme.withAlpha(Theme.errorHover, 0)
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

            Rectangle {
                id: disabledBadge
                visible: root.isDisabled
                width: disabledText.implicitWidth + Theme.spacingM
                height: disabledText.implicitHeight + Theme.spacingXS
                radius: height / 2
                color: Theme.withAlpha(Theme.outline, 0.3)
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    id: disabledText
                    text: I18n.tr("Disabled")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.centerIn: parent
                }
            }
        }

        DankDropdown {
            width: parent.width
            text: I18n.tr("Resolution & Refresh")
            visible: root.isConnected && !root.isDisabled
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
            horizontalAlignment: Text.AlignLeft
        }

        StyledText {
            visible: root.isDisabled
            text: I18n.tr("This output is disabled in the current profile")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
            width: parent.width
            horizontalAlignment: Text.AlignLeft
        }

        Row {
            width: parent.width
            spacing: Theme.spacingM
            visible: root.isConnected && !root.isDisabled

            Column {
                width: (parent.width - Theme.spacingM) / 2
                spacing: Theme.spacingXS

                StyledText {
                    text: I18n.tr("Scale")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
                }

                Item {
                    id: scaleContainer
                    width: parent.width
                    height: scaleDropdown.visible ? scaleDropdown.height : scaleInput.height

                    property bool customMode: false
                    property real currentScaleValue: {
                        const pendingScale = DisplayConfigState.getPendingValue(root.outputName, "scale");
                        if (pendingScale !== undefined)
                            return pendingScale;
                        return root.outputData?.logical?.scale || 1.0;
                    }
                    property string currentScale: DisplayConfigState.formatScaleLabel(currentScaleValue)
                    property var scaleOptionsData: {
                        void (DisplayConfigState.pendingChanges);
                        const customLabel = I18n.tr("Custom...");
                        const values = DisplayConfigState.getScalePresetValues(root.outputName, root.outputData);
                        const labels = [];
                        const valueByLabel = {};

                        function addValue(value) {
                            if (!isFinite(value) || value <= 0)
                                return;
                            const label = DisplayConfigState.formatScaleLabel(value);
                            if (valueByLabel[label] !== undefined)
                                return;
                            valueByLabel[label] = value;
                            labels.push(label);
                        }

                        for (const value of values)
                            addValue(value);
                        addValue(scaleContainer.currentScaleValue);

                        labels.sort((a, b) => parseFloat(a) - parseFloat(b));
                        labels.push(customLabel);
                        return {
                            "labels": labels,
                            "valueByLabel": valueByLabel
                        };
                    }

                    DankDropdown {
                        id: scaleDropdown
                        width: parent.width
                        dropdownWidth: parent.width
                        visible: !scaleContainer.customMode
                        currentValue: scaleContainer.currentScale
                        options: scaleContainer.scaleOptionsData.labels
                        onValueChanged: value => {
                            if (value === I18n.tr("Custom...")) {
                                scaleContainer.customMode = true;
                                scaleInput.text = scaleContainer.currentScale;
                                scaleInput.forceActiveFocus();
                                scaleInput.selectAll();
                                return;
                            }
                            const mapped = scaleContainer.scaleOptionsData.valueByLabel[value];
                            DisplayConfigState.setPendingChange(root.outputName, "scale", mapped !== undefined ? mapped : parseFloat(value));
                        }
                    }

                    DankTextField {
                        id: scaleInput
                        width: parent.width
                        height: 40
                        visible: scaleContainer.customMode
                        placeholderText: "0.25 - 4.0"

                        function applyValue() {
                            const val = parseFloat(text);
                            if (isNaN(val) || val < 0.25 || val > 4) {
                                text = scaleContainer.currentScale;
                                scaleContainer.customMode = false;
                                return;
                            }
                            DisplayConfigState.setPendingChange(root.outputName, "scale", parseFloat(val.toFixed(6)));
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
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
                }

                DankDropdown {
                    width: parent.width
                    dropdownWidth: parent.width
                    currentValue: {
                        const pendingTransform = DisplayConfigState.getPendingValue(root.outputName, "transform");
                        if (pendingTransform)
                            return DisplayConfigState.getTransformLabel(pendingTransform);
                        return DisplayConfigState.getTransformLabel(root.outputData?.logical?.transform ?? "Normal");
                    }
                    options: [I18n.tr("Normal", "display rotation option", true), I18n.tr("90°"), I18n.tr("180°"), I18n.tr("270°"), I18n.tr("Flipped"), I18n.tr("Flipped 90°"), I18n.tr("Flipped 180°"), I18n.tr("Flipped 270°")]
                    onValueChanged: value => DisplayConfigState.setPendingChange(root.outputName, "transform", DisplayConfigState.getTransformValue(value))
                }
            }
        }

        DankToggle {
            width: parent.width
            text: I18n.tr("Variable Refresh Rate")
            visible: root.isConnected && !root.isDisabled && !CompositorService.isMango && !CompositorService.isHyprland && !CompositorService.isNiri && (DisplayConfigState.outputs[root.outputName]?.vrr_supported ?? false)
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
            visible: root.isConnected && !root.isDisabled && CompositorService.isHyprland && (DisplayConfigState.outputs[root.outputName]?.vrr_supported ?? false)
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
            visible: root.isConnected && !root.isDisabled && CompositorService.isNiri && (DisplayConfigState.outputs[root.outputName]?.vrr_supported ?? false)
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

        // ICC Color Profile row
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.withAlpha(Theme.outline, 0.15)
            visible: iccProfileRow.visible
        }

        Row {
            id: iccProfileRow
            width: parent.width
            spacing: Theme.spacingS
            visible: root.isConnected && !root.isDisabled && ICCService.outputNames.indexOf(root.outputName) !== -1

            property var iccInfo: ICCService.status[root.outputName]

            DankIcon {
                name: "palette"
                size: 18
                color: iccProfileRow.iccInfo ? Theme.primary : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - 18 - Theme.spacingS - iccBrowseButton.width - Theme.spacingS - (iccRemoveButton.visible ? iccRemoveButton.width + Theme.spacingS : 0)
                spacing: 1
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: I18n.tr("Color Profile", "Display Config output card label for the per-monitor ICC profile row")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    width: parent.width
                    elide: Text.ElideRight
                }

                Row {
                    spacing: Theme.spacingXS
                    width: parent.width

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: iccProfileRow.iccInfo ? Theme.success : Theme.withAlpha(Theme.outline, 0.5)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: {
                            if (!iccProfileRow.iccInfo)
                                return I18n.tr("No profile", "Display Config output card ICC row when the output has no profile applied");
                            const info = iccProfileRow.iccInfo;
                            return info.description || info.path || I18n.tr("Active", "Active");
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: iccProfileRow.iccInfo ? Theme.success : Theme.surfaceVariantText
                        width: parent.width - 6 - Theme.spacingXS
                        elide: Text.ElideMiddle
                    }
                }
            }

            DankButton {
                id: iccBrowseButton
                text: I18n.tr("Browse", "Browse")
                iconName: "folder_open"
                buttonHeight: 30
                horizontalPadding: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.requestICCBrowse(root.outputName)
            }

            DankButton {
                id: iccRemoveButton
                text: ""
                iconName: "close"
                buttonHeight: 30
                horizontalPadding: Theme.spacingXS
                backgroundColor: "transparent"
                textColor: Theme.error
                visible: iccProfileRow.iccInfo !== undefined
                anchors.verticalCenter: parent.verticalCenter
                onClicked: ICCService.removeICC(root.outputName)
            }
        }

        // Per-output color temperature slider
        Row {
            id: colorTempRow
            width: parent.width
            spacing: Theme.spacingS
            visible: root.isConnected && !root.isDisabled && ICCService.outputNames.indexOf(root.outputName) !== -1
            leftPadding: 0
            topPadding: Theme.spacingS

            property int currentTemp: ICCService.outputTemps[root.outputName] !== undefined ? ICCService.outputTemps[root.outputName] : 7000
            property bool editing: false

            DankIcon {
                name: "thermostat"
                size: 18
                color: colorTempRow.currentTemp !== 7000 ? Theme.primary : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - 18 - Theme.spacingS - tempLabel.width - Theme.spacingS
                spacing: 1
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: I18n.tr("Color Temperature", "Color Temperature")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                StyledText {
                    text: colorTempRow.currentTemp === 0 ? I18n.tr("Default", "Default") : (colorTempRow.currentTemp + "K")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }

            StyledText {
                id: tempLabel
                text: colorTempRow.editing ? (Math.round(tempSlider.value) + "K") : (colorTempRow.currentTemp === 0 ? I18n.tr("Default", "Default") : (colorTempRow.currentTemp + "K"))
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: colorTempRow.currentTemp !== 7000 && colorTempRow.currentTemp !== 0 ? Theme.primary : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: 1
                height: 1
            }
        }

        // Slider row (appears below the temp label when visible)
        Item {
            id: tempSliderRow
            width: parent.width - (18 + Theme.spacingS) - Theme.spacingS
            height: 48
            visible: colorTempRow.visible
            x: 18 + Theme.spacingS

            DankSlider {
                id: tempSlider
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                minimum: 3000
                maximum: 10000
                step: 100
                value: colorTempRow.currentTemp === 0 ? 7000 : colorTempRow.currentTemp
                showValue: true
                unit: "K"

                onSliderValueChanged: function (newValue) {
                    // Keep the label binding (line above) intact: assigning
                    // tempLabel.text here would freeze it after the first drag.
                    colorTempRow.editing = true
                }

                onSliderDragFinished: function (finalValue) {
                    ICCService.setOutputTemp(root.outputName, finalValue)
                    colorTempRow.editing = false
                }
            }
        }
    }
}
