import QtQuick

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property int interval: 0
    property bool pending: false

    signal triggered

    function schedule() {
        if (!root.enabled || root.pending)
            return;
        root.pending = true;
        deferTimer.restart();
    }

    function restart() {
        if (!root.enabled)
            return;
        root.pending = true;
        deferTimer.restart();
    }

    function flush() {
        if (!root.pending)
            return;
        deferTimer.stop();
        root.pending = false;
        root.triggered();
    }

    function cancel() {
        deferTimer.stop();
        root.pending = false;
    }

    onEnabledChanged: {
        if (!enabled)
            cancel();
    }

    Timer {
        id: deferTimer
        interval: root.interval
        repeat: false
        onTriggered: root.flush()
    }

    Component.onDestruction: cancel()
}
