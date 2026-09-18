import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Modules.DankDash

DashCardComponent {
    id: root

    readonly property bool wide: width >= DashMetrics.gridRowUnit * 2

    tone: options.tone ?? ""

    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingS

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "extension"
            size: Theme.iconSizeLarge
            color: root.accentColor
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.wide
            text: I18n.trFor("myDashCard", "Hello")
            font.pixelSize: Theme.fontSizeLarge
            color: root.contentColor
        }
    }
}
