import QtQuick
import qs.Common
import qs.Services
import qs.Modules.ControlCenter.Widgets
import qs.Modules.ControlCenter.Components
import "../utils/detailHeight.js" as DetailHeightUtils
import "../utils/layout.js" as LayoutUtils

Column {
    id: root
    readonly property var log: Log.scoped("DragDropGrid")

    property bool editMode: false
    property string expandedSection: ""
    property int expandedWidgetIndex: -1
    property var model: null
    property var expandedWidgetData: null
    property var bluetoothCodecSelector: null
    property bool darkModeTransitionPending: false
    property string screenName: ""
    property string screenModel: ""
    property var parentScreen: null

    signal expandClicked(var widgetData, int globalIndex)
    signal removeWidget(int index)
    signal moveWidget(int fromIndex, int toIndex)
    signal toggleWidgetSize(int index)
    signal collapseRequested
    signal configRequested(int index, var widgetData, var anchor)

    function requestCollapse() {
        collapseRequested();
    }

    spacing: editMode ? Theme.spacingL : Theme.spacingS

    property real maxPopoutHeight: 9999
    property var currentRowWidgets: []
    property real currentRowWidth: 0
    property int expandedRowIndex: -1
    property var colorPickerModal: null
    property var activePluginDetailInstance: null

    readonly property real _maxDetailHeight: {
        const rows = layoutResult.rows;
        let totalRowHeight = 0;
        for (let i = 0; i < rows.length; i++) {
            const sliderOnly = rows[i].every(w => {
                const id = w.id || "";
                return id === "volumeSlider" || id === "brightnessSlider" || id === "inputVolumeSlider";
            });
            totalRowHeight += sliderOnly ? 36 : 60;
        }
        const rowSpacing = Math.max(0, rows.length - 1) * spacing;
        return Math.max(100, maxPopoutHeight - totalRowHeight - rowSpacing);
    }

    readonly property real targetImplicitHeight: {
        if (editMode)
            return editModeGrid.implicitHeight;
        const rows = layoutResult.rows;
        let totalHeight = 0;
        for (let i = 0; i < rows.length; i++) {
            const widgets = rows[i] || [];
            const sliderOnly = widgets.length > 0 && widgets.every(w => {
                const id = w.id || "";
                return id === "volumeSlider" || id === "brightnessSlider" || id === "inputVolumeSlider";
            });
            totalHeight += sliderOnly ? (editMode ? 56 : 36) : 60;
            if (expandedSection !== "" && i === expandedRowIndex)
                totalHeight += detailHeightForSection(expandedSection) + Theme.spacingS;
        }
        totalHeight += Math.max(0, rows.length - 1) * spacing;
        return totalHeight;
    }

    function detailHeightForSection(section) {
        return DetailHeightUtils.detailHeightForSection(section, _maxDetailHeight, activePluginDetailInstance);
    }

    function calculateRowsAndWidgets() {
        return LayoutUtils.calculateRowsAndWidgets(root, expandedSection, expandedWidgetIndex);
    }

    property var layoutResult: {
        const dummy = [expandedSection, expandedWidgetIndex, model?.controlCenterWidgets];
        return calculateRowsAndWidgets();
    }

    onLayoutResultChanged: {
        expandedRowIndex = layoutResult.expandedRowIndex;
    }

    function moveToTop(item) {
        const children = root.children;
        for (var i = 0; i < children.length; i++) {
            if (children[i] === item)
                continue;
            if (children[i].z)
                children[i].z = Math.min(children[i].z, 999);
        }
        item.z = 1000;
    }

    function getCompoundPillIconBlinking(id) {
        if (id === "wifi") return NetworkService.isWifiConnecting;
        if (id === "bluetooth") return BluetoothService.connecting;
        return false;
    }

    function getCompoundPillIconName(id, widgetDef) {
        switch (id) {
        case "wifi": {
            if (NetworkService.wifiToggling) return "sync";
            if (NetworkService.isConnecting && !NetworkService.ethernetConnected) return NetworkService.wifiSignalIcon;
            const status = NetworkService.networkStatus;
            if (status === "ethernet") return "settings_ethernet";
            if (status === "vpn") return NetworkService.ethernetConnected ? "settings_ethernet" : NetworkService.wifiSignalIcon;
            if (status === "wifi") return NetworkService.wifiSignalIcon;
            return "wifi";
        }
        case "bluetooth": {
            return "bluetooth";
        }
        case "audioOutput": {
            if (!AudioService.sink?.audio) return "volume_off";
            let volume = AudioService.sink.audio.volume;
            let muted = AudioService.sink.audio.muted;
            if (muted) return "volume_off";
            if (volume === 0.0) return "volume_mute";
            if (volume <= 0.33) return "volume_down";
            if (volume <= 0.66) return "volume_up";
            return "volume_up";
        }
        case "audioInput": {
            if (!AudioService.source?.audio) return "mic_off";
            return AudioService.source.audio.muted ? "mic_off" : "mic";
        }
        default:
            return widgetDef?.icon || "help";
        }
    }

    function getCompoundPillIsActive(id) {
        switch (id) {
        case "wifi": {
            if (NetworkService.wifiToggling) return false;
            const status = NetworkService.networkStatus;
            if (status === "ethernet") return true;
            if (status === "vpn") return NetworkService.ethernetConnected || NetworkService.wifiConnected;
            if (status === "wifi") return true;
            return NetworkService.wifiEnabled;
        }
        case "bluetooth":
            return !!(BluetoothService.available && BluetoothService.adapter && BluetoothService.adapter.enabled);
        case "audioOutput":
            return !!(AudioService.sink?.audio && !AudioService.sink.audio.muted);
        case "audioInput":
            return !!(AudioService.source?.audio && !AudioService.source.audio.muted);
        default:
            return false;
        }
    }

    function handleCompoundPillToggled(id) {
        switch (id) {
        case "wifi": {
            if (NetworkService.networkStatus !== "ethernet" && !NetworkService.wifiToggling) {
                NetworkService.toggleWifiRadio();
            }
            break;
        }
        case "bluetooth": {
            if (BluetoothService.available && BluetoothService.adapter) {
                BluetoothService.adapter.enabled = !BluetoothService.adapter.enabled;
            }
            break;
        }
        case "audioOutput": {
            if (AudioService.sink && AudioService.sink.audio) {
                AudioService.sink.audio.muted = !AudioService.sink.audio.muted;
            }
            break;
        }
        case "audioInput": {
            if (AudioService.source && AudioService.source.audio) {
                AudioService.source.audio.muted = !AudioService.source.audio.muted;
            }
            break;
        }
        }
    }

    function handleCompoundPillWheelEvent(id, wheelEvent) {
        if (id === "audioOutput") {
            if (!AudioService.sink || !AudioService.sink.audio) return;
            let delta = wheelEvent.angleDelta.y;
            let maxVol = AudioService.sinkMaxVolume;
            let currentVolume = AudioService.sink.audio.volume * 100;
            let newVolume;
            if (delta > 0) newVolume = Math.min(maxVol, currentVolume + 5);
            else newVolume = Math.max(0, currentVolume - 5);
            AudioService.sink.audio.muted = false;
            AudioService.sink.audio.volume = newVolume / 100;
            wheelEvent.accepted = true;
        } else if (id === "audioInput") {
            if (!AudioService.source || !AudioService.source.audio) return;
            let delta = wheelEvent.angleDelta.y;
            let currentVolume = AudioService.source.audio.volume * 100;
            let newVolume;
            if (delta > 0) newVolume = Math.min(100, currentVolume + 5);
            else newVolume = Math.max(0, currentVolume - 5);
            AudioService.source.audio.muted = false;
            AudioService.source.audio.volume = newVolume / 100;
            wheelEvent.accepted = true;
        }
    }

    function componentForWidget(widgetData) {
        const id = widgetData.id || "";
        const widgetWidth = widgetData.width || 50;
        if (id.startsWith("builtin_"))
            return builtinPluginWidgetComponent;
        if (id.startsWith("plugin_"))
            return pluginWidgetComponent;
        switch (id) {
        case "wifi":
        case "bluetooth":
        case "audioOutput":
        case "audioInput":
            return widgetWidth <= 25 ? smallCompoundComponent : compoundPillComponent;
        case "volumeSlider":
            return audioSliderComponent;
        case "brightnessSlider":
            return brightnessSliderComponent;
        case "inputVolumeSlider":
            return inputAudioSliderComponent;
        case "battery":
            return widgetWidth <= 25 ? smallBatteryComponent : batteryPillComponent;
        case "diskUsage":
            return widgetWidth <= 25 ? smallDiskUsageComponent : diskUsagePillComponent;
        case "colorPicker":
            return widgetWidth <= 25 ? smallColorPickerComponent : colorPickerPillComponent;
        case "doNotDisturb":
            return widgetWidth <= 25 ? smallToggleComponent : dndPillComponent;
        default:
            return widgetWidth <= 25 ? smallToggleComponent : toggleButtonComponent;
        }
    }

    Repeater {
        model: root.editMode ? [] : root.layoutResult.rows

        Column {
            width: root.width
            spacing: 0
            property int rowIndex: index
            property var rowWidgets: modelData
            property bool isSliderOnlyRow: {
                const widgets = rowWidgets || [];
                if (widgets.length === 0)
                    return false;
                return widgets.every(w => w.id === "volumeSlider" || w.id === "brightnessSlider" || w.id === "inputVolumeSlider");
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
                            const widgets = SettingsData.controlCenterWidgets || [];
                            for (var i = 0; i < widgets.length; i++) {
                                if (widgets[i].id === modelData.id) {
                                    if (modelData.id === "diskUsage" || modelData.id === "brightnessSlider") {
                                        if (widgets[i].instanceId === modelData.instanceId) {
                                            return i;
                                        }
                                    } else {
                                        return i;
                                    }
                                }
                            }
                            return -1;
                        }
                        property int widgetWidth: modelData.width || 50
                        width: {
                            const baseWidth = root.width;
                            const spacing = Theme.spacingS;
                            if (widgetWidth <= 25) {
                                return (baseWidth - spacing * 3) / 4;
                            } else if (widgetWidth <= 50) {
                                return (baseWidth - spacing) / 2;
                            } else if (widgetWidth <= 75) {
                                return (baseWidth - spacing * 2) * 0.75;
                            } else {
                                return baseWidth;
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
                            const id = modelData.id || "";
                            return id === "volumeSlider" || id === "brightnessSlider" || id === "inputVolumeSlider";
                        }

                        widgetComponent: root.componentForWidget(modelData)

                        onWidgetMoved: (fromIndex, toIndex) => root.moveWidget(fromIndex, toIndex)
                        onRemoveWidget: index => root.removeWidget(index)
                        onToggleWidgetSize: index => root.toggleWidgetSize(index)
                        onConfigRequested: (idx, data, anchor) => root.configRequested(idx, data, anchor)
                    }
                }
            }

            DetailHost {
                id: detailHost
                width: parent.width
                height: active ? (root.detailHeightForSection(root.expandedSection) + Theme.spacingS) : 0
                clip: true
                property string retainedSection: ""
                property var retainedWidgetData: null
                property bool active: {
                    if (root.expandedSection === "")
                        return false;

                    if (root.expandedSection.startsWith("diskUsage_") && root.expandedWidgetData) {
                        const expandedInstanceId = root.expandedWidgetData.instanceId;
                        return rowWidgets.some(w => w.id === "diskUsage" && w.instanceId === expandedInstanceId);
                    }

                    if (root.expandedSection.startsWith("brightnessSlider_") && root.expandedWidgetData) {
                        const expandedInstanceId = root.expandedWidgetData.instanceId;
                        return rowWidgets.some(w => w.id === "brightnessSlider" && w.instanceId === expandedInstanceId);
                    }

                    return rowIndex === root.expandedRowIndex;
                }
                visible: active || height > 0.5
                expandedSection: active ? root.expandedSection : retainedSection
                expandedWidgetData: active ? root.expandedWidgetData : retainedWidgetData
                bluetoothCodecSelector: root.bluetoothCodecSelector
                widgetModel: root.model
                collapseCallback: root.requestCollapse
                screenName: root.screenName
                screenModel: root.screenModel

                function retainActiveDetail() {
                    if (!active || !root.expandedSection)
                        return;
                    retainedSection = root.expandedSection;
                    retainedWidgetData = root.expandedWidgetData;
                }

                function syncActivePluginDetail() {
                    if (active) {
                        root.activePluginDetailInstance = pluginDetailInstance;
                    } else if (root.activePluginDetailInstance === pluginDetailInstance) {
                        root.activePluginDetailInstance = null;
                    }
                }

                onActiveChanged: {
                    retainActiveDetail();
                    syncActivePluginDetail();
                }
                onPluginDetailInstanceChanged: syncActivePluginDetail()
                onHeightChanged: {
                    if (!active && height <= 0.5) {
                        retainedSection = "";
                        retainedWidgetData = null;
                    }
                }

                Connections {
                    target: root
                    function onExpandedSectionChanged() {
                        detailHost.retainActiveDetail();
                    }
                    function onExpandedWidgetDataChanged() {
                        detailHost.retainActiveDetail();
                    }
                }

                Behavior on height {
                    enabled: true
                    NumberAnimation {
                        duration: Theme.variantDuration(Theme.popoutAnimationDuration, detailHost.active)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: detailHost.active ? Theme.variantPopoutEnterCurve : Theme.variantPopoutExitCurve
                    }
                }
            }
        }
    }

    EditModeGrid {
        id: editModeGrid
        width: root.width
        visible: root.editMode
        active: root.editMode
        model: root.model
        componentProvider: root
        onRemoveWidget: index => root.removeWidget(index)
        onToggleWidgetSize: index => root.toggleWidgetSize(index)
        onConfigRequested: (idx, data, anchor) => root.configRequested(idx, data, anchor)
    }

    Component {
        id: errorPillComponent
        ErrorPill {
            property var widgetData: parent.widgetData || {}
            width: parent.width
            height: 60
            primaryMessage: {
                if (!DMSService.dmsAvailable) {
                    return I18n.tr("DMS_SOCKET not available");
                }
                return I18n.tr("NM not supported");
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
            iconBlinking: root.getCompoundPillIconBlinking(widgetData.id || "")
            iconName: root.getCompoundPillIconName(widgetData.id || "", widgetDef)
            primaryText: {
                switch (widgetData.id || "") {
                case "wifi":
                    {
                        if (NetworkService.wifiToggling)
                            return NetworkService.wifiEnabled ? I18n.tr("Disabling WiFi...", "network status") : I18n.tr("Enabling WiFi...", "network status");
                        if (NetworkService.isConnecting && !NetworkService.ethernetConnected)
                            return NetworkService.connectingSSID || I18n.tr("Connecting...", "network status");

                        const status = NetworkService.networkStatus;
                        if (status === "ethernet")
                            return I18n.tr("Ethernet", "network status");
                        if (status === "vpn") {
                            if (NetworkService.ethernetConnected)
                                return I18n.tr("Ethernet", "network status");
                            if (NetworkService.wifiConnected && NetworkService.currentWifiSSID)
                                return NetworkService.currentWifiSSID;
                        }
                        if (status === "wifi" && NetworkService.currentWifiSSID)
                            return NetworkService.currentWifiSSID;
                        if (NetworkService.wifiEnabled)
                            return I18n.tr("Not connected", "network status");
                        return I18n.tr("WiFi off", "network status");
                    }
                case "bluetooth":
                    {
                        if (!BluetoothService.available)
                            return I18n.tr("Bluetooth", "bluetooth status");
                        if (!BluetoothService.adapter)
                            return I18n.tr("No adapter", "bluetooth status");
                        if (!BluetoothService.adapter.enabled)
                            return I18n.tr("Disabled", "bluetooth status");
                        return I18n.tr("Enabled", "bluetooth status");
                    }
                case "audioOutput":
                    return AudioService.sink?.description || I18n.tr("No output device", "audio status");
                case "audioInput":
                    return AudioService.source?.description || I18n.tr("No input device", "audio status");
                default:
                    return widgetDef?.text || I18n.tr("Unknown", "widget status");
                }
            }
            secondaryText: {
                switch (widgetData.id || "") {
                case "wifi":
                    {
                        if (NetworkService.wifiToggling)
                            return I18n.tr("Please wait...", "network status");
                        if (NetworkService.isConnecting && !NetworkService.ethernetConnected)
                            return I18n.tr("Connecting...", "network status");

                        const status = NetworkService.networkStatus;
                        if (status === "ethernet")
                            return I18n.tr("Connected", "network status");
                        if (status === "vpn") {
                            if (NetworkService.ethernetConnected)
                                return I18n.tr("Connected", "network status");
                            if (NetworkService.wifiConnected)
                                return NetworkService.wifiSignalStrength > 0 ? NetworkService.wifiSignalStrength + "%" : I18n.tr("Connected", "network status");
                        }
                        if (status === "wifi")
                            return NetworkService.wifiSignalStrength > 0 ? NetworkService.wifiSignalStrength + "%" : I18n.tr("Connected", "network status");
                        if (NetworkService.wifiEnabled)
                            return I18n.tr("Select network", "network status");
                        return "";
                    }
                case "bluetooth":
                    {
                        if (!BluetoothService.available)
                            return I18n.tr("No adapters", "bluetooth status");
                        if (!BluetoothService.adapter || !BluetoothService.adapter.enabled)
                            return I18n.tr("Off", "bluetooth status");
                        if (BluetoothService.connecting)
                            return I18n.tr("Connecting...", "bluetooth status");
                        const primaryDevice = (() => {
                                if (!BluetoothService.adapter || !BluetoothService.adapter.devices)
                                    return null;
                                let devices = [...BluetoothService.adapter.devices.values.filter(dev => dev && (dev.paired || dev.trusted))];
                                for (let device of devices) {
                                    if (device && device.connected)
                                        return device;
                                }
                                return null;
                            })();
                        if (primaryDevice)
                            return primaryDevice.name || primaryDevice.alias || primaryDevice.deviceName || I18n.tr("Connected Device", "bluetooth status");
                        return I18n.tr("No devices", "bluetooth status");
                    }
                case "audioOutput":
                    {
                        if (!AudioService.sink?.audio)
                            return I18n.tr("Select device", "audio status");
                        if (AudioService.sink.audio.muted)
                            return I18n.tr("Muted", "audio status");
                        const volume = AudioService.sink.audio.volume;
                        if (typeof volume !== "number" || isNaN(volume))
                            return "0%";
                        return Math.round(volume * 100) + "%";
                    }
                case "audioInput":
                    {
                        if (!AudioService.source?.audio)
                            return I18n.tr("Select device", "audio status");
                        if (AudioService.source.audio.muted)
                            return I18n.tr("Muted", "audio status");
                        const volume = AudioService.source.audio.volume;
                        if (typeof volume !== "number" || isNaN(volume))
                            return "0%";
                        return Math.round(volume * 100) + "%";
                    }
                default:
                    return widgetDef?.description || "";
                }
            }
            isActive: root.getCompoundPillIsActive(widgetData.id || "")
            enabled: widgetDef?.enabled ?? true
            onToggled: {
                if (root.editMode)
                    return;
                root.handleCompoundPillToggled(widgetData.id || "");
            }
            onExpandClicked: {
                if (root.editMode)
                    return;
                root.expandClicked(widgetData, widgetIndex);
            }
            onWheelEvent: function (wheelEvent) {
                if (root.editMode)
                    return;
                root.handleCompoundPillWheelEvent(widgetData.id || "", wheelEvent);
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
                sliderTrackColor: Theme.ccSliderTrackColor
                sliderTrackOpacity: Theme.ccSliderTrackOpacity
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
                screenName: root.screenName
                parentScreen: root.parentScreen
                sliderTrackColor: Theme.ccSliderTrackColor
                sliderTrackOpacity: Theme.ccSliderTrackOpacity

                onIconClicked: {
                    if (!root.editMode && DisplayService.devices && DisplayService.devices.length > 1) {
                        root.expandClicked(widgetData, widgetIndex);
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
                sliderTrackColor: Theme.ccSliderTrackColor
                sliderTrackOpacity: Theme.ccSliderTrackOpacity
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
                    root.expandClicked(widgetData, widgetIndex);
                }
            }
        }
    }

    Component {
        id: dndPillComponent
        DndPill {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            width: parent.width
            height: 60

            onExpandClicked: {
                if (!root.editMode) {
                    root.expandClicked(widgetData, widgetIndex);
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
                    root.expandClicked(widgetData, widgetIndex);
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
                    return DisplayService.nightModeEnabled ? "nightlight" : "dark_mode";
                case "darkMode":
                    return "contrast";
                case "idleInhibitor":
                    return "motion_sensor_active";
                default:
                    return "help";
                }
            }

            text: {
                switch (widgetData.id || "") {
                case "nightMode":
                    return I18n.tr("Night Mode");
                case "darkMode":
                    return I18n.tr("Dark Mode");
                case "idleInhibitor":
                    return SessionService.idleInhibited ? I18n.tr("Keeping Awake") : I18n.tr("Keep Awake");
                default:
                    return I18n.tr("Unknown", "widget status");
                }
            }

            iconRotation: {
                if (widgetData.id !== "darkMode")
                    return 0;
                if (darkModeTransitionPending) {
                    return SessionData.isLightMode ? 180 : 0;
                }
                return SessionData.isLightMode ? 180 : 0;
            }

            isActive: {
                switch (widgetData.id || "") {
                case "nightMode":
                    return DisplayService.nightModeEnabled || false;
                case "darkMode":
                    return !SessionData.isLightMode;
                case "idleInhibitor":
                    return SessionService.idleInhibited || false;
                default:
                    return false;
                }
            }

            enabled: !root.editMode

            onClicked: {
                if (root.editMode)
                    return;
                switch (widgetData.id || "") {
                case "nightMode":
                    {
                        if (DisplayService.automationAvailable)
                            DisplayService.toggleNightMode();
                        break;
                    }
                case "darkMode":
                    {
                        const newMode = !SessionData.isLightMode;
                        Theme.screenTransition();
                        Theme.setLightMode(newMode);
                        break;
                    }
                case "idleInhibitor":
                    {
                        SessionService.toggleIdleInhibit();
                        break;
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
                    return DisplayService.nightModeEnabled ? "nightlight" : "dark_mode";
                case "darkMode":
                    return "contrast";
                case "doNotDisturb":
                    return "do_not_disturb_on";
                case "idleInhibitor":
                    return "motion_sensor_active";
                default:
                    return "help";
                }
            }

            iconRotation: {
                if (widgetData.id !== "darkMode")
                    return 0;
                if (darkModeTransitionPending) {
                    return SessionData.isLightMode ? 180 : 0;
                }
                return SessionData.isLightMode ? 180 : 0;
            }

            isActive: {
                switch (widgetData.id || "") {
                case "nightMode":
                    return DisplayService.nightModeEnabled || false;
                case "darkMode":
                    return !SessionData.isLightMode;
                case "doNotDisturb":
                    return SessionData.doNotDisturb || false;
                case "idleInhibitor":
                    return SessionService.idleInhibited || false;
                default:
                    return false;
                }
            }

            enabled: !root.editMode

            onClicked: {
                if (root.editMode)
                    return;
                switch (widgetData.id || "") {
                case "nightMode":
                    {
                        if (DisplayService.automationAvailable)
                            DisplayService.toggleNightMode();
                        break;
                    }
                case "darkMode":
                    {
                        const newMode = !SessionData.isLightMode;
                        Theme.screenTransition();
                        Theme.setLightMode(newMode);
                        break;
                    }
                case "doNotDisturb":
                    {
                        SessionData.setDoNotDisturb(!SessionData.doNotDisturb);
                        break;
                    }
                case "idleInhibitor":
                    {
                        SessionService.toggleIdleInhibit();
                        break;
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
            showMountPath: widgetData.showMountPath !== undefined ? widgetData.showMountPath : true

            onExpandClicked: {
                if (!root.editMode) {
                    root.expandClicked(widgetData, widgetIndex);
                }
            }
        }
    }

    Component {
        id: smallDiskUsageComponent
        SmallDiskUsageButton {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            width: parent.width
            height: 48

            mountPath: widgetData.mountPath || "/"
            instanceId: widgetData.instanceId || ""
            showMountPath: widgetData.showMountPath !== undefined ? widgetData.showMountPath : true

            onClicked: {
                if (!root.editMode) {
                    root.expandClicked(widgetData, widgetIndex);
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
                const id = widgetData.id || "";
                if (id === "builtin_vpn") {
                    if (root.model?.vpnLoader) {
                        root.model.vpnLoader.active = true;
                    }
                    builtinInstance = Qt.binding(() => root.model?.vpnBuiltinInstance);
                }
                if (id === "builtin_cups") {
                    if (root.model?.cupsLoader) {
                        root.model.cupsLoader.active = true;
                    }
                    builtinInstance = Qt.binding(() => root.model?.cupsBuiltinInstance);
                }
                if (id === "builtin_tailscale") {
                    if (root.model?.tailscaleLoader) {
                        root.model.tailscaleLoader.active = true;
                    }
                    builtinInstance = Qt.binding(() => root.model?.tailscaleBuiltinInstance);
                }
                if (id === "builtin_display_profiles") {
                    if (root.model?.displayProfilesLoader) {
                        root.model.displayProfilesLoader.active = true;
                    }
                    builtinInstance = Qt.binding(() => root.model?.displayProfilesBuiltinInstance);
                }
            }

            sourceComponent: {
                if (!builtinInstance)
                    return null;

                const hasDetail = builtinInstance.ccDetailContent !== null;

                if (widgetWidth <= 25) {
                    return builtinSmallToggleComponent;
                } else if (hasDetail) {
                    return builtinCompoundPillComponent;
                } else {
                    return builtinToggleComponent;
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
                    return;
                if (builtinInstance) {
                    builtinInstance.ccWidgetToggled();
                }
            }

            onExpandClicked: {
                if (root.editMode)
                    return;
                if (builtinInstance) {
                    builtinInstance.ccWidgetExpanded();
                }
                root.expandClicked(widgetData, widgetIndex);
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
                    return;
                if (builtinInstance) {
                    builtinInstance.ccWidgetToggled();
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
                    return;
                if (builtinInstance) {
                    builtinInstance.ccWidgetToggled();
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
                    return null;

                const hasDetail = pluginInstance.ccDetailContent !== null;

                if (widgetWidth <= 25) {
                    return pluginSmallToggleComponent;
                } else if (hasDetail) {
                    return pluginCompoundPillComponent;
                } else {
                    return pluginToggleComponent;
                }
            }

            function tryCreatePluginInstance() {
                const pluginComponent = PluginService.pluginWidgetComponents[pluginId];
                if (!pluginComponent)
                    return false;
                try {
                    const instance = pluginComponent.createObject(null, {
                        "pluginId": pluginId,
                        "pluginService": PluginService,
                        "visible": false,
                        "width": 0,
                        "height": 0
                    });
                    if (instance) {
                        pluginInstance = instance;
                        return true;
                    }
                } catch (e) {
                    log.warn("stale plugin component for", pluginId, "- reloading");
                    PluginService.reloadPlugin(pluginId);
                }
                return false;
            }

            Component.onCompleted: {
                Qt.callLater(() => tryCreatePluginInstance());
            }

            Connections {
                target: PluginService
                function onPluginDataChanged(changedPluginId) {
                    if (changedPluginId === pluginId && pluginInstance) {
                        pluginInstance.loadPluginData();
                    }
                }
                function onPluginLoaded(loadedPluginId) {
                    if (loadedPluginId !== pluginId || pluginInstance)
                        return;
                    Qt.callLater(() => tryCreatePluginInstance());
                }
            }

            Component.onDestruction: {
                if (pluginInstance) {
                    pluginInstance.destroy();
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
                    return;
                if (pluginInstance) {
                    pluginInstance.ccWidgetToggled();
                }
            }

            onExpandClicked: {
                if (root.editMode)
                    return;
                if (pluginInstance) {
                    pluginInstance.ccWidgetExpanded();
                }
                root.expandClicked(widgetData, widgetIndex);
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
                    return;
                if (pluginInstance) {
                    pluginInstance.ccWidgetToggled();
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
                    return;
                if (pluginInstance && pluginInstance.ccDetailContent) {
                    root.expandClicked(widgetData, widgetIndex);
                } else if (pluginInstance) {
                    pluginInstance.ccWidgetToggled();
                }
            }
        }
    }

    Component {
        id: smallCompoundComponent
        SmallCompoundButton {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            property var widgetDef: root.model?.getWidgetForId(widgetData.id || "")
            width: parent.width
            height: 48
            iconBlinking: root.getCompoundPillIconBlinking(widgetData.id || "")
            iconName: root.getCompoundPillIconName(widgetData.id || "", widgetDef)
            isActive: root.getCompoundPillIsActive(widgetData.id || "")
            enabled: (widgetDef?.enabled ?? true) && !root.editMode
            onToggled: {
                if (root.editMode) return;
                root.handleCompoundPillToggled(widgetData.id || "");
            }
            onExpandClicked: {
                if (root.editMode) return;
                root.expandClicked(widgetData, widgetIndex);
            }
            onWheelEvent: function(wheelEvent) {
                if (root.editMode) return;
                root.handleCompoundPillWheelEvent(widgetData.id || "", wheelEvent);
            }
        }
    }

    Component {
        id: smallColorPickerComponent
        SmallColorPickerButton {
            property var widgetData: parent.widgetData || {}
            property int widgetIndex: parent.widgetIndex || 0
            width: parent.width
            height: 48
            colorPickerModal: root.colorPickerModal
            onClicked: {
                if (root.editMode) return;
                if (root.colorPickerModal)
                    root.colorPickerModal.show();
            }
        }
    }
}
