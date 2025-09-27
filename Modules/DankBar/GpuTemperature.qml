import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    property bool showPercentage: true
    property bool showIcon: true
    property var toggleProcessList
    property string section: "right"
    property var popupTarget: null
    property var parentScreen: null
    property var widgetData: null
    property real barHeight: 48
    property real widgetHeight: 30
    property int selectedGpuIndex: (widgetData && widgetData.selectedGpuIndex !== undefined) ? widgetData.selectedGpuIndex : 0
    readonly property real horizontalPadding: SettingsData.dankBarNoBackground ? 0 : Math.max(Theme.spacingXS, Theme.spacingS * (widgetHeight / 30))
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
        // Find and update this widget's pciId in the settings
        const sections = ["left", "center", "right"];
        for (let s = 0; s < sections.length; s++) {
            const sectionId = sections[s];
            let widgets = [];
            if (sectionId === "left") {
                widgets = SettingsData.dankBarLeftWidgets.slice();
            } else if (sectionId === "center") {
                widgets = SettingsData.dankBarCenterWidgets.slice();
            } else if (sectionId === "right") {
                widgets = SettingsData.dankBarRightWidgets.slice();
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
                    return ;
                }
            }
        }
    }

    width: gpuTempContent.implicitWidth + horizontalPadding * 2
    height: widgetHeight
    radius: SettingsData.dankBarNoBackground ? 0 : Theme.cornerRadius
    color: {
        if (SettingsData.dankBarNoBackground) {
            return "transparent";
        }

        const baseColor = gpuArea.containsMouse ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor;
        return Qt.rgba(baseColor.r, baseColor.g, baseColor.b, baseColor.a * Theme.widgetTransparency);
    }
    Component.onCompleted: {
        DgopService.addRef(["gpu"]);
        console.log("GpuTemperature widget - pciId:", widgetData ? widgetData.pciId : "no widgetData", "selectedGpuIndex:", widgetData ? widgetData.selectedGpuIndex : "no widgetData");
        // Add this widget's PCI ID to the service
        if (widgetData && widgetData.pciId) {
            console.log("Adding GPU PCI ID to service:", widgetData.pciId);
            DgopService.addGpuPciId(widgetData.pciId);
        } else {
            console.log("No PCI ID in widget data, starting auto-detection");
            // No PCI ID saved, auto-detect and save the first GPU
            autoSaveTimer.running = true;
        }
    }
    Component.onDestruction: {
        DgopService.removeRef(["gpu"]);
        // Remove this widget's PCI ID from the service
        if (widgetData && widgetData.pciId) {
            DgopService.removeGpuPciId(widgetData.pciId);
        }

    }

    Connections {
        function onWidgetDataChanged() {
            // Force property re-evaluation by triggering change detection
            root.selectedGpuIndex = Qt.binding(() => {
                return (root.widgetData && root.widgetData.selectedGpuIndex !== undefined) ? root.widgetData.selectedGpuIndex : 0;
            });
        }

        target: SettingsData
    }

    MouseArea {
        id: gpuArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            if (popupTarget && popupTarget.setTriggerPosition) {
                const globalPos = mapToGlobal(0, 0);
                const currentScreen = parentScreen || Screen;
                const screenX = currentScreen.x || 0;
                const relativeX = globalPos.x - screenX;
                popupTarget.setTriggerPosition(relativeX, SettingsData.getPopupYPosition(barHeight), width, section, currentScreen);
            }
            DgopService.setSortBy("cpu");
            if (root.toggleProcessList) {
                root.toggleProcessList();
            }

        }
    }

    Row {
        id: gpuTempContent

        anchors.centerIn: parent
        spacing: 3

        DankIcon {
            name: "auto_awesome_mosaic"
            size: Theme.iconSize - 8
            color: {
                if (root.displayTemp > 80) {
                    return Theme.tempDanger;
                }

                if (root.displayTemp > 65) {
                    return Theme.tempWarning;
                }

                return Theme.surfaceText;
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: {
                if (root.displayTemp === undefined || root.displayTemp === null || root.displayTemp === 0) {
                    return "--°";
                }

                return Math.round(root.displayTemp) + "°";
            }
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideNone

            StyledTextMetrics {
                id: gpuTempBaseline
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                text: "100°"
            }

            width: Math.max(gpuTempBaseline.width, paintedWidth)

            Behavior on width {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
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
                    // Save the first GPU's PCI ID to this widget's settings
                    updateWidgetPciId(firstGpu.pciId);
                    DgopService.addGpuPciId(firstGpu.pciId);
                }
            }
        }
    }


}
