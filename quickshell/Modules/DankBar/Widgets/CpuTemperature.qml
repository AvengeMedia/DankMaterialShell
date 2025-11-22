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

    signal cpuTempClicked()

    Component.onCompleted: {
        DgopService.addRef(["cpu"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["cpu"]);
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : cpuTempContent.implicitWidth
            implicitHeight: root.isVerticalOrientation ? cpuTempColumn.implicitHeight : (root.widgetThickness - root.horizontalPadding * 2)

            Column {
                id: cpuTempColumn
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: "device_thermostat"
                    size: Theme.barIconSize(root.barThickness)
                    color: {
                        if (DgopService.cpuTemperature > 85) {
                            return Theme.tempDanger;
                        }

                        if (DgopService.cpuTemperature > 69) {
                            return Theme.tempWarning;
                        }

                        return Theme.widgetIconColor;
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        if (DgopService.cpuTemperature === undefined || DgopService.cpuTemperature === null || DgopService.cpuTemperature < 0) {
                            return "--";
                        }

                        return Math.round(DgopService.cpuTemperature).toString();
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: cpuTempContent
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 3

                DankIcon {
                    name: "device_thermostat"
                    size: Theme.barIconSize(root.barThickness)
                    color: {
                        if (DgopService.cpuTemperature > 85) {
                            return Theme.tempDanger;
                        }

                        if (DgopService.cpuTemperature > 69) {
                            return Theme.tempWarning;
                        }

                        return Theme.widgetIconColor;
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: {
                        if (DgopService.cpuTemperature === undefined || DgopService.cpuTemperature === null || DgopService.cpuTemperature < 0) {
                            return "--°";
                        }

                        return Math.round(DgopService.cpuTemperature) + "°";
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideNone

                    StyledTextMetrics {
                        id: tempBaseline
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        text: "100°"
                    }

                    width: root.minimumWidth ? Math.max(tempBaseline.width, paintedWidth) : paintedWidth

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
            cpuTempClicked()
        }
    }
}
