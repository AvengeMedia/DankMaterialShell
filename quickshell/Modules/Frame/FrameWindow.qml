pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

PanelWindow {
    id: win

    required property ShellScreen screen

    WlrLayershell.namespace: "dms:frame"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    // No input — pass everything through to apps and bar
    mask: Region {}

    FrameBorder {
        anchors.fill: parent
        visible: SettingsData.frameEnabled
        barEdges: { SettingsData.barConfigs; return SettingsData.getActiveBarEdgesForScreen(win.screen); }
    }
}
