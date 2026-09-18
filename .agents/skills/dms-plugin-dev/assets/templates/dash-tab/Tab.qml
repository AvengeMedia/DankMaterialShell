import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Modules.DankDash

DashTabComponent {
    id: root

    focusTarget: button
    implicitHeight: Math.max(DashMetrics.tabMinHeight, content.implicitHeight + Theme.spacingL * 2)

    function restoreFocus() {
        button.forceActiveFocus(Qt.OtherFocusReason);
    }

    Column {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spacingM

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.options.compact
            text: I18n.trFor("myDashTab", "Hello from a dash tab")
            font.pixelSize: Theme.fontSizeXLarge
            color: Theme.surfaceText
        }

        DankButton {
            id: button
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.trFor("myDashTab", "Open overview")
            onClicked: root.tabRequested("overview")
        }
    }
}
