import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: barWindow
    readonly property var log: Log.scoped("DankBarWindow")

    required property var rootWindow
    required property var barConfig
    property var modelData: item

    property var leftWidgetsModel
    property var centerWidgetsModel
    property var rightWidgetsModel

    readonly property bool isVertical: body.isVertical
    readonly property int barPos: body.barPos
    readonly property bool barRevealed: body.barRevealed
    readonly property bool isIsland: body.isIsland
    readonly property var islandHost: body.islandHost
    readonly property var leadingSectionRect: body.leadingSectionRect
    readonly property var trailingSectionRect: body.trailingSectionRect

    function processScrollWheel(wheel) {
        body.processScrollWheel(wheel);
    }

    property alias controlCenterButtonRef: body.controlCenterButtonRef
    property alias clockButtonRef: body.clockButtonRef
    property alias systemUpdateButtonRef: body.systemUpdateButtonRef

    function triggerSystemUpdate() {
        body.triggerSystemUpdate();
    }
    function triggerControlCenter() {
        body.triggerControlCenter();
    }
    function triggerDashTab(tabId, position) {
        return body.triggerDashTab(tabId, position);
    }
    function positionDash(popout, position) {
        return body.positionDash(popout, position);
    }
    function triggerWallpaperBrowser() {
        body.triggerWallpaperBrowser();
    }
    function registerBlurWidget(item) {
        body.registerBlurWidget(item);
    }
    function unregisterBlurWidget(item) {
        body.unregisterBlurWidget(item);
    }
    function containsGlobalPoint(gx, gy, padding) {
        return body.containsGlobalPoint(gx, gy, padding);
    }

    readonly property bool usesOverlayLayer: CompositorService.framePeerSurfacesUseOverlayForScreen(barWindow.screen) || (isIsland ? LayerShell.envUsesOverlay("DMS_DANKISLAND_LAYER", SettingsData.islandSetting(barConfig, "islandUseOverlayLayer")) : (barConfig?.useOverlayLayer ?? false))
    readonly property var dBarLayer: LayerShell.fromEnv(isIsland ? "DMS_DANKISLAND_LAYER" : "DMS_DANKBAR_LAYER", barWindow.usesOverlayLayer ? WlrLayer.Overlay : WlrLayer.Top)

    screen: modelData
    readonly property var layoutInstance: ShellLayout.forConfig(screen, barConfig?.id)
    readonly property bool manualPlacement: ShellLayout.forScreen(screen)?.manualPlacement ?? false
    margins.top: manualPlacement ? layoutInstance?.margins.top ?? 0 : 0
    margins.bottom: manualPlacement ? layoutInstance?.margins.bottom ?? 0 : 0
    margins.left: manualPlacement ? layoutInstance?.margins.left ?? 0 : 0
    margins.right: manualPlacement ? layoutInstance?.margins.right ?? 0 : 0

    EdgeExclusion {
        screen: barWindow.screen
        edge: barWindow.layoutInstance?.edge ?? "top"
        exclusionSize: barWindow.layoutInstance?.exclusionSize ?? 0
    }

    color: "transparent"

    WlrLayershell.layer: dBarLayer
    WlrLayershell.namespace: isIsland ? "dms:dankisland" : "dms:bar"
    WlrLayershell.keyboardFocus: islandHost?.keyboardFocusPolicy ?? WlrKeyboardFocus.None

    DankFocusGrab {
        windows: [barWindow]
        wanted: barWindow.islandHost?.wantsFocusGrab ?? false
    }

    anchors.top: !isVertical ? (barPos === SettingsData.Position.Top) : true
    anchors.bottom: !isVertical ? (barPos === SettingsData.Position.Bottom) : true
    anchors.left: !isVertical ? true : (barPos === SettingsData.Position.Left)
    anchors.right: !isVertical ? true : (barPos === SettingsData.Position.Right)

    implicitHeight: body.surfaceImplicitHeight
    implicitWidth: body.surfaceImplicitWidth
    exclusiveZone: manualPlacement ? -1 : body.surfaceExclusiveZone

    BackgroundEffect.blurRegion: BlurService.enabled ? body.blurRegion : null

    Component.onCompleted: {
        KeyboardFocus.registerBarWindow(barWindow);
        SurfaceRecovery.track(barWindow);
    }
    Component.onDestruction: {
        KeyboardFocus.unregisterBarWindow(barWindow);
        SurfaceRecovery.untrack(barWindow);
    }

    IdleInhibitor {
        window: barWindow
        enabled: SessionService.idleInhibited || IdleService.externalInhibitActive
    }

    readonly property bool sectionMasked: body.clickThroughEnabled || (isIsland && !(islandHost?.inputSuspended ?? false))

    mask: Region {
        item: body.clickThroughEnabled || (isIsland && !body.islandBandInteractive) ? null : body.inputMaskItem

        Region {
            readonly property var r: barWindow.sectionMasked ? body.leadingSectionRect : {
                "x": 0,
                "y": 0,
                "w": 0,
                "h": 0
            }
            x: r.x
            y: r.y
            width: r.w
            height: r.h
        }

        Region {
            readonly property var r: barWindow.sectionMasked ? body.sectionRect(body._centerSection, true, body._revealProgress) : {
                "x": 0,
                "y": 0,
                "w": 0,
                "h": 0
            }
            x: r.x
            y: r.y
            width: r.w
            height: r.h
        }

        Region {
            readonly property var r: barWindow.sectionMasked ? body.trailingSectionRect : {
                "x": 0,
                "y": 0,
                "w": 0,
                "h": 0
            }
            x: r.x
            y: r.y
            width: r.w
            height: r.h
        }

        Region {
            readonly property bool active: body.clickThroughEnabled && !body.inputMaskItem.showing
            x: active ? body.inputMaskItem.x : 0
            y: active ? body.inputMaskItem.y : 0
            width: active ? body.inputMaskItem.width : 0
            height: active ? body.inputMaskItem.height : 0
        }

        Region {
            item: barWindow.islandHost && !barWindow.islandHost.inputSuspended ? barWindow.islandHost.inputMaskItem : null
        }

        Region {
            item: barWindow.islandHost && !barWindow.islandHost.inputSuspended ? barWindow.islandHost.fittsStripItem : null
        }
    }

    DankBarBody {
        id: body
        anchors.fill: parent
        hostWindow: barWindow
        modelData: barWindow.modelData
        rootWindow: barWindow.rootWindow
        barConfig: barWindow.barConfig
        leftWidgetsModel: barWindow.leftWidgetsModel
        centerWidgetsModel: barWindow.centerWidgetsModel
        rightWidgetsModel: barWindow.rightWidgetsModel
    }
}
