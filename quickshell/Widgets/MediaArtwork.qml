pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.Common

Item {
    id: root

    property string artUrl: ""
    property real placeholderIconSize: Math.min(width, height) * 0.46
    property real cornerRadius: Math.min(width, height) * 0.22
    readonly property int artPixelSize: Math.max(1, Math.round(Math.max(width, height) * 2))

    ClippingRectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: Theme.primaryContainer
        antialiasing: true

        DankIcon {
            anchors.centerIn: parent
            name: "music_note"
            size: root.placeholderIconSize
            color: Theme.primary
            visible: artwork.status !== Image.Ready
        }

        Image {
            id: artwork

            anchors.fill: parent
            source: root.visible && root.width > 0 ? root.artUrl : ""
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(root.artPixelSize, root.artPixelSize)
            visible: status === Image.Ready
        }
    }
}
