import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

Item {
    id: root

    visible: false

    required property var targetWindow
    property bool blurEnabled: Theme.connectedSurfaceBlurEnabled
    property real blurX: 0
    property real blurY: 0
    property real blurWidth: 0
    property real blurHeight: 0
    property real blurRadius: 0
    property bool clipEnabled: false
    property real clipX: blurX
    property real clipY: blurY
    property real clipWidth: blurWidth
    property real clipHeight: blurHeight

    readonly property bool _active: blurEnabled && BlurService.enabled && !!targetWindow

    Region {
        id: blurRegion
        x: root.blurX
        y: root.blurY
        width: root.blurWidth
        height: root.blurHeight
        radius: root.blurRadius

        Region {
            intersection: Intersection.Intersect
            x: root.clipEnabled ? root.clipX : root.blurX
            y: root.clipEnabled ? root.clipY : root.blurY
            width: root.clipEnabled ? root.clipWidth : root.blurWidth
            height: root.clipEnabled ? root.clipHeight : root.blurHeight
        }
    }

    function _apply() {
        if (!targetWindow)
            return;
        targetWindow.BackgroundEffect.blurRegion = _active ? blurRegion : null;
    }

    function _clear() {
        if (targetWindow)
            targetWindow.BackgroundEffect.blurRegion = null;
    }

    // Re-publish blur region after wl_surface remaps (e.g. screen change).
    function kick() {
        if (!targetWindow)
            return;
        targetWindow.BackgroundEffect.blurRegion = null;
        targetWindow.BackgroundEffect.blurRegion = _active ? blurRegion : null;
    }

    function _scheduleLifecycleKick() {
        lifecycleKickAction.restart();
    }

    function _runLifecycleKick() {
        if (!targetWindow)
            return;
        if (targetWindow.visible)
            kick();
        else
            _apply();
    }

    on_ActiveChanged: {
        if (_active)
            _scheduleLifecycleKick();
        else
            _clear();
    }
    onTargetWindowChanged: {
        lifecycleKickAction.cancel();
        _apply();
    }

    DeferredAction {
        id: lifecycleKickAction
        onTriggered: root._runLifecycleKick()
    }

    Connections {
        target: root.targetWindow ?? null
        ignoreUnknownSignals: true
        function onVisibleChanged() {
            if (root.targetWindow && root.targetWindow.visible)
                root._scheduleLifecycleKick();
            else
                root._clear();
        }
        function onResourcesLost() {
            lifecycleKickAction.cancel();
            root._clear();
        }
        function onWindowConnected() {
            root._scheduleLifecycleKick();
        }
    }

    Component.onCompleted: _scheduleLifecycleKick()
    Component.onDestruction: {
        lifecycleKickAction.cancel();
        if (targetWindow)
            targetWindow.BackgroundEffect.blurRegion = null;
    }
}
