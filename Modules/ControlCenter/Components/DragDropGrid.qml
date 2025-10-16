import QtQuick
import qs.Common
import qs.Services
import qs.Modules.ControlCenter.Widgets
import qs.Modules.ControlCenter.Components
import "../utils/layout.js" as LayoutUtils

Column {
    id: root

    property bool editMode: false
    property string expandedSection: ""
    property int expandedWidgetIndex: -1
    property var model: null
    property var expandedWidgetData: null
    property var bluetoothCodecSelector: null
    property bool darkModeTransitionPending: false

    signal expandClicked(var widgetData, int globalIndex)
    signal removeWidget(int index)
    signal moveWidget(int fromIndex, int toIndex)
    signal toggleWidgetSize(int index)
    signal collapseRequested()

    function requestCollapse() {
        collapseRequested()
    }

    spacing: editMode ? Theme.spacingL : Theme.spacingS

    property var currentRowWidgets: []
    property real currentRowWidth: 0
    property int expandedRowIndex: -1
    property var colorPickerModal: null

    function calculateRowsAndWidgets() {
        return LayoutUtils.calculateRowsAndWidgets(root, expandedSection, expandedWidgetIndex)
    }

    property var layoutResult: {
        const dummy = [expandedSection, expandedWidgetIndex, model?.controlCenterWidgets]
        return calculateRowsAndWidgets()
    }

    onLayoutResultChanged: {
        expandedRowIndex = layoutResult.expandedRowIndex
    }

    function moveToTop(item) {
        const children = root.children
        for (var i = 0; i < children.length; i++) {
            if (children[i] === item)
                continue
            if (children[i].z)
                children[i].z = Math.min(children[i].z, 999)
        }
        item.z = 1000
    }

    Repeater {
        model: root.layoutResult.rows

        Column {
            width: root.width
            spacing: 0
            property int rowIndex: index
            property var rowWidgets: modelData
            property bool isSliderOnlyRow: {
                const widgets = rowWidgets || []
                if (widgets.length === 0)
                    return false
                return widgets.every(w => w.id === "volumeSlider" || w.id === "brightnessSlider" || w.id === "inputVolumeSlider")
            }
            topPadding: isSliderOnlyRow ? (root.editMode ? 4 : -6) : 0
            bottomPadding: isSliderOnlyRow ? (root.editMode ? 4 : -6) : 0

            Flow {
                width: parent.width
                spacing: Theme.spacingS

                Repeater {
                    model: rowWidgets || []

                    DragDropWidgetWrapper {
                        widgetData: modelData
                        property int globalWidgetIndex: {
                            const widgets = SettingsData.controlCenterWidgets || []
                            for (var i = 0; i < widgets.length; i++) {
                                if (widgets[i].id === modelData.id) {
                                    if (modelData.id === "diskUsage" || modelData.id === "brightnessSlider") {
                                        if (widgets[i].instanceId === modelData.instanceId) {
                                            return i
                                        }
                                    } else {
                                        return i
                                    }
                                }
                            }
                            return -1
                        }
                        property int widgetWidth: modelData.width || 50
                        width: {
                            const baseWidth = root.width
                            const spacing = Theme.spacingS
                            if (widgetWidth <= 25) {
                                return (baseWidth - spacing * 3) / 4
                            } else if (widgetWidth <= 50) {
                                return (baseWidth - spacing) / 2
                            } else if (widgetWidth <= 75) {
                                return (baseWidth - spacing * 2) * 0.75
                            } else {
                                return baseWidth
                            }
                        }
                        height: isSliderOnlyRow ? 48 : 60

                        editMode: root.editMode
                        widgetIndex: globalWidgetIndex
                        gridCellWidth: width
                        gridCellHeight: height
                        gridColumns: 4
                        gridLayout: root
                        isSlider: {
                            const id = modelData.id || ""
                            return id === "volumeSlider" || id === "brightnessSlider" || id === "inputVolumeSlider"
                        }

                        widgetComponent: {
                            const id = modelData.id || ""
                            if (id.startsWith("builtin_")) {
                                return builtinPluginWidgetComponent
                            } else if (id.startsWith("plugin_")) {
                                return pluginWidgetComponent
                            } else if (id === "wifi" || id === "bluetooth" || id === "audioOutput" || id === "audioInput") {
                                return compoundPillComponent
                            } else if (id === "volumeSlider") {
                                return audioSliderComponent
                            } else if (id === "brightnessSlider") {
                                return brightnessSliderComponent
                            } else if (id === "inputVolumeSlider") {
                                return inputAudioSliderComponent
                            } else if (id === "battery") {
                                return widgetWidth <= 25 ? smallBatteryComponent : batteryPillComponent
                            } else if (id === "diskUsage") {
                                return diskUsagePillComponent
                            } else if (id === "colorPicker") {
                                return colorPickerPillComponent
                            } else {
                                return widgetWidth <= 25 ? smallToggleComponent : toggleButtonComponent
                            }
                        }

                        onWidgetMoved: (fromIndex, toIndex) => root.moveWidget(fromIndex, toIndex)
                        onRemoveWidget: index => root.removeWidget(index)
                        onToggleWidgetSize: index => root.toggleWidgetSize(index)
                    }
                }
            }

            DetailHost {
                width: parent.width
                height: active ? (250 + Theme.spacingS) : 0
                property bool active: {
                    if (root.expandedSection === "")
                        return false

                    if (root.expandedSection.startsWith("diskUsage_") && root.expandedWidgetData) {
                        const expandedInstanceId = root.expandedWidgetData.instanceId
                        return rowWidgets.some(w => w.id === "diskUsage" && w.instanceId === expandedInstanceId)
                    }

                    if (root.expandedSection.startsWith("brightnessSlider_") && root.expandedWidgetData) {
                        const expandedInstanceId = root.expandedWidgetData.instanceId
                        return rowWidgets.some(w => w.id === "brightnessSlider" && w.instanceId === expandedInstanceId)
                    }

                    return rowIndex === root.expandedRowIndex
                }
                visible: active
                expandedSection: root.expandedSection
                expandedWidgetData: root.expandedWidgetData
                bluetoothCodecSelector: root.bluetoothCodecSelector
                widgetModel: root.model
                collapseCallback: root.requestCollapse
            }
        }
    }

    Component {
        id: errorPillComponent
        ErrorPill {
            property var widgetData: parent.widgetData || {}
            width: parent.width
            height: 60
            primaryMessage: {
                if (!DMSService.dmsAvailable) {
                    return I18n.tr("DMS_SOCKET not available")
                }
                return I18n.tr("NM not supported")
            }
            secondaryMessage: I18n.tr("update dms for NM integration.")
        }
    }

    Component {
        id: compoundPillComponent
        CompoundPill {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            property var widgetDef: root.model?.getWidgetForId(widgetData.id || "")
            width: parent.width
            height: 60
            iconName: {
                switch (widgetData.id || "") {
                case "wifi":
                {
                    if (NetworkService.wifiToggling)
                        return "sync"
                    if (NetworkService.networkStatus === "ethernet")
                        return "settings_ethernet"
                    if (NetworkService.networkStatus === "wifi")
                        return NetworkService.wifiSignalIcon
                    if (NetworkService.wifiEnabled)
                        return "wifi_off"
                    return "wifi_off"
                }
                case "bluetooth":
                {
                    if (!BluetoothService.available)
                        return "bluetooth_disabled"
                    if (!BluetoothService.adapter || !BluetoothService.adapter.enabled)
                        return "bluetooth_disabled"
                    const primaryDevice = (() => {
                                               if (!BluetoothService.adapter || !BluetoothService.adapter.devices)
                                               return null
                                               let devices = [...BluetoothService.adapter.devices.values.filter(dev => dev && (dev.paired || dev.trusted))]
                                               for (let device of devices) {
                                                   if (device && device.connected)
                                                   return device
                                               }
                                               return null
                                           })()
                    if (primaryDevice)
                        return BluetoothService.getDeviceIcon(primaryDevice)
                    return "bluetooth"
                }
                case "audioOutput":
                {
                    if (!AudioService.sink)
                        return "volume_off"
                    let volume = AudioService.sink.audio.volume
                    let muted = AudioService.sink.audio.muted
                    if (muted || volume === 0.0)
                        return "volume_off"
                    if (volume <= 0.33)
                        return "volume_down"
                    if (volume <= 0.66)
                        return "volume_up"
                    return "volume_up"
                }
                case "audioInput":
                {
                    if (!AudioService.source)
                        return "mic_off"
                    let muted = AudioService.source.audio.muted
                    return muted ? "mic_off" : "mic"
                }
                default:
                    return widgetDef?.icon || "help"
                }
            }
            primaryText: {
                switch (widgetData.id || "") {
                case "wifi":
                {
                    if (NetworkService.wifiToggling)
                        return NetworkService.wifiEnabled ? "Disabling WiFi..." : "Enabling WiFi..."
                    if (NetworkService.networkStatus === "ethernet")
                        return "Ethernet"
                    if (NetworkService.networkStatus === "wifi" && NetworkService.currentWifiSSID)
                        return NetworkService.currentWifiSSID
                    if (NetworkService.wifiEnabled)
                        return "Not connected"
                    return "WiFi off"
                }
                case "bluetooth":
                {
                    if (!BluetoothService.available)
                        return "Bluetooth"
                    if (!BluetoothService.adapter)
                        return "No adapter"
                    if (!BluetoothService.adapter.enabled)
                        return "Disabled"
                    return "Enabled"
                }
                case "audioOutput":
                    return AudioService.sink?.description || "No output device"
                case "audioInput":
                    return AudioService.source?.description || "No input device"
                default:
                    return widgetDef?.text || "Unknown"
                }
            }
            secondaryText: {
                switch (widgetData.id || "") {
                case "wifi":
                {
                    if (NetworkService.wifiToggling)
                        return "Please wait..."
                    if (NetworkService.networkStatus === "ethernet")
                        return "Connected"
                    if (NetworkService.networkStatus === "wifi")
                        return NetworkService.wifiSignalStrength > 0 ? NetworkService.wifiSignalStrength + "%" : "Connected"
                    if (NetworkService.wifiEnabled)
                        return "Select network"
                    return ""
                }
                case "bluetooth":
                {
                    if (!BluetoothService.available)
                        return "No adapters"
                    if (!BluetoothService.adapter || !BluetoothService.adapter.enabled)
                        return "Off"
                    const primaryDevice = (() => {
                                               if (!BluetoothService.adapter || !BluetoothService.adapter.devices)
                                               return null
                                               let devices = [...BluetoothService.adapter.devices.values.filter(dev => dev && (dev.paired || dev.trusted))]
                                               for (let device of devices) {
                                                   if (device && device.connected)
                                                   return device
                                               }
                                               return null
                                           })()
                    if (primaryDevice)
                        return primaryDevice.name || primaryDevice.alias || primaryDevice.deviceName || "Connected Device"
                    return "No devices"
                }
                case "audioOutput":
                {
                    if (!AudioService.sink)
                        return "Select device"
                    if (AudioService.sink.audio.muted)
                        return "Muted"
                    return Math.round(AudioService.sink.audio.volume * 100) + "%"
                }
                case "audioInput":
                {
                    if (!AudioService.source)
                        return "Select device"
                    if (AudioService.source.audio.muted)
                        return "Muted"
                    return Math.round(AudioService.source.audio.volume * 100) + "%"
                }
                default:
                    return widgetDef?.description || ""
                }
            }
            isActive: {
                switch (widgetData.id || "") {
                case "wifi":
                {
                    if (NetworkService.wifiToggling)
                        return false
                    if (NetworkService.networkStatus === "ethernet")
                        return true
                    if (NetworkService.networkStatus === "wifi")
                        return true
                    return NetworkService.wifiEnabled
                }
                case "bluetooth":
                    return !!(BluetoothService.available && BluetoothService.adapter && BluetoothService.adapter.enabled)
                case "audioOutput":
                    return !!(AudioService.sink && !AudioService.sink.audio.muted)
                case "audioInput":
                    return !!(AudioService.source && !AudioService.source.audio.muted)
                default:
                    return false
                }
            }
            enabled: widgetDef?.enabled ?? true
            onToggled: {
                if (root.editMode)
                    return
                switch (widgetData.id || "") {
                case "wifi":
                {
                    if (NetworkService.networkStatus !== "ethernet" && !NetworkService.wifiToggling) {
                        NetworkService.toggleWifiRadio()
                    }
                    break
                }
                case "bluetooth":
                {
                    if (BluetoothService.available && BluetoothService.adapter) {
                        BluetoothService.adapter.enabled = !BluetoothService.adapter.enabled
                    }
                    break
                }
                case "audioOutput":
                {
                    if (AudioService.sink && AudioService.sink.audio) {
                        AudioService.sink.audio.muted = !AudioService.sink.audio.muted
                    }
                    break
                }
                case "audioInput":
                {
                    if (AudioService.source && AudioService.source.audio) {
                        AudioService.source.audio.muted = !AudioService.source.audio.muted
                    }
                    break
                }
                }
            }
            onExpandClicked: {
                if (root.editMode)
                    return
                root.expandClicked(widgetData, widgetIndex)
            }
            onWheelEvent: function (wheelEvent) {
                if (root.editMode)
                    return
                const id = widgetData.id || ""
                if (id === "audioOutput") {
                    if (!AudioService.sink || !AudioService.sink.audio)
                        return
                    let delta = wheelEvent.angleDelta.y
                    let currentVolume = AudioService.sink.audio.volume * 100
                    let newVolume
                    if (delta > 0)
                        newVolume = Math.min(100, currentVolume + 5)
                    else
                        newVolume = Math.max(0, currentVolume - 5)
                    AudioService.sink.audio.muted = false
                    AudioService.sink.audio.volume = newVolume / 100
                    wheelEvent.accepted = true
                } else if (id === "audioInput") {
                    if (!AudioService.source || !AudioService.source.audio)
                        return
                    let delta = wheelEvent.angleDelta.y
                    let currentVolume = AudioService.source.audio.volume * 100
                    let newVolume
                    if (delta > 0)
                        newVolume = Math.min(100, currentVolume + 5)
                    else
                        newVolume = Math.max(0, currentVolume - 5)
                    AudioService.source.audio.muted = false
                    AudioService.source.audio.volume = newVolume / 100
                    wheelEvent.accepted = true
                }
            }
        }
    }

    Component {
        id: audioSliderComponent
        Item {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            width: parent.width
            height: 16

            AudioSliderRow {
                anchors.centerIn: parent
                width: parent.width
                height: 14
                property color sliderTrackColor: Theme.surfaceContainerHigh
            }
        }
    }

    Component {
        id: brightnessSliderComponent
        Item {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            width: parent.width
            height: 16

            BrightnessSliderRow {
                id: brightnessSliderRow
                anchors.centerIn: parent
                width: parent.width
                height: 14
                deviceName: widgetData.deviceName || ""
                instanceId: widgetData.instanceId || ""
                property color sliderTrackColor: Theme.surfaceContainerHigh

                onIconClicked: {
                    if (!root.editMode && DisplayService.devices && DisplayService.devices.length > 1) {
                        root.expandClicked(widgetData, widgetIndex)
                    }
                }
            }
        }
    }

    Component {
        id: inputAudioSliderComponent
        Item {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            width: parent.width
            height: 16

            InputAudioSliderRow {
                anchors.centerIn: parent
                width: parent.width
                height: 14
                property color sliderTrackColor: Theme.surfaceContainerHigh
            }
        }
    }

    Component {
        id: batteryPillComponent
        BatteryPill {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            width: parent.width
            height: 60

            onExpandClicked: {
                if (!root.editMode) {
                    root.expandClicked(widgetData, widgetIndex)
                }
            }
        }
    }

    Component {
        id: smallBatteryComponent
        SmallBatteryButton {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            width: parent.width
            height: 48

            onClicked: {
                if (!root.editMode) {
                    root.expandClicked(widgetData, widgetIndex)
                }
            }
        }
    }

    Component {
        id: toggleButtonComponent
        ToggleButton {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            width: parent.width
            height: 60

            iconName: {
                switch (widgetData.id || "") {
                case "nightMode":
                    return DisplayService.nightModeEnabled ? "nightlight" : "dark_mode"
                case "darkMode":
                    return "contrast"
                case "doNotDisturb":
                    return SessionData.doNotDisturb ? "do_not_disturb_on" : "do_not_disturb_off"
                case "idleInhibitor":
                    return SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
                default:
                    return "help"
                }
            }

            text: {
                switch (widgetData.id || "") {
                case "nightMode":
                    return "Night Mode"
                case "darkMode":
                    return SessionData.isLightMode ? "Light Mode" : "Dark Mode"
                case "doNotDisturb":
                    return "Do Not Disturb"
                case "idleInhibitor":
                    return SessionService.idleInhibited ? "Keeping Awake" : "Keep Awake"
                default:
                    return "Unknown"
                }
            }

            iconRotation: {
                if (widgetData.id !== "darkMode")
                    return 0
                if (darkModeTransitionPending) {
                    return SessionData.isLightMode ? 180 : 0
                }
                return SessionData.isLightMode ? 180 : 0
            }

            isActive: {
                switch (widgetData.id || "") {
                case "nightMode":
                    return DisplayService.nightModeEnabled || false
                case "darkMode":
                    return SessionData.isLightMode
                case "doNotDisturb":
                    return SessionData.doNotDisturb || false
                case "idleInhibitor":
                    return SessionService.idleInhibited || false
                default:
                    return false
                }
            }

            enabled: !root.editMode

            onClicked: {
                if (root.editMode)
                    return
                switch (widgetData.id || "") {
                case "nightMode":
                {
                    if (DisplayService.automationAvailable)
                        DisplayService.toggleNightMode()
                    break
                }
                case "darkMode":
                {
                    const newMode = !SessionData.isLightMode
                    Theme.screenTransition()
                    Theme.setLightMode(newMode)
                    break
                }
                case "doNotDisturb":
                {
                    SessionData.setDoNotDisturb(!SessionData.doNotDisturb)
                    break
                }
                case "idleInhibitor":
                {
                    SessionService.toggleIdleInhibit()
                    break
                }
                }
            }
        }
    }

    Component {
        id: smallToggleComponent
        SmallToggleButton {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            width: parent.width
            height: 48

            iconName: {
                switch (widgetData.id || "") {
                case "nightMode":
                    return DisplayService.nightModeEnabled ? "nightlight" : "dark_mode"
                case "darkMode":
                    return "contrast"
                case "doNotDisturb":
                    return SessionData.doNotDisturb ? "do_not_disturb_on" : "do_not_disturb_off"
                case "idleInhibitor":
                    return SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
                default:
                    return "help"
                }
            }

            iconRotation: {
                if (widgetData.id !== "darkMode")
                    return 0
                if (darkModeTransitionPending) {
                    return SessionData.isLightMode ? 180 : 0
                }
                return SessionData.isLightMode ? 180 : 0
            }

            isActive: {
                switch (widgetData.id || "") {
                case "nightMode":
                    return DisplayService.nightModeEnabled || false
                case "darkMode":
                    return SessionData.isLightMode
                case "doNotDisturb":
                    return SessionData.doNotDisturb || false
                case "idleInhibitor":
                    return SessionService.idleInhibited || false
                default:
                    return false
                }
            }

            enabled: !root.editMode

            onClicked: {
                if (root.editMode)
                    return
                switch (widgetData.id || "") {
                case "nightMode":
                {
                    if (DisplayService.automationAvailable)
                        DisplayService.toggleNightMode()
                    break
                }
                case "darkMode":
                {
                    const newMode = !SessionData.isLightMode
                    Theme.screenTransition()
                    Theme.setLightMode(newMode)
                    break
                }
                case "doNotDisturb":
                {
                    SessionData.setDoNotDisturb(!SessionData.doNotDisturb)
                    break
                }
                case "idleInhibitor":
                {
                    SessionService.toggleIdleInhibit()
                    break
                }
                }
            }
        }
    }

    Component {
        id: diskUsagePillComponent
        DiskUsagePill {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            width: parent.width
            height: 60

            mountPath: widgetData.mountPath || "/"
            instanceId: widgetData.instanceId || ""

            onExpandClicked: {
                if (!root.editMode) {
                    root.expandClicked(widgetData, widgetIndex)
                }
            }
        }
    }

    Component {
        id: colorPickerPillComponent
        ColorPickerPill {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            width: parent.width
            height: 60

            colorPickerModal: root.colorPickerModal
        }
    }

    Component {
        id: builtinPluginWidgetComponent
        Loader {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            property int widgetWidth: widgetData.width || 50
            width: parent.width
            height: 60

            property var builtinInstance: null

            Component.onCompleted: {
                const id = widgetData.id || ""
                if (id === "builtin_vpn") {
                    if (root.model?.vpnLoader) {
                        root.model.vpnLoader.active = true
                    }
                    builtinInstance = Qt.binding(() => root.model?.vpnBuiltinInstance)
                }
            }

            sourceComponent: {
                if (!builtinInstance)
                    return null

                const hasDetail = builtinInstance.ccDetailContent !== null

                if (widgetWidth <= 25) {
                    return builtinSmallToggleComponent
                } else if (hasDetail) {
                    return builtinCompoundPillComponent
                } else {
                    return builtinToggleComponent
                }
            }
        }
    }

    Component {
        id: builtinCompoundPillComponent
        CompoundPill {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            property var builtinInstance: parent.builtinInstance

            iconName: builtinInstance?.ccWidgetIcon || "extension"
            primaryText: builtinInstance?.ccWidgetPrimaryText || "Built-in"
            secondaryText: builtinInstance?.ccWidgetSecondaryText || ""
            isActive: builtinInstance?.ccWidgetIsActive || false

            onToggled: {
                if (root.editMode)
                    return
                if (builtinInstance) {
                    builtinInstance.ccWidgetToggled()
                }
            }

            onExpandClicked: {
                if (root.editMode)
                    return
                root.expandClicked(widgetData, widgetIndex)
            }
        }
    }

    Component {
        id: builtinToggleComponent
        ToggleButton {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            property var builtinInstance: parent.builtinInstance

            iconName: builtinInstance?.ccWidgetIcon || "extension"
            text: builtinInstance?.ccWidgetPrimaryText || "Built-in"
            isActive: builtinInstance?.ccWidgetIsActive || false
            enabled: !root.editMode

            onClicked: {
                if (root.editMode)
                    return
                if (builtinInstance) {
                    builtinInstance.ccWidgetToggled()
                }
            }
        }
    }

    Component {
        id: builtinSmallToggleComponent
        SmallToggleButton {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            property var builtinInstance: parent.builtinInstance

            iconName: builtinInstance?.ccWidgetIcon || "extension"
            isActive: builtinInstance?.ccWidgetIsActive || false
            enabled: !root.editMode

            onClicked: {
                if (root.editMode)
                    return
                if (builtinInstance) {
                    builtinInstance.ccWidgetToggled()
                }
            }
        }
    }

    Component {
        id: pluginWidgetComponent
        Loader {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            property int widgetWidth: widgetData.width || 50
            width: parent.width
            height: 60

            property var pluginInstance: null
            property string pluginId: widgetData.id?.replace("plugin_", "") || ""

            sourceComponent: {
                if (!pluginInstance)
                    return null

                const hasDetail = pluginInstance.ccDetailContent !== null

                if (widgetWidth <= 25) {
                    return pluginSmallToggleComponent
                } else if (hasDetail) {
                    return pluginCompoundPillComponent
                } else {
                    return pluginToggleComponent
                }
            }

            Component.onCompleted: {
                Qt.callLater(() => {
                                 const pluginComponent = PluginService.pluginWidgetComponents[pluginId]
                                 if (pluginComponent) {
                                     const instance = pluginComponent.createObject(null, {
                                                                                       "pluginId": pluginId,
                                                                                       "pluginService": PluginService,
                                                                                       "visible": false,
                                                                                       "width": 0,
                                                                                       "height": 0
                                                                                   })
                                     if (instance) {
                                         pluginInstance = instance
                                     }
                                 }
                             })
            }

            Connections {
                target: PluginService
                function onPluginDataChanged(changedPluginId) {
                    if (changedPluginId === pluginId && pluginInstance) {
                        pluginInstance.loadPluginData()
                    }
                }
            }

            Component.onDestruction: {
                if (pluginInstance) {
                    pluginInstance.destroy()
                }
            }
        }
    }

    Component {
        id: pluginCompoundPillComponent
        CompoundPill {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            property var pluginInstance: parent.pluginInstance

            iconName: pluginInstance?.ccWidgetIcon || "extension"
            primaryText: pluginInstance?.ccWidgetPrimaryText || "Plugin"
            secondaryText: pluginInstance?.ccWidgetSecondaryText || ""
            isActive: pluginInstance?.ccWidgetIsActive || false

            onToggled: {
                if (root.editMode)
                    return
                if (pluginInstance) {
                    pluginInstance.ccWidgetToggled()
                }
            }

            onExpandClicked: {
                if (root.editMode)
                    return
                root.expandClicked(widgetData, widgetIndex)
            }
        }
    }

    Component {
        id: pluginToggleComponent
        ToggleButton {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            property var pluginInstance: parent.pluginInstance
            property var widgetDef: root.model?.getWidgetForId(widgetData.id || "")

            iconName: pluginInstance?.ccWidgetIcon || widgetDef?.icon || "extension"
            text: pluginInstance?.ccWidgetPrimaryText || widgetDef?.text || "Plugin"
            secondaryText: pluginInstance?.ccWidgetSecondaryText || ""
            isActive: pluginInstance?.ccWidgetIsActive || false
            enabled: !root.editMode

            onClicked: {
                if (root.editMode)
                    return
                if (pluginInstance) {
                    pluginInstance.ccWidgetToggled()
                }
            }
        }
    }

    Component {
        id: pluginSmallToggleComponent
        SmallToggleButton {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            property var pluginInstance: parent.pluginInstance
            property var widgetDef: root.model?.getWidgetForId(widgetData.id || "")

            iconName: pluginInstance?.ccWidgetIcon || widgetDef?.icon || "extension"
            isActive: pluginInstance?.ccWidgetIsActive || false
            enabled: !root.editMode

            onClicked: {
                if (root.editMode)
                    return
                if (pluginInstance && pluginInstance.ccDetailContent) {
                    root.expandClicked(widgetData, widgetIndex)
                } else if (pluginInstance) {
                    pluginInstance.ccWidgetToggled()
                }
            }
        }
    }
}
