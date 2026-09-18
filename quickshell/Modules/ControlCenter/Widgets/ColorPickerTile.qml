import QtQuick
import qs.Common

CcTile {
    iconName: "palette"
    title: I18n.tr("Color Picker")
    subtitle: I18n.tr("Choose color", "color picker title")

    onClicked: host?.colorPickerRequested()
}
