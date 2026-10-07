import QtQuick
import Quickshell

QtObject {
    required property Singleton service
    property var modules: null
    property bool active: true

    property bool _held: false

    function sync(wanted) {
        if (wanted === _held)
            return;
        _held = wanted;
        if (typeof service.addRef !== "function") {
            service.refCount += wanted ? 1 : -1;
            return;
        }
        const held = modules ?? [];
        if (wanted) {
            service.addRef(held);
            return;
        }
        service.removeRef(held);
    }

    onActiveChanged: sync(active)
    Component.onCompleted: sync(active)
    Component.onDestruction: sync(false)
}
