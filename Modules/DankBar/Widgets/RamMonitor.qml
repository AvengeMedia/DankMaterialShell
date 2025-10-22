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
                    font.weight: Font.Medium
                    color: Theme.surfaceText
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

                        return DgopService.memoryUsage.toFixed(0) + "%";
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness)
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideNone

                    StyledTextMetrics {
                        id: ramBaseline
                        font.pixelSize: Theme.barTextSize(root.barThickness)
                        font.weight: Font.Medium
                        text: "100%"
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
        hoverEnabled: true
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
