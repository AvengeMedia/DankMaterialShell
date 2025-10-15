pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Common

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    property bool suppressOSD: true
    property bool soundsAvailable: false

    property var volumeChangeSound: null
    property var powerPlugSound: null
    property var powerUnplugSound: null
    property var normalNotificationSound: null
    property var criticalNotificationSound: null

    signal micMuteChanged

    Timer {
        id: startupTimer
        interval: 500
        repeat: false
        running: true
        onTriggered: root.suppressOSD = false
    }

    function detectSoundsAvailability() {
        try {
            const testObj = Qt.createQmlObject(`
                import QtQuick
                import QtMultimedia
                Item {}
            `, root, "AudioService.TestComponent")
            if (testObj) {
                testObj.destroy()
            }
            soundsAvailable = true
            return true
        } catch (e) {
            soundsAvailable = false
            return false
        }
    }

    function createSoundPlayers() {
        if (!soundsAvailable) {
            return
        }

        try {
            volumeChangeSound = Qt.createQmlObject(`
                import QtQuick
                import QtMultimedia
                MediaPlayer {
                    source: Qt.resolvedUrl("../assets/sounds/freedesktop/audio-volume-change.wav")
                    audioOutput: AudioOutput { volume: 1.0 }
                }
            `, root, "AudioService.VolumeChangeSound")

            powerPlugSound = Qt.createQmlObject(`
                import QtQuick
                import QtMultimedia
                MediaPlayer {
                    source: Qt.resolvedUrl("../assets/sounds/plasma/power-plug.wav")
                    audioOutput: AudioOutput { volume: 1.0 }
                }
            `, root, "AudioService.PowerPlugSound")

            powerUnplugSound = Qt.createQmlObject(`
                import QtQuick
                import QtMultimedia
                MediaPlayer {
                    source: Qt.resolvedUrl("../assets/sounds/plasma/power-unplug.wav")
                    audioOutput: AudioOutput { volume: 1.0 }
                }
            `, root, "AudioService.PowerUnplugSound")

            normalNotificationSound = Qt.createQmlObject(`
                import QtQuick
                import QtMultimedia
                MediaPlayer {
                    source: Qt.resolvedUrl("../assets/sounds/freedesktop/message.wav")
                    audioOutput: AudioOutput { volume: 1.0 }
                }
            `, root, "AudioService.NormalNotificationSound")

            criticalNotificationSound = Qt.createQmlObject(`
                import QtQuick
                import QtMultimedia
                MediaPlayer {
                    source: Qt.resolvedUrl("../assets/sounds/freedesktop/message-new-instant.wav")
                    audioOutput: AudioOutput { volume: 1.0 }
                }
            `, root, "AudioService.CriticalNotificationSound")
        } catch (e) {
            console.warn("AudioService: Error creating sound players:", e)
        }
    }

    function playVolumeChangeSound() {
        if (soundsAvailable && volumeChangeSound) {
            volumeChangeSound.play()
        }
    }

    function playPowerPlugSound() {
        if (soundsAvailable && powerPlugSound) {
            powerPlugSound.play()
        }
    }

    function playPowerUnplugSound() {
        if (soundsAvailable && powerUnplugSound) {
            powerUnplugSound.play()
        }
    }

    function playNormalNotificationSound() {
        if (soundsAvailable && normalNotificationSound) {
            normalNotificationSound.play()
        }
    }

    function playCriticalNotificationSound() {
        if (soundsAvailable && criticalNotificationSound) {
            criticalNotificationSound.play()
        }
    }

    Timer {
        id: volumeSoundDebounce
        interval: 50
        repeat: false
        onTriggered: {
            if (!root.suppressOSD && SettingsData.soundsEnabled && SettingsData.soundVolumeChanged) {
                root.playVolumeChangeSound()
            }
        }
    }

    Connections {
        target: root.sink && root.sink.audio ? root.sink.audio : null
        enabled: root.sink && root.sink.audio
        ignoreUnknownSignals: true

        function onVolumeChanged() {
            volumeSoundDebounce.restart()
        }
    }

    function displayName(node) {
        if (!node) {
            return ""
        }

        if (node.properties && node.properties["device.description"]) {
            return node.properties["device.description"]
        }

        if (node.description && node.description !== node.name) {
            return node.description
        }

        if (node.nickname && node.nickname !== node.name) {
            return node.nickname
        }

        if (node.name.includes("analog-stereo")) {
            return "Built-in Speakers"
        }
        if (node.name.includes("bluez")) {
            return "Bluetooth Audio"
        }
        if (node.name.includes("usb")) {
            return "USB Audio"
        }
        if (node.name.includes("hdmi")) {
            return "HDMI Audio"
        }

        return node.name
    }

    function subtitle(name) {
        if (!name) {
            return ""
        }

        if (name.includes('usb-')) {
            if (name.includes('SteelSeries')) {
                return "USB Gaming Headset"
            }
            if (name.includes('Generic')) {
                return "USB Audio Device"
            }
            return "USB Audio"
        }

        if (name.includes('pci-')) {
            if (name.includes('01_00.1') || name.includes('01:00.1')) {
                return "NVIDIA GPU Audio"
            }
            return "PCI Audio"
        }

        if (name.includes('bluez')) {
            return "Bluetooth Audio"
        }
        if (name.includes('analog')) {
            return "Built-in Audio"
        }
        if (name.includes('hdmi')) {
            return "HDMI Audio"
        }

        return ""
    }

    PwObjectTracker {
        objects: Pipewire.nodes.values.filter(node => node.audio && !node.isStream)
    }

    function setVolume(percentage) {
        if (!root.sink?.audio) {
            return "No audio sink available"
        }

        const clampedVolume = Math.max(0, Math.min(100, percentage))
        root.sink.audio.volume = clampedVolume / 100
        return `Volume set to ${clampedVolume}%`
    }

    function toggleMute() {
        if (!root.sink?.audio) {
            return "No audio sink available"
        }

        root.sink.audio.muted = !root.sink.audio.muted
        return root.sink.audio.muted ? "Audio muted" : "Audio unmuted"
    }

    function setMicVolume(percentage) {
        if (!root.source?.audio) {
            return "No audio source available"
        }

        const clampedVolume = Math.max(0, Math.min(100, percentage))
        root.source.audio.volume = clampedVolume / 100
        return `Microphone volume set to ${clampedVolume}%`
    }

    function toggleMicMute() {
        if (!root.source?.audio) {
            return "No audio source available"
        }

        root.source.audio.muted = !root.source.audio.muted
        return root.source.audio.muted ? "Microphone muted" : "Microphone unmuted"
    }

    IpcHandler {
        target: "audio"

        function setvolume(percentage: string): string {
            return root.setVolume(parseInt(percentage))
        }

        function increment(step: string): string {
            if (!root.sink?.audio) {
                return "No audio sink available"
            }

            if (root.sink.audio.muted) {
                root.sink.audio.muted = false
            }

            const currentVolume = Math.round(root.sink.audio.volume * 100)
            const stepValue = parseInt(step || "5")
            const newVolume = Math.max(0, Math.min(100, currentVolume + stepValue))

            root.sink.audio.volume = newVolume / 100
            return `Volume increased to ${newVolume}%`
        }

        function decrement(step: string): string {
            if (!root.sink?.audio) {
                return "No audio sink available"
            }

            if (root.sink.audio.muted) {
                root.sink.audio.muted = false
            }

            const currentVolume = Math.round(root.sink.audio.volume * 100)
            const stepValue = parseInt(step || "5")
            const newVolume = Math.max(0, Math.min(100, currentVolume - stepValue))

            root.sink.audio.volume = newVolume / 100
            return `Volume decreased to ${newVolume}%`
        }

        function mute(): string {
            return root.toggleMute()
        }

        function setmic(percentage: string): string {
            return root.setMicVolume(parseInt(percentage))
        }

        function micmute(): string {
            const result = root.toggleMicMute()
            root.micMuteChanged()
            return result
        }

        function status(): string {
            let result = "Audio Status:\n"

            if (root.sink?.audio) {
                const volume = Math.round(root.sink.audio.volume * 100)
                const muteStatus = root.sink.audio.muted ? " (muted)" : ""
                result += `Output: ${volume}%${muteStatus}\n`
            } else {
                result += "Output: No sink available\n"
            }

            if (root.source?.audio) {
                const micVolume = Math.round(root.source.audio.volume * 100)
                const muteStatus = root.source.audio.muted ? " (muted)" : ""
                result += `Input: ${micVolume}%${muteStatus}`
            } else {
                result += "Input: No source available"
            }

            return result
        }
    }

    Component.onCompleted: {
        if (!detectSoundsAvailability()) {
            console.warn("AudioService: QtMultimedia not available - sound effects disabled")
        } else {
            console.log("AudioService: Sound effects enabled")
            createSoundPlayers()
        }
    }
}
