import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property bool showPercentage: true
    property bool showIcon: true
    property var toggleProcessList
    property var popoutTarget: null
    property var widgetData: null
    property bool minimumWidth: (widgetData && widgetData.minimumWidth !== undefined) ? widgetData.minimumWidth : true
    property bool showSwap: (widgetData && widgetData.showSwap !== undefined) ? widgetData.showSwap : false
    readonly property real swapUsage: DgopService.totalSwapKB > 0 ? (DgopService.usedSwapKB / DgopService.totalSwapKB) * 100 : 0

    Component.onCompleted: {
        DgopService.addRef(["memory"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["memory"]);
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : ramContent.implicitWidth
            implicitHeight: root.isVerticalOrientation ? ramColumn.implicitHeight : (root.widgetThickness - root.horizontalPadding * 2)

            Column {
                id: ramColumn
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: "developer_board"
                    size: Theme.barIconSize(root.barThickness)
                    color: {
                        if (DgopService.memoryUsage > 90) {
                            return Theme.tempDanger;
                        }

                        if (DgopService.memoryUsage > 75) {
                            return Theme.tempWarning;
                        }

                        return Theme.surfaceText;
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        if (DgopService.memoryUsage === undefined || DgopService.memoryUsage === null || DgopService.memoryUsage === 0) {
                            return "--";
                        }

                        return DgopService.memoryUsage.toFixed(0);
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness)
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    visible: root.showSwap && DgopService.totalSwapKB > 0
                    text: root.swapUsage.toFixed(0)
                    font.pixelSize: Theme.barTextSize(root.barThickness)
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: ramContent
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 3

                DankIcon {
                    name: "developer_board"
                    size: Theme.barIconSize(root.barThickness)
                    color: {
                        if (DgopService.memoryUsage > 90) {
                            return Theme.tempDanger;
                        }

                        if (DgopService.memoryUsage > 75) {
                            return Theme.tempWarning;
                        }

                        return Theme.surfaceText;
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: {
                        if (DgopService.memoryUsage === undefined || DgopService.memoryUsage === null || DgopService.memoryUsage === 0) {
                            return "--%";
                        }

                        let ramText = DgopService.memoryUsage.toFixed(0) + "%";
                        if (root.showSwap && DgopService.totalSwapKB > 0) {
                            return ramText + " · " + root.swapUsage.toFixed(0) + "%";
                        }
                        return ramText;
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness)
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideNone
                    wrapMode: Text.NoWrap

                    StyledTextMetrics {
                        id: ramBaseline
                        font.pixelSize: Theme.barTextSize(root.barThickness)
                        text: {
                            if (!root.showSwap) {
                                return "100%";
                            }
                            if (root.swapUsage < 10) {
                                return "100% · 0%";
                            }
                            return "100% · 100%";
                        }
                    }

                    width: root.minimumWidth ? Math.max(ramBaseline.width, paintedWidth) : paintedWidth

                    Behavior on width {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onPressed: {
            if (popoutTarget && popoutTarget.setTriggerPosition) {
                const globalPos = root.visualContent.mapToGlobal(0, 0)
                const currentScreen = parentScreen || Screen
                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, barThickness, root.visualWidth)
                popoutTarget.setTriggerPosition(pos.x, pos.y, pos.width, section, currentScreen)
            }
            DgopService.setSortBy("memory");
            if (root.toggleProcessList) {
                root.toggleProcessList();
            }
        }
    }
}
