import QtQuick
import qs.Common

Rectangle {
    id: inputFieldRect

    default property alias contentData: inputFieldRect.data
    property bool hasFocus: false
    property int fieldHeight: Theme.fontSizeMedium + Theme.spacingL * 2

    width: parent.width
    height: fieldHeight
    radius: Theme.cornerRadius
    color: Theme.surfaceHover
    border.color: hasFocus ? Theme.primary : Theme.outlineStrong
    border.width: hasFocus ? 2 : 1
}
