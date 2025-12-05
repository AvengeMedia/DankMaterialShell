import QtQuick
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

    signal cpuClicked

    Component.onCompleted: {
        DgopService.addRef(["cpu"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["cpu"]);
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : cpuContent.implicitWidth
            implicitHeight: root.isVerticalOrientation ? cpuColumn.implicitHeight : cpuContent.implicitHeight

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
                spacing: Theme.spacingXS

                DankIcon {
                    id: cpuIcon
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

                Item {
                    id: textBox
                    anchors.verticalCenter: parent.verticalCenter

                    implicitWidth: root.minimumWidth ? Math.max(cpuBaseline.width, cpuText.paintedWidth) : cpuText.paintedWidth
                    implicitHeight: cpuText.implicitHeight

                    width: implicitWidth
                    height: implicitHeight

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    StyledTextMetrics {
                        id: cpuBaseline
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        text: "88%"
                    }

                    StyledText {
                        id: cpuText
                        text: {
                            const v = DgopService.cpuUsage;
                            if (v === undefined || v === null || v === 0) {
                                return "--%";
                            }
                            return v.toFixed(0) + "%";
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor

                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideNone
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
            DgopService.setSortBy("cpu");
            cpuClicked();
        }
    }
}
