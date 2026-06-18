pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    required property string claimPrefix
    required property var isCurrentOwner
    required property var hasOwner
    required property var claimState
    required property var ensureState
    required property var releaseState

    property var statePresent: null
    property var updateAnimationState: null
    property var updateBodyState: null
    property var requestDockRetract: null
    property var releaseDockRetract: null

    property string screenName: ""
    property bool enabled: false
    property bool active: false
    property bool presented: false
    property bool dockBlocked: false
    property string dockSide: ""
    property bool renewTokenOnRecovery: true

    property string claimId: ""
    property string claimedScreenName: ""
    property int _claimSerial: 0

    signal recoveryRequested

    visible: false

    function _nextClaimId() {
        _claimSerial += 1;
        return claimPrefix + ":" + (new Date()).getTime() + ":" + _claimSerial + ":" + Math.floor(Math.random() * 1000000);
    }

    function _isCurrent(name) {
        return !!name && !!isCurrentOwner && !!isCurrentOwner(name);
    }

    function _hasOwner(name, ownerId) {
        return !!name && !!ownerId && !!hasOwner && !!hasOwner(name, ownerId);
    }

    function _hasState(name, ownerId) {
        return !statePresent || !!statePresent(name, ownerId);
    }

    function _shouldRecover() {
        return active && enabled && _isCurrent(screenName);
    }

    function requestRecovery() {
        if (!_shouldRecover())
            return false;
        recoveryRequested();
        return true;
    }

    function checkOwnershipRecovery() {
        if (!_shouldRecover())
            return false;
        if (claimedScreenName === screenName && _hasOwner(screenName, claimId))
            return false;
        recoveryRequested();
        return true;
    }

    function checkStateRecovery() {
        if (!_shouldRecover())
            return false;
        if (claimedScreenName === screenName && _hasOwner(screenName, claimId) && _hasState(screenName, claimId))
            return false;
        recoveryRequested();
        return true;
    }

    function checkRecovery() {
        return checkStateRecovery();
    }

    function beginClaim() {
        if (claimId && releaseDockRetract)
            releaseDockRetract(claimId);
        claimId = _nextClaimId();
        claimedScreenName = "";
        return claimId;
    }

    function _syncDockRetract() {
        if (!claimId)
            return;
        if (dockBlocked && presented && dockSide && requestDockRetract)
            requestDockRetract(claimId, screenName, dockSide);
        else if (releaseDockRetract)
            releaseDockRetract(claimId);
    }

    function publish(state, forceClaim) {
        if (!enabled || !screenName || !state) {
            release();
            return false;
        }

        if (claimedScreenName && claimedScreenName !== screenName)
            release();

        const current = _isCurrent(screenName);
        let claiming = !!forceClaim || !claimId;
        if (claiming && !current)
            return false;
        if (!claimId)
            beginClaim();

        let published = claiming ? claimState(screenName, state, claimId) : ensureState(screenName, state, claimId);
        if (!published && !claiming && current) {
            if (renewTokenOnRecovery) {
                beginClaim();
            } else if (releaseDockRetract) {
                releaseDockRetract(claimId);
            }
            published = claimState(screenName, state, claimId);
        }
        if (!published)
            return false;

        claimedScreenName = screenName;
        _syncDockRetract();
        return true;
    }

    function updateAnim(animX, animY) {
        if (!enabled || !claimId || !claimedScreenName || !updateAnimationState)
            return false;
        if (!_hasOwner(claimedScreenName, claimId)) {
            requestRecovery();
            return false;
        }
        return updateAnimationState(claimedScreenName, claimId, animX, animY);
    }

    function updateBody(bodyX, bodyY, bodyW, bodyH) {
        if (!enabled || !claimId || !claimedScreenName || !updateBodyState)
            return false;
        if (!_hasOwner(claimedScreenName, claimId)) {
            requestRecovery();
            return false;
        }
        return updateBodyState(claimedScreenName, claimId, bodyX, bodyY, bodyW, bodyH);
    }

    function release() {
        if (!claimId) {
            claimedScreenName = "";
            return false;
        }

        const releasedClaimId = claimId;
        const releasedScreenName = claimedScreenName;
        claimId = "";
        claimedScreenName = "";

        if (releaseDockRetract)
            releaseDockRetract(releasedClaimId);
        if (releasedScreenName)
            return !!releaseState(releasedScreenName, releasedClaimId);
        return false;
    }

    Component.onDestruction: release()
}
