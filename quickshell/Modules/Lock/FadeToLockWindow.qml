pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

PanelWindow {
    id: root

    property bool active: false
    property bool _completed: false

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
            if (opacity >= 0.99 && root.active && !root._completed) {
                root._completed = true;
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
        _completed = false;
        active = true;
        fadeOverlay.opacity = 0.0;
        fadeSeq.stop();
        fadeSeq.start();
    }

    function cancelFade() {
        if (_completed)
            return;
        fadeSeq.stop();
        fadeOverlay.opacity = 0.0;
        active = false;
        fadeCancelled();
    }

    function dismiss() {
        fadeSeq.stop();
        fadeOverlay.opacity = 0.0;
        active = false;
        _completed = false;
    }

    Connections {
        target: IdleService
        function onIsShellLockedChanged() {
            if (!IdleService.isShellLocked && root._completed)
                root.dismiss();
        }
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
