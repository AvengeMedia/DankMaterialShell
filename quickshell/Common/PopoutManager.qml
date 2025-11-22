pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property var currentPopoutsByScreen: ({})
    property var currentPopoutTriggers: ({})

    signal popoutOpening
    signal popoutChanged

    function showPopout(popout) {
        if (!popout || !popout.screen)
            return;
        popoutOpening();

        const screenName = popout.screen.name;

        for (const otherScreenName in currentPopoutsByScreen) {
            const otherPopout = currentPopoutsByScreen[otherScreenName];
            if (!otherPopout || otherPopout === popout)
                continue;
            if (otherPopout.dashVisible !== undefined) {
                otherPopout.dashVisible = false;
            } else if (otherPopout.notificationHistoryVisible !== undefined) {
                otherPopout.notificationHistoryVisible = false;
            } else {
                otherPopout.close();
            }
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
            if (!popout)
                continue;
            if (popout.dashVisible !== undefined) {
                popout.dashVisible = false;
            } else if (popout.notificationHistoryVisible !== undefined) {
                popout.notificationHistoryVisible = false;
            } else {
                popout.close();
            }
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

        let justClosedSamePopout = false;
        for (const otherScreenName in currentPopoutsByScreen) {
            if (otherScreenName === screenName)
                continue;
            const otherPopout = currentPopoutsByScreen[otherScreenName];
            if (!otherPopout)
                continue;
            if (otherPopout === popout) {
                justClosedSamePopout = true;
            }

            if (otherPopout.dashVisible !== undefined) {
                otherPopout.dashVisible = false;
            } else if (otherPopout.notificationHistoryVisible !== undefined) {
                otherPopout.notificationHistoryVisible = false;
            } else {
                otherPopout.close();
            }
        }

        if (currentPopout && currentPopout !== popout) {
            if (currentPopout.dashVisible !== undefined) {
                currentPopout.dashVisible = false;
            } else if (currentPopout.notificationHistoryVisible !== undefined) {
                currentPopout.notificationHistoryVisible = false;
            } else {
                currentPopout.close();
            }
        }

        if (currentPopout === popout && popout.shouldBeVisible) {
            if (triggerId !== undefined && currentPopoutTriggers[screenName] === triggerId) {
                if (popout.dashVisible !== undefined) {
                    popout.dashVisible = false;
                } else if (popout.notificationHistoryVisible !== undefined) {
                    popout.notificationHistoryVisible = false;
                } else {
                    popout.close();
                }
                return;
            }

            if (triggerId === undefined) {
                if (popout.dashVisible !== undefined) {
                    popout.dashVisible = false;
                } else if (popout.notificationHistoryVisible !== undefined) {
                    popout.notificationHistoryVisible = false;
                } else {
                    popout.close();
                }
                return;
            }

            if (tabIndex !== undefined && popout.currentTabIndex !== undefined) {
                popout.currentTabIndex = tabIndex;
            }
            currentPopoutTriggers[screenName] = triggerId;
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

        if (justClosedSamePopout) {
            Qt.callLater(() => {
                if (popout.dashVisible !== undefined) {
                    popout.dashVisible = true;
                } else if (popout.notificationHistoryVisible !== undefined) {
                    popout.notificationHistoryVisible = true;
                } else {
                    popout.open();
                }
            });
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
