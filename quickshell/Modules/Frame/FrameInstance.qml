pragma ComponentBehavior: Bound

import QtQuick

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
