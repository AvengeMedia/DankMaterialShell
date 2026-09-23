import QtQuick
import qs.Widgets
import "../../../Common/QmlUtils.js" as QmlUtils

DankReorderList {
    id: root

    readonly property bool isSettingsRow: true
    readonly property bool transparentSlot: true
    readonly property bool firstInGroup: parent?.isSettingsGroupHost ? parent.isEdge(root, true) : true
    readonly property bool lastInGroup: parent?.isSettingsGroupHost ? parent.isEdge(root, false) : true
    Component.onCompleted: flickable = QmlUtils.findParentFlickable(root.parent)
}
