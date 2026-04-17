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
    readonly property var _modalState: ConnectedModeState.modalStates[win._screenName] || ConnectedModeState.emptyModalState

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
    readonly property real _effectivePopoutFarCcr: {
        const isHoriz = ConnectedModeState.popoutBarSide === "top" || ConnectedModeState.popoutBarSide === "bottom";
        const crossSize = isHoriz ? _popoutBodyBlurAnchor.width : _popoutBodyBlurAnchor.height;
        return Math.max(0, Math.min(win._ccr, win._surfaceRadius, crossSize / 2));
    }
    readonly property real _effectivePopoutStartCcr: ConnectedModeState.popoutOmitStartConnector ? 0 : win._effectivePopoutCcr
    readonly property real _effectivePopoutEndCcr: ConnectedModeState.popoutOmitEndConnector ? 0 : win._effectivePopoutCcr
    readonly property real _effectivePopoutFarStartCcr: ConnectedModeState.popoutOmitStartConnector ? win._effectivePopoutFarCcr : 0
    readonly property real _effectivePopoutFarEndCcr: ConnectedModeState.popoutOmitEndConnector ? win._effectivePopoutFarCcr : 0
    readonly property real _effectivePopoutMaxCcr: Math.max(win._effectivePopoutStartCcr, win._effectivePopoutEndCcr)
    readonly property real _effectivePopoutFarExtent: Math.max(win._effectivePopoutFarStartCcr, win._effectivePopoutFarEndCcr)
    readonly property real _effectiveNotifCcr: {
        const isHoriz = win._notifState.barSide === "top" || win._notifState.barSide === "bottom";
        const crossSize = isHoriz ? _notifBodyBlurAnchor.width : _notifBodyBlurAnchor.height;
        const extent = isHoriz ? _notifBodyBlurAnchor.height : _notifBodyBlurAnchor.width;
        return Theme.snap(Math.max(0, Math.min(win._ccr, win._surfaceRadius, extent, crossSize / 2)), win._dpr);
    }
    readonly property real _effectiveNotifFarCcr: {
        const isHoriz = win._notifState.barSide === "top" || win._notifState.barSide === "bottom";
        const crossSize = isHoriz ? _notifBodySceneBlurAnchor.width : _notifBodySceneBlurAnchor.height;
        return Theme.snap(Math.max(0, Math.min(win._ccr, win._surfaceRadius, crossSize / 2)), win._dpr);
    }
    readonly property real _effectiveNotifStartCcr: win._notifState.omitStartConnector ? 0 : win._effectiveNotifCcr
    readonly property real _effectiveNotifEndCcr: win._notifState.omitEndConnector ? 0 : win._effectiveNotifCcr
    readonly property real _effectiveNotifFarStartCcr: win._notifState.omitStartConnector ? win._effectiveNotifFarCcr : 0
    readonly property real _effectiveNotifFarEndCcr: win._notifState.omitEndConnector ? win._effectiveNotifFarCcr : 0
    readonly property real _effectiveNotifMaxCcr: Math.max(win._effectiveNotifStartCcr, win._effectiveNotifEndCcr)
    readonly property real _effectiveNotifFarExtent: Math.max(win._effectiveNotifFarStartCcr, win._effectiveNotifFarEndCcr)
    readonly property real _effectiveModalCcr: {
        const isHoriz = win._modalState.barSide === "top" || win._modalState.barSide === "bottom";
        const crossSize = isHoriz ? _modalBodyBlurAnchor.width : _modalBodyBlurAnchor.height;
        const extent = isHoriz ? _modalBodyBlurAnchor.height : _modalBodyBlurAnchor.width;
        return Theme.snap(Math.max(0, Math.min(win._ccr, win._surfaceRadius, extent, crossSize / 2)), win._dpr);
    }
    readonly property real _effectiveModalFarCcr: {
        const isHoriz = win._modalState.barSide === "top" || win._modalState.barSide === "bottom";
        const crossSize = isHoriz ? _modalBodyBlurAnchor.width : _modalBodyBlurAnchor.height;
        return Theme.snap(Math.max(0, Math.min(win._ccr, win._surfaceRadius, crossSize / 2)), win._dpr);
    }
    readonly property real _effectiveModalStartCcr: win._modalState.omitStartConnector ? 0 : win._effectiveModalCcr
    readonly property real _effectiveModalEndCcr: win._modalState.omitEndConnector ? 0 : win._effectiveModalCcr
    readonly property real _effectiveModalFarStartCcr: win._modalState.omitStartConnector ? win._effectiveModalFarCcr : 0
    readonly property real _effectiveModalFarEndCcr: win._modalState.omitEndConnector ? win._effectiveModalFarCcr : 0
    readonly property real _effectiveModalFarExtent: Math.max(win._effectiveModalFarStartCcr, win._effectiveModalFarEndCcr)
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
        id: _popoutLeftConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._popoutConnectorRadius("left")
        readonly property bool _active: _popoutBodyBlurAnchor._active && _radius > 0
        readonly property real _w: win._popoutConnectorWidth(0, "left")
        readonly property real _h: win._popoutConnectorHeight(0, "left")

        x: _active ? Theme.snap(win._popoutConnectorX(_popoutBodyBlurAnchor.x, _popoutBodyBlurAnchor.width, "left", 0), win._dpr) : 0
        y: _active ? Theme.snap(win._popoutConnectorY(_popoutBodyBlurAnchor.y, _popoutBodyBlurAnchor.height, "left", 0), win._dpr) : 0
        width: _active ? _w : 0
        height: _active ? _h : 0
    }

    Item {
        id: _popoutRightConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._popoutConnectorRadius("right")
        readonly property bool _active: _popoutBodyBlurAnchor._active && _radius > 0
        readonly property real _w: win._popoutConnectorWidth(0, "right")
        readonly property real _h: win._popoutConnectorHeight(0, "right")

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
        readonly property real _radius: win._popoutConnectorRadius("left")

        x: _active ? win._connectorCutoutX(_popoutLeftConnectorBlurAnchor.x, _popoutLeftConnectorBlurAnchor.width, _arcCorner, _radius) : 0
        y: _active ? win._connectorCutoutY(_popoutLeftConnectorBlurAnchor.y, _popoutLeftConnectorBlurAnchor.height, _arcCorner, _radius) : 0
        width: _active ? _radius * 2 : 0
        height: _active ? _radius * 2 : 0
    }

    Item {
        id: _popoutRightConnectorCutout
        opacity: 0

        readonly property bool _active: _popoutRightConnectorBlurAnchor.width > 0 && _popoutRightConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: win._connectorArcCorner(ConnectedModeState.popoutBarSide, "right")
        readonly property real _radius: win._popoutConnectorRadius("right")

        x: _active ? win._connectorCutoutX(_popoutRightConnectorBlurAnchor.x, _popoutRightConnectorBlurAnchor.width, _arcCorner, _radius) : 0
        y: _active ? win._connectorCutoutY(_popoutRightConnectorBlurAnchor.y, _popoutRightConnectorBlurAnchor.height, _arcCorner, _radius) : 0
        width: _active ? _radius * 2 : 0
        height: _active ? _radius * 2 : 0
    }

    Item {
        id: _popoutFarStartConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._effectivePopoutFarStartCcr
        readonly property bool _active: _popoutBodyBlurAnchor._active && _radius > 0

        x: _active ? Theme.snap(win._farConnectorX(_popoutBodyBlurAnchor.x, _popoutBodyBlurAnchor.y, _popoutBodyBlurAnchor.width, _popoutBodyBlurAnchor.height, ConnectedModeState.popoutBarSide, "left", _radius), win._dpr) : 0
        y: _active ? Theme.snap(win._farConnectorY(_popoutBodyBlurAnchor.x, _popoutBodyBlurAnchor.y, _popoutBodyBlurAnchor.width, _popoutBodyBlurAnchor.height, ConnectedModeState.popoutBarSide, "left", _radius), win._dpr) : 0
        width: _active ? _radius : 0
        height: _active ? _radius : 0
    }

    Item {
        id: _popoutFarStartBodyBlurCap
        opacity: 0

        readonly property real _radius: win._effectivePopoutFarStartCcr
        readonly property bool _active: _popoutBodyBlurAnchor._active && _radius > 0

        x: _active ? Theme.snap(win._farBodyCapX(_popoutBodyBlurAnchor.x, _popoutBodyBlurAnchor.width, ConnectedModeState.popoutBarSide, "left", _radius), win._dpr) : 0
        y: _active ? Theme.snap(win._farBodyCapY(_popoutBodyBlurAnchor.y, _popoutBodyBlurAnchor.height, ConnectedModeState.popoutBarSide, "left", _radius), win._dpr) : 0
        width: _active ? _radius : 0
        height: _active ? _radius : 0
    }

    Item {
        id: _popoutFarEndBodyBlurCap
        opacity: 0

        readonly property real _radius: win._effectivePopoutFarEndCcr
        readonly property bool _active: _popoutBodyBlurAnchor._active && _radius > 0

        x: _active ? Theme.snap(win._farBodyCapX(_popoutBodyBlurAnchor.x, _popoutBodyBlurAnchor.width, ConnectedModeState.popoutBarSide, "right", _radius), win._dpr) : 0
        y: _active ? Theme.snap(win._farBodyCapY(_popoutBodyBlurAnchor.y, _popoutBodyBlurAnchor.height, ConnectedModeState.popoutBarSide, "right", _radius), win._dpr) : 0
        width: _active ? _radius : 0
        height: _active ? _radius : 0
    }

    Item {
        id: _popoutFarEndConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._effectivePopoutFarEndCcr
        readonly property bool _active: _popoutBodyBlurAnchor._active && _radius > 0

        x: _active ? Theme.snap(win._farConnectorX(_popoutBodyBlurAnchor.x, _popoutBodyBlurAnchor.y, _popoutBodyBlurAnchor.width, _popoutBodyBlurAnchor.height, ConnectedModeState.popoutBarSide, "right", _radius), win._dpr) : 0
        y: _active ? Theme.snap(win._farConnectorY(_popoutBodyBlurAnchor.x, _popoutBodyBlurAnchor.y, _popoutBodyBlurAnchor.width, _popoutBodyBlurAnchor.height, ConnectedModeState.popoutBarSide, "right", _radius), win._dpr) : 0
        width: _active ? _radius : 0
        height: _active ? _radius : 0
    }

    Item {
        id: _popoutFarStartConnectorCutout
        opacity: 0

        readonly property bool _active: _popoutFarStartConnectorBlurAnchor.width > 0 && _popoutFarStartConnectorBlurAnchor.height > 0
        readonly property string _barSide: win._farConnectorBarSide(ConnectedModeState.popoutBarSide, "left")
        readonly property string _placement: win._farConnectorPlacement(ConnectedModeState.popoutBarSide, "left")
        readonly property string _arcCorner: win._connectorArcCorner(_barSide, _placement)
        readonly property real _radius: win._effectivePopoutFarStartCcr

        x: _active ? win._connectorCutoutX(_popoutFarStartConnectorBlurAnchor.x, _popoutFarStartConnectorBlurAnchor.width, _arcCorner, _radius) : 0
        y: _active ? win._connectorCutoutY(_popoutFarStartConnectorBlurAnchor.y, _popoutFarStartConnectorBlurAnchor.height, _arcCorner, _radius) : 0
        width: _active ? _radius * 2 : 0
        height: _active ? _radius * 2 : 0
    }

    Item {
        id: _popoutFarEndConnectorCutout
        opacity: 0

        readonly property bool _active: _popoutFarEndConnectorBlurAnchor.width > 0 && _popoutFarEndConnectorBlurAnchor.height > 0
        readonly property string _barSide: win._farConnectorBarSide(ConnectedModeState.popoutBarSide, "right")
        readonly property string _placement: win._farConnectorPlacement(ConnectedModeState.popoutBarSide, "right")
        readonly property string _arcCorner: win._connectorArcCorner(_barSide, _placement)
        readonly property real _radius: win._effectivePopoutFarEndCcr

        x: _active ? win._connectorCutoutX(_popoutFarEndConnectorBlurAnchor.x, _popoutFarEndConnectorBlurAnchor.width, _arcCorner, _radius) : 0
        y: _active ? win._connectorCutoutY(_popoutFarEndConnectorBlurAnchor.y, _popoutFarEndConnectorBlurAnchor.height, _arcCorner, _radius) : 0
        width: _active ? _radius * 2 : 0
        height: _active ? _radius * 2 : 0
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
        id: _modalBodyBlurAnchor
        visible: false

        readonly property bool _active: win._frameActive && win._modalState.visible && win._modalState.bodyW > 0 && win._modalState.bodyH > 0

        // Clamp animX/Y so the blur body shrinks toward the bar edge (same as _popoutBodyBlurAnchor).
        readonly property real _dyClamp: (win._modalState.barSide === "top" || win._modalState.barSide === "bottom") ? Math.max(-win._modalState.bodyH, Math.min(win._modalState.animY, win._modalState.bodyH)) : 0
        readonly property real _dxClamp: (win._modalState.barSide === "left" || win._modalState.barSide === "right") ? Math.max(-win._modalState.bodyW, Math.min(win._modalState.animX, win._modalState.bodyW)) : 0

        x: _active ? Theme.snap(win._modalState.bodyX + (win._modalState.barSide === "right" ? _dxClamp : 0), win._dpr) : 0
        y: _active ? Theme.snap(win._modalState.bodyY + (win._modalState.barSide === "bottom" ? _dyClamp : 0), win._dpr) : 0
        width: _active ? Theme.snap(Math.max(0, win._modalState.bodyW - Math.abs(_dxClamp)), win._dpr) : 0
        height: _active ? Theme.snap(Math.max(0, win._modalState.bodyH - Math.abs(_dyClamp)), win._dpr) : 0
    }

    Item {
        id: _modalBodyBlurCap
        opacity: 0

        readonly property string _side: win._modalState.barSide
        readonly property real _capThickness: win._modalBlurCapThickness()
        readonly property bool _active: _modalBodyBlurAnchor._active && _capThickness > 0 && _modalBodyBlurAnchor.width > 0 && _modalBodyBlurAnchor.height > 0
        readonly property real _capWidth: (_side === "left" || _side === "right") ? Math.min(_capThickness, _modalBodyBlurAnchor.width) : _modalBodyBlurAnchor.width
        readonly property real _capHeight: (_side === "top" || _side === "bottom") ? Math.min(_capThickness, _modalBodyBlurAnchor.height) : _modalBodyBlurAnchor.height

        x: !_active ? 0 : (_side === "right" ? _modalBodyBlurAnchor.x + _modalBodyBlurAnchor.width - _capWidth : _modalBodyBlurAnchor.x)
        y: !_active ? 0 : (_side === "bottom" ? _modalBodyBlurAnchor.y + _modalBodyBlurAnchor.height - _capHeight : _modalBodyBlurAnchor.y)
        width: _active ? _capWidth : 0
        height: _active ? _capHeight : 0
    }

    Item {
        id: _modalLeftConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._modalConnectorRadius("left")
        readonly property bool _active: _modalBodyBlurAnchor._active && _radius > 0
        readonly property real _w: win._modalConnectorWidth(0, "left")
        readonly property real _h: win._modalConnectorHeight(0, "left")

        x: _active ? Theme.snap(win._modalConnectorX(_modalBodyBlurAnchor.x, _modalBodyBlurAnchor.width, "left", 0), win._dpr) : 0
        y: _active ? Theme.snap(win._modalConnectorY(_modalBodyBlurAnchor.y, _modalBodyBlurAnchor.height, "left", 0), win._dpr) : 0
        width: _active ? _w : 0
        height: _active ? _h : 0
    }

    Item {
        id: _modalRightConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._modalConnectorRadius("right")
        readonly property bool _active: _modalBodyBlurAnchor._active && _radius > 0
        readonly property real _w: win._modalConnectorWidth(0, "right")
        readonly property real _h: win._modalConnectorHeight(0, "right")

        x: _active ? Theme.snap(win._modalConnectorX(_modalBodyBlurAnchor.x, _modalBodyBlurAnchor.width, "right", 0), win._dpr) : 0
        y: _active ? Theme.snap(win._modalConnectorY(_modalBodyBlurAnchor.y, _modalBodyBlurAnchor.height, "right", 0), win._dpr) : 0
        width: _active ? _w : 0
        height: _active ? _h : 0
    }

    Item {
        id: _modalLeftConnectorCutout
        opacity: 0

        readonly property bool _active: _modalLeftConnectorBlurAnchor.width > 0 && _modalLeftConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: win._connectorArcCorner(win._modalState.barSide, "left")
        readonly property real _radius: win._modalConnectorRadius("left")

        x: _active ? win._connectorCutoutX(_modalLeftConnectorBlurAnchor.x, _modalLeftConnectorBlurAnchor.width, _arcCorner, _radius) : 0
        y: _active ? win._connectorCutoutY(_modalLeftConnectorBlurAnchor.y, _modalLeftConnectorBlurAnchor.height, _arcCorner, _radius) : 0
        width: _active ? _radius * 2 : 0
        height: _active ? _radius * 2 : 0
    }

    Item {
        id: _modalRightConnectorCutout
        opacity: 0

        readonly property bool _active: _modalRightConnectorBlurAnchor.width > 0 && _modalRightConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: win._connectorArcCorner(win._modalState.barSide, "right")
        readonly property real _radius: win._modalConnectorRadius("right")

        x: _active ? win._connectorCutoutX(_modalRightConnectorBlurAnchor.x, _modalRightConnectorBlurAnchor.width, _arcCorner, _radius) : 0
        y: _active ? win._connectorCutoutY(_modalRightConnectorBlurAnchor.y, _modalRightConnectorBlurAnchor.height, _arcCorner, _radius) : 0
        width: _active ? _radius * 2 : 0
        height: _active ? _radius * 2 : 0
    }

    Item {
        id: _modalFarStartConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._effectiveModalFarStartCcr
        readonly property bool _active: _modalBodyBlurAnchor._active && _radius > 0

        x: _active ? Theme.snap(win._farConnectorX(_modalBodyBlurAnchor.x, _modalBodyBlurAnchor.y, _modalBodyBlurAnchor.width, _modalBodyBlurAnchor.height, win._modalState.barSide, "left", _radius), win._dpr) : 0
        y: _active ? Theme.snap(win._farConnectorY(_modalBodyBlurAnchor.x, _modalBodyBlurAnchor.y, _modalBodyBlurAnchor.width, _modalBodyBlurAnchor.height, win._modalState.barSide, "left", _radius), win._dpr) : 0
        width: _active ? _radius : 0
        height: _active ? _radius : 0
    }

    Item {
        id: _modalFarStartBodyBlurCap
        opacity: 0

        readonly property real _radius: win._effectiveModalFarStartCcr
        readonly property bool _active: _modalBodyBlurAnchor._active && _radius > 0

        x: _active ? Theme.snap(win._farBodyCapX(_modalBodyBlurAnchor.x, _modalBodyBlurAnchor.width, win._modalState.barSide, "left", _radius), win._dpr) : 0
        y: _active ? Theme.snap(win._farBodyCapY(_modalBodyBlurAnchor.y, _modalBodyBlurAnchor.height, win._modalState.barSide, "left", _radius), win._dpr) : 0
        width: _active ? _radius : 0
        height: _active ? _radius : 0
    }

    Item {
        id: _modalFarEndBodyBlurCap
        opacity: 0

        readonly property real _radius: win._effectiveModalFarEndCcr
        readonly property bool _active: _modalBodyBlurAnchor._active && _radius > 0

        x: _active ? Theme.snap(win._farBodyCapX(_modalBodyBlurAnchor.x, _modalBodyBlurAnchor.width, win._modalState.barSide, "right", _radius), win._dpr) : 0
        y: _active ? Theme.snap(win._farBodyCapY(_modalBodyBlurAnchor.y, _modalBodyBlurAnchor.height, win._modalState.barSide, "right", _radius), win._dpr) : 0
        width: _active ? _radius : 0
        height: _active ? _radius : 0
    }

    Item {
        id: _modalFarEndConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._effectiveModalFarEndCcr
        readonly property bool _active: _modalBodyBlurAnchor._active && _radius > 0

        x: _active ? Theme.snap(win._farConnectorX(_modalBodyBlurAnchor.x, _modalBodyBlurAnchor.y, _modalBodyBlurAnchor.width, _modalBodyBlurAnchor.height, win._modalState.barSide, "right", _radius), win._dpr) : 0
        y: _active ? Theme.snap(win._farConnectorY(_modalBodyBlurAnchor.x, _modalBodyBlurAnchor.y, _modalBodyBlurAnchor.width, _modalBodyBlurAnchor.height, win._modalState.barSide, "right", _radius), win._dpr) : 0
        width: _active ? _radius : 0
        height: _active ? _radius : 0
    }

    Item {
        id: _modalFarStartConnectorCutout
        opacity: 0

        readonly property bool _active: _modalFarStartConnectorBlurAnchor.width > 0 && _modalFarStartConnectorBlurAnchor.height > 0
        readonly property string _barSide: win._farConnectorBarSide(win._modalState.barSide, "left")
        readonly property string _placement: win._farConnectorPlacement(win._modalState.barSide, "left")
        readonly property string _arcCorner: win._connectorArcCorner(_barSide, _placement)
        readonly property real _radius: win._effectiveModalFarStartCcr

        x: _active ? win._connectorCutoutX(_modalFarStartConnectorBlurAnchor.x, _modalFarStartConnectorBlurAnchor.width, _arcCorner, _radius) : 0
        y: _active ? win._connectorCutoutY(_modalFarStartConnectorBlurAnchor.y, _modalFarStartConnectorBlurAnchor.height, _arcCorner, _radius) : 0
        width: _active ? _radius * 2 : 0
        height: _active ? _radius * 2 : 0
    }

    Item {
        id: _modalFarEndConnectorCutout
        opacity: 0

        readonly property bool _active: _modalFarEndConnectorBlurAnchor.width > 0 && _modalFarEndConnectorBlurAnchor.height > 0
        readonly property string _barSide: win._farConnectorBarSide(win._modalState.barSide, "right")
        readonly property string _placement: win._farConnectorPlacement(win._modalState.barSide, "right")
        readonly property string _arcCorner: win._connectorArcCorner(_barSide, _placement)
        readonly property real _radius: win._effectiveModalFarEndCcr

        x: _active ? win._connectorCutoutX(_modalFarEndConnectorBlurAnchor.x, _modalFarEndConnectorBlurAnchor.width, _arcCorner, _radius) : 0
        y: _active ? win._connectorCutoutY(_modalFarEndConnectorBlurAnchor.y, _modalFarEndConnectorBlurAnchor.height, _arcCorner, _radius) : 0
        width: _active ? _radius * 2 : 0
        height: _active ? _radius * 2 : 0
    }

    Item {
        id: _notifBodySceneBlurAnchor
        visible: false

        readonly property bool _active: _notifBodyBlurAnchor._active

        x: _active ? Theme.snap(win._notifBodySceneX(), win._dpr) : 0
        y: _active ? Theme.snap(win._notifBodySceneY(), win._dpr) : 0
        width: _active ? Theme.snap(win._notifBodySceneWidth(), win._dpr) : 0
        height: _active ? Theme.snap(win._notifBodySceneHeight(), win._dpr) : 0
    }

    Item {
        id: _notifBodyBlurCap
        opacity: 0

        readonly property string _side: win._notifState.barSide
        readonly property real _capRadius: win._notifMaxConnectorRadius()
        readonly property bool _active: _notifBodySceneBlurAnchor._active && _notifBodySceneBlurAnchor.width > 0 && _notifBodySceneBlurAnchor.height > 0 && _capRadius > 0
        readonly property real _capWidth: (_side === "left" || _side === "right") ? Math.min(_capRadius, _notifBodySceneBlurAnchor.width) : _notifBodySceneBlurAnchor.width
        readonly property real _capHeight: (_side === "top" || _side === "bottom") ? Math.min(_capRadius, _notifBodySceneBlurAnchor.height) : _notifBodySceneBlurAnchor.height

        x: !_active ? 0 : (_side === "right" ? _notifBodySceneBlurAnchor.x + _notifBodySceneBlurAnchor.width - _capWidth : _notifBodySceneBlurAnchor.x)
        y: !_active ? 0 : (_side === "bottom" ? _notifBodySceneBlurAnchor.y + _notifBodySceneBlurAnchor.height - _capHeight : _notifBodySceneBlurAnchor.y)
        width: _active ? _capWidth : 0
        height: _active ? _capHeight : 0
    }

    Item {
        id: _notifLeftConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._notifConnectorRadius("left")
        readonly property bool _active: _notifBodySceneBlurAnchor._active && _radius > 0
        readonly property real _w: win._notifConnectorWidth(0, "left")
        readonly property real _h: win._notifConnectorHeight(0, "left")

        x: _active ? Theme.snap(win._notifConnectorX(_notifBodySceneBlurAnchor.x, _notifBodySceneBlurAnchor.width, "left", 0), win._dpr) : 0
        y: _active ? Theme.snap(win._notifConnectorY(_notifBodySceneBlurAnchor.y, _notifBodySceneBlurAnchor.height, "left", 0), win._dpr) : 0
        width: _active ? _w : 0
        height: _active ? _h : 0
    }

    Item {
        id: _notifRightConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._notifConnectorRadius("right")
        readonly property bool _active: _notifBodySceneBlurAnchor._active && _radius > 0
        readonly property real _w: win._notifConnectorWidth(0, "right")
        readonly property real _h: win._notifConnectorHeight(0, "right")

        x: _active ? Theme.snap(win._notifConnectorX(_notifBodySceneBlurAnchor.x, _notifBodySceneBlurAnchor.width, "right", 0), win._dpr) : 0
        y: _active ? Theme.snap(win._notifConnectorY(_notifBodySceneBlurAnchor.y, _notifBodySceneBlurAnchor.height, "right", 0), win._dpr) : 0
        width: _active ? _w : 0
        height: _active ? _h : 0
    }

    Item {
        id: _notifLeftConnectorCutout
        opacity: 0

        readonly property bool _active: _notifLeftConnectorBlurAnchor.width > 0 && _notifLeftConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: win._connectorArcCorner(win._notifState.barSide, "left")
        readonly property real _radius: win._notifConnectorRadius("left")

        x: _active ? win._connectorCutoutX(_notifLeftConnectorBlurAnchor.x, _notifLeftConnectorBlurAnchor.width, _arcCorner, _radius) : 0
        y: _active ? win._connectorCutoutY(_notifLeftConnectorBlurAnchor.y, _notifLeftConnectorBlurAnchor.height, _arcCorner, _radius) : 0
        width: _active ? _radius * 2 : 0
        height: _active ? _radius * 2 : 0
    }

    Item {
        id: _notifRightConnectorCutout
        opacity: 0

        readonly property bool _active: _notifRightConnectorBlurAnchor.width > 0 && _notifRightConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: win._connectorArcCorner(win._notifState.barSide, "right")
        readonly property real _radius: win._notifConnectorRadius("right")

        x: _active ? win._connectorCutoutX(_notifRightConnectorBlurAnchor.x, _notifRightConnectorBlurAnchor.width, _arcCorner, _radius) : 0
        y: _active ? win._connectorCutoutY(_notifRightConnectorBlurAnchor.y, _notifRightConnectorBlurAnchor.height, _arcCorner, _radius) : 0
        width: _active ? _radius * 2 : 0
        height: _active ? _radius * 2 : 0
    }

    Item {
        id: _notifFarStartConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._effectiveNotifFarStartCcr
        readonly property bool _active: _notifBodySceneBlurAnchor._active && _radius > 0

        x: _active ? Theme.snap(win._farConnectorX(_notifBodySceneBlurAnchor.x, _notifBodySceneBlurAnchor.y, _notifBodySceneBlurAnchor.width, _notifBodySceneBlurAnchor.height, win._notifState.barSide, "left", _radius), win._dpr) : 0
        y: _active ? Theme.snap(win._farConnectorY(_notifBodySceneBlurAnchor.x, _notifBodySceneBlurAnchor.y, _notifBodySceneBlurAnchor.width, _notifBodySceneBlurAnchor.height, win._notifState.barSide, "left", _radius), win._dpr) : 0
        width: _active ? _radius : 0
        height: _active ? _radius : 0
    }

    Item {
        id: _notifFarStartBodyBlurCap
        opacity: 0

        readonly property real _radius: win._effectiveNotifFarStartCcr
        readonly property bool _active: _notifBodySceneBlurAnchor._active && _radius > 0

        x: _active ? Theme.snap(win._farBodyCapX(_notifBodySceneBlurAnchor.x, _notifBodySceneBlurAnchor.width, win._notifState.barSide, "left", _radius), win._dpr) : 0
        y: _active ? Theme.snap(win._farBodyCapY(_notifBodySceneBlurAnchor.y, _notifBodySceneBlurAnchor.height, win._notifState.barSide, "left", _radius), win._dpr) : 0
        width: _active ? _radius : 0
        height: _active ? _radius : 0
    }

    Item {
        id: _notifFarEndBodyBlurCap
        opacity: 0

        readonly property real _radius: win._effectiveNotifFarEndCcr
        readonly property bool _active: _notifBodySceneBlurAnchor._active && _radius > 0

        x: _active ? Theme.snap(win._farBodyCapX(_notifBodySceneBlurAnchor.x, _notifBodySceneBlurAnchor.width, win._notifState.barSide, "right", _radius), win._dpr) : 0
        y: _active ? Theme.snap(win._farBodyCapY(_notifBodySceneBlurAnchor.y, _notifBodySceneBlurAnchor.height, win._notifState.barSide, "right", _radius), win._dpr) : 0
        width: _active ? _radius : 0
        height: _active ? _radius : 0
    }

    Item {
        id: _notifFarEndConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._effectiveNotifFarEndCcr
        readonly property bool _active: _notifBodySceneBlurAnchor._active && _radius > 0

        x: _active ? Theme.snap(win._farConnectorX(_notifBodySceneBlurAnchor.x, _notifBodySceneBlurAnchor.y, _notifBodySceneBlurAnchor.width, _notifBodySceneBlurAnchor.height, win._notifState.barSide, "right", _radius), win._dpr) : 0
        y: _active ? Theme.snap(win._farConnectorY(_notifBodySceneBlurAnchor.x, _notifBodySceneBlurAnchor.y, _notifBodySceneBlurAnchor.width, _notifBodySceneBlurAnchor.height, win._notifState.barSide, "right", _radius), win._dpr) : 0
        width: _active ? _radius : 0
        height: _active ? _radius : 0
    }

    Item {
        id: _notifFarStartConnectorCutout
        opacity: 0

        readonly property bool _active: _notifFarStartConnectorBlurAnchor.width > 0 && _notifFarStartConnectorBlurAnchor.height > 0
        readonly property string _barSide: win._farConnectorBarSide(win._notifState.barSide, "left")
        readonly property string _placement: win._farConnectorPlacement(win._notifState.barSide, "left")
        readonly property string _arcCorner: win._connectorArcCorner(_barSide, _placement)
        readonly property real _radius: win._effectiveNotifFarStartCcr

        x: _active ? win._connectorCutoutX(_notifFarStartConnectorBlurAnchor.x, _notifFarStartConnectorBlurAnchor.width, _arcCorner, _radius) : 0
        y: _active ? win._connectorCutoutY(_notifFarStartConnectorBlurAnchor.y, _notifFarStartConnectorBlurAnchor.height, _arcCorner, _radius) : 0
        width: _active ? _radius * 2 : 0
        height: _active ? _radius * 2 : 0
    }

    Item {
        id: _notifFarEndConnectorCutout
        opacity: 0

        readonly property bool _active: _notifFarEndConnectorBlurAnchor.width > 0 && _notifFarEndConnectorBlurAnchor.height > 0
        readonly property string _barSide: win._farConnectorBarSide(win._notifState.barSide, "right")
        readonly property string _placement: win._farConnectorPlacement(win._notifState.barSide, "right")
        readonly property string _arcCorner: win._connectorArcCorner(_barSide, _placement)
        readonly property real _radius: win._effectiveNotifFarEndCcr

        x: _active ? win._connectorCutoutX(_notifFarEndConnectorBlurAnchor.x, _notifFarEndConnectorBlurAnchor.width, _arcCorner, _radius) : 0
        y: _active ? win._connectorCutoutY(_notifFarEndConnectorBlurAnchor.y, _notifFarEndConnectorBlurAnchor.height, _arcCorner, _radius) : 0
        width: _active ? _radius * 2 : 0
        height: _active ? _radius * 2 : 0
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
                radius: win._popoutConnectorRadius("left")
            }
        }
        Region {
            item: _popoutRightConnectorBlurAnchor
            Region {
                item: _popoutRightConnectorCutout
                intersection: Intersection.Subtract
                radius: win._popoutConnectorRadius("right")
            }
        }
        Region {
            item: _popoutFarStartBodyBlurCap
        }
        Region {
            item: _popoutFarEndBodyBlurCap
        }
        Region {
            item: _popoutFarStartConnectorBlurAnchor
            Region {
                item: _popoutFarStartConnectorCutout
                intersection: Intersection.Subtract
                radius: win._effectivePopoutFarStartCcr
            }
        }
        Region {
            item: _popoutFarEndConnectorBlurAnchor
            Region {
                item: _popoutFarEndConnectorCutout
                intersection: Intersection.Subtract
                radius: win._effectivePopoutFarEndCcr
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
            item: _notifBodySceneBlurAnchor
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
                radius: win._notifConnectorRadius("left")
            }
        }
        Region {
            item: _notifRightConnectorBlurAnchor
            Region {
                item: _notifRightConnectorCutout
                intersection: Intersection.Subtract
                radius: win._notifConnectorRadius("right")
            }
        }
        Region {
            item: _notifFarStartBodyBlurCap
        }
        Region {
            item: _notifFarEndBodyBlurCap
        }
        Region {
            item: _notifFarStartConnectorBlurAnchor
            Region {
                item: _notifFarStartConnectorCutout
                intersection: Intersection.Subtract
                radius: win._effectiveNotifFarStartCcr
            }
        }
        Region {
            item: _notifFarEndConnectorBlurAnchor
            Region {
                item: _notifFarEndConnectorCutout
                intersection: Intersection.Subtract
                radius: win._effectiveNotifFarEndCcr
            }
        }

        // ── Connected modal blur regions ──
        Region {
            item: _modalBodyBlurAnchor
            radius: win._surfaceRadius
        }
        Region {
            item: _modalBodyBlurCap
        }
        Region {
            item: _modalLeftConnectorBlurAnchor
            Region {
                item: _modalLeftConnectorCutout
                intersection: Intersection.Subtract
                radius: win._modalConnectorRadius("left")
            }
        }
        Region {
            item: _modalRightConnectorBlurAnchor
            Region {
                item: _modalRightConnectorCutout
                intersection: Intersection.Subtract
                radius: win._modalConnectorRadius("right")
            }
        }
        Region {
            item: _modalFarStartBodyBlurCap
        }
        Region {
            item: _modalFarEndBodyBlurCap
        }
        Region {
            item: _modalFarStartConnectorBlurAnchor
            Region {
                item: _modalFarStartConnectorCutout
                intersection: Intersection.Subtract
                radius: win._effectiveModalFarStartCcr
            }
        }
        Region {
            item: _modalFarEndConnectorBlurAnchor
            Region {
                item: _modalFarEndConnectorCutout
                intersection: Intersection.Subtract
                radius: win._effectiveModalFarEndCcr
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

    function _notifSideUnderlap() {
        const side = win._notifState.barSide;
        return (side === "left" || side === "right") ? win._seamOverlap : 0;
    }

    function _notifStartUnderlap() {
        return win._notifState.omitStartConnector ? win._seamOverlap : 0;
    }

    function _notifEndUnderlap() {
        return win._notifState.omitEndConnector ? win._seamOverlap : 0;
    }

    function _notifBodySceneX() {
        const side = win._notifState.barSide;
        const isHoriz = side === "top" || side === "bottom";
        if (isHoriz)
            return _notifBodyBlurAnchor.x - win._notifStartUnderlap();
        return _notifBodyBlurAnchor.x - (side === "left" ? win._notifSideUnderlap() : 0);
    }

    function _notifBodySceneY() {
        const side = win._notifState.barSide;
        const isHoriz = side === "top" || side === "bottom";
        if (isHoriz)
            return _notifBodyBlurAnchor.y;
        return _notifBodyBlurAnchor.y - win._notifStartUnderlap();
    }

    function _notifBodySceneWidth() {
        const side = win._notifState.barSide;
        const isHoriz = side === "top" || side === "bottom";
        if (isHoriz)
            return _notifBodyBlurAnchor.width + win._notifStartUnderlap() + win._notifEndUnderlap();
        return _notifBodyBlurAnchor.width + win._notifSideUnderlap();
    }

    function _notifBodySceneHeight() {
        const side = win._notifState.barSide;
        const isHoriz = side === "top" || side === "bottom";
        if (isHoriz)
            return _notifBodyBlurAnchor.height;
        return _notifBodyBlurAnchor.height + win._notifStartUnderlap() + win._notifEndUnderlap();
    }

    function _notifConnectorRadius(placement) {
        return placement === "right" ? win._effectiveNotifEndCcr : win._effectiveNotifStartCcr;
    }

    function _notifMaxConnectorRadius() {
        return win._effectiveNotifMaxCcr;
    }

    function _notifConnectorWidth(spacing, placement) {
        const isVert = win._notifState.barSide === "left" || win._notifState.barSide === "right";
        const radius = win._notifConnectorRadius(placement);
        return isVert ? (spacing + radius) : radius;
    }

    function _notifConnectorHeight(spacing, placement) {
        const isVert = win._notifState.barSide === "left" || win._notifState.barSide === "right";
        const radius = win._notifConnectorRadius(placement);
        return isVert ? radius : (spacing + radius);
    }

    function _notifConnectorX(baseX, bodyWidth, placement, spacing) {
        const notifSide = win._notifState.barSide;
        const isVert = notifSide === "left" || notifSide === "right";
        const seamX = !isVert ? (placement === "left" ? baseX : baseX + bodyWidth) : (notifSide === "left" ? baseX : baseX + bodyWidth);
        const w = _notifConnectorWidth(spacing, placement);
        if (!isVert)
            return placement === "left" ? seamX - w : seamX;
        return notifSide === "left" ? seamX : seamX - w;
    }

    function _notifConnectorY(baseY, bodyHeight, placement, spacing) {
        const notifSide = win._notifState.barSide;
        const seamY = notifSide === "top" ? baseY : notifSide === "bottom" ? baseY + bodyHeight : (placement === "left" ? baseY : baseY + bodyHeight);
        const h = _notifConnectorHeight(spacing, placement);
        if (notifSide === "top")
            return seamY;
        if (notifSide === "bottom")
            return seamY - h;
        return placement === "left" ? seamY - h : seamY;
    }

    function _popoutConnectorRadius(placement) {
        return placement === "right" ? win._effectivePopoutEndCcr : win._effectivePopoutStartCcr;
    }

    function _popoutConnectorWidth(spacing, placement) {
        const isVert = ConnectedModeState.popoutBarSide === "left" || ConnectedModeState.popoutBarSide === "right";
        const radius = win._popoutConnectorRadius(placement);
        return isVert ? (spacing + radius) : radius;
    }

    function _popoutConnectorHeight(spacing, placement) {
        const isVert = ConnectedModeState.popoutBarSide === "left" || ConnectedModeState.popoutBarSide === "right";
        const radius = win._popoutConnectorRadius(placement);
        return isVert ? radius : (spacing + radius);
    }

    function _popoutConnectorX(baseX, bodyWidth, placement, spacing) {
        const popoutSide = ConnectedModeState.popoutBarSide;
        const isVert = popoutSide === "left" || popoutSide === "right";
        const seamX = !isVert ? (placement === "left" ? baseX : baseX + bodyWidth) : (popoutSide === "left" ? baseX : baseX + bodyWidth);
        const w = _popoutConnectorWidth(spacing, placement);
        if (!isVert)
            return placement === "left" ? seamX - w : seamX;
        return popoutSide === "left" ? seamX : seamX - w;
    }

    function _popoutConnectorY(baseY, bodyHeight, placement, spacing) {
        const popoutSide = ConnectedModeState.popoutBarSide;
        const seamY = popoutSide === "top" ? baseY : popoutSide === "bottom" ? baseY + bodyHeight : (placement === "left" ? baseY : baseY + bodyHeight);
        const h = _popoutConnectorHeight(spacing, placement);
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

    function _modalArcExtent() {
        return (win._modalState.barSide === "top" || win._modalState.barSide === "bottom") ? _modalBodyBlurAnchor.height : _modalBodyBlurAnchor.width;
    }

    function _modalBlurCapThickness() {
        const extent = win._modalArcExtent();
        return Math.max(0, Math.min(win._effectiveModalCcr, extent - win._surfaceRadius));
    }

    function _modalConnectorRadius(placement) {
        return placement === "right" ? win._effectiveModalEndCcr : win._effectiveModalStartCcr;
    }

    function _modalConnectorWidth(spacing, placement) {
        const isVert = win._modalState.barSide === "left" || win._modalState.barSide === "right";
        const radius = win._modalConnectorRadius(placement);
        return isVert ? (spacing + radius) : radius;
    }

    function _modalConnectorHeight(spacing, placement) {
        const isVert = win._modalState.barSide === "left" || win._modalState.barSide === "right";
        const radius = win._modalConnectorRadius(placement);
        return isVert ? radius : (spacing + radius);
    }

    function _modalConnectorX(baseX, bodyWidth, placement, spacing) {
        const barSide = win._modalState.barSide;
        const isVert = barSide === "left" || barSide === "right";
        const seamX = !isVert ? (placement === "left" ? baseX : baseX + bodyWidth) : (barSide === "left" ? baseX : baseX + bodyWidth);
        const w = _modalConnectorWidth(spacing, placement);
        if (!isVert)
            return placement === "left" ? seamX - w : seamX;
        return barSide === "left" ? seamX : seamX - w;
    }

    function _modalConnectorY(baseY, bodyHeight, placement, spacing) {
        const barSide = win._modalState.barSide;
        const seamY = barSide === "top" ? baseY : barSide === "bottom" ? baseY + bodyHeight : (placement === "left" ? baseY : baseY + bodyHeight);
        const h = _modalConnectorHeight(spacing, placement);
        if (barSide === "top")
            return seamY;
        if (barSide === "bottom")
            return seamY - h;
        return placement === "left" ? seamY - h : seamY;
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
        return Math.max(0, Math.min(win._effectivePopoutMaxCcr, extent - win._surfaceRadius));
    }

    function _popoutChromeX() {
        const barSide = ConnectedModeState.popoutBarSide;
        return ConnectedModeState.popoutBodyX - ((barSide === "top" || barSide === "bottom") ? win._effectivePopoutStartCcr : 0);
    }

    function _popoutChromeY() {
        const barSide = ConnectedModeState.popoutBarSide;
        return ConnectedModeState.popoutBodyY - ((barSide === "left" || barSide === "right") ? win._effectivePopoutStartCcr : 0);
    }

    function _popoutChromeWidth() {
        const barSide = ConnectedModeState.popoutBarSide;
        return ConnectedModeState.popoutBodyW + ((barSide === "top" || barSide === "bottom") ? win._effectivePopoutStartCcr + win._effectivePopoutEndCcr : 0);
    }

    function _popoutChromeHeight() {
        const barSide = ConnectedModeState.popoutBarSide;
        return ConnectedModeState.popoutBodyH + ((barSide === "left" || barSide === "right") ? win._effectivePopoutStartCcr + win._effectivePopoutEndCcr : 0);
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

    function _popoutShapeBodyOffsetX() {
        const side = ConnectedModeState.popoutBarSide;
        if (side === "top" || side === "bottom")
            return win._effectivePopoutStartCcr;
        return side === "right" ? win._effectivePopoutFarExtent : 0;
    }

    function _popoutShapeBodyOffsetY() {
        const side = ConnectedModeState.popoutBarSide;
        if (side === "top" || side === "bottom")
            return side === "bottom" ? win._effectivePopoutFarExtent : 0;
        return win._effectivePopoutStartCcr;
    }

    function _popoutShapeWidth() {
        const side = ConnectedModeState.popoutBarSide;
        if (side === "top" || side === "bottom")
            return win._popoutClipWidth() + win._effectivePopoutStartCcr + win._effectivePopoutEndCcr;
        return win._popoutClipWidth() + win._effectivePopoutFarExtent;
    }

    function _popoutShapeHeight() {
        const side = ConnectedModeState.popoutBarSide;
        if (side === "top" || side === "bottom")
            return win._popoutClipHeight() + win._effectivePopoutFarExtent;
        return win._popoutClipHeight() + win._effectivePopoutStartCcr + win._effectivePopoutEndCcr;
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

    function _farConnectorBarSide(sourceSide, placement) {
        if (sourceSide === "top" || sourceSide === "bottom")
            return placement === "left" ? "left" : "right";
        return placement === "left" ? "top" : "bottom";
    }

    function _farConnectorPlacement(sourceSide, placement) {
        if (sourceSide === "top")
            return "right";
        if (sourceSide === "bottom")
            return "left";
        if (sourceSide === "left")
            return "right";
        return "left";
    }

    function _farConnectorX(baseX, baseY, bodyWidth, bodyHeight, sourceSide, placement, radius) {
        if (sourceSide === "top" || sourceSide === "bottom")
            return placement === "left" ? baseX : baseX + bodyWidth - radius;
        if (sourceSide === "left")
            return baseX + bodyWidth;
        return baseX - radius;
    }

    function _farConnectorY(baseX, baseY, bodyWidth, bodyHeight, sourceSide, placement, radius) {
        if (sourceSide === "top")
            return baseY + bodyHeight;
        if (sourceSide === "bottom")
            return baseY - radius;
        return placement === "left" ? baseY : baseY + bodyHeight - radius;
    }

    function _farBodyCapX(baseX, bodyWidth, sourceSide, placement, radius) {
        if (sourceSide === "top" || sourceSide === "bottom")
            return placement === "left" ? baseX : baseX + bodyWidth - radius;
        if (sourceSide === "left")
            return baseX + bodyWidth - radius;
        return baseX;
    }

    function _farBodyCapY(baseY, bodyHeight, sourceSide, placement, radius) {
        if (sourceSide === "top")
            return baseY + bodyHeight - radius;
        if (sourceSide === "bottom")
            return baseY;
        return placement === "left" ? baseY : baseY + bodyHeight - radius;
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
        function onFrameCloseGapsChanged() {
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
                    x: win._popoutClipX() - win._popoutShapeBodyOffsetX()
                    y: win._popoutClipY() - win._popoutShapeBodyOffsetY()
                    width: win._popoutShapeWidth()
                    height: win._popoutShapeHeight()
                    clip: true

                    ConnectedShape {
                        id: _popoutShape
                        visible: _popoutBodyBlurAnchor._active && _popoutBodyBlurAnchor.width > 0 && _popoutBodyBlurAnchor.height > 0
                        barSide: ConnectedModeState.popoutBarSide
                        bodyWidth: win._popoutClipWidth()
                        bodyHeight: win._popoutClipHeight()
                        connectorRadius: win._effectivePopoutCcr
                        startConnectorRadius: win._effectivePopoutStartCcr
                        endConnectorRadius: win._effectivePopoutEndCcr
                        farStartConnectorRadius: win._effectivePopoutFarStartCcr
                        farEndConnectorRadius: win._effectivePopoutFarEndCcr
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
            visible: _notifBodySceneBlurAnchor._active

            readonly property string _notifSide: win._notifState.barSide
            readonly property bool _isHoriz: _notifSide === "top" || _notifSide === "bottom"
            readonly property real _startCcr: win._effectiveNotifStartCcr
            readonly property real _endCcr: win._effectiveNotifEndCcr
            readonly property real _farExtent: win._effectiveNotifFarExtent
            readonly property real _bodyOffsetX: _isHoriz ? _startCcr : (_notifSide === "right" ? _farExtent : 0)
            readonly property real _bodyOffsetY: _isHoriz ? (_notifSide === "bottom" ? _farExtent : 0) : _startCcr
            readonly property real _bodyW: Theme.snap(_notifBodySceneBlurAnchor.width, win._dpr)
            readonly property real _bodyH: Theme.snap(_notifBodySceneBlurAnchor.height, win._dpr)

            z: _isHoriz ? 0 : -1
            x: Theme.snap(_notifBodySceneBlurAnchor.x - _bodyOffsetX, win._dpr)
            y: Theme.snap(_notifBodySceneBlurAnchor.y - _bodyOffsetY, win._dpr)
            width: _isHoriz ? Theme.snap(_bodyW + _startCcr + _endCcr, win._dpr) : Theme.snap(_bodyW + _farExtent, win._dpr)
            height: _isHoriz ? Theme.snap(_bodyH + _farExtent, win._dpr) : Theme.snap(_bodyH + _startCcr + _endCcr, win._dpr)

            ConnectedShape {
                visible: _notifBodySceneBlurAnchor._active && _notifBodySceneBlurAnchor.width > 0 && _notifBodySceneBlurAnchor.height > 0
                barSide: _notifChrome._notifSide
                bodyWidth: _notifChrome._bodyW
                bodyHeight: _notifChrome._bodyH
                connectorRadius: win._effectiveNotifCcr
                startConnectorRadius: _notifChrome._startCcr
                endConnectorRadius: _notifChrome._endCcr
                farStartConnectorRadius: win._effectiveNotifFarStartCcr
                farEndConnectorRadius: win._effectiveNotifFarEndCcr
                surfaceRadius: win._surfaceRadius
                fillColor: win._opaqueSurfaceColor
                x: 0
                y: 0
            }
        }

        // Bar-side-bounded clip so modal chrome retracts behind the bar on exit
        // instead of sliding over bar widgets (mirrors the popout `_popoutClip`).
        Item {
            id: _modalClip
            visible: _modalBodyBlurAnchor._active
            z: 1

            readonly property string _modalSide: win._modalState.barSide
            readonly property real _inset: _modalBodyBlurAnchor._active && win.screen ? SettingsData.frameEdgeInsetForSide(win.screen, _modalSide) : 0
            readonly property real _topBound: _modalSide === "top" ? _inset : 0
            readonly property real _bottomBound: _modalSide === "bottom" ? (win.height - _inset) : win.height
            readonly property real _leftBound: _modalSide === "left" ? _inset : 0
            readonly property real _rightBound: _modalSide === "right" ? (win.width - _inset) : win.width

            x: _leftBound
            y: _topBound
            width: Math.max(0, _rightBound - _leftBound)
            height: Math.max(0, _bottomBound - _topBound)
            clip: true

            Item {
                id: _modalChrome

                readonly property string _modalSide: win._modalState.barSide
                readonly property bool _isHoriz: _modalSide === "top" || _modalSide === "bottom"
                readonly property real _startCcr: win._effectiveModalStartCcr
                readonly property real _endCcr: win._effectiveModalEndCcr
                readonly property real _farExtent: win._effectiveModalFarExtent
                readonly property real _bodyOffsetX: _isHoriz ? _startCcr : (_modalSide === "right" ? _farExtent : 0)
                readonly property real _bodyOffsetY: _isHoriz ? (_modalSide === "bottom" ? _farExtent : 0) : _startCcr
                readonly property real _bodyW: Theme.snap(_modalBodyBlurAnchor.width, win._dpr)
                readonly property real _bodyH: Theme.snap(_modalBodyBlurAnchor.height, win._dpr)

                x: Theme.snap(_modalBodyBlurAnchor.x - _bodyOffsetX - _modalClip.x, win._dpr)
                y: Theme.snap(_modalBodyBlurAnchor.y - _bodyOffsetY - _modalClip.y, win._dpr)
                width: _isHoriz ? Theme.snap(_bodyW + _startCcr + _endCcr, win._dpr) : Theme.snap(_bodyW + _farExtent, win._dpr)
                height: _isHoriz ? Theme.snap(_bodyH + _farExtent, win._dpr) : Theme.snap(_bodyH + _startCcr + _endCcr, win._dpr)

                ConnectedShape {
                    visible: _modalBodyBlurAnchor._active && _modalChrome._bodyW > 0 && _modalChrome._bodyH > 0
                    barSide: _modalChrome._modalSide
                    bodyWidth: _modalChrome._bodyW
                    bodyHeight: _modalChrome._bodyH
                    connectorRadius: win._effectiveModalCcr
                    startConnectorRadius: _modalChrome._startCcr
                    endConnectorRadius: _modalChrome._endCcr
                    farStartConnectorRadius: win._effectiveModalFarStartCcr
                    farEndConnectorRadius: win._effectiveModalFarEndCcr
                    surfaceRadius: win._surfaceRadius
                    fillColor: win._opaqueSurfaceColor
                    x: 0
                    y: 0
                }
            }
        }
    }
}
