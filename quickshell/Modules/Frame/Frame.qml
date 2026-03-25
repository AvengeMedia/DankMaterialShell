pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

Variants {
    id: root

    model: SettingsData.getFrameScreensAlways()

    FrameInstance {
        required property ShellScreen modelData

        screen: modelData
    }
}
