pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

FloatingWindow {
    id: root

    readonly property bool isFloatingWindowSurface: true

    default property alias content: contentItem.data

    property color surfaceColor: Theme.floatingWindowSurface
    property bool contentVisible: true

    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: root.surfaceColor
        visible: root.contentVisible
    }

    WindowBlur {
        targetWindow: root
        blurEnabled: root.contentVisible && Theme.connectedSurfaceBlurEnabled
        blurX: 0
        blurY: 0
        blurWidth: root.visible ? root.width : 0
        blurHeight: root.visible ? root.height : 0
    }

    Item {
        id: contentItem

        readonly property bool isFloatingWindowSurface: true
        property bool disablePopupTransparency: true

        anchors.fill: parent
        visible: root.contentVisible
    }
}
