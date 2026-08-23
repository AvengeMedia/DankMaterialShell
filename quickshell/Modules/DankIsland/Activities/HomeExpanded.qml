pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DankDash
import qs.Widgets

FocusScope {
    id: root

    required property var islandController

    property bool contentStaged: false

    readonly property real stageWidth: root.islandController.homeExpandedTarget.width - 2
    readonly property real stageHeight: root.islandController.homeExpandedTarget.height - 2
    readonly property real faceInset: Theme.spacingM
    readonly property var overviewTab: tabLoader.item

    clip: true

    function focusOverview() {
        root.forceActiveFocus();
    }

    Loader {
        id: tabLoader

        x: root.faceInset
        width: root.stageWidth - root.faceInset * 2
        height: tabLoader.item?.implicitHeight || 410
        y: Math.round((root.stageHeight - height) / 2)
        active: root.contentStaged
        asynchronous: true
        visible: status === Loader.Ready
        sourceComponent: overviewTabComponent
    }

    Component {
        id: overviewTabComponent

        OverviewTab {
            live: root.islandController.expanded && root.islandController.activeActivity === "home"
            onCloseDash: root.islandController.requestCollapse()
            onNavFocusRequested: root.focusOverview()
            onSwitchToMediaTab: root.islandController.requestActivity("media", true, true)
            onSwitchToWeatherTab: {
                if (SettingsData.weatherEnabled)
                    root.islandController.requestWeather(false);
            }
            Component.onCompleted: root.focusOverview()
        }
    }

    DankSpinner {
        anchors.centerIn: parent
        size: 40
        visible: !tabLoader.visible
    }

    Keys.onPressed: event => {
        if (root.overviewTab?.handleKeyEvent(event) === true) {
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Escape) {
            root.islandController.requestCollapse();
            event.accepted = true;
        }
    }

    Component.onCompleted: root.contentStaged = true
}
