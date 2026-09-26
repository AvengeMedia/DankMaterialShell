import QtQuick
import Quickshell.Services.Pipewire
import qs.Common

Item {
    id: root
    visible: false

    readonly property bool ready: Pipewire.ready
    readonly property var nodes: Pipewire.nodes.values
    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource

    signal nodesUpdated

    function setDefaultSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    Connections {
        target: Pipewire.nodes
        function onValuesChanged() {
            root.nodesUpdated();
        }
    }

    PwObjectTracker {
        objects: Pipewire.nodes.values.filter(node => node.audio && (SettingsData.audioShowStreamDevices || !node.isStream))
    }
}
