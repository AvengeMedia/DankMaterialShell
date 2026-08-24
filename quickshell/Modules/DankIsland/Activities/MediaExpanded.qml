pragma ComponentBehavior: Bound

import QtQuick
import qs.Modules.DankDash
import qs.Widgets

FocusScope {
    id: root

    required property var controller
    property var effectiveScreen: null
    property real alignedX: 0
    property real alignedY: 0
    property real alignedWidth: 0
    property real alignedHeight: 0

    property bool contentStaged: false
    property bool geometrySettled: false
    readonly property bool menusEnabled: root.controller.expanded && geometrySettled
    readonly property var playerTab: tabLoader.item

    signal showVolumeDropdown(point pos)
    signal showAudioDevicesDropdown(point pos)
    signal showPlayersDropdown(point pos)
    signal hideDropdowns
    signal dropdownHoverEnded

    clip: true

    function focusPlayer() {
        root.forceActiveFocus();
        return true;
    }

    function resetDropdownStates() {
        root.playerTab?.resetDropdownStates();
    }

    Loader {
        id: tabLoader

        anchors.fill: parent
        active: root.contentStaged
        asynchronous: true
        visible: status === Loader.Ready
        sourceComponent: playerTabComponent
    }

    Component {
        id: playerTabComponent

        MediaPlayerTab {
            chrome: "island"
            live: root.controller.expanded && root.controller.activeActivity === "media"
            targetScreen: root.effectiveScreen
            popoutX: root.alignedX
            popoutY: root.alignedY
            popoutWidth: root.alignedWidth
            popoutHeight: root.alignedHeight
            contentOffsetY: 0
            section: "right"
            menusEnabled: root.menusEnabled
            onShowVolumeDropdown: (pos, screen, rightEdge, player, players) => root.showVolumeDropdown(pos)
            onShowAudioDevicesDropdown: (pos, screen, rightEdge) => root.showAudioDevicesDropdown(pos)
            onShowPlayersDropdown: (pos, screen, rightEdge, player, players) => root.showPlayersDropdown(pos)
            onHideDropdowns: root.hideDropdowns()
            onDropdownButtonExited: root.dropdownHoverEnded()
            Component.onCompleted: root.focusPlayer()
        }
    }

    DankSpinner {
        anchors.centerIn: parent
        size: 40
        visible: !tabLoader.visible
    }

    Keys.onPressed: event => {
        if (root.playerTab?.handleKeyEvent(event) === true) {
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

        function onMediaDropdownOpenChanged() {
            if (!root.controller.mediaDropdownOpen)
                root.resetDropdownStates();
        }
    }

    Component.onCompleted: root.contentStaged = true
}
