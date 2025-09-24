import QtQuick
import QtQuick.Controls
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
                if (widgets.length === 0)
                    return false
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
                        id: widgetContainer

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
                        property bool isDragging: false
                        property bool dragEnabled: false
                        property real originalX: x
                        property real originalY: y

                        // Store original position when starting to drag
                        onXChanged: if (!isDragging)
                                        originalX = x
                        onYChanged: if (!isDragging)
                                        originalY = y

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

                        // Add smooth animations for position changes during reordering
                        Behavior on x {
                            enabled: !isDragging && root.editMode
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on y {
                            enabled: !isDragging && root.editMode
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutCubic
                            }
                        }

                        Drag.active: dragMouseArea.drag.active
                        Drag.keys: ["widget-reorder"]
                        Drag.mimeData: {
                            "application/x-widget-index": globalWidgetIndex.toString()
                        }
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2
                        Drag.source: widgetContainer

                        MouseArea {
                            id: dragMouseArea
                            anchors.fill: parent
                            enabled: root.editMode

                            drag.target: widgetContainer
                            drag.axis: Drag.XAndYAxis

                            // Constrain drag to the grid area
                            drag.minimumX: -widgetContainer.width
                            drag.maximumX: root.width
                            drag.minimumY: -widgetContainer.height
                            drag.maximumY: root.height * 3

                            onPressed: function (mouse) {
                                // Store current position before starting drag
                                originalX = widgetContainer.x
                                originalY = widgetContainer.y
                                isDragging = true
                                console.log("Starting drag for widget index:", globalWidgetIndex)
                                widgetContainer.Drag.start()
                                mouse.accepted = true
                            }

                            onReleased: {
                                if (isDragging) {
                                    console.log("Dropping widget at position:", widgetContainer.x, widgetContainer.y)
                                    const dropped = widgetContainer.Drag.drop()
                                    isDragging = false

                                    if (dropped !== Qt.IgnoreAction) {
                                        console.log("Widget dropped successfully")
                                    } else {
                                        console.log("Widget dropped in empty space, snapping back")
                                    }

                                    // Always snap back to original position smoothly
                                    Qt.callLater(() => {
                                                     snapBackXAnimation.to = originalX
                                                     snapBackYAnimation.to = originalY
                                                     snapBackXAnimation.restart()
                                                     snapBackYAnimation.restart()
                                                 })
                                }
                            }
                        }

                        NumberAnimation {
                            id: snapBackXAnimation
                            target: widgetContainer
                            property: "x"
                            duration: 350
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            id: snapBackYAnimation
                            target: widgetContainer
                            property: "y"
                            duration: 350
                            easing.type: Easing.OutCubic
                        }

                        states: State {
                            when: dragMouseArea.drag.active
                            PropertyChanges {
                                target: widgetContainer
                                z: 1000
                                scale: 1.1
                                opacity: 0.8
                            }
                        }

                        transitions: Transition {
                            NumberAnimation {
                                properties: "scale,opacity"
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }

                        DropArea {
                            anchors.fill: parent
                            anchors.margins: -Theme.spacingXS
                            keys: ["widget-reorder"]

                            property int lastMoveTime: 0

                            onEntered: function (drag) {
                                console.log("DropArea entered, edit mode:", root.editMode, "mimeData:", drag.mimeData, "source:", drag.source)
                                if (root.editMode) {
                                    // Throttle moves to prevent rapid-fire reordering
                                    const currentTime = Date.now()
                                    if (currentTime - lastMoveTime < 150) {
                                        console.log("Throttling move operation")
                                        return
                                    }
                                    lastMoveTime = currentTime

                                    // Try to get source index from mimeData first
                                    let sourceIndex = -1
                                    if (drag.mimeData && "application/x-widget-index" in drag.mimeData) {
                                        const sourceIndexStr = drag.mimeData["application/x-widget-index"]
                                        sourceIndex = parseInt(sourceIndexStr)
                                        console.log("Source index from mimeData:", sourceIndex)
                                    } else if (drag.source) {
                                        // Fallback: try to get from the drag source directly
                                        if (drag.source.globalWidgetIndex !== undefined) {
                                            sourceIndex = drag.source.globalWidgetIndex
                                            console.log("Source index from drag.source.globalWidgetIndex:", sourceIndex)
                                        } else {
                                            // Last resort: try to find by widget data
                                            const widgets = SettingsData.controlCenterWidgets || []
                                            for (var i = 0; i < widgets.length; i++) {
                                                if (drag.source.widgetData && drag.source.widgetData.id === widgets[i].id) {
                                                    sourceIndex = i
                                                    console.log("Source index from widget data match:", sourceIndex)
                                                    break
                                                }
                                            }
                                        }
                                    }

                                    const targetIndex = globalWidgetIndex
                                    console.log("Moving widget from", sourceIndex, "to", targetIndex)
                                    if (sourceIndex >= 0 && sourceIndex !== targetIndex && targetIndex >= 0) {
                                        root.moveWidget(sourceIndex, targetIndex)
                                    }
                                }
                            }

                            onDropped: function (drop) {
                                console.log("Widget dropped in DropArea successfully")
                                drop.accept(Qt.MoveAction)
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                                radius: Theme.cornerRadius
                                visible: parent.containsDrag && root.editMode
                                border.color: Theme.primary
                                border.width: 2
                            }
                        }

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
                case "wifi":
                {
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
                case "bluetooth":
                {
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
                case "bluetooth":
                {
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
                case "bluetooth":
                {
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
                case "audioOutput":
                {
                    if (!AudioService.sink) {
                        return "Select device"
                    }
                    if (AudioService.sink.audio.muted) {
                        return "Muted"
                    }
                    return Math.round(AudioService.sink.audio.volume * 100) + "%"
                }
                case "audioInput":
                {
                    if (!AudioService.source) {
                        return "Select device"
                    }
                    if (AudioService.source.audio.muted) {
                        return "Muted"
                    }
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
            enabled: (widgetDef?.enabled ?? true) && !root.editMode
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

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData
                widgetIndex: parent.widgetIndex
                showSizeControls: true
                isSlider: false
                onRemoveWidget: index => root.removeWidget(index)
                onToggleWidgetSize: index => root.toggleWidgetSize(index)
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
                enabled: !root.editMode
                property color sliderTrackColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.60)
            }

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData
                widgetIndex: parent.widgetIndex
                showSizeControls: true
                isSlider: true
                onRemoveWidget: index => root.removeWidget(index)
                onToggleWidgetSize: index => root.toggleWidgetSize(index)
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
                enabled: !root.editMode
                property color sliderTrackColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.60)
            }

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData
                widgetIndex: parent.widgetIndex
                showSizeControls: true
                isSlider: true
                onRemoveWidget: index => root.removeWidget(index)
                onToggleWidgetSize: index => root.toggleWidgetSize(index)
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
                enabled: !root.editMode
                property color sliderTrackColor: Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, Theme.getContentBackgroundAlpha() * 0.60)
            }

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData
                widgetIndex: parent.widgetIndex
                showSizeControls: true
                isSlider: true
                onRemoveWidget: index => root.removeWidget(index)
                onToggleWidgetSize: index => root.toggleWidgetSize(index)
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
            enabled: !root.editMode
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
                onRemoveWidget: index => root.removeWidget(index)
                onToggleWidgetSize: index => root.toggleWidgetSize(index)
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

            enabled: !root.editMode
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
                onRemoveWidget: index => root.removeWidget(index)
                onToggleWidgetSize: index => root.toggleWidgetSize(index)
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
                case "nightMode":
                    return DisplayService.nightModeEnabled ? "nightlight" : "dark_mode"
                case "darkMode":
                    return "contrast"
                case "doNotDisturb":
                    return SessionData.doNotDisturb ? "do_not_disturb_on" : "do_not_disturb_off"
                case "idleInhibitor":
                    return SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
                default:
                    return widgetDef?.icon || "help"
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
                    return widgetDef?.text || "Unknown"
                }
            }

            secondaryText: ""

            iconRotation: widgetData.id === "darkMode" && SessionData.isLightMode ? 180 : 0

            isActive: {
                switch (widgetData.id || "") {
                case "nightMode":
                    return DisplayService.nightModeEnabled || false
                case "darkMode":
                    return !SessionData.isLightMode
                case "doNotDisturb":
                    return SessionData.doNotDisturb || false
                case "idleInhibitor":
                    return SessionService.idleInhibited || false
                default:
                    return false
                }
            }

            enabled: (widgetDef?.enabled ?? true) && !root.editMode

            onClicked: {
                switch (widgetData.id || "") {
                case "nightMode":
                {
                    if (DisplayService.automationAvailable) {
                        DisplayService.toggleNightMode()
                    }
                    break
                }
                case "darkMode":
                {
                    Theme.toggleLightMode()
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

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData
                widgetIndex: parent.widgetIndex
                showSizeControls: true
                isSlider: false
                onRemoveWidget: index => root.removeWidget(index)
                onToggleWidgetSize: index => root.toggleWidgetSize(index)
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
                case "nightMode":
                    return DisplayService.nightModeEnabled ? "nightlight" : "dark_mode"
                case "darkMode":
                    return "contrast"
                case "doNotDisturb":
                    return SessionData.doNotDisturb ? "do_not_disturb_on" : "do_not_disturb_off"
                case "idleInhibitor":
                    return SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
                default:
                    return widgetDef?.icon || "help"
                }
            }

            iconRotation: widgetData.id === "darkMode" && SessionData.isLightMode ? 180 : 0

            isActive: {
                switch (widgetData.id || "") {
                case "nightMode":
                    return DisplayService.nightModeEnabled || false
                case "darkMode":
                    return !SessionData.isLightMode
                case "doNotDisturb":
                    return SessionData.doNotDisturb || false
                case "idleInhibitor":
                    return SessionService.idleInhibited || false
                default:
                    return false
                }
            }

            enabled: (widgetDef?.enabled ?? true) && !root.editMode

            onClicked: {
                switch (widgetData.id || "") {
                case "nightMode":
                {
                    if (DisplayService.automationAvailable) {
                        DisplayService.toggleNightMode()
                    }
                    break
                }
                case "darkMode":
                {
                    Theme.toggleLightMode()
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

            EditModeOverlay {
                anchors.fill: parent
                editMode: root.editMode
                widgetData: parent.widgetData
                widgetIndex: parent.widgetIndex
                showSizeControls: true
                isSlider: false
                onRemoveWidget: index => root.removeWidget(index)
                onToggleWidgetSize: index => root.toggleWidgetSize(index)
            }
        }
    }
}
