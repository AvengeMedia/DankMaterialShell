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
    property var deviceBrightness: ({})
    property var deviceBrightnessUserSet: ({})
    property var deviceMaxCache: ({})
    property int brightnessVersion: 0
    property string currentDevice: ""
    property string lastIpcDevice: ""
    property int brightnessLevel: {
        brightnessVersion
        const deviceToUse = lastIpcDevice === "" ? getDefaultDevice() : (lastIpcDevice || currentDevice)
        if (!deviceToUse) {
            return 50
        }

        return getDeviceBrightness(deviceToUse)
    }
    property int maxBrightness: 100
    property bool brightnessInitialized: false

    signal brightnessChanged(bool showOsd)
    signal deviceSwitched

    property bool nightModeActive: nightModeEnabled

    property bool nightModeEnabled: false
    property bool automationAvailable: false
    property bool gammaControlAvailable: false

    function updateSingleDevice(device) {
        const deviceIndex = devices.findIndex(d => d.id === device.id)
        if (deviceIndex !== -1) {
            const newDevices = [...devices]
            const existingDevice = devices[deviceIndex]
            const cachedMax = deviceMaxCache[device.id]

            let displayMax = cachedMax || (device.class === "ddc" ? device.max : 100)
            if (displayMax > 0 && !cachedMax) {
                const newCache = Object.assign({}, deviceMaxCache)
                newCache[device.id] = displayMax
                deviceMaxCache = newCache
            }

            newDevices[deviceIndex] = {
                "id": device.id,
                "name": device.id,
                "class": device.class,
                "current": device.current,
                "percentage": device.currentPercent,
                "max": device.max,
                "backend": device.backend,
                "displayMax": displayMax
            }
            devices = newDevices
        }

        const isExponential = SessionData.getBrightnessExponential(device.id)
        const userSetValue = deviceBrightnessUserSet[device.id]

        let displayValue = device.currentPercent
        if (isExponential) {
            if (userSetValue !== undefined) {
                displayValue = userSetValue
            } else {
                displayValue = linearToExponential(device.currentPercent, device.id)
            }
        }

        const newBrightness = Object.assign({}, deviceBrightness)
        newBrightness[device.id] = displayValue
        deviceBrightness = newBrightness
        brightnessVersion++
    }

    function updateFromBrightnessState(state) {
        if (!state || !state.devices) {
            return
        }

        const newMaxCache = Object.assign({}, deviceMaxCache)
        devices = state.devices.map(d => {
                                              const cachedMax = deviceMaxCache[d.id]
                                              let displayMax = cachedMax || (d.class === "ddc" ? d.max : 100)
                                              if (displayMax > 0 && !cachedMax) {
                                                  newMaxCache[d.id] = displayMax
                                              }
                                              return {
                                                  "id": d.id,
                                                  "name": d.id,
                                                  "class": d.class,
                                                  "current": d.current,
                                                  "percentage": d.currentPercent,
                                                  "max": d.max,
                                                  "backend": d.backend,
                                                  "displayMax": displayMax
                                              }
                                          })
        deviceMaxCache = newMaxCache

        const newBrightness = {}
        for (const device of state.devices) {
            const isExponential = SessionData.getBrightnessExponential(device.id)
            const userSetValue = deviceBrightnessUserSet[device.id]

            if (isExponential) {
                if (userSetValue !== undefined) {
                    newBrightness[device.id] = userSetValue
                } else {
                    newBrightness[device.id] = linearToExponential(device.currentPercent, device.id)
                }
            } else {
                newBrightness[device.id] = device.currentPercent
            }
        }
        deviceBrightness = newBrightness
        brightnessVersion++

        brightnessAvailable = devices.length > 0

        if (devices.length > 0 && !currentDevice) {
            const lastDevice = SessionData.lastBrightnessDevice || ""
            const deviceExists = devices.some(d => d.id === lastDevice)
            if (deviceExists) {
                setCurrentDevice(lastDevice, false)
            } else {
                const backlight = devices.find(d => d.class === "backlight")
                const nonKbdDevice = devices.find(d => !d.id.includes("kbd"))
                const defaultDevice = backlight || nonKbdDevice || devices[0]
                setCurrentDevice(defaultDevice.id, false)
            }
        }

        if (!brightnessInitialized) {
            brightnessInitialized = true
        }
    }

    function setBrightness(percentage, device, suppressOsd) {
        const actualDevice = device === "" ? getDefaultDevice() : (device || currentDevice || getDefaultDevice())

        if (!actualDevice) {
            console.warn("DisplayService: No device selected for brightness change")
            return
        }

        const deviceInfo = getCurrentDeviceInfoByName(actualDevice)
        const isExponential = SessionData.getBrightnessExponential(actualDevice)

        let minValue = 0
        let maxValue = 100

        if (isExponential) {
            minValue = 1
            maxValue = 100
        } else {
            minValue = (deviceInfo && (deviceInfo.class === "backlight" || deviceInfo.class === "ddc")) ? 1 : 0
            maxValue = deviceInfo?.displayMax || 100
        }

        if (maxValue <= 0) {
            console.warn("DisplayService: Invalid max value for device", actualDevice, "- skipping brightness change")
            return
        }

        const clampedValue = Math.max(minValue, Math.min(maxValue, percentage))

        if (!DMSService.isConnected) {
            console.warn("DisplayService: Not connected to DMS")
            return
        }

        const newBrightness = Object.assign({}, deviceBrightness)
        newBrightness[actualDevice] = clampedValue
        deviceBrightness = newBrightness
        brightnessVersion++

        if (isExponential) {
            const newUserSet = Object.assign({}, deviceBrightnessUserSet)
            newUserSet[actualDevice] = clampedValue
            deviceBrightnessUserSet = newUserSet
            SessionData.setBrightnessUserSetValue(actualDevice, clampedValue)
        }

        if (!suppressOsd) {
            brightnessChanged(true)
        }

        const params = {
            "device": actualDevice,
            "percent": clampedValue
        }
        if (isExponential) {
            params.exponential = true
            params.exponent = SessionData.getBrightnessExponent(actualDevice)
        }

        DMSService.sendRequest("brightness.setBrightness", params, response => {
                                   if (response.error) {
                                       console.error("DisplayService: Failed to set brightness:", response.error)
                                       ToastService.showError("Failed to set brightness: " + response.error, "", "", "brightness")
                                   } else {
                                       ToastService.dismissCategory("brightness")
                                   }
                               })
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
    }

    function getDeviceBrightness(deviceName) {
        if (!deviceName) {
            return 50
        }

        if (deviceName in deviceBrightness) {
            return deviceBrightness[deviceName]
        }

        return 50
    }

    function linearToExponential(linearPercent, deviceName) {
        const exponent = SessionData.getBrightnessExponent(deviceName)
        const hardwarePercent = linearPercent / 100.0
        const normalizedPercent = Math.pow(hardwarePercent, 1.0 / exponent)
        return Math.round(normalizedPercent * 100.0)
    }

    function getDefaultDevice() {
        for (const device of devices) {
            if (device.class === "backlight") {
                return device.id
            }
        }
        return devices.length > 0 ? devices[0].id : ""
    }

    function getCurrentDeviceInfo() {
        const deviceToUse = lastIpcDevice === "" ? getDefaultDevice() : (lastIpcDevice || currentDevice)
        if (!deviceToUse) {
            return null
        }

        for (const device of devices) {
            if (device.id === deviceToUse) {
                return device
            }
        }
        return null
    }

    function isCurrentDeviceReady() {
        const deviceToUse = lastIpcDevice === "" ? getDefaultDevice() : (lastIpcDevice || currentDevice)
        return deviceToUse !== ""
    }

    function getCurrentDeviceInfoByName(deviceName) {
        if (!deviceName) {
            return null
        }

        for (const device of devices) {
            if (device.id === deviceName) {
                return device
            }
        }
        return null
    }

    function getDeviceMax(deviceName) {
        const deviceInfo = getCurrentDeviceInfoByName(deviceName)
        if (!deviceInfo) {
            return 100
        }
        return deviceInfo.displayMax || 100
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
                                       ToastService.showError("Failed to enable night mode: " + response.error, "", "", "night-mode")
                                       nightModeEnabled = false
                                       SessionData.setNightModeEnabled(false)
                                       return
                                   }
                                   ToastService.dismissCategory("night-mode")

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
                                       ToastService.showError("Failed to disable night mode: " + response.error, "", "", "night-mode")
                                   } else {
                                       ToastService.dismissCategory("night-mode")
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
                                                                                         "low": temperature,
                                                                                         "high": 6500
                                                                                     }, response => {
                                                                                         if (response.error) {
                                                                                             console.error("DisplayService: Failed to set temperature:", response.error)
                                                                                             ToastService.showError("Failed to set night mode temperature: " + response.error, "", "", "night-mode")
                                                                                         } else {
                                                                                             ToastService.dismissCategory("night-mode")
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
        const highTemp = SessionData.nightModeHighTemperature || 6500
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
                                                              "high": highTemp
                                                          }, response => {
                                                              if (response.error) {
                                                                  console.error("DisplayService: Failed to set temperature:", response.error)
                                                                  ToastService.showError("Failed to set night mode temperature: " + response.error, "", "", "night-mode")
                                                                  return
                                                              }

                                                              DMSService.sendRequest("wayland.gamma.setManualTimes", {
                                                                                         "sunrise": sunrise,
                                                                                         "sunset": sunset
                                                                                     }, response => {
                                                                                         if (response.error) {
                                                                                             console.error("DisplayService: Failed to set manual times:", response.error)
                                                                                             ToastService.showError("Failed to set night mode schedule: " + response.error, "", "", "night-mode")
                                                                                         } else {
                                                                                             ToastService.dismissCategory("night-mode")
                                                                                         }
                                                                                     })
                                                          })
                               })
    }

    function startLocationBasedMode() {
        const temperature = SessionData.nightModeTemperature || 4000
        const highTemp = SessionData.nightModeHighTemperature || 6500

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
                                                              "high": highTemp
                                                          }, response => {
                                                              if (response.error) {
                                                                  console.error("DisplayService: Failed to set temperature:", response.error)
                                                                  ToastService.showError("Failed to set night mode temperature: " + response.error, "", "", "night-mode")
                                                                  return
                                                              }

                                                              if (SessionData.nightModeUseIPLocation) {
                                                                  DMSService.sendRequest("wayland.gamma.setUseIPLocation", {
                                                                                             "use": true
                                                                                         }, response => {
                                                                                             if (response.error) {
                                                                                                 console.error("DisplayService: Failed to enable IP location:", response.error)
                                                                                                 ToastService.showError("Failed to enable IP location: " + response.error, "", "", "night-mode")
                                                                                             } else {
                                                                                                 ToastService.dismissCategory("night-mode")
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
                                                                                                                            ToastService.showError("Failed to set night mode location: " + response.error, "", "", "night-mode")
                                                                                                                        } else {
                                                                                                                            ToastService.dismissCategory("night-mode")
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

    function rescanDevices() {
        if (!DMSService.isConnected) {
            return
        }

        DMSService.sendRequest("brightness.rescan", null, response => {
                                   if (response.error) {
                                       console.error("DisplayService: Failed to rescan brightness devices:", response.error)
                                   }
                               })
    }

    function updateDeviceBrightnessDisplay(deviceName) {
        brightnessVersion++
        brightnessChanged()
    }

    Component.onCompleted: {
        nightModeEnabled = SessionData.nightModeEnabled
        deviceBrightnessUserSet = Object.assign({}, SessionData.brightnessUserSetValues)
        if (DMSService.isConnected) {
            checkGammaControlAvailability()
        }
    }

    Connections {
        target: Quickshell

        function onScreensChanged() {
            rescanDevices()
        }
    }

    Connections {
        target: DMSService

        function onConnectionStateChanged() {
            if (DMSService.isConnected) {
                checkGammaControlAvailability()
            } else {
                brightnessAvailable = false
                gammaControlAvailable = false
                automationAvailable = false
            }
        }

        function onCapabilitiesReceived() {
            checkGammaControlAvailability()
        }

        function onBrightnessStateUpdate(data) {
            updateFromBrightnessState(data)
        }

        function onBrightnessDeviceUpdate(device) {
            updateSingleDevice(device)
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
        function onNightModeHighTemperatureChanged() {
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

            const targetDevice = device || ""

            if (targetDevice && !root.devices.some(d => d.id === targetDevice)) {
                return "Device not found: " + targetDevice
            }

            const deviceInfo = targetDevice ? root.getCurrentDeviceInfoByName(targetDevice) : null
            const minValue = (deviceInfo && (deviceInfo.class === "backlight" || deviceInfo.class === "ddc")) ? 1 : 0
            const clampedValue = Math.max(minValue, Math.min(100, value))

            root.lastIpcDevice = targetDevice
            if (targetDevice && targetDevice !== root.currentDevice) {
                root.setCurrentDevice(targetDevice, false)
            }
            root.setBrightness(clampedValue, targetDevice, false)

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

            if (actualDevice && !root.devices.some(d => d.id === actualDevice)) {
                return "Device not found: " + actualDevice
            }

            const stepValue = parseInt(step || "5")

            root.lastIpcDevice = actualDevice
            if (actualDevice && actualDevice !== root.currentDevice) {
                root.setCurrentDevice(actualDevice, false)
            }

            const isExponential = SessionData.getBrightnessExponential(actualDevice)
            const currentBrightness = root.getDeviceBrightness(actualDevice)
            const deviceInfo = root.getCurrentDeviceInfoByName(actualDevice)

            let maxValue = 100
            if (isExponential) {
                maxValue = 100
            } else {
                maxValue = deviceInfo?.displayMax || 100
            }

            const newBrightness = Math.min(maxValue, currentBrightness + stepValue)

            root.setBrightness(newBrightness, actualDevice, false)

            return "Brightness increased by " + stepValue + "%" + (targetDevice ? " on " + targetDevice : "")
        }

        function decrement(step: string, device: string): string {
            if (!root.brightnessAvailable) {
                return "Brightness control not available"
            }

            const targetDevice = device || ""
            const actualDevice = targetDevice === "" ? root.getDefaultDevice() : targetDevice

            if (actualDevice && !root.devices.some(d => d.id === actualDevice)) {
                return "Device not found: " + actualDevice
            }

            const stepValue = parseInt(step || "5")

            root.lastIpcDevice = actualDevice
            if (actualDevice && actualDevice !== root.currentDevice) {
                root.setCurrentDevice(actualDevice, false)
            }

            const isExponential = SessionData.getBrightnessExponential(actualDevice)
            const currentBrightness = root.getDeviceBrightness(actualDevice)
            const deviceInfo = root.getCurrentDeviceInfoByName(actualDevice)

            let minValue = 0
            if (isExponential) {
                minValue = 1
            } else {
                minValue = (deviceInfo && (deviceInfo.class === "backlight" || deviceInfo.class === "ddc")) ? 1 : 0
            }

            const newBrightness = Math.max(minValue, currentBrightness - stepValue)

            root.setBrightness(newBrightness, actualDevice, false)

            return "Brightness decreased by " + stepValue + "%" + (targetDevice ? " on " + targetDevice : "")
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

            let result = "Available devices:\n"
            for (const device of root.devices) {
                const isExp = SessionData.getBrightnessExponential(device.id)
                result += device.id + " (" + device.class + ")" + (isExp ? " [exponential]" : "") + "\n"
            }
            return result
        }

        function enableExponential(device: string): string {
            const targetDevice = device || root.currentDevice
            if (!targetDevice) {
                return "No device specified"
            }

            if (!root.devices.some(d => d.id === targetDevice)) {
                return "Device not found: " + targetDevice
            }

            SessionData.setBrightnessExponential(targetDevice, true)
            return "Exponential mode enabled for " + targetDevice
        }

        function disableExponential(device: string): string {
            const targetDevice = device || root.currentDevice
            if (!targetDevice) {
                return "No device specified"
            }

            if (!root.devices.some(d => d.id === targetDevice)) {
                return "Device not found: " + targetDevice
            }

            SessionData.setBrightnessExponential(targetDevice, false)
            return "Exponential mode disabled for " + targetDevice
        }

        function toggleExponential(device: string): string {
            const targetDevice = device || root.currentDevice
            if (!targetDevice) {
                return "No device specified"
            }

            if (!root.devices.some(d => d.id === targetDevice)) {
                return "Device not found: " + targetDevice
            }

            const currentState = SessionData.getBrightnessExponential(targetDevice)
            SessionData.setBrightnessExponential(targetDevice, !currentState)
            return "Exponential mode " + (!currentState ? "enabled" : "disabled") + " for " + targetDevice
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
