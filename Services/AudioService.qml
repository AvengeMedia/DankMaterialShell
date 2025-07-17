pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool sinkMuted: sink?.audio?.muted ?? false
    readonly property bool sourceMuted: source?.audio?.muted ?? false
    readonly property real volumeLevel: (sink?.audio?.volume ?? 0) * 100
    readonly property real micLevel: (source?.audio?.volume ?? 0) * 100

    property var audioSinks: []
    property var audioSources: []

    property bool _refreshQueued: false

    Component.onCompleted: {
        deferRefresh()
    }

    function deferRefresh() {
        if (_refreshQueued) return
        _refreshQueued = true
        Qt.callLater(function () {
            _refreshQueued = false
            updateDevices() 
        })
    }

    function updateDevices() {
        updateAudioSinks()
        updateAudioSources()
    }

    Connections {
        target: Pipewire
        function onReadyChanged() {
            if (Pipewire.ready) deferRefresh()
        }
        function onDefaultAudioSinkChanged() {
            deferRefresh()
        }
        function onDefaultAudioSourceChanged() {
            deferRefresh()
        }
    }

    // Timer to check for node changes since ObjectModel doesn't expose change signals
    Timer {
        interval: 2000
        running: Pipewire.ready
        repeat: true
        onTriggered: {
            if (Pipewire.nodes && Pipewire.nodes.values) {
                let currentCount = Pipewire.nodes.values.length
                if (currentCount !== lastNodeCount) {
                    lastNodeCount = currentCount
                    deferRefresh()
                }
            }
        }
    }

    property int lastNodeCount: 0

    function updateAudioSinks() {
        if (!Pipewire.ready || !Pipewire.nodes) return

        let sinks = []
        
        if (Pipewire.nodes.values) {
            for (let i = 0; i < Pipewire.nodes.values.length; i++) {
                let node = Pipewire.nodes.values[i]
                if (!node) continue

                if ((node.type & PwNodeType.AudioSink) === PwNodeType.AudioSink && !node.isStream) {
                    let displayName = getDisplayName(node)

                    sinks.push({
                        id: node.id.toString(),
                        name: node.name,
                        displayName: displayName,
                        subtitle: getDeviceSubtitle(node.name),
                        active: node === root.sink,
                        node: node
                    })
                }
            }
        }

        audioSinks = sinks
    }

    function updateAudioSources() {
        if (!Pipewire.ready || !Pipewire.nodes) return

        let sources = []
        
        if (Pipewire.nodes.values) {
            for (let i = 0; i < Pipewire.nodes.values.length; i++) {
                let node = Pipewire.nodes.values[i]
                if (!node) continue
                
                if ((node.type & PwNodeType.AudioSource) === PwNodeType.AudioSource && !node.isStream && !node.name.includes('.monitor')) {
                    sources.push({
                        id: node.id.toString(),
                        name: node.name,
                        displayName: getDisplayName(node),
                        subtitle: getDeviceSubtitle(node.name),
                        active: node === root.source,
                        node: node
                    })
                }
            }
        }
        audioSources = sources
    }

    function getDisplayName(node) {
        // Check properties first (this is key for Bluetooth devices!)
        if (node.properties && node.properties["device.description"]) {
            return node.properties["device.description"]
        }

        if (node.description && node.description !== node.name) {
            return node.description
        }

        if (node.nickname && node.nickname !== node.name) {
            return node.nickname
        }

        // Fallback to name processing
        if (node.name.includes("analog-stereo")) return "Built-in Speakers"
        else if (node.name.includes("bluez")) return "Bluetooth Audio"
        else if (node.name.includes("usb")) return "USB Audio"
        else if (node.name.includes("hdmi")) return "HDMI Audio"

        return node.name
    }

    function getDeviceSubtitle(nodeName) {
        if (!nodeName) return ""
        
        // Simple subtitle based on node name patterns
        if (nodeName.includes('usb-')) {
            if (nodeName.includes('SteelSeries')) {
                return "USB Gaming Headset"
            } else if (nodeName.includes('Generic')) {
                return "USB Audio Device"
            }
            return "USB Audio"
        } else if (nodeName.includes('pci-')) {
            if (nodeName.includes('01_00.1') || nodeName.includes('01:00.1')) {
                return "NVIDIA GPU Audio"
            }
            return "PCI Audio"
        } else if (nodeName.includes('bluez')) {
            return "Bluetooth Audio"
        } else if (nodeName.includes('analog')) {
            return "Built-in Audio"
        }
        
        return ""
    }

    readonly property string currentAudioSink: sink?.name ?? ""
    readonly property string currentAudioSource: source?.name ?? ""
    
    readonly property string currentSinkDisplayName: {
        if (!sink) return ""

        for (let sinkInfo of audioSinks) {
            if (sinkInfo.node === sink) {
                return sinkInfo.displayName
            }
        }

        return sink.description || sink.name
    }
    
    readonly property string currentSourceDisplayName: {
        if (!source) return ""

        for (let sourceInfo of audioSources) {
            if (sourceInfo.node === source) {
                return sourceInfo.displayName
            }
        }

        return source.description || source.name
    }

    function setVolume(percentage) {
        if (!sink?.ready || !sink?.audio) return
        sink.audio.muted = false
        sink.audio.volume = percentage / 100
    }

    function setMicLevel(percentage) {
        if (!source?.ready || !source?.audio) return
        source.audio.muted = false
        source.audio.volume = percentage / 100
    }

    function toggleMute() {
        if (!sink?.ready || !sink?.audio) return
        sink.audio.muted = !sink.audio.muted
    }

    function toggleMicMute() {
        if (!source?.ready || !source?.audio) return
        source.audio.muted = !source.audio.muted
    }

    function setAudioSink(sinkName) {
        if (!Pipewire.nodes?.values) return
        for (let i = 0; i < Pipewire.nodes.values.length; i++) {
            let node = Pipewire.nodes.values[i]
            if (node && node.name === sinkName && (node.type & PwNodeType.AudioSink) === PwNodeType.AudioSink && !node.isStream) {
                Pipewire.preferredDefaultAudioSink = node
                break
            }
        }
    }

    function setAudioSource(sourceName) {
        if (!Pipewire.nodes?.values) return
        for (let i = 0; i < Pipewire.nodes.values.length; i++) {
            let node = Pipewire.nodes.values[i]
            if (node && node.name === sourceName && (node.type & PwNodeType.AudioSource) === PwNodeType.AudioSource && !node.isStream) {
                Pipewire.preferredDefaultAudioSource = node
                break
            }
        }
    }

    PwObjectTracker {
        id: nodeTracker
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
}