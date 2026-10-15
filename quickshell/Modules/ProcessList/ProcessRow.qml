import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import Quickshell.Widgets
import "ProcessColumns.js" as ProcessColumns

DListItem {
    id: root

    required property var process
    property real rowHeight: ProcessListMetrics.rowHeight
    property bool isExpanded: false
    readonly property string command: process?.command ?? ""
    readonly property string fullCommand: process?.fullCommand ?? command

    property var columns: ProcessColumns.DEFAULT_COLUMNS
    readonly property int childCount: process?.childCount ?? 0
    readonly property var appEntry: ProcessListMetrics.appEntry(process)
    readonly property string displayName: appEntry?.name || command

    // The part of a sideways-scrolling table that is on screen; the details stay inside it.
    property real detailX: 0
    property real detailWidth: -1

    signal actionRequested(string action)

    listView: null
    color: surfaceColor

    height: root.rowHeight + (isExpanded && details.item ? details.item.implicitHeight + Theme.spacingXS + Theme.spacingS : 0)
    clip: true

    // Opening one strip closes another; animating both shows where the selection went.
    Behavior on height {
        enabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
        NumberAnimation {
            duration: Theme.expressiveDurations.expressiveDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
        }
    }
    Accessible.name: command
    Accessible.description: fullCommand

    Rectangle {
        width: parent.width
        height: root.rowHeight
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.height > root.rowHeight ? root.radius : root.bottomLeftRadius
        bottomRightRadius: bottomLeftRadius
        color: Theme.selectedContainer
        visible: root.isSelected || root.visualFocus
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.spacingL
        anchors.rightMargin: Theme.spacingL
        height: root.rowHeight
        spacing: Theme.spacingXS

        Item {
            Layout.rightMargin: Theme.spacingS
            Layout.preferredWidth: ProcessListMetrics.appIconSize
            Layout.preferredHeight: ProcessListMetrics.appIconSize

            IconImage {
                id: appIcon
                anchors.fill: parent
                source: root.command ? Paths.getAppIcon(root.appEntry?.id ?? root.command, root.appEntry) : ""
                smooth: true
                mipmap: true
                asynchronous: true
                visible: status === Image.Ready
            }

            Rectangle {
                anchors.fill: parent
                visible: !appIcon.visible
                radius: Theme.cornerRadiusXS
                color: Theme.surfaceContainerHighest

                StyledText {
                    anchors.centerIn: parent
                    text: root.command.charAt(0).toUpperCase()
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: Theme.surfaceVariantText
                }
            }
        }

        StyledText {
            id: nameText
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            text: root.childCount > 0 ? root.displayName + " (" + root.childCount + ")" : root.displayName
            font.pixelSize: Theme.fontSizeMedium
            color: root.contentColor
            textFormat: Text.PlainText
            maximumLineCount: 1
            elide: Text.ElideRight

            MouseArea {
                id: nameHover
                anchors.fill: parent
                enabled: root.childCount > 0 || root.displayName !== root.command
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onContainsMouseChanged: {
                    if (containsMouse) {
                        rowTip.text = (root.displayName !== root.command ? root.command : "") + (root.childCount > 0 ? (root.displayName !== root.command ? "\n" : "") + I18n.tr("Includes %1 more processes of the same program; the values are their total", "process row tooltip, %1 is the count in parentheses").arg(root.childCount) : "");
                        rowTip.target = nameText;
                        rowTip.hoverArea = nameHover;
                    } else if (rowTip.hoverArea === nameHover) {
                        rowTip.hoverArea = null;
                    }
                }
            }
        }

        Repeater {
            model: root.columns

            StyledText {
                id: cell

                required property string modelData
                readonly property var col: ProcessColumns.COLUMNS.find(c => c.id === modelData) ?? ({})
                readonly property var raw: ProcessColumns.formatCell(modelData, root.process ?? ({}), false)
                readonly property bool absent: raw === null
                readonly property bool zero: !cell.absent && ProcessColumns.rawValue(cell.modelData, root.process ?? ({})) === 0

                Layout.minimumWidth: Theme.fontSizeSmall * (col.width ?? 6) - Theme.spacingS
                Layout.maximumWidth: Layout.minimumWidth
                Layout.rightMargin: Theme.spacingS
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                maximumLineCount: 1
                font.features: {
                    "tnum": 1
                }
                text: cell.absent ? "—" : cell.modelData === "status" ? ProcessListMetrics.statusLabel(cell.raw) : cell.raw
                font.pixelSize: Theme.fontSizeSmall
                color: cell.absent || cell.zero ? Theme.surfaceVariantText : cell.col.meter ? root.contentColor : root.supportingContentColor

                MouseArea {
                    id: absentArea
                    anchors.fill: parent
                    enabled: cell.absent
                    hoverEnabled: enabled
                    acceptedButtons: Qt.NoButton
                    onContainsMouseChanged: {
                        if (containsMouse) {
                            const reason = ProcessColumns.absentReason(cell.modelData, root.process);
                            rowTip.text = reason === "unmonitored" ? I18n.tr("Monitoring off") : reason === "unknown" ? I18n.tr("Unknown", "process network rate that could not be measured") : I18n.tr("Not readable without privileges");
                            rowTip.target = cell;
                            rowTip.hoverArea = absentArea;
                        } else if (rowTip.hoverArea === absentArea) {
                            rowTip.hoverArea = null;
                        }
                    }
                }
            }
        }
    }

    // One tooltip per row, created on first hover: building one up front for every row made sorting slow.
    DTooltipHost {
        id: rowTip
        multiline: true
    }

    Loader {
        id: details
        x: root.detailX + Theme.spacingL
        width: (root.detailWidth >= 0 ? root.detailWidth : root.width) - Theme.spacingL * 2
        anchors.top: parent.top
        anchors.topMargin: root.rowHeight + Theme.spacingXS
        active: root.isExpanded || root.height > root.rowHeight

        sourceComponent: ProcessDetailStrip {
            process: root.process
            onActionRequested: action => root.actionRequested(action)
        }
    }
}
