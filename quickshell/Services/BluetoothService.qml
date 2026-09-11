pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property var log: Log.scoped("BluetoothService")
    readonly property var adapters: Bluetooth.adapters?.values ?? []
    readonly property BluetoothAdapter adapter: adapters.find(a => a.dbusPath === SessionData.bluetoothAdapterOverride) ?? Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: (adapter && adapter.enabled) ?? false
    readonly property bool discovering: (adapter && adapter.discovering) ?? false
    readonly property bool dbusBridgeAvailable: DMSService.isConnected && DMSService.capabilities.includes("dbus")
    readonly property bool bluetoothBridgeAvailable: DMSService.isConnected && DMSService.capabilities.includes("bluetooth")
    property bool wpexecAvailable: false
    property bool wpexecChecked: false
    property var pendingCodecActions: []
    property bool _codecSignalsSubscribed: false
    readonly property string bluezService: "org.bluez"
    readonly property string mediaTransportIface: "org.bluez.MediaTransport1"
    readonly property string mediaEndpointIface: "org.bluez.MediaEndpoint1"
    readonly property string objectManagerIface: "org.freedesktop.DBus.ObjectManager"
    readonly property string propertiesIface: "org.freedesktop.DBus.Properties"
    readonly property string cardProfileScript: Quickshell.shellDir + "/scripts/bluez-card-profile.lua"
    readonly property bool codecControlAvailable: wpexecChecked && wpexecAvailable
    readonly property var devices: adapter ? adapter.devices : null
    readonly property bool enhancedPairingAvailable: DMSService.dmsAvailable && DMSService.apiVersion >= 9 && DMSService.capabilities.includes("bluetooth")
    readonly property bool connected: {
        if (!adapter || !adapter.devices) {
            return false;
        }

        let isConnected = false;
        adapter.devices.values.forEach(dev => {
            if (dev.connected)
                isConnected = true;
        });
        return isConnected;
    }
    readonly property bool connecting: {
        if (!adapter || !adapter.devices) {
            return false;
        }

        let busy = false;
        adapter.devices.values.forEach(dev => {
            if (!dev)
                return;
            if (dev.pairing || dev.state === BluetoothDeviceState.Connecting)
                busy = true;
        });
        return busy;
    }
    readonly property var pairedDevices: {
        if (!adapter || !adapter.devices) {
            return [];
        }

        return adapter.devices.values.filter(dev => {
            return dev && (dev.paired || dev.trusted);
        });
    }
    readonly property var allDevicesWithBattery: {
        if (!adapter || !adapter.devices) {
            return [];
        }

        return adapter.devices.values.filter(dev => {
            return dev && dev.batteryAvailable && dev.battery > 0;
        });
    }

    Component.onCompleted: {
        detectWpexecProcess.running = true;
        maybeSubscribeCodecSignals();
    }

    function setBluetoothEnabled(enabled) {
        if (bluetoothBridgeAvailable) {
            DMSService.sendRequest("bluetooth.setPowered", {
                "powered": enabled,
                "adapter": adapter?.dbusPath ?? ""
            }, response => {
                if (response.error)
                    log.warn("Failed to set Bluetooth powered state:", response.error);
            });
            return;
        }

        if (adapter)
            adapter.enabled = enabled;
    }

    function toggleBluetooth() {
        if (bluetoothBridgeAvailable && DMSService.apiVersion >= 33) {
            DMSService.sendRequest("bluetooth.togglePowered", {
                "adapter": adapter?.dbusPath ?? ""
            }, response => {
                if (response.error)
                    log.warn("Failed to toggle Bluetooth powered state:", response.error);
            });
            return;
        }

        setBluetoothEnabled(!enabled);
    }

    Connections {
        target: DMSService

        function onConnectionStateChanged() {
            root._codecSignalsSubscribed = false;
            root.maybeSubscribeCodecSignals();
        }

        function onCapabilitiesReceived() {
            root.maybeSubscribeCodecSignals();
        }

        function onDbusSignalReceived(subscriptionId, data) {
            root.handleCodecDbusSignal(data);
        }
    }

    function whenCodecBackendReady(action) {
        if (wpexecChecked) {
            action();
            return;
        }

        const actions = pendingCodecActions.slice();
        actions.push(action);
        pendingCodecActions = actions;
        if (!detectWpexecProcess.running)
            detectWpexecProcess.running = true;
    }

    function maybeSubscribeCodecSignals() {
        if (!dbusBridgeAvailable || _codecSignalsSubscribed)
            return;
        _codecSignalsSubscribed = true;
        DMSService.dbusSubscribe("system", bluezService, "", objectManagerIface, "InterfacesAdded", null);
        DMSService.dbusSubscribe("system", bluezService, "", objectManagerIface, "InterfacesRemoved", null);
        DMSService.dbusSubscribe("system", bluezService, "", propertiesIface, "PropertiesChanged", null);
    }

    function handleCodecDbusSignal(data) {
        if (!data?.path || !data.path.includes("/dev_"))
            return;

        const member = data.member || "";
        if (member !== "InterfacesAdded" && member !== "InterfacesRemoved" && member !== "PropertiesChanged")
            return;

        if (member === "PropertiesChanged" && data.body?.[0] !== mediaTransportIface && data.body?.[0] !== mediaEndpointIface)
            return;

        const device = deviceForDbusPath(data.path);
        if (device && device.connected && isAudioDevice(device))
            Qt.callLater(() => root.refreshDeviceCodec(device));
    }

    function deviceForDbusPath(path) {
        if (!path || !adapter?.devices)
            return null;
        const match = path.match(/\/dev_([0-9A-Fa-f_]+)/);
        if (!match)
            return null;
        const address = match[1].replace(/_/g, ":").toUpperCase();
        return adapter.devices.values.find(d => (d.address || "").toUpperCase() === address) ?? null;
    }

    function bytesFromDbusValue(value) {
        if (!value)
            return [];
        if (Array.isArray(value))
            return value.map(v => Number(v) & 0xff);
        if (typeof value === "string") {
            try {
                const decoded = Qt.atob(value);
                if (decoded instanceof ArrayBuffer) {
                    return Array.from(new Uint8Array(decoded));
                }
                const bytes = [];
                for (let i = 0; i < decoded.length; i++)
                    bytes.push(decoded.charCodeAt(i) & 0xff);
                return bytes;
            } catch (e) {
                return [];
            }
        }
        return [];
    }

    function codecNameFromBluez(codecId, configValue) {
        const id = Number(codecId);
        if (id === 0x00)
            return "SBC";
        if (id === 0x01)
            return "MPEG12";
        if (id === 0x02)
            return "AAC";
        if (id === 0x04)
            return "ATRAC";
        if (id === 0xFF) {
            const bytes = bytesFromDbusValue(configValue);
            if (bytes.length >= 6) {
                const vendor = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
                const vendorCodec = bytes[4] | (bytes[5] << 8);
                if (vendor === 0x0000004f && vendorCodec === 0x0001)
                    return "APTX";
                if (vendor === 0x000000d7 && vendorCodec === 0x0024)
                    return "APTX_HD";
                if (vendor === 0x0000000a && vendorCodec === 0x0002)
                    return "APTX";
                if (vendor === 0x0000012d && vendorCodec === 0x00aa)
                    return "LDAC";
            }
            return "VENDOR";
        }
        return "";
    }

    function queryBluezCodecState(device, callback) {
        if (!dbusBridgeAvailable || !device) {
            callback([], "");
            return;
        }

        const devicePath = getDevicePath(device);
        if (!devicePath) {
            callback([], "");
            return;
        }

        DMSService.dbusCall("system", bluezService, "/", objectManagerIface, "GetManagedObjects", [], response => {
            if (response.error) {
                callback([], "");
                return;
            }

            const objects = response.result?.values?.[0] || {};
            const codecs = [];
            let current = "";

            for (const path in objects) {
                if (!path.startsWith(devicePath + "/"))
                    continue;
                const ifaces = objects[path] || {};
                const transport = ifaces[mediaTransportIface];
                if (transport) {
                    const name = codecNameFromBluez(transport.Codec, transport.Configuration);
                    if (name) {
                        current = root.getCodecInfo(name).name;
                        if (!codecs.some(c => c.name === current)) {
                            const info = root.getCodecInfo(name);
                            codecs.push({
                                "name": info.name,
                                "profile": info.name,
                                "description": info.description,
                                "qualityColor": info.qualityColor,
                                "category": root.codecCategory(info.name, info.name)
                            });
                        }
                    }
                }
                const endpoint = ifaces[mediaEndpointIface];
                if (endpoint) {
                    const name = codecNameFromBluez(endpoint.Codec, endpoint.Capabilities || endpoint.Configuration);
                    if (name) {
                        const info = root.getCodecInfo(name);
                        if (!codecs.some(c => c.name === info.name)) {
                            codecs.push({
                                "name": info.name,
                                "profile": info.name,
                                "description": info.description,
                                "qualityColor": info.qualityColor,
                                "category": root.codecCategory(info.name, info.name)
                            });
                        }
                    }
                }
            }

            callback(codecs, current);
        });
    }

    function sortDevices(devices) {
        return devices.sort((a, b) => {
            const aName = a.name || a.deviceName || "";
            const bName = b.name || b.deviceName || "";
            const aAddr = a.address || "";
            const bAddr = b.address || "";

            const aHasRealName = aName.includes(" ") && aName.length > 3;
            const bHasRealName = bName.includes(" ") && bName.length > 3;

            if (aHasRealName && !bHasRealName)
                return -1;
            if (!aHasRealName && bHasRealName)
                return 1;

            if (aHasRealName && bHasRealName) {
                return aName.localeCompare(bName);
            }

            return aAddr.localeCompare(bAddr);
        });
    }

    function getDeviceIcon(device) {
        if (!device) {
            return "bluetooth";
        }

        const name = (device.name || device.deviceName || "").toLowerCase();
        const icon = (device.icon || "").toLowerCase();

        const audioKeywords = ["headset", "audio", "headphone", "airpod", "arctis"];
        if (audioKeywords.some(keyword => icon.includes(keyword) || name.includes(keyword))) {
            return "headset";
        }

        if (icon.includes("mouse") || name.includes("mouse")) {
            return "mouse";
        }

        if (icon.includes("keyboard") || name.includes("keyboard")) {
            return "keyboard";
        }

        const phoneKeywords = ["phone", "iphone", "android", "samsung"];
        if (phoneKeywords.some(keyword => icon.includes(keyword) || name.includes(keyword))) {
            return "smartphone";
        }

        if (icon.includes("watch") || name.includes("watch")) {
            return "watch";
        }

        if (icon.includes("speaker") || name.includes("speaker")) {
            return "speaker";
        }

        if (icon.includes("display") || name.includes("tv")) {
            return "tv";
        }

        return "bluetooth";
    }

    function canConnect(device) {
        if (!device) {
            return false;
        }

        return !device.paired && !device.pairing && !device.blocked;
    }

    function getSignalStrength(device) {
        if (!device || device.signalStrength === undefined || device.signalStrength <= 0) {
            return "Unknown";
        }

        const signal = device.signalStrength;
        if (signal >= 80) {
            return "Excellent";
        }
        if (signal >= 60) {
            return "Good";
        }
        if (signal >= 40) {
            return "Fair";
        }
        if (signal >= 20) {
            return "Poor";
        }

        return "Very Poor";
    }

    function isDeviceBusy(device) {
        if (!device) {
            return false;
        }
        return device.pairing || device.state === BluetoothDeviceState.Disconnecting || device.state === BluetoothDeviceState.Connecting;
    }

    function connectDeviceWithTrust(device) {
        if (!device) {
            return;
        }

        device.trusted = true;
        device.connect();
    }

    function pairDevice(device, callback) {
        if (!device) {
            if (callback)
                callback({
                    error: "Invalid device"
                });
            return;
        }

        // The DMS backend actually implements a bluez agent, so we can pair anything
        if (enhancedPairingAvailable) {
            const devicePath = getDevicePath(device);
            DMSService.bluetoothPair(devicePath, callback);
            return;
        }

        // Quickshell does not implement a bluez agent, so we can try to pair but only with devices that don't require a passcode
        device.trusted = true;
        device.connect();
        if (callback)
            callback({
                success: true
            });
    }

    function getCardName(device) {
        if (!device) {
            return "";
        }
        return `bluez_card.${device.address.replace(/:/g, "_")}`;
    }

    function deviceForNodeName(nodeName) {
        const match = (nodeName || "").match(/^bluez_(?:output|input|card)\.([0-9A-Fa-f_]+)/);
        if (!match)
            return null;
        const address = match[1].replace(/_/g, ":").toUpperCase();
        return Bluetooth.devices?.values?.find(d => (d.address || "").toUpperCase() === address) ?? null;
    }

    function getDevicePath(device) {
        if (!device || !device.address) {
            return "";
        }
        return device.dbusPath ?? "";
    }

    function isAudioDevice(device) {
        if (!device) {
            return false;
        }
        const icon = getDeviceIcon(device);
        return icon === "headset" || icon === "speaker";
    }

    function getCodecInfo(codecName) {
        const codec = codecName.replace(/[-\s]+/g, "_").toUpperCase();

        const codecMap = {
            "LDAC": {
                "name": "LDAC",
                "description": "Highest quality • Higher battery usage",
                "qualityColor": "#4CAF50"
            },
            "APTX_HD": {
                "name": "aptX HD",
                "description": "High quality • Balanced battery",
                "qualityColor": "#FF9800"
            },
            "APTX_LL": {
                "name": "aptX LL",
                "description": "Low latency • Gaming and video",
                "qualityColor": "#FF9800"
            },
            "APTX_ADAPTIVE": {
                "name": "aptX Adaptive",
                "description": "Adaptive quality and latency",
                "qualityColor": "#FF9800"
            },
            "APTX": {
                "name": "aptX",
                "description": "Good quality • Low latency",
                "qualityColor": "#FF9800"
            },
            "AAC_ELD": {
                "name": "AAC-ELD",
                "description": "Low-delay AAC • Voice and video",
                "qualityColor": "#2196F3"
            },
            "AAC": {
                "name": "AAC",
                "description": "Balanced quality and battery",
                "qualityColor": "#2196F3"
            },
            "OPUS_05": {
                "name": "Opus",
                "description": "High quality • Modern Bluetooth LE audio",
                "qualityColor": "#4CAF50"
            },
            "OPUS_G": {
                "name": "Opus",
                "description": "High quality • Modern Bluetooth LE audio",
                "qualityColor": "#4CAF50"
            },
            "OPUS": {
                "name": "Opus",
                "description": "High quality • Efficient streaming",
                "qualityColor": "#4CAF50"
            },
            "LC3": {
                "name": "LC3",
                "description": "LE Audio • Efficient high quality",
                "qualityColor": "#4CAF50"
            },
            "LC3_SWB": {
                "name": "LC3-SWB",
                "description": "Wideband speech • Hands-free calls",
                "qualityColor": "#9E9E9E"
            },
            "LC3_A127": {
                "name": "LC3",
                "description": "LE Audio speech • Hands-free calls",
                "qualityColor": "#9E9E9E"
            },
            "SBC_XQ": {
                "name": "SBC-XQ",
                "description": "Enhanced SBC • Better compatibility",
                "qualityColor": "#2196F3"
            },
            "SBC": {
                "name": "SBC",
                "description": "Basic quality • Universal compatibility",
                "qualityColor": "#9E9E9E"
            },
            "MSBC": {
                "name": "mSBC",
                "description": "Modified SBC • Optimized for speech",
                "qualityColor": "#9E9E9E"
            },
            "CVSD": {
                "name": "CVSD",
                "description": "Basic speech codec • Legacy compatibility",
                "qualityColor": "#9E9E9E"
            },
            "FASTSTREAM": {
                "name": "FastStream",
                "description": "Low latency SBC variant",
                "qualityColor": "#2196F3"
            }
        };

        return codecMap[codec] || {
            "name": codecName,
            "description": "Unknown codec",
            "qualityColor": "#9E9E9E"
        };
    }

    property var deviceCodecs: ({})

    function updateDeviceCodec(deviceAddress, codec) {
        if (!deviceAddress || !codec)
            return;
        const next = Object.assign({}, deviceCodecs);
        next[deviceAddress] = codec;
        deviceCodecs = next;
    }

    function codecCategory(codecName, profileName) {
        const profile = String(profileName || "").toLowerCase();
        const codec = String(codecName || "").replace(/[-\s]+/g, "_").toUpperCase();
        if (profile.includes("headset") || profile.includes("hfp") || profile.includes("hsp") || profile.includes("handsfree") || profile.includes("head-unit") || profile.includes("audio-gateway"))
            return "call";
        if (codec === "CVSD" || codec === "MSBC" || codec === "LC3_SWB" || codec === "LC3_A127")
            return "call";
        return "media";
    }

    function codecNameFromProfile(profileName) {
        if (!profileName)
            return "";
        const match = String(profileName).match(/codec\s+([^\)]+)/i);
        if (match)
            return getCodecInfo(match[1].trim()).name;
        const parts = String(profileName).split(/[-_]/);
        if (parts.length > 1) {
            const tail = parts.slice(1).join("_");
            const info = getCodecInfo(tail);
            if (info.description !== "Unknown codec")
                return info.name;
            const last = parts[parts.length - 1];
            const lastInfo = getCodecInfo(last);
            if (lastInfo.description !== "Unknown codec")
                return lastInfo.name;
        }
        const info = getCodecInfo(profileName);
        return info.description === "Unknown codec" ? "" : info.name;
    }

    function refreshDeviceCodec(device) {
        if (!device || !device.connected || !isAudioDevice(device)) {
            return;
        }

        whenCodecBackendReady(() => {
            if (root.wpexecAvailable) {
                root.queryCardProfiles(device, (codecs, current) => {
                    if (current) {
                        root.updateDeviceCodec(device.address, current);
                        return;
                    }
                    if (!root.dbusBridgeAvailable)
                        return;
                    root.queryBluezCodecState(device, (bluezCodecs, bluezCurrent) => {
                        if (bluezCurrent)
                            root.updateDeviceCodec(device.address, bluezCurrent);
                    });
                });
                return;
            }

            if (!root.dbusBridgeAvailable)
                return;
            root.queryBluezCodecState(device, (codecs, current) => {
                if (current)
                    root.updateDeviceCodec(device.address, current);
            });
        });
    }

    function getAvailableCodecs(device, callback) {
        if (!device || !device.connected || !isAudioDevice(device)) {
            callback([], "");
            return;
        }

        whenCodecBackendReady(() => {
            if (!root.wpexecAvailable) {
                if (root.dbusBridgeAvailable) {
                    root.queryBluezCodecState(device, callback);
                    return;
                }
                callback([], "");
                return;
            }

            root.queryCardProfiles(device, (codecs, current) => {
                if (codecs.length > 0 || !root.dbusBridgeAvailable) {
                    callback(codecs, current);
                    return;
                }
                root.queryBluezCodecState(device, (bluezCodecs, bluezCurrent) => {
                    callback(bluezCodecs, bluezCurrent || current);
                });
            });
        });
    }

    function switchCodec(device, profileName, callback, codecDisplayName) {
        if (!device || !isAudioDevice(device)) {
            callback(false, "Invalid device");
            return;
        }

        whenCodecBackendReady(() => {
            if (!root.wpexecAvailable) {
                callback(false, I18n.tr("Codec switching is unavailable. WirePlumber wpexec was not found."));
                return;
            }

            const cardName = root.getCardName(device);
            codecSwitchProcess.cardName = cardName;
            codecSwitchProcess.profile = profileName;
            codecSwitchProcess.deviceAddress = device.address || "";
            codecSwitchProcess.expectedCodec = codecDisplayName || root.codecNameFromProfile(profileName);
            codecSwitchProcess.callback = callback;
            codecSwitchProcess.command = ["wpexec", root.cardProfileScript, JSON.stringify({
                    "mode": "set",
                    "device": cardName,
                    "target": profileName
                })];
            codecSwitchProcess.running = true;
        });
    }

    function queryCardProfiles(device, callback) {
        if (!device || !wpexecAvailable) {
            callback([], "");
            return;
        }

        const cardName = getCardName(device);
        codecListProcess.cardName = cardName;
        codecListProcess.callback = callback;
        codecListProcess.availableCodecs = [];
        codecListProcess.detectedCodec = "";
        codecListProcess.command = ["wpexec", cardProfileScript, JSON.stringify({
                "mode": "list",
                "device": cardName
            })];
        codecListProcess.running = true;
    }

    Process {
        id: detectWpexecProcess
        running: false
        command: ["sh", "-c", "command -v wpexec"]

        onExited: function (exitCode) {
            root.wpexecAvailable = (exitCode === 0);
            root.wpexecChecked = true;
            const actions = root.pendingCodecActions.slice();
            root.pendingCodecActions = [];
            actions.forEach(action => action());
        }
    }

    Process {
        id: codecListProcess

        property string cardName: ""
        property var callback: null
        property string detectedCodec: ""
        property var availableCodecs: []

        command: ["wpexec", root.cardProfileScript, "{}"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const line = data.trim();
                if (!line.startsWith("CODEC\t"))
                    return;
                const parts = line.split("\t");
                if (parts.length < 5)
                    return;
                const codecName = parts[1];
                const profile = parts[2];
                const isCurrent = parts[4] === "1";
                const codecInfo = root.getCodecInfo(codecName);
                if (!codecInfo)
                    return;
                if (isCurrent)
                    codecListProcess.detectedCodec = codecInfo.name;
                if (!codecListProcess.availableCodecs.some(c => c.profile === profile)) {
                    const next = codecListProcess.availableCodecs.slice();
                    next.push({
                        "name": codecInfo.name,
                        "profile": profile,
                        "description": codecInfo.description,
                        "qualityColor": codecInfo.qualityColor,
                        "category": root.codecCategory(codecInfo.name, profile)
                    });
                    codecListProcess.availableCodecs = next;
                }
            }
        }

        onExited: function (exitCode) {
            if (callback)
                callback(exitCode === 0 ? availableCodecs : [], exitCode === 0 ? detectedCodec : "");
            detectedCodec = "";
            availableCodecs = [];
            callback = null;
        }
    }

    Process {
        id: codecSwitchProcess

        property string cardName: ""
        property string profile: ""
        property string deviceAddress: ""
        property string expectedCodec: ""
        property var callback: null
        property bool sawOk: false

        command: ["wpexec", root.cardProfileScript, "{}"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const line = data.trim();
                if (!line.startsWith("OK\t"))
                    return;
                codecSwitchProcess.sawOk = true;
                const appliedProfile = line.split("\t")[1] || "";
                if (appliedProfile)
                    codecSwitchProcess.expectedCodec = root.codecNameFromProfile(appliedProfile) || codecSwitchProcess.expectedCodec;
            }
        }

        onExited: function (exitCode) {
            const success = exitCode === 0 && sawOk;
            if (success && deviceAddress && expectedCodec)
                root.updateDeviceCodec(deviceAddress, expectedCodec);

            if (callback)
                callback(success, success ? I18n.tr("Codec switched successfully") : I18n.tr("Failed to switch codec"));

            sawOk = false;
            expectedCodec = "";
            deviceAddress = "";
            callback = null;
        }
    }
}
