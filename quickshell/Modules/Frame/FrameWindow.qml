pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
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
    readonly property var _notifState: ConnectedModeState.notificationStates[win._screenName] || ConnectedModeState.emptyNotificationState

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
    readonly property real _effectiveNotifCcr: {
        const isHoriz = win._notifState.barSide === "top" || win._notifState.barSide === "bottom";
        const crossSize = isHoriz ? _notifBodyBlurAnchor.width : _notifBodyBlurAnchor.height;
        const extent = isHoriz ? _notifBodyBlurAnchor.height : _notifBodyBlurAnchor.width;
        return Theme.snap(Math.max(0, Math.min(win._ccr, win._surfaceRadius, extent, crossSize / 2)), win._dpr);
    }
    readonly property color _surfaceColor: Theme.connectedSurfaceColor
    readonly property real _surfaceOpacity: _surfaceColor.a
    readonly property color _opaqueSurfaceColor: Qt.rgba(_surfaceColor.r, _surfaceColor.g, _surfaceColor.b, 1)
    readonly property real _surfaceRadius: Theme.connectedSurfaceRadius
    readonly property real _seamOverlap: Theme.hairline(win._dpr)
    readonly property bool _disableLayer: Quickshell.env("DMS_DISABLE_LAYER") === "true" || Quickshell.env("DMS_DISABLE_LAYER") === "1"

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

        readonly property real _dyClamp: (ConnectedModeState.popoutBarSide === "top" || ConnectedModeState.popoutBarSide === "bottom") ? Math.max(-ConnectedModeState.popoutBodyH, Math.min(ConnectedModeState.popoutAnimY * 1.02, ConnectedModeState.popoutBodyH)) : 0
        readonly property real _dxClamp: (ConnectedModeState.popoutBarSide === "left" || ConnectedModeState.popoutBarSide === "right") ? Math.max(-ConnectedModeState.popoutBodyW, Math.min(ConnectedModeState.popoutAnimX * 1.02, ConnectedModeState.popoutBodyW)) : 0

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
        id: _popoutLeftConnectorBlurAnchor
        opacity: 0

        readonly property bool _active: _popoutBodyBlurAnchor._active && win._effectivePopoutCcr > 0
        readonly property real _w: win._popoutConnectorWidth(0)
        readonly property real _h: win._popoutConnectorHeight(0)

        x: _active ? Theme.snap(win._popoutConnectorX(_popoutBodyBlurAnchor.x, _popoutBodyBlurAnchor.width, "left", 0), win._dpr) : 0
        y: _active ? Theme.snap(win._popoutConnectorY(_popoutBodyBlurAnchor.y, _popoutBodyBlurAnchor.height, "left", 0), win._dpr) : 0
        width: _active ? _w : 0
        height: _active ? _h : 0
    }

    Item {
        id: _popoutRightConnectorBlurAnchor
        opacity: 0

        readonly property bool _active: _popoutBodyBlurAnchor._active && win._effectivePopoutCcr > 0
        readonly property real _w: win._popoutConnectorWidth(0)
        readonly property real _h: win._popoutConnectorHeight(0)

        x: _active ? Theme.snap(win._popoutConnectorX(_popoutBodyBlurAnchor.x, _popoutBodyBlurAnchor.width, "right", 0), win._dpr) : 0
        y: _active ? Theme.snap(win._popoutConnectorY(_popoutBodyBlurAnchor.y, _popoutBodyBlurAnchor.height, "right", 0), win._dpr) : 0
        width: _active ? _w : 0
        height: _active ? _h : 0
    }

    Item {
        id: _popoutLeftConnectorCutout
        opacity: 0

        readonly property bool _active: _popoutLeftConnectorBlurAnchor.width > 0 && _popoutLeftConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: win._connectorArcCorner(ConnectedModeState.popoutBarSide, "left")

        x: _active ? win._connectorCutoutX(_popoutLeftConnectorBlurAnchor.x, _popoutLeftConnectorBlurAnchor.width, _arcCorner, win._effectivePopoutCcr) : 0
        y: _active ? win._connectorCutoutY(_popoutLeftConnectorBlurAnchor.y, _popoutLeftConnectorBlurAnchor.height, _arcCorner, win._effectivePopoutCcr) : 0
        width: _active ? win._effectivePopoutCcr * 2 : 0
        height: _active ? win._effectivePopoutCcr * 2 : 0
    }

    Item {
        id: _popoutRightConnectorCutout
        opacity: 0

        readonly property bool _active: _popoutRightConnectorBlurAnchor.width > 0 && _popoutRightConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: win._connectorArcCorner(ConnectedModeState.popoutBarSide, "right")

        x: _active ? win._connectorCutoutX(_popoutRightConnectorBlurAnchor.x, _popoutRightConnectorBlurAnchor.width, _arcCorner, win._effectivePopoutCcr) : 0
        y: _active ? win._connectorCutoutY(_popoutRightConnectorBlurAnchor.y, _popoutRightConnectorBlurAnchor.height, _arcCorner, win._effectivePopoutCcr) : 0
        width: _active ? win._effectivePopoutCcr * 2 : 0
        height: _active ? win._effectivePopoutCcr * 2 : 0
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
        id: _notifBodyBlurAnchor
        visible: false

        readonly property bool _active: win._frameActive && win._notifState.visible && win._notifState.bodyW > 0 && win._notifState.bodyH > 0

        x: _active ? Theme.snap(win._notifState.bodyX, win._dpr) : 0
        y: _active ? Theme.snap(win._notifState.bodyY, win._dpr) : 0
        width: _active ? Theme.snap(win._notifState.bodyW, win._dpr) : 0
        height: _active ? Theme.snap(win._notifState.bodyH, win._dpr) : 0
    }

    Item {
        id: _notifBodyBlurCap
        opacity: 0

        readonly property string _side: win._notifState.barSide
        readonly property bool _active: _notifBodyBlurAnchor._active && _notifBodyBlurAnchor.width > 0 && _notifBodyBlurAnchor.height > 0 && win._notifConnectorRadius() > 0
        readonly property real _capWidth: (_side === "left" || _side === "right") ? Math.min(win._notifConnectorRadius(), _notifBodyBlurAnchor.width) : _notifBodyBlurAnchor.width
        readonly property real _capHeight: (_side === "top" || _side === "bottom") ? Math.min(win._notifConnectorRadius(), _notifBodyBlurAnchor.height) : _notifBodyBlurAnchor.height

        x: !_active ? 0 : (_side === "right" ? _notifBodyBlurAnchor.x + _notifBodyBlurAnchor.width - _capWidth : _notifBodyBlurAnchor.x)
        y: !_active ? 0 : (_side === "bottom" ? _notifBodyBlurAnchor.y + _notifBodyBlurAnchor.height - _capHeight : _notifBodyBlurAnchor.y)
        width: _active ? _capWidth : 0
        height: _active ? _capHeight : 0
    }

    Item {
        id: _notifLeftConnectorBlurAnchor
        opacity: 0

        readonly property bool _active: _notifBodyBlurAnchor._active && win._notifConnectorRadius() > 0
        readonly property real _w: win._notifConnectorWidth(0)
        readonly property real _h: win._notifConnectorHeight(0)

        x: _active ? Theme.snap(win._notifConnectorX(_notifBodyBlurAnchor.x, _notifBodyBlurAnchor.width, "left", 0), win._dpr) : 0
        y: _active ? Theme.snap(win._notifConnectorY(_notifBodyBlurAnchor.y, _notifBodyBlurAnchor.height, "left", 0), win._dpr) : 0
        width: _active ? _w : 0
        height: _active ? _h : 0
    }

    Item {
        id: _notifRightConnectorBlurAnchor
        opacity: 0

        readonly property bool _active: _notifBodyBlurAnchor._active && win._notifConnectorRadius() > 0
        readonly property real _w: win._notifConnectorWidth(0)
        readonly property real _h: win._notifConnectorHeight(0)

        x: _active ? Theme.snap(win._notifConnectorX(_notifBodyBlurAnchor.x, _notifBodyBlurAnchor.width, "right", 0), win._dpr) : 0
        y: _active ? Theme.snap(win._notifConnectorY(_notifBodyBlurAnchor.y, _notifBodyBlurAnchor.height, "right", 0), win._dpr) : 0
        width: _active ? _w : 0
        height: _active ? _h : 0
    }

    Item {
        id: _notifLeftConnectorCutout
        opacity: 0

        readonly property bool _active: _notifLeftConnectorBlurAnchor.width > 0 && _notifLeftConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: win._connectorArcCorner(win._notifState.barSide, "left")

        x: _active ? win._connectorCutoutX(_notifLeftConnectorBlurAnchor.x, _notifLeftConnectorBlurAnchor.width, _arcCorner, win._notifConnectorRadius()) : 0
        y: _active ? win._connectorCutoutY(_notifLeftConnectorBlurAnchor.y, _notifLeftConnectorBlurAnchor.height, _arcCorner, win._notifConnectorRadius()) : 0
        width: _active ? win._notifConnectorRadius() * 2 : 0
        height: _active ? win._notifConnectorRadius() * 2 : 0
    }

    Item {
        id: _notifRightConnectorCutout
        opacity: 0

        readonly property bool _active: _notifRightConnectorBlurAnchor.width > 0 && _notifRightConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: win._connectorArcCorner(win._notifState.barSide, "right")

        x: _active ? win._connectorCutoutX(_notifRightConnectorBlurAnchor.x, _notifRightConnectorBlurAnchor.width, _arcCorner, win._notifConnectorRadius()) : 0
        y: _active ? win._connectorCutoutY(_notifRightConnectorBlurAnchor.y, _notifRightConnectorBlurAnchor.height, _arcCorner, win._notifConnectorRadius()) : 0
        width: _active ? win._notifConnectorRadius() * 2 : 0
        height: _active ? win._notifConnectorRadius() * 2 : 0
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
            radius: win._surfaceRadius
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
            Region {
                item: _dockLeftConnectorCutout
                intersection: Intersection.Subtract
                radius: win._dockConnectorRadius()
            }
        }
        Region {
            item: _dockRightConnectorBlurAnchor
            Region {
                item: _dockRightConnectorCutout
                intersection: Intersection.Subtract
                radius: win._dockConnectorRadius()
            }
        }

        Region {
            item: _notifBodyBlurAnchor
            radius: win._surfaceRadius
        }
        Region {
            item: _notifBodyBlurCap
        }
        Region {
            item: _notifLeftConnectorBlurAnchor
            Region {
                item: _notifLeftConnectorCutout
                intersection: Intersection.Subtract
                radius: win._notifConnectorRadius()
            }
        }
        Region {
            item: _notifRightConnectorBlurAnchor
            Region {
                item: _notifRightConnectorCutout
                intersection: Intersection.Subtract
                radius: win._notifConnectorRadius()
            }
        }
    }

    // ─── Connector position helpers ────────────────────────────────────────

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

    function _notifConnectorRadius() {
        return win._effectiveNotifCcr;
    }

    function _notifConnectorWidth(spacing) {
        const isVert = win._notifState.barSide === "left" || win._notifState.barSide === "right";
        const radius = win._notifConnectorRadius();
        return isVert ? (spacing + radius) : radius;
    }

    function _notifConnectorHeight(spacing) {
        const isVert = win._notifState.barSide === "left" || win._notifState.barSide === "right";
        const radius = win._notifConnectorRadius();
        return isVert ? radius : (spacing + radius);
    }

    function _notifConnectorX(baseX, bodyWidth, placement, spacing) {
        const notifSide = win._notifState.barSide;
        const isVert = notifSide === "left" || notifSide === "right";
        const seamX = !isVert ? (placement === "left" ? baseX : baseX + bodyWidth) : (notifSide === "left" ? baseX : baseX + bodyWidth);
        const w = _notifConnectorWidth(spacing);
        if (!isVert)
            return placement === "left" ? seamX - w : seamX;
        return notifSide === "left" ? seamX : seamX - w;
    }

    function _notifConnectorY(baseY, bodyHeight, placement, spacing) {
        const notifSide = win._notifState.barSide;
        const seamY = notifSide === "top" ? baseY : notifSide === "bottom" ? baseY + bodyHeight : (placement === "left" ? baseY : baseY + bodyHeight);
        const h = _notifConnectorHeight(spacing);
        if (notifSide === "top")
            return seamY;
        if (notifSide === "bottom")
            return seamY - h;
        return placement === "left" ? seamY - h : seamY;
    }

    function _popoutConnectorWidth(spacing) {
        const isVert = ConnectedModeState.popoutBarSide === "left" || ConnectedModeState.popoutBarSide === "right";
        const radius = win._effectivePopoutCcr;
        return isVert ? (spacing + radius) : radius;
    }

    function _popoutConnectorHeight(spacing) {
        const isVert = ConnectedModeState.popoutBarSide === "left" || ConnectedModeState.popoutBarSide === "right";
        const radius = win._effectivePopoutCcr;
        return isVert ? radius : (spacing + radius);
    }

    function _popoutConnectorX(baseX, bodyWidth, placement, spacing) {
        const popoutSide = ConnectedModeState.popoutBarSide;
        const isVert = popoutSide === "left" || popoutSide === "right";
        const seamX = !isVert ? (placement === "left" ? baseX : baseX + bodyWidth) : (popoutSide === "left" ? baseX : baseX + bodyWidth);
        const w = _popoutConnectorWidth(spacing);
        if (!isVert)
            return placement === "left" ? seamX - w : seamX;
        return popoutSide === "left" ? seamX : seamX - w;
    }

    function _popoutConnectorY(baseY, bodyHeight, placement, spacing) {
        const popoutSide = ConnectedModeState.popoutBarSide;
        const seamY = popoutSide === "top" ? baseY : popoutSide === "bottom" ? baseY + bodyHeight : (placement === "left" ? baseY : baseY + bodyHeight);
        const h = _popoutConnectorHeight(spacing);
        if (popoutSide === "top")
            return seamY;
        if (popoutSide === "bottom")
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
        visible: win._frameActive && !win._connectedActive
        cutoutTopInset: win.cutoutTopInset
        cutoutBottomInset: win.cutoutBottomInset
        cutoutLeftInset: win.cutoutLeftInset
        cutoutRightInset: win.cutoutRightInset
        cutoutRadius: win.cutoutRadius
    }

    // ─── Connected chrome fills ───────────────────────────────────────────────

    Item {
        id: _connectedSurfaceLayer
        anchors.fill: parent
        visible: win._connectedActive
        opacity: win._surfaceOpacity
        // Skip FBO when disabled, or when neither elevation nor alpha blend is active
        layer.enabled: !win._disableLayer && (Theme.elevationEnabled || win._surfaceOpacity < 1)
        layer.smooth: false

        layer.effect: MultiEffect {
            readonly property var level: Theme.elevationLevel2
            readonly property real _shadowBlur: Theme.elevationEnabled ? (level && level.blurPx !== undefined ? level.blurPx : 0) : 0
            readonly property real _shadowSpread: Theme.elevationEnabled ? (level && level.spreadPx !== undefined ? level.spreadPx : 0) : 0

            autoPaddingEnabled: true
            blurEnabled: false
            maskEnabled: false

            shadowEnabled: !win._disableLayer && Theme.elevationEnabled
            shadowBlur: Math.max(0, Math.min(1, _shadowBlur / Math.max(1, Theme.elevationBlurMax)))
            shadowScale: 1 + (2 * _shadowSpread) / Math.max(1, Math.min(_connectedSurfaceLayer.width, _connectedSurfaceLayer.height))
            shadowHorizontalOffset: Theme.elevationOffsetXFor(level, Theme.elevationLightDirection, 4)
            shadowVerticalOffset: Theme.elevationOffsetYFor(level, Theme.elevationLightDirection, 4)
            shadowColor: Theme.elevationShadowColor(level)
            shadowOpacity: 1
        }

        FrameBorder {
            anchors.fill: parent
            borderColor: win._opaqueSurfaceColor
            cutoutTopInset: win.cutoutTopInset
            cutoutBottomInset: win.cutoutBottomInset
            cutoutLeftInset: win.cutoutLeftInset
            cutoutRightInset: win.cutoutRightInset
            cutoutRadius: win.cutoutRadius
        }

        Item {
            id: _connectedChrome
            anchors.fill: parent
            visible: true

            Item {
                id: _popoutChrome
                visible: ConnectedModeState.popoutVisible && ConnectedModeState.popoutScreen === win._screenName
                x: win._popoutChromeX()
                y: win._popoutChromeY()
                width: win._popoutChromeWidth()
                height: win._popoutChromeHeight()

                Item {
                    id: _popoutClip
                    readonly property bool _barHoriz: ConnectedModeState.popoutBarSide === "top" || ConnectedModeState.popoutBarSide === "bottom"
                    // Expand clip by ccr on bar axis to include arc columns
                    x: win._popoutClipX() - (_barHoriz ? win._effectivePopoutCcr : 0)
                    y: win._popoutClipY() - (_barHoriz ? 0 : win._effectivePopoutCcr)
                    width: win._popoutClipWidth() + (_barHoriz ? win._effectivePopoutCcr * 2 : 0)
                    height: win._popoutClipHeight() + (_barHoriz ? 0 : win._effectivePopoutCcr * 2)
                    clip: true

                    ConnectedShape {
                        id: _popoutShape
                        visible: _popoutBodyBlurAnchor._active && _popoutBodyBlurAnchor.width > 0 && _popoutBodyBlurAnchor.height > 0
                        barSide: ConnectedModeState.popoutBarSide
                        bodyWidth: win._popoutClipWidth()
                        bodyHeight: win._popoutClipHeight()
                        connectorRadius: win._effectivePopoutCcr
                        surfaceRadius: win._surfaceRadius
                        fillColor: win._opaqueSurfaceColor
                        x: 0
                        y: 0
                    }
                }
            }

            Item {
                id: _dockChrome
                visible: _dockBodyBlurAnchor._active
                x: win._dockChromeX()
                y: win._dockChromeY()
                width: win._dockChromeWidth()
                height: win._dockChromeHeight()

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

        Item {
            id: _notifChrome
            visible: _notifBodyBlurAnchor._active

            readonly property string _notifSide: win._notifState.barSide
            readonly property bool _isHoriz: _notifSide === "top" || _notifSide === "bottom"
            readonly property real _notifCcr: win._effectiveNotifCcr
            readonly property real _sideUnderlap: _isHoriz ? 0 : win._seamOverlap
            readonly property real _bodyW: Theme.snap(_notifBodyBlurAnchor.width + _sideUnderlap, win._dpr)
            readonly property real _bodyH: Theme.snap(_notifBodyBlurAnchor.height, win._dpr)

            z: _isHoriz ? 0 : -1
            x: Theme.snap(_notifBodyBlurAnchor.x - (_isHoriz ? _notifCcr : (_notifSide === "left" ? _sideUnderlap : 0)), win._dpr)
            y: Theme.snap(_notifBodyBlurAnchor.y - (_isHoriz ? 0 : _notifCcr), win._dpr)
            width: _isHoriz ? Theme.snap(_bodyW + _notifCcr * 2, win._dpr) : _bodyW
            height: Theme.snap(_bodyH + (_isHoriz ? 0 : _notifCcr * 2), win._dpr)

            ConnectedShape {
                visible: _notifBodyBlurAnchor._active && _notifBodyBlurAnchor.width > 0 && _notifBodyBlurAnchor.height > 0
                barSide: _notifChrome._notifSide
                bodyWidth: _notifChrome._bodyW
                bodyHeight: _notifChrome._bodyH
                connectorRadius: _notifChrome._notifCcr
                surfaceRadius: win._surfaceRadius
                fillColor: win._opaqueSurfaceColor
                x: 0
                y: 0
            }
        }
    }
}
