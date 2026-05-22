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

    property bool showSwap:
        (widgetData && widgetData.showSwap !== undefined)
        ? widgetData.showSwap
        : false

    readonly property real swapUsage:
        DgopService.totalSwapKB > 0
        ? (DgopService.usedSwapKB / DgopService.totalSwapKB) * 100
        : 0

    signal ramClicked

    Component.onCompleted: {
        DgopService.addRef(["memory"]);
    }

    Component.onDestruction: {
        DgopService.removeRef(["memory"]);
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation
                           ? (root.widgetThickness
                              - root.horizontalPadding * 2)
                           : ramContent.implicitWidth

            implicitHeight: root.isVerticalOrientation
                            ? ramColumn.implicitHeight
                            : ramContent.implicitHeight

            Column {
                id: ramColumn

                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: "developer_board"

                    size: Theme.barIconSize(
                              root.barThickness,
                              undefined,
                              root.barConfig?.maximizeWidgetIcons,
                              root.barConfig?.iconScale
                          )

                    color: {
                        if (DgopService.memoryUsage > 90)
                            return Theme.tempDanger;

                        if (DgopService.memoryUsage > 75)
                            return Theme.tempWarning;

                        return Theme.widgetIconColor;
                    }

                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        if (DgopService.memoryUsage === undefined
                                || DgopService.memoryUsage === null
                                || DgopService.memoryUsage === 0) {
                            return "--";
                        }

                        return DgopService.memoryUsage.toFixed(0);
                    }

                    font.pixelSize: Theme.barTextSize(
                                        root.barThickness,
                                        root.barConfig?.fontScale,
                                        root.barConfig?.maximizeWidgetText
                                    )

                    color: Theme.widgetTextColor

                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: ramContent

                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: "developer_board"

                    size: Theme.barIconSize(
                              root.barThickness,
                              undefined,
                              root.barConfig?.maximizeWidgetIcons,
                              root.barConfig?.iconScale
                          )

                    color: {
                        if (DgopService.memoryUsage > 90)
                            return Theme.tempDanger;

                        if (DgopService.memoryUsage > 75)
                            return Theme.tempWarning;

                        return Theme.widgetIconColor;
                    }

                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    id: ramText

                    text: {
                        if (DgopService.memoryUsage === undefined
                                || DgopService.memoryUsage === null
                                || DgopService.memoryUsage === 0) {
                            return "--%";
                        }

                        let text =
                                DgopService.memoryUsage.toFixed(0)
                                + "%";

                        if (root.showSwap
                                && DgopService.totalSwapKB > 0) {
                            return text
                                   + " · "
                                   + root.swapUsage.toFixed(0)
                                   + "%";
                        }

                        return text;
                    }

                    font.pixelSize: Theme.barTextSize(
                                        root.barThickness,
                                        root.barConfig?.fontScale,
                                        root.barConfig?.maximizeWidgetText
                                    )

                    color: Theme.widgetTextColor

                    anchors.verticalCenter: parent.verticalCenter

                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter

                    elide: Text.ElideNone
                    wrapMode: Text.NoWrap
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent

        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        onPressed: mouse => {
            root.triggerRipple(this, mouse.x, mouse.y);
            DgopService.setSortBy("memory");
            ramClicked();
        }
    }
}
