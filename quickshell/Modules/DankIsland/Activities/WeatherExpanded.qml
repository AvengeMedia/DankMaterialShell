pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DankDash
import qs.Widgets

FocusScope {
    id: root

    required property var controller

    property bool contentStaged: false

    readonly property real stageWidth: root.controller.weatherExpandedTarget.width - 2
    readonly property real stageHeight: root.controller.weatherExpandedTarget.height - 2
    readonly property real faceInset: Theme.spacingM

    clip: true

    function focusWeather() {
        root.forceActiveFocus();
    }

    Loader {
        id: tabLoader

        x: root.faceInset
        y: root.faceInset
        width: root.stageWidth - root.faceInset * 2
        height: root.stageHeight - root.faceInset * 2
        active: root.contentStaged
        asynchronous: true
        visible: status === Loader.Ready
        sourceComponent: weatherTabComponent
    }

    Component {
        id: weatherTabComponent

        WeatherTab {
            live: root.controller.expanded && root.controller.activeActivity === "weather"
            Component.onCompleted: root.focusWeather()
        }
    }

    DankSpinner {
        anchors.centerIn: parent
        size: 40
        visible: !tabLoader.visible
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.controller.requestCollapse();
            event.accepted = true;
        }
    }

    Component.onCompleted: {
        root.contentStaged = true;
        root.controller.markVisualsReady("weather");
    }

    Component.onDestruction: {
        root.controller.setVisualsReady("weather", false);
    }
}
