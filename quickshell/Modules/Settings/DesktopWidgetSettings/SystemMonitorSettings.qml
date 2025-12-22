pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Column {
    id: root

    property string instanceId: ""
    property var instanceData: null

    readonly property var cfg: instanceData?.config ?? {}

    function updateConfig(key, value) {
        if (!instanceId)
            return;
        var updates = {};
        updates[key] = value;
        SettingsData.updateDesktopWidgetInstanceConfig(instanceId, updates);
    }

    width: parent?.width ?? 400
    spacing: 0

    SettingsToggleRow {
        text: I18n.tr("Show Header")
        checked: cfg.showHeader ?? true
        onToggled: checked => root.updateConfig("showHeader", checked)
    }

    SettingsDivider {}

    Item {
        width: parent.width
        height: graphIntervalColumn.height + Theme.spacingM * 2

        Column {
            id: graphIntervalColumn
            width: parent.width - Theme.spacingM * 2
            x: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("Graph Time Range")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
            }

            DankButtonGroup {
                model: ["1m", "5m", "10m", "30m"]
                currentIndex: {
                    switch (cfg.graphInterval ?? 60) {
                    case 60:
                        return 0;
                    case 300:
                        return 1;
                    case 600:
                        return 2;
                    case 1800:
                        return 3;
                    default:
                        return 0;
                    }
                }
                buttonHeight: 32
                minButtonWidth: 48
                textSize: Theme.fontSizeSmall
                checkEnabled: false
                onSelectionChanged: (index, selected) => {
                    if (!selected)
                        return;
                    const values = [60, 300, 600, 1800];
                    root.updateConfig("graphInterval", values[index]);
                }
            }
        }
    }

    SettingsDivider {}

    SettingsToggleRow {
        text: I18n.tr("CPU")
        checked: cfg.showCpu ?? true
        onToggled: checked => root.updateConfig("showCpu", checked)
    }

    SettingsDivider {
        visible: cfg.showCpu ?? true
    }

    SettingsToggleRow {
        visible: cfg.showCpu ?? true
        text: I18n.tr("CPU Graph")
        checked: cfg.showCpuGraph ?? true
        onToggled: checked => root.updateConfig("showCpuGraph", checked)
    }

    SettingsDivider {
        visible: cfg.showCpu ?? true
    }

    SettingsToggleRow {
        visible: cfg.showCpu ?? true
        text: I18n.tr("CPU Temperature")
        checked: cfg.showCpuTemp ?? true
        onToggled: checked => root.updateConfig("showCpuTemp", checked)
    }

    SettingsDivider {}

    SettingsToggleRow {
        text: I18n.tr("GPU Temperature")
        checked: cfg.showGpuTemp ?? false
        onToggled: checked => root.updateConfig("showGpuTemp", checked)
    }

    SettingsDivider {
        visible: (cfg.showGpuTemp ?? false) && DgopService.availableGpus.length > 0
    }

    Item {
        width: parent.width
        height: gpuSelectColumn.height + Theme.spacingM * 2
        visible: (cfg.showGpuTemp ?? false) && DgopService.availableGpus.length > 0

        Column {
            id: gpuSelectColumn
            width: parent.width - Theme.spacingM * 2
            x: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("GPU")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                Repeater {
                    model: DgopService.availableGpus

                    Rectangle {
                        required property var modelData

                        readonly property bool isSelected: (cfg.gpuPciId ?? "") === modelData.pciId

                        width: parent.width
                        height: 44
                        radius: Theme.cornerRadius
                        color: isSelected ? Theme.primarySelected : Theme.surfaceHover
                        border.color: isSelected ? Theme.primary : "transparent"
                        border.width: 2

                        Row {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "videocam"
                                size: Theme.iconSizeSmall
                                color: isSelected ? Theme.primary : Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - Theme.iconSizeSmall - Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                StyledText {
                                    text: modelData.displayName || "Unknown GPU"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    width: parent.width
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    text: modelData.driver || ""
                                    font.pixelSize: Theme.fontSizeSmall - 2
                                    color: Theme.surfaceVariantText
                                    visible: text !== ""
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.updateConfig("gpuPciId", modelData.pciId)
                        }
                    }
                }
            }
        }
    }

    SettingsDivider {}

    SettingsToggleRow {
        text: I18n.tr("Memory")
        checked: cfg.showMemory ?? true
        onToggled: checked => root.updateConfig("showMemory", checked)
    }

    SettingsDivider {
        visible: cfg.showMemory ?? true
    }

    SettingsToggleRow {
        visible: cfg.showMemory ?? true
        text: I18n.tr("Memory Graph")
        checked: cfg.showMemoryGraph ?? true
        onToggled: checked => root.updateConfig("showMemoryGraph", checked)
    }

    SettingsDivider {}

    SettingsToggleRow {
        text: I18n.tr("Network")
        checked: cfg.showNetwork ?? true
        onToggled: checked => root.updateConfig("showNetwork", checked)
    }

    SettingsDivider {
        visible: cfg.showNetwork ?? true
    }

    SettingsToggleRow {
        visible: cfg.showNetwork ?? true
        text: I18n.tr("Network Graph")
        checked: cfg.showNetworkGraph ?? true
        onToggled: checked => root.updateConfig("showNetworkGraph", checked)
    }

    SettingsDivider {}

    SettingsToggleRow {
        text: I18n.tr("Disk")
        checked: cfg.showDisk ?? true
        onToggled: checked => root.updateConfig("showDisk", checked)
    }

    SettingsDivider {}

    SettingsToggleRow {
        text: I18n.tr("Top Processes")
        checked: cfg.showTopProcesses ?? false
        onToggled: checked => root.updateConfig("showTopProcesses", checked)
    }

    SettingsDivider {
        visible: cfg.showTopProcesses ?? false
    }

    Item {
        width: parent.width
        height: topProcessesColumn.height + Theme.spacingM * 2
        visible: cfg.showTopProcesses ?? false

        Column {
            id: topProcessesColumn
            width: parent.width - Theme.spacingM * 2
            x: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM

                StyledText {
                    width: parent.width - processCountButtons.width - Theme.spacingM
                    text: I18n.tr("Process Count")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankButtonGroup {
                    id: processCountButtons
                    model: ["3", "5", "10"]
                    currentIndex: {
                        switch (cfg.topProcessCount ?? 3) {
                        case 3:
                            return 0;
                        case 5:
                            return 1;
                        case 10:
                            return 2;
                        default:
                            return 0;
                        }
                    }
                    buttonHeight: 32
                    minButtonWidth: 36
                    textSize: Theme.fontSizeSmall
                    checkEnabled: false
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        const values = [3, 5, 10];
                        root.updateConfig("topProcessCount", values[index]);
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM

                StyledText {
                    width: parent.width - sortByButtons.width - Theme.spacingM
                    text: I18n.tr("Sort By")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankButtonGroup {
                    id: sortByButtons
                    model: ["CPU", "MEM"]
                    currentIndex: (cfg.topProcessSortBy ?? "cpu") === "cpu" ? 0 : 1
                    buttonHeight: 32
                    minButtonWidth: 48
                    textSize: Theme.fontSizeSmall
                    checkEnabled: false
                    onSelectionChanged: (index, selected) => {
                        if (!selected)
                            return;
                        root.updateConfig("topProcessSortBy", index === 0 ? "cpu" : "memory");
                    }
                }
            }
        }
    }

    SettingsDivider {}

    SettingsDropdownRow {
        text: I18n.tr("Layout")
        options: [I18n.tr("Auto"), I18n.tr("Grid"), I18n.tr("List")]
        currentValue: {
            switch (cfg.layoutMode ?? "auto") {
            case "grid":
                return I18n.tr("Grid");
            case "list":
                return I18n.tr("List");
            default:
                return I18n.tr("Auto");
            }
        }
        onValueChanged: value => {
            switch (value) {
            case I18n.tr("Grid"):
                root.updateConfig("layoutMode", "grid");
                return;
            case I18n.tr("List"):
                root.updateConfig("layoutMode", "list");
                return;
            default:
                root.updateConfig("layoutMode", "auto");
            }
        }
    }

    SettingsDivider {}

    SettingsSliderRow {
        text: I18n.tr("Transparency")
        minimum: 0
        maximum: 100
        value: Math.round((cfg.transparency ?? 0.8) * 100)
        unit: "%"
        onSliderValueChanged: newValue => root.updateConfig("transparency", newValue / 100)
    }

    SettingsDivider {}

    SettingsColorPicker {
        colorMode: cfg.colorMode ?? "primary"
        customColor: cfg.customColor ?? "#ffffff"
        onColorModeSelected: mode => root.updateConfig("colorMode", mode)
        onCustomColorSelected: selectedColor => root.updateConfig("customColor", selectedColor.toString())
    }

    SettingsDivider {}

    SettingsDisplayPicker {
        displayPreferences: cfg.displayPreferences ?? ["all"]
        onPreferencesChanged: prefs => root.updateConfig("displayPreferences", prefs)
    }

    SettingsDivider {}

    Item {
        width: parent.width
        height: resetRow.height + Theme.spacingM * 2

        Row {
            id: resetRow
            x: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingM

            DankButton {
                text: I18n.tr("Reset Position")
                backgroundColor: Theme.surfaceHover
                textColor: Theme.surfaceText
                buttonHeight: 36
                onClicked: {
                    if (!root.instanceId)
                        return;
                    SettingsData.updateDesktopWidgetInstance(root.instanceId, {
                        positions: {}
                    });
                }
            }

            DankButton {
                text: I18n.tr("Reset Size")
                backgroundColor: Theme.surfaceHover
                textColor: Theme.surfaceText
                buttonHeight: 36
                onClicked: {
                    if (!root.instanceId)
                        return;
                    SettingsData.updateDesktopWidgetInstance(root.instanceId, {
                        positions: {}
                    });
                }
            }
        }
    }
}
