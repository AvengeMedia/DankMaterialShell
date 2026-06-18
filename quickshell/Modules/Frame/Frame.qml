pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

Variants {
    id: root

    model: Quickshell.screens

    delegate: Loader {
        id: instanceLoader

        required property var modelData

        active: SettingsData.frameEnabled && SettingsData.isScreenInPreferences(instanceLoader.modelData, SettingsData.frameScreenPreferences)
        asynchronous: false

        sourceComponent: FrameInstance {
            screen: instanceLoader.modelData
        }
    }
}
