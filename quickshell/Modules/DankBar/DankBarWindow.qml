import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

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

    readonly property bool usesOverlayLayer: CompositorService.framePeerSurfacesUseOverlayForScreen(barWindow.screen) || (barConfig?.useOverlayLayer ?? false)
    readonly property var dBarLayer: LayerShell.fromEnv("DMS_DANKBAR_LAYER", barWindow.usesOverlayLayer ? WlrLayer.Overlay : WlrLayer.Top)

    screen: modelData
    color: "transparent"

    WlrLayershell.layer: dBarLayer
    WlrLayershell.namespace: "dms:bar"

    anchors.top: !isVertical ? (barPos === SettingsData.Position.Top) : true
    anchors.bottom: !isVertical ? (barPos === SettingsData.Position.Bottom) : true
    anchors.left: !isVertical ? true : (barPos === SettingsData.Position.Left)
    anchors.right: !isVertical ? true : (barPos === SettingsData.Position.Right)

    implicitHeight: body.surfaceImplicitHeight
    implicitWidth: body.surfaceImplicitWidth
    exclusiveZone: body.surfaceExclusiveZone

    BackgroundEffect.blurRegion: body.blurRegion

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

    mask: Region {
        item: body.clickThroughEnabled ? null : body.inputMaskItem

        Region {
            readonly property var r: body.clickThroughEnabled ? body.sectionRect(body._leftSection, false, body._revealProgress) : {
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
            readonly property var r: body.clickThroughEnabled ? body.sectionRect(body._centerSection, true, body._revealProgress) : {
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
            readonly property var r: body.clickThroughEnabled ? body.sectionRect(body._rightSection, false, body._revealProgress) : {
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
