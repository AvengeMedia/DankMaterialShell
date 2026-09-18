import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Frame
import qs.Modules.Dock
import qs.Modules.Notifications.Popup
import qs.Modals.Common
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property int modalReads: 0
    property int popoutReads: 0
    readonly property var modalDescriptor: ConnectedModeState.surfaceDescriptor("DP-1", "modal")
    readonly property var popoutDescriptor: ConnectedModeState.surfaceDescriptor("DP-1", "popout")
    onModalDescriptorChanged: modalReads++
    onPopoutDescriptorChanged: popoutReads++

    function check(condition, message) {
        if (!condition)
            throw new Error(message);
    }
    function near(a, b) {
        return Math.abs(a - b) < 0.5;
    }
    function compile(components) {
        for (const component of components)
            root.check(component.status === Component.Ready, "compile " + component.errorString());
    }

    Component {
        id: leaseComponent
        ConnectedSurfaceLease {
            claimPrefix: "fixture"
            slot: "modal"
            isCurrentOwner: () => true
        }
    }
    Component {
        id: chromeComponent
        ConnectedModalChrome {
            modalHandle: null
            claimPrefix: "fixture"
        }
    }
    Component {
        id: frameComponent
        FrameWindow {}
    }
    Component {
        id: dockComponent
        DockBody {}
    }
    Component {
        id: popoutComponent
        DankPopoutHost {}
    }
    Component {
        id: notificationComponent
        NotificationPopupManager {}
    }
    Component {
        id: modalComponent
        DankModalHost {}
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }

    Timer {
        interval: 300
        running: true
        onTriggered: root.run()
    }

    function run() {
        try {
            compile([leaseComponent, chromeComponent, frameComponent, dockComponent, popoutComponent, notificationComponent, modalComponent]);
            const S = ConnectedModeState;
            const body = {
                bodyX: 10,
                bodyY: 20,
                bodyW: 300,
                bodyH: 200,
                phase: "open",
                visible: true,
                presented: true,
                barSide: "top"
            };

            check(!S.claimSurface("", "popout", body, "a"), "claim needs a screen");
            check(!S.updateSurface("DP-1", "popout", body, "a"), "update before claim fails");
            check(S.claimSurface("DP-1", "popout", body, "a", true), "popout claim");
            check(S.surfaceRevisions["DP-1"] === 1, "claim bumps the screen revision");
            check(S.hasSurfaceOwner("DP-1", "popout", "a") && S.hasSurfaceDescriptor("DP-1", "popout", "a"), "popout owner and presence");
            check(popoutDescriptor.phase === "open" && near(popoutDescriptor.bodyRect.width, 300), "popout descriptor geometry");
            check(!S.updateSurface("DP-1", "popout", {
                bodyX: 99
            }, "stale"), "stale owner update rejected");
            check(!S.releaseSurface("DP-1", "popout", "stale"), "stale owner release rejected");

            check(S.claimSurface("DP-1", "modal", Object.assign({}, body, {
                kind: "launcher",
                barSide: "bottom"
            }), "m"), "modal claim");
            check(modalDescriptor.kind === "launcher" && modalDescriptor.barSide === "bottom", "modal keeps launcher kind");
            const modalReadsBefore = modalReads;
            const popoutReadsBefore = popoutReads;
            check(S.setSurfaceMotion("DP-1", "popout", "a", {
                animY: -40
            }), "popout anim motion");
            check(S.setSurfaceMotion("DP-1", "popout", "a", {
                bodyX: 15,
                bodyW: 320
            }), "popout body motion");
            check(near(popoutDescriptor.animationOffset.y, -40) && near(popoutDescriptor.bodyRect.x, 15) && near(popoutDescriptor.bodyRect.width, 320) && near(popoutDescriptor.bodyRect.height, 200), "motion overlays descriptor");
            check(popoutReads > popoutReadsBefore, "popout binding follows motion");
            check(modalReads === modalReadsBefore, "modal binding ignores popout motion");
            check(!S.setSurfaceMotion("DP-1", "popout", "stale", {
                animY: 0
            }), "stale owner motion rejected");

            const revision = popoutDescriptor.revision;
            check(S.updateSurface("DP-1", "popout", {
                omitEndConnector: true
            }, "a"), "partial update");
            check(near(popoutDescriptor.bodyRect.x, 15) && near(popoutDescriptor.animationOffset.y, -40) && popoutDescriptor.omitEndConnector, "partial update keeps motion values");
            check(popoutDescriptor.revision === revision + 1, "revision bumps once per change");
            check(S.updateSurface("DP-1", "popout", {
                omitEndConnector: true
            }, "a") && popoutDescriptor.revision === revision + 1, "unchanged update keeps revision");
            const screenRevision = S.surfaceRevisions["DP-1"];
            check(S.updateSurface("DP-1", "popout", {
                bodyY: 25
            }, "a") && S.surfaceRevisions["DP-1"] === screenRevision, "geometry update leaves the screen revision alone");
            check(S.updateSurface("DP-1", "popout", {
                phase: "closing",
                visible: false,
                presented: true
            }, "a") && S.surfaceRevisions["DP-1"] === screenRevision + 1 && popoutDescriptor.phase === "closing", "visibility change bumps the screen revision");

            check(S.claimSurface("DP-2", "popout", body, "b", true), "exclusive claim on another screen");
            check(!S.hasSurfaceOwner("DP-1", "popout", "a") && S.hasSurfaceOwner("DP-2", "popout", "b"), "exclusive claim releases other screens");
            check(popoutDescriptor.phase === "hidden", "released popout reads hidden");
            check(S.claimSurface("DP-2", "modal", body, "m2"), "second modal");
            check(S.hasSurfaceOwner("DP-1", "modal", "m"), "modal claims stay per screen");

            check(S.claimSurface("DP-1", S.surfaceSlot("dock", "d1"), body, "dock1") && S.claimSurface("DP-1", S.surfaceSlot("dock", "d2"), body, "dock2"), "two docks on one screen");
            check(S.setSurfaceMotion("DP-1", "dock:d1", "dock1", {
                animX: 8
            }), "dock slide");
            const docks = S.surfaceDescriptorsOfKind("DP-1", "dock");
            check(docks.length === 2 && docks.some(d => near(d.animationOffset.x, 8)) && docks.some(d => near(d.animationOffset.x, 0)), "dock descriptors carry their own motion");
            check(S.surfaceDescriptorsOfKind("DP-1", "modal").length === 1, "kind filter excludes other slots");

            check(S.releaseSurface("DP-1", "modal", "m") && !S.hasSurfaceOwner("DP-1", "modal", "m") && Object.keys(S.surfaceMotion).every(key => key !== "DP-1|modal"), "release drops descriptor and motion");
            check(!S.releaseSurface("DP-1", "modal", "m"), "double release is false");

            S.savePopoutMotion("b", "DP-2", "top", Qt.rect(1, 2, 3, 4), Qt.vector4d(0, 0, 0, 0));
            check(S.takePopoutMotion("DP-2", "bottom") === null && S.takePopoutMotion("DP-2", "top") === null, "handoff side mismatch consumes it");
            S.savePopoutMotion("b", "DP-2", "top", Qt.rect(1, 2, 3, 4), Qt.vector4d(0, 0, 0, 0));
            check(S.takePopoutMotion("DP-2", "top")?.rect.width === 3, "handoff taken by matching owner");
            S.savePopoutMotion("stale", "DP-2", "top", Qt.rect(1, 2, 3, 4), Qt.vector4d(0, 0, 0, 0));
            check(S.popoutMotionHandoff === null, "stale owner cannot save handoff");

            check(S.requestDockRetract("m2", "DP-2", "bottom") && S.dockRetractActiveForSide("DP-2", "bottom") && !S.dockRetractActiveForSide("DP-2", "top"), "dock retract request");
            check(S.releaseDockRetract("m2") && !S.dockRetractActiveForSide("DP-2", "bottom"), "dock retract release");

            S._pruneToLiveScreens();
            check(Object.keys(S.surfaceDescriptors).length === 0 && Object.keys(S.surfaceMotion).length === 0 && Object.keys(S.surfaceRevisions).length === 0, "prune drops surfaces on absent screens");

            console.log("FIXTURE_PASS");
        } catch (error) {
            console.error("FIXTURE_FAIL", error.message);
        }
        Qt.quit();
    }
}
