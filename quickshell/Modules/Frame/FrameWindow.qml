pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import "../../Common/ConnectorGeometry.js" as ConnectorGeometry
import "../../Common/ConnectedSurfaceGeometry.js" as SurfaceGeometry

PanelWindow {
    id: win

    readonly property var log: Log.scoped("FrameWindow")

    required property var targetScreen

    screen: targetScreen
    readonly property bool _frameVisible: CompositorService.frameWindowVisibleForScreen(win.targetScreen)
    visible: win._frameVisible
    updatesEnabled: win._frameVisible

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
        return SettingsData.getActiveBarEdgesForScreen(win.targetScreen);
    }

    readonly property real _dpr: CompositorService.getScreenScale(win.targetScreen)
    readonly property bool _frameActive: SettingsData.frameEnabled && SettingsData.isScreenInPreferences(win.targetScreen, SettingsData.frameScreenPreferences)
    readonly property int _windowRegionWidth: win._regionInt(win.width)
    readonly property int _windowRegionHeight: win._regionInt(win.height)
    readonly property string _screenName: win.targetScreen ? win.targetScreen.name : ""
    readonly property int _surfaceRevision: Number(ConnectedModeState.surfaceRevisions[win._screenName] || 0)
    readonly property var _popoutDescriptor: ConnectedModeState.surfaceDescriptor(win._screenName, "popout")
    readonly property var _dockDescriptor: ConnectedModeState.surfaceDescriptor(win._screenName, "dock")
    readonly property var _notifDescriptor: ConnectedModeState.surfaceDescriptor(win._screenName, "notification")
    readonly property var _modalDescriptor: ConnectedModeState.surfaceDescriptor(win._screenName, "modal")
    readonly property var _popoutState: ConnectedModeState.legacySurfaceState(win._screenName, "popout")
    readonly property var _dockState: ConnectedModeState.legacySurfaceState(win._screenName, "dock")
    readonly property var _notifState: ConnectedModeState.legacySurfaceState(win._screenName, "notification")
    readonly property var _modalState: ConnectedModeState.legacySurfaceState(win._screenName, "modal")

    readonly property bool _connectedActive: CompositorService.usesConnectedFrameChromeForScreen(win.targetScreen)
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

    readonly property bool _popoutHorizontal: SurfaceGeometry.isHorizontal(win._popoutDescriptor.barSide)
    readonly property bool _notifHorizontal: ConnectorGeometry.isHorizontal(win._notifState.barSide)
    readonly property bool _modalHorizontal: ConnectorGeometry.isHorizontal(win._modalState.barSide)
    readonly property bool _dockHorizontal: ConnectorGeometry.isHorizontal(win._dockState.barSide)
    readonly property var _popoutBodyGeometry: SurfaceGeometry.animatedBodyRect(win._popoutDescriptor, win._dpr)
    readonly property var _popoutStaticBodyGeometry: SurfaceGeometry.bodyRect(win._popoutDescriptor, win._dpr)
    readonly property var _modalBodyGeometry: SurfaceGeometry.animatedBodyRect(win._modalDescriptor, win._dpr)
    readonly property var _notifBodyGeometry: SurfaceGeometry.bodyRect(win._notifDescriptor, win._dpr)
    readonly property var _dockBodyGeometry: SurfaceGeometry.translatedBodyRect(win._dockDescriptor, win._dpr)

    readonly property real _popoutArcExtent: win._popoutHorizontal ? _popoutBodyBlurAnchor.height : _popoutBodyBlurAnchor.width
    readonly property real _modalArcExtent: win._modalHorizontal ? _modalBodyBlurAnchor.height : _modalBodyBlurAnchor.width
    readonly property real _popoutConnectorRadiusLeft: win._effectivePopoutStartCcr
    readonly property real _popoutConnectorRadiusRight: win._effectivePopoutEndCcr
    readonly property real _modalConnectorRadiusLeft: win._effectiveModalStartCcr
    readonly property real _modalConnectorRadiusRight: win._effectiveModalEndCcr
    readonly property real _notifConnectorRadiusLeft: win._effectiveNotifStartCcr
    readonly property real _notifConnectorRadiusRight: win._effectiveNotifEndCcr
    readonly property real _dockBodyBlurRadiusValue: _dockBodyBlurAnchor._active ? Math.max(0, Math.min(win._surfaceRadius, _dockBodyBlurAnchor.width / 2, _dockBodyBlurAnchor.height / 2)) : win._surfaceRadius
    readonly property real _dockConnectorRadiusValue: {
        if (!_dockBodyBlurAnchor._active)
            return win._ccr;
        const thickness = (win._dockState.barSide === "left" || win._dockState.barSide === "right") ? _dockBodyBlurAnchor.width : _dockBodyBlurAnchor.height;
        const bodyRadius = win._dockBodyBlurRadiusValue;
        const maxConnectorRadius = Math.max(0, thickness - bodyRadius - win._seamOverlap);
        return Math.max(0, Math.min(win._ccr, bodyRadius, maxConnectorRadius));
    }

    readonly property real _popoutFillOverlapXValue: win._popoutHorizontal ? win._seamOverlap : 0
    readonly property real _popoutFillOverlapYValue: (win._popoutState.barSide === "left" || win._popoutState.barSide === "right") ? win._seamOverlap : 0
    readonly property real _dockFillOverlapXValue: win._dockHorizontal ? win._seamOverlap : 0
    readonly property real _dockFillOverlapYValue: (win._dockState.barSide === "left" || win._dockState.barSide === "right") ? win._seamOverlap : 0
    readonly property real _dockJoinOverlapXValue: ConnectorGeometry.isVertical(win._dockState.barSide) ? win._seamOverlap : 0
    readonly property real _dockJoinOverlapYValue: ConnectorGeometry.isHorizontal(win._dockState.barSide) ? win._seamOverlap : 0
    readonly property real _notifSideUnderlapValue: ConnectorGeometry.isVertical(win._notifState.barSide) ? win._seamOverlap : 0
    readonly property real _notifStartUnderlapValue: win._notifState.omitStartConnector ? win._seamOverlap : 0
    readonly property real _notifEndUnderlapValue: win._notifState.omitEndConnector ? win._seamOverlap : 0

    // Theme.snap rounds to integer pixel: equal rounded values suppress
    // downstream Changed during sub-pixel morph jitter.
    readonly property var _popoutRadii: SurfaceGeometry.connectorRadii(win._popoutDescriptor, win._popoutBodyGeometry, win._ccr, win._surfaceRadius, win._dpr, false)
    readonly property real _effectivePopoutCcr: win._popoutRadii.near
    readonly property real _effectivePopoutFarCcr: win._popoutRadii.far
    readonly property real _effectivePopoutStartCcr: win._popoutRadii.start
    readonly property real _effectivePopoutEndCcr: win._popoutRadii.end
    readonly property real _effectivePopoutFarStartCcr: win._popoutRadii.farStart
    readonly property real _effectivePopoutFarEndCcr: win._popoutRadii.farEnd
    readonly property real _effectivePopoutMaxCcr: Math.max(win._effectivePopoutStartCcr, win._effectivePopoutEndCcr)
    readonly property real _effectivePopoutFarExtent: Math.max(win._effectivePopoutFarStartCcr, win._effectivePopoutFarEndCcr)
    readonly property var _popoutChromeGeometry: SurfaceGeometry.chromeBounds(win._popoutStaticBodyGeometry, win._popoutDescriptor.barSide, win._effectivePopoutStartCcr, win._effectivePopoutEndCcr, 0, win._dpr)
    readonly property var _notifNearRadii: SurfaceGeometry.connectorRadii(win._notifDescriptor, win._notifBodyGeometry, win._ccr, win._surfaceRadius, win._dpr, true)
    readonly property var _notifFarRadii: SurfaceGeometry.connectorRadii(win._notifDescriptor, win._notifBodyScene(), win._ccr, win._surfaceRadius, win._dpr, true)
    readonly property real _effectiveNotifCcr: win._notifNearRadii.near
    readonly property real _effectiveNotifFarCcr: win._notifFarRadii.far
    readonly property real _effectiveNotifStartCcr: win._notifNearRadii.start
    readonly property real _effectiveNotifEndCcr: win._notifNearRadii.end
    readonly property real _effectiveNotifFarStartCcr: win._notifFarRadii.farStart
    readonly property real _effectiveNotifFarEndCcr: win._notifFarRadii.farEnd
    readonly property real _effectiveNotifMaxCcr: Math.max(win._effectiveNotifStartCcr, win._effectiveNotifEndCcr)
    readonly property real _effectiveNotifFarExtent: Math.max(win._effectiveNotifFarStartCcr, win._effectiveNotifFarEndCcr)
    readonly property var _modalRadii: SurfaceGeometry.connectorRadii(win._modalDescriptor, win._modalBodyGeometry, win._ccr, win._surfaceRadius, win._dpr, true)
    readonly property real _effectiveModalCcr: win._modalRadii.near
    readonly property real _effectiveModalFarCcr: win._modalRadii.far
    readonly property real _effectiveModalStartCcr: win._modalRadii.start
    readonly property real _effectiveModalEndCcr: win._modalRadii.end
    readonly property real _effectiveModalFarStartCcr: win._modalRadii.farStart
    readonly property real _effectiveModalFarEndCcr: win._modalRadii.farEnd
    readonly property real _effectiveModalFarExtent: Math.max(win._effectiveModalFarStartCcr, win._effectiveModalFarEndCcr)
    readonly property var _dockChromeGeometry: SurfaceGeometry.chromeBounds(win._dockBodyGeometry, win._dockDescriptor.barSide, win._dockConnectorRadiusValue, win._dockConnectorRadiusValue, 0, win._dpr)
    readonly property color _surfaceColor: Theme.connectedSurfaceColor
    readonly property real _surfaceOpacity: _surfaceColor.a
    readonly property color _opaqueSurfaceColor: Qt.rgba(_surfaceColor.r, _surfaceColor.g, _surfaceColor.b, 1)
    readonly property real _surfaceRadius: Theme.connectedSurfaceRadius
    readonly property real _seamOverlap: Theme.hairline(win._dpr)
    readonly property bool _disableLayer: Quickshell.env("DMS_DISABLE_LAYER") === "true" || Quickshell.env("DMS_DISABLE_LAYER") === "1"
    // The connected silhouette is drawn directly as one translucent Shape; the
    // full-output layer/FBO is allocated only when it must source the elevation
    // shadow. Translucency no longer needs a flatten (single primitive).
    readonly property bool _elevationShadow: win._connectedActive && Theme.elevationEnabled && !win._disableLayer
    // Active surfaces packed into four fixed SDF-shader slots. Each near (bar)
    // edge is clamped to the cutout edge so the smooth-min connector attaches
    // there; connR (the smin radius) is the connector fillet.
    readonly property var _sdfSlots: {
        const T = win.cutoutTopInset;
        const L = win.cutoutLeftInset;
        const R = win.width - win.cutoutRightInset;
        const B = win.height - win.cutoutBottomInset;
        const clampNear = function (side, b) {
            const r = {"x": b.x, "y": b.y, "width": b.width, "height": b.height};
            if (side === "top") {
                r.height = Math.max(0, b.y + b.height - T);
                r.y = T;
            } else if (side === "bottom") {
                r.height = Math.max(0, B - b.y);
            } else if (side === "left") {
                r.width = Math.max(0, b.x + b.width - L);
                r.x = L;
            } else if (side === "right") {
                r.width = Math.max(0, R - b.x);
            }
            return r;
        };
        const src = win._unifiedSurfaces();
        const out = [];
        for (let i = 0; i < 4; i++) {
            if (i < src.length) {
                const s = src[i];
                const b = clampNear(s.side, s.body);
                // smin radius = the near connector fillet only; an omitted
                // connector contributes no flare (its corner just rounds).
                const connR = Math.max(s.radii.startCr, s.radii.endCr);
                const active = b.width > 0 && b.height > 0 ? 1 : 0;
                // A bar-side corner is sharp only where its connector is present;
                // an omitted connector (farStart/farEnd set) keeps that corner
                // rounded. Far corners always round. (start=left/top, end=right/bottom.)
                const bodyR = s.radii.surfaceRadius;
                const omitS = s.radii.farStartCr > 0;
                const omitE = s.radii.farEndCr > 0;
                let tl = bodyR, tr = bodyR, br = bodyR, bl = bodyR;
                if (s.side === "top") {
                    if (!omitS) tl = 0;
                    if (!omitE) tr = 0;
                } else if (s.side === "bottom") {
                    if (!omitS) bl = 0;
                    if (!omitE) br = 0;
                } else if (s.side === "left") {
                    if (!omitS) tl = 0;
                    if (!omitE) bl = 0;
                } else {
                    if (!omitS) tr = 0;
                    if (!omitE) br = 0;
                }
                out.push({
                    "rect": Qt.vector4d(b.x, b.y, b.width, b.height),
                    "corner": Qt.vector4d(tl, tr, br, bl),
                    "param": Qt.vector4d(connR, active, 0, 0)
                });
            } else {
                out.push({"rect": Qt.vector4d(0, 0, 0, 0), "corner": Qt.vector4d(0, 0, 0, 0), "param": Qt.vector4d(0, 0, 0, 0)});
            }
        }
        return out;
    }
    property bool _surfaceRefreshNeedsLayerRecreate: false
    property bool _surfaceLayerRecoveryActive: false

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

        readonly property bool _active: win._popoutDescriptor.visible
        readonly property real _dyClamp: win._popoutBodyGeometry.dy
        readonly property real _dxClamp: win._popoutBodyGeometry.dx

        x: _active ? win._popoutBodyGeometry.x : 0
        y: _active ? win._popoutBodyGeometry.y : 0
        width: _active ? win._popoutBodyGeometry.width : 0
        height: _active ? win._popoutBodyGeometry.height : 0
    }

    Item {
        id: _dockBodyBlurAnchor
        visible: false

        readonly property bool _active: win._connectedActive && win._dockDescriptor.visible && win._dockBodyGeometry.width > 0 && win._dockBodyGeometry.height > 0

        x: _active ? win._dockBodyGeometry.x : 0
        y: _active ? win._dockBodyGeometry.y : 0
        width: _active ? win._dockBodyGeometry.width : 0
        height: _active ? win._dockBodyGeometry.height : 0
    }

    Item {
        id: _popoutBodyBlurCap
        opacity: 0

        readonly property string _side: win._popoutState.barSide
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
        readonly property real _capWidth: (_side === "left" || _side === "right") ? Math.min(win._dockConnectorRadiusValue, _dockBodyBlurAnchor.width) : _dockBodyBlurAnchor.width
        readonly property real _capHeight: (_side === "top" || _side === "bottom") ? Math.min(win._dockConnectorRadiusValue, _dockBodyBlurAnchor.height) : _dockBodyBlurAnchor.height

        x: !_active ? 0 : (_side === "right" ? _dockBodyBlurAnchor.x + _dockBodyBlurAnchor.width - _capWidth : _dockBodyBlurAnchor.x)
        y: !_active ? 0 : (_side === "bottom" ? _dockBodyBlurAnchor.y + _dockBodyBlurAnchor.height - _capHeight : _dockBodyBlurAnchor.y)
        width: _active ? _capWidth : 0
        height: _active ? _capHeight : 0
    }

    Item {
        id: _popoutLeftConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._popoutConnectorRadiusLeft
        readonly property bool _active: _popoutBodyBlurAnchor._active && _radius > 0
        readonly property var _rect: SurfaceGeometry.connectorRect(win._popoutDescriptor.barSide, win._popoutBodyGeometry, "left", 0, _radius, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _popoutRightConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._popoutConnectorRadiusRight
        readonly property bool _active: _popoutBodyBlurAnchor._active && _radius > 0
        readonly property var _rect: SurfaceGeometry.connectorRect(win._popoutDescriptor.barSide, win._popoutBodyGeometry, "right", 0, _radius, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _popoutLeftConnectorCutout
        opacity: 0

        readonly property bool _active: _popoutLeftConnectorBlurAnchor.width > 0 && _popoutLeftConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: ConnectorGeometry.arcCorner(win._popoutState.barSide, "left")
        readonly property real _radius: win._popoutConnectorRadiusLeft

        x: _active ? win._connectorCutoutX(_popoutLeftConnectorBlurAnchor.x, _popoutLeftConnectorBlurAnchor.width, _arcCorner, _radius) : 0
        y: _active ? win._connectorCutoutY(_popoutLeftConnectorBlurAnchor.y, _popoutLeftConnectorBlurAnchor.height, _arcCorner, _radius) : 0
        width: _active ? _radius * 2 : 0
        height: _active ? _radius * 2 : 0
    }

    Item {
        id: _popoutRightConnectorCutout
        opacity: 0

        readonly property bool _active: _popoutRightConnectorBlurAnchor.width > 0 && _popoutRightConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: ConnectorGeometry.arcCorner(win._popoutState.barSide, "right")
        readonly property real _radius: win._popoutConnectorRadiusRight

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
        readonly property var _rect: SurfaceGeometry.farConnectorRect(win._popoutDescriptor.barSide, win._popoutBodyGeometry, "left", _radius, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _popoutFarStartBodyBlurCap
        opacity: 0

        readonly property real _radius: win._effectivePopoutFarStartCcr
        readonly property bool _active: _popoutBodyBlurAnchor._active && _radius > 0
        readonly property var _rect: SurfaceGeometry.farBodyCapRect(win._popoutDescriptor.barSide, win._popoutBodyGeometry, "left", _radius, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _popoutFarEndBodyBlurCap
        opacity: 0

        readonly property real _radius: win._effectivePopoutFarEndCcr
        readonly property bool _active: _popoutBodyBlurAnchor._active && _radius > 0
        readonly property var _rect: SurfaceGeometry.farBodyCapRect(win._popoutDescriptor.barSide, win._popoutBodyGeometry, "right", _radius, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _popoutFarEndConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._effectivePopoutFarEndCcr
        readonly property bool _active: _popoutBodyBlurAnchor._active && _radius > 0
        readonly property var _rect: SurfaceGeometry.farConnectorRect(win._popoutDescriptor.barSide, win._popoutBodyGeometry, "right", _radius, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _popoutFarStartConnectorCutout
        opacity: 0

        readonly property bool _active: _popoutFarStartConnectorBlurAnchor.width > 0 && _popoutFarStartConnectorBlurAnchor.height > 0
        readonly property string _barSide: win._farConnectorBarSide(win._popoutState.barSide, "left")
        readonly property string _placement: win._farConnectorPlacement(win._popoutState.barSide, "left")
        readonly property string _arcCorner: ConnectorGeometry.arcCorner(_barSide, _placement)
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
        readonly property string _barSide: win._farConnectorBarSide(win._popoutState.barSide, "right")
        readonly property string _placement: win._farConnectorPlacement(win._popoutState.barSide, "right")
        readonly property string _arcCorner: ConnectorGeometry.arcCorner(_barSide, _placement)
        readonly property real _radius: win._effectivePopoutFarEndCcr

        x: _active ? win._connectorCutoutX(_popoutFarEndConnectorBlurAnchor.x, _popoutFarEndConnectorBlurAnchor.width, _arcCorner, _radius) : 0
        y: _active ? win._connectorCutoutY(_popoutFarEndConnectorBlurAnchor.y, _popoutFarEndConnectorBlurAnchor.height, _arcCorner, _radius) : 0
        width: _active ? _radius * 2 : 0
        height: _active ? _radius * 2 : 0
    }

    Item {
        id: _dockLeftConnectorBlurAnchor
        opacity: 0

        readonly property bool _active: _dockBodyBlurAnchor._active && win._dockConnectorRadiusValue > 0
        readonly property var _rect: SurfaceGeometry.connectorRect(win._dockDescriptor.barSide, win._dockBodyGeometry, "left", 0, win._dockConnectorRadiusValue, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _dockRightConnectorBlurAnchor
        opacity: 0

        readonly property bool _active: _dockBodyBlurAnchor._active && win._dockConnectorRadiusValue > 0
        readonly property var _rect: SurfaceGeometry.connectorRect(win._dockDescriptor.barSide, win._dockBodyGeometry, "right", 0, win._dockConnectorRadiusValue, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _dockLeftConnectorCutout
        opacity: 0

        readonly property bool _active: _dockLeftConnectorBlurAnchor.width > 0 && _dockLeftConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: ConnectorGeometry.arcCorner(win._dockState.barSide, "left")

        x: _active ? win._connectorCutoutX(_dockLeftConnectorBlurAnchor.x, _dockLeftConnectorBlurAnchor.width, _arcCorner, win._dockConnectorRadiusValue) : 0
        y: _active ? win._connectorCutoutY(_dockLeftConnectorBlurAnchor.y, _dockLeftConnectorBlurAnchor.height, _arcCorner, win._dockConnectorRadiusValue) : 0
        width: _active ? win._dockConnectorRadiusValue * 2 : 0
        height: _active ? win._dockConnectorRadiusValue * 2 : 0
    }

    Item {
        id: _dockRightConnectorCutout
        opacity: 0

        readonly property bool _active: _dockRightConnectorBlurAnchor.width > 0 && _dockRightConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: ConnectorGeometry.arcCorner(win._dockState.barSide, "right")

        x: _active ? win._connectorCutoutX(_dockRightConnectorBlurAnchor.x, _dockRightConnectorBlurAnchor.width, _arcCorner, win._dockConnectorRadiusValue) : 0
        y: _active ? win._connectorCutoutY(_dockRightConnectorBlurAnchor.y, _dockRightConnectorBlurAnchor.height, _arcCorner, win._dockConnectorRadiusValue) : 0
        width: _active ? win._dockConnectorRadiusValue * 2 : 0
        height: _active ? win._dockConnectorRadiusValue * 2 : 0
    }

    Item {
        id: _notifBodyBlurAnchor
        visible: false

        readonly property bool _active: win._frameActive && win._notifDescriptor.visible && win._notifBodyGeometry.width > 0 && win._notifBodyGeometry.height > 0

        x: _active ? win._notifBodyGeometry.x : 0
        y: _active ? win._notifBodyGeometry.y : 0
        width: _active ? win._notifBodyGeometry.width : 0
        height: _active ? win._notifBodyGeometry.height : 0
    }

    Item {
        id: _modalBodyBlurAnchor
        visible: false

        readonly property bool _active: win._frameActive && win._modalDescriptor.visible && win._modalBodyGeometry.width > 0 && win._modalBodyGeometry.height > 0
        readonly property real _dyClamp: win._modalBodyGeometry.dy
        readonly property real _dxClamp: win._modalBodyGeometry.dx

        x: _active ? win._modalBodyGeometry.x : 0
        y: _active ? win._modalBodyGeometry.y : 0
        width: _active ? win._modalBodyGeometry.width : 0
        height: _active ? win._modalBodyGeometry.height : 0
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

        readonly property real _radius: win._modalConnectorRadiusLeft
        readonly property bool _active: _modalBodyBlurAnchor._active && _radius > 0
        readonly property var _rect: SurfaceGeometry.connectorRect(win._modalDescriptor.barSide, win._modalBodyGeometry, "left", 0, _radius, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _modalRightConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._modalConnectorRadiusRight
        readonly property bool _active: _modalBodyBlurAnchor._active && _radius > 0
        readonly property var _rect: SurfaceGeometry.connectorRect(win._modalDescriptor.barSide, win._modalBodyGeometry, "right", 0, _radius, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _modalLeftConnectorCutout
        opacity: 0

        readonly property bool _active: _modalLeftConnectorBlurAnchor.width > 0 && _modalLeftConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: ConnectorGeometry.arcCorner(win._modalState.barSide, "left")
        readonly property real _radius: win._modalConnectorRadiusLeft

        x: _active ? win._connectorCutoutX(_modalLeftConnectorBlurAnchor.x, _modalLeftConnectorBlurAnchor.width, _arcCorner, _radius) : 0
        y: _active ? win._connectorCutoutY(_modalLeftConnectorBlurAnchor.y, _modalLeftConnectorBlurAnchor.height, _arcCorner, _radius) : 0
        width: _active ? _radius * 2 : 0
        height: _active ? _radius * 2 : 0
    }

    Item {
        id: _modalRightConnectorCutout
        opacity: 0

        readonly property bool _active: _modalRightConnectorBlurAnchor.width > 0 && _modalRightConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: ConnectorGeometry.arcCorner(win._modalState.barSide, "right")
        readonly property real _radius: win._modalConnectorRadiusRight

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
        readonly property var _rect: SurfaceGeometry.farConnectorRect(win._modalDescriptor.barSide, win._modalBodyGeometry, "left", _radius, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _modalFarStartBodyBlurCap
        opacity: 0

        readonly property real _radius: win._effectiveModalFarStartCcr
        readonly property bool _active: _modalBodyBlurAnchor._active && _radius > 0
        readonly property var _rect: SurfaceGeometry.farBodyCapRect(win._modalDescriptor.barSide, win._modalBodyGeometry, "left", _radius, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _modalFarEndBodyBlurCap
        opacity: 0

        readonly property real _radius: win._effectiveModalFarEndCcr
        readonly property bool _active: _modalBodyBlurAnchor._active && _radius > 0
        readonly property var _rect: SurfaceGeometry.farBodyCapRect(win._modalDescriptor.barSide, win._modalBodyGeometry, "right", _radius, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _modalFarEndConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._effectiveModalFarEndCcr
        readonly property bool _active: _modalBodyBlurAnchor._active && _radius > 0
        readonly property var _rect: SurfaceGeometry.farConnectorRect(win._modalDescriptor.barSide, win._modalBodyGeometry, "right", _radius, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _modalFarStartConnectorCutout
        opacity: 0

        readonly property bool _active: _modalFarStartConnectorBlurAnchor.width > 0 && _modalFarStartConnectorBlurAnchor.height > 0
        readonly property string _barSide: win._farConnectorBarSide(win._modalState.barSide, "left")
        readonly property string _placement: win._farConnectorPlacement(win._modalState.barSide, "left")
        readonly property string _arcCorner: ConnectorGeometry.arcCorner(_barSide, _placement)
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
        readonly property string _arcCorner: ConnectorGeometry.arcCorner(_barSide, _placement)
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
        readonly property var _scene: _active ? win._notifBodyScene() : null

        x: _scene ? Theme.snap(_scene.x, win._dpr) : 0
        y: _scene ? Theme.snap(_scene.y, win._dpr) : 0
        width: _scene ? Theme.snap(_scene.width, win._dpr) : 0
        height: _scene ? Theme.snap(_scene.height, win._dpr) : 0
    }

    Item {
        id: _notifBodyBlurCap
        opacity: 0

        readonly property string _side: win._notifState.barSide
        readonly property real _capRadius: win._effectiveNotifMaxCcr
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

        readonly property real _radius: win._notifConnectorRadiusLeft
        readonly property bool _active: _notifBodySceneBlurAnchor._active && _radius > 0
        readonly property var _rect: SurfaceGeometry.connectorRect(win._notifDescriptor.barSide, _notifBodySceneBlurAnchor, "left", 0, _radius, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _notifRightConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._notifConnectorRadiusRight
        readonly property bool _active: _notifBodySceneBlurAnchor._active && _radius > 0
        readonly property var _rect: SurfaceGeometry.connectorRect(win._notifDescriptor.barSide, _notifBodySceneBlurAnchor, "right", 0, _radius, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _notifLeftConnectorCutout
        opacity: 0

        readonly property bool _active: _notifLeftConnectorBlurAnchor.width > 0 && _notifLeftConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: ConnectorGeometry.arcCorner(win._notifState.barSide, "left")
        readonly property real _radius: win._notifConnectorRadiusLeft

        x: _active ? win._connectorCutoutX(_notifLeftConnectorBlurAnchor.x, _notifLeftConnectorBlurAnchor.width, _arcCorner, _radius) : 0
        y: _active ? win._connectorCutoutY(_notifLeftConnectorBlurAnchor.y, _notifLeftConnectorBlurAnchor.height, _arcCorner, _radius) : 0
        width: _active ? _radius * 2 : 0
        height: _active ? _radius * 2 : 0
    }

    Item {
        id: _notifRightConnectorCutout
        opacity: 0

        readonly property bool _active: _notifRightConnectorBlurAnchor.width > 0 && _notifRightConnectorBlurAnchor.height > 0
        readonly property string _arcCorner: ConnectorGeometry.arcCorner(win._notifState.barSide, "right")
        readonly property real _radius: win._notifConnectorRadiusRight

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
        readonly property var _rect: SurfaceGeometry.farConnectorRect(win._notifDescriptor.barSide, _notifBodySceneBlurAnchor, "left", _radius, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _notifFarStartBodyBlurCap
        opacity: 0

        readonly property real _radius: win._effectiveNotifFarStartCcr
        readonly property bool _active: _notifBodySceneBlurAnchor._active && _radius > 0
        readonly property var _rect: SurfaceGeometry.farBodyCapRect(win._notifDescriptor.barSide, _notifBodySceneBlurAnchor, "left", _radius, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _notifFarEndBodyBlurCap
        opacity: 0

        readonly property real _radius: win._effectiveNotifFarEndCcr
        readonly property bool _active: _notifBodySceneBlurAnchor._active && _radius > 0
        readonly property var _rect: SurfaceGeometry.farBodyCapRect(win._notifDescriptor.barSide, _notifBodySceneBlurAnchor, "right", _radius, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _notifFarEndConnectorBlurAnchor
        opacity: 0

        readonly property real _radius: win._effectiveNotifFarEndCcr
        readonly property bool _active: _notifBodySceneBlurAnchor._active && _radius > 0
        readonly property var _rect: SurfaceGeometry.farConnectorRect(win._notifDescriptor.barSide, _notifBodySceneBlurAnchor, "right", _radius, win._dpr)

        x: _active ? _rect.x : 0
        y: _active ? _rect.y : 0
        width: _active ? _rect.width : 0
        height: _active ? _rect.height : 0
    }

    Item {
        id: _notifFarStartConnectorCutout
        opacity: 0

        readonly property bool _active: _notifFarStartConnectorBlurAnchor.width > 0 && _notifFarStartConnectorBlurAnchor.height > 0
        readonly property string _barSide: win._farConnectorBarSide(win._notifState.barSide, "left")
        readonly property string _placement: win._farConnectorPlacement(win._notifState.barSide, "left")
        readonly property string _arcCorner: ConnectorGeometry.arcCorner(_barSide, _placement)
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
        readonly property string _arcCorner: ConnectorGeometry.arcCorner(_barSide, _placement)
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
                radius: win._popoutConnectorRadiusLeft
            }
        }
        Region {
            item: _popoutRightConnectorBlurAnchor
            Region {
                item: _popoutRightConnectorCutout
                intersection: Intersection.Subtract
                radius: win._popoutConnectorRadiusRight
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

        Region {
            item: _dockBodyBlurAnchor
            radius: win._dockBodyBlurRadiusValue
        }
        Region {
            item: _dockBodyBlurCap
        }
        Region {
            item: _dockLeftConnectorBlurAnchor
            Region {
                item: _dockLeftConnectorCutout
                intersection: Intersection.Subtract
                radius: win._dockConnectorRadiusValue
            }
        }
        Region {
            item: _dockRightConnectorBlurAnchor
            Region {
                item: _dockRightConnectorCutout
                intersection: Intersection.Subtract
                radius: win._dockConnectorRadiusValue
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
                radius: win._notifConnectorRadiusLeft
            }
        }
        Region {
            item: _notifRightConnectorBlurAnchor
            Region {
                item: _notifRightConnectorCutout
                intersection: Intersection.Subtract
                radius: win._notifConnectorRadiusRight
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
                radius: win._modalConnectorRadiusLeft
            }
        }
        Region {
            item: _modalRightConnectorBlurAnchor
            Region {
                item: _modalRightConnectorCutout
                intersection: Intersection.Subtract
                radius: win._modalConnectorRadiusRight
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

    // Notif body scene rect, accounting for start/end/side underlaps per bar orientation.
    function _notifBodyScene() {
        const isHoriz = ConnectorGeometry.isHorizontal(win._notifState.barSide);
        const start = win._notifStartUnderlapValue;
        const end = win._notifEndUnderlapValue;
        const side = win._notifSideUnderlapValue;
        if (isHoriz) {
            return {
                "x": _notifBodyBlurAnchor.x - start,
                "y": _notifBodyBlurAnchor.y,
                "width": _notifBodyBlurAnchor.width + start + end,
                "height": _notifBodyBlurAnchor.height
            };
        }
        return {
            "x": _notifBodyBlurAnchor.x - (win._notifState.barSide === "left" ? side : 0),
            "y": _notifBodyBlurAnchor.y - start,
            "width": _notifBodyBlurAnchor.width + side,
            "height": _notifBodyBlurAnchor.height + start + end
        };
    }

    function _modalBlurCapThickness() {
        const extent = win._modalArcExtent;
        return Math.max(0, Math.min(win._effectiveModalCcr, extent - win._surfaceRadius));
    }

    function _popoutArcVisible() {
        if (!_popoutBodyBlurAnchor._active || _popoutBodyBlurAnchor.width <= 0 || _popoutBodyBlurAnchor.height <= 0)
            return false;
        return win._popoutArcExtent >= win._ccr * (1 + win._ccr * 0.02);
    }

    function _popoutBlurCapThickness() {
        const extent = win._popoutArcExtent;
        return Math.max(0, Math.min(win._effectivePopoutMaxCcr, extent - win._surfaceRadius));
    }

    function _popoutChromeX() {
        return win._popoutChromeGeometry.x;
    }

    function _popoutChromeY() {
        return win._popoutChromeGeometry.y;
    }

    function _popoutChromeWidth() {
        return win._popoutChromeGeometry.width;
    }

    function _popoutChromeHeight() {
        return win._popoutChromeGeometry.height;
    }

    function _popoutClipX() {
        return _popoutBodyBlurAnchor.x - win._popoutChromeX() - win._popoutFillOverlapXValue;
    }

    function _popoutClipY() {
        return _popoutBodyBlurAnchor.y - win._popoutChromeY() - win._popoutFillOverlapYValue;
    }

    function _popoutClipWidth() {
        return _popoutBodyBlurAnchor.width + win._popoutFillOverlapXValue * 2;
    }

    function _popoutClipHeight() {
        return _popoutBodyBlurAnchor.height + win._popoutFillOverlapYValue * 2;
    }

    function _popoutShapeBodyOffsetX() {
        const side = win._popoutState.barSide;
        if (ConnectorGeometry.isHorizontal(side))
            return win._effectivePopoutStartCcr;
        return side === "right" ? win._effectivePopoutFarExtent : 0;
    }

    function _popoutShapeBodyOffsetY() {
        const side = win._popoutState.barSide;
        if (ConnectorGeometry.isHorizontal(side))
            return side === "bottom" ? win._effectivePopoutFarExtent : 0;
        return win._effectivePopoutStartCcr;
    }

    function _popoutShapeWidth() {
        const side = win._popoutState.barSide;
        if (ConnectorGeometry.isHorizontal(side))
            return win._popoutClipWidth() + win._effectivePopoutStartCcr + win._effectivePopoutEndCcr;
        return win._popoutClipWidth() + win._effectivePopoutFarExtent;
    }

    function _popoutShapeHeight() {
        const side = win._popoutState.barSide;
        if (ConnectorGeometry.isHorizontal(side))
            return win._popoutClipHeight() + win._effectivePopoutFarExtent;
        return win._popoutClipHeight() + win._effectivePopoutStartCcr + win._effectivePopoutEndCcr;
    }

    function _popoutBodyXInClip() {
        return (win._popoutState.barSide === "left" ? _popoutBodyBlurAnchor._dxClamp : 0) - win._popoutFillOverlapXValue;
    }

    function _popoutBodyYInClip() {
        return (win._popoutState.barSide === "top" ? _popoutBodyBlurAnchor._dyClamp : 0) - win._popoutFillOverlapYValue;
    }

    function _popoutBodyFullWidth() {
        return win._popoutState.bodyW + win._popoutFillOverlapXValue * 2;
    }

    function _popoutBodyFullHeight() {
        return win._popoutState.bodyH + win._popoutFillOverlapYValue * 2;
    }

    // Active connected surfaces fed to the unified silhouette path. Raw animated
    // body rects (no seam/fill overlap); the builder anchors each to the cutout
    // edge. Connector radii match what each ConnectedShape would receive.
    function _unifiedSurfaces() {
        const arr = [];
        const p = win._popoutBodyGeometry;
        if (win._popoutDescriptor.visible && win._popoutState.screen === win._screenName && p.width > 0 && p.height > 0)
            arr.push({
                "side": win._popoutDescriptor.barSide,
                "body": {"x": p.x, "y": p.y, "width": p.width, "height": p.height},
                "radii": {
                    "startCr": win._effectivePopoutStartCcr,
                    "endCr": win._effectivePopoutEndCcr,
                    "farStartCr": win._effectivePopoutFarStartCcr,
                    "farEndCr": win._effectivePopoutFarEndCcr,
                    "surfaceRadius": win._surfaceRadius
                }
            });
        const m = win._modalBodyGeometry;
        if (win._frameActive && win._modalDescriptor.visible && m.width > 0 && m.height > 0)
            arr.push({
                "side": win._modalDescriptor.barSide,
                "body": {"x": m.x, "y": m.y, "width": m.width, "height": m.height},
                "radii": {
                    "startCr": win._effectiveModalStartCcr,
                    "endCr": win._effectiveModalEndCcr,
                    "farStartCr": win._effectiveModalFarStartCcr,
                    "farEndCr": win._effectiveModalFarEndCcr,
                    "surfaceRadius": win._surfaceRadius
                }
            });
        const n = win._notifBodyGeometry;
        if (win._frameActive && win._notifDescriptor.visible && n.width > 0 && n.height > 0)
            arr.push({
                "side": win._notifDescriptor.barSide,
                "body": {"x": n.x, "y": n.y, "width": n.width, "height": n.height},
                "radii": {
                    "startCr": win._effectiveNotifStartCcr,
                    "endCr": win._effectiveNotifEndCcr,
                    "farStartCr": win._effectiveNotifFarStartCcr,
                    "farEndCr": win._effectiveNotifFarEndCcr,
                    "surfaceRadius": win._surfaceRadius
                }
            });
        const dk = win._dockBodyGeometry;
        if (win._connectedActive && win._dockDescriptor.visible && dk.width > 0 && dk.height > 0)
            arr.push({
                "side": win._dockDescriptor.barSide,
                "body": {"x": dk.x, "y": dk.y, "width": dk.width, "height": dk.height},
                "radii": {
                    "startCr": win._dockConnectorRadiusValue,
                    "endCr": win._dockConnectorRadiusValue,
                    "farStartCr": 0,
                    "farEndCr": 0,
                    "surfaceRadius": win._dockBodyBlurRadiusValue
                }
            });
        return arr;
    }

    function _dockChromeX() {
        return win._dockChromeGeometry.x;
    }

    function _dockChromeY() {
        return win._dockChromeGeometry.y;
    }

    function _dockChromeWidth() {
        return win._dockChromeGeometry.width;
    }

    function _dockChromeHeight() {
        return win._dockChromeGeometry.height;
    }

    function _dockBodyXInChrome() {
        return (ConnectorGeometry.isHorizontal(win._dockState.barSide) ? win._dockConnectorRadiusValue : 0) - win._dockFillOverlapXValue;
    }

    function _dockBodyYInChrome() {
        return ((win._dockState.barSide === "left" || win._dockState.barSide === "right") ? win._dockConnectorRadiusValue : 0) - win._dockFillOverlapYValue;
    }

    function _dockJoinOverlapXOffset() {
        return win._dockState.barSide === "left" ? -win._dockJoinOverlapXValue : 0;
    }

    function _dockJoinOverlapYOffset() {
        return win._dockState.barSide === "top" ? -win._dockJoinOverlapYValue : 0;
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

    function _connectorCutoutX(connectorX, connectorWidth, arcCorner, radius) {
        const r = radius === undefined ? win._effectivePopoutCcr : radius;
        return (arcCorner === "topLeft" || arcCorner === "bottomLeft") ? connectorX - r : connectorX + connectorWidth - r;
    }

    function _connectorCutoutY(connectorY, connectorHeight, arcCorner, radius) {
        const r = radius === undefined ? win._effectivePopoutCcr : radius;
        return (arcCorner === "topLeft" || arcCorner === "topRight") ? connectorY - r : connectorY + connectorHeight - r;
    }

    function _buildBlur(forceRepublish) {
        try {
            if (!BlurService.enabled || !SettingsData.frameBlurEnabled || !win._frameActive || !win.visible) {
                win.BackgroundEffect.blurRegion = null;
                return;
            }
            if (forceRepublish)
                win.BackgroundEffect.blurRegion = null;
            win.BackgroundEffect.blurRegion = _staticBlurRegion;
        } catch (e) {
            win.log.warn("Failed to set blur region:", e);
        }
    }

    function _teardownBlur() {
        try {
            win.BackgroundEffect.blurRegion = null;
        } catch (e) {}
    }

    // Coalesce bursts of settings-change signals into a single _buildBlur() call
    // on the next event loop tick.
    DeferredAction {
        id: blurRebuildAction
        onTriggered: win._runBlurRebuild()
    }

    function _scheduleBlurRebuild() {
        blurRebuildAction.schedule();
    }
    function _runBlurRebuild() {
        _buildBlur(false);
    }

    function _republishFrameBlur() {
        _buildBlur(true);
    }

    function _requestContentUpdate() {
        try {
            if (win.contentItem && typeof win.contentItem.update === "function")
                win.contentItem.update();
        } catch (e) {}
    }

    function _scheduleSurfaceRefresh(recreateLayer) {
        if (recreateLayer)
            _surfaceRefreshNeedsLayerRecreate = true;
        surfaceRefreshAction.restart();
    }

    function _runSurfaceRefresh() {
        if (!win.visible)
            return;
        if (_surfaceRefreshNeedsLayerRecreate) {
            _surfaceRefreshNeedsLayerRecreate = false;
            if (win._elevationShadow) {
                _surfaceLayerRecoveryActive = true;
                surfaceLayerRestoreAction.restart();
            }
        }
        _requestContentUpdate();
        _republishFrameBlur();
    }

    function _finishSurfaceLayerRecovery() {
        _surfaceLayerRecoveryActive = false;
        _requestContentUpdate();
        _republishFrameBlur();
    }

    DeferredAction {
        id: surfaceRefreshAction
        onTriggered: win._runSurfaceRefresh()
    }

    DeferredAction {
        id: surfaceLayerRestoreAction
        onTriggered: win._finishSurfaceLayerRecovery()
    }

    Connections {
        target: SettingsData
        function onFrameBlurEnabledChanged() {
            win._scheduleBlurRebuild();
        }
        function onFrameEnabledChanged() {
            win._scheduleBlurRebuild();
        }
        function onFrameThicknessChanged() {
            win._scheduleBlurRebuild();
        }
        function onFrameBarSizeChanged() {
            win._scheduleBlurRebuild();
        }
        function onFrameOpacityChanged() {
            win._scheduleBlurRebuild();
        }
        function onFrameRoundingChanged() {
            win._scheduleBlurRebuild();
        }
        function onFrameScreenPreferencesChanged() {
            win._scheduleBlurRebuild();
        }
        function onBarConfigsChanged() {
            win._scheduleBlurRebuild();
        }
        function onConnectedFrameModeActiveChanged() {
            win._scheduleBlurRebuild();
        }
        function onFrameCloseGapsChanged() {
            win._scheduleBlurRebuild();
        }
    }

    Connections {
        target: BlurService
        function onEnabledChanged() {
            win._scheduleBlurRebuild();
        }
    }

    onVisibleChanged: {
        if (visible) {
            win._scheduleBlurRebuild();
            win._scheduleSurfaceRefresh(false);
        } else {
            surfaceRefreshAction.cancel();
            surfaceLayerRestoreAction.cancel();
            _surfaceLayerRecoveryActive = false;
            _surfaceRefreshNeedsLayerRecreate = false;
            _teardownBlur();
        }
    }

    on_SurfaceRevisionChanged: win._scheduleSurfaceRefresh(false)

    onResourcesLost: {
        blurRebuildAction.cancel();
        surfaceRefreshAction.cancel();
        surfaceLayerRestoreAction.cancel();
        _surfaceRefreshNeedsLayerRecreate = true;
        if (win._elevationShadow)
            _surfaceLayerRecoveryActive = true;
        win._teardownBlur();
    }

    onWindowConnected: {
        win._scheduleSurfaceRefresh(true);
        win._scheduleBlurRebuild();
    }

    Component.onCompleted: {
        win._scheduleBlurRebuild();
        win._scheduleSurfaceRefresh(false);
    }
    Component.onDestruction: {
        blurRebuildAction.cancel();
        surfaceRefreshAction.cancel();
        surfaceLayerRestoreAction.cancel();
        win._teardownBlur();
    }

    FrameBorder {
        anchors.fill: parent
        visible: win._frameActive && !win._connectedActive
        cutoutTopInset: win.cutoutTopInset
        cutoutBottomInset: win.cutoutBottomInset
        cutoutLeftInset: win.cutoutLeftInset
        cutoutRightInset: win.cutoutRightInset
        cutoutRadius: win.cutoutRadius
    }

    Item {
        id: _connectedSurfaceLayer
        anchors.fill: parent
        visible: win._connectedActive
        // Elevation-off draws the silhouette directly at the surface color, so
        // group opacity is 1. Elevation-on draws children opaque and applies the
        // surface alpha to the whole group beneath the shadow.
        opacity: win._elevationShadow ? win._surfaceOpacity : 1
        // FBO is allocated only to source the elevation shadow.
        layer.enabled: win._elevationShadow && !win._surfaceLayerRecoveryActive
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

        // Elevation-off: the entire connected silhouette (frame ring + every
        // active chrome) as one SDF in a fragment shader. Analytic fwidth AA →
        // crisp at any scale, no FBO; the smooth-min radius is the connector.
        ShaderEffect {
            anchors.fill: parent
            visible: win._connectedActive && !win._elevationShadow
            fragmentShader: Qt.resolvedUrl("../../Shaders/qsb/connected_arc.frag.qsb")

            property real widthPx: width
            property real heightPx: height
            property real cutoutRadius: win.cutoutRadius
            property vector4d cutout: Qt.vector4d(win.cutoutLeftInset, win.cutoutTopInset, win.width - win.cutoutRightInset, win.height - win.cutoutBottomInset)
            property vector4d surfaceColor: Qt.vector4d(win._surfaceColor.r, win._surfaceColor.g, win._surfaceColor.b, win._surfaceColor.a)
            property vector4d chromeRect0: win._sdfSlots[0].rect
            property vector4d chromeCorner0: win._sdfSlots[0].corner
            property vector4d chromeParam0: win._sdfSlots[0].param
            property vector4d chromeRect1: win._sdfSlots[1].rect
            property vector4d chromeCorner1: win._sdfSlots[1].corner
            property vector4d chromeParam1: win._sdfSlots[1].param
            property vector4d chromeRect2: win._sdfSlots[2].rect
            property vector4d chromeCorner2: win._sdfSlots[2].corner
            property vector4d chromeParam2: win._sdfSlots[2].param
            property vector4d chromeRect3: win._sdfSlots[3].rect
            property vector4d chromeCorner3: win._sdfSlots[3].corner
            property vector4d chromeParam3: win._sdfSlots[3].param
        }

        // Elevation-on: opaque children flattened in the FBO so the MultiEffect
        // can derive one shadow; the layer applies the surface alpha.
        FrameBorder {
            anchors.fill: parent
            visible: win._elevationShadow
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
            visible: win._elevationShadow

            Item {
                id: _popoutChrome
                visible: win._popoutState.visible && win._popoutState.screen === win._screenName
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
                        barSide: win._popoutState.barSide
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
                    x: win._dockBodyXInChrome() + win._dockJoinOverlapXOffset()
                    y: win._dockBodyYInChrome() + win._dockJoinOverlapYOffset()
                    width: _dockBodyBlurAnchor.width + win._dockFillOverlapXValue * 2 + win._dockJoinOverlapXValue
                    height: _dockBodyBlurAnchor.height + win._dockFillOverlapYValue * 2 + win._dockJoinOverlapYValue
                    color: win._opaqueSurfaceColor
                    z: 1

                    readonly property string _dockSide: win._dockState.barSide
                    readonly property real _dockRadius: win._dockBodyBlurRadiusValue
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
                    connectorRadius: win._dockConnectorRadiusValue
                    color: win._opaqueSurfaceColor
                    dpr: win._dpr
                    x: Theme.snap(_dockLeftConnectorBlurAnchor.x - _dockChrome.x, win._dpr)
                    y: Theme.snap(_dockLeftConnectorBlurAnchor.y - _dockChrome.y, win._dpr)
                }

                ConnectedCorner {
                    id: _connDockRight
                    visible: _dockBodyBlurAnchor._active
                    barSide: win._dockState.barSide
                    placement: "right"
                    spacing: 0
                    connectorRadius: win._dockConnectorRadiusValue
                    color: win._opaqueSurfaceColor
                    dpr: win._dpr
                    x: Theme.snap(_dockRightConnectorBlurAnchor.x - _dockChrome.x, win._dpr)
                    y: Theme.snap(_dockRightConnectorBlurAnchor.y - _dockChrome.y, win._dpr)
                }
            }
        }

        Item {
            id: _notifChrome
            visible: win._elevationShadow && _notifBodySceneBlurAnchor._active

            readonly property string _notifSide: win._notifState.barSide
            readonly property bool _isHoriz: _notifSide === "top" || _notifSide === "bottom"
            readonly property real _startCcr: win._effectiveNotifStartCcr
            readonly property real _endCcr: win._effectiveNotifEndCcr
            readonly property real _farExtent: win._effectiveNotifFarExtent
            readonly property real _bodyW: Theme.snap(_notifBodySceneBlurAnchor.width, win._dpr)
            readonly property real _bodyH: Theme.snap(_notifBodySceneBlurAnchor.height, win._dpr)
            readonly property var _geometry: SurfaceGeometry.chromeBounds(_notifBodySceneBlurAnchor, _notifSide, _startCcr, _endCcr, _farExtent, win._dpr)

            z: _isHoriz ? 0 : -1
            x: _geometry.x
            y: _geometry.y
            width: _geometry.width
            height: _geometry.height

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
            visible: win._elevationShadow && _modalBodyBlurAnchor._active
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
                readonly property real _bodyW: Theme.snap(_modalBodyBlurAnchor.width, win._dpr)
                readonly property real _bodyH: Theme.snap(_modalBodyBlurAnchor.height, win._dpr)
                readonly property var _geometry: SurfaceGeometry.chromeBounds(_modalBodyBlurAnchor, _modalSide, _startCcr, _endCcr, _farExtent, win._dpr)

                x: Theme.snap(_geometry.x - _modalClip.x, win._dpr)
                y: Theme.snap(_geometry.y - _modalClip.y, win._dpr)
                width: _geometry.width
                height: _geometry.height

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
