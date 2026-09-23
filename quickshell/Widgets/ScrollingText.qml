pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services

Item {
    id: root

    property alias text: label.text
    property alias font: label.font
    property alias fontToken: label.fontToken
    property alias color: label.color
    property bool active: true
    property real holdStartMs: 2000
    property real holdEndMs: 2000
    property real pxPerMs: 1 / 60
    property int stepInterval: 60
    property real overscroll: 5
    property bool animateTextChange: false
    property bool loop: false
    property bool fadeEdges: false
    property real loopGap: Theme.spacingXL * 2
    property int horizontalAlignment: Text.AlignLeft
    readonly property alias contentWidth: label.contentWidth
    readonly property alias implicitTextWidth: label.implicitWidth
    readonly property alias implicitTextHeight: label.implicitHeight
    readonly property bool needsScrolling: label.implicitWidth > width && SettingsData.scrollTitleEnabled
    readonly property bool rightToLeft: label.effectiveHorizontalAlignment === Text.AlignRight
    readonly property bool scrollActive: needsScrolling && visible && (Window.window?.visible ?? false) && active && !SettingsData.reduceMotion
    readonly property real maxScrollOffset: loop ? label.implicitWidth + loopGap : Math.max(0, label.implicitWidth - width + overscroll)

    property real scrollOffset: 0
    property int scrollDirection: 1
    property real scrollHoldMs: holdStartMs
    property real textShift: 0
    property real lastStepMs: 0

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
        if (loop) {
            scrollOffset = next % maxScrollOffset;
            return;
        }
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
        if (!scrollActive) {
            resetScroll();
            return;
        }
        lastStepMs = Date.now();
    }

    clip: true
    implicitHeight: label.implicitHeight
    layer.enabled: fadeEdges && needsScrolling
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: edgeMask.item
    }

    StyledText {
        id: label

        anchors.verticalCenter: parent.verticalCenter
        wrapMode: Text.NoWrap
        width: root.needsScrolling ? implicitWidth : Math.min(implicitWidth, root.width)
        elide: SettingsData.scrollTitleEnabled ? Text.ElideNone : Text.ElideRight
        // Whole-pixel x plus NativeRendering's glyph snapping quantises the offset twice, which
        // turns even motion into a 1px/2px stutter. Both go while the text is actually scrolling.
        renderType: root.needsScrolling ? Text.QtRendering : resolvedRenderType
        x: {
            if (root.needsScrolling) {
                const offset = Math.min(root.scrollOffset, root.maxScrollOffset);
                return (root.rightToLeft ? root.width - width + offset : -offset) + root.textShift;
            }
            switch (root.horizontalAlignment) {
            case Text.AlignHCenter:
                return (root.width - width) / 2;
            case Text.AlignRight:
                return root.width - width;
            }
            return root.textShift;
        }
        opacity: 1

        onTextChanged: {
            root.resetScroll();
            root.textShift = 0;
            if (!root.animateTextChange)
                return;
            textChangeAnimation.restart();
        }
    }

    Loader {
        anchors.verticalCenter: parent.verticalCenter
        x: label.x + (root.rightToLeft ? -1 : 1) * root.maxScrollOffset
        active: root.loop && root.needsScrolling

        sourceComponent: StyledText {
            text: label.text
            font: label.font
            color: label.color
            wrapMode: Text.NoWrap
            renderType: Text.QtRendering
            Accessible.ignored: true
        }
    }

    Loader {
        id: edgeMask
        anchors.fill: parent
        active: root.fadeEdges && root.needsScrolling

        sourceComponent: Rectangle {
            visible: false
            layer.enabled: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: Math.min(0.5, Theme.spacingL / Math.max(1, root.width))
                    color: "white"
                }
                GradientStop {
                    position: 1 - Math.min(0.5, Theme.spacingL / Math.max(1, root.width))
                    color: "white"
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }
    }

    // Timer stepping, not NumberAnimation: a running animation commits frames every vsync (#2863).
    // When cava frames are already driving renders, scroll steps ride those ticks instead (#2863).
    Timer {
        interval: root.stepInterval
        repeat: true
        running: root.scrollActive
        onTriggered: {
            const now = Date.now();
            const elapsed = Math.min(now - root.lastStepMs, root.stepInterval * 4);
            root.lastStepMs = now;
            if (cavaTickWatch.running)
                return;
            root.stepScroll(elapsed);
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
