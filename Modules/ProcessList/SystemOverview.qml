import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Row {
    width: parent.width
    spacing: Theme.spacingM
    Component.onCompleted: {
        DgopService.addRef(["cpu", "memory", "system"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["cpu", "memory", "system"]);
    }

    Rectangle {
        width: (parent.width - Theme.spacingM * 2) / 3
        height: 80
        radius: Theme.cornerRadius
        color: {
            if (DgopService.sortBy === "cpu") {
                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16);
            } else if (cpuCardMouseArea.containsMouse) {
                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12);
            } else {
                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08);
            }
        }
        border.color: DgopService.sortBy === "cpu" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
        border.width: DgopService.sortBy === "cpu" ? 2 : 1

        MouseArea {
            id: cpuCardMouseArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                DgopService.setSortBy("cpu");
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                text: I18n.tr("CPU")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: DgopService.sortBy === "cpu" ? Theme.primary : Theme.secondary
                opacity: DgopService.sortBy === "cpu" ? 1 : 0.8
            }

            Row {
                spacing: Theme.spacingS

                StyledText {
                    text: {
                        if (DgopService.cpuUsage === undefined || DgopService.cpuUsage === null) {
                            return "--%";
                        }
                        return DgopService.cpuUsage.toFixed(1) + "%";
                    }
                    font.pixelSize: Theme.fontSizeLarge
                    font.family: SettingsData.monoFontFamily
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 1
                    height: 20
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.3)
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: {
                        if (DgopService.cpuTemperature === undefined || DgopService.cpuTemperature === null || DgopService.cpuTemperature <= 0) {
                            return "--°";
                        }
                        return Math.round(DgopService.cpuTemperature) + "°";
                    }
                    font.pixelSize: Theme.fontSizeMedium
                    font.family: SettingsData.monoFontFamily
                    font.weight: Font.Medium
                    color: {
                        if (DgopService.cpuTemperature > 80) {
                            return Theme.error;
                        }
                        if (DgopService.cpuTemperature > 60) {
                            return Theme.warning;
                        }
                        return Theme.surfaceText;
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

            }

            StyledText {
                text: `${DgopService.cpuCores} cores`
                font.pixelSize: Theme.fontSizeSmall
                font.family: SettingsData.monoFontFamily
                color: Theme.surfaceText
                opacity: 0.7
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.shortDuration
            }

        }

    }

    Rectangle {
        width: (parent.width - Theme.spacingM * 2) / 3
        height: 80
        radius: Theme.cornerRadius
        color: {
            if (DgopService.sortBy === "memory") {
                return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16);
            } else if (memoryCardMouseArea.containsMouse) {
                return Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.12);
            } else {
                return Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08);
            }
        }
        border.color: DgopService.sortBy === "memory" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.2)
        border.width: DgopService.sortBy === "memory" ? 2 : 1

        MouseArea {
            id: memoryCardMouseArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                DgopService.setSortBy("memory");
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                text: I18n.tr("Memory")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: DgopService.sortBy === "memory" ? Theme.primary : Theme.secondary
                opacity: DgopService.sortBy === "memory" ? 1 : 0.8
            }

            Row {
                spacing: Theme.spacingS

                StyledText {
                    text: DgopService.formatSystemMemory(DgopService.usedMemoryKB)
                    font.pixelSize: Theme.fontSizeLarge
                    font.family: SettingsData.monoFontFamily
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 1
                    height: 20
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.3)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: DgopService.totalSwapKB > 0
                }

                StyledText {
                    text: DgopService.totalSwapKB > 0 ? DgopService.formatSystemMemory(DgopService.usedSwapKB) : ""
                    font.pixelSize: Theme.fontSizeMedium
                    font.family: SettingsData.monoFontFamily
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: DgopService.totalSwapKB > 0
                }

            }

            StyledText {
                text: {
                    if (DgopService.totalSwapKB > 0) {
                        return "of " + DgopService.formatSystemMemory(DgopService.totalMemoryKB) + " + swap";
                    }
                    return "of " + DgopService.formatSystemMemory(DgopService.totalMemoryKB);
                }
                font.pixelSize: Theme.fontSizeSmall
                font.family: SettingsData.monoFontFamily
                color: Theme.surfaceText
                opacity: 0.7
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.shortDuration
            }

        }

    }

    Rectangle {
        width: (parent.width - Theme.spacingM * 2) / 3
        height: 80
        radius: Theme.cornerRadius
        color: {
            if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
                if (gpuCardMouseArea.containsMouse && DgopService.availableGpus.length > 1) {
                    return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.16);
                } else {
                    return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08);
                }
            }
            const gpu = DgopService.availableGpus[Math.min(SessionData.selectedGpuIndex, DgopService.availableGpus.length - 1)];
            const vendor = gpu.vendor.toLowerCase();
            if (vendor.includes("nvidia")) {
                if (gpuCardMouseArea.containsMouse && DgopService.availableGpus.length > 1) {
                    return Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.2);
                } else {
                    return Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.12);
                }
            } else if (vendor.includes("amd")) {
                if (gpuCardMouseArea.containsMouse && DgopService.availableGpus.length > 1) {
                    return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2);
                } else {
                    return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12);
                }
            } else if (vendor.includes("intel")) {
                if (gpuCardMouseArea.containsMouse && DgopService.availableGpus.length > 1) {
                    return Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.2);
                } else {
                    return Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.12);
                }
            }
            if (gpuCardMouseArea.containsMouse && DgopService.availableGpus.length > 1) {
                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.16);
            } else {
                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.08);
            }
        }
        border.color: {
            if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
                return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2);
            }
            const gpu = DgopService.availableGpus[Math.min(SessionData.selectedGpuIndex, DgopService.availableGpus.length - 1)];
            const vendor = gpu.vendor.toLowerCase();
            if (vendor.includes("nvidia")) {
                return Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.3);
            } else if (vendor.includes("amd")) {
                return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.3);
            } else if (vendor.includes("intel")) {
                return Qt.rgba(Theme.info.r, Theme.info.g, Theme.info.b, 0.3);
            }
            return Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.2);
        }
        border.width: 1

        MouseArea {
            id: gpuCardMouseArea

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: DgopService.availableGpus.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    if (DgopService.availableGpus.length > 1) {
                        const nextIndex = (SessionData.selectedGpuIndex + 1) % DgopService.availableGpus.length;
                        SessionData.setSelectedGpuIndex(nextIndex);
                    }
                } else if (mouse.button === Qt.RightButton) {
                    gpuContextMenu.popup();
                }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                text: I18n.tr("GPU")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.secondary
                opacity: 0.8
            }

            StyledText {
                text: {
                    if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
                        return "No GPU";
                    }
                    const gpu = DgopService.availableGpus[Math.min(SessionData.selectedGpuIndex, DgopService.availableGpus.length - 1)];
                    // Check if temperature monitoring is enabled for this GPU
                    const tempEnabled = SessionData.enabledGpuPciIds && SessionData.enabledGpuPciIds.indexOf(gpu.pciId) !== -1;
                    const temp = gpu.temperature;
                    const hasTemp = tempEnabled && temp !== undefined && temp !== null && temp !== 0;
                    if (hasTemp) {
                        return Math.round(temp) + "°";
                    } else {
                        return gpu.vendor;
                    }
                }
                font.pixelSize: Theme.fontSizeLarge
                font.family: SettingsData.monoFontFamily
                font.weight: Font.Bold
                color: {
                    if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
                        return Theme.surfaceText;
                    }
                    const gpu = DgopService.availableGpus[Math.min(SessionData.selectedGpuIndex, DgopService.availableGpus.length - 1)];
                    const tempEnabled = SessionData.enabledGpuPciIds && SessionData.enabledGpuPciIds.indexOf(gpu.pciId) !== -1;
                    const temp = gpu.temperature || 0;
                    if (tempEnabled && temp > 80) {
                        return Theme.error;
                    }
                    if (tempEnabled && temp > 60) {
                        return Theme.warning;
                    }
                    return Theme.surfaceText;
                }
            }

            StyledText {
                text: {
                    if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
                        return "No GPUs detected";
                    }
                    const gpu = DgopService.availableGpus[Math.min(SessionData.selectedGpuIndex, DgopService.availableGpus.length - 1)];
                    const tempEnabled = SessionData.enabledGpuPciIds && SessionData.enabledGpuPciIds.indexOf(gpu.pciId) !== -1;
                    const temp = gpu.temperature;
                    const hasTemp = tempEnabled && temp !== undefined && temp !== null && temp !== 0;
                    if (hasTemp) {
                        return gpu.vendor + " " + gpu.displayName;
                    } else {
                        return gpu.displayName;
                    }
                }
                font.pixelSize: Theme.fontSizeSmall
                font.family: SettingsData.monoFontFamily
                color: Theme.surfaceText
                opacity: 0.7
                width: parent.parent.width - Theme.spacingM * 2
                elide: Text.ElideRight
                maximumLineCount: 1
            }

        }

        Menu {
            id: gpuContextMenu

            MenuItem {
                text: I18n.tr("Enable GPU Temperature")
                checkable: true
                checked: {
                    if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
                        return false;
                    }
                    const gpu = DgopService.availableGpus[Math.min(SessionData.selectedGpuIndex, DgopService.availableGpus.length - 1)];
                    if (!gpu.pciId) {
                        return false;
                    }
                    return SessionData.enabledGpuPciIds ? SessionData.enabledGpuPciIds.indexOf(gpu.pciId) !== -1 : false;
                }
                onTriggered: {
                    if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
                        return;
                    }
                    const gpu = DgopService.availableGpus[Math.min(SessionData.selectedGpuIndex, DgopService.availableGpus.length - 1)];
                    if (!gpu.pciId) {
                        return;
                    }
                    const enabledIds = SessionData.enabledGpuPciIds ? SessionData.enabledGpuPciIds.slice() : [];
                    const index = enabledIds.indexOf(gpu.pciId);
                    if (checked && index === -1) {
                        enabledIds.push(gpu.pciId);
                        DgopService.addGpuPciId(gpu.pciId);
                    } else if (!checked && index !== -1) {
                        enabledIds.splice(index, 1);
                        DgopService.removeGpuPciId(gpu.pciId);
                    }
                    SessionData.setEnabledGpuPciIds(enabledIds);
                }
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
            }

        }

    }

}
