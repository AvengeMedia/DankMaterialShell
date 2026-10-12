pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Settings.Widgets
import "../../Common/Format.js" as Format
import "Drives.js" as Drives
import "../../Services/SysmonDevices.js" as Devices

Rectangle {
    id: root

    // Drive object from drives.list; mounts is DgopService's diskmounts list
    property var drive: null
    property var mounts: []

    signal reportRequested(var drive)
    signal installRequested

    readonly property string level: Drives.healthLevel(drive)
    readonly property bool asleep: drive?.asleep ?? false
    readonly property var rates: (DgopService.diskRates ?? []).find(d => d.device === drive?.name) ?? null
    readonly property var history: DgopService.deviceHistory[Devices.deviceKey("disk", drive?.name ?? "")] ?? ({})
    readonly property real axisMax: Devices.rateAxisMax(history.a, history.b, 1024 * 1024)
    readonly property var strip: Drives.partitionStrip(drive, mounts)
    readonly property var allRows: Drives.summaryRows(drive)
    readonly property var powerOn: allRows.find(r => r.id === "powerOnTime") ?? null
    readonly property var smartRows: allRows.filter(r => r.id !== "wear" && r.id !== "powerOnTime" && r.id !== "dataWritten")
    readonly property var wear: drive?.nvme?.percentUsed ?? null
    readonly property color healthTint: level === "failing" ? Theme.error : level === "warning" ? Theme.warning : Theme.success
    readonly property real pad: Theme.spacingL
    property bool expanded: false

    implicitHeight: body.implicitHeight + pad * 2
    radius: Theme.cornerRadiusL
    color: Theme.surfaceContainerLow

    function rowLabel(id) {
        switch (id) {
        case "criticalWarning":
            return I18n.tr("Critical warning");
        case "spare":
            return I18n.tr("Spare blocks left");
        case "mediaErrors":
            return I18n.tr("Media errors");
        case "dataRead":
            return I18n.tr("Data read");
        case "dataWritten":
            return I18n.tr("Data written");
        case "unsafeShutdowns":
            return I18n.tr("Unsafe shutdowns");
        case "powerOnTime":
            return I18n.tr("Power-on time");
        case "selftest":
            return I18n.tr("Last self-test");
        case "reallocated":
            return I18n.tr("Reallocated sectors");
        case "pending":
            return I18n.tr("Current pending sectors");
        case "uncorrectable":
            return I18n.tr("Offline uncorrectable");
        case "crc":
            return I18n.tr("Cable errors");
        case "startStop":
            return I18n.tr("Start/stop count");
        case "loadCycles":
            return I18n.tr("Head load cycles");
        case "spinUp":
            return I18n.tr("Spin-up time");
        }
        return id;
    }

    function rowValue(r) {
        if (!r)
            return "";
        if (r.id === "powerOnTime") {
            const text = r.unit === "hours" ? I18n.tr("%1 hours") : r.unit === "days" ? I18n.tr("%1 days") : I18n.tr("%1 years");
            return text.arg(r.value);
        }
        if (r.id === "criticalWarning" && r.value === "none")
            return I18n.tr("None");
        if (r.id === "selftest")
            return r.value === "ok" ? I18n.tr("OK") : r.value === "running" ? I18n.tr("Running") : I18n.tr("Error");
        return r.value;
    }

    function healthText() {
        const w = Drives.healthWord(level);
        return w === "critical" ? I18n.tr("Critical", "drive health") : w === "warning" ? I18n.tr("Warning") : I18n.tr("Healthy", "drive health");
    }

    function warnTooltip() {
        return Drives.warnRows(drive).map(r => rowLabel(r.id) + ": " + rowValue(r)).join("\n");
    }

    function partitionTooltip(device) {
        const p = (drive?.partitions ?? []).find(x => x.device === device);
        if (!p)
            return "";
        return [p.fsType ?? "", Devices.formatBytes(p.size)].filter(s => s !== "").join(", ");
    }

    function segmentDetail(seg) {
        if (seg.usedRatio !== null && seg.size > 0)
            return I18n.tr("%1 of %2 used", "partition space, e.g. 1.2 TB of 2 TB used").arg(Drives.formatCapacity(seg.size * seg.usedRatio)).arg(Drives.formatCapacity(seg.size));
        return seg.size > 0 ? Drives.formatCapacity(seg.size) : "";
    }

    ColumnLayout {
        id: body
        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        spacing: Theme.spacingL

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingL

            Rectangle {
                Layout.preferredWidth: Theme.iconButtonSize
                Layout.preferredHeight: Layout.preferredWidth
                radius: Theme.cornerRadiusM
                color: Theme.secondaryContainer

                DIcon {
                    anchors.centerIn: parent
                    name: root.drive?.kind === "hdd" ? "album" : "hard_drive"
                    size: Theme.iconSize
                    color: Theme.onSecondaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.drive?.model || root.drive?.name || ""
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: Drives.driveSubtitle(root.drive)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
            }

            MetricChart {
                visible: !root.expanded
                Layout.preferredWidth: Theme.iconButtonSize * 2
                Layout.preferredHeight: Theme.buttonHeightXXS
                compact: true
                values: root.history.a ?? []
                secondaryValues: root.history.b ?? []
                maximum: root.axisMax
                historyLength: DgopService.deviceHistorySize
            }

            NumericText {
                visible: root.drive?.temperature != null
                isMonospace: false
                text: Devices.formatTemp(root.drive?.temperature ?? null, SettingsData.useFahrenheit)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            Pill {
                visible: root.asleep
                text: I18n.tr("Asleep")
                dotColor: Theme.surfaceVariantText
                tooltip: (root.drive?.smartUpdated ?? 0) > 0 ? Qt.formatDateTime(new Date(root.drive.smartUpdated * 1000), Locale.ShortFormat) : ""
            }

            Pill {
                visible: root.level !== ""
                text: root.healthText()
                dotColor: root.healthTint
                textColor: root.level === "healthy" ? Theme.surfaceText : root.healthTint
                tooltip: root.warnTooltip()
            }

            DActionButton {
                iconName: "expand_more"
                rotation: root.expanded ? 180 : 0
                tooltipText: root.expanded ? I18n.tr("Collapse") : I18n.tr("Expand")
                onClicked: root.expanded = !root.expanded
            }
        }

        RowLayout {
            visible: root.expanded
            Layout.fillWidth: true
            spacing: Theme.spacingL

            ChartCard {
                Layout.fillWidth: true
                Layout.horizontalStretchFactor: 3
                Layout.alignment: Qt.AlignTop
                cardColor: Theme.surfaceContainer
                chartHeight: Math.max(Theme.listItemHeight * 1.5, stats.height - Theme.spacingL * 2 - Theme.spacingS * 2 - Theme.fontSizeSmall * 3)
                label: I18n.tr("Read")
                valueText: root.rates?.readRate != null ? Devices.formatRate(root.rates.readRate, false) : "—"
                secondaryLabel: I18n.tr("Write")
                secondaryValueText: root.rates?.writeRate != null ? Devices.formatRate(root.rates.writeRate, false) : "—"
                values: root.history.a ?? []
                secondaryValues: root.history.b ?? []
                maximum: root.axisMax
                maximumText: Devices.formatRate(root.axisMax, false)
                historyLength: DgopService.deviceHistorySize
            }

            SettingsGroup {
                id: stats
                Layout.fillWidth: true
                Layout.horizontalStretchFactor: 2
                Layout.alignment: Qt.AlignTop
                customPaddingV: 0
                customPaddingH: Theme.spacingL

                StatRow {
                    visible: !root.asleep && root.rates?.busy != null
                    height: Theme.buttonHeightXS
                    label: I18n.tr("Busy")
                    value: Math.round(root.rates?.busy ?? 0) + "%"
                }

                StatRow {
                    visible: !root.asleep && root.rates?.responseTime != null
                    height: Theme.buttonHeightXS
                    label: I18n.tr("Response time")
                    value: (root.rates?.responseTime ?? 0).toFixed(2) + " ms"
                }

                StatRow {
                    visible: root.wear !== null
                    height: Theme.buttonHeightXS
                    label: I18n.tr("Wear")
                    value: root.wear + "%"
                    tooltip: I18n.tr("Share of the rated write endurance used up")
                }

                StatRow {
                    visible: root.powerOn !== null
                    height: Theme.buttonHeightXS
                    label: I18n.tr("Power-on time")
                    value: root.rowValue(root.powerOn)
                }

                StatRow {
                    visible: root.drive?.nvme?.dataWritten != null
                    height: Theme.buttonHeightXS
                    label: I18n.tr("Written total", "lifetime data written to a drive")
                    value: Devices.formatBytes(root.drive?.nvme?.dataWritten ?? 0)
                }

                StatRow {
                    visible: !!root.drive?.firmware
                    height: Theme.buttonHeightXS
                    label: I18n.tr("Firmware", "drive firmware revision")
                    value: root.drive?.firmware ?? ""
                }

                Repeater {
                    model: root.smartRows

                    StatRow {
                        required property var modelData
                        height: Theme.buttonHeightXS
                        label: root.rowLabel(modelData.id)
                        value: root.rowValue(modelData)
                    }
                }
            }
        }

        RowLayout {
            visible: root.expanded
            Layout.fillWidth: true
            spacing: Theme.spacingL

            Item {
                id: stripRow
                visible: root.strip.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.buttonHeightS

                Row {
                    anchors.fill: parent
                    spacing: Theme.spacingXS

                    Repeater {
                        model: root.strip

                        ClippingRectangle {
                            id: seg

                            required property var modelData

                            width: Math.max(0, stripRow.width - Theme.spacingXS * (root.strip.length - 1)) * modelData.weight
                            height: stripRow.height
                            radius: Theme.cornerRadiusS
                            color: Theme.surfaceContainerHighest

                            Rectangle {
                                visible: seg.modelData.usedRatio !== null
                                width: parent.width * (seg.modelData.usedRatio ?? 0)
                                height: parent.height
                                color: Theme.withAlpha(Theme.primary, 0.28)
                            }

                            StyledText {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS + Theme.spacingXXS
                                anchors.rightMargin: Theme.spacingS + Theme.spacingXXS
                                verticalAlignment: Text.AlignVCenter
                                textFormat: Text.StyledText
                                text: {
                                    const name = seg.modelData.swap ? I18n.tr("Swap") : seg.modelData.label;
                                    const detail = root.segmentDetail(seg.modelData);
                                    return "<b>" + Format.escapeHtml(name) + "</b>" + (detail ? " " + Format.escapeHtml(detail) : "");
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                wrapMode: Text.NoWrap
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: segHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            DTooltipHost {
                                text: root.partitionTooltip(seg.modelData.device)
                                target: seg
                                hoverArea: segHover
                            }
                        }
                    }
                }
            }

            Item {
                visible: root.strip.length === 0
                Layout.fillWidth: true
            }

            StyledText {
                visible: DriveService.smartctlPath === "" && DriveService.installCommand === ""
                text: I18n.tr("Requires %1", "missing program", true).arg("smartctl")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            DButton {
                visible: DriveService.smartctlPath === "" && DriveService.installCommand !== ""
                text: I18n.tr("Install smartmontools")
                iconName: "download"
                backgroundColor: Theme.secondaryContainer
                textColor: Theme.onSecondaryContainer
                onClicked: root.installRequested()
            }

            DButton {
                visible: DriveService.smartctlPath !== ""
                text: I18n.tr("Full SMART report")
                iconName: "lock_open"
                backgroundColor: Theme.secondaryContainer
                textColor: Theme.onSecondaryContainer
                tooltipText: I18n.tr("Authentication Required")
                enabled: !DriveService.reporting || DriveService.reportDevice === root.drive.device
                onClicked: root.reportRequested(root.drive)
            }
        }
    }

    component Pill: Rectangle {
        id: pill

        property string text: ""
        property color dotColor: Theme.success
        property color textColor: Theme.surfaceText
        property string tooltip: ""

        implicitWidth: pillRow.implicitWidth + Theme.spacingM * 2
        implicitHeight: Theme.buttonHeightXS
        radius: height / 2
        color: Theme.surfaceContainerHighest

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: Theme.spacingS

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.spacingS
                height: width
                radius: width / 2
                color: pill.dotColor
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.text
                font.pixelSize: Theme.fontSizeSmall
                color: pill.textColor
            }
        }

        MouseArea {
            id: pillHover
            anchors.fill: parent
            hoverEnabled: pill.tooltip !== ""
            acceptedButtons: Qt.NoButton
        }

        DTooltipHost {
            text: pill.tooltip
            target: pill
            hoverArea: pillHover
        }
    }
}
