pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Settings.Widgets
import "SystemInfo.js" as SystemInfo
import "../../Services/SysmonDevices.js" as Devices

Item {
    id: root

    // The page's one action sits in a FAB, like Settings pages; SettingsFabBar finds this property.
    property var fabBar: null

    Ref {
        service: DgopService
        modules: ["system", "cpu", "memory-modules", "sensors"]
        active: root.visible
    }

    Ref {
        service: DriveService
        active: root.visible
    }

    readonly property var displayRows: {
        const outputs = (WlrOutputService.outputs ?? []).filter(o => o.enabled && o.currentMode);
        if (outputs.length > 0)
            return outputs.map(o => SystemInfo.modeText(o.currentMode));
        return Quickshell.screens.map(s => SystemInfo.modeText({
                "width": Math.round(s.width * s.devicePixelRatio),
                "height": Math.round(s.height * s.devicePixelRatio)
            }));
    }

    readonly property string networkText: {
        if (NetworkService.ethernetConnected) {
            const dev = (NetworkService.ethernetDevices ?? []).find(d => d.name === NetworkService.ethernetInterface);
            const speed = dev?.speed > 0 ? (dev.speed >= 1000 ? dev.speed / 1000 + " Gbit/s" : dev.speed + " Mbit/s") : "";
            return [I18n.tr("Ethernet"), speed].filter(s => s).join(", ");
        }
        if (NetworkService.wifiConnected)
            return I18n.tr("Wi-Fi");
        return NetworkService.networkAvailable ? I18n.tr("Disconnected") : "";
    }

    readonly property var softwareRows: [
        {
            "label": I18n.tr("Distribution", "system info label"),
            "value": DgopService.distribution
        },
        {
            "label": I18n.tr("Kernel", "system info label"),
            "value": DgopService.kernelVersion,
            "tooltip": DgopService.architecture
        },
        {
            "label": I18n.tr("Compositor"),
            "value": CompositorService.displayName
        },
        {
            "label": "DMS",
            "value": ShellVersionService.shellVersion
        },
        {
            "label": I18n.tr("Init", "init system, e.g. systemd"),
            "value": DgopService.initSystem ?? ""
        },
        {
            "label": I18n.tr("Uptime"),
            "value": DgopService.uptime ? DgopService.uptime.slice(3) : ""
        },
        {
            "label": I18n.tr("Processes"),
            "value": DgopService.processCount > 0 ? DgopService.processCount.toString() : ""
        }
    ]

    readonly property var hardwareRows: {
        const rows = [
            {
                "label": I18n.tr("Board"),
                "value": DgopService.bios?.motherboard ?? ""
            },
            {
                "label": I18n.tr("BIOS"),
                "value": DgopService.bios?.version ?? "",
                "tooltip": DgopService.bios?.date ?? ""
            },
            {
                "label": I18n.tr("CPU"),
                "value": DgopService.cpuModel
            },
            {
                "label": I18n.tr("Memory"),
                "value": Devices.memoryModulesSummary(DgopService.memoryModules?.modules) || (DgopService.totalMemoryKB > 0 ? DgopService.formatSystemMemory(DgopService.totalMemoryKB) : "")
            }
        ];
        for (const gpu of DgopService.availableGpus ?? [])
            rows.push({
                "label": I18n.tr("GPU"),
                "value": gpu.displayName,
                "tooltip": gpu.fullName !== gpu.displayName ? gpu.fullName : ""
            });
        rows.push({
            "label": I18n.tr("Storage", "total drive capacity, e.g. 2 TB + 4 TB NVMe"),
            "value": SystemInfo.storageSummary(DriveService.drives),
            "tooltip": (DriveService.drives ?? []).map(d => d.model || d.name).join("\n")
        });
        for (const mode of root.displayRows)
            rows.push({
                "label": I18n.tr("Display"),
                "value": mode
            });
        rows.push({
            "label": I18n.tr("Network"),
            "value": root.networkText
        });
        return rows;
    }

    readonly property var sensorNames: ({
            "cpu": I18n.tr("CPU"),
            "gpu": I18n.tr("GPU"),
            "memory": I18n.tr("Memory")
        })
    readonly property var gpuNames: (DgopService.gpuStats ?? []).map(g => ({
                "pciSlot": g.pciSlot,
                "name": g.name
            }))
    readonly property var sensorRows: SystemInfo.sensorRows(DgopService.sensors, DriveService.drives, gpuNames, sensorNames, SettingsData.useFahrenheit)
    readonly property int sensorSplit: Math.ceil(sensorRows.length / 2)

    function copySystemInfo() {
        const text = SystemInfo.plainText(DgopService.hostname, [
            {
                "title": I18n.tr("Software", "system info section"),
                "rows": softwareRows
            },
            {
                "title": I18n.tr("Hardware", "system info section"),
                "rows": hardwareRows
            }
        ]);
        Quickshell.execDetached([Proc.dmsBin, "cl", "copy", text]);
        ToastService.showInfo(I18n.tr("Copied to clipboard"));
    }

    DFlickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight + (root.fabBar?.reservedHeight ?? 0)

        ColumnLayout {
            id: column
            width: scroll.width
            spacing: Theme.spacingL

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingL

                StyledText {
                    Layout.fillWidth: true
                    text: DgopService.hostname
                    font.pixelSize: Theme.fontSizeXXLarge
                    color: Theme.surfaceText
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }

            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 640 ? 2 : 1
                columnSpacing: Theme.spacingXL
                rowSpacing: Theme.spacingL

                InfoColumn {
                    title: I18n.tr("Software", "system info section")
                    rows: root.softwareRows
                }

                InfoColumn {
                    title: I18n.tr("Hardware", "system info section")
                    rows: root.hardwareRows
                }
            }

            ColumnLayout {
                visible: root.sensorRows.length > 0
                Layout.fillWidth: true
                spacing: 0

                SettingsSectionLabel {
                    Layout.fillWidth: true
                    text: I18n.tr("Sensors", "hardware sensors section")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.groupedListGap

                    SensorGroup {
                        rows: root.sensorRows.slice(0, root.sensorSplit)
                    }

                    SensorGroup {
                        rows: root.sensorRows.slice(root.sensorSplit)
                    }
                }
            }
        }
    }

    component InfoColumn: ColumnLayout {
        id: info

        property string title: ""
        property var rows: []

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 0

        SettingsSectionLabel {
            Layout.fillWidth: true
            text: info.title
        }

        SettingsGroup {
            Layout.fillWidth: true
            customPaddingV: 0
            customPaddingH: Theme.spacingL

            Repeater {
                model: info.rows

                StatRow {
                    required property var modelData
                    visible: !!modelData.value
                    label: modelData.label
                    value: modelData.value
                    tooltip: modelData.tooltip ?? ""
                }
            }
        }
    }

    component SensorGroup: SettingsGroup {
        id: group

        property var rows: []

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        customPaddingV: 0
        customPaddingH: Theme.spacingL

        Repeater {
            model: group.rows

            Item {
                id: sensor

                required property var modelData

                height: Theme.iconButtonSize

                StyledText {
                    anchors.left: parent.left
                    anchors.right: bar.left
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    text: sensor.modelData.name
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }

                Rectangle {
                    id: bar
                    anchors.right: valueText.left
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(120, sensor.width / 4)
                    height: Theme.spacingS
                    radius: height / 2
                    color: Theme.surfaceContainerHighest
                    opacity: sensor.modelData.ratio === null ? 0 : 1

                    Rectangle {
                        width: parent.width * (sensor.modelData.ratio ?? 0)
                        height: parent.height
                        radius: height / 2
                        color: (sensor.modelData.ratio ?? 0) >= 0.9 ? Theme.error : Theme.primary
                    }
                }

                NumericText {
                    id: valueText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconButtonSize * 2
                    isMonospace: false
                    text: sensor.modelData.value
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    SettingsFabBar {
        DFab {
            text: I18n.tr("Copy system info", "button, copies a plain-text summary of software and hardware")
            iconName: "content_copy"
            onClicked: root.copySystemInfo()
        }
    }
}
