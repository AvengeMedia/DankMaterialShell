import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string imageSource: ""
    property string fallbackIcon: "notifications"
    property string fallbackText: ""
    property bool hasImage: imageSource !== ""
    property alias imageStatus: internalImage.status

    radius: width / 2
    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
    border.color: "transparent"
    border.width: 0

    Image {
        id: internalImage
        anchors.fill: parent
        anchors.margins: 2
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        cache: true
        visible: false
        source: root.imageSource
    }

    MultiEffect {
        anchors.fill: parent
        anchors.margins: 2
        source: internalImage
        maskEnabled: true
        maskSource: circularMask
        visible: internalImage.status === Image.Ready && root.imageSource !== ""
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    Item {
        id: circularMask
        anchors.centerIn: parent
        width: parent.width - 4
        height: parent.height - 4
        layer.enabled: true
        layer.smooth: true
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "black"
            antialiasing: true
        }
    }

    DankIcon {
        anchors.centerIn: parent
        name: root.fallbackIcon
        size: parent.width * 0.5
        color: Theme.surfaceVariantText
        visible: (internalImage.status !== Image.Ready || root.imageSource === "") && root.fallbackIcon !== ""
    }


    StyledText {
        anchors.centerIn: parent
        visible: root.imageSource === "" && root.fallbackIcon === "" && root.fallbackText !== ""
        text: root.fallbackText
        font.pixelSize: Math.max(12, parent.width * 0.5)
        font.weight: Font.Bold
        color: Theme.surfaceVariantText
    }
}