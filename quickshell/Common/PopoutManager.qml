pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property var currentPopoutsByScreen: ({})
    property var currentPopoutTriggers: ({})

    signal popoutOpening
    signal popoutChanged

    function _closePopout(popout) {
        switch (true) {
        case popout.dashVisible !== undefined:
            popout.dashVisible = false;
            return;
        case popout.notificationHistoryVisible !== undefined:
            popout.notificationHistoryVisible = false;
            return;
        default:
            popout.close();
        }
    }

    function _isStale(popout) {
        try {
            return !popout || !("shouldBeVisible" in popout);
        } catch (e) {
            return true;
        }
    }

    function showPopout(popout) {
        if (!popout || !popout.screen)
            return;
        popoutOpening();

        const screenName = popout.screen.name;

        for (const otherScreenName in currentPopoutsByScreen) {
            const otherPopout = currentPopoutsByScreen[otherScreenName];
            if (!otherPopout || otherPopout === popout)
                continue;
            if (_isStale(otherPopout)) {
                currentPopoutsByScreen[otherScreenName] = null;
                continue;
            }
            _closePopout(otherPopout);
        }

        currentPopoutsByScreen[screenName] = popout;
        popoutChanged();
        ModalManager.closeAllModalsExcept(null);
    }

    function hidePopout(popout) {
        if (!popout || !popout.screen)
            return;
        const screenName = popout.screen.name;
        if (currentPopoutsByScreen[screenName] === popout) {
            currentPopoutsByScreen[screenName] = null;
            currentPopoutTriggers[screenName] = null;
            popoutChanged();
        }
    }

    function closeAllPopouts() {
        for (const screenName in currentPopoutsByScreen) {
            const popout = currentPopoutsByScreen[screenName];
            if (!popout || _isStale(popout))
                continue;
            _closePopout(popout);
        }
        currentPopoutsByScreen = {};
    }

    function getActivePopout(screen) {
        if (!screen)
            return null;
        return currentPopoutsByScreen[screen.name] || null;
    }

    function requestPopout(popout, tabIndex, triggerSource) {
        if (!popout || !popout.screen)
            return;
        const screenName = popout.screen.name;
        const currentPopout = currentPopoutsByScreen[screenName];
        const triggerId = triggerSource !== undefined ? triggerSource : tabIndex;

        const willOpen = !(currentPopout === popout && popout.shouldBeVisible && triggerId !== undefined && currentPopoutTriggers[screenName] === triggerId);
        if (willOpen) {
            popoutOpening();
        }

        let movedFromOtherScreen = false;
        for (const otherScreenName in currentPopoutsByScreen) {
            if (otherScreenName === screenName)
                continue;
            const otherPopout = currentPopoutsByScreen[otherScreenName];
            if (!otherPopout)
                continue;

            if (_isStale(otherPopout)) {
                currentPopoutsByScreen[otherScreenName] = null;
                currentPopoutTriggers[otherScreenName] = null;
                continue;
            }

            if (otherPopout === popout) {
                movedFromOtherScreen = true;
                currentPopoutsByScreen[otherScreenName] = null;
                currentPopoutTriggers[otherScreenName] = null;
                continue;
            }

            _closePopout(otherPopout);
        }

        if (currentPopout && currentPopout !== popout) {
            if (_isStale(currentPopout)) {
                currentPopoutsByScreen[screenName] = null;
                currentPopoutTriggers[screenName] = null;
            } else {
                _closePopout(currentPopout);
            }
        }

        if (currentPopout === popout && popout.shouldBeVisible && !movedFromOtherScreen) {
            if (triggerId !== undefined && currentPopoutTriggers[screenName] === triggerId) {
                _closePopout(popout);
                return;
            }

            if (triggerId === undefined) {
                _closePopout(popout);
                return;
            }

            if (tabIndex !== undefined && popout.currentTabIndex !== undefined) {
                popout.currentTabIndex = tabIndex;
            }
            if (popout.updateSurfacePosition)
                popout.updateSurfacePosition();
            currentPopoutTriggers[screenName] = triggerId;
            return;
        }

        currentPopoutTriggers[screenName] = triggerId;
        currentPopoutsByScreen[screenName] = popout;
        popoutChanged();

        if (tabIndex !== undefined && popout.currentTabIndex !== undefined) {
            popout.currentTabIndex = tabIndex;
        }

        if (currentPopout !== popout) {
            ModalManager.closeAllModalsExcept(null);
        }

        if (movedFromOtherScreen) {
            popout.open();
        } else {
            if (popout.dashVisible !== undefined) {
                popout.dashVisible = true;
            } else if (popout.notificationHistoryVisible !== undefined) {
                popout.notificationHistoryVisible = true;
            } else {
                popout.open();
            }
        }
    }
}
