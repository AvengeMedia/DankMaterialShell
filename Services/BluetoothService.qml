pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: (adapter && adapter.enabled) ?? false
    readonly property bool discovering: (adapter && adapter.discovering) ?? false
    readonly property var devices: adapter ? adapter.devices : null
    readonly property bool connected: {
        if (!adapter || !adapter.devices) {
            return false
        }

        let isConnected = false
        adapter.devices.values.forEach(dev => { if (dev.connected) isConnected = true })
        return isConnected
    }
    readonly property var pairedDevices: {
        if (!adapter || !adapter.devices) {
            return []
        }

        return adapter.devices.values.filter(dev => {
                                                 return dev && (dev.paired || dev.trusted)
                                             })
    }
    readonly property var allDevicesWithBattery: {
        if (!adapter || !adapter.devices) {
            return []
        }

        return adapter.devices.values.filter(dev => {
                                                 return dev && dev.batteryAvailable && dev.battery > 0
                                             })
    }

    function sortDevices(devices) {
        return devices.sort((a, b) => {
                                const aName = a.name || a.deviceName || ""
                                const bName = b.name || b.deviceName || ""

                                const aHasRealName = aName.includes(" ") && aName.length > 3
                                const bHasRealName = bName.includes(" ") && bName.length > 3

                                if (aHasRealName && !bHasRealName) {
                                    return -1
                                }
                                if (!aHasRealName && bHasRealName) {
                                    return 1
                                }

                                const aSignal = (a.signalStrength !== undefined && a.signalStrength > 0) ? a.signalStrength : 0
                                const bSignal = (b.signalStrength !== undefined && b.signalStrength > 0) ? b.signalStrength : 0
                                return bSignal - aSignal
                            })
    }

    function getDeviceIcon(device) {
        if (!device) {
            return "bluetooth"
        }

        const name = (device.name || device.deviceName || "").toLowerCase()
        const icon = (device.icon || "").toLowerCase()

        const audioKeywords = ["headset", "audio", "headphone", "airpod", "arctis"]
        if (audioKeywords.some(keyword => icon.includes(keyword) || name.includes(keyword))) {
            return "headset"
        }

        if (icon.includes("mouse") || name.includes("mouse")) {
            return "mouse"
        }

        if (icon.includes("keyboard") || name.includes("keyboard")) {
            return "keyboard"
        }

        const phoneKeywords = ["phone", "iphone", "android", "samsung"]
        if (phoneKeywords.some(keyword => icon.includes(keyword) || name.includes(keyword))) {
            return "smartphone"
        }

        if (icon.includes("watch") || name.includes("watch")) {
            return "watch"
        }

        if (icon.includes("speaker") || name.includes("speaker")) {
            return "speaker"
        }

        if (icon.includes("display") || name.includes("tv")) {
            return "tv"
        }

        return "bluetooth"
    }

    function canConnect(device) {
        if (!device) {
            return false
        }

        return !device.paired && !device.pairing && !device.blocked
    }

    function getSignalStrength(device) {
        if (!device || device.signalStrength === undefined || device.signalStrength <= 0) {
            return "Unknown"
        }

        const signal = device.signalStrength
        if (signal >= 80) {
            return "Excellent"
        }
        if (signal >= 60) {
            return "Good"
        }
        if (signal >= 40) {
            return "Fair"
        }
        if (signal >= 20) {
            return "Poor"
        }

        return "Very Poor"
    }

    function getSignalIcon(device) {
        if (!device || device.signalStrength === undefined || device.signalStrength <= 0) {
            return "signal_cellular_null"
        }

        const signal = device.signalStrength
        if (signal >= 80) {
            return "signal_cellular_4_bar"
        }
        if (signal >= 60) {
            return "signal_cellular_3_bar"
        }
        if (signal >= 40) {
            return "signal_cellular_2_bar"
        }
        if (signal >= 20) {
            return "signal_cellular_1_bar"
        }

        return "signal_cellular_0_bar"
    }

    function isDeviceBusy(device) {
        if (!device) {
            return false
        }
        return device.pairing || device.state === BluetoothDeviceState.Disconnecting || device.state === BluetoothDeviceState.Connecting
    }

    function connectDeviceWithTrust(device) {
        if (!device) {
            return
        }

        device.trusted = true
        device.connect()
    }

    function getCardName(device) {
        if (!device) {
            return ""
        }
        return `bluez_card.${device.address.replace(/:/g, "_")}`
    }

    function isAudioDevice(device) {
        if (!device) {
            return false
        }
        const icon = getDeviceIcon(device)
        return icon === "headset" || icon === "speaker"
    }

    function getCodecInfo(codecName) {
        const codec = codecName.replace(/-/g, "_").toUpperCase()

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
        }

        return codecMap[codec] || {
            "name": codecName,
            "description": "Unknown codec",
            "qualityColor": "#9E9E9E"
        }
    }

    property var deviceCodecs: ({})

    function updateDeviceCodec(deviceAddress, codec) {
        deviceCodecs[deviceAddress] = codec
        deviceCodecsChanged()
    }

    function refreshDeviceCodec(device) {
        if (!device || !device.connected || !isAudioDevice(device)) {
            return
        }

        const cardName = getCardName(device)
        codecQueryProcess.cardName = cardName
        codecQueryProcess.deviceAddress = device.address
        codecQueryProcess.availableCodecs = []
        codecQueryProcess.parsingTargetCard = false
        codecQueryProcess.detectedCodec = ""
        codecQueryProcess.running = true
    }

    function getCurrentCodec(device, callback) {
        if (!device || !device.connected || !isAudioDevice(device)) {
            callback("")
            return
        }

        const cardName = getCardName(device)
        codecQueryProcess.cardName = cardName
        codecQueryProcess.callback = callback
        codecQueryProcess.availableCodecs = []
        codecQueryProcess.parsingTargetCard = false
        codecQueryProcess.detectedCodec = ""
        codecQueryProcess.running = true
    }

    function getAvailableCodecs(device, callback) {
        if (!device || !device.connected || !isAudioDevice(device)) {
            callback([], "")
            return
        }

        const cardName = getCardName(device)
        codecFullQueryProcess.cardName = cardName
        codecFullQueryProcess.callback = callback
        codecFullQueryProcess.availableCodecs = []
        codecFullQueryProcess.parsingTargetCard = false
        codecFullQueryProcess.detectedCodec = ""
        codecFullQueryProcess.running = true
    }

    function switchCodec(device, profileName, callback) {
        if (!device || !isAudioDevice(device)) {
            callback(false, "Invalid device")
            return
        }

        const cardName = getCardName(device)
        codecSwitchProcess.cardName = cardName
        codecSwitchProcess.profile = profileName
        codecSwitchProcess.callback = callback
        codecSwitchProcess.running = true
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
                    root.updateDeviceCodec(deviceAddress, detectedCodec)
                }
                if (callback) {
                    callback(detectedCodec)
                }
            } else if (callback) {
                callback("")
            }

            parsingTargetCard = false
            detectedCodec = ""
            availableCodecs = []
            deviceAddress = ""
            callback = null
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let line = data.trim()

                if (line.includes(`Name: ${codecQueryProcess.cardName}`)) {
                    codecQueryProcess.parsingTargetCard = true
                    return
                }

                if (codecQueryProcess.parsingTargetCard && line.startsWith("Name: ") && !line.includes(codecQueryProcess.cardName)) {
                    codecQueryProcess.parsingTargetCard = false
                    return
                }

                if (codecQueryProcess.parsingTargetCard) {
                    if (line.startsWith("Active Profile:")) {
                        let profile = line.split(": ")[1] || ""
                        let activeCodec = codecQueryProcess.availableCodecs.find(c => {
                                                                                     return c.profile === profile
                                                                                 })
                        if (activeCodec) {
                            codecQueryProcess.detectedCodec = activeCodec.name
                        }
                        return
                    }
                    if (line.includes("codec") && line.includes("available: yes")) {
                        let parts = line.split(": ")
                        if (parts.length >= 2) {
                            let profile = parts[0].trim()
                            let description = parts[1]
                            let codecMatch = description.match(/codec ([^\)\s]+)/i)
                            let codecName = codecMatch ? codecMatch[1].toUpperCase() : "UNKNOWN"
                            let codecInfo = root.getCodecInfo(codecName)
                            if (codecInfo && !codecQueryProcess.availableCodecs.some(c => {
                                                                                         return c.profile === profile
                                                                                     })) {
                                let newCodecs = codecQueryProcess.availableCodecs.slice()
                                newCodecs.push({
                                                   "name": codecInfo.name,
                                                   "profile": profile,
                                                   "description": codecInfo.description,
                                                   "qualityColor": codecInfo.qualityColor
                                               })
                                codecQueryProcess.availableCodecs = newCodecs
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
                callback(exitCode === 0 ? availableCodecs : [], exitCode === 0 ? detectedCodec : "")
            }
            parsingTargetCard = false
            detectedCodec = ""
            availableCodecs = []
            callback = null
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let line = data.trim()

                if (line.includes(`Name: ${codecFullQueryProcess.cardName}`)) {
                    codecFullQueryProcess.parsingTargetCard = true
                    return
                }

                if (codecFullQueryProcess.parsingTargetCard && line.startsWith("Name: ") && !line.includes(codecFullQueryProcess.cardName)) {
                    codecFullQueryProcess.parsingTargetCard = false
                    return
                }

                if (codecFullQueryProcess.parsingTargetCard) {
                    if (line.startsWith("Active Profile:")) {
                        let profile = line.split(": ")[1] || ""
                        let activeCodec = codecFullQueryProcess.availableCodecs.find(c => {
                                                                                         return c.profile === profile
                                                                                     })
                        if (activeCodec) {
                            codecFullQueryProcess.detectedCodec = activeCodec.name
                        }
                        return
                    }
                    if (line.includes("codec") && line.includes("available: yes")) {
                        let parts = line.split(": ")
                        if (parts.length >= 2) {
                            let profile = parts[0].trim()
                            let description = parts[1]
                            let codecMatch = description.match(/codec ([^\)\s]+)/i)
                            let codecName = codecMatch ? codecMatch[1].toUpperCase() : "UNKNOWN"
                            let codecInfo = root.getCodecInfo(codecName)
                            if (codecInfo && !codecFullQueryProcess.availableCodecs.some(c => {
                                                                                             return c.profile === profile
                                                                                         })) {
                                let newCodecs = codecFullQueryProcess.availableCodecs.slice()
                                newCodecs.push({
                                                   "name": codecInfo.name,
                                                   "profile": profile,
                                                   "description": codecInfo.description,
                                                   "qualityColor": codecInfo.qualityColor
                                               })
                                codecFullQueryProcess.availableCodecs = newCodecs
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
                callback(exitCode === 0, exitCode === 0 ? "Codec switched successfully" : "Failed to switch codec")
            }

            // If successful, refresh the codec for this device
            if (exitCode === 0) {
                if (root.adapter && root.adapter.devices) {
                    root.adapter.devices.values.forEach(device => {
                                                            if (device && root.getCardName(device) === cardName) {
                                                                Qt.callLater(() => root.refreshDeviceCodec(device))
                                                            }
                                                        })
                }
            }

            callback = null
        }
    }
}
