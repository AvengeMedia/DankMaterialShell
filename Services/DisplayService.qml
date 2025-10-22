pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    property bool brightnessAvailable: devices.length > 0
    property var devices: []
    property var ddcDevices: []
    property var deviceBrightness: ({})
    property var ddcPendingInit: ({})
    property string currentDevice: ""
    property string lastIpcDevice: ""
    property bool ddcAvailable: false
    property var ddcInitQueue: []
    property bool skipDdcRead: false
    property int brightnessLevel: {
        const deviceToUse = lastIpcDevice === "" ? getDefaultDevice() : (lastIpcDevice || currentDevice)
        if (!deviceToUse) {
            return 50
        }

        return getDeviceBrightness(deviceToUse)
    }
    property int maxBrightness: 100
    property bool brightnessInitialized: false

    signal brightnessChanged
    signal deviceSwitched

    property bool nightModeActive: nightModeEnabled

    property bool nightModeEnabled: false
    property bool automationAvailable: false
    property bool gammaControlAvailable: false
    readonly property int dayTemp: 6500

    function setBrightnessInternal(percentage, device) {
        const clampedValue = Math.max(1, Math.min(100, percentage))
        const actualDevice = device === "" ? getDefaultDevice() : (device || currentDevice || getDefaultDevice())

        if (actualDevice) {
            const newBrightness = Object.assign({}, deviceBrightness)
            newBrightness[actualDevice] = clampedValue
            deviceBrightness = newBrightness
        }

        const deviceInfo = getCurrentDeviceInfoByName(actualDevice)

        if (deviceInfo && deviceInfo.class === "ddc") {
            ddcBrightnessSetProcess.command = ["ddcutil", "setvcp", "-d", String(deviceInfo.ddcDisplay), "10", String(clampedValue)]
            ddcBrightnessSetProcess.running = true
        } else {
            if (device) {
                brightnessSetProcess.command = ["brightnessctl", "-d", device, "set", `${clampedValue}%`]
            } else {
                brightnessSetProcess.command = ["brightnessctl", "set", `${clampedValue}%`]
            }
            brightnessSetProcess.running = true
        }
    }

    function setBrightness(percentage, device) {
        setBrightnessInternal(percentage, device)
        brightnessChanged()
    }

    function setCurrentDevice(deviceName, saveToSession = false) {
        if (currentDevice === deviceName) {
            return
        }

        currentDevice = deviceName
        lastIpcDevice = deviceName

        if (saveToSession) {
            SessionData.setLastBrightnessDevice(deviceName)
        }

        deviceSwitched()

        const deviceInfo = getCurrentDeviceInfoByName(deviceName)
        if (deviceInfo && deviceInfo.class === "ddc") {
            return
        } else {
            brightnessGetProcess.command = ["brightnessctl", "-m", "-d", deviceName, "get"]
            brightnessGetProcess.running = true
        }
    }

    function refreshDevices() {
        deviceListProcess.running = true
    }

    function refreshDevicesInternal() {
        const allDevices = [...devices, ...ddcDevices]

        allDevices.sort((a, b) => {
                            if (a.class === "backlight" && b.class !== "backlight") {
                                return -1
                            }
                            if (a.class !== "backlight" && b.class === "backlight") {
                                return 1
                            }

                            if (a.class === "ddc" && b.class !== "ddc" && b.class !== "backlight") {
                                return -1
                            }
                            if (a.class !== "ddc" && b.class === "ddc" && a.class !== "backlight") {
                                return 1
                            }

                            return a.name.localeCompare(b.name)
                        })

        devices = allDevices

        if (devices.length > 0 && !currentDevice) {
            const lastDevice = SessionData.lastBrightnessDevice || ""
            const deviceExists = devices.some(d => d.name === lastDevice)
            if (deviceExists) {
                setCurrentDevice(lastDevice, false)
            } else {
                const nonKbdDevice = devices.find(d => !d.name.includes("kbd")) || devices[0]
                setCurrentDevice(nonKbdDevice.name, false)
            }
        }
    }

    function getDeviceBrightness(deviceName) {
        if (!deviceName) {
            return
        } 50

        const deviceInfo = getCurrentDeviceInfoByName(deviceName)
        if (!deviceInfo) {
            return 50
        }

        if (deviceInfo.class === "ddc") {
            return deviceBrightness[deviceName] || 50
        }

        return deviceBrightness[deviceName] || deviceInfo.percentage || 50
    }

    function getDefaultDevice() {
        for (const device of devices) {
            if (device.class === "backlight") {
                return device.name
            }
        }
        return devices.length > 0 ? devices[0].name : ""
    }

    function getCurrentDeviceInfo() {
        const deviceToUse = lastIpcDevice === "" ? getDefaultDevice() : (lastIpcDevice || currentDevice)
        if (!deviceToUse) {
            return null
        }

        for (const device of devices) {
            if (device.name === deviceToUse) {
                return device
            }
        }
        return null
    }

    function isCurrentDeviceReady() {
        const deviceToUse = lastIpcDevice === "" ? getDefaultDevice() : (lastIpcDevice || currentDevice)
        if (!deviceToUse) {
            return false
        }

        if (ddcPendingInit[deviceToUse]) {
            return false
        }

        return true
    }

    function getCurrentDeviceInfoByName(deviceName) {
        if (!deviceName) {
            return null
        }

        for (const device of devices) {
            if (device.name === deviceName) {
                return device
            }
        }
        return null
    }

    function processNextDdcInit() {
        if (ddcInitQueue.length === 0 || ddcInitialBrightnessProcess.running) {
            return
        }

        const displayId = ddcInitQueue.shift()
        ddcInitialBrightnessProcess.command = ["ddcutil", "getvcp", "-d", String(displayId), "10", "--brief"]
        ddcInitialBrightnessProcess.running = true
    }

    // Night Mode Functions - Simplified
    function enableNightMode() {
        if (!gammaControlAvailable) {
            ToastService.showWarning("Night mode failed: DMS gamma control not available")
            return
        }

        nightModeEnabled = true
        SessionData.setNightModeEnabled(true)

        DMSService.sendRequest("wayland.gamma.setEnabled", {
            "enabled": true
        }, response => {
            if (response.error) {
                console.error("DisplayService: Failed to enable gamma control:", response.error)
                ToastService.showError("Failed to enable night mode: " + response.error)
                nightModeEnabled = false
                SessionData.setNightModeEnabled(false)
                return
            }

            if (SessionData.nightModeAutoEnabled) {
                startAutomation()
            } else {
                applyNightModeDirectly()
            }
        })
    }

    function disableNightMode() {
        nightModeEnabled = false
        SessionData.setNightModeEnabled(false)

        if (!gammaControlAvailable) {
            return
        }

        DMSService.sendRequest("wayland.gamma.setEnabled", {
            "enabled": false
        }, response => {
            if (response.error) {
                console.error("DisplayService: Failed to disable gamma control:", response.error)
                ToastService.showError("Failed to disable night mode: " + response.error)
            }
        })
    }

    function toggleNightMode() {
        if (nightModeEnabled) {
            disableNightMode()
        } else {
            enableNightMode()
        }
    }

    function applyNightModeDirectly() {
        const temperature = SessionData.nightModeTemperature || 4000

        DMSService.sendRequest("wayland.gamma.setManualTimes", {
            "sunrise": null,
            "sunset": null
        }, response => {
            if (response.error) {
                console.error("DisplayService: Failed to clear manual times:", response.error)
                return
            }

            DMSService.sendRequest("wayland.gamma.setUseIPLocation", {
                "use": false
            }, response => {
                if (response.error) {
                    console.error("DisplayService: Failed to disable IP location:", response.error)
                    return
                }

                DMSService.sendRequest("wayland.gamma.setTemperature", {
                    "temp": temperature
                }, response => {
                    if (response.error) {
                        console.error("DisplayService: Failed to set temperature:", response.error)
                        ToastService.showError("Failed to set night mode temperature: " + response.error)
                    }
                })
            })
        })
    }

    function startAutomation() {
        if (!automationAvailable) {
            return
        }

        const mode = SessionData.nightModeAutoMode || "time"

        switch (mode) {
        case "time":
            startTimeBasedMode()
            break
        case "location":
            startLocationBasedMode()
            break
        }
    }

    function startTimeBasedMode() {
        const temperature = SessionData.nightModeTemperature || 4000
        const sunriseHour = SessionData.nightModeEndHour
        const sunriseMinute = SessionData.nightModeEndMinute
        const sunsetHour = SessionData.nightModeStartHour
        const sunsetMinute = SessionData.nightModeStartMinute

        const sunrise = `${String(sunriseHour).padStart(2, '0')}:${String(sunriseMinute).padStart(2, '0')}`
        const sunset = `${String(sunsetHour).padStart(2, '0')}:${String(sunsetMinute).padStart(2, '0')}`

        DMSService.sendRequest("wayland.gamma.setUseIPLocation", {
            "use": false
        }, response => {
            if (response.error) {
                console.error("DisplayService: Failed to disable IP location:", response.error)
                return
            }

            DMSService.sendRequest("wayland.gamma.setTemperature", {
                "low": temperature,
                "high": dayTemp
            }, response => {
                if (response.error) {
                    console.error("DisplayService: Failed to set temperature:", response.error)
                    ToastService.showError("Failed to set night mode temperature: " + response.error)
                    return
                }

                DMSService.sendRequest("wayland.gamma.setManualTimes", {
                    "sunrise": sunrise,
                    "sunset": sunset
                }, response => {
                    if (response.error) {
                        console.error("DisplayService: Failed to set manual times:", response.error)
                        ToastService.showError("Failed to set night mode schedule: " + response.error)
                    }
                })
            })
        })
    }

    function startLocationBasedMode() {
        const temperature = SessionData.nightModeTemperature || 4000
        const dayTemp = 6500

        DMSService.sendRequest("wayland.gamma.setManualTimes", {
            "sunrise": null,
            "sunset": null
        }, response => {
            if (response.error) {
                console.error("DisplayService: Failed to clear manual times:", response.error)
                return
            }

            DMSService.sendRequest("wayland.gamma.setTemperature", {
                "low": temperature,
                "high": dayTemp
            }, response => {
                if (response.error) {
                    console.error("DisplayService: Failed to set temperature:", response.error)
                    ToastService.showError("Failed to set night mode temperature: " + response.error)
                    return
                }

                if (SessionData.nightModeUseIPLocation) {
                    DMSService.sendRequest("wayland.gamma.setUseIPLocation", {
                        "use": true
                    }, response => {
                        if (response.error) {
                            console.error("DisplayService: Failed to enable IP location:", response.error)
                            ToastService.showError("Failed to enable IP location: " + response.error)
                        }
                    })
                } else if (SessionData.latitude !== 0.0 && SessionData.longitude !== 0.0) {
                    DMSService.sendRequest("wayland.gamma.setUseIPLocation", {
                        "use": false
                    }, response => {
                        if (response.error) {
                            console.error("DisplayService: Failed to disable IP location:", response.error)
                            return
                        }

                        DMSService.sendRequest("wayland.gamma.setLocation", {
                            "latitude": SessionData.latitude,
                            "longitude": SessionData.longitude
                        }, response => {
                            if (response.error) {
                                console.error("DisplayService: Failed to set location:", response.error)
                                ToastService.showError("Failed to set night mode location: " + response.error)
                            }
                        })
                    })
                } else {
                    console.warn("DisplayService: Location mode selected but no coordinates set and IP location disabled")
                }
            })
        })
    }

    function setNightModeAutomationMode(mode) {
        SessionData.setNightModeAutoMode(mode)
    }

    function evaluateNightMode() {
        if (!nightModeEnabled) {
            return
        }

        if (SessionData.nightModeAutoEnabled) {
            restartTimer.nextAction = "automation"
            restartTimer.start()
        } else {
            restartTimer.nextAction = "direct"
            restartTimer.start()
        }
    }

    function checkGammaControlAvailability() {
        if (!DMSService.isConnected) {
            return
        }

        if (DMSService.apiVersion < 6) {
            gammaControlAvailable = false
            automationAvailable = false
            return
        }

        if (!DMSService.capabilities.includes("gamma")) {
            gammaControlAvailable = false
            automationAvailable = false
            return
        }

        DMSService.sendRequest("wayland.gamma.getState", null, response => {
            if (response.error) {
                gammaControlAvailable = false
                automationAvailable = false
                console.error("DisplayService: Gamma control not available:", response.error)
            } else {
                gammaControlAvailable = true
                automationAvailable = true

                if (nightModeEnabled) {
                    DMSService.sendRequest("wayland.gamma.setEnabled", {
                        "enabled": true
                    }, enableResponse => {
                        if (enableResponse.error) {
                            console.error("DisplayService: Failed to enable gamma control on startup:", enableResponse.error)
                            return
                        }

                        if (SessionData.nightModeAutoEnabled) {
                            startAutomation()
                        } else {
                            applyNightModeDirectly()
                        }
                    })
                }
            }
        })
    }

    Timer {
        id: restartTimer
        property string nextAction: ""
        interval: 100
        repeat: false

        onTriggered: {
            if (nextAction === "automation") {
                startAutomation()
            } else if (nextAction === "direct") {
                applyNightModeDirectly()
            }
            nextAction = ""
        }
    }

    Component.onCompleted: {
        ddcDetectionProcess.running = true
        refreshDevices()
        nightModeEnabled = SessionData.nightModeEnabled
    }

    Process {
        id: ddcDetectionProcess

        command: ["which", "ddcutil"]
        running: false

        onExited: function (exitCode) {
            ddcAvailable = (exitCode === 0)
            if (ddcAvailable) {
                ddcDisplayDetectionProcess.running = true
            } else {
                console.log("DisplayService: ddcutil not available")
            }
        }
    }

    Process {
        id: ddcDisplayDetectionProcess

        command: ["bash", "-c", "ddcutil detect --brief 2>/dev/null | grep '^Display [0-9]' | awk '{print \"{\\\"display\\\":\" $2 \",\\\"name\\\":\\\"ddc-\" $2 \"\\\",\\\"class\\\":\\\"ddc\\\"}\"}' | tr '\\n' ',' | sed 's/,$//' | sed 's/^/[/' | sed 's/$/]/' || echo '[]'"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) {
                    ddcDevices = []
                    return
                }

                try {
                    const parsedDevices = JSON.parse(text.trim())
                    const newDdcDevices = []

                    for (const device of parsedDevices) {
                        if (device.display && device.class === "ddc") {
                            newDdcDevices.push({
                                                   "name": device.name,
                                                   "class": "ddc",
                                                   "current": 50,
                                                   "percentage": 50,
                                                   "max": 100,
                                                   "ddcDisplay": device.display
                                               })
                        }
                    }

                    ddcDevices = newDdcDevices
                    console.log("DisplayService: Found", ddcDevices.length, "DDC displays")

                    // Queue initial brightness readings for DDC devices
                    ddcInitQueue = []
                    for (const device of ddcDevices) {
                        ddcInitQueue.push(device.ddcDisplay)
                        // Mark DDC device as pending initialization
                        ddcPendingInit[device.name] = true
                    }

                    // Start processing the queue
                    processNextDdcInit()

                    // Refresh device list to include DDC devices
                    refreshDevicesInternal()

                    // Retry setting last device now that DDC devices are available
                    const lastDevice = SessionData.lastBrightnessDevice || ""
                    if (lastDevice) {
                        const deviceExists = devices.some(d => d.name === lastDevice)
                        if (deviceExists && (!currentDevice || currentDevice !== lastDevice)) {
                            setCurrentDevice(lastDevice, false)
                        }
                    }
                } catch (error) {
                    console.warn("DisplayService: Failed to parse DDC devices:", error)
                    ddcDevices = []
                }
            }
        }

        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.warn("DisplayService: Failed to detect DDC displays:", exitCode)
                ddcDevices = []
            }
        }
    }

    Process {
        id: deviceListProcess

        command: ["brightnessctl", "-m", "-l"]
        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.warn("DisplayService: Failed to list devices:", exitCode)
                brightnessAvailable = false
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) {
                    console.warn("DisplayService: No devices found")
                    return
                }
                const lines = text.trim().split("\n")
                const newDevices = []
                for (const line of lines) {
                    const parts = line.split(",")
                    if (parts.length >= 5) {
                        newDevices.push({
                                            "name": parts[0],
                                            "class": parts[1],
                                            "current": parseInt(parts[2]),
                                            "percentage": parseInt(parts[3]),
                                            "max": parseInt(parts[4])
                                        })
                    }
                }
                // Store brightnessctl devices separately
                devices = newDevices

                // Always refresh to combine with DDC devices and set up device selection
                refreshDevicesInternal()
            }
        }
    }

    Process {
        id: brightnessSetProcess

        running: false
        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.warn("DisplayService: Failed to set brightness:", exitCode)
            }
        }
    }

    Process {
        id: ddcBrightnessSetProcess

        running: false
        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.warn("DisplayService: Failed to set DDC brightness:", exitCode)
            }
        }
    }

    Process {
        id: ddcInitialBrightnessProcess

        running: false
        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.warn("DisplayService: Failed to get initial DDC brightness:", exitCode)
            }

            processNextDdcInit()
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                return

                const parts = text.trim().split(" ")
                if (parts.length >= 5) {
                    const current = parseInt(parts[3]) || 50
                    const max = parseInt(parts[4]) || 100
                    const brightness = Math.round((current / max) * 100)

                    const commandParts = ddcInitialBrightnessProcess.command
                    if (commandParts && commandParts.length >= 4) {
                        const displayId = commandParts[3]
                        const deviceName = "ddc-" + displayId

                        var newBrightness = Object.assign({}, deviceBrightness)
                        newBrightness[deviceName] = brightness
                        deviceBrightness = newBrightness

                        var newPending = Object.assign({}, ddcPendingInit)
                        delete newPending[deviceName]
                        ddcPendingInit = newPending

                        console.log("DisplayService: Initial DDC Device", deviceName, "brightness:", brightness + "%")
                    }
                }
            }
        }
    }

    Process {
        id: brightnessGetProcess

        running: false
        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.warn("DisplayService: Failed to get brightness:", exitCode)
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                return

                const parts = text.trim().split(",")
                if (parts.length >= 5) {
                    const current = parseInt(parts[2])
                    const max = parseInt(parts[4])
                    maxBrightness = max
                    const brightness = Math.round((current / max) * 100)

                    // Update the device brightness cache
                    if (currentDevice) {
                        var newBrightness = Object.assign({}, deviceBrightness)
                        newBrightness[currentDevice] = brightness
                        deviceBrightness = newBrightness
                    }

                    brightnessInitialized = true
                    console.log("DisplayService: Device", currentDevice, "brightness:", brightness + "%")
                    brightnessChanged()
                }
            }
        }
    }

    Process {
        id: ddcBrightnessGetProcess

        running: false
        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.warn("DisplayService: Failed to get DDC brightness:", exitCode)
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                return

                // Parse ddcutil getvcp output format: "VCP 10 C 50 100"
                const parts = text.trim().split(" ")
                if (parts.length >= 5) {
                    const current = parseInt(parts[3]) || 50
                    const max = parseInt(parts[4]) || 100
                    maxBrightness = max
                    const brightness = Math.round((current / max) * 100)

                    // Update the device brightness cache
                    if (currentDevice) {
                        var newBrightness = Object.assign({}, deviceBrightness)
                        newBrightness[currentDevice] = brightness
                        deviceBrightness = newBrightness
                    }

                    brightnessInitialized = true
                    console.log("DisplayService: DDC Device", currentDevice, "brightness:", brightness + "%")
                    brightnessChanged()
                }
            }
        }
    }

    Connections {
        target: DMSService

        function onConnectionStateChanged() {
            if (DMSService.isConnected) {
                checkGammaControlAvailability()
            } else {
                gammaControlAvailable = false
                automationAvailable = false
            }
        }

        function onCapabilitiesReceived() {
            checkGammaControlAvailability()
        }
    }

    // Session Data Connections
    Connections {
        target: SessionData

        function onNightModeEnabledChanged() {
            nightModeEnabled = SessionData.nightModeEnabled
            evaluateNightMode()
        }

        function onNightModeAutoEnabledChanged() {
            evaluateNightMode()
        }
        function onNightModeAutoModeChanged() {
            evaluateNightMode()
        }
        function onNightModeStartHourChanged() {
            evaluateNightMode()
        }
        function onNightModeStartMinuteChanged() {
            evaluateNightMode()
        }
        function onNightModeEndHourChanged() {
            evaluateNightMode()
        }
        function onNightModeEndMinuteChanged() {
            evaluateNightMode()
        }
        function onNightModeTemperatureChanged() {
            evaluateNightMode()
        }
        function onLatitudeChanged() {
            evaluateNightMode()
        }
        function onLongitudeChanged() {
            evaluateNightMode()
        }
        function onNightModeUseIPLocationChanged() {
            evaluateNightMode()
        }
    }

    // IPC Handler for external control
    IpcHandler {
        function set(percentage: string, device: string): string {
            if (!root.brightnessAvailable) {
                return "Brightness control not available"
            }

            const value = parseInt(percentage)
            if (isNaN(value)) {
                return "Invalid brightness value: " + percentage
            }

            const clampedValue = Math.max(1, Math.min(100, value))
            const targetDevice = device || ""

            // Ensure device exists if specified
            if (targetDevice && !root.devices.some(d => d.name === targetDevice)) {
                return "Device not found: " + targetDevice
            }

            root.lastIpcDevice = targetDevice
            if (targetDevice && targetDevice !== root.currentDevice) {
                root.setCurrentDevice(targetDevice, false)
            }
            root.setBrightness(clampedValue, targetDevice)

            if (targetDevice) {
                return "Brightness set to " + clampedValue + "% on " + targetDevice
            } else {
                return "Brightness set to " + clampedValue + "%"
            }
        }

        function increment(step: string, device: string): string {
            if (!root.brightnessAvailable) {
                return "Brightness control not available"
            }

            const targetDevice = device || ""
            const actualDevice = targetDevice === "" ? root.getDefaultDevice() : targetDevice

            // Ensure device exists
            if (actualDevice && !root.devices.some(d => d.name === actualDevice)) {
                return "Device not found: " + actualDevice
            }

            const currentLevel = actualDevice ? root.getDeviceBrightness(actualDevice) : root.brightnessLevel
            const stepValue = parseInt(step || "10")
            const newLevel = Math.max(1, Math.min(100, currentLevel + stepValue))

            root.lastIpcDevice = targetDevice
            if (targetDevice && targetDevice !== root.currentDevice) {
                root.setCurrentDevice(targetDevice, false)
            }
            root.setBrightness(newLevel, targetDevice)

            if (targetDevice) {
                return "Brightness increased to " + newLevel + "% on " + targetDevice
            } else {
                return "Brightness increased to " + newLevel + "%"
            }
        }

        function decrement(step: string, device: string): string {
            if (!root.brightnessAvailable) {
                return "Brightness control not available"
            }

            const targetDevice = device || ""
            const actualDevice = targetDevice === "" ? root.getDefaultDevice() : targetDevice

            // Ensure device exists
            if (actualDevice && !root.devices.some(d => d.name === actualDevice)) {
                return "Device not found: " + actualDevice
            }

            const currentLevel = actualDevice ? root.getDeviceBrightness(actualDevice) : root.brightnessLevel
            const stepValue = parseInt(step || "10")
            const newLevel = Math.max(1, Math.min(100, currentLevel - stepValue))

            root.lastIpcDevice = targetDevice
            if (targetDevice && targetDevice !== root.currentDevice) {
                root.setCurrentDevice(targetDevice, false)
            }
            root.setBrightness(newLevel, targetDevice)

            if (targetDevice) {
                return "Brightness decreased to " + newLevel + "% on " + targetDevice
            } else {
                return "Brightness decreased to " + newLevel + "%"
            }
        }

        function status(): string {
            if (!root.brightnessAvailable) {
                return "Brightness control not available"
            }

            return "Device: " + root.currentDevice + " - Brightness: " + root.brightnessLevel + "%"
        }

        function list(): string {
            if (!root.brightnessAvailable) {
                return "No brightness devices available"
            }

            let result = "Available devices:\\n"
            for (const device of root.devices) {
                result += device.name + " (" + device.class + ")\\n"
            }
            return result
        }

        target: "brightness"
    }

    // IPC Handler for night mode control
    IpcHandler {
        function toggle(): string {
            root.toggleNightMode()
            return root.nightModeEnabled ? "Night mode enabled" : "Night mode disabled"
        }

        function enable(): string {
            root.enableNightMode()
            return "Night mode enabled"
        }

        function disable(): string {
            root.disableNightMode()
            return "Night mode disabled"
        }

        function status(): string {
            return root.nightModeEnabled ? "Night mode is enabled" : "Night mode is disabled"
        }

        function temperature(value: string): string {
            if (!value) {
                return "Current temperature: " + SessionData.nightModeTemperature + "K"
            }

            const temp = parseInt(value)
            if (isNaN(temp)) {
                return "Invalid temperature. Use a value between 2500 and 6000 (in steps of 500)"
            }

            // Validate temperature is in valid range and steps
            if (temp < 2500 || temp > 6000) {
                return "Temperature must be between 2500K and 6000K"
            }

            // Round to nearest 500
            const rounded = Math.round(temp / 500) * 500

            SessionData.setNightModeTemperature(rounded)

            // Restart night mode with new temperature if active
            if (root.nightModeEnabled) {
                if (SessionData.nightModeAutoEnabled) {
                    root.startAutomation()
                } else {
                    root.applyNightModeDirectly()
                }
            }

            if (rounded !== temp) {
                return "Night mode temperature set to " + rounded + "K (rounded from " + temp + "K)"
            } else {
                return "Night mode temperature set to " + rounded + "K"
            }
        }

        target: "night"
    }
}
