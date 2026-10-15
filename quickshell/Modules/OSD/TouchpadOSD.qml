import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

DOSD {
    id: root

    osdKind: "touchpad"

    osdWidth: Theme.osdHeight
    osdHeight: Theme.osdHeight
    autoHideInterval: 2000
    enableMouseInteraction: false

    property bool touchpadEnabled: true

    Connections {
        target: NiriService

        function onTouchpadOsdRequested(enabled: bool) {
            if (!SettingsData.osdTouchpadEnabled)
                return;
            root.touchpadEnabled = enabled;
            root.show();
        }
    }

    content: Item {
        OsdIcon {
            tonal: false
            anchors.centerIn: parent
            iconName: root.touchpadEnabled ? "touchpad_mouse" : "touchpad_mouse_off"
            iconColor: root.touchpadEnabled ? Theme.primary : Theme.outline
        }
    }
}
