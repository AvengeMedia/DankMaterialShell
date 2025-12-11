import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string title: ""
    property Component content: null
    property bool isVisible: true
    property int contentHeight: 300

    width: parent ? parent.width : 400
    implicitHeight: isVisible ? contentHeight : 0
    height: implicitHeight
    color: "transparent"
    clip: true

    Loader {
        id: contentLoader
        anchors.fill: parent
        sourceComponent: root.content
        asynchronous: true
    }


}
