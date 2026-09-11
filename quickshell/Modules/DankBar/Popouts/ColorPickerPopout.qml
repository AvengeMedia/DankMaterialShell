import QtQuick
import qs.Common
import qs.Modules.ColorPicker
import qs.Widgets

DankPopout {
    id: root

    layerNamespace: "dms:color-picker"
    popupWidth: 680
    popupHeight: contentLoader.item ? contentLoader.item.implicitHeight : 620
    triggerWidth: 70
    positioning: ""
    shouldBeVisible: false

    onBackgroundClicked: close()

    content: Component {
        ColorPickerContent {
            anchors.fill: parent
            initialColor: SessionData.recentColors.length > 0 ? SessionData.recentColors[0] : Theme.primary
            onCloseRequested: root.close()
            onHideRequested: root.instantClose()
            onShowRequested: root.open()
        }
    }
}
