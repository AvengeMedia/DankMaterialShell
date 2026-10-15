import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Settings.Widgets
import "ProcessColumns.js" as ProcessColumns
import "../../Services/SysmonDevices.js" as Devices

Rectangle {
    id: root

    required property var process

    readonly property int pid: process?.pid ?? 0
    readonly property var live: (DgopService.allProcesses ?? []).find(p => p.pid === pid) ?? process
    readonly property string fullCommand: live?.fullCommand || live?.command || ""
    readonly property var startTime: live?.startTime ?? null
    readonly property var started: startTime !== null ? new Date(startTime * 1000) : null
    readonly property bool startedToday: started !== null && started.toDateString() === new Date().toDateString()
    readonly property var parentProcess: (live?.ppid ?? 0) > 0 ? (DgopService.allProcesses ?? []).find(p => p.pid === live.ppid) ?? null : null
    readonly property int connectionCount: live?.connections ?? 0
    readonly property int localConnectionCount: live?.localConnections ?? 0
    readonly property var remoteGroups: groupRemotes(false)
    readonly property var localGroups: groupRemotes(true)
    readonly property int shownGroups: 4
    readonly property int hiddenConnections: hiddenCount(connectionCount, remoteGroups)
    readonly property int hiddenLocalConnections: hiddenCount(localConnectionCount, localGroups)

    property var detail: null
    readonly property real groupWidth: Theme.fontSizeMedium * 16
    readonly property bool own: ProcessActions.isOwn(live)
    readonly property bool endable: ProcessActions.canEnd(live)
    readonly property string restartKind: ProcessActions.restartKind(live)
    readonly property string authTip: own ? "" : I18n.tr("Authentication Required")
    readonly property string unreadableTip: I18n.tr("Not readable without privileges")

    signal actionRequested(string action)

    function cell(id) {
        return ProcessColumns.formatCell(id, live ?? ({}), false) ?? "—";
    }

    function groupRemotes(local) {
        const counts = {};
        for (const r of live?.remotes ?? []) {
            if ((r.local === true) === local)
                counts[r.remote] = (counts[r.remote] ?? 0) + 1;
        }
        return Object.keys(counts).map(k => ({
                    "remote": k,
                    "count": counts[k]
                })).sort((a, b) => b.count - a.count);
    }

    function hiddenCount(total, groups) {
        return total - groups.slice(0, shownGroups).reduce((n, g) => n + g.count, 0);
    }

    function bytes(v) {
        return v === null || v === undefined ? "" : Devices.formatBytes(v);
    }

    function refreshDetail() {
        if (pid > 0)
            DgopService.fetchProcessDetail(pid, d => root.detail = d);
    }

    Component.onCompleted: refreshDetail()

    Timer {
        interval: DgopService.updateInterval
        running: root.visible && root.pid > 0
        repeat: true
        onTriggered: root.refreshDetail()
    }

    implicitHeight: body.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadiusM
    color: Theme.surfaceContainerHigh

    ColumnLayout {
        id: body
        x: Theme.spacingL
        y: Theme.spacingL
        width: parent.width - Theme.spacingL * 2
        spacing: Theme.spacingL

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXS

            StyledText {
                text: I18n.tr("Command", "noun, the full command line of a process")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXS

                // Long command lines (scripts passed inline) scroll inside four lines instead of growing the row.
                DFlickable {
                    id: commandScroll
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredHeight: Math.min(commandText.implicitHeight, commandText.implicitHeight / Math.max(1, commandText.lineCount) * 4)
                    contentWidth: width
                    contentHeight: commandText.implicitHeight
                    clip: true

                    TextEdit {
                        id: commandText
                        width: commandScroll.width
                        text: root.fullCommand
                        readOnly: true
                        activeFocusOnPress: false
                        selectByMouse: true
                        wrapMode: TextEdit.WrapAnywhere
                        textFormat: TextEdit.PlainText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        selectedTextColor: Theme.primaryText
                        selectionColor: Theme.primary
                    }
                }

                DActionButton {
                    Layout.alignment: Qt.AlignTop
                    iconName: "content_copy"
                    iconColor: Theme.surfaceText
                    tooltipText: I18n.tr("Copy Full Command")
                    onClicked: Quickshell.execDetached(["dms", "cl", "copy", root.fullCommand])
                }
            }

            Row {
                Layout.topMargin: Theme.spacingS
                spacing: Theme.spacingXL

                Row {
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("PID")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    NumericText {
                        isMonospace: false
                        text: String(root.pid)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }
                }

                Item {
                    visible: root.started !== null
                    implicitWidth: startedRow.implicitWidth
                    implicitHeight: startedRow.implicitHeight

                    Row {
                        id: startedRow
                        spacing: Theme.spacingXS

                        StyledText {
                            text: I18n.tr("Started")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        NumericText {
                            isMonospace: false
                            text: root.started ? Qt.formatTime(root.started, "HH:mm") : ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }
                    }

                    MouseArea {
                        id: startedHover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }

                    DTooltipHost {
                        text: root.started && !root.startedToday ? Qt.formatDate(root.started, Locale.ShortFormat) : ""
                        target: parent
                        hoverArea: startedHover
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: Math.max(1, Math.min(3, Math.floor((width + columnSpacing) / (root.groupWidth + columnSpacing))))
            columnSpacing: Theme.spacingL
            rowSpacing: Theme.spacingL

            SettingsGroup {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                customPaddingV: 0
                customPaddingH: Theme.spacingM
                slotColor: Theme.surfaceContainerHighest

                StatRow {
                    height: Theme.buttonHeightXS
                    label: I18n.tr("User")
                    value: root.live?.username ?? ""
                }

                StatRow {
                    height: Theme.buttonHeightXS
                    label: I18n.tr("Status")
                    value: root.live?.status ? ProcessListMetrics.statusLabel(root.live.status) : ""
                }

                StatRow {
                    height: Theme.buttonHeightXS
                    label: I18n.tr("CPU time", "process column: total CPU time used")
                    value: root.cell("cpuTime")
                }

                StatRow {
                    height: Theme.buttonHeightXS
                    label: I18n.tr("Threads")
                    value: root.cell("threads")
                }

                StatRow {
                    height: Theme.buttonHeightXS
                    label: I18n.tr("Nice", "process column: Linux nice value, scheduling priority")
                    value: root.cell("nice")
                }

                StatRow {
                    height: Theme.buttonHeightXS
                    label: I18n.tr("Parent", "the process that started this one")
                    value: root.parentProcess ? root.parentProcess.command : (root.live?.ppid ?? 0) > 0 ? String(root.live.ppid) : ""
                    tooltip: root.parentProcess ? I18n.tr("PID") + " " + root.parentProcess.pid : ""
                }
            }

            SettingsGroup {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                customPaddingV: 0
                customPaddingH: Theme.spacingM
                slotColor: Theme.surfaceContainerHighest

                StatRow {
                    height: Theme.buttonHeightXS
                    label: I18n.tr("Read total", "bytes a process has read from storage since it started")
                    value: root.bytes(root.detail?.readTotal)
                    tooltip: value === "" ? root.unreadableTip : ""
                }

                StatRow {
                    height: Theme.buttonHeightXS
                    label: I18n.tr("Written total", "lifetime data written to a drive")
                    value: root.bytes(root.detail?.writeTotal)
                    tooltip: value === "" ? root.unreadableTip : ""
                }

                StatRow {
                    height: Theme.buttonHeightXS
                    label: I18n.tr("Swap")
                    value: root.detail?.swapKB != null ? root.bytes(root.detail.swapKB * 1024) : ""
                    tooltip: value === "" ? root.unreadableTip : ""
                }

                StatRow {
                    height: Theme.buttonHeightXS
                    label: I18n.tr("Open files", "number of files and sockets a process has open")
                    value: root.detail?.openFiles != null ? String(root.detail.openFiles) : ""
                    tooltip: value === "" ? root.unreadableTip : ""
                }

                StatRow {
                    height: Theme.buttonHeightXS
                    label: I18n.tr("Shared memory")
                    value: root.live?.gpuGttKB != null ? root.bytes(root.live.gpuGttKB * 1024) : ""
                    tooltip: I18n.tr("System memory the GPU uses for this process")
                }

                StatRow {
                    height: Theme.buttonHeightXS
                    label: I18n.tr("Service", "the systemd unit or app scope a process runs in")
                    value: root.detail?.unit ?? ""
                    tooltip: root.detail?.unit ?? ""
                }
            }

            SettingsGroup {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                customPaddingV: 0
                customPaddingH: Theme.spacingM
                slotColor: Theme.surfaceContainerHighest

                StatRow {
                    height: Theme.buttonHeightXS
                    label: I18n.tr("Internet connections", "process detail: list of internet addresses the process talks to")
                    value: root.cell("connections")
                    tooltip: root.live?.connections == null ? root.unreadableTip : I18n.tr("Connections to public internet addresses; local network and VPN peers are not counted")
                }

                Repeater {
                    model: root.remoteGroups.slice(0, root.shownGroups)

                    StatRow {
                        required property var modelData
                        height: Theme.buttonHeightXS
                        label: modelData.remote
                        value: modelData.count > 1 ? "× " + modelData.count : " "
                    }
                }

                StatRow {
                    visible: root.hiddenConnections > 0
                    height: Theme.buttonHeightXS
                    label: I18n.tr("+ %1 more", "overflow line, %1 is a count of hidden items").arg(root.hiddenConnections)
                    value: " "
                }

                StatRow {
                    visible: root.localConnectionCount > 0
                    height: Theme.buttonHeightXS
                    label: I18n.tr("Local network", "process detail: connections to LAN, VPN or link-local addresses, not the internet")
                    value: String(root.localConnectionCount)
                }

                Repeater {
                    model: root.localGroups.slice(0, root.shownGroups)

                    StatRow {
                        required property var modelData
                        height: Theme.buttonHeightXS
                        label: modelData.remote
                        value: modelData.count > 1 ? "× " + modelData.count : " "
                    }
                }

                StatRow {
                    visible: root.hiddenLocalConnections > 0
                    height: Theme.buttonHeightXS
                    label: I18n.tr("+ %1 more", "overflow line, %1 is a count of hidden items").arg(root.hiddenLocalConnections)
                    value: " "
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            Item {
                Layout.fillWidth: true
            }

            DButton {
                text: root.restartKind === "reload" ? I18n.tr("Reload", "process action: reload a compositor's configuration") : I18n.tr("Restart")
                iconName: "restart_alt"
                visible: root.restartKind !== "" && !(root.restartKind === "relaunch" && (root.detail?.terminal ?? false))
                backgroundColor: Theme.secondaryContainer
                textColor: Theme.onSecondaryContainer
                tooltipText: root.authTip || null
                onClicked: root.actionRequested("restart")
            }

            DSplitButton {
                id: quitButton
                visible: root.endable
                text: I18n.tr("Quit", "process action: ask the process to exit (SIGTERM)")
                iconName: "close"
                size: "s"
                variant: "filled"
                expanded: quitMenu.menuVisible
                tooltipText: root.authTip
                menuTooltipText: I18n.tr("More")
                onClicked: root.actionRequested("quit")
                onMenuClicked: {
                    quitMenu.currentValue = "";
                    quitMenu.openDropdownMenu();
                }

                DDropdown {
                    id: quitMenu
                    showTrigger: false
                    popupAnchorItem: quitButton.trailingButton
                    focusReturnTarget: quitButton.trailingButton
                    alignPopupRight: !I18n.isRtl
                    popupWidth: Theme.fontSizeMedium * 14
                    options: [I18n.tr("Force quit", "process action: kill the process immediately (SIGKILL)"), I18n.tr("End process tree", "process action: quit the process and every process it started")]
                    optionIcons: ["dangerous", "account_tree"]
                    onValueChanged: value => root.actionRequested(value === options[0] ? "force" : "tree")
                }
            }
        }
    }
}
