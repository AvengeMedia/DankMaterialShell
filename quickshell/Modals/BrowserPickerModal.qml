import QtQuick
import Quickshell
import qs.Common
import qs.Modals

AppPickerModal {
    id: root

    property string url: ""

    title: I18n.tr("Open with...")
    targetData: url
    targetDataLabel: ""
    categoryFilter: ["WebBrowser", "X-WebBrowser"]
    viewMode: SettingsData.browserPickerViewMode || "grid"
    usageHistoryKey: "browserUsageHistory"
    showTargetData: true

    function shellEscape(str) {
        return "'" + str.replace(/'/g, "'\\''") + "'"
    }

    onApplicationSelected: (app, url) => {
        if (!app) return

        let cmd = app.exec || ""
        const escapedUrl = shellEscape(url)

        let hasField = false
        if (cmd.includes("%u")) { cmd = cmd.replace("%u", escapedUrl); hasField = true }
        else if (cmd.includes("%U")) { cmd = cmd.replace("%U", escapedUrl); hasField = true }
        else if (cmd.includes("%f")) { cmd = cmd.replace("%f", escapedUrl); hasField = true }
        else if (cmd.includes("%F")) { cmd = cmd.replace("%F", escapedUrl); hasField = true }

        cmd = cmd.replace(/%[ikc]/g, "")

        if (!hasField) {
            cmd += " " + escapedUrl
        }

        console.log("BrowserPicker: Launching", cmd)

        Quickshell.execDetached({
            command: ["sh", "-c", cmd]
        })
    }

    onViewModeChanged: {
        SettingsData.set("browserPickerViewMode", viewMode)
    }
}
