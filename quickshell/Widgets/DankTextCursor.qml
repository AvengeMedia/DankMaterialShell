import QtQuick
import qs.Common

Rectangle {
    id: root

    property bool shown: true
    property bool blinkOn: true

    readonly property int flashTime: Qt.styleHints.cursorFlashTime

    function resetBlink() {
        blinkOn = true;
        blinkTimer.restart();
    }

    width: 2
    radius: 1
    color: Theme.primary
    visible: shown && blinkOn

    onShownChanged: resetBlink()

    Timer {
        id: blinkTimer
        running: root.shown && root.flashTime > 1
        interval: root.flashTime / 2
        repeat: true
        onTriggered: root.blinkOn = !root.blinkOn
    }
}
