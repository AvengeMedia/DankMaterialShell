pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    property alias text: label.text
    property alias font: label.font
    property alias color: label.color
    property bool active: true
    property real holdStartMs: 2000
    property real holdEndMs: 2000
    property real pxPerMs: 1 / 60
    property real overscroll: 5
    property bool animateTextChange: false
    readonly property alias contentWidth: label.contentWidth
    readonly property alias implicitTextWidth: label.implicitWidth
    readonly property alias implicitTextHeight: label.implicitHeight
    readonly property bool needsScrolling: label.implicitWidth > width && SettingsData.scrollTitleEnabled
    readonly property bool scrollActive: needsScrolling && visible && (Window.window?.visible ?? false) && active
    readonly property real maxScrollOffset: Math.max(0, label.implicitWidth - width + overscroll)

    property real scrollOffset: 0
    property int scrollDirection: 1
    property real scrollHoldMs: holdStartMs
    property real textShift: 0

    function resetScroll() {
        scrollOffset = 0;
        scrollDirection = 1;
        scrollHoldMs = holdStartMs;
    }

    function stepScroll(deltaMs) {
        if (scrollHoldMs > 0) {
            scrollHoldMs -= deltaMs;
            return;
        }
        const next = scrollOffset + scrollDirection * deltaMs * pxPerMs;
        if (next >= maxScrollOffset) {
            scrollOffset = maxScrollOffset;
            scrollDirection = -1;
            scrollHoldMs = holdEndMs;
            return;
        }
        if (next <= 0) {
            scrollOffset = 0;
            scrollDirection = 1;
            scrollHoldMs = holdStartMs;
            return;
        }
        scrollOffset = next;
    }

    onScrollActiveChanged: {
        if (!scrollActive)
            resetScroll();
    }

    clip: true
    implicitHeight: label.implicitHeight

    StyledText {
        id: label

        anchors.verticalCenter: parent.verticalCenter
        wrapMode: Text.NoWrap
        width: root.needsScrolling ? implicitWidth : root.width
        elide: root.needsScrolling ? Text.ElideNone : Text.ElideRight
        x: Math.round((root.needsScrolling ? -Math.min(root.scrollOffset, root.maxScrollOffset) : 0) + root.textShift)
        opacity: 1

        onTextChanged: {
            root.resetScroll();
            root.textShift = 0;
            if (!root.animateTextChange)
                return;
            textChangeAnimation.restart();
        }
    }

    // Timer stepping, not NumberAnimation: a running animation commits frames every vsync (#2863).
    // When cava frames are already driving renders, scroll steps ride those ticks instead (#2863).
    Timer {
        interval: 60
        repeat: true
        running: root.scrollActive
        onTriggered: {
            if (cavaTickWatch.running)
                return;
            root.stepScroll(60);
        }
    }

    Timer {
        id: cavaTickWatch
        interval: 150
    }

    Connections {
        target: CavaService
        enabled: root.scrollActive && SettingsData.audioVisualizerEnabled && CavaService.cavaAvailable
        function onValuesChanged() {
            cavaTickWatch.restart();
            root.stepScroll(40);
        }
    }

    SequentialAnimation {
        id: textChangeAnimation

        ParallelAnimation {
            NumberAnimation {
                target: label
                property: "opacity"
                from: 0.7
                to: 1
                duration: Theme.shortDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
            }

            NumberAnimation {
                target: root
                property: "textShift"
                from: 4
                to: 0
                duration: Theme.shortDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
            }
        }
    }
}
