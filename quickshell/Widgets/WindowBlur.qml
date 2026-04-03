import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    visible: false

    required property var targetWindow
    property var blurItem: null
    property bool blurEnabled: Theme.connectedSurfaceBlurEnabled
    property real blurX: 0
    property real blurY: 0
    property real blurWidth: 0
    property real blurHeight: 0
    property real blurRadius: 0

    property var _region: null

    function _apply() {
        if (!blurEnabled || !BlurService.enabled || !targetWindow) {
            _cleanup();
            return;
        }

        if (!_region)
            _region = BlurService.createBlurRegion(targetWindow);

        if (!_region)
            return;

        _region.item = Qt.binding(() => root.blurItem);
        _region.x = Qt.binding(() => root.blurX);
        _region.y = Qt.binding(() => root.blurY);
        _region.width = Qt.binding(() => root.blurWidth);
        _region.height = Qt.binding(() => root.blurHeight);
        _region.radius = Qt.binding(() => root.blurRadius);
    }

    function _cleanup() {
        if (!_region)
            return;
        BlurService.destroyBlurRegion(targetWindow, _region);
        _region = null;
    }

    onBlurEnabledChanged: _apply()

    Connections {
        target: BlurService
        function onEnabledChanged() {
            root._apply();
        }
    }

    Connections {
        target: root.targetWindow
        function onVisibleChanged() {
            if (root.targetWindow && root.targetWindow.visible) {
                root._region = null;
                root._apply();
            }
        }
    }

    Component.onCompleted: _apply()
    Component.onDestruction: _cleanup()
}
