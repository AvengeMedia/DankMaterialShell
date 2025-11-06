import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

DankFlickable {
    anchors.fill: parent
    contentHeight: systemColumn.implicitHeight
    clip: true
    Component.onCompleted: {
        DgopService.addRef(["system", "hardware", "diskmounts"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["system", "hardware", "diskmounts"]);
    }

    Column {
        id: systemColumn

        width: parent.width
        spacing: Theme.spacingM

        Rectangle {
            width: parent.width
            height: systemInfoColumn.implicitHeight + 2 * Theme.spacingL
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
            border.width: 0

            Column {
                id: systemInfoColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingL

                Row {
                    width: parent.width
                    spacing: Theme.spacingL

                    SystemLogo {
                        width: 80
                        height: 80
                    }

                    Column {
                        width: parent.width - 80 - Theme.spacingL
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        StyledText {
                            text: DgopService.hostname
                            font.pixelSize: Theme.fontSizeXLarge
                            font.family: SettingsData.monoFontFamily
                            font.weight: Font.Light
                            color: Theme.surfaceText
                            verticalAlignment: Text.AlignVCenter
                        }

                        StyledText {
                            text: `${DgopService.distribution} • ${DgopService.architecture} • ${DgopService.kernelVersion}`
                            font.pixelSize: Theme.fontSizeMedium
                            font.family: SettingsData.monoFontFamily
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                            verticalAlignment: Text.AlignVCenter
                        }

                        StyledText {
                            text: `${UserInfoService.uptime} • Boot: ${DgopService.bootTime}`
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                            verticalAlignment: Text.AlignVCenter
                        }

                        StyledText {
                            text: `Load: ${DgopService.loadAverage} • ${DgopService.processCount} processes, ${DgopService.threadCount} threads`
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.6)
                            verticalAlignment: Text.AlignVCenter
                        }

                    }

                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingXL

                    Rectangle {
                        width: (parent.width - Theme.spacingXL) / 2
                        height: hardwareColumn.implicitHeight + Theme.spacingL
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                        border.width: 1
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)

                        Column {
                            id: hardwareColumn

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingXS

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: "memory"
                                    size: Theme.iconSizeSmall
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: I18n.tr("System")
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: SettingsData.monoFontFamily
                                    font.weight: Font.Bold
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                            }

                            StyledText {
                                text: DgopService.cpuModel
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                width: parent.width
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                                maximumLineCount: 1
                                verticalAlignment: Text.AlignVCenter
                            }

                            StyledText {
                                text: DgopService.motherboard
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.8)
                                width: parent.width
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                                maximumLineCount: 1
                                verticalAlignment: Text.AlignVCenter
                            }

                            StyledText {
                                text: `BIOS ${DgopService.biosVersion}`
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                                width: parent.width
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                            StyledText {
                                text: `${DgopService.formatSystemMemory(DgopService.totalMemoryKB)} RAM`
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.8)
                                width: parent.width
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                        }

                    }

                    Rectangle {
                        width: (parent.width - Theme.spacingXL) / 2
                        height: gpuColumn.implicitHeight + Theme.spacingL
                        radius: Theme.cornerRadius
                        color: {
                            const baseColor = Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency);
                            const hoverColor = Qt.rgba(Theme.surfaceContainerHigh.r, Theme.surfaceContainerHigh.g, Theme.surfaceContainerHigh.b, Theme.popupTransparency * 1.5);
                            if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
                                return gpuCardMouseArea.containsMouse && DgopService.availableGpus.length > 1 ? hoverColor : baseColor;
                            }

                            const gpu = DgopService.availableGpus[Math.min(SessionData.selectedGpuIndex, DgopService.availableGpus.length - 1)];
                            const vendor = gpu.fullName.split(' ')[0].toLowerCase();
                            let tintColor;
                            if (vendor.includes("nvidia")) {
                                tintColor = Theme.success;
                            } else if (vendor.includes("amd")) {
                                tintColor = Theme.error;
                            } else if (vendor.includes("intel")) {
                                tintColor = Theme.info;
                            } else {
                                return gpuCardMouseArea.containsMouse && DgopService.availableGpus.length > 1 ? hoverColor : baseColor;
                            }
                            if (gpuCardMouseArea.containsMouse && DgopService.availableGpus.length > 1) {
                                return Qt.rgba((hoverColor.r + tintColor.r * 0.1) / 1.1, (hoverColor.g + tintColor.g * 0.1) / 1.1, (hoverColor.b + tintColor.b * 0.1) / 1.1, 0.6);
                            } else {
                                return Qt.rgba((baseColor.r + tintColor.r * 0.08) / 1.08, (baseColor.g + tintColor.g * 0.08) / 1.08, (baseColor.b + tintColor.b * 0.08) / 1.08, 0.4);
                            }
                        }
                        border.width: 1
                        border.color: {
                            if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
                                return Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1);
                            }

                            const gpu = DgopService.availableGpus[Math.min(SessionData.selectedGpuIndex, DgopService.availableGpus.length - 1)];
                            const vendor = gpu.fullName.split(' ')[0].toLowerCase();
                            if (vendor.includes("nvidia")) {
                                return Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.3);
                            } else if (vendor.includes("amd")) {
                                return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.3);
                            } else if (vendor.includes("intel")) {
                                return Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.3);
                            }
                            return Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1);
                        }

                        MouseArea {
                            id: gpuCardMouseArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: DgopService.availableGpus.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (DgopService.availableGpus.length > 1) {
                                    const nextIndex = (SessionData.selectedGpuIndex + 1) % DgopService.availableGpus.length;
                                    SessionData.setSelectedGpuIndex(nextIndex);
                                }
                            }
                        }

                        Column {
                            id: gpuColumn

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingXS

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: "auto_awesome_mosaic"
                                    size: Theme.iconSizeSmall
                                    color: Theme.secondary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: "GPU"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: SettingsData.monoFontFamily
                                    font.weight: Font.Bold
                                    color: Theme.secondary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                            }

                            StyledText {
                                text: {
                                    if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
                                        return "No GPUs detected";
                                    }

                                    const gpu = DgopService.availableGpus[Math.min(SessionData.selectedGpuIndex, DgopService.availableGpus.length - 1)];
                                    return gpu.fullName;
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                width: parent.width
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                verticalAlignment: Text.AlignVCenter
                            }

                            StyledText {
                                text: {
                                    if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
                                        return "Device: N/A";
                                    }

                                    const gpu = DgopService.availableGpus[Math.min(SessionData.selectedGpuIndex, DgopService.availableGpus.length - 1)];
                                    return `Device: ${gpu.pciId}`;
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.8)
                                width: parent.width
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                                textFormat: Text.RichText
                            }

                            StyledText {
                                text: {
                                    if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
                                        return "Driver: N/A";
                                    }

                                    const gpu = DgopService.availableGpus[Math.min(SessionData.selectedGpuIndex, DgopService.availableGpus.length - 1)];
                                    return `Driver: ${gpu.driver}`;
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.8)
                                width: parent.width
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                            StyledText {
                                text: {
                                    if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
                                        return "Temp: --°";
                                    }

                                    const gpu = DgopService.availableGpus[Math.min(SessionData.selectedGpuIndex, DgopService.availableGpus.length - 1)];
                                    const temp = gpu.temperature;
                                    return `Temp: ${(temp === undefined || temp === null || temp === 0) ? '--°' : `${Math.round(temp)}°C`}`;
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                color: {
                                    if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
                                        return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7);
                                    }

                                    const gpu = DgopService.availableGpus[Math.min(SessionData.selectedGpuIndex, DgopService.availableGpus.length - 1)];
                                    const temp = gpu.temperature || 0;
                                    if (temp > 80) {
                                        return Theme.error;
                                    }

                                    if (temp > 60) {
                                        return Theme.warning;
                                    }

                                    return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7);
                                }
                                width: parent.width
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
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

        }

        Rectangle {
            width: parent.width
            height: storageColumn.implicitHeight + 2 * Theme.spacingL
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
            border.width: 0

            Column {
                id: storageColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingS

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "storage"
                        size: Theme.iconSize
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: I18n.tr("Storage & Disks")
                        font.pixelSize: Theme.fontSizeLarge
                        font.family: SettingsData.monoFontFamily
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                }

                Column {
                    width: parent.width
                    spacing: 2

                    Row {
                        width: parent.width
                        height: 24
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Device")
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            width: parent.width * 0.25
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        StyledText {
                            text: I18n.tr("Mount")
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            width: parent.width * 0.2
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        StyledText {
                            text: I18n.tr("Size")
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            width: parent.width * 0.15
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        StyledText {
                            text: I18n.tr("Used")
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            width: parent.width * 0.15
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        StyledText {
                            text: I18n.tr("Available")
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            width: parent.width * 0.15
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        StyledText {
                            text: I18n.tr("Use%")
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            width: parent.width * 0.1
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                    }

                    Repeater {
                        id: diskMountRepeater

                        model: DgopService.diskMounts

                        Rectangle {
                            width: parent.width
                            height: 24
                            radius: Theme.cornerRadius
                            color: diskMouseArea.containsMouse ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.04) : "transparent"

                            MouseArea {
                                id: diskMouseArea

                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            Row {
                                anchors.fill: parent
                                spacing: Theme.spacingS

                                StyledText {
                                    text: modelData.device
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: SettingsData.monoFontFamily
                                    color: Theme.surfaceText
                                    width: parent.width * 0.25
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                StyledText {
                                    text: modelData.mount
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: SettingsData.monoFontFamily
                                    color: Theme.surfaceText
                                    width: parent.width * 0.2
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                StyledText {
                                    text: modelData.size
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: SettingsData.monoFontFamily
                                    color: Theme.surfaceText
                                    width: parent.width * 0.15
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                StyledText {
                                    text: modelData.used
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: SettingsData.monoFontFamily
                                    color: Theme.surfaceText
                                    width: parent.width * 0.15
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                StyledText {
                                    text: modelData.avail
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: SettingsData.monoFontFamily
                                    color: Theme.surfaceText
                                    width: parent.width * 0.15
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                StyledText {
                                    text: modelData.percent
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: SettingsData.monoFontFamily
                                    color: {
                                        const percent = parseInt(modelData.percent);
                                        if (percent > 90) {
                                            return Theme.error;
                                        }

                                        if (percent > 75) {
                                            return Theme.warning;
                                        }

                                        return Theme.surfaceText;
                                    }
                                    width: parent.width * 0.1
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                            }

                        }

                    }

                }

            }

        }

    }

}