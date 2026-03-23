pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Item {
    id: root

    required property ShellScreen screen

    FrameWindow {
        screen: root.screen
    }

    FrameExclusions {
        screen: root.screen
    }
}
