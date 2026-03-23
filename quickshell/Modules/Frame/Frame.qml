pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

Variants {
    id: root

    model: SettingsData.frameEnabled ? SettingsData.getFrameFilteredScreens() : []

    FrameInstance {
        required property ShellScreen modelData

        screen: modelData
    }
}
