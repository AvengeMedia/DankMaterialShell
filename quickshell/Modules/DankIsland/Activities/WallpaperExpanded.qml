pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.DankDash
import qs.Widgets

FocusScope {
    id: root

    required property var controller
    property var effectiveScreen: null

    property bool contentStaged: false

    readonly property real stageWidth: root.controller.wallpaperExpandedTarget.width - 2
    readonly property real stageHeight: root.controller.wallpaperExpandedTarget.height - 2
    readonly property var wallpaperTab: tabLoader.item

    clip: true

    function focusGrid() {
        root.forceActiveFocus();
    }

    function beginSession() {
        root.wallpaperTab?.collapseSearch();
        root.focusGrid();
    }

    QtObject {
        id: hostContract

        property var customKeyboardFocus: null

        onCustomKeyboardFocusChanged: root.controller.keyboardYielded = hostContract.customKeyboardFocus !== null
    }

    Loader {
        id: tabLoader

        x: Theme.spacingM
        y: Theme.spacingM
        width: root.stageWidth - Theme.spacingM * 2
        height: root.stageHeight - Theme.spacingM - Theme.spacingS
        active: root.contentStaged
        asynchronous: true
        visible: status === Loader.Ready
        sourceComponent: wallpaperTabComponent
    }

    Component {
        id: wallpaperTabComponent

        WallpaperTab {
            active: true
            pagerCachePages: 0
            targetScreen: root.effectiveScreen
            parentPopout: hostContract
            Component.onCompleted: root.focusGrid()
        }
    }

    DankSpinner {
        anchors.centerIn: parent
        size: 40
        visible: !tabLoader.visible
    }

    Keys.onPressed: event => {
        if (root.wallpaperTab?.handleKeyEvent(event) === true) {
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Escape) {
            root.controller.requestCollapse();
            event.accepted = true;
        }
    }

    Connections {
        target: root.controller

        function onSessionStarted(activityId) {
            if (activityId === "wallpaper")
                Qt.callLater(root.beginSession);
        }
    }

    Component.onCompleted: {
        root.contentStaged = true;
        root.controller.markVisualsReady("wallpaper");
    }

    Component.onDestruction: {
        root.controller.keyboardYielded = false;
        root.controller.setVisualsReady("wallpaper", false);
    }
}
