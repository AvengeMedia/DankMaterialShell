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
    property bool gsettingsAvailable: false
    property var availableSoundThemes: []
    property string currentSoundTheme: ""
    property var soundFilePaths: ({})

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

    function checkGsettings() {
        Proc.runCommand("checkGsettings", ["sh", "-c", "gsettings get org.gnome.desktop.sound theme-name 2>/dev/null"], (output, exitCode) => {
            gsettingsAvailable = (exitCode === 0)
            if (gsettingsAvailable) {
                scanSoundThemes()
                getCurrentSoundTheme()
            }
        }, 0)
    }

    function scanSoundThemes() {
        const xdgDataDirs = Quickshell.env("XDG_DATA_DIRS")
        const searchPaths = xdgDataDirs && xdgDataDirs.trim() !== ""
            ? xdgDataDirs.split(":")
            : ["/usr/share", "/usr/local/share", StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.local/share"]

        const basePaths = searchPaths.map(p => p + "/sounds").join(" ")
        const script = `
            for base_dir in ${basePaths}; do
                [ -d "$base_dir" ] || continue
                for theme_dir in "$base_dir"/*; do
                    [ -d "$theme_dir/stereo" ] || continue
                    basename "$theme_dir"
                done
            done | sort -u
        `

        Proc.runCommand("scanSoundThemes", ["sh", "-c", script], (output, exitCode) => {
            if (exitCode === 0 && output.trim()) {
                const themes = output.trim().split('\n').filter(t => t && t.length > 0)
                availableSoundThemes = themes
            } else {
                availableSoundThemes = []
            }
        }, 0)
    }

    function getCurrentSoundTheme() {
        Proc.runCommand("getCurrentSoundTheme", ["sh", "-c", "gsettings get org.gnome.desktop.sound theme-name 2>/dev/null | sed \"s/'//g\""], (output, exitCode) => {
            if (exitCode === 0 && output.trim()) {
                currentSoundTheme = output.trim()
                console.log("AudioService: Current system sound theme:", currentSoundTheme)
                if (SettingsData.useSystemSoundTheme) {
                    discoverSoundFiles(currentSoundTheme)
                }
            } else {
                currentSoundTheme = ""
                console.log("AudioService: No system sound theme found")
            }
        }, 0)
    }

    function setSoundTheme(themeName) {
        if (!themeName || themeName === currentSoundTheme) {
            return
        }

        Proc.runCommand("setSoundTheme", ["sh", "-c", `gsettings set org.gnome.desktop.sound theme-name '${themeName}'`], (output, exitCode) => {
            if (exitCode === 0) {
                currentSoundTheme = themeName
                if (SettingsData.useSystemSoundTheme) {
                    discoverSoundFiles(themeName)
                }
            }
        }, 0)
    }

    function discoverSoundFiles(themeName) {
        if (!themeName) {
            soundFilePaths = {}
            if (soundsAvailable) {
                destroySoundPlayers()
                createSoundPlayers()
            }
            return
        }

        const xdgDataDirs = Quickshell.env("XDG_DATA_DIRS")
        const searchPaths = xdgDataDirs && xdgDataDirs.trim() !== ""
            ? xdgDataDirs.split(":")
            : ["/usr/share", "/usr/local/share", StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.local/share"]

        const extensions = ["oga", "ogg", "wav", "mp3", "flac"]
        const themesToSearch = themeName !== "freedesktop" ? `${themeName} freedesktop` : themeName

        const script = `
            for event_key in audio-volume-change power-plug power-unplug message message-new-instant; do
                found=0

                case "$event_key" in
                    message)
                        names="dialog-information message message-lowpriority bell"
                        ;;
                    message-new-instant)
                        names="dialog-warning message-new-instant message-highlight"
                        ;;
                    *)
                        names="$event_key"
                        ;;
                esac

                for theme in ${themesToSearch}; do
                    for event_name in $names; do
                        for base_path in ${searchPaths.join(" ")}; do
                            sounds_path="$base_path/sounds"
                            for ext in ${extensions.join(" ")}; do
                                file_path="$sounds_path/$theme/stereo/$event_name.$ext"
                                if [ -f "$file_path" ]; then
                                    echo "$event_key=$file_path"
                                    found=1
                                    break
                                fi
                            done
                            [ $found -eq 1 ] && break
                        done
                        [ $found -eq 1 ] && break
                    done
                    [ $found -eq 1 ] && break
                done
            done
        `

        Proc.runCommand("discoverSoundFiles", ["sh", "-c", script], (output, exitCode) => {
            const paths = {}
            if (exitCode === 0 && output.trim()) {
                const lines = output.trim().split('\n')
                for (let line of lines) {
                    const parts = line.split('=')
                    if (parts.length === 2) {
                        paths[parts[0]] = "file://" + parts[1]
                    }
                }
            }
            soundFilePaths = paths

            if (soundsAvailable) {
                destroySoundPlayers()
                createSoundPlayers()
            }
        }, 0)
    }

    function getSoundPath(soundEvent) {
        const soundMap = {
            "audio-volume-change": "../assets/sounds/freedesktop/audio-volume-change.wav",
            "power-plug": "../assets/sounds/plasma/power-plug.wav",
            "power-unplug": "../assets/sounds/plasma/power-unplug.wav",
            "message": "../assets/sounds/freedesktop/message.wav",
            "message-new-instant": "../assets/sounds/freedesktop/message-new-instant.wav"
        }

        const specialConditions = {
            "smooth": ["audio-volume-change"]
        }

        const themeLower = currentSoundTheme.toLowerCase()
        if (SettingsData.useSystemSoundTheme && specialConditions[themeLower]?.includes(soundEvent)) {
            const bundledPath = Qt.resolvedUrl(soundMap[soundEvent] || "../assets/sounds/freedesktop/message.wav")
            console.log("AudioService: Using bundled sound (special condition) for", soundEvent, ":", bundledPath)
            return bundledPath
        }

        if (SettingsData.useSystemSoundTheme && soundFilePaths[soundEvent]) {
            console.log("AudioService: Using system sound for", soundEvent, ":", soundFilePaths[soundEvent])
            return soundFilePaths[soundEvent]
        }

        const bundledPath = Qt.resolvedUrl(soundMap[soundEvent] || "../assets/sounds/freedesktop/message.wav")
        console.log("AudioService: Using bundled sound for", soundEvent, ":", bundledPath)
        return bundledPath
    }

    function reloadSounds() {
        console.log("AudioService: Reloading sounds, useSystemSoundTheme:", SettingsData.useSystemSoundTheme, "currentSoundTheme:", currentSoundTheme)
        if (SettingsData.useSystemSoundTheme && currentSoundTheme) {
            discoverSoundFiles(currentSoundTheme)
        } else {
            soundFilePaths = {}
            if (soundsAvailable) {
                destroySoundPlayers()
                createSoundPlayers()
            }
        }
    }

    function destroySoundPlayers() {
        if (volumeChangeSound) {
            volumeChangeSound.destroy()
            volumeChangeSound = null
        }
        if (powerPlugSound) {
            powerPlugSound.destroy()
            powerPlugSound = null
        }
        if (powerUnplugSound) {
            powerUnplugSound.destroy()
            powerUnplugSound = null
        }
        if (normalNotificationSound) {
            normalNotificationSound.destroy()
            normalNotificationSound = null
        }
        if (criticalNotificationSound) {
            criticalNotificationSound.destroy()
            criticalNotificationSound = null
        }
    }

    function createSoundPlayers() {
        if (!soundsAvailable) {
            return
        }

        try {
            const volumeChangePath = getSoundPath("audio-volume-change")
            volumeChangeSound = Qt.createQmlObject(`
                import QtQuick
                import QtMultimedia
                MediaPlayer {
                    source: "${volumeChangePath}"
                    audioOutput: AudioOutput { volume: 1.0 }
                }
            `, root, "AudioService.VolumeChangeSound")

            const powerPlugPath = getSoundPath("power-plug")
            powerPlugSound = Qt.createQmlObject(`
                import QtQuick
                import QtMultimedia
                MediaPlayer {
                    source: "${powerPlugPath}"
                    audioOutput: AudioOutput { volume: 1.0 }
                }
            `, root, "AudioService.PowerPlugSound")

            const powerUnplugPath = getSoundPath("power-unplug")
            powerUnplugSound = Qt.createQmlObject(`
                import QtQuick
                import QtMultimedia
                MediaPlayer {
                    source: "${powerUnplugPath}"
                    audioOutput: AudioOutput { volume: 1.0 }
                }
            `, root, "AudioService.PowerUnplugSound")

            const messagePath = getSoundPath("message")
            normalNotificationSound = Qt.createQmlObject(`
                import QtQuick
                import QtMultimedia
                MediaPlayer {
                    source: "${messagePath}"
                    audioOutput: AudioOutput { volume: 1.0 }
                }
            `, root, "AudioService.NormalNotificationSound")

            const messageNewInstantPath = getSoundPath("message-new-instant")
            criticalNotificationSound = Qt.createQmlObject(`
                import QtQuick
                import QtMultimedia
                MediaPlayer {
                    source: "${messageNewInstantPath}"
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

    Connections {
        target: SettingsData
        function onUseSystemSoundThemeChanged() {
            reloadSounds()
        }
    }

    Component.onCompleted: {
        if (!detectSoundsAvailability()) {
            console.warn("AudioService: QtMultimedia not available - sound effects disabled")
        } else {
            console.log("AudioService: Sound effects enabled")
            checkGsettings()
            Qt.callLater(createSoundPlayers)
        }
    }
}
