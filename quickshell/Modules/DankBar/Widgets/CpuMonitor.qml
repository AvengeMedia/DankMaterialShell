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

    signal cpuClicked()

    Component.onCompleted: {
        DgopService.addRef(["cpu"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["cpu"]);
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : cpuContent.implicitWidth
            implicitHeight: root.isVerticalOrientation ? cpuColumn.implicitHeight : (root.widgetThickness - root.horizontalPadding * 2)

            Column {
                id: cpuColumn
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: "memory"
                    size: Theme.barIconSize(root.barThickness)
                    color: {
                        if (DgopService.cpuUsage > 80) {
                            return Theme.tempDanger;
                        }

                        if (DgopService.cpuUsage > 60) {
                            return Theme.tempWarning;
                        }

                        return Theme.widgetIconColor;
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        if (DgopService.cpuUsage === undefined || DgopService.cpuUsage === null || DgopService.cpuUsage === 0) {
                            return "--";
                        }

                        return DgopService.cpuUsage.toFixed(0);
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: cpuContent
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 3

                DankIcon {
                    name: "memory"
                    size: Theme.barIconSize(root.barThickness)
                    color: {
                        if (DgopService.cpuUsage > 80) {
                            return Theme.tempDanger;
                        }

                        if (DgopService.cpuUsage > 60) {
                            return Theme.tempWarning;
                        }

                        return Theme.widgetIconColor;
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: {
                        if (DgopService.cpuUsage === undefined || DgopService.cpuUsage === null || DgopService.cpuUsage === 0) {
                            return "--%";
                        }

                        return DgopService.cpuUsage.toFixed(0) + "%";
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideNone

                    StyledTextMetrics {
                        id: cpuBaseline
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        text: "100%"
                    }

                    width: root.minimumWidth ? Math.max(cpuBaseline.width, paintedWidth) : paintedWidth

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
            DgopService.setSortBy("cpu")
            cpuClicked()
        }
    }
}
