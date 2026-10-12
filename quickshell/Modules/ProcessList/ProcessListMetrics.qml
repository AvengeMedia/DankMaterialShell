pragma Singleton

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Settings.Widgets

Singleton {
    readonly property real rowHeight: Theme.buttonHeightXS + Theme.spacingXS
    readonly property real headerHeight: Theme.buttonHeightXS + Theme.spacingXS
    readonly property real groupHeaderHeight: Theme.buttonHeightXXS
    readonly property real appIconSize: Theme.iconSizeMedium
    readonly property real windowHeight: SettingsMetrics.windowHeight
    readonly property real menuWidth: 240
    readonly property real dialogWidth: 360
    readonly property int refreshInterval: DgopService.updateInterval

    // Shared by the window and the bar popout, like the user/system filter; not persisted.
    property bool onlineOnly: false

    function columnLabel(id) {
        switch (id) {
        case "cpu": return I18n.tr("CPU");
        case "memory": return I18n.tr("Memory");
        case "gpu": return I18n.tr("GPU");
        case "vram": return I18n.tr("VRAM");
        case "gpuVideo": return I18n.tr("Video", "process column: GPU video engine usage in percent");
        case "diskRead": return I18n.tr("Read");
        case "diskWrite": return I18n.tr("Write");
        case "connections": return I18n.tr("Online", "process column: number of open internet connections");
        case "netRx": return I18n.tr("Down", "network direction");
        case "netTx": return I18n.tr("Up", "network direction");
        case "status": return I18n.tr("Status");
        case "threads": return I18n.tr("Threads");
        case "nice": return I18n.tr("Nice", "process column: Linux nice value, scheduling priority");
        case "cpuTime": return I18n.tr("CPU time", "process column: total CPU time used");
        case "pid": return I18n.tr("PID");
        case "user": return I18n.tr("User");
        }
        return "";
    }

    function groupLabel(group) {
        switch (group) {
        case "disk": return I18n.tr("Disk");
        case "network": return I18n.tr("Network");
        }
        return "";
    }

    function statusLabel(letter) {
        switch (letter) {
        case "R": return I18n.tr("Running", "process state");
        case "S": return I18n.tr("Sleeping", "process state");
        case "D": return I18n.tr("Waiting", "process state: uninterruptible wait, usually for disk");
        case "Z": return I18n.tr("Zombie", "process state: exited, not yet reaped by its parent");
        case "T":
        case "t": return I18n.tr("Stopped", "process state");
        case "I": return I18n.tr("Idle", "process state");
        }
        return letter;
    }
}
