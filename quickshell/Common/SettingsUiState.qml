pragma Singleton

import QtQuick
import Quickshell
import qs.Common

Singleton {
    id: root

    property string selectedBarId: "default"

    function normalizeSelectedBar() {
        if (SettingsData.getBarConfig(selectedBarId))
            return;
        selectedBarId = SettingsData.barConfigs[0]?.id ?? "default";
    }

    Connections {
        target: SettingsData

        function onBarConfigsChanged() {
            root.normalizeSelectedBar();
        }
    }
}
