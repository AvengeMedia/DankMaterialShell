import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets

DHeroCard {
    brand: "DMS"
    accent: {
        const semver = ShellVersionService.semverVersion.replace(/^v/, "");
        const base = semver.match(/^\d+\.\d+/);
        return base ? base[0] : semver || SystemUpdateService.shellRunning.replace(/^v/, "");
    }
    caption: ShellVersionService.shellCodename.toUpperCase()
    color: SettingsMetrics.rowColor
}
