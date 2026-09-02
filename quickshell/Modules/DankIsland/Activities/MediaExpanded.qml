pragma ComponentBehavior: Bound

import QtQuick
import qs.Modules.DankDash

DashTabFace {
    id: root

    property var effectiveScreen: null
    property real alignedX: 0
    property real alignedY: 0
    property real alignedWidth: 0
    property bool geometrySettled: false
    readonly property bool menusEnabled: root.live && root.geometrySettled

    signal dropdownRequested(int dropdownType, point pos)
    signal dropdownsHidden
    signal dropdownHoverStarted
    signal dropdownHoverEnded

    activityId: "media"
    tabComponent: Component {
        MediaPlayerTab {
            compact: true
            live: root.live
            menusEnabled: root.menusEnabled
            targetScreen: root.effectiveScreen
            popoutX: root.alignedX
            popoutY: root.alignedY
            popoutWidth: root.alignedWidth
            contentOffsetY: root.inset
            section: "left"
            onShowVolumeDropdown: pos => root.dropdownRequested(1, pos)
            onShowAudioDevicesDropdown: pos => root.dropdownRequested(2, pos)
            onShowPlayersDropdown: pos => root.dropdownRequested(3, pos)
            onHideDropdowns: root.dropdownsHidden()
            onDropdownButtonEntered: root.dropdownHoverStarted()
            onDropdownButtonExited: root.dropdownHoverEnded()
        }
    }

    Connections {
        target: root.controller

        function onMediaDropdownOpenChanged() {
            if (!root.controller.mediaDropdownOpen)
                root.tab?.resetDropdownStates();
        }
    }
}
