import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: processItemRoot

    property var process: null
    property bool isExpanded: false
    property bool isSelected: false
    property var contextMenu: null

    signal toggleExpand
    signal clicked
    signal contextMenuRequested(real mouseX, real mouseY)

    readonly property int processPid: process?.pid ?? 0
    readonly property real processCpu: process?.cpu ?? 0
    readonly property int processMemKB: process?.memoryKB ?? 0
    readonly property string processCmd: process?.command ?? ""
    readonly property string processFullCmd: process?.fullCommand ?? processCmd

    height: isExpanded ? (44 + expandedRect.height + Theme.spacingXS) : 44
    radius: Theme.cornerRadius
    color: {
        if (isSelected)
            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15);
        return processMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06) : "transparent";
    }
    border.color: {
        if (isSelected)
            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3);
        return processMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent";
    }
    border.width: 1
    clip: true

    Behavior on height {
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
        }
    }

    MouseArea {
        id: processMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                processItemRoot.contextMenuRequested(mouse.x, mouse.y);
                return;
            }
            processItemRoot.clicked();
            processItemRoot.toggleExpand();
        }
    }

    Column {
        anchors.fill: parent
        spacing: 0

        Item {
            width: parent.width
            height: 44

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 200
                    height: parent.height

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: DgopService.getProcessIcon(processItemRoot.processCmd)
                            size: Theme.iconSize - 4
                            color: {
                                if (processItemRoot.processCpu > 80)
                                    return Theme.error;
                                if (processItemRoot.processCpu > 50)
                                    return Theme.warning;
                                return Theme.surfaceText;
                            }
                            opacity: 0.8
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: processItemRoot.processCmd
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 280)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Item {
                    Layout.preferredWidth: 100
                    height: parent.height

                    Rectangle {
                        anchors.centerIn: parent
                        width: 70
                        height: 24
                        radius: Theme.cornerRadius
                        color: {
                            if (processItemRoot.processCpu > 80)
                                return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15);
                            if (processItemRoot.processCpu > 50)
                                return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12);
                            return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06);
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: DgopService.formatCpuUsage(processItemRoot.processCpu)
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            font.weight: Font.Bold
                            color: {
                                if (processItemRoot.processCpu > 80)
                                    return Theme.error;
                                if (processItemRoot.processCpu > 50)
                                    return Theme.warning;
                                return Theme.surfaceText;
                            }
                        }
                    }
                }

                Item {
                    Layout.preferredWidth: 100
                    height: parent.height

                    Rectangle {
                        anchors.centerIn: parent
                        width: 70
                        height: 24
                        radius: Theme.cornerRadius
                        color: {
                            if (processItemRoot.processMemKB > 2 * 1024 * 1024)
                                return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15);
                            if (processItemRoot.processMemKB > 1024 * 1024)
                                return Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12);
                            return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06);
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: DgopService.formatMemoryUsage(processItemRoot.processMemKB)
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: SettingsData.monoFontFamily
                            font.weight: Font.Bold
                            color: {
                                if (processItemRoot.processMemKB > 2 * 1024 * 1024)
                                    return Theme.error;
                                if (processItemRoot.processMemKB > 1024 * 1024)
                                    return Theme.warning;
                                return Theme.surfaceText;
                            }
                        }
                    }
                }

                Item {
                    Layout.preferredWidth: 80
                    height: parent.height

                    StyledText {
                        anchors.centerIn: parent
                        text: processItemRoot.processPid > 0 ? processItemRoot.processPid.toString() : ""
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: SettingsData.monoFontFamily
                        color: Theme.surfaceVariantText
                    }
                }

                Item {
                    Layout.preferredWidth: 40
                    height: parent.height

                    DankIcon {
                        anchors.centerIn: parent
                        name: processItemRoot.isExpanded ? "expand_less" : "expand_more"
                        size: Theme.iconSize - 4
                        color: Theme.surfaceVariantText
                    }
                }
            }
        }

        Rectangle {
            id: expandedRect
            width: parent.width - Theme.spacingM * 2
            height: processItemRoot.isExpanded ? (expandedContent.implicitHeight + Theme.spacingS * 2) : 0
            anchors.horizontalCenter: parent.horizontalCenter
            radius: Theme.cornerRadius - 2
            color: Qt.rgba(Theme.surfaceContainerHigh.r, Theme.surfaceContainerHigh.g, Theme.surfaceContainerHigh.b, 0.6)
            clip: true
            visible: processItemRoot.isExpanded

            Behavior on height {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Column {
                id: expandedContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingXS

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        id: cmdLabel
                        text: I18n.tr("Full Command:", "process detail label")
                        font.pixelSize: Theme.fontSizeSmall - 2
                        font.weight: Font.Bold
                        color: Theme.surfaceVariantText
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        id: cmdText
                        text: processItemRoot.processFullCmd
                        font.pixelSize: Theme.fontSizeSmall - 2
                        font.family: SettingsData.monoFontFamily
                        color: Theme.surfaceText
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        elide: Text.ElideMiddle
                    }

                    Rectangle {
                        id: copyBtn
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        Layout.alignment: Qt.AlignVCenter
                        radius: Theme.cornerRadius - 2
                        color: copyMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"

                        DankIcon {
                            anchors.centerIn: parent
                            name: "content_copy"
                            size: 14
                            color: copyMouseArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                        }

                        MouseArea {
                            id: copyMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["dms", "cl", "copy", processItemRoot.processFullCmd]);
                            }
                        }
                    }
                }

                Row {
                    spacing: Theme.spacingL

                    Row {
                        spacing: Theme.spacingXS

                        StyledText {
                            text: "PPID:"
                            font.pixelSize: Theme.fontSizeSmall - 2
                            font.weight: Font.Bold
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            text: (processItemRoot.process?.ppid ?? 0) > 0 ? processItemRoot.process.ppid.toString() : "--"
                            font.pixelSize: Theme.fontSizeSmall - 2
                            font.family: SettingsData.monoFontFamily
                            color: Theme.surfaceText
                        }
                    }

                    Row {
                        spacing: Theme.spacingXS

                        StyledText {
                            text: "Mem:"
                            font.pixelSize: Theme.fontSizeSmall - 2
                            font.weight: Font.Bold
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            text: (processItemRoot.process?.memoryPercent ?? 0).toFixed(1) + "%"
                            font.pixelSize: Theme.fontSizeSmall - 2
                            font.family: SettingsData.monoFontFamily
                            color: Theme.surfaceText
                        }
                    }
                }
            }
        }
    }
}
