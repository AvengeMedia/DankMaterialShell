pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property int reserveHeight: 58
    property int hostHeight: 300

    color: "transparent"
    implicitHeight: hostHeight
    exclusiveZone: reserveHeight

    anchors {
        top: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "dms:dankisland-lab"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        item: lab.inputMaskItem
    }

    DankIslandMotionLab {
        id: lab

        anchors.fill: parent
        reserveHeight: root.reserveHeight
    }
}
