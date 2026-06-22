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

    function _isCurrentModal(name) {
        return !!name && ModalManager.isCurrentModal(modalHandle, name);
    }

    ConnectedSurfaceLease {
        id: lease
        claimPrefix: root.claimPrefix
        screenName: root.screenName
        enabled: root.enabled
        active: root.active
        presented: root.presented
        dockBlocked: root.dockBlocked
        dockSide: root.dockSide
        isCurrentOwner: function(name) {
            return root._isCurrentModal(name);
        }
        hasOwner: function(name, ownerId) {
            return ConnectedModeState.hasModalOwner(name, ownerId);
        }
        statePresent: function(name, ownerId) {
            return ConnectedModeState.hasModalOwner(name, ownerId) && ConnectedModeState.hasSurfaceDescriptor(name, root.surfaceKind, ownerId);
        }
        claimState: function(name, state, ownerId) {
            return ConnectedModeState.claimModalState(name, state, ownerId);
        }
        ensureState: function(name, state, ownerId) {
            return ConnectedModeState.ensureModalState(name, state, ownerId);
        }
        releaseState: function(name, ownerId) {
            return ConnectedModeState.clearModalState(name, ownerId);
        }
        updateAnimationState: function(name, ownerId, animX, animY) {
            return ConnectedModeState.setModalAnim(name, animX, animY, ownerId);
        }
        updateBodyState: function(name, ownerId, bodyX, bodyY, bodyW, bodyH) {
            return ConnectedModeState.setModalBody(name, bodyX, bodyY, bodyW, bodyH, ownerId);
        }
        requestDockRetract: function(ownerId, name, side) {
            return ConnectedModeState.requestDockRetract(ownerId, name, side);
        }
        releaseDockRetract: function(ownerId) {
            return ConnectedModeState.releaseDockRetract(ownerId);
        }
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
        function onModalOwnersChanged() {
            lease.checkOwnershipRecovery();
        }
        function onModalStatesChanged() {
            lease.checkStateRecovery();
        }
        function onSurfaceDescriptorsChanged() {
            lease.checkStateRecovery();
        }
    }
}
