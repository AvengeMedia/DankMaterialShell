import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.Common
import qs.Widgets

Item {
    id: root

    required property var tray
    property var trayItem: null
    property string source: ""

    IconImage {
        id: iconImg
        anchors.centerIn: parent
        width: root.tray.trayIconSize
        height: root.tray.trayIconSize
        source: root.source
        asynchronous: true
        smooth: true
        mipmap: true
        visible: status === Image.Ready
        layer.enabled: root.tray.trayIconTintEnabled
        layer.effect: MultiEffect {
            saturation: root.tray.trayIconSaturation
            colorization: root.tray.trayIconColorization
            colorizationColor: root.tray.trayIconTintColor
        }
    }

    StyledText {
        anchors.centerIn: parent
        visible: !iconImg.visible
        text: {
            const itemId = root.trayItem?.id || "";
            if (!itemId)
                return "?";
            return itemId.charAt(0).toUpperCase();
        }
        font.pixelSize: 10
        color: Theme.widgetTextColor
    }
}
