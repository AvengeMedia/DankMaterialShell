pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    required property var modalHandle
    required property string claimPrefix
    property string screenName: ""
    property bool enabled: false
    property bool active: false
    property bool presented: false
    property bool dockBlocked: false
    property string dockSide: ""

    property string claimId: ""
    property string claimedScreenName: ""

    signal recoveryRequested

    visible: false

    function _nextClaimId() {
        return claimPrefix + ":" + (new Date()).getTime() + ":" + Math.floor(Math.random() * 1000);
    }

    function _isCurrentModal(name) {
        return !!name && ModalManager.isCurrentModal(modalHandle, name);
    }

    function _shouldRecover() {
        return active && enabled && _isCurrentModal(screenName);
    }

    function _requestRecovery() {
        if (_shouldRecover())
            recoveryRequested();
    }

    function publish(state) {
        if (!enabled || !screenName || !state) {
            release();
            return false;
        }
        if (claimedScreenName && claimedScreenName !== screenName)
            release();

        const isCurrent = _isCurrentModal(screenName);
        let isClaim = !claimId;
        if (isClaim && !isCurrent)
            return false;
        if (isClaim)
            claimId = _nextClaimId();

        let published = isClaim ? ConnectedModeState.claimModalState(screenName, state, claimId) : ConnectedModeState.ensureModalState(screenName, state, claimId);
        if (!published && !isClaim && isCurrent) {
            ConnectedModeState.releaseDockRetract(claimId);
            claimId = _nextClaimId();
            published = ConnectedModeState.claimModalState(screenName, state, claimId);
        }
        if (!published)
            return false;

        claimedScreenName = screenName;
        if (dockBlocked && presented)
            ConnectedModeState.requestDockRetract(claimId, screenName, dockSide);
        else
            ConnectedModeState.releaseDockRetract(claimId);
        return true;
    }

    function updateAnim(animX, animY) {
        if (!enabled || !claimId || !claimedScreenName)
            return false;
        if (!ConnectedModeState.hasModalOwner(claimedScreenName, claimId)) {
            _requestRecovery();
            return false;
        }
        return ConnectedModeState.setModalAnim(claimedScreenName, animX, animY, claimId);
    }

    function updateBody(bodyX, bodyY, bodyW, bodyH) {
        if (!enabled || !claimId || !claimedScreenName)
            return false;
        if (!ConnectedModeState.hasModalOwner(claimedScreenName, claimId)) {
            _requestRecovery();
            return false;
        }
        return ConnectedModeState.setModalBody(claimedScreenName, bodyX, bodyY, bodyW, bodyH, claimId);
    }

    function release() {
        if (!claimId)
            return;
        ConnectedModeState.releaseDockRetract(claimId);
        const releasedClaimId = claimId;
        const releasedScreenName = claimedScreenName;
        claimId = "";
        claimedScreenName = "";
        if (releasedScreenName)
            ConnectedModeState.clearModalState(releasedScreenName, releasedClaimId);
    }

    Component.onDestruction: release()

    Connections {
        target: ModalManager
        function onModalChanged() {
            root._requestRecovery();
        }
    }

    Connections {
        target: ConnectedModeState
        function onModalOwnersChanged() {
            if (!ConnectedModeState.hasModalOwner(root.screenName, root.claimId))
                root._requestRecovery();
        }
        function onModalStatesChanged() {
            if (!ConnectedModeState.modalStates[root.screenName])
                root._requestRecovery();
        }
    }
}
