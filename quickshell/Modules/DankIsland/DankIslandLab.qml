pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Variants {
    model: Quickshell.screens

    delegate: DankIslandLabWindow {
        required property var modelData

        screen: modelData
    }
}
