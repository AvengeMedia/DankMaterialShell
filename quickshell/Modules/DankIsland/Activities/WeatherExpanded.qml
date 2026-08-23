pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DankDash
import qs.Widgets

FocusScope {
    id: root

    required property var islandController

    property bool contentStaged: false

    readonly property real stageWidth: root.islandController.weatherExpandedTarget.width - 2
    readonly property real stageHeight: root.islandController.weatherExpandedTarget.height - 2
    readonly property real faceInset: Theme.spacingM
    readonly property var weatherTab: tabLoader.item

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
            live: root.islandController.expanded && root.islandController.activeActivity === "weather"
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
            root.islandController.requestCollapse();
            event.accepted = true;
        }
    }

    Component.onCompleted: {
        root.contentStaged = true;
        root.islandController.markWeatherVisualsReady();
    }

    Component.onDestruction: {
        root.islandController.weatherVisualsReady = false;
    }
}
