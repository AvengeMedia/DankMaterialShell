import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    Component.onCompleted: {
        DgopService.addRef(["system", "cpu"]);
    }

    Component.onDestruction: {
        DgopService.removeRef(["system", "cpu"]);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingM

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: systemInfoColumn.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

            ColumnLayout {
                id: systemInfoColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Row {
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "computer"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: I18n.tr("System Information", "system info header in system monitor")
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: Theme.spacingS
                    columnSpacing: Theme.spacingXL

                    InfoRow {
                        label: I18n.tr("Hostname", "system info label")
                        value: DgopService.hostname || "--"
                    }
                    InfoRow {
                        label: I18n.tr("Distribution", "system info label")
                        value: DgopService.distribution || "--"
                    }
                    InfoRow {
                        label: I18n.tr("Kernel", "system info label")
                        value: DgopService.kernelVersion || "--"
                    }
                    InfoRow {
                        label: I18n.tr("Architecture", "system info label")
                        value: DgopService.architecture || "--"
                    }
                    InfoRow {
                        label: I18n.tr("CPU")
                        value: DgopService.cpuModel || ("" + DgopService.cpuCores + " cores")
                    }
                    InfoRow {
                        label: I18n.tr("Uptime")
                        value: DgopService.uptime || "--"
                    }
                    InfoRow {
                        label: I18n.tr("Load Average", "system info label")
                        value: DgopService.loadAverage || "--"
                    }
                    InfoRow {
                        label: I18n.tr("Processes")
                        value: DgopService.processCount > 0 ? DgopService.processCount.toString() : "--"
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Row {
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "developer_board"
                        size: Theme.iconSize
                        color: Theme.secondary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: I18n.tr("GPU Monitoring", "gpu section header in system monitor")
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.outlineLight
                }

                DankListView {
                    id: gpuListView

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8

                    model: DgopService.availableGpus

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: gpuListView.width
                        height: 80
                        radius: Theme.cornerRadius
                        color: {
                            const vendor = (modelData?.vendor ?? "").toLowerCase();
                            if (vendor.includes("nvidia"))
                                return Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.08);
                            if (vendor.includes("amd"))
                                return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.08);
                            if (vendor.includes("intel"))
                                return Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.08);
                            return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08);
                        }
                        border.color: {
                            const vendor = (modelData?.vendor ?? "").toLowerCase();
                            if (vendor.includes("nvidia"))
                                return Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.2);
                            if (vendor.includes("amd"))
                                return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2);
                            if (vendor.includes("intel"))
                                return Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.2);
                            return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2);
                        }
                        border.width: 1

                        readonly property bool tempEnabled: {
                            const pciId = modelData?.pciId ?? "";
                            if (!pciId)
                                return false;
                            return SessionData.enabledGpuPciIds ? SessionData.enabledGpuPciIds.indexOf(pciId) !== -1 : false;
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "developer_board"
                                size: Theme.iconSize + 4
                                color: {
                                    const vendor = (modelData?.vendor ?? "").toLowerCase();
                                    if (vendor.includes("nvidia"))
                                        return Theme.success;
                                    if (vendor.includes("amd"))
                                        return Theme.error;
                                    if (vendor.includes("intel"))
                                        return Theme.info;
                                    return Theme.surfaceVariantText;
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: Theme.spacingXS

                                StyledText {
                                    text: modelData?.displayName ?? I18n.tr("Unknown GPU", "fallback gpu name")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                }

                                Row {
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: modelData?.vendor ?? ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: "•"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        visible: (modelData?.driver ?? "").length > 0
                                    }

                                    StyledText {
                                        text: modelData?.driver ?? ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        visible: (modelData?.driver ?? "").length > 0
                                    }
                                }

                                StyledText {
                                    text: modelData?.pciId ?? ""
                                    font.pixelSize: Theme.fontSizeSmall - 2
                                    font.family: SettingsData.monoFontFamily
                                    color: Theme.surfaceVariantText
                                    opacity: 0.7
                                }
                            }

                            Rectangle {
                                width: 70
                                height: 32
                                radius: Theme.cornerRadius
                                color: parent.parent.tempEnabled ? Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3) : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.15)
                                border.color: tempMouseArea.containsMouse ? Theme.outline : "transparent"
                                border.width: 1

                                Row {
                                    id: tempRow
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        name: "thermostat"
                                        size: 16
                                        color: {
                                            if (!parent.parent.parent.parent.tempEnabled)
                                                return Theme.surfaceVariantText;
                                            const temp = modelData?.temperature ?? 0;
                                            if (temp > 85)
                                                return Theme.error;
                                            if (temp > 70)
                                                return Theme.warning;
                                            return Theme.surfaceText;
                                        }
                                        opacity: parent.parent.parent.parent.tempEnabled ? 1 : 0.5
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: {
                                            if (!parent.parent.parent.parent.tempEnabled)
                                                return I18n.tr("Off");
                                            const temp = modelData?.temperature ?? 0;
                                            return temp > 0 ? (temp.toFixed(0) + "°C") : "--";
                                        }
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.family: parent.parent.parent.parent.tempEnabled ? SettingsData.monoFontFamily : ""
                                        font.weight: parent.parent.parent.parent.tempEnabled ? Font.Bold : Font.Normal
                                        color: {
                                            if (!parent.parent.parent.parent.tempEnabled)
                                                return Theme.surfaceVariantText;
                                            const temp = modelData?.temperature ?? 0;
                                            if (temp > 85)
                                                return Theme.error;
                                            if (temp > 70)
                                                return Theme.warning;
                                            return Theme.surfaceText;
                                        }
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: tempMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const pciId = modelData?.pciId;
                                        if (!pciId)
                                            return;

                                        const enabledIds = SessionData.enabledGpuPciIds ? SessionData.enabledGpuPciIds.slice() : [];
                                        const idx = enabledIds.indexOf(pciId);
                                        const wasEnabled = idx !== -1;

                                        if (!wasEnabled) {
                                            enabledIds.push(pciId);
                                            DgopService.addGpuPciId(pciId);
                                        } else {
                                            enabledIds.splice(idx, 1);
                                            DgopService.removeGpuPciId(pciId);
                                        }

                                        SessionData.setEnabledGpuPciIds(enabledIds);
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.shortDuration
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 300
                        height: 100
                        radius: Theme.cornerRadius
                        color: "transparent"
                        visible: DgopService.availableGpus.length === 0

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "developer_board_off"
                                size: 32
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: I18n.tr("No GPUs detected", "empty state in gpu list")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
            }
        }
    }

    component InfoRow: RowLayout {
        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        spacing: Theme.spacingS

        StyledText {
            text: label + ":"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceVariantText
            Layout.preferredWidth: 100
        }

        StyledText {
            text: value
            font.pixelSize: Theme.fontSizeSmall
            font.family: SettingsData.monoFontFamily
            color: Theme.surfaceText
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }
}
