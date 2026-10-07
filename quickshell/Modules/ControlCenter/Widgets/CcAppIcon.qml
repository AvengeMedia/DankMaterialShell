import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.DCommon.Widgets

Item {
    id: root

    property string appId: ""
    property real iconSize: Theme.iconSize

    implicitWidth: iconSize
    implicitHeight: iconSize

    IconImage {
        id: image
        anchors.fill: parent
        source: root.appId ? Paths.getAppIcon(root.appId, DesktopEntries.heuristicLookup(root.appId)) : ""
        smooth: true
        mipmap: true
        asynchronous: true
        visible: status === Image.Ready
    }

    DIcon {
        anchors.centerIn: parent
        name: "apps"
        size: root.iconSize
        color: Theme.onSurfaceVariant
        visible: image.status === Image.Error || image.source.toString() === ""
    }
}
