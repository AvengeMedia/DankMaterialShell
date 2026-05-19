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

    readonly property bool _active: blurEnabled && BlurService.enabled && !!targetWindow

    Region {
        id: blurRegion
        x: root.blurX
        y: root.blurY
        width: root.blurWidth
        height: root.blurHeight
        radius: root.blurRadius
    }

    function _apply() {
        if (!targetWindow)
            return;
        targetWindow.BackgroundEffect.blurRegion = _active ? blurRegion : null;
    }

    // Force BackgroundEffect to re-publish the blur region on the current wl_surface.
    // Clearing first bypasses Quickshell's same-Region dedup in BackgroundEffect::setBlurRegion,
    // setting pendingBlurRegion=true so the next polish actually ships the region — needed
    // when the underlying surface has been remapped (e.g. PanelWindow.screen change).
    function kick() {
        if (!targetWindow)
            return;
        targetWindow.BackgroundEffect.blurRegion = null;
        targetWindow.BackgroundEffect.blurRegion = _active ? blurRegion : null;
    }

    on_ActiveChanged: _apply()
    onTargetWindowChanged: _apply()

    Connections {
        target: root.targetWindow ?? null
        ignoreUnknownSignals: true
        function onVisibleChanged() {
            if (root.targetWindow && root.targetWindow.visible)
                root._apply();
        }
    }

    Component.onCompleted: _apply()
    Component.onDestruction: {
        if (targetWindow)
            targetWindow.BackgroundEffect.blurRegion = null;
    }
}
