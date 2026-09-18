import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services

RowLayout {
    spacing: Theme.spacingS
    implicitHeight: ProcessListMetrics.graphHeight

    PerformanceCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        compact: true
        title: I18n.tr("CPU", "processor label in system monitor")
        icon: "memory"
        value: DgopService.cpuUsage.toFixed(1) + "%" + (DgopService.cpuTemperature > 0 ? " · " + DgopService.cpuTemperature.toFixed(0) + "°C" : "")
        history: DgopService.cpuHistory
        accentColor: Theme.primary
    }

    PerformanceCard {
        Layout.fillWidth: true
        Layout.fillHeight: true
        compact: true
        title: I18n.tr("Memory")
        icon: "sd_card"
        value: DgopService.formatSystemMemory(DgopService.usedMemoryKB) + " / " + DgopService.formatSystemMemory(DgopService.totalMemoryKB) + (DgopService.totalSwapKB > 0 ? " + " + DgopService.formatSystemMemory(DgopService.usedSwapKB) : "")
        history: DgopService.memoryHistory
        accentColor: Theme.secondary
    }
}
