import QtQuick
import qs.Common
import qs.Widgets

StyledText {
    property string title
    text: title
    font.pixelSize: Theme.fontSizeMedium
    font.weight: Font.Medium
    color: Theme.primary
    topPadding: Theme.spacingM
    bottomPadding: Theme.spacingXS
    width: parent.width
    horizontalAlignment: Text.AlignLeft
}
