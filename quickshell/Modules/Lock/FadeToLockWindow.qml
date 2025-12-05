pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

PanelWindow {
    id: root

    property bool active: false

    signal fadeCompleted
    signal fadeCancelled

    visible: active
    color: "transparent"

    WlrLayershell.namespace: "dms:fade-to-lock"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    Rectangle {
        id: fadeOverlay
        anchors.fill: parent
        color: "black"
        opacity: 0

        onOpacityChanged: {
            if (opacity >= 0.99 && root.active) {
                root.fadeCompleted();
            }
        }
    }

    SequentialAnimation {
        id: fadeSeq
        running: false

        NumberAnimation {
            target: fadeOverlay
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: SettingsData.fadeToLockGracePeriod * 1000
            easing.type: Easing.OutCubic
        }
    }

    function startFade() {
        if (!SettingsData.fadeToLockEnabled)
            return;
        active = true;
        fadeOverlay.opacity = 0.0;
        fadeSeq.stop();
        fadeSeq.start();
    }

    function cancelFade() {
        fadeSeq.stop();
        fadeOverlay.opacity = 0.0;
        active = false;
        fadeCancelled();
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.active
        onClicked: root.cancelFade()
        onPressed: root.cancelFade()
    }

    FocusScope {
        anchors.fill: parent
        focus: root.active

        Keys.onPressed: event => {
            root.cancelFade();
            event.accepted = true;
        }
    }

    Component.onCompleted: {
        if (active) {
            forceActiveFocus();
        }
    }

    onActiveChanged: {
        if (active) {
            forceActiveFocus();
        }
    }
}
