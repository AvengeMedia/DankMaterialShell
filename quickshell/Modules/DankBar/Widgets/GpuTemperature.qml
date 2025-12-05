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
    property int selectedGpuIndex: (widgetData && widgetData.selectedGpuIndex !== undefined) ? widgetData.selectedGpuIndex : 0
    property bool minimumWidth: (widgetData && widgetData.minimumWidth !== undefined) ? widgetData.minimumWidth : true

    signal gpuTempClicked

    property real displayTemp: {
        if (!DgopService.availableGpus || DgopService.availableGpus.length === 0) {
            return 0;
        }

        if (selectedGpuIndex >= 0 && selectedGpuIndex < DgopService.availableGpus.length) {
            return DgopService.availableGpus[selectedGpuIndex].temperature || 0;
        }

        return 0;
    }

    function updateWidgetPciId(pciId) {
        const sections = ["left", "center", "right"];
        const defaultBar = SettingsData.barConfigs[0] || SettingsData.getBarConfig("default");
        if (!defaultBar)
            return;
        for (let s = 0; s < sections.length; s++) {
            const sectionId = sections[s];
            let widgets = [];
            if (sectionId === "left") {
                widgets = (defaultBar.leftWidgets || []).slice();
            } else if (sectionId === "center") {
                widgets = (defaultBar.centerWidgets || []).slice();
            } else if (sectionId === "right") {
                widgets = (defaultBar.rightWidgets || []).slice();
            }
            for (let i = 0; i < widgets.length; i++) {
                const widget = widgets[i];
                if (typeof widget === "object" && widget.id === "gpuTemp" && (!widget.pciId || widget.pciId === "")) {
                    widgets[i] = {
                        "id": widget.id,
                        "enabled": widget.enabled !== undefined ? widget.enabled : true,
                        "selectedGpuIndex": 0,
                        "pciId": pciId
                    };
                    if (sectionId === "left") {
                        SettingsData.setDankBarLeftWidgets(widgets);
                    } else if (sectionId === "center") {
                        SettingsData.setDankBarCenterWidgets(widgets);
                    } else if (sectionId === "right") {
                        SettingsData.setDankBarRightWidgets(widgets);
                    }
                    return;
                }
            }
        }
    }

    Component.onCompleted: {
        DgopService.addRef(["gpu"]);
        if (widgetData && widgetData.pciId) {
            DgopService.addGpuPciId(widgetData.pciId);
        } else {
            autoSaveTimer.running = true;
        }
    }
    Component.onDestruction: {
        DgopService.removeRef(["gpu"]);
        if (widgetData && widgetData.pciId) {
            DgopService.removeGpuPciId(widgetData.pciId);
        }
    }

    Connections {
        function onWidgetDataChanged() {
            root.selectedGpuIndex = Qt.binding(() => {
                return (root.widgetData && root.widgetData.selectedGpuIndex !== undefined) ? root.widgetData.selectedGpuIndex : 0;
            });
        }

        target: SettingsData
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : gpuTempRow.implicitWidth
            implicitHeight: root.isVerticalOrientation ? gpuTempColumn.implicitHeight : gpuTempRow.implicitHeight

            Column {
                id: gpuTempColumn
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: "auto_awesome_mosaic"
                    size: Theme.barIconSize(root.barThickness)
                    color: {
                        if (root.displayTemp > 80) {
                            return Theme.tempDanger;
                        }

                        if (root.displayTemp > 65) {
                            return Theme.tempWarning;
                        }

                        return Theme.widgetIconColor;
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        if (root.displayTemp === undefined || root.displayTemp === null || root.displayTemp === 0) {
                            return "--";
                        }

                        return Math.round(root.displayTemp).toString();
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: gpuTempRow
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    id: gpuTempIcon
                    name: "auto_awesome_mosaic"
                    size: Theme.barIconSize(root.barThickness)
                    color: {
                        if (root.displayTemp > 80) {
                            return Theme.tempDanger;
                        }

                        if (root.displayTemp > 65) {
                            return Theme.tempWarning;
                        }

                        return Theme.widgetIconColor;
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    id: textBox
                    anchors.verticalCenter: parent.verticalCenter

                    implicitWidth: root.minimumWidth ? Math.max(gpuTempBaseline.width, gpuTempText.paintedWidth) : gpuTempText.paintedWidth
                    implicitHeight: gpuTempText.implicitHeight

                    width: implicitWidth
                    height: implicitHeight

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    StyledTextMetrics {
                        id: gpuTempBaseline
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        text: "88°"
                    }

                    StyledText {
                        id: gpuTempText
                        text: {
                            if (root.displayTemp === undefined || root.displayTemp === null || root.displayTemp === 0) {
                                return "--°";
                            }

                            return Math.round(root.displayTemp) + "°";
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
            gpuTempClicked();
        }
    }

    Timer {
        id: autoSaveTimer

        interval: 100
        running: false
        onTriggered: {
            if (DgopService.availableGpus && DgopService.availableGpus.length > 0) {
                const firstGpu = DgopService.availableGpus[0];
                if (firstGpu && firstGpu.pciId) {
                    updateWidgetPciId(firstGpu.pciId);
                    DgopService.addGpuPciId(firstGpu.pciId);
                }
            }
        }
    }
}
