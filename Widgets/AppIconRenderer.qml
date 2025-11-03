import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.Common

Item {
    id: root

    required property string iconValue
    required property int iconSize
    property string fallbackText: "A"
    property color iconColor: Theme.surfaceText
    property color fallbackBackgroundColor: Theme.surfaceLight
    property color fallbackTextColor: Theme.primary
    property real materialIconSizeAdjustment: Theme.spacingM
    property real unicodeIconScale: 0.7
    property real fallbackTextScale: 0.4
    property alias iconMargins: iconImg.anchors.margins
    property real fallbackLeftMargin: 0
    property real fallbackRightMargin: 0
    property real fallbackTopMargin: 0
    property real fallbackBottomMargin: 0

    property bool isMaterial: iconValue.indexOf("material:") === 0
    property bool isUnicode: iconValue.indexOf("unicode:") === 0
    property string materialName: isMaterial ? iconValue.substring(9) : ""
    property string unicodeChar: isUnicode ? iconValue.substring(8) : ""

    visible: iconValue !== undefined && iconValue !== ""

    DankIcon {
        anchors.centerIn: parent
        name: root.materialName
        size: root.iconSize - root.materialIconSizeAdjustment
        color: root.iconColor
        visible: root.isMaterial
    }

    StyledText {
        anchors.centerIn: parent
        text: root.unicodeChar
        font.pixelSize: root.iconSize * root.unicodeIconScale
        color: root.iconColor
        visible: root.isUnicode
    }

    IconImage {
        id: iconImg

        anchors.fill: parent
        source: root.isMaterial || root.isUnicode ? "" : Quickshell.iconPath(root.iconValue, true)
        smooth: true
        asynchronous: true
        visible: !root.isMaterial && !root.isUnicode && status === Image.Ready
    }

    Rectangle {
        id: fallbackRect

        anchors.fill: parent
        anchors.leftMargin: root.fallbackLeftMargin
        anchors.rightMargin: root.fallbackRightMargin
        anchors.topMargin: root.fallbackTopMargin
        anchors.bottomMargin: root.fallbackBottomMargin
        visible: !root.isMaterial && !root.isUnicode && iconImg.status !== Image.Ready
        color: root.fallbackBackgroundColor
        radius: Theme.cornerRadius
        border.width: 0
        border.color: Theme.primarySelected

        StyledText {
            anchors.centerIn: parent
            text: root.fallbackText
            font.pixelSize: root.iconSize * root.fallbackTextScale
            color: root.fallbackTextColor
            font.weight: Font.Bold
        }
    }
}
