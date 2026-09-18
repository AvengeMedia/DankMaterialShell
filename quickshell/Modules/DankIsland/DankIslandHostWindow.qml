pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

Item {
    id: root

    required property string barId
    property var screen: null
    property var hyprlandOverviewLoader: null

    readonly property var body: IslandHostRegistry.hostFor(root.screen?.name, root.barId)
    readonly property var islandController: root.body?.islandController ?? null
    readonly property int launcherResultCount: root.body?.launcherResultCount ?? 0
    readonly property int hostOriginX: root.body?.hostOriginX ?? 0
    readonly property int hostOriginY: root.body?.hostOriginY ?? 0
    readonly property var islandLayer: root.body?.hostWindow?.dBarLayer ?? WlrLayer.Top

    function requestKeyboardFocus() {
        root.body?.requestKeyboardFocus();
    }

    function containsGlobalPoint(gx, gy, padding) {
        return root.body?.containsGlobalPoint(gx, gy, padding) ?? false;
    }

    PanelWindow {
        id: dismissWindow

        screen: root.screen
        visible: !!root.body && root.body.expanded && !PopoutManager.screenshotActive
        color: "transparent"
        exclusiveZone: -1

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.namespace: "dms:dankisland:dismiss"
        WlrLayershell.layer: root.islandLayer
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region {
            item: dismissMask

            Region {
                item: islandHole
                intersection: Intersection.Subtract
            }

            Region {
                item: fittsStripHole
                intersection: Intersection.Subtract
            }

            Region {
                item: leadingSectionHole
                intersection: Intersection.Subtract
            }

            Region {
                item: trailingSectionHole
                intersection: Intersection.Subtract
            }
        }

        Rectangle {
            id: dismissMask

            anchors.fill: parent
            visible: false
            color: "transparent"
        }

        Item {
            id: islandHole

            readonly property var mask: root.body?.inputMaskItem ?? null
            x: (mask?.x ?? 0) + root.hostOriginX
            y: (mask?.y ?? 0) + root.hostOriginY
            width: mask?.width ?? 0
            height: mask?.height ?? 0
        }

        Item {
            id: fittsStripHole

            readonly property var strip: root.body?.fittsStripItem ?? null
            x: (strip?.x ?? 0) + root.hostOriginX
            y: (strip?.y ?? 0) + root.hostOriginY
            width: strip?.visible ? strip.width : 0
            height: strip?.visible ? strip.height : 0
        }

        Item {
            id: leadingSectionHole

            readonly property var r: root.body?.hostWindow?.leadingSectionRect ?? null
            x: (r?.x ?? 0) + root.hostOriginX - (root.body?.originOffsetX ?? 0)
            y: (r?.y ?? 0) + root.hostOriginY - (root.body?.originOffsetY ?? 0)
            width: r?.w ?? 0
            height: r?.h ?? 0
        }

        Item {
            id: trailingSectionHole

            readonly property var r: root.body?.hostWindow?.trailingSectionRect ?? null
            x: (r?.x ?? 0) + root.hostOriginX - (root.body?.originOffsetX ?? 0)
            y: (r?.y ?? 0) + root.hostOriginY - (root.body?.originOffsetY ?? 0)
            width: r?.w ?? 0
            height: r?.h ?? 0
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            onPressed: mouse => {
                root.islandController?.requestCollapse();
                mouse.accepted = true;
            }

            onWheel: wheel => root.body?.hostWindow?.processScrollWheel?.(wheel)
        }
    }
}
