pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

Scope {
    id: root

    required property ShellScreen screen

    readonly property var barEdges: {
        SettingsData.barConfigs; // force re-eval when bar configs change
        return SettingsData.getActiveBarEdgesForScreen(screen);
    }

    // One thin invisible PanelWindow per edge.
    // Skips any edge where a bar already provides its own exclusiveZone.

    Loader {
        active: SettingsData.frameEnabled && !root.barEdges.includes("top")
        sourceComponent: EdgeExclusion {
            screen:       root.screen
            anchorTop:    true
            anchorLeft:   true
            anchorRight:  true
        }
    }

    Loader {
        active: SettingsData.frameEnabled && !root.barEdges.includes("bottom")
        sourceComponent: EdgeExclusion {
            screen:        root.screen
            anchorBottom:  true
            anchorLeft:    true
            anchorRight:   true
        }
    }

    Loader {
        active: SettingsData.frameEnabled && !root.barEdges.includes("left")
        sourceComponent: EdgeExclusion {
            screen:        root.screen
            anchorLeft:    true
            anchorTop:     true
            anchorBottom:  true
        }
    }

    Loader {
        active: SettingsData.frameEnabled && !root.barEdges.includes("right")
        sourceComponent: EdgeExclusion {
            screen:        root.screen
            anchorRight:   true
            anchorTop:     true
            anchorBottom:  true
        }
    }

    component EdgeExclusion: PanelWindow {
        required property ShellScreen screen
        property bool anchorTop:    false
        property bool anchorBottom: false
        property bool anchorLeft:   false
        property bool anchorRight:  false

        WlrLayershell.namespace: "dms:frame-exclusion"
        WlrLayershell.layer: WlrLayer.Top
        exclusiveZone: SettingsData.frameThickness
        color: "transparent"
        mask: Region {}
        implicitWidth:  1
        implicitHeight: 1

        anchors {
            top:    anchorTop
            bottom: anchorBottom
            left:   anchorLeft
            right:  anchorRight
        }
    }
}
