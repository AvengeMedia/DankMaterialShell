pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    property int revision: 0
    property int appliedRevision: 0
    readonly property bool ready: appliedRevision >= revision

    // Latched: surfaces render the last compositor-acknowledged state until the atomic flip on ack
    property bool effectiveFrameEnabled: false
    property string effectiveFrameMode: "connected"
    readonly property bool effectiveConnectedFrameModeActive: effectiveFrameEnabled && effectiveFrameMode === "connected"

    signal transitionRequested(int revision)

    function begin() {
        revision++;
        transitionRequested(revision);
        return revision;
    }

    function acknowledge(requestRevision) {
        if (requestRevision > appliedRevision)
            appliedRevision = requestRevision;
    }

    function syncEffective() {
        effectiveFrameEnabled = SettingsData.frameEnabled;
        effectiveFrameMode = SettingsData.frameMode;
    }

    onReadyChanged: {
        if (ready)
            syncEffective();
    }

    // Tracks settings-load changes; live toggles begin() first (ready false) so the latch holds
    Connections {
        target: SettingsData
        function onFrameEnabledChanged() {
            if (root.ready)
                root.syncEffective();
        }
        function onFrameModeChanged() {
            if (root.ready)
                root.syncEffective();
        }
    }

    Component.onCompleted: syncEffective()
}
