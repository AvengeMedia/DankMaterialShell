import QtQuick
import Quickshell

QtObject {
    required property Singleton service
    property bool active: true

    property bool _held: false

    function sync(wanted) {
        if (wanted === _held)
            return;
        _held = wanted;
        service.refCount += wanted ? 1 : -1;
    }

    onActiveChanged: sync(active)
    Component.onCompleted: sync(active)
    Component.onDestruction: sync(false)
}
