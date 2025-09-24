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

    signal expandClicked(var widgetData, int globalIndex)
    signal removeWidget(int index)
    signal moveWidget(int fromIndex, int toIndex)
    signal toggleWidgetSize(int index)

    spacing: editMode ? Theme.spacingL : Theme.spacingS

    property var currentRowWidgets: []
    property real currentRowWidth: 0
    property int expandedRowIndex: -1

    function calculateRowsAndWidgets() {
        return LayoutUtils.calculateRowsAndWidgets(root, expandedSection, expandedWidgetIndex)
    }

    Repeater {
        model: {
            const result = root.calculateRowsAndWidgets()
            root.expandedRowIndex = result.expandedRowIndex
            return result.rows
        }

        Column {
            width: root.width
            spacing: 0
            property int rowIndex: index
            property var rowWidgets: modelData
            property bool isSliderOnlyRow: {
                const widgets = rowWidgets || []
                if (widgets.length === 0) return false
                return widgets.every(w => w.id === "volumeSlider" || w.id === "brightnessSlider" || w.id === "inputVolumeSlider")
            }
            topPadding: isSliderOnlyRow ? (root.editMode ? 4 : -12) : 0
            bottomPadding: isSliderOnlyRow ? (root.editMode ? 4 : -12) : 0

            Flow {
                width: parent.width
                spacing: Theme.spacingS

                Repeater {
                    model: rowWidgets || []

                    Item {
                        property var widgetData: modelData
                        property int globalWidgetIndex: {
                            const widgets = SettingsData.controlCenterWidgets || []
                            for (var i = 0; i < widgets.length; i++) {
                                if (widgets[i].id === modelData.id) {
                                    return i
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
                        height: 60

                        Loader {
                            id: widgetLoader
                            anchors.fill: parent
                            property var widgetData: parent.widgetData
                            property int widgetIndex: parent.globalWidgetIndex
                            property int globalWidgetIndex: parent.globalWidgetIndex
                            property int widgetWidth: parent.widgetWidth

                            sourceComponent: {
                                const id = modelData.id || ""
                                if (id === "wifi" || id === "bluetooth" || id === "audioOutput" || id === "audioInput") {
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
                                } else {
                                    return widgetWidth <= 25 ? smallToggleComponent : toggleButtonComponent
                                }
                            }

                        }
                    }
                }
            }

            DetailHost {
                width: parent.width
                height: active ? (250 + Theme.spacingS) : 0
                property bool active: root.expandedSection !== "" && rowIndex === root.expandedRowIndex
                visible: active
                expandedSection: root.expandedSection
            }
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
                case "wifi": {
                    if (NetworkService.wifiToggling) {
                        return "sync"
                    }
                    if (NetworkService.networkStatus === "ethernet") {
                        return "settings_ethernet"
                    }
                    if (NetworkService.networkStatus === "wifi") {
                        return NetworkService.wifiSignalIcon
                    }
                    if (NetworkService.wifiEnabled) {
                        return "wifi_off"
                    }
                    return "wifi_off"
                }
                case "bluetooth": {
                    if (!BluetoothService.available) {
                        return "bluetooth_disabled"
                    }
                    if (!BluetoothService.adapter || !BluetoothService.adapter.enabled) {
                        return "bluetooth_disabled"
                    }
                    const primaryDevice = (() => {
                        if (!BluetoothService.adapter || !BluetoothService.adapter.devices) {
                            return null
                        }
                        let devices = [...BluetoothService.adapter.devices.values.filter(dev => dev && (dev.paired || dev.trusted))]
                        for (let device of devices) {
                            if (device && device.connected) {
                                return device
                            }
                        }
                        return null
                    })()
                    if (primaryDevice) {
                        return BluetoothService.getDeviceIcon(primaryDevice)
                    }
                    return "bluetooth"
                }
                case "audioOutput": {
                    if (!AudioService.sink) return "volume_off"
                    let volume = AudioService.sink.audio.volume
                    let muted = AudioService.sink.audio.muted
                    if (muted || volume === 0.0) return "volume_off"
                    if (volume <= 0.33) return "volume_down"
                    if (volume <= 0.66) return "volume_up"
                    return "volume_up"
                }
                case "audioInput": {
                    if (!AudioService.source) return "mic_off"
                    let muted = AudioService.source.audio.muted
                    return muted ? "mic_off" : "mic"
                }
                default: return widgetDef?.icon || "help"
                }
            }
            primaryText: {
                switch (widgetData.id || "") {
                case "wifi": {
                    if (NetworkService.wifiToggling) {
                        return NetworkService.wifiEnabled ? "Disabling WiFi..." : "Enabling WiFi..."
                    }
                    if (NetworkService.networkStatus === "ethernet") {
                        return "Ethernet"
                    }
                    if (NetworkService.networkStatus === "wifi" && NetworkService.currentWifiSSID) {
                        return NetworkService.currentWifiSSID
                    }
                    if (NetworkService.wifiEnabled) {
                        return "Not connected"
                    }
                    return "WiFi off"
                }
                case "bluetooth": {
                    if (!BluetoothService.available) {
                        return "Bluetooth"
                    }
                    if (!BluetoothService.adapter) {
                        return "No adapter"
                    }
                    if (!BluetoothService.adapter.enabled) {
                        return "Disabled"
                    }
                    return "Enabled"
                }
                case "audioOutput": return AudioService.sink?.description || "No output device"
                case "audioInput": return AudioService.source?.description || "No input device"
                default: return widgetDef?.text || "Unknown"
                }
            }
            secondaryText: {
                switch (widgetData.id || "") {
                case "wifi": {
                    if (NetworkService.wifiToggling) {
                        return "Please wait..."
                    }
                    if (NetworkService.networkStatus === "ethernet") {
                        return "Connected"
                    }
                    if (NetworkService.networkStatus === "wifi") {
                        return NetworkService.wifiSignalStrength > 0 ? NetworkService.wifiSignalStrength + "%" : "Connected"
                    }
                    if (NetworkService.wifiEnabled) {
                        return "Select network"
                    }
                    return ""
                }
                case "bluetooth": {
                    if (!BluetoothService.available) {
                        return "No adapters"
                    }
                    if (!BluetoothService.adapter || !BluetoothService.adapter.enabled) {
                        return "Off"
                    }
                    const primaryDevice = (() => {
                        if (!BluetoothService.adapter || !BluetoothService.adapter.devices) {
                            return null
                        }
                        let devices = [...BluetoothService.adapter.devices.values.filter(dev => dev && (dev.paired || dev.trusted))]
                        for (let device of devices) {
                            if (device && device.connected) {
                                return device
                            }
                        }
                        return null
                    })()
                    if (primaryDevice) {
                        return primaryDevice.name || primaryDevice.alias || primaryDevice.deviceName || "Connected Device"
                    }
                    return "No devices"
                }
                case "audioOutput": {
                    if (!AudioService.sink) {
                        return "Select device"
                    }
                    if (AudioService.sink.audio.muted) {
                        return "Muted"
                    }
                    return Math.round(AudioService.sink.audio.volume * 100) + "%"
                }
                case "audioInput": {
                    if (!AudioService.source) {
                        return "Select device"
                    }
                    if (AudioService.source.audio.muted) {
                        return "Muted"
                    }
                    return Math.round(AudioService.source.audio.volume * 100) + "%"
                }
                default: return widgetDef?.description || ""
                }
            }
            isActive: {
                switch (widgetData.id || "") {
                case "wifi": {
                    if (NetworkService.wifiToggling) {
                        return false
                    }
                    if (NetworkService.networkStatus === "ethernet") {
                        return true
                    }
                    if (NetworkService.networkStatus === "wifi") {
                        return true
                    }
                    return NetworkService.wifiEnabled
                }
                case "bluetooth": return !!(BluetoothService.available && BluetoothService.adapter && BluetoothService.adapter.enabled)
                case "audioOutput": return !!(AudioService.sink && !AudioService.sink.audio.muted)
                case "audioInput": return !!(AudioService.source && !AudioService.source.audio.muted)
                default: return false
                }
            }
            enabled: (widgetDef?.enabled ?? true)
            onToggled: {
                if (root.editMode) return
                switch (widgetData.id || "") {
                case "wifi": {
                    if (NetworkService.networkStatus !== "ethernet" && !NetworkService.wifiToggling) {
                        NetworkService.toggleWifiRadio()
                    }
                    break
                }
                case "bluetooth": {
                    if (BluetoothService.available && BluetoothService.adapter) {
                        BluetoothService.adapter.enabled = !BluetoothService.adapter.enabled
                    }
                    break
                }
                case "audioOutput": {
                    if (AudioService.sink && AudioService.sink.audio) {
                        AudioService.sink.audio.muted = !AudioService.sink.audio.muted
                    }
                    break
                }
                case "audioInput": {
                    if (AudioService.source && AudioService.source.audio) {
                        AudioService.source.audio.muted = !AudioService.source.audio.muted
                    }
                    break
                }
                }
            }
            onExpandClicked: {
                if (root.editMode) return
                root.expandClicked(widgetData, widgetIndex)
            }
            onWheelEvent: function (wheelEvent) {
                const id = widgetData.id || ""
                if (id === "audioOutput") {
                    if (!AudioService.sink || !AudioService.sink.audio) return
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
                    if (!AudioService.source || !AudioService.source.audio) return
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

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData
                widgetIndex: parent.widgetIndex
                showSizeControls: true
                isSlider: false
                onRemoveWidget: (index) => root.removeWidget(index)
                onToggleWidgetSize: (index) => root.toggleWidgetSize(index)
                onMoveWidget: (fromIndex, toIndex) => root.moveWidget(fromIndex, toIndex)
            }
        }
    }

    Component {
        id: audioSliderComponent
        Item {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            property var widgetDef: root.model?.getWidgetForId(widgetData.id || "")
            width: parent.width
            height: 16

            AudioSliderRow {
                anchors.centerIn: parent
                width: parent.width
                height: 14
                property color sliderTrackColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.60)
            }

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData
                widgetIndex: parent.widgetIndex
                showSizeControls: true
                isSlider: true
                onRemoveWidget: (index) => root.removeWidget(index)
                onToggleWidgetSize: (index) => root.toggleWidgetSize(index)
                onMoveWidget: (fromIndex, toIndex) => root.moveWidget(fromIndex, toIndex)
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
                anchors.centerIn: parent
                width: parent.width
                height: 14
                property color sliderTrackColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.60)
            }

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData
                widgetIndex: parent.widgetIndex
                showSizeControls: true
                isSlider: true
                onRemoveWidget: (index) => root.removeWidget(index)
                onToggleWidgetSize: (index) => root.toggleWidgetSize(index)
                onMoveWidget: (fromIndex, toIndex) => root.moveWidget(fromIndex, toIndex)
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
                property color sliderTrackColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.60)
            }

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData
                widgetIndex: parent.widgetIndex
                showSizeControls: true
                isSlider: true
                onRemoveWidget: (index) => root.removeWidget(index)
                onToggleWidgetSize: (index) => root.toggleWidgetSize(index)
                onMoveWidget: (fromIndex, toIndex) => root.moveWidget(fromIndex, toIndex)
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

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData
                widgetIndex: parent.widgetIndex
                showSizeControls: true
                isSlider: false
                onRemoveWidget: (index) => root.removeWidget(index)
                onToggleWidgetSize: (index) => root.toggleWidgetSize(index)
                onMoveWidget: (fromIndex, toIndex) => root.moveWidget(fromIndex, toIndex)
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

            onExpandClicked: {
                if (!root.editMode) {
                    root.expandClicked(widgetData, widgetIndex)
                }
            }

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData
                widgetIndex: parent.widgetIndex
                showSizeControls: true
                isSlider: false
                onRemoveWidget: (index) => root.removeWidget(index)
                onToggleWidgetSize: (index) => root.toggleWidgetSize(index)
                onMoveWidget: (fromIndex, toIndex) => root.moveWidget(fromIndex, toIndex)
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

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData
                widgetIndex: parent.widgetIndex
                showSizeControls: true
                isSlider: false
                onRemoveWidget: (index) => root.removeWidget(index)
                onToggleWidgetSize: (index) => root.toggleWidgetSize(index)
                onMoveWidget: (fromIndex, toIndex) => root.moveWidget(fromIndex, toIndex)
            }
        }
    }

    Component {
        id: toggleButtonComponent
        ToggleButton {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            property var widgetDef: root.model?.getWidgetForId(widgetData.id || "")
            width: parent.width
            height: 60

            iconName: {
                switch (widgetData.id || "") {
                case "nightMode": return DisplayService.nightModeEnabled ? "nightlight" : "dark_mode"
                case "darkMode": return "contrast"
                case "doNotDisturb": return SessionData.doNotDisturb ? "do_not_disturb_on" : "do_not_disturb_off"
                case "idleInhibitor": return SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
                default: return widgetDef?.icon || "help"
                }
            }

            text: {
                switch (widgetData.id || "") {
                case "nightMode": return "Night Mode"
                case "darkMode": return SessionData.isLightMode ? "Light Mode" : "Dark Mode"
                case "doNotDisturb": return "Do Not Disturb"
                case "idleInhibitor": return SessionService.idleInhibited ? "Keeping Awake" : "Keep Awake"
                default: return widgetDef?.text || "Unknown"
                }
            }

            secondaryText: ""

            iconRotation: widgetData.id === "darkMode" && SessionData.isLightMode ? 180 : 0

            isActive: {
                switch (widgetData.id || "") {
                case "nightMode": return DisplayService.nightModeEnabled || false
                case "darkMode": return !SessionData.isLightMode
                case "doNotDisturb": return SessionData.doNotDisturb || false
                case "idleInhibitor": return SessionService.idleInhibited || false
                default: return false
                }
            }

            enabled: (widgetDef?.enabled ?? true) && !root.editMode

            onClicked: {
                switch (widgetData.id || "") {
                case "nightMode": {
                    if (DisplayService.automationAvailable) {
                        DisplayService.toggleNightMode()
                    }
                    break
                }
                case "darkMode": {
                    Theme.toggleLightMode()
                    break
                }
                case "doNotDisturb": {
                    SessionData.setDoNotDisturb(!SessionData.doNotDisturb)
                    break
                }
                case "idleInhibitor": {
                    SessionService.toggleIdleInhibit()
                    break
                }
                }
            }

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData
                widgetIndex: parent.widgetIndex
                showSizeControls: true
                isSlider: false
                onRemoveWidget: (index) => root.removeWidget(index)
                onToggleWidgetSize: (index) => root.toggleWidgetSize(index)
                onMoveWidget: (fromIndex, toIndex) => root.moveWidget(fromIndex, toIndex)
            }
        }
    }

    Component {
        id: smallToggleComponent
        SmallToggleButton {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            property var widgetDef: root.model?.getWidgetForId(widgetData.id || "")
            width: parent.width
            height: 48

            iconName: {
                switch (widgetData.id || "") {
                case "nightMode": return DisplayService.nightModeEnabled ? "nightlight" : "dark_mode"
                case "darkMode": return "contrast"
                case "doNotDisturb": return SessionData.doNotDisturb ? "do_not_disturb_on" : "do_not_disturb_off"
                case "idleInhibitor": return SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
                default: return widgetDef?.icon || "help"
                }
            }

            iconRotation: widgetData.id === "darkMode" && SessionData.isLightMode ? 180 : 0

            isActive: {
                switch (widgetData.id || "") {
                case "nightMode": return DisplayService.nightModeEnabled || false
                case "darkMode": return !SessionData.isLightMode
                case "doNotDisturb": return SessionData.doNotDisturb || false
                case "idleInhibitor": return SessionService.idleInhibited || false
                default: return false
                }
            }

            enabled: (widgetDef?.enabled ?? true) && !root.editMode

            onClicked: {
                switch (widgetData.id || "") {
                case "nightMode": {
                    if (DisplayService.automationAvailable) {
                        DisplayService.toggleNightMode()
                    }
                    break
                }
                case "darkMode": {
                    Theme.toggleLightMode()
                    break
                }
                case "doNotDisturb": {
                    SessionData.setDoNotDisturb(!SessionData.doNotDisturb)
                    break
                }
                case "idleInhibitor": {
                    SessionService.toggleIdleInhibit()
                    break
                }
                }
            }

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData
                widgetIndex: parent.widgetIndex
                showSizeControls: true
                isSlider: false
                onRemoveWidget: (index) => root.removeWidget(index)
                onToggleWidgetSize: (index) => root.toggleWidgetSize(index)
                onMoveWidget: (fromIndex, toIndex) => root.moveWidget(fromIndex, toIndex)
            }
        }
    }
}