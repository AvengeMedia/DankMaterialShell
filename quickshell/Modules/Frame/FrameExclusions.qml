pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

Scope {
    id: root

    required property var screen

    readonly property var barEdges: {
        SettingsData.barConfigs; // force re-eval when bar configs change
        return SettingsData.getActiveBarEdgesForScreen(screen);
    }

    // One thin invisible PanelWindow per edge. A standalone bar reserves its own edge, so
    // that edge is skipped — unless the frame hosts the bar (connected mode), where no bar
    // window exists and the exclusion must reserve the full bar thickness itself.

    readonly property bool screenEnabled: CompositorService.frameWindowVisibleForScreen(root.screen)
    readonly property bool hostsBar: CompositorService.frameHostsSurfacesForScreen(root.screen)

    function exclusionSizeForEdge(edge) {
        return root.barEdges.includes(edge) ? SettingsData.frameBarSize : SettingsData.frameThickness;
    }

    Loader {
        readonly property bool isBarEdge: root.barEdges.includes("top")
        active: root.screenEnabled && (!isBarEdge || root.hostsBar)
        sourceComponent: EdgeExclusion {
            targetScreen: root.screen
            exclusionSize: root.exclusionSizeForEdge("top")
            anchorTop: true
            anchorLeft: true
            anchorRight: true
        }
    }

    Loader {
        readonly property bool isBarEdge: root.barEdges.includes("bottom")
        active: root.screenEnabled && (!isBarEdge || root.hostsBar)
        sourceComponent: EdgeExclusion {
            targetScreen: root.screen
            exclusionSize: root.exclusionSizeForEdge("bottom")
            anchorBottom: true
            anchorLeft: true
            anchorRight: true
        }
    }

    Loader {
        readonly property bool isBarEdge: root.barEdges.includes("left")
        active: root.screenEnabled && (!isBarEdge || root.hostsBar)
        sourceComponent: EdgeExclusion {
            targetScreen: root.screen
            exclusionSize: root.exclusionSizeForEdge("left")
            anchorLeft: true
            anchorTop: true
            anchorBottom: true
        }
    }

    Loader {
        readonly property bool isBarEdge: root.barEdges.includes("right")
        active: root.screenEnabled && (!isBarEdge || root.hostsBar)
        sourceComponent: EdgeExclusion {
            targetScreen: root.screen
            exclusionSize: root.exclusionSizeForEdge("right")
            anchorRight: true
            anchorTop: true
            anchorBottom: true
        }
    }

    component EdgeExclusion: PanelWindow {
        required property var targetScreen
        property real exclusionSize: SettingsData.frameThickness

        screen: targetScreen
        property bool anchorTop: false
        property bool anchorBottom: false
        property bool anchorLeft: false
        property bool anchorRight: false

        WlrLayershell.namespace: "dms:frame-exclusion"
        WlrLayershell.layer: WlrLayer.Top
        exclusiveZone: exclusionSize
        color: "transparent"
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1

        anchors {
            top: anchorTop
            bottom: anchorBottom
            left: anchorLeft
            right: anchorRight
        }
    }
}
