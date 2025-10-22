import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    content: Component {
        Item {
            implicitWidth: root.widgetThickness - root.horizontalPadding * 2
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            DankIcon {
                anchors.centerIn: parent
                name: SessionService.idleInhibited ? "motion_sensor_active" : "motion_sensor_idle"
                size: Theme.barIconSize(root.barThickness, -4)
                color: Theme.surfaceText
            }
        }
    }

    MouseArea {
        z: 1
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            SessionService.toggleIdleInhibit()
        }
    }
}
