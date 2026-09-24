pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {
    id: root

    readonly property bool microphoneActive: {
        if (!AudioService.pipewireReady) {
            return false
        }

        for (let i = 0; i < AudioService.pipewireNodes.length; i++) {
            const node = AudioService.pipewireNodes[i]
            if (!node) {
                continue
            }

            if (node.properties?.["media.class"] === "Stream/Input/Audio") {
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


    readonly property bool cameraActive: {
        if (!AudioService.pipewireReady) {
            return false
        }

        for (let i = 0; i < AudioService.pipewireNodes.length; i++) {
            const node = AudioService.pipewireNodes[i]
            if (!node || !node.ready || node.properties?.["media.role"] === "Screen") {
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
        if (CompositorService.isNiri && NiriService.hasActiveCast) {
            return true
        }

        if (!AudioService.pipewireReady) {
            return false
        }

        for (let i = 0; i < AudioService.pipewireNodes.length; i++) {
            const node = AudioService.pipewireNodes[i]
            if (!node || !node.ready) {
                continue
            }

            if (node.properties?.["media.class"] === "Video/Source") {
                if (looksLikeScreencast(node)) {
                    return true
                }
            }

            if (node.properties && node.properties["media.class"] === "Stream/Output/Video") {
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
        const mediaName = (node.properties && node.properties["media.name"] || "").toLowerCase()
        const combined = appName + " " + nodeName + " " + mediaName
        return /xdg-desktop-portal|xdpw|screencast|screen-cast|screen|gnome shell|kwin|obs|niri/.test(combined)
    }

    function screencastSourceIds() {
        const ids = []

        if (CompositorService.isNiri) {
            for (const cast of NiriService.casts) {
                if (cast && cast.is_active) {
                    ids.push("niri:" + cast.stream_id)
                }
            }
        }

        if (!AudioService.pipewireReady) {
            return ids
        }

        for (let i = 0; i < AudioService.pipewireNodes.length; i++) {
            const node = AudioService.pipewireNodes[i]
            if (!node || !node.ready) {
                continue
            }

            const isVideoSource = node.properties?.["media.class"] === "Video/Source"
            const isVideoStream = node.properties && node.properties["media.class"] === "Stream/Output/Video"
            if ((isVideoSource || isVideoStream) && looksLikeScreencast(node)) {
                ids.push("pw:" + node.id)
            }
        }

        return ids.sort()
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
