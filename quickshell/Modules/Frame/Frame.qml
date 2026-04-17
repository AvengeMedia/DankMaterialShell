pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Variants {
    id: root

    model: Quickshell.screens

    FrameInstance {
        required property var modelData

        screen: modelData
    }
}
