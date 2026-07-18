pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.Services

Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: (adapter && adapter.enabled) ?? false
    readonly property bool discovering: (adapter && adapter.discovering) ?? false
    property bool pactlAvailable: false
    property bool pactlChecked: false
    property var pendingPactlActions: []
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

    // Split keyboards (e.g. ZMK) report each half's charge on a separate GATT
    // Battery Level (0x2A19) characteristic, but BlueZ's org.bluez.Battery1 —
    // and therefore Quickshell's device.battery — surfaces only one of them. We
    // read the extra characteristics (identified by their 0x2901 user-description
    // descriptor, e.g. "Peripheral 0") directly over D-Bus and expose them here,
    // keyed by uppercased device address: { "AA:BB:..": [{ percentage, label }] }.
    property var peripheralBatteries: ({})
    // Live tracking state for the peripheral Battery Level characteristics,
    // keyed by their GATT object path.
    property var _peripheralCharacteristics: ({})
    property bool _bluezSubscribed: false
    property bool _bluezRescanQueued: false

    function peripheralBatteriesFor(device) {
        if (!device || !device.address)
            return [];
        return root.peripheralBatteries[device.address.toUpperCase()] || [];
    }

    Component.onCompleted: {
        detectPactlProcess.running = true;
        maybeInitBluez();
    }

    // The split-keyboard batteries are read over DMS's persistent system-bus
    // D-Bus bridge (org.bluez / BlueZ GATT), which requires the "dbus"
    // capability. When it is unavailable we simply expose no extra batteries
    // and non-split devices render exactly as before.
    Connections {
        target: DMSService

        function onConnectionStateChanged() {
            root.maybeInitBluez();
        }

        function onCapabilitiesChanged() {
            root.maybeInitBluez();
        }

        function onDbusSignalReceived(subscriptionId, data) {
            root.handleBluezSignal(data);
        }
    }

    function maybeInitBluez() {
        if (!DMSService.isConnected || !DMSService.capabilities.includes("dbus")) {
            root._bluezSubscribed = false;
            return;
        }
        subscribeBluezSignals();
        scanPeripheralBatteries();
    }

    function subscribeBluezSignals() {
        if (root._bluezSubscribed)
            return;
        root._bluezSubscribed = true;

        DMSService.dbusSubscribe("system", "org.bluez", "", "org.freedesktop.DBus.Properties", "PropertiesChanged", null);
        DMSService.dbusSubscribe("system", "org.bluez", "", "org.freedesktop.DBus.ObjectManager", "InterfacesAdded", null);
        DMSService.dbusSubscribe("system", "org.bluez", "", "org.freedesktop.DBus.ObjectManager", "InterfacesRemoved", null);
    }

    function handleBluezSignal(data) {
        switch (data.member) {
        case "PropertiesChanged": {
            const characteristic = root._peripheralCharacteristics[data.path];
            if (!characteristic)
                return;
            if (data.body?.[0] !== "org.bluez.GattCharacteristic1")
                return;
            const changed = data.body?.[1] || {};
            if (!("Value" in changed))
                return;
            const percentage = gattByte(changed.Value);
            if (percentage === null || !characteristic.label)
                return;
            setPeripheralBattery(characteristic.address, characteristic.label, percentage);
            return;
        }
        case "InterfacesAdded":
        case "InterfacesRemoved":
            // GATT objects tend to appear in a burst during service discovery;
            // coalesce them into a single event-driven rescan.
            queueBluezRescan();
            return;
        }
    }

    function queueBluezRescan() {
        if (root._bluezRescanQueued)
            return;
        root._bluezRescanQueued = true;
        Qt.callLater(() => {
            root._bluezRescanQueued = false;
            root.scanPeripheralBatteries();
        });
    }

    // Walk BlueZ's GATT tree once and pick out every peripheral Battery Level
    // (0x2A19) characteristic that carries a 0x2901 user-description descriptor
    // (which is exactly how ZMK tags a split half, e.g. "Peripheral 0"). The
    // unlabeled central battery is deliberately skipped — it is already exposed
    // via org.bluez.Battery1 / device.battery.
    function scanPeripheralBatteries() {
        DMSService.dbusCall("system", "org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects", [], response => {
            const objects = response.result?.values?.[0];
            if (response.error || !objects)
                return;

            const batteries = {};
            const characteristics = {};

            for (const path in objects) {
                const characteristic = objects[path]?.["org.bluez.GattCharacteristic1"];
                if (!characteristic || !String(characteristic.UUID || "").toLowerCase().startsWith("00002a19"))
                    continue;

                const descriptorPath = findUserDescription(objects, path);
                if (!descriptorPath)
                    continue;

                const devicePath = devicePathForCharacteristic(objects, characteristic);
                const device = objects[devicePath]?.["org.bluez.Device1"];
                if (!device?.Address)
                    continue;

                const address = String(device.Address).toUpperCase();
                const descriptor = objects[descriptorPath]?.["org.bluez.GattDescriptor1"];

                const tracked = {
                    "address": address,
                    "path": path,
                    "descriptorPath": descriptorPath,
                    "label": gattString(descriptor?.Value),
                    "connected": device.Connected === true
                };
                characteristics[path] = tracked;

                const percentage = gattByte(characteristic.Value);
                if (tracked.label && percentage !== null)
                    appendPeripheralBattery(batteries, address, tracked.label, percentage);
            }

            root._peripheralCharacteristics = characteristics;
            root.peripheralBatteries = batteries;

            for (const path in characteristics) {
                if (characteristics[path].connected)
                    primePeripheralCharacteristic(characteristics[path]);
            }
        });
    }

    // On a cold cache BlueZ has no stored Value yet, so subscribe for future
    // notifications and read the current label/level once. StartNotify stays
    // active because it is owned by the persistent DMS D-Bus connection, not a
    // short-lived helper process.
    function primePeripheralCharacteristic(characteristic) {
        DMSService.dbusCall("system", "org.bluez", characteristic.path, "org.bluez.GattCharacteristic1", "StartNotify", [], null);

        if (!characteristic.label) {
            DMSService.dbusCall("system", "org.bluez", characteristic.descriptorPath, "org.bluez.GattDescriptor1", "ReadValue", [{}], response => {
                const label = gattString(response.result?.values?.[0]);
                if (!label)
                    return;
                const updated = Object.assign({}, root._peripheralCharacteristics);
                if (updated[characteristic.path])
                    updated[characteristic.path].label = label;
                root._peripheralCharacteristics = updated;
            });
        }

        DMSService.dbusCall("system", "org.bluez", characteristic.path, "org.bluez.GattCharacteristic1", "ReadValue", [{}], response => {
            const percentage = gattByte(response.result?.values?.[0]);
            const label = root._peripheralCharacteristics[characteristic.path]?.label;
            if (percentage === null || !label)
                return;
            setPeripheralBattery(characteristic.address, label, percentage);
        });
    }

    function devicePathForCharacteristic(objects, characteristic) {
        const servicePath = characteristic.Service;
        const service = objects[servicePath]?.["org.bluez.GattService1"];
        return service?.Device || "";
    }

    function findUserDescription(objects, characteristicPath) {
        for (const path in objects) {
            if (!path.startsWith(characteristicPath + "/desc"))
                continue;
            const descriptor = objects[path]?.["org.bluez.GattDescriptor1"];
            if (descriptor && String(descriptor.UUID || "").toLowerCase().startsWith("00002901"))
                return path;
        }
        return "";
    }

    function appendPeripheralBattery(map, address, label, percentage) {
        if (!map[address])
            map[address] = [];
        map[address].push({
            "percentage": percentage,
            "label": label
        });
    }

    function setPeripheralBattery(address, label, percentage) {
        const map = JSON.parse(JSON.stringify(root.peripheralBatteries));
        if (!map[address])
            map[address] = [];
        const existing = map[address].find(battery => battery.label === label);
        if (existing)
            existing.percentage = percentage;
        else
            map[address].push({
                "percentage": percentage,
                "label": label
            });
        root.peripheralBatteries = map;
    }

    // The Go bridge serializes D-Bus `ay` byte arrays as base64 strings. Decode
    // them here rather than via Qt.atob(), whose string overload is deprecated
    // and warns on every call.
    function base64Bytes(value) {
        const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        const clean = String(value).replace(/=+$/, "");
        const bytes = [];
        let buffer = 0;
        let bits = 0;
        for (let i = 0; i < clean.length; i++) {
            const idx = chars.indexOf(clean[i]);
            if (idx === -1)
                continue;
            buffer = (buffer << 6) | idx;
            bits += 6;
            if (bits >= 8) {
                bits -= 8;
                bytes.push((buffer >> bits) & 0xFF);
            }
        }
        return bytes;
    }

    function gattByte(value) {
        if (typeof value !== "string" || !value.length)
            return null;
        const bytes = base64Bytes(value);
        // An empty cached byte array must not be read as 0%.
        return bytes.length >= 1 ? bytes[0] : null;
    }

    function gattString(value) {
        if (typeof value !== "string" || !value.length)
            return "";
        const bytes = base64Bytes(value);
        let result = "";
        for (let i = 0; i < bytes.length; i++)
            result += String.fromCharCode(bytes[i]);
        return result;
    }

    function whenPactlChecked(action) {
        if (pactlChecked) {
            action();
            return;
        }

        const actions = pendingPactlActions.slice();
        actions.push(action);
        pendingPactlActions = actions;
        if (!detectPactlProcess.running)
            detectPactlProcess.running = true;
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

    function getSignalIcon(device) {
        if (!device || device.signalStrength === undefined || device.signalStrength <= 0) {
            return "signal_cellular_null";
        }

        const signal = device.signalStrength;
        if (signal >= 80) {
            return "signal_cellular_4_bar";
        }
        if (signal >= 60) {
            return "signal_cellular_3_bar";
        }
        if (signal >= 40) {
            return "signal_cellular_2_bar";
        }
        if (signal >= 20) {
            return "signal_cellular_1_bar";
        }

        return "signal_cellular_0_bar";
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
            "APTX": {
                "name": "aptX",
                "description": "Good quality • Low latency",
                "qualityColor": "#FF9800"
            },
            "AAC": {
                "name": "AAC",
                "description": "Balanced quality and battery",
                "qualityColor": "#2196F3"
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
        deviceCodecs[deviceAddress] = codec;
        deviceCodecsChanged();
    }

    function refreshDeviceCodec(device) {
        if (!device || !device.connected || !isAudioDevice(device)) {
            return;
        }
        if (!pactlChecked) {
            whenPactlChecked(() => root.refreshDeviceCodec(device));
            return;
        }
        if (!pactlAvailable) {
            return;
        }

        const cardName = getCardName(device);
        codecQueryProcess.cardName = cardName;
        codecQueryProcess.deviceAddress = device.address;
        codecQueryProcess.availableCodecs = [];
        codecQueryProcess.parsingTargetCard = false;
        codecQueryProcess.detectedCodec = "";
        codecQueryProcess.running = true;
    }

    function getCurrentCodec(device, callback) {
        if (!device || !device.connected || !isAudioDevice(device)) {
            callback("");
            return;
        }
        if (!pactlChecked) {
            whenPactlChecked(() => root.getCurrentCodec(device, callback));
            return;
        }
        if (!pactlAvailable) {
            callback("");
            return;
        }

        const cardName = getCardName(device);
        codecQueryProcess.cardName = cardName;
        codecQueryProcess.callback = callback;
        codecQueryProcess.availableCodecs = [];
        codecQueryProcess.parsingTargetCard = false;
        codecQueryProcess.detectedCodec = "";
        codecQueryProcess.running = true;
    }

    function getAvailableCodecs(device, callback) {
        if (!device || !device.connected || !isAudioDevice(device)) {
            callback([], "");
            return;
        }
        if (!pactlChecked) {
            whenPactlChecked(() => root.getAvailableCodecs(device, callback));
            return;
        }
        if (!pactlAvailable) {
            callback([], "");
            return;
        }

        const cardName = getCardName(device);
        codecFullQueryProcess.cardName = cardName;
        codecFullQueryProcess.callback = callback;
        codecFullQueryProcess.availableCodecs = [];
        codecFullQueryProcess.parsingTargetCard = false;
        codecFullQueryProcess.detectedCodec = "";
        codecFullQueryProcess.running = true;
    }

    function switchCodec(device, profileName, callback) {
        if (!device || !isAudioDevice(device)) {
            callback(false, "Invalid device");
            return;
        }
        if (!pactlChecked) {
            whenPactlChecked(() => root.switchCodec(device, profileName, callback));
            return;
        }
        if (!pactlAvailable) {
            callback(false, I18n.tr("Codec switching is unavailable because pactl was not found"));
            return;
        }

        const cardName = getCardName(device);
        codecSwitchProcess.cardName = cardName;
        codecSwitchProcess.profile = profileName;
        codecSwitchProcess.callback = callback;
        codecSwitchProcess.running = true;
    }

    Process {
        id: detectPactlProcess
        running: false
        command: ["sh", "-c", "command -v pactl"]

        onExited: function (exitCode) {
            root.pactlAvailable = (exitCode === 0);
            root.pactlChecked = true;
            const actions = root.pendingPactlActions.slice();
            root.pendingPactlActions = [];
            actions.forEach(action => action());
        }
    }

    Process {
        id: codecQueryProcess

        property string cardName: ""
        property string deviceAddress: ""
        property var callback: null
        property bool parsingTargetCard: false
        property string detectedCodec: ""
        property var availableCodecs: []

        command: ["pactl", "list", "cards"]

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && detectedCodec) {
                if (deviceAddress) {
                    root.updateDeviceCodec(deviceAddress, detectedCodec);
                }
                if (callback) {
                    callback(detectedCodec);
                }
            } else if (callback) {
                callback("");
            }

            parsingTargetCard = false;
            detectedCodec = "";
            availableCodecs = [];
            deviceAddress = "";
            callback = null;
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let line = data.trim();

                if (line.includes(`Name: ${codecQueryProcess.cardName}`)) {
                    codecQueryProcess.parsingTargetCard = true;
                    return;
                }

                if (codecQueryProcess.parsingTargetCard && line.startsWith("Name: ") && !line.includes(codecQueryProcess.cardName)) {
                    codecQueryProcess.parsingTargetCard = false;
                    return;
                }

                if (codecQueryProcess.parsingTargetCard) {
                    if (line.startsWith("Active Profile:")) {
                        let profile = line.split(": ")[1] || "";
                        let activeCodec = codecQueryProcess.availableCodecs.find(c => {
                            return c.profile === profile;
                        });
                        if (activeCodec) {
                            codecQueryProcess.detectedCodec = activeCodec.name;
                        }
                        return;
                    }
                    if (line.includes("codec") && line.includes("available: yes")) {
                        let parts = line.split(": ");
                        if (parts.length >= 2) {
                            let profile = parts[0].trim();
                            let description = parts[1];
                            let codecMatch = description.match(/codec ([^\)]+)\)/i);
                            let codecName = codecMatch ? codecMatch[1].trim().toUpperCase() : "UNKNOWN";
                            let codecInfo = root.getCodecInfo(codecName);
                            if (codecInfo && !codecQueryProcess.availableCodecs.some(c => {
                                return c.profile === profile;
                            })) {
                                let newCodecs = codecQueryProcess.availableCodecs.slice();
                                newCodecs.push({
                                    "name": codecInfo.name,
                                    "profile": profile,
                                    "description": codecInfo.description,
                                    "qualityColor": codecInfo.qualityColor
                                });
                                codecQueryProcess.availableCodecs = newCodecs;
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: codecFullQueryProcess

        property string cardName: ""
        property var callback: null
        property bool parsingTargetCard: false
        property string detectedCodec: ""
        property var availableCodecs: []

        command: ["pactl", "list", "cards"]

        onExited: function (exitCode, exitStatus) {
            if (callback) {
                callback(exitCode === 0 ? availableCodecs : [], exitCode === 0 ? detectedCodec : "");
            }
            parsingTargetCard = false;
            detectedCodec = "";
            availableCodecs = [];
            callback = null;
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let line = data.trim();

                if (line.includes(`Name: ${codecFullQueryProcess.cardName}`)) {
                    codecFullQueryProcess.parsingTargetCard = true;
                    return;
                }

                if (codecFullQueryProcess.parsingTargetCard && line.startsWith("Name: ") && !line.includes(codecFullQueryProcess.cardName)) {
                    codecFullQueryProcess.parsingTargetCard = false;
                    return;
                }

                if (codecFullQueryProcess.parsingTargetCard) {
                    if (line.startsWith("Active Profile:")) {
                        let profile = line.split(": ")[1] || "";
                        let activeCodec = codecFullQueryProcess.availableCodecs.find(c => {
                            return c.profile === profile;
                        });
                        if (activeCodec) {
                            codecFullQueryProcess.detectedCodec = activeCodec.name;
                        }
                        return;
                    }
                    if (line.includes("codec") && line.includes("available: yes")) {
                        let parts = line.split(": ");
                        if (parts.length >= 2) {
                            let profile = parts[0].trim();
                            let description = parts[1];
                            let codecMatch = description.match(/codec ([^\)]+)\)/i);
                            let codecName = codecMatch ? codecMatch[1].trim().toUpperCase() : "UNKNOWN";
                            let codecInfo = root.getCodecInfo(codecName);
                            if (codecInfo && !codecFullQueryProcess.availableCodecs.some(c => {
                                return c.profile === profile;
                            })) {
                                let newCodecs = codecFullQueryProcess.availableCodecs.slice();
                                newCodecs.push({
                                    "name": codecInfo.name,
                                    "profile": profile,
                                    "description": codecInfo.description,
                                    "qualityColor": codecInfo.qualityColor
                                });
                                codecFullQueryProcess.availableCodecs = newCodecs;
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: codecSwitchProcess

        property string cardName: ""
        property string profile: ""
        property var callback: null

        command: ["pactl", "set-card-profile", cardName, profile]

        onExited: function (exitCode, exitStatus) {
            if (callback) {
                callback(exitCode === 0, exitCode === 0 ? "Codec switched successfully" : "Failed to switch codec");
            }

            // If successful, refresh the codec for this device
            if (exitCode === 0) {
                if (root.adapter && root.adapter.devices) {
                    root.adapter.devices.values.forEach(device => {
                        if (device && root.getCardName(device) === cardName) {
                            Qt.callLater(() => root.refreshDeviceCodec(device));
                        }
                    });
                }
            }

            callback = null;
        }
    }

}
