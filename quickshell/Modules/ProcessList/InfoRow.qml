import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

RowLayout {
    property string label: ""
    property string value: ""

    Layout.fillWidth: true
    spacing: Theme.spacingS

    StyledText {
        text: label + ":"
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.surfaceVariantText
        Layout.preferredWidth: 100
    }

    StyledText {
        text: value
        font.pixelSize: Theme.fontSizeSmall
        font.family: SettingsData.monoFontFamily
        color: Theme.surfaceText
        Layout.fillWidth: true
        elide: Text.ElideRight
    }
}
