import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

ListView {
    id: listView

    property real scrollBarTopMargin: 0
    property real mouseWheelSpeed: 60
    property real savedY: 0
    property bool justChanged: false
    property bool isUserScrolling: false
    property real momentumVelocity: 0
    property bool isMomentumActive: false
    property real friction: 0.95
    property real minMomentumVelocity: 50
    property real maxMomentumVelocity: 2500

    flickDeceleration: 1500
    maximumFlickVelocity: 2000
    boundsBehavior: Flickable.StopAtBounds
    boundsMovement: Flickable.FollowBoundsBehavior
    pressDelay: 0
    flickableDirection: Flickable.VerticalFlick

    add: ListViewTransitions.add
    remove: ListViewTransitions.remove
    displaced: ListViewTransitions.displaced
    move: ListViewTransitions.move

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
        property real touchpadSpeed: 2.8
        property real lastWheelTime: 0
        property real momentum: 0
        property var velocitySamples: []
        property bool sessionUsedMouseWheel: false

        function startMomentum() {
            isMomentumActive = true;
            momentumTimer.start();
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
                momentumTimer.stop();
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
                momentumTimer.stop();
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
                momentumTimer.stop();
                isMomentumActive = false;

                let delta = event.pixelDelta.y * touchpadSpeed;

                velocitySamples.push({
                    "delta": delta,
                    "time": currentTime
                });
                velocitySamples = velocitySamples.filter(s => currentTime - s.time < 100);

                if (velocitySamples.length > 1) {
                    const totalDelta = velocitySamples.reduce((sum, s) => sum + s.delta, 0);
                    const timeSpan = currentTime - velocitySamples[0].time;
                    if (timeSpan > 0) {
                        momentumVelocity = Math.max(-maxMomentumVelocity, Math.min(maxMomentumVelocity, totalDelta / timeSpan * 1000));
                    }
                }

                if (timeDelta < 50) {
                    momentum = momentum * 0.92 + delta * 0.15;
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
                if (!sessionUsedMouseWheel && Math.abs(momentumVelocity) >= minMomentumVelocity) {
                    startMomentum();
                } else {
                    velocitySamples = [];
                    momentumVelocity = 0;
                }
            }
        }
    }

    Timer {
        id: momentumTimer
        interval: 16
        repeat: true

        onTriggered: {
            const newY = contentY - momentumVelocity * 0.016;
            const maxY = Math.max(0, contentHeight - height + originY);
            const minY = originY;

            if (newY < minY || newY > maxY) {
                contentY = newY < minY ? minY : maxY;
                savedY = contentY;
                stop();
                isMomentumActive = false;
                momentumVelocity = 0;
                return;
            }

            contentY = newY;
            savedY = newY;
            momentumVelocity *= friction;

            if (Math.abs(momentumVelocity) < 5) {
                stop();
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
