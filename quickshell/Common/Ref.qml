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
        if (modules === null) {
            service.refCount += wanted ? 1 : -1;
            return;
        }
        if (wanted) {
            service.addRef(modules);
            return;
        }
        service.removeRef(modules);
    }

    onActiveChanged: sync(active)
    Component.onCompleted: sync(active)
    Component.onDestruction: sync(false)
}
