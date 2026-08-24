pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

Variants {
    id: dockVariants
    // Connected frame mode renders the dock inside the frame surface; skip the standalone window there.
    model: (SettingsData.showDock || (CompositorService.isNiri && SettingsData.dockOpenOnOverview)) ? SettingsData.getFilteredScreens("dock").filter(screen => !CompositorService.frameHostsDockForScreen(screen)) : []

    property var contextMenu
    property var trashContextMenu

    delegate: PanelWindow {
        id: dock

        property var modelData: item

        screen: modelData
        color: "transparent"

        WlrLayershell.namespace: "dms:dock"
        WlrLayershell.layer: body.usesOverlayLayer ? WlrLayer.Overlay : WlrLayer.Top

        anchors {
            top: !body.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Top) : true
            bottom: !body.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom) : true
            left: !body.isVertical ? true : (SettingsData.dockPosition === SettingsData.Position.Left)
            right: !body.isVertical ? true : (SettingsData.dockPosition === SettingsData.Position.Right)
        }

        visible: {
            if (CompositorService.isNiri && NiriService.inOverview) {
                return SettingsData.dockOpenOnOverview;
            }
            return SettingsData.showDock;
        }

        implicitWidth: body.surfaceImplicitWidth
        implicitHeight: body.surfaceImplicitHeight
        exclusiveZone: body.surfaceExclusiveZone

        Component.onCompleted: SurfaceRecovery.track(dock)
        Component.onDestruction: SurfaceRecovery.untrack(dock)

        WindowBlur {
            targetWindow: dock
            blurEnabled: body.effectiveBlurEnabled && !body.usesConnectedFrameChrome
            blurX: body.blurX
            blurY: body.blurY
            blurWidth: body.blurWidth
            blurHeight: body.blurHeight
            blurRadius: body.blurRadius
        }

        mask: Region {
            item: body.inputMaskItem
        }

        DockBody {
            id: body
            anchors.fill: parent
            hostWindow: dock
            modelData: dock.modelData
            contextMenu: dockVariants.contextMenu
            trashContextMenu: dockVariants.trashContextMenu
        }

        PanelWindow {
            id: dockExclusion

            screen: dock.screen || dock.modelData
            visible: body.frameDockExclusionActive && body.shouldReserveDockSpace
            color: "transparent"
            mask: Region {}
            implicitWidth: body.isVertical ? body.dockReserveZone : 1
            implicitHeight: body.isVertical ? 1 : body.dockReserveZone
            exclusiveZone: visible ? body.dockReserveZone : -1

            WlrLayershell.namespace: "dms:dock-exclusion"
            WlrLayershell.layer: WlrLayer.Top

            Component.onCompleted: SurfaceRecovery.track(dockExclusion)
            Component.onDestruction: SurfaceRecovery.untrack(dockExclusion)

            anchors {
                top: !body.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Top) : true
                bottom: !body.isVertical ? (SettingsData.dockPosition === SettingsData.Position.Bottom) : true
                left: !body.isVertical ? true : (SettingsData.dockPosition === SettingsData.Position.Left)
                right: !body.isVertical ? true : (SettingsData.dockPosition === SettingsData.Position.Right)
            }
        }
    }
}
