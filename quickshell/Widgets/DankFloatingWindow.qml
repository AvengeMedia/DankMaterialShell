pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

FloatingWindow {
    id: root

    default property alias content: contentItem.data

    property color surfaceColor: Theme.floatingWindowSurface

    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: root.surfaceColor
    }

    WindowBlur {
        targetWindow: root
        blurX: 0
        blurY: 0
        blurWidth: root.visible ? root.width : 0
        blurHeight: root.visible ? root.height : 0
    }

    Item {
        id: contentItem

        property bool disablePopupTransparency: true

        anchors.fill: parent
    }
}
