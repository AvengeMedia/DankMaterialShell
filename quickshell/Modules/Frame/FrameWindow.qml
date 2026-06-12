pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
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
    readonly property bool _modalHorizontal: SurfaceGeometry.isHorizontal(win._modalDescriptor.barSide)
    readonly property var _popoutBodyGeometry: SurfaceGeometry.animatedBodyRect(win._popoutDescriptor, win._dpr)
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
        const thickness = SurfaceGeometry.isVertical(win._dockDescriptor.barSide) ? _dockBodyBlurAnchor.width : _dockBodyBlurAnchor.height;
        const bodyRadius = win._dockBodyBlurRadiusValue;
        const maxConnectorRadius = Math.max(0, thickness - bodyRadius - win._seamOverlap);
        return Math.max(0, Math.min(win._ccr, bodyRadius, maxConnectorRadius));
    }

    readonly property real _notifSideUnderlapValue: SurfaceGeometry.isVertical(win._notifDescriptor.barSide) ? win._seamOverlap : 0
    readonly property real _notifStartUnderlapValue: win._notifDescriptor.omitStartConnector ? win._seamOverlap : 0
    readonly property real _notifEndUnderlapValue: win._notifDescriptor.omitEndConnector ? win._seamOverlap : 0

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
    readonly property color _surfaceColor: Theme.connectedSurfaceColor
    readonly property real _surfaceRadius: Theme.connectedSurfaceRadius
    readonly property real _seamOverlap: Theme.hairline(win._dpr)
    readonly property bool _disableLayer: Quickshell.env("DMS_DISABLE_LAYER") === "true" || Quickshell.env("DMS_DISABLE_LAYER") === "1"
    // Both elevation states render through the SDF shader; this only toggles
    // the shadow term inside it.
    readonly property bool _elevationShadow: win._connectedActive && Theme.elevationEnabled && !win._disableLayer
    // Active surfaces packed into four fixed SDF-shader slots. Each near (bar)
    // edge is clamped to the cutout edge so the smooth-min connector attaches
    // there; the per-corner smin radius is that corner's junction fillet.
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
                const active = b.width > 0 && b.height > 0 ? 1 : 0;
                // Map start/end (left/top, right/bottom) onto corners
                // (tl,tr,br,bl): bar-side corners take their near connector
                // fillet, far corners always take the far fillet so a body
                // meeting a perpendicular border joins with an arc (smin is
                // inert when nothing is within k). A bar-side corner is sharp
                // where its connector is present; an omitted connector makes
                // its far corner sharp instead (the far-cap join).
                const sc = s.radii.startCr, ec = s.radii.endCr;
                // Clamp the far fillet to the body extent so it cannot flare
                // back across a shallow body into the bar mid-animation.
                const extent = (s.side === "top" || s.side === "bottom") ? b.height : b.width;
                const fc = Math.min(s.radii.farCr, extent);
                const omitS = s.radii.farStartCr > 0;
                const omitE = s.radii.farEndCr > 0;
                const bodyR = s.radii.surfaceRadius;
                const nearS = omitS ? bodyR : 0, nearE = omitE ? bodyR : 0;
                const farS = omitS ? 0 : bodyR, farE = omitE ? 0 : bodyR;
                // An omitted bar-side corner sits flush against the border, so
                // it keeps a nonzero fillet (a zero k hard-joins the coincident
                // edges and shows a half-coverage hairline along the seam).
                const kS = omitS ? fc : sc, kE = omitE ? fc : ec;
                let ks, cr;
                if (s.side === "top") {
                    ks = [kS, kE, fc, fc];
                    cr = [nearS, nearE, farE, farS];
                } else if (s.side === "bottom") {
                    ks = [fc, fc, kE, kS];
                    cr = [farS, farE, nearE, nearS];
                } else if (s.side === "left") {
                    ks = [kS, fc, fc, kE];
                    cr = [nearS, farS, farE, nearE];
                } else {
                    ks = [fc, kS, kE, fc];
                    cr = [farS, nearS, nearE, farE];
                }
                out.push({
                    "rect": Qt.vector4d(b.x, b.y, b.width, b.height),
                    "corner": Qt.vector4d(cr[0], cr[1], cr[2], cr[3]),
                    "k": Qt.vector4d(ks[0], ks[1], ks[2], ks[3]),
                    "param": Qt.vector4d(active, 0, 0, 0)
                });
            } else {
                out.push({"rect": Qt.vector4d(0, 0, 0, 0), "corner": Qt.vector4d(0, 0, 0, 0), "k": Qt.vector4d(0, 0, 0, 0), "param": Qt.vector4d(0, 0, 0, 0)});
            }
        }
        return out;
    }
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

    // Pins every surface blur region to zero while frame blur cannot be
    // consumed, so animations stop dirtying the region tree.
    readonly property bool _blurSurfacesActive: BlurService.enabled && SettingsData.frameBlurEnabled && win._frameActive
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

    // Blur regions bind rounded integer pixels directly: equal rounded values
    // suppress Changed during sub-pixel motion, and inactive children pin to
    // all-zero so the region build skips them.
    QtObject {
        id: _notifBodyBlurAnchor

        readonly property bool _active: win._blurSurfacesActive && win._notifDescriptor.visible && win._notifBodyGeometry.width > 0 && win._notifBodyGeometry.height > 0
        readonly property int x: _active ? Math.round(win._notifBodyGeometry.x) : 0
        readonly property int y: _active ? Math.round(win._notifBodyGeometry.y) : 0
        readonly property int width: _active ? Math.round(win._notifBodyGeometry.width) : 0
        readonly property int height: _active ? Math.round(win._notifBodyGeometry.height) : 0
    }

    Region {
        id: _staticBlurRegion
        x: 0
        y: 0
        width: win._windowRegionWidth
        height: win._windowRegionHeight

        // Frame cutout (always active when frame is on)
        Region {
            id: _blurCutout
            intersection: Intersection.Subtract
            radius: win._blurCutoutRadius
            x: win._blurCutoutLeft
            y: win._blurCutoutTop
            width: Math.max(0, win._blurCutoutRight - win._blurCutoutLeft)
            height: Math.max(0, win._blurCutoutBottom - win._blurCutoutTop)
        }

        Region {
            id: _popoutBodyBlurAnchor

            readonly property bool _active: win._blurSurfacesActive && win._popoutDescriptor.visible

            radius: win._surfaceRadius
            x: _active ? Math.round(win._popoutBodyGeometry.x) : 0
            y: _active ? Math.round(win._popoutBodyGeometry.y) : 0
            width: _active ? Math.round(win._popoutBodyGeometry.width) : 0
            height: _active ? Math.round(win._popoutBodyGeometry.height) : 0
        }
        Region {
            id: _popoutBodyBlurCap

            readonly property string _side: win._popoutDescriptor.barSide
            readonly property real _capThickness: win._popoutBlurCapThickness()
            readonly property bool _active: _popoutBodyBlurAnchor._active && _capThickness > 0 && _popoutBodyBlurAnchor.width > 0 && _popoutBodyBlurAnchor.height > 0
            readonly property int _capWidth: (_side === "left" || _side === "right") ? Math.round(Math.min(_capThickness, _popoutBodyBlurAnchor.width)) : _popoutBodyBlurAnchor.width
            readonly property int _capHeight: (_side === "top" || _side === "bottom") ? Math.round(Math.min(_capThickness, _popoutBodyBlurAnchor.height)) : _popoutBodyBlurAnchor.height

            x: !_active ? 0 : (_side === "right" ? _popoutBodyBlurAnchor.x + _popoutBodyBlurAnchor.width - _capWidth : _popoutBodyBlurAnchor.x)
            y: !_active ? 0 : (_side === "bottom" ? _popoutBodyBlurAnchor.y + _popoutBodyBlurAnchor.height - _capHeight : _popoutBodyBlurAnchor.y)
            width: _active ? _capWidth : 0
            height: _active ? _capHeight : 0
        }
        Region {
            id: _popoutLeftConnectorBlurAnchor

            readonly property real _radius: win._popoutConnectorRadiusLeft
            readonly property bool _active: _popoutBodyBlurAnchor._active && _radius > 0
            readonly property var _rect: SurfaceGeometry.connectorRect(win._popoutDescriptor.barSide, win._popoutBodyGeometry, "left", 0, _radius, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0

            Region {
                id: _popoutLeftConnectorCutout

                readonly property bool _active: _popoutLeftConnectorBlurAnchor.width > 0 && _popoutLeftConnectorBlurAnchor.height > 0
                readonly property string _arcCorner: ConnectorGeometry.arcCorner(win._popoutDescriptor.barSide, "left")
                readonly property real _radius: win._popoutConnectorRadiusLeft

                intersection: Intersection.Subtract
                radius: win._popoutConnectorRadiusLeft
                x: _active ? Math.round(win._connectorCutoutX(_popoutLeftConnectorBlurAnchor.x, _popoutLeftConnectorBlurAnchor.width, _arcCorner, _radius)) : 0
                y: _active ? Math.round(win._connectorCutoutY(_popoutLeftConnectorBlurAnchor.y, _popoutLeftConnectorBlurAnchor.height, _arcCorner, _radius)) : 0
                width: _active ? Math.round(_radius * 2) : 0
                height: _active ? Math.round(_radius * 2) : 0
            }
        }
        Region {
            id: _popoutRightConnectorBlurAnchor

            readonly property real _radius: win._popoutConnectorRadiusRight
            readonly property bool _active: _popoutBodyBlurAnchor._active && _radius > 0
            readonly property var _rect: SurfaceGeometry.connectorRect(win._popoutDescriptor.barSide, win._popoutBodyGeometry, "right", 0, _radius, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0

            Region {
                id: _popoutRightConnectorCutout

                readonly property bool _active: _popoutRightConnectorBlurAnchor.width > 0 && _popoutRightConnectorBlurAnchor.height > 0
                readonly property string _arcCorner: ConnectorGeometry.arcCorner(win._popoutDescriptor.barSide, "right")
                readonly property real _radius: win._popoutConnectorRadiusRight

                intersection: Intersection.Subtract
                radius: win._popoutConnectorRadiusRight
                x: _active ? Math.round(win._connectorCutoutX(_popoutRightConnectorBlurAnchor.x, _popoutRightConnectorBlurAnchor.width, _arcCorner, _radius)) : 0
                y: _active ? Math.round(win._connectorCutoutY(_popoutRightConnectorBlurAnchor.y, _popoutRightConnectorBlurAnchor.height, _arcCorner, _radius)) : 0
                width: _active ? Math.round(_radius * 2) : 0
                height: _active ? Math.round(_radius * 2) : 0
            }
        }
        Region {
            id: _popoutFarStartBodyBlurCap

            readonly property real _radius: win._effectivePopoutFarStartCcr
            readonly property bool _active: _popoutBodyBlurAnchor._active && _radius > 0
            readonly property var _rect: SurfaceGeometry.farBodyCapRect(win._popoutDescriptor.barSide, win._popoutBodyGeometry, "left", _radius, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0
        }
        Region {
            id: _popoutFarEndBodyBlurCap

            readonly property real _radius: win._effectivePopoutFarEndCcr
            readonly property bool _active: _popoutBodyBlurAnchor._active && _radius > 0
            readonly property var _rect: SurfaceGeometry.farBodyCapRect(win._popoutDescriptor.barSide, win._popoutBodyGeometry, "right", _radius, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0
        }
        Region {
            id: _popoutFarStartConnectorBlurAnchor

            readonly property real _radius: win._effectivePopoutFarStartCcr
            readonly property bool _active: _popoutBodyBlurAnchor._active && _radius > 0
            readonly property var _rect: SurfaceGeometry.farConnectorRect(win._popoutDescriptor.barSide, win._popoutBodyGeometry, "left", _radius, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0

            Region {
                id: _popoutFarStartConnectorCutout

                readonly property bool _active: _popoutFarStartConnectorBlurAnchor.width > 0 && _popoutFarStartConnectorBlurAnchor.height > 0
                readonly property string _barSide: win._farConnectorBarSide(win._popoutDescriptor.barSide, "left")
                readonly property string _placement: win._farConnectorPlacement(win._popoutDescriptor.barSide, "left")
                readonly property string _arcCorner: ConnectorGeometry.arcCorner(_barSide, _placement)
                readonly property real _radius: win._effectivePopoutFarStartCcr

                intersection: Intersection.Subtract
                radius: win._effectivePopoutFarStartCcr
                x: _active ? Math.round(win._connectorCutoutX(_popoutFarStartConnectorBlurAnchor.x, _popoutFarStartConnectorBlurAnchor.width, _arcCorner, _radius)) : 0
                y: _active ? Math.round(win._connectorCutoutY(_popoutFarStartConnectorBlurAnchor.y, _popoutFarStartConnectorBlurAnchor.height, _arcCorner, _radius)) : 0
                width: _active ? Math.round(_radius * 2) : 0
                height: _active ? Math.round(_radius * 2) : 0
            }
        }
        Region {
            id: _popoutFarEndConnectorBlurAnchor

            readonly property real _radius: win._effectivePopoutFarEndCcr
            readonly property bool _active: _popoutBodyBlurAnchor._active && _radius > 0
            readonly property var _rect: SurfaceGeometry.farConnectorRect(win._popoutDescriptor.barSide, win._popoutBodyGeometry, "right", _radius, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0

            Region {
                id: _popoutFarEndConnectorCutout

                readonly property bool _active: _popoutFarEndConnectorBlurAnchor.width > 0 && _popoutFarEndConnectorBlurAnchor.height > 0
                readonly property string _barSide: win._farConnectorBarSide(win._popoutDescriptor.barSide, "right")
                readonly property string _placement: win._farConnectorPlacement(win._popoutDescriptor.barSide, "right")
                readonly property string _arcCorner: ConnectorGeometry.arcCorner(_barSide, _placement)
                readonly property real _radius: win._effectivePopoutFarEndCcr

                intersection: Intersection.Subtract
                radius: win._effectivePopoutFarEndCcr
                x: _active ? Math.round(win._connectorCutoutX(_popoutFarEndConnectorBlurAnchor.x, _popoutFarEndConnectorBlurAnchor.width, _arcCorner, _radius)) : 0
                y: _active ? Math.round(win._connectorCutoutY(_popoutFarEndConnectorBlurAnchor.y, _popoutFarEndConnectorBlurAnchor.height, _arcCorner, _radius)) : 0
                width: _active ? Math.round(_radius * 2) : 0
                height: _active ? Math.round(_radius * 2) : 0
            }
        }

        Region {
            id: _dockBodyBlurAnchor

            readonly property bool _active: win._blurSurfacesActive && win._connectedActive && win._dockDescriptor.visible && win._dockBodyGeometry.width > 0 && win._dockBodyGeometry.height > 0

            radius: win._dockBodyBlurRadiusValue
            x: _active ? Math.round(win._dockBodyGeometry.x) : 0
            y: _active ? Math.round(win._dockBodyGeometry.y) : 0
            width: _active ? Math.round(win._dockBodyGeometry.width) : 0
            height: _active ? Math.round(win._dockBodyGeometry.height) : 0
        }
        Region {
            id: _dockBodyBlurCap

            readonly property string _side: win._dockDescriptor.barSide
            readonly property bool _active: _dockBodyBlurAnchor._active && _dockBodyBlurAnchor.width > 0 && _dockBodyBlurAnchor.height > 0
            readonly property int _capWidth: (_side === "left" || _side === "right") ? Math.round(Math.min(win._dockConnectorRadiusValue, _dockBodyBlurAnchor.width)) : _dockBodyBlurAnchor.width
            readonly property int _capHeight: (_side === "top" || _side === "bottom") ? Math.round(Math.min(win._dockConnectorRadiusValue, _dockBodyBlurAnchor.height)) : _dockBodyBlurAnchor.height

            x: !_active ? 0 : (_side === "right" ? _dockBodyBlurAnchor.x + _dockBodyBlurAnchor.width - _capWidth : _dockBodyBlurAnchor.x)
            y: !_active ? 0 : (_side === "bottom" ? _dockBodyBlurAnchor.y + _dockBodyBlurAnchor.height - _capHeight : _dockBodyBlurAnchor.y)
            width: _active ? _capWidth : 0
            height: _active ? _capHeight : 0
        }
        Region {
            id: _dockLeftConnectorBlurAnchor

            readonly property bool _active: _dockBodyBlurAnchor._active && win._dockConnectorRadiusValue > 0
            readonly property var _rect: SurfaceGeometry.connectorRect(win._dockDescriptor.barSide, win._dockBodyGeometry, "left", 0, win._dockConnectorRadiusValue, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0

            Region {
                id: _dockLeftConnectorCutout

                readonly property bool _active: _dockLeftConnectorBlurAnchor.width > 0 && _dockLeftConnectorBlurAnchor.height > 0
                readonly property string _arcCorner: ConnectorGeometry.arcCorner(win._dockDescriptor.barSide, "left")

                intersection: Intersection.Subtract
                radius: win._dockConnectorRadiusValue
                x: _active ? Math.round(win._connectorCutoutX(_dockLeftConnectorBlurAnchor.x, _dockLeftConnectorBlurAnchor.width, _arcCorner, win._dockConnectorRadiusValue)) : 0
                y: _active ? Math.round(win._connectorCutoutY(_dockLeftConnectorBlurAnchor.y, _dockLeftConnectorBlurAnchor.height, _arcCorner, win._dockConnectorRadiusValue)) : 0
                width: _active ? Math.round(win._dockConnectorRadiusValue * 2) : 0
                height: _active ? Math.round(win._dockConnectorRadiusValue * 2) : 0
            }
        }
        Region {
            id: _dockRightConnectorBlurAnchor

            readonly property bool _active: _dockBodyBlurAnchor._active && win._dockConnectorRadiusValue > 0
            readonly property var _rect: SurfaceGeometry.connectorRect(win._dockDescriptor.barSide, win._dockBodyGeometry, "right", 0, win._dockConnectorRadiusValue, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0

            Region {
                id: _dockRightConnectorCutout

                readonly property bool _active: _dockRightConnectorBlurAnchor.width > 0 && _dockRightConnectorBlurAnchor.height > 0
                readonly property string _arcCorner: ConnectorGeometry.arcCorner(win._dockDescriptor.barSide, "right")

                intersection: Intersection.Subtract
                radius: win._dockConnectorRadiusValue
                x: _active ? Math.round(win._connectorCutoutX(_dockRightConnectorBlurAnchor.x, _dockRightConnectorBlurAnchor.width, _arcCorner, win._dockConnectorRadiusValue)) : 0
                y: _active ? Math.round(win._connectorCutoutY(_dockRightConnectorBlurAnchor.y, _dockRightConnectorBlurAnchor.height, _arcCorner, win._dockConnectorRadiusValue)) : 0
                width: _active ? Math.round(win._dockConnectorRadiusValue * 2) : 0
                height: _active ? Math.round(win._dockConnectorRadiusValue * 2) : 0
            }
        }

        Region {
            id: _notifBodySceneBlurAnchor

            readonly property bool _active: _notifBodyBlurAnchor._active
            readonly property var _scene: _active ? win._notifBodyScene() : null

            radius: win._surfaceRadius
            x: _scene ? Math.round(_scene.x) : 0
            y: _scene ? Math.round(_scene.y) : 0
            width: _scene ? Math.round(_scene.width) : 0
            height: _scene ? Math.round(_scene.height) : 0
        }
        Region {
            id: _notifBodyBlurCap

            readonly property string _side: win._notifDescriptor.barSide
            readonly property real _capRadius: win._effectiveNotifMaxCcr
            readonly property bool _active: _notifBodySceneBlurAnchor._active && _notifBodySceneBlurAnchor.width > 0 && _notifBodySceneBlurAnchor.height > 0 && _capRadius > 0
            readonly property int _capWidth: (_side === "left" || _side === "right") ? Math.round(Math.min(_capRadius, _notifBodySceneBlurAnchor.width)) : _notifBodySceneBlurAnchor.width
            readonly property int _capHeight: (_side === "top" || _side === "bottom") ? Math.round(Math.min(_capRadius, _notifBodySceneBlurAnchor.height)) : _notifBodySceneBlurAnchor.height

            x: !_active ? 0 : (_side === "right" ? _notifBodySceneBlurAnchor.x + _notifBodySceneBlurAnchor.width - _capWidth : _notifBodySceneBlurAnchor.x)
            y: !_active ? 0 : (_side === "bottom" ? _notifBodySceneBlurAnchor.y + _notifBodySceneBlurAnchor.height - _capHeight : _notifBodySceneBlurAnchor.y)
            width: _active ? _capWidth : 0
            height: _active ? _capHeight : 0
        }
        Region {
            id: _notifLeftConnectorBlurAnchor

            readonly property real _radius: win._notifConnectorRadiusLeft
            readonly property bool _active: _notifBodySceneBlurAnchor._active && _radius > 0
            readonly property var _rect: SurfaceGeometry.connectorRect(win._notifDescriptor.barSide, _notifBodySceneBlurAnchor, "left", 0, _radius, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0

            Region {
                id: _notifLeftConnectorCutout

                readonly property bool _active: _notifLeftConnectorBlurAnchor.width > 0 && _notifLeftConnectorBlurAnchor.height > 0
                readonly property string _arcCorner: ConnectorGeometry.arcCorner(win._notifDescriptor.barSide, "left")
                readonly property real _radius: win._notifConnectorRadiusLeft

                intersection: Intersection.Subtract
                radius: win._notifConnectorRadiusLeft
                x: _active ? Math.round(win._connectorCutoutX(_notifLeftConnectorBlurAnchor.x, _notifLeftConnectorBlurAnchor.width, _arcCorner, _radius)) : 0
                y: _active ? Math.round(win._connectorCutoutY(_notifLeftConnectorBlurAnchor.y, _notifLeftConnectorBlurAnchor.height, _arcCorner, _radius)) : 0
                width: _active ? Math.round(_radius * 2) : 0
                height: _active ? Math.round(_radius * 2) : 0
            }
        }
        Region {
            id: _notifRightConnectorBlurAnchor

            readonly property real _radius: win._notifConnectorRadiusRight
            readonly property bool _active: _notifBodySceneBlurAnchor._active && _radius > 0
            readonly property var _rect: SurfaceGeometry.connectorRect(win._notifDescriptor.barSide, _notifBodySceneBlurAnchor, "right", 0, _radius, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0

            Region {
                id: _notifRightConnectorCutout

                readonly property bool _active: _notifRightConnectorBlurAnchor.width > 0 && _notifRightConnectorBlurAnchor.height > 0
                readonly property string _arcCorner: ConnectorGeometry.arcCorner(win._notifDescriptor.barSide, "right")
                readonly property real _radius: win._notifConnectorRadiusRight

                intersection: Intersection.Subtract
                radius: win._notifConnectorRadiusRight
                x: _active ? Math.round(win._connectorCutoutX(_notifRightConnectorBlurAnchor.x, _notifRightConnectorBlurAnchor.width, _arcCorner, _radius)) : 0
                y: _active ? Math.round(win._connectorCutoutY(_notifRightConnectorBlurAnchor.y, _notifRightConnectorBlurAnchor.height, _arcCorner, _radius)) : 0
                width: _active ? Math.round(_radius * 2) : 0
                height: _active ? Math.round(_radius * 2) : 0
            }
        }
        Region {
            id: _notifFarStartBodyBlurCap

            readonly property real _radius: win._effectiveNotifFarStartCcr
            readonly property bool _active: _notifBodySceneBlurAnchor._active && _radius > 0
            readonly property var _rect: SurfaceGeometry.farBodyCapRect(win._notifDescriptor.barSide, _notifBodySceneBlurAnchor, "left", _radius, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0
        }
        Region {
            id: _notifFarEndBodyBlurCap

            readonly property real _radius: win._effectiveNotifFarEndCcr
            readonly property bool _active: _notifBodySceneBlurAnchor._active && _radius > 0
            readonly property var _rect: SurfaceGeometry.farBodyCapRect(win._notifDescriptor.barSide, _notifBodySceneBlurAnchor, "right", _radius, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0
        }
        Region {
            id: _notifFarStartConnectorBlurAnchor

            readonly property real _radius: win._effectiveNotifFarStartCcr
            readonly property bool _active: _notifBodySceneBlurAnchor._active && _radius > 0
            readonly property var _rect: SurfaceGeometry.farConnectorRect(win._notifDescriptor.barSide, _notifBodySceneBlurAnchor, "left", _radius, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0

            Region {
                id: _notifFarStartConnectorCutout

                readonly property bool _active: _notifFarStartConnectorBlurAnchor.width > 0 && _notifFarStartConnectorBlurAnchor.height > 0
                readonly property string _barSide: win._farConnectorBarSide(win._notifDescriptor.barSide, "left")
                readonly property string _placement: win._farConnectorPlacement(win._notifDescriptor.barSide, "left")
                readonly property string _arcCorner: ConnectorGeometry.arcCorner(_barSide, _placement)
                readonly property real _radius: win._effectiveNotifFarStartCcr

                intersection: Intersection.Subtract
                radius: win._effectiveNotifFarStartCcr
                x: _active ? Math.round(win._connectorCutoutX(_notifFarStartConnectorBlurAnchor.x, _notifFarStartConnectorBlurAnchor.width, _arcCorner, _radius)) : 0
                y: _active ? Math.round(win._connectorCutoutY(_notifFarStartConnectorBlurAnchor.y, _notifFarStartConnectorBlurAnchor.height, _arcCorner, _radius)) : 0
                width: _active ? Math.round(_radius * 2) : 0
                height: _active ? Math.round(_radius * 2) : 0
            }
        }
        Region {
            id: _notifFarEndConnectorBlurAnchor

            readonly property real _radius: win._effectiveNotifFarEndCcr
            readonly property bool _active: _notifBodySceneBlurAnchor._active && _radius > 0
            readonly property var _rect: SurfaceGeometry.farConnectorRect(win._notifDescriptor.barSide, _notifBodySceneBlurAnchor, "right", _radius, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0

            Region {
                id: _notifFarEndConnectorCutout

                readonly property bool _active: _notifFarEndConnectorBlurAnchor.width > 0 && _notifFarEndConnectorBlurAnchor.height > 0
                readonly property string _barSide: win._farConnectorBarSide(win._notifDescriptor.barSide, "right")
                readonly property string _placement: win._farConnectorPlacement(win._notifDescriptor.barSide, "right")
                readonly property string _arcCorner: ConnectorGeometry.arcCorner(_barSide, _placement)
                readonly property real _radius: win._effectiveNotifFarEndCcr

                intersection: Intersection.Subtract
                radius: win._effectiveNotifFarEndCcr
                x: _active ? Math.round(win._connectorCutoutX(_notifFarEndConnectorBlurAnchor.x, _notifFarEndConnectorBlurAnchor.width, _arcCorner, _radius)) : 0
                y: _active ? Math.round(win._connectorCutoutY(_notifFarEndConnectorBlurAnchor.y, _notifFarEndConnectorBlurAnchor.height, _arcCorner, _radius)) : 0
                width: _active ? Math.round(_radius * 2) : 0
                height: _active ? Math.round(_radius * 2) : 0
            }
        }

        Region {
            id: _modalBodyBlurAnchor

            readonly property bool _active: win._blurSurfacesActive && win._modalDescriptor.visible && win._modalBodyGeometry.width > 0 && win._modalBodyGeometry.height > 0

            radius: win._surfaceRadius
            x: _active ? Math.round(win._modalBodyGeometry.x) : 0
            y: _active ? Math.round(win._modalBodyGeometry.y) : 0
            width: _active ? Math.round(win._modalBodyGeometry.width) : 0
            height: _active ? Math.round(win._modalBodyGeometry.height) : 0
        }
        Region {
            id: _modalBodyBlurCap

            readonly property string _side: win._modalDescriptor.barSide
            readonly property real _capThickness: win._modalBlurCapThickness()
            readonly property bool _active: _modalBodyBlurAnchor._active && _capThickness > 0 && _modalBodyBlurAnchor.width > 0 && _modalBodyBlurAnchor.height > 0
            readonly property int _capWidth: (_side === "left" || _side === "right") ? Math.round(Math.min(_capThickness, _modalBodyBlurAnchor.width)) : _modalBodyBlurAnchor.width
            readonly property int _capHeight: (_side === "top" || _side === "bottom") ? Math.round(Math.min(_capThickness, _modalBodyBlurAnchor.height)) : _modalBodyBlurAnchor.height

            x: !_active ? 0 : (_side === "right" ? _modalBodyBlurAnchor.x + _modalBodyBlurAnchor.width - _capWidth : _modalBodyBlurAnchor.x)
            y: !_active ? 0 : (_side === "bottom" ? _modalBodyBlurAnchor.y + _modalBodyBlurAnchor.height - _capHeight : _modalBodyBlurAnchor.y)
            width: _active ? _capWidth : 0
            height: _active ? _capHeight : 0
        }
        Region {
            id: _modalLeftConnectorBlurAnchor

            readonly property real _radius: win._modalConnectorRadiusLeft
            readonly property bool _active: _modalBodyBlurAnchor._active && _radius > 0
            readonly property var _rect: SurfaceGeometry.connectorRect(win._modalDescriptor.barSide, win._modalBodyGeometry, "left", 0, _radius, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0

            Region {
                id: _modalLeftConnectorCutout

                readonly property bool _active: _modalLeftConnectorBlurAnchor.width > 0 && _modalLeftConnectorBlurAnchor.height > 0
                readonly property string _arcCorner: ConnectorGeometry.arcCorner(win._modalDescriptor.barSide, "left")
                readonly property real _radius: win._modalConnectorRadiusLeft

                intersection: Intersection.Subtract
                radius: win._modalConnectorRadiusLeft
                x: _active ? Math.round(win._connectorCutoutX(_modalLeftConnectorBlurAnchor.x, _modalLeftConnectorBlurAnchor.width, _arcCorner, _radius)) : 0
                y: _active ? Math.round(win._connectorCutoutY(_modalLeftConnectorBlurAnchor.y, _modalLeftConnectorBlurAnchor.height, _arcCorner, _radius)) : 0
                width: _active ? Math.round(_radius * 2) : 0
                height: _active ? Math.round(_radius * 2) : 0
            }
        }
        Region {
            id: _modalRightConnectorBlurAnchor

            readonly property real _radius: win._modalConnectorRadiusRight
            readonly property bool _active: _modalBodyBlurAnchor._active && _radius > 0
            readonly property var _rect: SurfaceGeometry.connectorRect(win._modalDescriptor.barSide, win._modalBodyGeometry, "right", 0, _radius, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0

            Region {
                id: _modalRightConnectorCutout

                readonly property bool _active: _modalRightConnectorBlurAnchor.width > 0 && _modalRightConnectorBlurAnchor.height > 0
                readonly property string _arcCorner: ConnectorGeometry.arcCorner(win._modalDescriptor.barSide, "right")
                readonly property real _radius: win._modalConnectorRadiusRight

                intersection: Intersection.Subtract
                radius: win._modalConnectorRadiusRight
                x: _active ? Math.round(win._connectorCutoutX(_modalRightConnectorBlurAnchor.x, _modalRightConnectorBlurAnchor.width, _arcCorner, _radius)) : 0
                y: _active ? Math.round(win._connectorCutoutY(_modalRightConnectorBlurAnchor.y, _modalRightConnectorBlurAnchor.height, _arcCorner, _radius)) : 0
                width: _active ? Math.round(_radius * 2) : 0
                height: _active ? Math.round(_radius * 2) : 0
            }
        }
        Region {
            id: _modalFarStartBodyBlurCap

            readonly property real _radius: win._effectiveModalFarStartCcr
            readonly property bool _active: _modalBodyBlurAnchor._active && _radius > 0
            readonly property var _rect: SurfaceGeometry.farBodyCapRect(win._modalDescriptor.barSide, win._modalBodyGeometry, "left", _radius, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0
        }
        Region {
            id: _modalFarEndBodyBlurCap

            readonly property real _radius: win._effectiveModalFarEndCcr
            readonly property bool _active: _modalBodyBlurAnchor._active && _radius > 0
            readonly property var _rect: SurfaceGeometry.farBodyCapRect(win._modalDescriptor.barSide, win._modalBodyGeometry, "right", _radius, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0
        }
        Region {
            id: _modalFarStartConnectorBlurAnchor

            readonly property real _radius: win._effectiveModalFarStartCcr
            readonly property bool _active: _modalBodyBlurAnchor._active && _radius > 0
            readonly property var _rect: SurfaceGeometry.farConnectorRect(win._modalDescriptor.barSide, win._modalBodyGeometry, "left", _radius, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0

            Region {
                id: _modalFarStartConnectorCutout

                readonly property bool _active: _modalFarStartConnectorBlurAnchor.width > 0 && _modalFarStartConnectorBlurAnchor.height > 0
                readonly property string _barSide: win._farConnectorBarSide(win._modalDescriptor.barSide, "left")
                readonly property string _placement: win._farConnectorPlacement(win._modalDescriptor.barSide, "left")
                readonly property string _arcCorner: ConnectorGeometry.arcCorner(_barSide, _placement)
                readonly property real _radius: win._effectiveModalFarStartCcr

                intersection: Intersection.Subtract
                radius: win._effectiveModalFarStartCcr
                x: _active ? Math.round(win._connectorCutoutX(_modalFarStartConnectorBlurAnchor.x, _modalFarStartConnectorBlurAnchor.width, _arcCorner, _radius)) : 0
                y: _active ? Math.round(win._connectorCutoutY(_modalFarStartConnectorBlurAnchor.y, _modalFarStartConnectorBlurAnchor.height, _arcCorner, _radius)) : 0
                width: _active ? Math.round(_radius * 2) : 0
                height: _active ? Math.round(_radius * 2) : 0
            }
        }
        Region {
            id: _modalFarEndConnectorBlurAnchor

            readonly property real _radius: win._effectiveModalFarEndCcr
            readonly property bool _active: _modalBodyBlurAnchor._active && _radius > 0
            readonly property var _rect: SurfaceGeometry.farConnectorRect(win._modalDescriptor.barSide, win._modalBodyGeometry, "right", _radius, win._dpr)

            x: _active ? Math.round(_rect.x) : 0
            y: _active ? Math.round(_rect.y) : 0
            width: _active ? Math.round(_rect.width) : 0
            height: _active ? Math.round(_rect.height) : 0

            Region {
                id: _modalFarEndConnectorCutout

                readonly property bool _active: _modalFarEndConnectorBlurAnchor.width > 0 && _modalFarEndConnectorBlurAnchor.height > 0
                readonly property string _barSide: win._farConnectorBarSide(win._modalDescriptor.barSide, "right")
                readonly property string _placement: win._farConnectorPlacement(win._modalDescriptor.barSide, "right")
                readonly property string _arcCorner: ConnectorGeometry.arcCorner(_barSide, _placement)
                readonly property real _radius: win._effectiveModalFarEndCcr

                intersection: Intersection.Subtract
                radius: win._effectiveModalFarEndCcr
                x: _active ? Math.round(win._connectorCutoutX(_modalFarEndConnectorBlurAnchor.x, _modalFarEndConnectorBlurAnchor.width, _arcCorner, _radius)) : 0
                y: _active ? Math.round(win._connectorCutoutY(_modalFarEndConnectorBlurAnchor.y, _modalFarEndConnectorBlurAnchor.height, _arcCorner, _radius)) : 0
                width: _active ? Math.round(_radius * 2) : 0
                height: _active ? Math.round(_radius * 2) : 0
            }
        }
    }

    // Notif body scene rect, accounting for start/end/side underlaps per bar orientation.
    function _notifBodyScene() {
        const isHoriz = SurfaceGeometry.isHorizontal(win._notifDescriptor.barSide);
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
            "x": _notifBodyBlurAnchor.x - (win._notifDescriptor.barSide === "left" ? side : 0),
            "y": _notifBodyBlurAnchor.y - start,
            "width": _notifBodyBlurAnchor.width + side,
            "height": _notifBodyBlurAnchor.height + start + end
        };
    }

    function _modalBlurCapThickness() {
        const extent = win._modalArcExtent;
        return Math.max(0, Math.min(win._effectiveModalCcr, extent - win._surfaceRadius));
    }

    function _popoutBlurCapThickness() {
        const extent = win._popoutArcExtent;
        return Math.max(0, Math.min(win._effectivePopoutMaxCcr, extent - win._surfaceRadius));
    }

    // Active connected surfaces fed to the unified silhouette path. Raw animated
    // body rects (no seam/fill overlap); the builder anchors each to the cutout
    // edge. Connector radii use the same per-surface helpers as the blur regions.
    function _unifiedSurfaces() {
        const arr = [];
        const p = win._popoutBodyGeometry;
        if (win._popoutDescriptor.visible && win._popoutDescriptor.screenName === win._screenName && p.width > 0 && p.height > 0)
            arr.push({
                "side": win._popoutDescriptor.barSide,
                "body": {"x": p.x, "y": p.y, "width": p.width, "height": p.height},
                "radii": {
                    "farCr": win._effectivePopoutFarCcr,
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
                    "farCr": win._effectiveModalFarCcr,
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
                    "farCr": win._effectiveNotifFarCcr,
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
                    "farCr": win._dockConnectorRadiusValue,
                    "startCr": win._dockConnectorRadiusValue,
                    "endCr": win._dockConnectorRadiusValue,
                    "farStartCr": 0,
                    "farEndCr": 0,
                    "surfaceRadius": win._dockBodyBlurRadiusValue
                }
            });
        return arr;
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

    function _scheduleSurfaceRefresh() {
        surfaceRefreshAction.restart();
    }

    function _runSurfaceRefresh() {
        if (!win.visible)
            return;
        _requestContentUpdate();
        _republishFrameBlur();
    }

    DeferredAction {
        id: surfaceRefreshAction
        onTriggered: win._runSurfaceRefresh()
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
            win._scheduleSurfaceRefresh();
        } else {
            surfaceRefreshAction.cancel();
            _teardownBlur();
        }
    }

    on_SurfaceRevisionChanged: win._scheduleSurfaceRefresh()

    onResourcesLost: {
        blurRebuildAction.cancel();
        surfaceRefreshAction.cancel();
        win._teardownBlur();
    }

    onWindowConnected: {
        win._scheduleSurfaceRefresh();
        win._scheduleBlurRebuild();
    }

    Component.onCompleted: {
        win._scheduleBlurRebuild();
        win._scheduleSurfaceRefresh();
    }
    Component.onDestruction: {
        blurRebuildAction.cancel();
        surfaceRefreshAction.cancel();
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

    // The entire connected silhouette (frame ring + every active chrome) as one
    // SDF in a fragment shader. Analytic fwidth AA → crisp at any scale, no FBO;
    // the smooth-min radius is the connector. The elevation shadow is derived
    // from the same distance field, so elevation-on needs no grouping layer.
    ShaderEffect {
        anchors.fill: parent
        visible: win._connectedActive
        fragmentShader: Qt.resolvedUrl("../../Shaders/qsb/connected_arc.frag.qsb")

        readonly property var _level: Theme.elevationLevel2
        readonly property color _shadowTint: Theme.elevationShadowColor(_level)
        readonly property var _ambient: Theme.elevationAmbient(_level)
        property real widthPx: width
        property real heightPx: height
        property real cutoutRadius: win.cutoutRadius
        property vector4d cutout: Qt.vector4d(win.cutoutLeftInset, win.cutoutTopInset, win.width - win.cutoutRightInset, win.height - win.cutoutBottomInset)
        property vector4d surfaceColor: Qt.vector4d(win._surfaceColor.r, win._surfaceColor.g, win._surfaceColor.b, win._surfaceColor.a)
        property vector4d shadowColor: Qt.vector4d(_shadowTint.r, _shadowTint.g, _shadowTint.b, win._elevationShadow ? _shadowTint.a : 0)
        property vector4d shadowParam: Qt.vector4d(Math.max(0, _level.blurPx), Math.max(0, _level.spreadPx), Theme.elevationOffsetXFor(_level, Theme.elevationLightDirection, 4), Theme.elevationOffsetYFor(_level, Theme.elevationLightDirection, 4))
        property vector4d ambientParam: Qt.vector4d(_ambient.blurPx, _ambient.spreadPx, win._elevationShadow ? _ambient.alpha : 0, 0)
        property vector4d chromeRect0: win._sdfSlots[0].rect
        property vector4d chromeCorner0: win._sdfSlots[0].corner
        property vector4d chromeK0: win._sdfSlots[0].k
        property vector4d chromeParam0: win._sdfSlots[0].param
        property vector4d chromeRect1: win._sdfSlots[1].rect
        property vector4d chromeCorner1: win._sdfSlots[1].corner
        property vector4d chromeK1: win._sdfSlots[1].k
        property vector4d chromeParam1: win._sdfSlots[1].param
        property vector4d chromeRect2: win._sdfSlots[2].rect
        property vector4d chromeCorner2: win._sdfSlots[2].corner
        property vector4d chromeK2: win._sdfSlots[2].k
        property vector4d chromeParam2: win._sdfSlots[2].param
        property vector4d chromeRect3: win._sdfSlots[3].rect
        property vector4d chromeCorner3: win._sdfSlots[3].corner
        property vector4d chromeK3: win._sdfSlots[3].k
        property vector4d chromeParam3: win._sdfSlots[3].param
    }
}
