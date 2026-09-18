import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DankOSD {
    id: root

    osdWidth: Theme.osdHeight
    osdHeight: Theme.osdHeight
    autoHideInterval: 2000
    enableMouseInteraction: false

    Connections {
        target: SessionService
        function onInhibitorChanged() {
            if (SettingsData.osdIdleInhibitorEnabled) {
                root.show();
            }
        }
    }

    content: Item {
        OsdIcon {
            tonal: false
            anchors.centerIn: parent
            iconName: SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
            iconColor: SessionService.idleInhibited ? Theme.primary : Theme.outline
        }
    }
}
