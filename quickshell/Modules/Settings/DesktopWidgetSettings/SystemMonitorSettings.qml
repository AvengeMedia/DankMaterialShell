pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

DesktopWidgetInstanceSettings {
    id: root

    SettingsToggleRow {
        text: I18n.tr("Show header")
        checked: root.cfg.showHeader ?? true
        onToggled: checked => root.updateConfig("showHeader", checked)
    }

    SettingsDivider {}

    SettingsButtonGroupRow {
        readonly property var intervals: [60, 300, 600, 1800]
        text: I18n.tr("Graph time range")
        model: ["1m", "5m", "10m", "30m"]
        currentIndex: Math.max(0, intervals.indexOf(root.cfg.graphInterval ?? 60))
        checkEnabled: false
        onSelectionChanged: (index, selected) => {
            if (!selected)
                return;
            root.updateConfig("graphInterval", intervals[index]);
        }
    }

    SettingsDivider {}

    SettingsToggleRow {
        text: I18n.tr("CPU")
        checked: root.cfg.showCpu ?? true
        onToggled: checked => root.updateConfig("showCpu", checked)
    }

    SettingsDivider {
        visible: root.cfg.showCpu ?? true
    }

    SettingsToggleRow {
        enabled: root.cfg.showCpu ?? true
        text: I18n.tr("CPU graph")
        checked: root.cfg.showCpuGraph ?? true
        onToggled: checked => root.updateConfig("showCpuGraph", checked)
    }

    SettingsDivider {
        visible: root.cfg.showCpu ?? true
    }

    SettingsToggleRow {
        enabled: root.cfg.showCpu ?? true
        text: I18n.tr("CPU temperature")
        checked: root.cfg.showCpuTemp ?? true
        onToggled: checked => root.updateConfig("showCpuTemp", checked)
    }

    SettingsDivider {}

    SettingsToggleRow {
        text: I18n.tr("GPU temperature")
        checked: root.cfg.showGpuTemp ?? false
        onToggled: checked => root.updateConfig("showGpuTemp", checked)
    }

    SettingsDivider {
        visible: (root.cfg.showGpuTemp ?? false) && DgopService.availableGpus.length > 0
    }

    Item {
        width: parent.width
        height: gpuSelectColumn.height + Theme.spacingM * 2
        visible: (root.cfg.showGpuTemp ?? false) && DgopService.availableGpus.length > 0

        Column {
            id: gpuSelectColumn
            width: parent.width - Theme.spacingM * 2
            x: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("GPU", "graphics processor label in system monitor")
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

                        readonly property bool isSelected: (root.cfg.gpuPciId ?? "") === modelData.pciId

                        width: parent.width
                        height: 44
                        radius: Theme.cornerRadius
                        color: isSelected ? Theme.primarySelected : Theme.chipSurface
                        border.color: isSelected ? Theme.primary : Theme.withAlpha(Theme.primary, 0)
                        border.width: Theme.outlineWidthFocused

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
        checked: root.cfg.showMemory ?? true
        onToggled: checked => root.updateConfig("showMemory", checked)
    }

    SettingsDivider {
        visible: root.cfg.showMemory ?? true
    }

    SettingsToggleRow {
        enabled: root.cfg.showMemory ?? true
        text: I18n.tr("Memory graph")
        checked: root.cfg.showMemoryGraph ?? true
        onToggled: checked => root.updateConfig("showMemoryGraph", checked)
    }

    SettingsDivider {}

    SettingsToggleRow {
        text: I18n.tr("Network")
        checked: root.cfg.showNetwork ?? true
        onToggled: checked => root.updateConfig("showNetwork", checked)
    }

    SettingsDivider {
        visible: root.cfg.showNetwork ?? true
    }

    SettingsToggleRow {
        enabled: root.cfg.showNetwork ?? true
        text: I18n.tr("Network graph")
        checked: root.cfg.showNetworkGraph ?? true
        onToggled: checked => root.updateConfig("showNetworkGraph", checked)
    }

    SettingsDivider {}

    SettingsToggleRow {
        text: I18n.tr("Disk")
        checked: root.cfg.showDisk ?? true
        onToggled: checked => root.updateConfig("showDisk", checked)
    }

    SettingsDivider {}

    SettingsToggleRow {
        text: I18n.tr("Top processes")
        checked: root.cfg.showTopProcesses ?? false
        onToggled: checked => root.updateConfig("showTopProcesses", checked)
    }

    SettingsDivider {
        visible: root.cfg.showTopProcesses ?? false
    }

    SettingsButtonGroupRow {
        readonly property var counts: [3, 5, 10]
        visible: root.cfg.showTopProcesses ?? false
        text: I18n.tr("Process count")
        model: counts.map(count => String(count))
        currentIndex: Math.max(0, counts.indexOf(root.cfg.topProcessCount ?? 3))
        checkEnabled: false
        onSelectionChanged: (index, selected) => {
            if (!selected)
                return;
            root.updateConfig("topProcessCount", counts[index]);
        }
    }

    SettingsDivider {
        visible: root.cfg.showTopProcesses ?? false
    }

    SettingsButtonGroupRow {
        visible: root.cfg.showTopProcesses ?? false
        text: I18n.tr("Sort by")
        model: ["CPU", "MEM"]
        currentIndex: (root.cfg.topProcessSortBy ?? "cpu") === "cpu" ? 0 : 1
        checkEnabled: false
        onSelectionChanged: (index, selected) => {
            if (!selected)
                return;
            root.updateConfig("topProcessSortBy", index === 0 ? "cpu" : "memory");
        }
    }

    SettingsDivider {}

    SettingsDropdownRow {
        text: I18n.tr("Layout")
        options: [I18n.tr("Auto"), I18n.tr("Grid"), I18n.tr("List")]
        currentValue: {
            switch (root.cfg.layoutMode ?? "auto") {
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
}
