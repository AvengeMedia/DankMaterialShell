pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

Scope {
    id: root

    required property var screen

    readonly property var barEdges: {
        SettingsData.barConfigs; // force re-eval when bar configs change
        return SettingsData.getActiveBarEdgesForScreen(screen);
    }

    // One thin invisible PanelWindow per edge.
    // Skips any edge where a bar already provides its own exclusiveZone.

    readonly property bool screenEnabled: SettingsData.frameEnabled && SettingsData.isScreenInPreferences(root.screen, SettingsData.frameScreenPreferences)

    Loader {
        active: root.screenEnabled && !root.barEdges.includes("top")
        sourceComponent: EdgeExclusion {
            targetScreen:  root.screen
            anchorTop:    true
            anchorLeft:   true
            anchorRight:  true
        }
    }

    Loader {
        active: root.screenEnabled && !root.barEdges.includes("bottom")
        sourceComponent: EdgeExclusion {
            targetScreen:  root.screen
            anchorBottom:  true
            anchorLeft:    true
            anchorRight:   true
        }
    }

    Loader {
        active: root.screenEnabled && !root.barEdges.includes("left")
        sourceComponent: EdgeExclusion {
            targetScreen:  root.screen
            anchorLeft:    true
            anchorTop:     true
            anchorBottom:  true
        }
    }

    Loader {
        active: root.screenEnabled && !root.barEdges.includes("right")
        sourceComponent: EdgeExclusion {
            targetScreen:  root.screen
            anchorRight:   true
            anchorTop:     true
            anchorBottom:  true
        }
    }

    component EdgeExclusion: PanelWindow {
        required property var targetScreen

        screen: targetScreen
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
