import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import "../../Common/Format.js" as Format

DankListItem {
    id: root

    required property var process
    property real rowHeight: ProcessListMetrics.rowHeight
    property bool isExpanded: false
    readonly property string command: process?.command ?? ""
    readonly property string fullCommand: process?.fullCommand ?? command

    signal killRequested

    surfaceColor: Theme.foregroundColor(Theme.chipSurface, Theme.isFloatingWindow(root))

    height: root.rowHeight + (isExpanded ? details.implicitHeight + Theme.spacingM * 2 : 0)
    clip: true
    Accessible.name: command
    Accessible.description: fullCommand

    function processIcon(command) {
        const cmd = command.toLowerCase();
        if (cmd.includes("firefox") || cmd.includes("chrome") || cmd.includes("browser") || cmd.includes("chromium"))
            return "web";
        if (cmd.includes("code") || cmd.includes("editor") || cmd.includes("vim"))
            return "code";
        if (cmd.includes("terminal") || cmd.includes("bash") || cmd.includes("zsh"))
            return "terminal";
        if (cmd.includes("music") || cmd.includes("audio") || cmd.includes("spotify"))
            return "music_note";
        if (cmd.includes("video") || cmd.includes("vlc") || cmd.includes("mpv"))
            return "play_circle";
        if (cmd.includes("systemd") || cmd.includes("elogind") || cmd.includes("kernel") || cmd.includes("kthread") || cmd.includes("kworker"))
            return "settings";
        return "memory";
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.spacingL
        anchors.rightMargin: Theme.spacingL
        height: root.rowHeight
        spacing: Theme.spacingS

        DankIcon {
            name: root.processIcon(root.command)
            size: Theme.iconSize
            color: root.contentColor
        }

        Column {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 0
            spacing: 0

            StyledText {
                id: nameText
                width: parent.width
                maximumLineCount: 1
                text: root.command
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
                color: root.contentColor
                textFormat: Text.PlainText
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                height: Math.min(implicitHeight, Math.max(0, root.rowHeight - nameText.implicitHeight - Theme.spacingXS * 2))
                maximumLineCount: 2
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                text: root.fullCommand
                font.pixelSize: Theme.fontSizeSmall
                color: root.supportingContentColor
                textFormat: Text.PlainText
                elide: Text.ElideRight
            }
        }

        NumericText {
            Layout.minimumWidth: ProcessListMetrics.cpuColumnWidth
            Layout.maximumWidth: ProcessListMetrics.cpuColumnWidth
            elide: Text.ElideRight
            maximumLineCount: 1
            reserveText: "9999.9%"
            text: (root.process?.cpu ?? 0).toFixed(1) + "%"
            isMonospace: false
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Theme.fontSizeSmall
            color: root.contentColor
        }

        NumericText {
            Layout.minimumWidth: ProcessListMetrics.memoryColumnWidth
            Layout.maximumWidth: ProcessListMetrics.memoryColumnWidth
            elide: Text.ElideRight
            maximumLineCount: 1
            reserveText: "999.9 GB"
            text: Format.formatBytes((root.process?.memoryKB ?? 0) * 1024)
            isMonospace: false
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Theme.fontSizeSmall
            color: root.contentColor
        }

        NumericText {
            Layout.minimumWidth: ProcessListMetrics.pidColumnWidth
            Layout.maximumWidth: ProcessListMetrics.pidColumnWidth
            elide: Text.ElideRight
            maximumLineCount: 1
            reserveText: "9999999"
            text: (root.process?.pid ?? 0).toString()
            isMonospace: false
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Theme.fontSizeSmall
            color: root.supportingContentColor
        }

        Item {
            Layout.minimumWidth: ProcessListMetrics.actionColumnWidth
            Layout.maximumWidth: ProcessListMetrics.actionColumnWidth
            Layout.preferredHeight: Theme.iconButtonSize

            DankActionButton {
                anchors.centerIn: parent
                iconName: "close"
                iconColor: root.contentColor
                tooltipText: I18n.tr("Kill Process")
                focusPolicy: activeFocus || root.isSelected ? Qt.StrongFocus : Qt.ClickFocus
                visible: root.hovered || root.isSelected || activeFocus
                enabled: (root.process?.pid ?? 0) > 0
                onClicked: root.killRequested()
            }
        }
    }

    ColumnLayout {
        id: details
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.rowHeight
        anchors.leftMargin: Theme.spacingL
        anchors.rightMargin: Theme.spacingL
        spacing: Theme.spacingXS
        visible: root.isExpanded

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: root.fullCommand
                font.pixelSize: Theme.fontSizeSmall
                color: root.contentColor
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
            }

            DankActionButton {
                iconName: "content_copy"
                iconColor: root.contentColor
                tooltipText: I18n.tr("Copy Full Command")
                onClicked: Quickshell.execDetached(["dms", "cl", "copy", root.fullCommand])
            }
        }

        StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            maximumLineCount: 1
            text: "PPID" + ": " + (root.process?.ppid ?? 0) + " · " + I18n.tr("Memory") + ": " + (root.process?.memoryPercent ?? 0).toFixed(1) + "%"
            font.pixelSize: Theme.fontSizeSmall
            color: root.contentColor
        }
    }
}
