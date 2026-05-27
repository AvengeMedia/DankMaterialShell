import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property var widgetData: null
    property string mountPath: (widgetData && widgetData.mountPath !== undefined) ? widgetData.mountPath : "/"
    property int diskUsageMode: (widgetData && widgetData.diskUsageMode !== undefined) ? widgetData.diskUsageMode : 0
    property bool showMountPath: (widgetData && widgetData.showMountPath !== undefined) ? widgetData.showMountPath : true
    property bool isHovered: mouseArea.containsMouse
    property bool isAutoHideBar: false
    property bool minimumWidth: (widgetData && widgetData.minimumWidth !== undefined) ? widgetData.minimumWidth : true

    property var selectedMount: {
        if (!DgopService.diskMounts || DgopService.diskMounts.length === 0) {
            return null;
        }

        const currentMountPath = root.mountPath || "/";

        for (let i = 0; i < DgopService.diskMounts.length; i++) {
            if (DgopService.diskMounts[i].mount === currentMountPath) {
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
        const percentStr = selectedMount.percent.replace("%", "");
        return parseFloat(percentStr) || 0;
    }

    Component.onCompleted: {
        DgopService.addRef(["diskmounts"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["diskmounts"]);
    }

    readonly property real minTooltipY: {
        if (!parentScreen || !isVerticalOrientation) {
            return 0;
        }

        if (isAutoHideBar) {
            return 0;
        }

        if (parentScreen.y > 0) {
            const spacing = barConfig?.spacing ?? 4;
            const offset = barThickness + spacing;
            return offset;
        }

        return 0;
    }

    Connections {
        target: SettingsData

        function onWidgetDataChanged() {
            root.mountPath = Qt.binding(() => {
                return (root.widgetData && root.widgetData.mountPath !== undefined) ? root.widgetData.mountPath : "/";
            });

            root.selectedMount = Qt.binding(() => {
                if (!DgopService.diskMounts || DgopService.diskMounts.length === 0) {
                    return null;
                }

                const currentMountPath = root.mountPath || "/";

                for (let i = 0; i < DgopService.diskMounts.length; i++) {
                    if (DgopService.diskMounts[i].mount === currentMountPath) {
                        return DgopService.diskMounts[i];
                    }
                }

                for (let i = 0; i < DgopService.diskMounts.length; i++) {
                    if (DgopService.diskMounts[i].mount === "/") {
                        return DgopService.diskMounts[i];
                    }
                }

                return DgopService.diskMounts[0] || null;
            });
        }
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : diskContent.implicitWidth
            implicitHeight: root.isVerticalOrientation ? diskColumn.implicitHeight : diskContent.implicitHeight

            Column {
                id: diskColumn
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: "storage"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: {
                        if (root.diskUsagePercent > 90) {
                            return Theme.tempDanger;
                        }

                        if (root.diskUsagePercent > 75) {
                            return Theme.tempWarning;
                        }

                        return Theme.widgetIconColor;
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        if (root.diskUsagePercent === undefined || root.diskUsagePercent === null || root.diskUsagePercent === 0) {
                            return "--";
                        }
                        if (!root.selectedMount)
                            return "--";
                        switch (root.diskUsageMode) {
                        case 1:
                            return root.selectedMount.size || "--";
                        case 2:
                            return root.selectedMount.avail || "--";
                        case 3:
                            return (root.selectedMount.avail || "--") + " / " + (root.selectedMount.size || "--");
                        default:
                            return root.diskUsagePercent.toFixed(0);
                        }
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
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
                    id: diskIcon
                    name: "storage"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: {
                        if (root.diskUsagePercent > 90) {
                            return Theme.tempDanger;
                        }

                        if (root.diskUsagePercent > 75) {
                            return Theme.tempWarning;
                        }

                        return Theme.widgetIconColor;
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    id: mountText
                    visible: root.showMountPath
                    text: {
                        if (!root.selectedMount) {
                            return "--";
                        }
                        return root.selectedMount.mount;
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideNone
                    wrapMode: Text.NoWrap
                }

                Item {
                    id: textBox
                    anchors.verticalCenter: parent.verticalCenter

                    implicitWidth: root.minimumWidth ? Math.max(diskBaseline.width, diskCurrent.width) : diskCurrent.width
                    implicitHeight: diskText.implicitHeight

                    width: implicitWidth
                    height: implicitHeight

                    StyledTextMetrics {
                        id: diskBaseline
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        text: {
                            switch (root.diskUsageMode) {
                            case 3:
                                return "888.8G / 888.8G";
                            case 1:
                            case 2:
                                return "888.8G";
                            default:
                                return "100%";
                            }
                        }
                    }

                    StyledTextMetrics {
                        id: diskCurrent
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        text: diskText.text
                    }

                    StyledText {
                        id: diskText
                        text: {
                            if (root.diskUsagePercent === undefined || root.diskUsagePercent === null || root.diskUsagePercent === 0) {
                                return "--%";
                            }
                            if (!root.selectedMount)
                                return "--%";
                            switch (root.diskUsageMode) {
                            case 1:
                                return root.selectedMount.size || "--";
                            case 2:
                                return root.selectedMount.avail || "--";
                            case 3:
                                return (root.selectedMount.avail || "--") + " / " + (root.selectedMount.size || "--");
                            default:
                                return root.diskUsagePercent.toFixed(0) + "%";
                            }
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor

                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideNone
                        wrapMode: Text.NoWrap
                    }
                }
            }
        }
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }

    MouseArea {
        id: mouseArea
        z: 1
        anchors.fill: parent
        hoverEnabled: root.isVerticalOrientation
        onEntered: {
            if (root.isVerticalOrientation && root.selectedMount) {
                tooltipLoader.active = true;
                if (tooltipLoader.item) {
                    const globalPos = mapToGlobal(width / 2, height / 2);
                    const currentScreen = root.parentScreen || Screen;
                    const screenX = currentScreen ? currentScreen.x : 0;
                    const screenY = currentScreen ? currentScreen.y : 0;
                    const relativeY = globalPos.y - screenY;
                    const adjustedY = relativeY + root.minTooltipY;
                    const tooltipX = root.axis?.edge === "left" ? (root.barThickness + root.barSpacing + Theme.spacingXS) : (currentScreen.width - root.barThickness - root.barSpacing - Theme.spacingXS);
                    const isLeft = root.axis?.edge === "left";
                    tooltipLoader.item.show(root.selectedMount.mount, screenX + tooltipX, adjustedY, currentScreen, isLeft, !isLeft);
                }
            }
        }
        onExited: {
            if (tooltipLoader.item) {
                tooltipLoader.item.hide();
            }
            tooltipLoader.active = false;
        }
    }
}
