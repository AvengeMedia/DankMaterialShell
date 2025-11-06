import QtQuick
import qs.Common
import qs.Modules.ControlCenter.Details

Item {
    id: root

    property string expandedSection: ""
    property var expandedWidgetData: null

    height: active ? 250 : 0
    visible: active

    readonly property bool active: expandedSection !== ""

    Behavior on height {
        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Easing.OutCubic
        }
    }

    Loader {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingS
        sourceComponent: {
            if (!root.active) return null

            if (expandedSection.startsWith("diskUsage_")) {
                return diskUsageDetailComponent
            }

            switch (expandedSection) {
                case "wifi": return networkDetailComponent
                case "bluetooth": return bluetoothDetailComponent
                case "audioOutput": return audioOutputDetailComponent
                case "audioInput": return audioInputDetailComponent
                case "battery": return batteryDetailComponent
                default: return null
            }
        }
    }

    Component {
        id: networkDetailComponent
        NetworkDetail {}
    }

    Component {
        id: bluetoothDetailComponent
        BluetoothDetail {}
    }

    Component {
        id: audioOutputDetailComponent
        AudioOutputDetail {}
    }

    Component {
        id: audioInputDetailComponent
        AudioInputDetail {}
    }

    Component {
        id: batteryDetailComponent
        BatteryDetail {}
    }

    Component {
        id: diskUsageDetailComponent
        DiskUsageDetail {
            currentMountPath: root.expandedWidgetData?.mountPath || "/"
            instanceId: root.expandedWidgetData?.instanceId || ""

            onMountPathChanged: (newMountPath) => {
                if (root.expandedWidgetData && root.expandedWidgetData.id === "diskUsage") {
                    const widgets = SettingsData.controlCenterWidgets || []
                    const newWidgets = widgets.map(w => {
                        if (w.id === "diskUsage" && w.instanceId === root.expandedWidgetData.instanceId) {
                            const updatedWidget = Object.assign({}, w)
                            updatedWidget.mountPath = newMountPath
                            return updatedWidget
                        }
                        return w
                    })
                    SettingsData.set("controlCenterWidgets", newWidgets)
                }
            }
        }
    }
}