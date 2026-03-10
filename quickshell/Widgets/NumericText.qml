import QtQuick
import qs.Common

StyledText {
    id: root

    property string reserveText: ""
    readonly property real reservedWidth: reserveText !== "" ? Math.max(contentWidth, reserveMetrics.width) : contentWidth

    isMonospace: true
    wrapMode: Text.NoWrap

    StyledTextMetrics {
        id: reserveMetrics
        isMonospace: root.isMonospace
        font.pixelSize: root.font.pixelSize
        font.family: root.font.family
        font.weight: root.font.weight
        font.hintingPreference: root.font.hintingPreference
        text: root.reserveText
    }
}
