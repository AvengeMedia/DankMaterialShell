pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DankDash
import qs.Widgets

FocusScope {
    id: root

    required property var controller

    property bool contentStaged: false

    readonly property real stageWidth: root.controller.homeExpandedTarget.width - 2
    readonly property real stageHeight: root.controller.homeExpandedTarget.height - 2
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
            live: root.controller.expanded && root.controller.activeActivity === "home"
            onCloseDash: root.controller.requestCollapse()
            onNavFocusRequested: root.focusOverview()
            onSwitchToMediaTab: root.controller.requestActivity("media", true, true)
            onSwitchToWeatherTab: {
                if (SettingsData.weatherEnabled)
                    root.controller.requestWeather(false);
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
            root.controller.requestCollapse();
            event.accepted = true;
        }
    }

    Component.onCompleted: root.contentStaged = true
}
