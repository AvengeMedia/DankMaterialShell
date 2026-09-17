pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

PanelWindow {
    id: root

    required property var controller
    property bool inputEnabled: false
    property bool mouseInitialized: false
    property point lastMousePosition: Qt.point(-1, -1)

    readonly property int zoneColumn: controller.zoneIndex % 3
    readonly property int zoneRow: Math.floor(controller.zoneIndex / 3)
    readonly property real sceneWidth: Math.min(width * 0.76, 1080)
    readonly property real sceneHeight: controller.contentMode === "ascii" ? Math.min(height * 0.68, 720) : Math.min(height * 0.48, 500)
    readonly property real safeMarginX: Math.max(Theme.spacingXL * 2, width * 0.055)
    readonly property real safeMarginY: Math.max(Theme.spacingXL * 2, height * 0.07)
    readonly property real availableX: Math.max(0, width - sceneWidth - safeMarginX * 2)
    readonly property real availableY: Math.max(0, height - sceneHeight - safeMarginY * 2)
    readonly property real sceneX: safeMarginX + availableX * zoneColumn / 2
    readonly property real sceneY: safeMarginY + availableY * zoneRow / 2

    visible: controller.active
    color: Theme.surfaceContainerLowest

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "dms:expressive-screensaver"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (!visible)
            return;
        inputEnabled = false;
        mouseInitialized = false;
        lastMousePosition = Qt.point(-1, -1);
        inputEnableTimer.restart();
        Qt.callLater(() => inputScope.forceActiveFocus());
    }

    Timer {
        id: inputEnableTimer
        interval: 500
        onTriggered: root.inputEnabled = true
    }

    Item {
        id: scene
        x: root.sceneX
        y: root.sceneY
        width: root.sceneWidth
        height: root.sceneHeight

        Behavior on x {
            enabled: !root.controller.reducedMotion
            SpringAnimation { spring: 1.7; damping: 0.22; epsilon: 0.5 }
        }

        Behavior on y {
            enabled: !root.controller.reducedMotion
            SpringAnimation { spring: 1.7; damping: 0.22; epsilon: 0.5 }
        }

        TextScreensaverView {
            anchors.fill: parent
            visible: root.controller.contentMode === "text"
            content: root.controller.configuredContent
            effect: root.controller.currentEffect
            revision: root.controller.cycleRevision
            reducedMotion: root.controller.reducedMotion
            showShapes: root.controller.showShapes
        }

        AsciiScreensaverView {
            anchors.fill: parent
            visible: root.controller.contentMode === "ascii"
            content: root.controller.configuredContent
            effect: root.controller.currentEffect
            revision: root.controller.cycleRevision
            reducedMotion: root.controller.reducedMotion
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.visible && root.inputEnabled
        hoverEnabled: true
        cursorShape: Qt.BlankCursor

        onPressed: root.controller.hide()
        onWheel: root.controller.hide()
        onPositionChanged: mouse => {
            if (!root.mouseInitialized) {
                root.lastMousePosition = Qt.point(mouse.x, mouse.y);
                root.mouseInitialized = true;
                return;
            }
            if (Math.abs(mouse.x - root.lastMousePosition.x) <= 5 && Math.abs(mouse.y - root.lastMousePosition.y) <= 5)
                return;
            root.controller.hide();
        }
    }

    FocusScope {
        id: inputScope
        anchors.fill: parent
        focus: root.visible

        Keys.onPressed: event => {
            root.controller.hide();
            event.accepted = true;
        }
    }
}
