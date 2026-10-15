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
    property var meterMaxes: ({})
    readonly property string command: process?.command ?? ""
    readonly property string fullCommand: process?.fullCommand ?? command

    property var columns: ProcessColumns.DEFAULT_COLUMNS
    readonly property int childCount: process?.childCount ?? 0

    signal actionRequested(string action)

    listView: null
    surfaceColor: "transparent"
    color: "transparent"
    border.width: 0
    radius: Theme.cornerRadiusS
    topLeftRadius: radius
    topRightRadius: radius
    bottomLeftRadius: radius
    bottomRightRadius: radius

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
        radius: Theme.cornerRadiusS
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
                source: root.command ? Paths.getAppIcon(root.command, DesktopEntries.heuristicLookup(root.command)) : ""
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
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            text: root.childCount > 0 ? root.command + " (" + root.childCount + ")" : root.command
            font.pixelSize: Theme.fontSizeMedium
            color: root.contentColor
            textFormat: Text.PlainText
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        Repeater {
            model: root.columns

            Item {
                id: cell

                required property string modelData
                readonly property var col: ProcessColumns.COLUMNS.find(c => c.id === modelData) ?? ({})
                readonly property var raw: ProcessColumns.formatCell(modelData, root.process ?? ({}), false)
                readonly property bool absent: raw === null
                readonly property real fill: ProcessColumns.meterRatio(modelData, root.process ?? ({}), root.meterMaxes)
                readonly property bool zero: !cell.absent && ProcessColumns.rawValue(cell.modelData, root.process ?? ({})) === 0

                Layout.minimumWidth: Theme.fontSizeSmall * (col.width ?? 6)
                Layout.maximumWidth: Layout.minimumWidth
                Layout.fillHeight: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * cell.fill
                    height: parent.height - Theme.spacingXS * 2
                    radius: Theme.cornerRadiusXS
                    color: Theme.withAlpha(Theme.primary, 0.2)
                    visible: cell.fill >= 0.01
                }

                NumericText {
                    anchors.fill: parent
                    anchors.rightMargin: Theme.spacingS
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    isMonospace: false
                    text: cell.absent ? "—" : cell.modelData === "status" ? ProcessListMetrics.statusLabel(cell.raw) : cell.raw
                    font.pixelSize: Theme.fontSizeSmall
                    color: cell.absent || cell.zero ? Theme.surfaceVariantText : cell.col.meter ? root.contentColor : root.supportingContentColor
                }

                MouseArea {
                    id: absentArea
                    anchors.fill: parent
                    enabled: cell.absent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onContainsMouseChanged: {
                        if (containsMouse) {
                            const reason = ProcessColumns.absentReason(cell.modelData, root.process);
                            absentTip.text = reason === "unmonitored" ? I18n.tr("Monitoring off") : reason === "unknown" ? I18n.tr("Unknown", "process network rate that could not be measured") : I18n.tr("Not readable without privileges");
                            absentTip.target = cell;
                            absentTip.hoverArea = absentArea;
                        } else if (absentTip.hoverArea === absentArea) {
                            absentTip.hoverArea = null;
                        }
                    }
                }
            }
        }
    }

    DTooltipHost {
        id: absentTip
        text: I18n.tr("Not readable without privileges")
    }

    Loader {
        id: details
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.rowHeight + Theme.spacingXS
        anchors.leftMargin: Theme.spacingL
        anchors.rightMargin: Theme.spacingL
        active: root.isExpanded || root.height > root.rowHeight

        sourceComponent: ProcessDetailStrip {
            process: root.process
            onActionRequested: action => root.actionRequested(action)
        }
    }
}
