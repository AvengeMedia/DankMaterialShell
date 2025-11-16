pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property var currentPopoutsByScreen: ({})
    property var currentPopoutTriggers: ({})

    function showPopout(popout) {
        if (!popout || !popout.screen) return

        const screenName = popout.screen.name

        for (const otherScreenName in currentPopoutsByScreen) {
            const otherPopout = currentPopoutsByScreen[otherScreenName]
            if (!otherPopout || otherPopout === popout) continue

            if (otherPopout.dashVisible !== undefined) {
                otherPopout.dashVisible = false
            } else if (otherPopout.notificationHistoryVisible !== undefined) {
                otherPopout.notificationHistoryVisible = false
            } else {
                otherPopout.close()
            }
        }

        currentPopoutsByScreen[screenName] = popout
        ModalManager.closeAllModalsExcept(null)
        TrayMenuManager.closeAllMenus()
    }

    function hidePopout(popout) {
        if (!popout || !popout.screen) return

        const screenName = popout.screen.name
        if (currentPopoutsByScreen[screenName] === popout) {
            currentPopoutsByScreen[screenName] = null
            currentPopoutTriggers[screenName] = null
        }
    }

    function closeAllPopouts() {
        for (const screenName in currentPopoutsByScreen) {
            const popout = currentPopoutsByScreen[screenName]
            if (!popout) continue

            if (popout.dashVisible !== undefined) {
                popout.dashVisible = false
            } else if (popout.notificationHistoryVisible !== undefined) {
                popout.notificationHistoryVisible = false
            } else {
                popout.close()
            }
        }
        currentPopoutsByScreen = {}
    }

    function getActivePopout(screen) {
        if (!screen) return null
        return currentPopoutsByScreen[screen.name] || null
    }

    function requestPopout(popout, tabIndex, triggerSource) {
        if (!popout || !popout.screen) return

        const screenName = popout.screen.name
        const currentPopout = currentPopoutsByScreen[screenName]
        const triggerId = triggerSource !== undefined ? triggerSource : tabIndex

        let justClosedSamePopout = false
        for (const otherScreenName in currentPopoutsByScreen) {
            if (otherScreenName === screenName) continue
            const otherPopout = currentPopoutsByScreen[otherScreenName]
            if (!otherPopout) continue

            if (otherPopout === popout) {
                justClosedSamePopout = true
            }

            if (otherPopout.dashVisible !== undefined) {
                otherPopout.dashVisible = false
            } else if (otherPopout.notificationHistoryVisible !== undefined) {
                otherPopout.notificationHistoryVisible = false
            } else {
                otherPopout.close()
            }
        }

        if (currentPopout && currentPopout !== popout) {
            if (currentPopout.dashVisible !== undefined) {
                currentPopout.dashVisible = false
            } else if (currentPopout.notificationHistoryVisible !== undefined) {
                currentPopout.notificationHistoryVisible = false
            } else {
                currentPopout.close()
            }
        }

        if (currentPopout === popout && popout.shouldBeVisible) {
            if (triggerId !== undefined && currentPopoutTriggers[screenName] === triggerId) {
                if (popout.dashVisible !== undefined) {
                    popout.dashVisible = false
                } else if (popout.notificationHistoryVisible !== undefined) {
                    popout.notificationHistoryVisible = false
                } else {
                    popout.close()
                }
                return
            }

            if (triggerId === undefined) {
                if (popout.dashVisible !== undefined) {
                    popout.dashVisible = false
                } else if (popout.notificationHistoryVisible !== undefined) {
                    popout.notificationHistoryVisible = false
                } else {
                    popout.close()
                }
                return
            }

            if (tabIndex !== undefined && popout.currentTabIndex !== undefined) {
                popout.currentTabIndex = tabIndex
            }
            currentPopoutTriggers[screenName] = triggerId
            return
        }

        currentPopoutTriggers[screenName] = triggerId
        currentPopoutsByScreen[screenName] = popout

        if (tabIndex !== undefined && popout.currentTabIndex !== undefined) {
            popout.currentTabIndex = tabIndex
        }

        ModalManager.closeAllModalsExcept(null)
        TrayMenuManager.closeAllMenus()

        if (justClosedSamePopout) {
            Qt.callLater(() => {
                if (popout.dashVisible !== undefined) {
                    popout.dashVisible = true
                } else if (popout.notificationHistoryVisible !== undefined) {
                    popout.notificationHistoryVisible = true
                } else {
                    popout.open()
                }
            })
        } else {
            if (popout.dashVisible !== undefined) {
                popout.dashVisible = true
            } else if (popout.notificationHistoryVisible !== undefined) {
                popout.notificationHistoryVisible = true
            } else {
                popout.open()
            }
        }
    }
}
