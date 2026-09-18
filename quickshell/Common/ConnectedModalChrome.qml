pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    required property var modalHandle
    required property string claimPrefix
    property string surfaceKind: "modal"
    property string screenName: ""
    property bool enabled: false
    property bool active: false
    property bool presented: false
    property bool dockBlocked: false
    property string dockSide: ""

    property alias claimId: lease.claimId
    property alias claimedScreenName: lease.claimedScreenName

    signal recoveryRequested

    visible: false

    ConnectedSurfaceLease {
        id: lease
        claimPrefix: root.claimPrefix
        slot: ConnectedModeState.surfaceSlot(root.surfaceKind)
        requirePresentedState: true
        retractsDock: true
        screenName: root.screenName
        enabled: root.enabled
        active: root.active
        presented: root.presented
        dockBlocked: root.dockBlocked
        dockSide: root.dockSide
        isCurrentOwner: name => ModalManager.isCurrentModal(modalHandle, name)
        onRecoveryRequested: root.recoveryRequested()
    }

    function publish(state) {
        return lease.publish(Object.assign({}, state, {
            "kind": root.surfaceKind,
            "screenName": root.screenName,
            "presented": root.presented,
            "dockRetractSide": root.dockBlocked ? root.dockSide : ""
        }), false);
    }

    function updateAnim(animX, animY) {
        return lease.updateAnim(animX, animY);
    }

    function updateBody(bodyX, bodyY, bodyW, bodyH) {
        return lease.updateBody(bodyX, bodyY, bodyW, bodyH);
    }

    function release() {
        return lease.release();
    }

    Connections {
        target: ModalManager
        function onModalChanged() {
            lease.requestRecovery();
        }
    }

    Connections {
        target: ConnectedModeState
        function onSurfaceDescriptorsChanged() {
            lease.checkRecovery();
        }
    }
}
