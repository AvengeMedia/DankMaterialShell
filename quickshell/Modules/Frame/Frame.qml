pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

Variants {
    id: root

    model: Quickshell.screens

    FrameInstance {
        required property var modelData

        screen: modelData
    }
}
