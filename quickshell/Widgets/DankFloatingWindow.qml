pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services

FloatingWindow {
    id: root

    default property alias content: contentItem.data

    property color surfaceColor: Theme.floatingWindowSurface

    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: root.surfaceColor
    }

    WindowBlur {
        targetWindow: root
        blurX: 0
        blurY: 0
        blurWidth: root.visible ? root.width : 0
        blurHeight: root.visible ? root.height : 0
        blurRadius: Theme.cornerRadius
    }

    Item {
        id: contentItem

        property bool disablePopupTransparency: true

        anchors.fill: parent
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: "transparent"
        border.color: BlurService.borderColor
        border.width: BlurService.borderWidth
        antialiasing: true
        z: 100
    }
}
