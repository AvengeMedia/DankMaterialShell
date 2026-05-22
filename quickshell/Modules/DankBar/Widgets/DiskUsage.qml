import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property var widgetData: null

    property string mountPath:
        (widgetData && widgetData.mountPath !== undefined)
        ? widgetData.mountPath
        : "/"

    property int diskUsageMode:
        (widgetData && widgetData.diskUsageMode !== undefined)
        ? widgetData.diskUsageMode
        : 0

    property bool isHovered: mouseArea.containsMouse
    property bool isAutoHideBar: false

    property var selectedMount: {
        if (!DgopService.diskMounts
                || DgopService.diskMounts.length === 0) {
            return null;
        }

        const currentMountPath = root.mountPath || "/";

        for (let i = 0; i < DgopService.diskMounts.length; i++) {
            if (DgopService.diskMounts[i].mount
                    === currentMountPath) {
                return DgopService.diskMounts[i];
            }
        }

        for (let i = 0; i < DgopService.diskMounts.length; i++) {
            if (DgopService.diskMounts[i].mount === "/") {
                return DgopService.diskMounts[i];
            }
        }

        return DgopService.diskMounts[0] || null;
    }

    property real diskUsagePercent: {
        if (!selectedMount || !selectedMount.percent) {
            return 0;
        }

        const percentStr =
                selectedMount.percent.replace("%", "");

        return parseFloat(percentStr) || 0;
    }

    Component.onCompleted: {
        DgopService.addRef(["diskmounts"]);
    }

    Component.onDestruction: {
        DgopService.removeRef(["diskmounts"]);
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation
                           ? (root.widgetThickness
                              - root.horizontalPadding * 2)
                           : diskContent.implicitWidth

            implicitHeight: root.isVerticalOrientation
                            ? diskColumn.implicitHeight
                            : diskContent.implicitHeight

            Column {
                id: diskColumn

                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: "storage"

                    size: Theme.barIconSize(
                              root.barThickness,
                              undefined,
                              root.barConfig?.maximizeWidgetIcons,
                              root.barConfig?.iconScale
                          )

                    color: {
                        if (root.diskUsagePercent > 90)
                            return Theme.tempDanger;

                        if (root.diskUsagePercent > 75)
                            return Theme.tempWarning;

                        return Theme.surfaceText;
                    }

                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        if (!root.selectedMount) {
                            return "--";
                        }

                        return root.diskUsagePercent.toFixed(0);
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
                id: diskContent

                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: "storage"

                    size: Theme.barIconSize(
                              root.barThickness,
                              undefined,
                              root.barConfig?.maximizeWidgetIcons,
                              root.barConfig?.iconScale
                          )

                    color: {
                        if (root.diskUsagePercent > 90)
                            return Theme.tempDanger;

                        if (root.diskUsagePercent > 75)
                            return Theme.tempWarning;

                        return Theme.surfaceText;
                    }

                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: {
                        if (!root.selectedMount) {
                            return "--%";
                        }

                        switch (root.diskUsageMode) {
                        case 1:
                            return root.selectedMount.size || "--";

                        case 2:
                            return root.selectedMount.avail || "--";

                        case 3:
                            return (root.selectedMount.avail || "--")
                                   + " / "
                                   + (root.selectedMount.size || "--");

                        default:
                            return root.diskUsagePercent.toFixed(0)
                                   + "%";
                        }
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
}
