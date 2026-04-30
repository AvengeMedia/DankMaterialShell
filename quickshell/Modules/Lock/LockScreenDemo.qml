pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services

PanelWindow {
    id: root
    readonly property var log: Log.scoped("LockScreenDemo")

    property bool demoActive: false

    visible: demoActive

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    color: "transparent"

    function showDemo(): void {
        log.debug("Showing lock screen demo");
        demoActive = true;
    }

    function hideDemo(): void {
        log.debug("Hiding lock screen demo");
        demoActive = false;
    }

    Loader {
        anchors.fill: parent
        active: demoActive
        sourceComponent: LockScreenContent {
            demoMode: true
            screenName: root.screen?.name ?? ""
            onUnlockRequested: root.hideDemo()
        }
    }
}
