import QtQuick
import Quickshell.Hyprland
import qs.Common

// Delays grab release so keyboardFocus=None commits before the grab dies,
// keeping Hyprland from handing focus back to the closing surface (#2577)
HyprlandFocusGrab {
    id: root

    property bool wanted: false
    property bool _held: false
    property bool _compositorCleared: false
    property var _restoreToplevel: null
    property int _restoreWorkspaceId: -1

    property Timer _releaseTimer: Timer {
        interval: 50
        onTriggered: {
            root._held = false;
            root.active = false;
            // Restoring a toplevel from another workspace would drag the user back
            // to the workspace they just navigated away from (#2963)
            const workspaceChanged = (Hyprland.focusedWorkspace?.id ?? -1) !== root._restoreWorkspaceId;
            root._restoreToplevel = (root._compositorCleared || workspaceChanged) ? null : KeyboardFocus.restoreToplevel(root._restoreToplevel);
        }
    }

    onWantedChanged: _sync()
    Component.onCompleted: _sync()

    function _sync() {
        if (!wanted) {
            if (_held)
                _releaseTimer.restart();
            return;
        }
        _releaseTimer.stop();
        _held = true;
        _compositorCleared = false;
        _restoreToplevel = KeyboardFocus.captureActiveToplevel();
        _restoreWorkspaceId = Hyprland.focusedWorkspace?.id ?? -1;
        active = true;
    }

    onCleared: _compositorCleared = true
}
