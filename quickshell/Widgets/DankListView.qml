import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import "ScrollConstants.js" as Scroll

ListView {
    id: listView

    property real scrollBarTopMargin: 0
    property real mouseWheelSpeed: Scroll.mouseWheelSpeed
    property real savedY: 0
    property bool justChanged: false
    property bool isUserScrolling: false
    property real momentumVelocity: 0
    property bool isMomentumActive: false
    property real friction: Scroll.friction

    flickDeceleration: Scroll.flickDeceleration
    maximumFlickVelocity: Scroll.maximumFlickVelocity
    boundsBehavior: Flickable.StopAtBounds
    boundsMovement: Flickable.FollowBoundsBehavior
    pressDelay: 0
    flickableDirection: Flickable.VerticalFlick

    add: ListViewTransitions.add
    remove: ListViewTransitions.remove
    displaced: ListViewTransitions.displaced
    move: ListViewTransitions.move

    // QQmlDelegateModel can release a delegate back to its cache without hiding it,
    // leaving a stale row painted over live ones. Hide anything the view no longer claims.
    Connections {
        target: listView.model?.objectName !== undefined ? listView.model : null
        ignoreUnknownSignals: true
        function onRowsInserted() {
            orphanSweep.arm();
        }
        function onRowsRemoved() {
            orphanSweep.arm();
        }
        function onRowsMoved() {
            orphanSweep.arm();
        }
        function onModelReset() {
            orphanSweep.arm();
        }
    }

    FrameAnimation {
        id: orphanSweep

        property int frames: 0

        function arm() {
            frames = 0;
            running = true;
        }

        onTriggered: {
            const kids = listView.contentItem.children;
            const rows = [];
            for (let i = 0; i < kids.length; i++) {
                const c = kids[i];
                if (!c || c.index === undefined)
                    continue;
                const claimed = listView.itemAtIndex(c.index) === c;
                if (claimed && !c.visible) {
                    c.visible = true;
                    continue;
                }
                if (c.visible)
                    rows.push({
                        item: c,
                        claimed: claimed
                    });
            }
            for (let a = 0; a < rows.length; a++) {
                if (rows[a].claimed)
                    continue;
                for (let b = 0; b < rows.length; b++) {
                    if (a === b || !rows[b].claimed)
                        continue;
                    if (Math.abs(rows[a].item.y - rows[b].item.y) < rows[b].item.height / 2) {
                        rows[a].item.visible = false;
                        break;
                    }
                }
            }
            if (++frames >= 3)
                running = false;
        }
    }

    onMovementStarted: {
        isUserScrolling = true;
        vbar._scrollBarActive = true;
        vbar.hideTimer.stop();
    }
    onMovementEnded: {
        isUserScrolling = false;
        vbar.hideTimer.restart();
    }

    onContentYChanged: {
        if (!justChanged && isUserScrolling) {
            savedY = contentY;
        }
        justChanged = false;
    }

    onModelChanged: {
        justChanged = true;
        contentY = savedY;
    }

    WheelHandler {
        id: wheelHandler
        property real touchpadSpeed: Scroll.touchpadSpeed
        property real lastWheelTime: 0
        property real momentum: 0
        property var velocitySamples: []
        property bool sessionUsedMouseWheel: false

        function startMomentum() {
            isMomentumActive = true;
            momentumAnim.running = true;
        }

        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            isUserScrolling = true;
            vbar._scrollBarActive = true;
            vbar.hideTimer.restart();

            const currentTime = Date.now();
            const timeDelta = currentTime - lastWheelTime;
            lastWheelTime = currentTime;

            const hasPixel = event.pixelDelta && event.pixelDelta.y !== 0;
            const deltaY = event.angleDelta.y;
            const isTraditionalMouse = !hasPixel && Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0;
            const isHighDpiMouse = !hasPixel && !isTraditionalMouse && deltaY !== 0;
            const isTouchpad = hasPixel;

            if (isTraditionalMouse) {
                sessionUsedMouseWheel = true;
                momentumAnim.running = false;
                isMomentumActive = false;
                velocitySamples = [];
                momentum = 0;
                momentumVelocity = 0;

                const lines = Math.round(Math.abs(deltaY) / 120);
                const scrollAmount = (deltaY > 0 ? -lines : lines) * mouseWheelSpeed;
                let newY = listView.contentY + scrollAmount;
                const maxY = Math.max(0, listView.contentHeight - listView.height + listView.originY);
                newY = Math.max(listView.originY, Math.min(maxY, newY));

                if (listView.flicking) {
                    listView.cancelFlick();
                }

                listView.contentY = newY;
                savedY = newY;
            } else if (isHighDpiMouse) {
                sessionUsedMouseWheel = true;
                momentumAnim.running = false;
                isMomentumActive = false;
                velocitySamples = [];
                momentum = 0;
                momentumVelocity = 0;

                let delta = deltaY / 8 * touchpadSpeed;
                let newY = listView.contentY - delta;
                const maxY = Math.max(0, listView.contentHeight - listView.height + listView.originY);
                newY = Math.max(listView.originY, Math.min(maxY, newY));

                if (listView.flicking) {
                    listView.cancelFlick();
                }

                listView.contentY = newY;
                savedY = newY;
            } else if (isTouchpad) {
                sessionUsedMouseWheel = false;
                momentumAnim.running = false;
                isMomentumActive = false;

                let delta = event.pixelDelta.y * touchpadSpeed;

                velocitySamples.push({
                    "delta": delta,
                    "time": currentTime
                });
                velocitySamples = velocitySamples.filter(s => currentTime - s.time < Scroll.velocitySampleWindowMs);

                if (velocitySamples.length > 1) {
                    const totalDelta = velocitySamples.reduce((sum, s) => sum + s.delta, 0);
                    const timeSpan = currentTime - velocitySamples[0].time;
                    if (timeSpan > 0) {
                        momentumVelocity = Math.max(-Scroll.maxMomentumVelocity, Math.min(Scroll.maxMomentumVelocity, totalDelta / timeSpan * 1000));
                    }
                }

                if (timeDelta < Scroll.momentumTimeThreshold) {
                    momentum = momentum * Scroll.momentumRetention + delta * Scroll.momentumDeltaFactor;
                    delta += momentum;
                } else {
                    momentum = 0;
                }

                let newY = listView.contentY - delta;
                const maxY = Math.max(0, listView.contentHeight - listView.height + listView.originY);
                newY = Math.max(listView.originY, Math.min(maxY, newY));

                if (listView.flicking) {
                    listView.cancelFlick();
                }

                listView.contentY = newY;
                savedY = newY;
            }

            event.accepted = true;
        }

        onActiveChanged: {
            if (!active) {
                isUserScrolling = false;
                if (!sessionUsedMouseWheel && Math.abs(momentumVelocity) >= Scroll.minMomentumVelocity) {
                    startMomentum();
                } else {
                    velocitySamples = [];
                    momentumVelocity = 0;
                }
            }
        }
    }

    FrameAnimation {
        id: momentumAnim
        running: false

        onTriggered: {
            const dt = frameTime;
            const newY = contentY - momentumVelocity * dt;
            const maxY = Math.max(0, contentHeight - height + originY);
            const minY = originY;

            if (newY < minY || newY > maxY) {
                contentY = newY < minY ? minY : maxY;
                savedY = contentY;
                running = false;
                isMomentumActive = false;
                momentumVelocity = 0;
                return;
            }

            contentY = newY;
            savedY = newY;
            momentumVelocity *= Math.pow(friction, dt / 0.016);

            if (Math.abs(momentumVelocity) < Scroll.momentumStopThreshold) {
                running = false;
                isMomentumActive = false;
                momentumVelocity = 0;
            }
        }
    }

    ScrollBar.vertical: DankScrollbar {
        id: vbar
        topPadding: listView.scrollBarTopMargin
    }
}
