pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: win

    required property var targetScreen

    screen: targetScreen
    visible: true

    WlrLayershell.namespace: "dms:frame"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    mask: Region {}

    readonly property var barEdges: {
        SettingsData.barConfigs;
        return SettingsData.getActiveBarEdgesForScreen(win.screen);
    }

    readonly property real _dpr: CompositorService.getScreenScale(win.screen)
    readonly property bool _frameActive: SettingsData.frameEnabled && SettingsData.isScreenInPreferences(win.screen, SettingsData.frameScreenPreferences)
    readonly property int _windowRegionWidth: win._regionInt(win.width)
    readonly property int _windowRegionHeight: win._regionInt(win.height)
    readonly property string _screenName: win.screen ? win.screen.name : ""
    readonly property var _dockState: ConnectedModeState.dockStates[win._screenName] || ConnectedModeState.emptyDockState
    readonly property var _dockSlide: ConnectedModeState.dockSlides[win._screenName] || ({
            "x": 0,
            "y": 0
        })

    // ─── Connected chrome convenience properties ──────────────────────────────
    readonly property bool _connectedActive: win._frameActive && SettingsData.connectedFrameModeActive
    readonly property string _barSide: {
        const edges = win.barEdges;
        if (edges.includes("top"))
            return "top";
        if (edges.includes("bottom"))
            return "bottom";
        if (edges.includes("left"))
            return "left";
        return "right";
    }
    readonly property real _ccr: Theme.connectedCornerRadius
    readonly property real _effectivePopoutCcr: {
        const extent = win._popoutArcExtent();
        const isHoriz = ConnectedModeState.popoutBarSide === "top" || ConnectedModeState.popoutBarSide === "bottom";
        const crossSize = isHoriz ? _popoutBodyBlurAnchor.width : _popoutBodyBlurAnchor.height;
        return Math.max(0, Math.min(win._ccr, extent, crossSize / 2));
    }
    readonly property color _surfaceColor: Theme.connectedSurfaceColor
    readonly property real _surfaceOpacity: _surfaceColor.a
    readonly property color _opaqueSurfaceColor: Qt.rgba(_surfaceColor.r, _surfaceColor.g, _surfaceColor.b, 1)
    readonly property real _surfaceRadius: Theme.connectedSurfaceRadius
    readonly property real _seamOverlap: Theme.hairline(win._dpr)

    function _regionInt(value) {
        return Math.max(0, Math.round(Theme.px(value, win._dpr)));
    }

    readonly property int cutoutTopInset: win._regionInt(barEdges.includes("top") ? SettingsData.frameBarSize : SettingsData.frameThickness)
    readonly property int cutoutBottomInset: win._regionInt(barEdges.includes("bottom") ? SettingsData.frameBarSize : SettingsData.frameThickness)
    readonly property int cutoutLeftInset: win._regionInt(barEdges.includes("left") ? SettingsData.frameBarSize : SettingsData.frameThickness)
    readonly property int cutoutRightInset: win._regionInt(barEdges.includes("right") ? SettingsData.frameBarSize : SettingsData.frameThickness)
    readonly property int cutoutWidth: Math.max(0, win._windowRegionWidth - win.cutoutLeftInset - win.cutoutRightInset)
    readonly property int cutoutHeight: Math.max(0, win._windowRegionHeight - win.cutoutTopInset - win.cutoutBottomInset)
    readonly property int cutoutRadius: {
        const requested = win._regionInt(SettingsData.frameRounding);
        const maxRadius = Math.floor(Math.min(win.cutoutWidth, win.cutoutHeight) / 2);
        return Math.max(0, Math.min(requested, maxRadius));
    }

    readonly property int _blurCutoutCompensation: SettingsData.frameOpacity <= 0.2 ? 1 : 0
    readonly property int _blurCutoutLeft: Math.max(0, win.cutoutLeftInset - win._blurCutoutCompensation)
    readonly property int _blurCutoutTop: Math.max(0, win.cutoutTopInset - win._blurCutoutCompensation)
    readonly property int _blurCutoutRight: Math.min(win._windowRegionWidth, win._windowRegionWidth - win.cutoutRightInset + win._blurCutoutCompensation)
    readonly property int _blurCutoutBottom: Math.min(win._windowRegionHeight, win._windowRegionHeight - win.cutoutBottomInset + win._blurCutoutCompensation)
    readonly property int _blurCutoutRadius: {
        const requested = win.cutoutRadius + win._blurCutoutCompensation;
        const maxRadius = Math.floor(Math.min(_blurCutout.width, _blurCutout.height) / 2);
        return Math.max(0, Math.min(requested, maxRadius));
    }

    // Invisible items providing scene coordinates for blur Region anchors
    Item {
        id: _blurCutout
        x: win._blurCutoutLeft
        y: win._blurCutoutTop
        width: Math.max(0, win._blurCutoutRight - win._blurCutoutLeft)
        height: Math.max(0, win._blurCutoutBottom - win._blurCutoutTop)
    }

    Item {
        id: _popoutBodyBlurAnchor
        visible: false

        readonly property bool _active: ConnectedModeState.popoutVisible && ConnectedModeState.popoutScreen === win._screenName

        readonly property real _dyClamp: (ConnectedModeState.popoutBarSide === "top" || ConnectedModeState.popoutBarSide === "bottom") ? Math.max(-ConnectedModeState.popoutBodyH, Math.min(ConnectedModeState.popoutAnimY, ConnectedModeState.popoutBodyH)) : 0
        readonly property real _dxClamp: (ConnectedModeState.popoutBarSide === "left" || ConnectedModeState.popoutBarSide === "right") ? Math.max(-ConnectedModeState.popoutBodyW, Math.min(ConnectedModeState.popoutAnimX, ConnectedModeState.popoutBodyW)) : 0

        x: _active ? ConnectedModeState.popoutBodyX + (ConnectedModeState.popoutBarSide === "right" ? _dxClamp : 0) : 0
        y: _active ? ConnectedModeState.popoutBodyY + (ConnectedModeState.popoutBarSide === "bottom" ? _dyClamp : 0) : 0
        width: _active ? Math.max(0, ConnectedModeState.popoutBodyW - Math.abs(_dxClamp)) : 0
        height: _active ? Math.max(0, ConnectedModeState.popoutBodyH - Math.abs(_dyClamp)) : 0
    }

    Item {
        id: _dockBodyBlurAnchor
        visible: false

        readonly property bool _active: win._dockState.reveal && win._dockState.bodyW > 0 && win._dockState.bodyH > 0

        x: _active ? win._dockState.bodyX + (win._dockSlide.x || 0) : 0
        y: _active ? win._dockState.bodyY + (win._dockSlide.y || 0) : 0
        width: _active ? win._dockState.bodyW : 0
        height: _active ? win._dockState.bodyH : 0
    }

    Item {
        id: _popoutBodyBlurCap
        opacity: 0

        readonly property string _side: ConnectedModeState.popoutBarSide
        readonly property real _capThickness: win._popoutBlurCapThickness()
        readonly property bool _active: _popoutBodyBlurAnchor._active && _capThickness > 0 && _popoutBodyBlurAnchor.width > 0 && _popoutBodyBlurAnchor.height > 0
        readonly property real _capWidth: (_side === "left" || _side === "right") ? Math.min(_capThickness, _popoutBodyBlurAnchor.width) : _popoutBodyBlurAnchor.width
        readonly property real _capHeight: (_side === "top" || _side === "bottom") ? Math.min(_capThickness, _popoutBodyBlurAnchor.height) : _popoutBodyBlurAnchor.height

        x: !_active ? 0 : (_side === "right" ? _popoutBodyBlurAnchor.x + _popoutBodyBlurAnchor.width - _capWidth : _popoutBodyBlurAnchor.x)
        y: !_active ? 0 : (_side === "bottom" ? _popoutBodyBlurAnchor.y + _popoutBodyBlurAnchor.height - _capHeight : _popoutBodyBlurAnchor.y)
        width: _active ? _capWidth : 0
        height: _active ? _capHeight : 0
    }

    Item {
        id: _dockBodyBlurCap
        opacity: 0

        readonly property string _side: win._dockState.barSide
        readonly property bool _active: _dockBodyBlurAnchor._active && _dockBodyBlurAnchor.width > 0 && _dockBodyBlurAnchor.height > 0
        readonly property real _capWidth: (_side === "left" || _side === "right") ? Math.min(win._dockConnectorRadius(), _dockBodyBlurAnchor.width) : _dockBodyBlurAnchor.width
        readonly property real _capHeight: (_side === "top" || _side === "bottom") ? Math.min(win._dockConnectorRadius(), _dockBodyBlurAnchor.height) : _dockBodyBlurAnchor.height

        x: !_active ? 0 : (_side === "right" ? _dockBodyBlurAnchor.x + _dockBodyBlurAnchor.width - _capWidth : _dockBodyBlurAnchor.x)
        y: !_active ? 0 : (_side === "bottom" ? _dockBodyBlurAnchor.y + _dockBodyBlurAnchor.height - _capHeight : _dockBodyBlurAnchor.y)
        width: _active ? _capWidth : 0
        height: _active ? _capHeight : 0
    }

    Item {
        id: _dockLeftConnectorBlurAnchor
        opacity: 0

        readonly property bool _active: _dockBodyBlurAnchor._active && win._dockConnectorRadius() > 0
        readonly property real _w: win._dockConnectorWidth(0)
        readonly property real _h: win._dockConnectorHeight(0)

        x: _active ? Theme.snap(win._dockConnectorX(_dockBodyBlurAnchor.x, _dockBodyBlurAnchor.width, "left", 0), win._dpr) : 0
        y: _active ? Theme.snap(win._dockConnectorY(_dockBodyBlurAnchor.y, _dockBodyBlurAnchor.height, "left", 0), win._dpr) : 0
        width: _active ? _w : 0
        height: _active ? _h : 0
    }

    Item {
        id: _dockRightConnectorBlurAnchor
        opacity: 0

        readonly property bool _active: _dockBodyBlurAnchor._active && win._dockConnectorRadius() > 0
        readonly property real _w: win._dockConnectorWidth(0)
        readonly property real _h: win._dockConnectorHeight(0)

        x: _active ? Theme.snap(win._dockConnectorX(_dockBodyBlurAnchor.x, _dockBodyBlurAnchor.width, "right", 0), win._dpr) : 0
        y: _active ? Theme.snap(win._dockConnectorY(_dockBodyBlurAnchor.y, _dockBodyBlurAnchor.height, "right", 0), win._dpr) : 0
        width: _active ? _w : 0
        height: _active ? _h : 0
    }

    Item {
        id: _dockLeftConnectorCutout
        opacity: 0

        readonly property bool _active: _dockLeftConnectorBlurAnchor.width > 0 && _dockLeftConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: win._connectorArcCorner(win._dockState.barSide, "left")

        x: _active ? win._connectorCutoutX(_dockLeftConnectorBlurAnchor.x, _dockLeftConnectorBlurAnchor.width, _arcCorner, win._dockConnectorRadius()) : 0
        y: _active ? win._connectorCutoutY(_dockLeftConnectorBlurAnchor.y, _dockLeftConnectorBlurAnchor.height, _arcCorner, win._dockConnectorRadius()) : 0
        width: _active ? win._dockConnectorRadius() * 2 : 0
        height: _active ? win._dockConnectorRadius() * 2 : 0
    }

    Item {
        id: _dockRightConnectorCutout
        opacity: 0

        readonly property bool _active: _dockRightConnectorBlurAnchor.width > 0 && _dockRightConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: win._connectorArcCorner(win._dockState.barSide, "right")

        x: _active ? win._connectorCutoutX(_dockRightConnectorBlurAnchor.x, _dockRightConnectorBlurAnchor.width, _arcCorner, win._dockConnectorRadius()) : 0
        y: _active ? win._connectorCutoutY(_dockRightConnectorBlurAnchor.y, _dockRightConnectorBlurAnchor.height, _arcCorner, win._dockConnectorRadius()) : 0
        width: _active ? win._dockConnectorRadius() * 2 : 0
        height: _active ? win._dockConnectorRadius() * 2 : 0
    }

    Item {
        id: _popoutLeftConnectorBlurAnchor
        opacity: 0

        readonly property bool _active: win._popoutArcVisible()
        readonly property real _w: win._popoutConnectorWidth(0)
        readonly property real _h: win._popoutConnectorHeight(0)

        x: _active ? Theme.snap(win._popoutConnectorX(ConnectedModeState.popoutBodyX, ConnectedModeState.popoutBodyW, "left", 0), win._dpr) : 0
        y: _active ? Theme.snap(win._popoutConnectorY(ConnectedModeState.popoutBodyY, ConnectedModeState.popoutBodyH, "left", 0), win._dpr) : 0
        width: _active ? _w : 0
        height: _active ? _h : 0
    }

    Item {
        id: _popoutRightConnectorBlurAnchor
        opacity: 0

        readonly property bool _active: win._popoutArcVisible()
        readonly property real _w: win._popoutConnectorWidth(0)
        readonly property real _h: win._popoutConnectorHeight(0)

        x: _active ? Theme.snap(win._popoutConnectorX(ConnectedModeState.popoutBodyX, ConnectedModeState.popoutBodyW, "right", 0), win._dpr) : 0
        y: _active ? Theme.snap(win._popoutConnectorY(ConnectedModeState.popoutBodyY, ConnectedModeState.popoutBodyH, "right", 0), win._dpr) : 0
        width: _active ? _w : 0
        height: _active ? _h : 0
    }

    Item {
        id: _popoutLeftConnectorCutout
        opacity: 0

        readonly property bool _active: _popoutLeftConnectorBlurAnchor.width > 0 && _popoutLeftConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: win._connectorArcCorner(ConnectedModeState.popoutBarSide, "left")

        x: _active ? win._connectorCutoutX(_popoutLeftConnectorBlurAnchor.x, _popoutLeftConnectorBlurAnchor.width, _arcCorner) : 0
        y: _active ? win._connectorCutoutY(_popoutLeftConnectorBlurAnchor.y, _popoutLeftConnectorBlurAnchor.height, _arcCorner) : 0
        width: _active ? win._effectivePopoutCcr * 2 : 0
        height: _active ? win._effectivePopoutCcr * 2 : 0
    }

    Item {
        id: _popoutRightConnectorCutout
        opacity: 0

        readonly property bool _active: _popoutRightConnectorBlurAnchor.width > 0 && _popoutRightConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: win._connectorArcCorner(ConnectedModeState.popoutBarSide, "right")

        x: _active ? win._connectorCutoutX(_popoutRightConnectorBlurAnchor.x, _popoutRightConnectorBlurAnchor.width, _arcCorner) : 0
        y: _active ? win._connectorCutoutY(_popoutRightConnectorBlurAnchor.y, _popoutRightConnectorBlurAnchor.height, _arcCorner) : 0
        width: _active ? win._effectivePopoutCcr * 2 : 0
        height: _active ? win._effectivePopoutCcr * 2 : 0
    }

    Region {
        id: _staticBlurRegion
        x: 0
        y: 0
        width: win._windowRegionWidth
        height: win._windowRegionHeight

        // Frame cutout (always active when frame is on)
        Region {
            item: _blurCutout
            intersection: Intersection.Subtract
            radius: win._blurCutoutRadius
        }

        // ── Connected popout blur regions ──
        Region {
            item: _popoutBodyBlurAnchor
            readonly property string _bs: ConnectedModeState.popoutBarSide
            topLeftRadius: (_bs === "top" || _bs === "left") ? win._effectivePopoutCcr : win._surfaceRadius
            topRightRadius: (_bs === "top" || _bs === "right") ? win._effectivePopoutCcr : win._surfaceRadius
            bottomLeftRadius: (_bs === "bottom" || _bs === "left") ? win._effectivePopoutCcr : win._surfaceRadius
            bottomRightRadius: (_bs === "bottom" || _bs === "right") ? win._effectivePopoutCcr : win._surfaceRadius
        }
        Region {
            item: _popoutBodyBlurCap
        }
        Region {
            item: _popoutLeftConnectorBlurAnchor
            Region {
                item: _popoutLeftConnectorCutout
                intersection: Intersection.Subtract
                radius: win._effectivePopoutCcr
            }
        }
        Region {
            item: _popoutRightConnectorBlurAnchor
            Region {
                item: _popoutRightConnectorCutout
                intersection: Intersection.Subtract
                radius: win._effectivePopoutCcr
            }
        }

        // ── Connected dock blur regions ──
        Region {
            item: _dockBodyBlurAnchor
            radius: win._dockBodyBlurRadius()
        }
        Region {
            item: _dockBodyBlurCap
        }
        Region {
            item: _dockLeftConnectorBlurAnchor
            radius: win._dockConnectorRadius()
            Region {
                item: _dockLeftConnectorCutout
                intersection: Intersection.Subtract
                radius: win._dockConnectorRadius()
            }
        }
        Region {
            item: _dockRightConnectorBlurAnchor
            radius: win._dockConnectorRadius()
            Region {
                item: _dockRightConnectorCutout
                intersection: Intersection.Subtract
                radius: win._dockConnectorRadius()
            }
        }
    }

    // ─── Connector position helpers (mirror DankPopout / Dock logic) ──────────

    function _popoutConnectorWidth(spacing) {
        const barSide = ConnectedModeState.popoutBarSide;
        return (barSide === "top" || barSide === "bottom") ? win._effectivePopoutCcr : (spacing + win._effectivePopoutCcr);
    }

    function _popoutConnectorHeight(spacing) {
        const barSide = ConnectedModeState.popoutBarSide;
        return (barSide === "top" || barSide === "bottom") ? (spacing + win._effectivePopoutCcr) : win._effectivePopoutCcr;
    }

    function _popoutConnectorX(baseX, bodyWidth, placement, spacing) {
        const barSide = ConnectedModeState.popoutBarSide;
        const seamX = (barSide === "top" || barSide === "bottom") ? (placement === "left" ? baseX : baseX + bodyWidth) : (barSide === "left" ? baseX : baseX + bodyWidth);
        const w = _popoutConnectorWidth(spacing);
        if (barSide === "top" || barSide === "bottom")
            return placement === "left" ? seamX - w : seamX;
        return barSide === "left" ? seamX : seamX - w;
    }

    function _popoutConnectorY(baseY, bodyHeight, placement, spacing) {
        const barSide = ConnectedModeState.popoutBarSide;
        const seamY = barSide === "top" ? baseY : barSide === "bottom" ? baseY + bodyHeight : (placement === "left" ? baseY : baseY + bodyHeight);
        const h = _popoutConnectorHeight(spacing);
        if (barSide === "top")
            return seamY;
        if (barSide === "bottom")
            return seamY - h;
        return placement === "left" ? seamY - h : seamY;
    }

    function _dockBodyBlurRadius() {
        return _dockBodyBlurAnchor._active ? Math.max(0, Math.min(win._surfaceRadius, _dockBodyBlurAnchor.width / 2, _dockBodyBlurAnchor.height / 2)) : win._surfaceRadius;
    }

    function _dockConnectorRadius() {
        if (!_dockBodyBlurAnchor._active)
            return win._ccr;
        const dockSide = win._dockState.barSide;
        const thickness = (dockSide === "left" || dockSide === "right") ? _dockBodyBlurAnchor.width : _dockBodyBlurAnchor.height;
        const bodyRadius = win._dockBodyBlurRadius();
        const maxConnectorRadius = Math.max(0, thickness - bodyRadius - win._seamOverlap);
        return Math.max(0, Math.min(win._ccr, bodyRadius, maxConnectorRadius));
    }

    function _dockConnectorWidth(spacing) {
        const isVert = win._dockState.barSide === "left" || win._dockState.barSide === "right";
        const radius = win._dockConnectorRadius();
        return isVert ? (spacing + radius) : radius;
    }

    function _dockConnectorHeight(spacing) {
        const isVert = win._dockState.barSide === "left" || win._dockState.barSide === "right";
        const radius = win._dockConnectorRadius();
        return isVert ? radius : (spacing + radius);
    }

    function _dockConnectorX(baseX, bodyWidth, placement, spacing) {
        const dockSide = win._dockState.barSide;
        const isVert = dockSide === "left" || dockSide === "right";
        const seamX = !isVert ? (placement === "left" ? baseX : baseX + bodyWidth) : (dockSide === "left" ? baseX : baseX + bodyWidth);
        const w = _dockConnectorWidth(spacing);
        if (!isVert)
            return placement === "left" ? seamX - w : seamX;
        return dockSide === "left" ? seamX : seamX - w;
    }

    function _dockConnectorY(baseY, bodyHeight, placement, spacing) {
        const dockSide = win._dockState.barSide;
        const seamY = dockSide === "top" ? baseY : dockSide === "bottom" ? baseY + bodyHeight : (placement === "left" ? baseY : baseY + bodyHeight);
        const h = _dockConnectorHeight(spacing);
        if (dockSide === "top")
            return seamY;
        if (dockSide === "bottom")
            return seamY - h;
        return placement === "left" ? seamY - h : seamY;
    }

    function _popoutFillOverlapX() {
        return (ConnectedModeState.popoutBarSide === "top" || ConnectedModeState.popoutBarSide === "bottom") ? win._seamOverlap : 0;
    }

    function _popoutFillOverlapY() {
        return (ConnectedModeState.popoutBarSide === "left" || ConnectedModeState.popoutBarSide === "right") ? win._seamOverlap : 0;
    }

    function _dockFillOverlapX() {
        return (win._dockState.barSide === "top" || win._dockState.barSide === "bottom") ? win._seamOverlap : 0;
    }

    function _dockFillOverlapY() {
        return (win._dockState.barSide === "left" || win._dockState.barSide === "right") ? win._seamOverlap : 0;
    }

    function _popoutArcExtent() {
        return (ConnectedModeState.popoutBarSide === "top" || ConnectedModeState.popoutBarSide === "bottom") ? _popoutBodyBlurAnchor.height : _popoutBodyBlurAnchor.width;
    }

    function _popoutArcVisible() {
        if (!_popoutBodyBlurAnchor._active || _popoutBodyBlurAnchor.width <= 0 || _popoutBodyBlurAnchor.height <= 0)
            return false;
        return win._popoutArcExtent() >= win._ccr * (1 + win._ccr * 0.02);
    }

    function _popoutBlurCapThickness() {
        const extent = win._popoutArcExtent();
        return Math.max(0, Math.min(win._effectivePopoutCcr, extent - win._surfaceRadius));
    }

    function _popoutChromeX() {
        const barSide = ConnectedModeState.popoutBarSide;
        return ConnectedModeState.popoutBodyX - ((barSide === "top" || barSide === "bottom") ? win._effectivePopoutCcr : 0);
    }

    function _popoutChromeY() {
        const barSide = ConnectedModeState.popoutBarSide;
        return ConnectedModeState.popoutBodyY - ((barSide === "left" || barSide === "right") ? win._effectivePopoutCcr : 0);
    }

    function _popoutChromeWidth() {
        const barSide = ConnectedModeState.popoutBarSide;
        return ConnectedModeState.popoutBodyW + ((barSide === "top" || barSide === "bottom") ? win._effectivePopoutCcr * 2 : 0);
    }

    function _popoutChromeHeight() {
        const barSide = ConnectedModeState.popoutBarSide;
        return ConnectedModeState.popoutBodyH + ((barSide === "left" || barSide === "right") ? win._effectivePopoutCcr * 2 : 0);
    }

    function _popoutClipX() {
        return _popoutBodyBlurAnchor.x - win._popoutChromeX() - win._popoutFillOverlapX();
    }

    function _popoutClipY() {
        return _popoutBodyBlurAnchor.y - win._popoutChromeY() - win._popoutFillOverlapY();
    }

    function _popoutClipWidth() {
        return _popoutBodyBlurAnchor.width + win._popoutFillOverlapX() * 2;
    }

    function _popoutClipHeight() {
        return _popoutBodyBlurAnchor.height + win._popoutFillOverlapY() * 2;
    }

    function _popoutBodyXInClip() {
        return (ConnectedModeState.popoutBarSide === "left" ? _popoutBodyBlurAnchor._dxClamp : 0) - win._popoutFillOverlapX();
    }

    function _popoutBodyYInClip() {
        return (ConnectedModeState.popoutBarSide === "top" ? _popoutBodyBlurAnchor._dyClamp : 0) - win._popoutFillOverlapY();
    }

    function _popoutBodyFullWidth() {
        return ConnectedModeState.popoutBodyW + win._popoutFillOverlapX() * 2;
    }

    function _popoutBodyFullHeight() {
        return ConnectedModeState.popoutBodyH + win._popoutFillOverlapY() * 2;
    }

    function _dockChromeX() {
        const dockSide = win._dockState.barSide;
        return _dockBodyBlurAnchor.x - ((dockSide === "top" || dockSide === "bottom") ? win._dockConnectorRadius() : 0);
    }

    function _dockChromeY() {
        const dockSide = win._dockState.barSide;
        return _dockBodyBlurAnchor.y - ((dockSide === "left" || dockSide === "right") ? win._dockConnectorRadius() : 0);
    }

    function _dockChromeWidth() {
        const dockSide = win._dockState.barSide;
        return _dockBodyBlurAnchor.width + ((dockSide === "top" || dockSide === "bottom") ? win._dockConnectorRadius() * 2 : 0);
    }

    function _dockChromeHeight() {
        const dockSide = win._dockState.barSide;
        return _dockBodyBlurAnchor.height + ((dockSide === "left" || dockSide === "right") ? win._dockConnectorRadius() * 2 : 0);
    }

    function _dockBodyXInChrome() {
        return ((win._dockState.barSide === "top" || win._dockState.barSide === "bottom") ? win._dockConnectorRadius() : 0) - win._dockFillOverlapX();
    }

    function _dockBodyYInChrome() {
        return ((win._dockState.barSide === "left" || win._dockState.barSide === "right") ? win._dockConnectorRadius() : 0) - win._dockFillOverlapY();
    }

    function _connectorArcCorner(barSide, placement) {
        if (barSide === "top")
            return placement === "left" ? "bottomLeft" : "bottomRight";
        if (barSide === "bottom")
            return placement === "left" ? "topLeft" : "topRight";
        if (barSide === "left")
            return placement === "left" ? "topRight" : "bottomRight";
        return placement === "left" ? "topLeft" : "bottomLeft";
    }

    function _connectorCutoutX(connectorX, connectorWidth, arcCorner, radius) {
        const r = radius === undefined ? win._effectivePopoutCcr : radius;
        return (arcCorner === "topLeft" || arcCorner === "bottomLeft") ? connectorX - r : connectorX + connectorWidth - r;
    }

    function _connectorCutoutY(connectorY, connectorHeight, arcCorner, radius) {
        const r = radius === undefined ? win._effectivePopoutCcr : radius;
        return (arcCorner === "topLeft" || arcCorner === "topRight") ? connectorY - r : connectorY + connectorHeight - r;
    }

    // ─── Blur build / teardown ────────────────────────────────────────────────

    function _buildBlur() {
        try {
            if (!BlurService.enabled || !SettingsData.frameBlurEnabled || !win._frameActive || !win.visible) {
                win.BackgroundEffect.blurRegion = null;
                return;
            }
            win.BackgroundEffect.blurRegion = _staticBlurRegion;
        } catch (e) {
            console.warn("FrameWindow: Failed to set blur region:", e);
        }
    }

    function _teardownBlur() {
        try {
            win.BackgroundEffect.blurRegion = null;
        } catch (e) {}
    }

    Timer {
        id: _blurRebuildTimer
        interval: 1
        onTriggered: win._buildBlur()
    }

    Connections {
        target: SettingsData
        function onFrameBlurEnabledChanged() {
            _blurRebuildTimer.restart();
        }
        function onFrameEnabledChanged() {
            _blurRebuildTimer.restart();
        }
        function onFrameThicknessChanged() {
            _blurRebuildTimer.restart();
        }
        function onFrameBarSizeChanged() {
            _blurRebuildTimer.restart();
        }
        function onFrameOpacityChanged() {
            _blurRebuildTimer.restart();
        }
        function onFrameRoundingChanged() {
            _blurRebuildTimer.restart();
        }
        function onFrameScreenPreferencesChanged() {
            _blurRebuildTimer.restart();
        }
        function onBarConfigsChanged() {
            _blurRebuildTimer.restart();
        }
        function onConnectedFrameModeActiveChanged() {
            _blurRebuildTimer.restart();
        }
    }

    Connections {
        target: BlurService
        function onEnabledChanged() {
            _blurRebuildTimer.restart();
        }
    }

    onVisibleChanged: {
        if (visible) {
            _blurRebuildTimer.restart();
        } else {
            _teardownBlur();
        }
    }

    Component.onCompleted: Qt.callLater(() => win._buildBlur())
    Component.onDestruction: win._teardownBlur()

    // ─── Frame border ─────────────────────────────────────────────────────────

    FrameBorder {
        anchors.fill: parent
        visible: win._frameActive
        cutoutTopInset: win.cutoutTopInset
        cutoutBottomInset: win.cutoutBottomInset
        cutoutLeftInset: win.cutoutLeftInset
        cutoutRightInset: win.cutoutRightInset
        cutoutRadius: win.cutoutRadius
    }

    // ─── Connected chrome fills ───────────────────────────────────────────────

    Item {
        id: _connectedChrome
        anchors.fill: parent
        visible: win._connectedActive

        Item {
            id: _popoutChrome
            visible: ConnectedModeState.popoutVisible && ConnectedModeState.popoutScreen === win._screenName
            x: win._popoutChromeX()
            y: win._popoutChromeY()
            width: win._popoutChromeWidth()
            height: win._popoutChromeHeight()
            opacity: win._surfaceOpacity
            layer.enabled: opacity < 1
            layer.smooth: false

            Item {
                id: _popoutClip
                x: win._popoutClipX()
                y: win._popoutClipY()
                width: win._popoutClipWidth()
                height: win._popoutClipHeight()
                clip: true

                Rectangle {
                    id: _popoutFill
                    x: win._popoutBodyXInClip()
                    y: win._popoutBodyYInClip()
                    width: win._popoutBodyFullWidth()
                    height: win._popoutBodyFullHeight()
                    color: win._opaqueSurfaceColor
                    z: 1
                    topLeftRadius: (ConnectedModeState.popoutBarSide === "top" || ConnectedModeState.popoutBarSide === "left") ? 0 : win._surfaceRadius
                    topRightRadius: (ConnectedModeState.popoutBarSide === "top" || ConnectedModeState.popoutBarSide === "right") ? 0 : win._surfaceRadius
                    bottomLeftRadius: (ConnectedModeState.popoutBarSide === "bottom" || ConnectedModeState.popoutBarSide === "left") ? 0 : win._surfaceRadius
                    bottomRightRadius: (ConnectedModeState.popoutBarSide === "bottom" || ConnectedModeState.popoutBarSide === "right") ? 0 : win._surfaceRadius
                }
            }

            ConnectedCorner {
                id: _connPopoutLeft
                visible: win._popoutArcVisible()
                barSide: ConnectedModeState.popoutBarSide
                placement: "left"
                spacing: 0
                connectorRadius: win._effectivePopoutCcr
                color: win._opaqueSurfaceColor
                edgeStrokeWidth: win._seamOverlap
                edgeStrokeColor: win._opaqueSurfaceColor
                dpr: win._dpr
                x: Theme.snap(win._popoutConnectorX(ConnectedModeState.popoutBodyX, ConnectedModeState.popoutBodyW, "left", 0) - _popoutChrome.x, win._dpr)
                y: Theme.snap(win._popoutConnectorY(ConnectedModeState.popoutBodyY, ConnectedModeState.popoutBodyH, "left", 0) - _popoutChrome.y, win._dpr)
            }

            ConnectedCorner {
                id: _connPopoutRight
                visible: win._popoutArcVisible()
                barSide: ConnectedModeState.popoutBarSide
                placement: "right"
                spacing: 0
                connectorRadius: win._effectivePopoutCcr
                color: win._opaqueSurfaceColor
                edgeStrokeWidth: win._seamOverlap
                edgeStrokeColor: win._opaqueSurfaceColor
                dpr: win._dpr
                x: Theme.snap(win._popoutConnectorX(ConnectedModeState.popoutBodyX, ConnectedModeState.popoutBodyW, "right", 0) - _popoutChrome.x, win._dpr)
                y: Theme.snap(win._popoutConnectorY(ConnectedModeState.popoutBodyY, ConnectedModeState.popoutBodyH, "right", 0) - _popoutChrome.y, win._dpr)
            }
        }

        Item {
            id: _dockChrome
            visible: _dockBodyBlurAnchor._active
            x: win._dockChromeX()
            y: win._dockChromeY()
            width: win._dockChromeWidth()
            height: win._dockChromeHeight()
            opacity: win._surfaceOpacity
            layer.enabled: opacity < 1
            layer.smooth: false

            Rectangle {
                id: _dockFill
                x: win._dockBodyXInChrome()
                y: win._dockBodyYInChrome()
                width: _dockBodyBlurAnchor.width + win._dockFillOverlapX() * 2
                height: _dockBodyBlurAnchor.height + win._dockFillOverlapY() * 2
                color: win._opaqueSurfaceColor
                z: 1

                readonly property string _dockSide: win._dockState.barSide
                readonly property real _dockRadius: win._dockBodyBlurRadius()
                topLeftRadius: (_dockSide === "top" || _dockSide === "left") ? 0 : _dockRadius
                topRightRadius: (_dockSide === "top" || _dockSide === "right") ? 0 : _dockRadius
                bottomLeftRadius: (_dockSide === "bottom" || _dockSide === "left") ? 0 : _dockRadius
                bottomRightRadius: (_dockSide === "bottom" || _dockSide === "right") ? 0 : _dockRadius
            }

            ConnectedCorner {
                id: _connDockLeft
                visible: _dockBodyBlurAnchor._active
                barSide: win._dockState.barSide
                placement: "left"
                spacing: 0
                connectorRadius: win._dockConnectorRadius()
                color: win._opaqueSurfaceColor
                dpr: win._dpr
                x: Theme.snap(win._dockConnectorX(_dockBodyBlurAnchor.x, _dockBodyBlurAnchor.width, "left", 0) - _dockChrome.x, win._dpr)
                y: Theme.snap(win._dockConnectorY(_dockBodyBlurAnchor.y, _dockBodyBlurAnchor.height, "left", 0) - _dockChrome.y, win._dpr)
            }

            ConnectedCorner {
                id: _connDockRight
                visible: _dockBodyBlurAnchor._active
                barSide: win._dockState.barSide
                placement: "right"
                spacing: 0
                connectorRadius: win._dockConnectorRadius()
                color: win._opaqueSurfaceColor
                dpr: win._dpr
                x: Theme.snap(win._dockConnectorX(_dockBodyBlurAnchor.x, _dockBodyBlurAnchor.width, "right", 0) - _dockChrome.x, win._dpr)
                y: Theme.snap(win._dockConnectorY(_dockBodyBlurAnchor.y, _dockBodyBlurAnchor.height, "right", 0) - _dockChrome.y, win._dpr)
            }
        }
    }
}
