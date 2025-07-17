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

    property ListModel audioSinksModel: ListModel {}
    property ListModel audioSourcesModel: ListModel {}

    property var audioSinks: []
    property var audioSources: []

    Component.onCompleted: _rebuildModels()

    Connections {
        target: Pipewire
        function onReadyChanged() { _rebuildModels() }
        function onDefaultAudioSinkChanged() { _rebuildModels() }
        function onDefaultAudioSourceChanged() { _rebuildModels() }        
        function onNodeAdded() { _rebuildModels() }
        function onNodeRemoved() { _rebuildModels() }
    }
    
    Timer {
        interval: 2000
        running: Pipewire.ready
        repeat: true
        onTriggered: _checkForNodeChanges()
    }
    
    property int _lastNodeCount: 0
    
    function _checkForNodeChanges() {
        if (Pipewire.nodes?.values) {
            let currentCount = Pipewire.nodes.values.length
            if (currentCount !== _lastNodeCount) {
                _lastNodeCount = currentCount
                _rebuildModels()
            }
        }
    }

    readonly property string currentAudioSink: sink?.name ?? ""
    readonly property string currentAudioSource: source?.name ?? ""

    readonly property string currentSinkDisplayName: {
        if (!sink) return ""
        for (let i = 0; i < audioSinksModel.count; i++) {
            let item = audioSinksModel.get(i)
            if (item.node === sink) {
                return item.displayName
            }
        }
        return _displayName(sink)
    }

    readonly property string currentSourceDisplayName: {
        if (!source) return ""
        for (let i = 0; i < audioSourcesModel.count; i++) {
            let item = audioSourcesModel.get(i)
            if (item.node === source) {
                return item.displayName
            }
        }
        return _displayName(source)
    }

    function setVolume(percentage) {
        if (sink?.audio) {
            sink.audio.muted = false
            sink.audio.volume = percentage / 100
        }
    }

    function setMicLevel(percentage) {
        if (source?.audio) {
            source.audio.muted = false
            source.audio.volume = percentage / 100
        }
    }

    function toggleMute() {
        if (sink?.audio) {
            sink.audio.muted = !sink.audio.muted
        }
    }

    function toggleMicMute() {
        if (source?.audio) {
            source.audio.muted = !source.audio.muted
        }
    }

    function setAudioSink(sinkName) {
        _setPreferred(sinkName, PwNodeType.AudioSink)
    }

    function setAudioSource(sourceName) {
        _setPreferred(sourceName, PwNodeType.AudioSource)
    }

    function _rebuildModels() {
        audioSinksModel.clear()
        audioSourcesModel.clear()
        
        let sinks = []
        let sources = []

        if (!Pipewire.ready || !Pipewire.nodes?.values) return

        for (let i = 0; i < Pipewire.nodes.values.length; i++) {
            let node = Pipewire.nodes.values[i]
            if (!node || node.isStream) continue

            let entry = {
                id: node.id.toString(),
                name: node.name,
                displayName: _displayName(node),
                subtitle: _subtitle(node.name),
                active: node === sink || node === source,
                node: node
            }

            if ((node.type & PwNodeType.AudioSink) === PwNodeType.AudioSink) {
                audioSinksModel.append(entry)
                sinks.push(entry)
            }
            if ((node.type & PwNodeType.AudioSource) === PwNodeType.AudioSource && !node.name.includes(".monitor")) {
                audioSourcesModel.append(entry)
                sources.push(entry)
            }
        }
        
        audioSinks = sinks
        audioSources = sources
    }

    function _displayName(node) {
        if (node.properties?.["device.description"]) {
            return node.properties["device.description"]
        }

        if (node.description && node.description !== node.name) {
            return node.description
        }

        if (node.nickname && node.nickname !== node.name) {
            return node.nickname
        }

        if (node.name.includes("analog-stereo")) return "Built-in Speakers"
        else if (node.name.includes("bluez")) return "Bluetooth Audio"
        else if (node.name.includes("usb")) return "USB Audio"
        else if (node.name.includes("hdmi")) return "HDMI Audio"

        return node.name
    }

    function _subtitle(name) {
        if (!name) return ""

        if (name.includes('usb-')) {
            if (name.includes('SteelSeries')) {
                return "USB Gaming Headset"
            } else if (name.includes('Generic')) {
                return "USB Audio Device"
            }
            return "USB Audio"
        } else if (name.includes('pci-')) {
            if (name.includes('01_00.1') || name.includes('01:00.1')) {
                return "NVIDIA GPU Audio"
            }
            return "PCI Audio"
        } else if (name.includes('bluez')) {
            return "Bluetooth Audio"
        } else if (name.includes('analog')) {
            return "Built-in Audio"
        } else if (name.includes('hdmi')) {
            return "HDMI Audio"
        }

        return ""
    }

    function _setPreferred(name, kind) {
        if (!Pipewire.nodes?.values) return

        for (let i = 0; i < Pipewire.nodes.values.length; i++) {
            let node = Pipewire.nodes.values[i]
            if (node && node.name === name && !node.isStream && ((node.type & kind) === kind)) {
                if (kind === PwNodeType.AudioSink) {
                    Pipewire.preferredDefaultAudioSink = node
                } else if (kind === PwNodeType.AudioSource) {
                    Pipewire.preferredDefaultAudioSource = node
                }
                break
            }
        }
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
}