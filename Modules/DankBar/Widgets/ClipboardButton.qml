import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

BasePill {
    id: root

    property bool isActive: false
    property var clipboardHistoryModal: null

    content: Component {
        Item {
            implicitWidth: root.widgetThickness - root.horizontalPadding * 2
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            DankIcon {
                anchors.centerIn: parent
                name: "content_paste"
                size: Theme.barIconSize(root.barThickness)
                color: Theme.surfaceText
            }
        }
    }
}