pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    required property string barId

    readonly property bool free: true
    readonly property bool dot: body.dotMode
    readonly property var barConfig: SettingsData.getBarConfig(root.barId)
    readonly property var islandController: body.islandController
    readonly property int launcherResultCount: body.launcherResultCount
    readonly property int hostOriginX: body.hostOriginX
    readonly property int hostOriginY: body.hostOriginY
    readonly property real dotSize: body.dotSize
    readonly property real compactWidth: body.islandController.compactTarget.width
    readonly property real compactHeight: body.islandController.compactTarget.height
    readonly property real idleScale: Math.max(0.2, Math.min(1, body.setting("islandFreeIdleScale")))
    readonly property real idleOpacity: Math.max(0.05, Math.min(1, body.setting("islandFreeIdleOpacity")))
    readonly property int idleDelay: root.dot ? body.setting("islandFreeIdleDelay") : 0
    readonly property real screenWidth: root.screen?.width ?? 1920
    readonly property real screenHeight: root.screen?.height ?? 1080
    readonly property string positionKey: IslandHostRegistry.key(root.screen?.name, root.barId)
    readonly property var storedAnchor: SessionData.islandFreePositions[root.positionKey] ?? null
    readonly property real storedAnchorX: root.clampAnchorX((typeof root.storedAnchor?.x === "number" ? root.storedAnchor.x : 0.5) * root.screenWidth)
    readonly property real storedAnchorY: root.clampAnchorY((typeof root.storedAnchor?.y === "number" ? root.storedAnchor.y : 0.5) * root.screenHeight)
    readonly property int surfaceX: Math.floor(body.currentVisualX - root.hitPadding)
    readonly property int surfaceY: Math.floor(body.currentVisualY - root.hitPadding)

    readonly property bool expanded: body.expanded
    readonly property bool pointerInside: body.islandController.pointerInside
    readonly property string activeActivity: body.islandController.activeActivity
    // An idle-shrunk nub keeps its full-size hit area; the drag area shares it or ring clicks would be lost.
    readonly property real hitPadding: root.idle ? Math.max(0, (root.dotSize - root.dotSize * root.idleScale) / 2) : 0
    // Blur regions are not antialiased and a small circle shows the jagged rim, so blur waits for the morph.
    readonly property bool blurWanted: !root.dot || Math.min(body.currentVisualWidth, body.currentVisualHeight) > root.dotSize * 1.5

    property real anchorX: 0
    property real anchorY: 0
    property bool dragging: false
    property bool idle: false

    function anchorLimit(size, extent) {
        const half = size / 2;
        const low = body.freeMargin + half;
        const high = extent - body.freeMargin - half;
        return high <= low ? [extent / 2, extent / 2] : [low, high];
    }

    function clampAnchorX(value) {
        const range = root.anchorLimit(root.compactWidth, root.screenWidth);
        return Math.max(range[0], Math.min(value, range[1]));
    }

    function clampAnchorY(value) {
        const range = root.anchorLimit(root.compactHeight, root.screenHeight);
        return Math.max(range[0], Math.min(value, range[1]));
    }

    function storeAnchor() {
        SessionData.setIslandFreePosition(root.positionKey, root.anchorX / root.screenWidth, root.anchorY / root.screenHeight);
    }

    function moveTo(x, y) {
        root.anchorX = root.clampAnchorX(x);
        root.anchorY = root.clampAnchorY(y);
        root.storeAnchor();
        root.wake();
    }

    function wake() {
        root.idle = false;
        if (root.idleDelay > 0)
            idleTimer.restart();
        else
            idleTimer.stop();
    }

    function requestKeyboardFocus() {
        body.requestKeyboardFocus();
    }

    function containsGlobalPoint(gx, gy, padding) {
        return body.containsGlobalPoint(gx, gy, padding);
    }

    onStoredAnchorXChanged: {
        if (!root.dragging)
            root.anchorX = root.storedAnchorX;
    }
    onStoredAnchorYChanged: {
        if (!root.dragging)
            root.anchorY = root.storedAnchorY;
    }
    onPointerInsideChanged: root.wake()
    onExpandedChanged: root.wake()
    onActiveActivityChanged: root.wake()

    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.namespace: "dms:dankisland"
    WlrLayershell.layer: LayerShell.fromEnv("DMS_DANKISLAND_LAYER", body.usesOverlayLayer ? WlrLayer.Overlay : WlrLayer.Top)
    WlrLayershell.keyboardFocus: body.keyboardFocusPolicy
    BackgroundEffect.blurRegion: root.blurWanted && BlurService.enabled && BlurService.available && body.surfaceOpacity > 0 && body.surfaceOpacity < 1 ? surfaceBlurRegion : null

    Region {
        id: surfaceBlurRegion

        x: body.x + body.currentVisualX
        y: body.y + body.currentVisualY
        width: body.currentVisualWidth
        height: body.currentVisualHeight
        radius: body.currentSurfaceRadius
    }

    anchors {
        top: true
        left: true
    }
    WlrLayershell.margins {
        left: root.surfaceX
        top: root.surfaceY
    }
    implicitWidth: Math.ceil(body.currentVisualX + body.currentVisualWidth + root.hitPadding) - root.surfaceX
    implicitHeight: Math.ceil(body.currentVisualY + body.currentVisualHeight + root.hitPadding) - root.surfaceY

    Component.onCompleted: {
        root.wake();
        KeyboardFocus.registerBarWindow(root);
    }
    Component.onDestruction: KeyboardFocus.unregisterBarWindow(root)

    DankFocusGrab {
        windows: [root, dismissWindow]
        wanted: body.wantsFocusGrab
    }

    Timer {
        id: idleTimer

        interval: Math.max(1000, root.idleDelay)
        onTriggered: {
            if (root.expanded || root.pointerInside || root.dragging || body.islandController.transientActive)
                return;
            root.idle = true;
        }
    }

    mask: Region {
        item: body.inputSuspended ? null : hitTarget
    }
    Item {
        id: hitTarget
        anchors.fill: parent
    }

    // Keep the animated buffer tight; the unmoving input-only window catches outside clicks.
    PanelWindow {
        id: dismissWindow
        screen: root.screen
        visible: root.expanded && !body.inputSuspended
        color: "transparent"
        exclusiveZone: -1
        WlrLayershell.namespace: "dms:dankisland-dismiss"
        WlrLayershell.layer: root.WlrLayershell.layer
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        mask: Region {
            width: dismissWindow.width
            height: dismissWindow.height
            Region {
                x: root.surfaceX
                y: root.surfaceY
                width: root.width
                height: root.height
                intersection: Intersection.Subtract
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: body.islandController.requestCollapse()
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.expanded && !body.inputSuspended
        onClicked: {
            SettingsData.recordBarInteraction(root.screen, root.barId);
            body.islandController.requestToggle(true);
        }
    }

    IslandBarHost {
        id: body

        x: -root.surfaceX
        y: -root.surfaceY
        width: root.screenWidth
        height: root.screenHeight
        originOffsetX: x
        originOffsetY: y
        barConfig: root.barConfig
        screen: root.screen
        hostWindow: root
        barId: root.barId
        anchorX: root.anchorX
        anchorY: root.anchorY
        anchorSnaps: root.dragging
        freeScale: root.idle ? root.idleScale : 1
        freeOpacity: root.idle ? root.idleOpacity : 1
    }

    IslandFreeDragArea {
        hostWindow: root
        surface: body.surface
        enabled: !root.expanded && !body.inputSuspended
    }
}
