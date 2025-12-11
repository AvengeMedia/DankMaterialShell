import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ControlCenter.Widgets

CompoundPill {
    id: root

    property var colorPickerModal: null

    isActive: true
    iconName: "palette"
    iconColor: Theme.primary
    primaryText: "Color Picker"
    secondaryText: "Choose a color"

    onToggled: {
        console.log("ColorPickerPill toggled, modal:", colorPickerModal)
        if (colorPickerModal) {
            colorPickerModal.show()
        }
    }

    onExpandClicked: {
        console.log("ColorPickerPill expandClicked, modal:", colorPickerModal)
        if (colorPickerModal) {
            colorPickerModal.show()
        }
    }
}
