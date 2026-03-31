pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Item {
    id: root

    required property var screen

    FrameWindow {
        targetScreen: root.screen
    }

    FrameExclusions {
        screen: root.screen
    }
}
