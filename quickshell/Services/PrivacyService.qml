pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property bool microphoneActive: {
        if (!Pipewire.ready || !Pipewire.nodes?.values) {
            return false
        }

        for (let i = 0; i < Pipewire.nodes.values.length; i++) {
            const node = Pipewire.nodes.values[i]
            if (!node) {
                continue
            }

            if ((node.type & PwNodeType.AudioInStream) === PwNodeType.AudioInStream) {
                if (!looksLikeSystemVirtualMic(node)) {
                    if (node.audio && node.audio.muted) {
                        return false
                    }
                    return true
                }
            }
        }
        return false
    }

    PwObjectTracker {
        objects: Pipewire.nodes.values.filter(node => !node.isStream)
    }

    readonly property bool cameraActive: {
        if (!Pipewire.ready || !Pipewire.nodes?.values) {
            return false
        }

        for (let i = 0; i < Pipewire.nodes.values.length; i++) {
            const node = Pipewire.nodes.values[i]
            if (!node || !node.ready) {
                continue
            }
            
            if (node.properties && node.properties["media.class"] === "Stream/Input/Video") {
                if (node.properties["stream.is-live"] === "true") {
                    return true
                }
            }
        }
        return false
    }

    readonly property bool screensharingActive: {
        if (!Pipewire.ready || !Pipewire.nodes?.values) {
            return false
        }

        for (let i = 0; i < Pipewire.nodes.values.length; i++) {
            const node = Pipewire.nodes.values[i]
            if (!node || !node.ready) {
                continue
            }

            if ((node.type & PwNodeType.VideoSource) === PwNodeType.VideoSource) {
                if (looksLikeScreencast(node)) {
                    return true
                }
            }

            if (node.properties && node.properties["media.class"] === "Stream/Input/Audio") {
                const mediaName = (node.properties["media.name"] || "").toLowerCase()
                const appName = (node.properties["application.name"] || "").toLowerCase()

                if (mediaName.includes("desktop") || appName.includes("screen") || appName === "obs") {
                    if (node.properties["stream.is-live"] === "true") {
                        if (node.audio && node.audio.muted) {
                            return false
                        }
                        return true
                    }
                }
            }
        }
        return false
    }

    readonly property bool anyPrivacyActive: microphoneActive || cameraActive || screensharingActive

    function looksLikeSystemVirtualMic(node) {
        if (!node) {
            return false
        }
        const name = (node.name || "").toLowerCase()
        const mediaName = (node.properties && node.properties["media.name"] || "").toLowerCase()
        const appName = (node.properties && node.properties["application.name"] || "").toLowerCase()
        const combined = name + " " + mediaName + " " + appName
        return /cava|monitor|system/.test(combined)
    }

    function looksLikeScreencast(node) {
        if (!node) {
            return false
        }
        const appName = (node.properties && node.properties["application.name"] || "").toLowerCase()
        const nodeName = (node.name || "").toLowerCase()
        const combined = appName + " " + nodeName
        return /xdg-desktop-portal|xdpw|screencast|screen|gnome shell|kwin|obs/.test(combined)
    }

    function getMicrophoneStatus() {
        return microphoneActive ? "active" : "inactive"
    }

    function getCameraStatus() {
        return cameraActive ? "active" : "inactive"
    }

    function getScreensharingStatus() {
        return screensharingActive ? "active" : "inactive"
    }

    function getPrivacySummary() {
        const active = []
        if (microphoneActive) {
            active.push("microphone")
        }
        if (cameraActive) {
            active.push("camera")
        }
        if (screensharingActive) {
            active.push("screensharing")
        }

        return active.length > 0 ? `Privacy active: ${active.join(", ")}` : "No privacy concerns detected"
    }
}
