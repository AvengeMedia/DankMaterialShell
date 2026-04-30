import QtQuick
import qs.Common
import qs.Modules.ControlCenter.Widgets
import qs.Services

CompoundPill {
    id: root
    readonly property var log: Log.scoped("ColorPickerPill")

    property var colorPickerModal: null

    isActive: true
    iconName: "palette"
    iconColor: Theme.primary
    primaryText: I18n.tr("Color Picker")
    secondaryText: I18n.tr("Choose a color")

    onToggled: {
        log.debug("ColorPickerPill toggled, modal:", colorPickerModal);
        if (colorPickerModal) {
            colorPickerModal.show();
        }
    }

    onExpandClicked: {
        log.debug("ColorPickerPill expandClicked, modal:", colorPickerModal);
        if (colorPickerModal) {
            colorPickerModal.show();
        }
    }
}
