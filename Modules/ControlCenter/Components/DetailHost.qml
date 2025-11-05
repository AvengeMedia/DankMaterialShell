import QtQuick
import qs.Common
import qs.Services
import qs.Modules.ControlCenter.Details
import qs.Modules.ControlCenter.Models

Item {
    id: root

    property string expandedSection: ""
    property var expandedWidgetData: null
    property var bluetoothCodecSelector: null
    property string screenName: ""

    property var pluginDetailInstance: null
    property var widgetModel: null
    property var collapseCallback: null

    Loader {
        id: pluginDetailLoader
        width: parent.width
        height: 250
        y: Theme.spacingS
        active: false
        sourceComponent: null
    }

    Loader {
        id: coreDetailLoader
        width: parent.width
        height: 250
        y: Theme.spacingS
        active: false
        sourceComponent: null
    }

    Connections {
        target: coreDetailLoader.item
        enabled: root.expandedSection.startsWith("brightnessSlider_")
        ignoreUnknownSignals: true

        function onDeviceNameChanged(newDeviceName) {
            if (root.expandedWidgetData && root.expandedWidgetData.id === "brightnessSlider") {
                const widgets = SettingsData.controlCenterWidgets || []
                const newWidgets = widgets.map(w => {
                    if (w.id === "brightnessSlider" && w.instanceId === root.expandedWidgetData.instanceId) {
                        const updatedWidget = Object.assign({}, w)
                        updatedWidget.deviceName = newDeviceName
                        return updatedWidget
                    }
                    return w
                })
                SettingsData.set("controlCenterWidgets", newWidgets)
                if (root.collapseCallback) {
                    root.collapseCallback()
                }
            }
        }
    }

    Connections {
        target: coreDetailLoader.item
        enabled: root.expandedSection.startsWith("diskUsage_")
        ignoreUnknownSignals: true

        function onMountPathChanged(newMountPath) {
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
                if (root.collapseCallback) {
                    root.collapseCallback()
                }
            }
        }
    }

    onExpandedSectionChanged: {
        if (pluginDetailInstance) {
            pluginDetailInstance.destroy()
            pluginDetailInstance = null
        }
        pluginDetailLoader.active = false
        coreDetailLoader.active = false

        if (!root.expandedSection) {
            return
        }

        if (root.expandedSection.startsWith("builtin_")) {
            const builtinId = root.expandedSection
            let builtinInstance = null

            if (builtinId === "builtin_vpn") {
                if (widgetModel?.vpnLoader) {
                    widgetModel.vpnLoader.active = true
                }
                builtinInstance = widgetModel.vpnBuiltinInstance
            }
            if (builtinId === "builtin_cups") {
                if (widgetModel?.cupsLoader) {
                    widgetModel.cupsLoader.active = true
                }
                builtinInstance = widgetModel.cupsBuiltinInstance
            }

            if (!builtinInstance || !builtinInstance.ccDetailContent) {
                return
            }

            pluginDetailLoader.sourceComponent = builtinInstance.ccDetailContent
            pluginDetailLoader.active = parent.height > 0
            return
        }

        if (root.expandedSection.startsWith("plugin_")) {
            const pluginId = root.expandedSection.replace("plugin_", "")
            const pluginComponent = PluginService.pluginWidgetComponents[pluginId]
            if (!pluginComponent) {
                return
            }

            pluginDetailInstance = pluginComponent.createObject(null)
            if (!pluginDetailInstance || !pluginDetailInstance.ccDetailContent) {
                if (pluginDetailInstance) {
                    pluginDetailInstance.destroy()
                    pluginDetailInstance = null
                }
                return
            }

            pluginDetailLoader.sourceComponent = pluginDetailInstance.ccDetailContent
            pluginDetailLoader.active = parent.height > 0
            return
        }

        if (root.expandedSection.startsWith("diskUsage_")) {
            coreDetailLoader.sourceComponent = diskUsageDetailComponent
            coreDetailLoader.active = parent.height > 0
            return
        }

        if (root.expandedSection.startsWith("brightnessSlider_")) {
            coreDetailLoader.sourceComponent = brightnessDetailComponent
            coreDetailLoader.active = parent.height > 0
            return
        }

        switch (root.expandedSection) {
        case "network":
        case "wifi": coreDetailLoader.sourceComponent = networkDetailComponent; break
        case "bluetooth": coreDetailLoader.sourceComponent = bluetoothDetailComponent; break
        case "audioOutput": coreDetailLoader.sourceComponent = audioOutputDetailComponent; break
        case "audioInput": coreDetailLoader.sourceComponent = audioInputDetailComponent; break
        case "battery": coreDetailLoader.sourceComponent = batteryDetailComponent; break
        default: return
        }

        coreDetailLoader.active = parent.height > 0
    }

    Component {
        id: networkDetailComponent
        NetworkDetail {}
    }

    Component {
        id: bluetoothDetailComponent
        BluetoothDetail {
            id: bluetoothDetail
            onShowCodecSelector: function(device) {
                if (root.bluetoothCodecSelector) {
                    root.bluetoothCodecSelector.show(device)
                    root.bluetoothCodecSelector.codecSelected.connect(function(deviceAddress, codecName) {
                        bluetoothDetail.updateDeviceCodecDisplay(deviceAddress, codecName)
                    })
                }
            }
        }
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
        }
    }

    Component {
        id: brightnessDetailComponent
        BrightnessDetail {
            initialDeviceName: root.expandedWidgetData?.deviceName || ""
            instanceId: root.expandedWidgetData?.instanceId || ""
            screenName: root.screenName
        }
    }
}