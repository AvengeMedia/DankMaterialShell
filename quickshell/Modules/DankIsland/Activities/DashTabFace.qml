pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Widgets

FocusScope {
    id: root

    required property var controller
    required property string activityId
    required property Component tabComponent
    property real inset: Theme.spacingM
    property bool contentStaged: false

    readonly property bool live: root.controller.expanded && root.controller.activeActivity === root.activityId
    readonly property var tab: tabLoader.item

    clip: true

    function focusFace() {
        root.forceActiveFocus();
        return true;
    }

    function forwardKey(event) {
        if (!root.tab || typeof root.tab.handleKeyEvent !== "function")
            return false;
        return root.tab.handleKeyEvent(event) === true;
    }

    Loader {
        id: tabLoader

        anchors {
            fill: parent
            margins: root.inset
        }
        active: root.contentStaged
        asynchronous: true
        visible: status === Loader.Ready
        sourceComponent: root.tabComponent
        onLoaded: {
            if (root.live)
                root.focusFace();
        }
    }

    DankSpinner {
        anchors.centerIn: parent
        size: 40
        visible: !tabLoader.visible
    }

    Keys.onPressed: event => event.accepted = root.forwardKey(event)

    Component.onCompleted: root.contentStaged = true
}
